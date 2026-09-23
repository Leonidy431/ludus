using UnityEngine;

namespace DeaconsPath.VR.Cockpit
{
    /// <summary>
    /// Analog hinged lever. The player grabs the handle and drags it; the
    /// interactor supplies the hand's world position, and the lever rotates
    /// around its local <see cref="hingeAxisLocal"/> to follow.
    ///
    /// Output is a normalised value in [-1..1] for a symmetric hinge
    /// (min = -max) or [0..1] for a one-sided hinge (min = 0). Used for
    /// throttle, rudder trim, ballast blow and similar analog controls.
    /// </summary>
    public sealed class CockpitLever : CockpitControl
    {
        [Header("Hinge")]
        [Tooltip("Local-space axis the lever rotates around, e.g. Vector3.right.")]
        [SerializeField] private Vector3 hingeAxisLocal = Vector3.right;
        [SerializeField] private float minAngleDeg = -35f;
        [SerializeField] private float maxAngleDeg = 35f;
        [SerializeField] private bool invert = false;

        [Header("Return")]
        [Tooltip("When true the lever springs back to restValue when released.")]
        [SerializeField] private bool springReturn = false;
        [SerializeField] private float springDegreesPerSecond = 180f;
        [SerializeField, Range(-1f, 1f)] private float restValue = 0f;

        private float _angle;
        private float _grabAngleStart;
        private float _grabHandAngleStart;
        private Vector3 _hingeWorldAxis;
        private Vector3 _referenceWorldDir;
        private bool _referenceValid;

        /// <summary>Current normalised position: [-1..1] or [0..1] by range.</summary>
        public float NormalizedValue
        {
            get
            {
                if (_angle >= 0f)
                {
                    return maxAngleDeg > 1e-3f
                        ? Mathf.Clamp(_angle / maxAngleDeg, 0f, 1f)
                        : 0f;
                }

                float absMin = Mathf.Abs(minAngleDeg);
                return absMin > 1e-3f
                    ? Mathf.Clamp(_angle / absMin, -1f, 0f)
                    : 0f;
            }
        }

        /// <summary>Current hinge angle in degrees, measured from the authored rest pose.</summary>
        public float AngleDegrees => _angle;

        protected override void Awake()
        {
            base.Awake();
            CaptureHinge();
        }

        public override void GrabBegin(in CockpitInteractionContext ctx)
        {
            base.GrabBegin(in ctx);
            if (!IsEnabled)
                return;

            CaptureHinge();
            _grabAngleStart = _angle;
            _grabHandAngleStart = HandAngle(ctx.handPosition);
        }

        public override void GrabTick(in CockpitInteractionContext ctx)
        {
            base.GrabTick(in ctx);
            if (!IsGrabbed || !_referenceValid)
                return;

            float handAngle = HandAngle(ctx.handPosition);
            float delta = handAngle - _grabHandAngleStart;
            float target = _grabAngleStart + (invert ? -delta : delta);
            ApplyAngle(NormalizedClampAngle(target));
        }

        public override void GrabEnd(in CockpitInteractionContext ctx)
        {
            base.GrabEnd(in ctx);
            _grabAngleStart = 0f;
            _grabHandAngleStart = 0f;
        }

        private void Update()
        {
            if (!springReturn || IsGrabbed)
                return;

            float restAngle = AngleFromValue(restValue);
            if (Mathf.Abs(_angle - restAngle) < 1e-3f)
                return;

            ApplyAngle(Mathf.MoveTowards(_angle, restAngle, springDegreesPerSecond * Time.deltaTime));
        }

        private void CaptureHinge()
        {
            Vector3 localAxis = hingeAxisLocal.sqrMagnitude > 1e-6f
                ? hingeAxisLocal.normalized
                : Vector3.right;

            _hingeWorldAxis = ControlTransform.TransformDirection(localAxis).normalized;

            Vector3 reference = Vector3.ProjectOnPlane(
                ControlTransform.TransformDirection(Vector3.forward), _hingeWorldAxis);

            if (reference.sqrMagnitude < 1e-6f)
            {
                reference = Vector3.ProjectOnPlane(ControlTransform.up, _hingeWorldAxis);
            }

            _referenceWorldDir = reference.normalized;
            _referenceValid = _referenceWorldDir.sqrMagnitude > 1e-6f;
        }

        private float HandAngle(Vector3 worldPoint)
        {
            if (!_referenceValid)
                return 0f;

            Vector3 plane = Vector3.ProjectOnPlane(
                worldPoint - ControlTransform.position, _hingeWorldAxis);

            if (plane.sqrMagnitude < 1e-8f)
                return _grabHandAngleStart;

            return Vector3.SignedAngle(_referenceWorldDir, plane.normalized, _hingeWorldAxis);
        }

        private float NormalizedClampAngle(float angle)
        {
            float lo = Mathf.Min(minAngleDeg, maxAngleDeg);
            float hi = Mathf.Max(minAngleDeg, maxAngleDeg);
            return Mathf.Clamp(angle, lo, hi);
        }

        private float AngleFromValue(float value)
        {
            float v = Mathf.Clamp(value, -1f, 1f);
            return v >= 0f ? v * maxAngleDeg : v * Mathf.Abs(minAngleDeg);
        }

        private void ApplyAngle(float targetAngle)
        {
            float delta = targetAngle - _angle;
            if (Mathf.Abs(delta) < 1e-4f)
                return;

            _angle = targetAngle;

            Vector3 axis = hingeAxisLocal.sqrMagnitude > 1e-6f
                ? hingeAxisLocal.normalized
                : Vector3.right;
            ControlTransform.Rotate(axis, delta, Space.Self);

            Emit(CockpitEventType.LeverMoved, NormalizedValue, _angle > 0f);
        }
    }
}
