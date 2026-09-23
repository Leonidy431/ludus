using UnityEngine;

namespace DeaconsPath.VR.Cockpit
{
    /// <summary>
    /// Rotary knob. Uses the same grab-and-drag maths as the lever, but around
    /// a knob axis and with optional quantisation into detents (e.g. a 6-step
    /// heading selector).
    ///
    /// Output is normalised to [0..1] across [minAngleDeg..maxAngleDeg].
    /// </summary>
    public sealed class CockpitDial : CockpitControl
    {
        [Header("Knob")]
        [SerializeField] private Vector3 axisLocal = Vector3.up;
        [SerializeField] private float minAngleDeg = -135f;
        [SerializeField] private float maxAngleDeg = 135f;

        [Header("Detents")]
        [Tooltip("0 or 1 = continuous. N > 1 quantises to N evenly spaced positions.")]
        [SerializeField] private int detents = 0;

        private float _angle;
        private float _grabAngleStart;
        private float _grabHandAngleStart;
        private Vector3 _axisWorld;
        private Vector3 _referenceWorldDir;
        private bool _referenceValid;

        /// <summary>Current position, normalised to [0..1].</summary>
        public float NormalizedValue
        {
            get
            {
                float span = Mathf.Max(1e-3f, maxAngleDeg - minAngleDeg);
                return Mathf.Clamp01((_angle - minAngleDeg) / span);
            }
        }

        /// <summary>Current knob angle in degrees, measured from the authored rest pose.</summary>
        public float AngleDegrees => _angle;

        public override void GrabBegin(in CockpitInteractionContext ctx)
        {
            base.GrabBegin(in ctx);
            if (!IsEnabled)
                return;

            CaptureAxis();
            _grabAngleStart = _angle;
            _grabHandAngleStart = HandAngle(ctx.handPosition);
        }

        public override void GrabTick(in CockpitInteractionContext ctx)
        {
            base.GrabTick(in ctx);
            if (!IsGrabbed || !_referenceValid)
                return;

            float delta = HandAngle(ctx.handPosition) - _grabHandAngleStart;
            float target = _grabAngleStart + delta;
            ApplyAngle(Clamp(target));

            if (detents > 1)
            {
                float snapped = SnapToDetent(NormalizedValue);
                ApplyAngle(Mathf.Lerp(minAngleDeg, maxAngleDeg, snapped));
            }
        }

        public override void GrabEnd(in CockpitInteractionContext ctx)
        {
            base.GrabEnd(in ctx);
            _grabAngleStart = 0f;
            _grabHandAngleStart = 0f;
        }

        private void CaptureAxis()
        {
            Vector3 localAxis = axisLocal.sqrMagnitude > 1e-6f ? axisLocal.normalized : Vector3.up;
            _axisWorld = ControlTransform.TransformDirection(localAxis).normalized;

            Vector3 reference = Vector3.ProjectOnPlane(
                ControlTransform.TransformDirection(Vector3.forward), _axisWorld);

            if (reference.sqrMagnitude < 1e-6f)
            {
                reference = Vector3.ProjectOnPlane(ControlTransform.up, _axisWorld);
            }

            _referenceWorldDir = reference.normalized;
            _referenceValid = _referenceWorldDir.sqrMagnitude > 1e-6f;
        }

        private float HandAngle(Vector3 worldPoint)
        {
            if (!_referenceValid)
                return 0f;

            Vector3 plane = Vector3.ProjectOnPlane(
                worldPoint - ControlTransform.position, _axisWorld);

            if (plane.sqrMagnitude < 1e-8f)
                return _grabHandAngleStart;

            return Vector3.SignedAngle(_referenceWorldDir, plane.normalized, _axisWorld);
        }

        private float Clamp(float angle)
        {
            float lo = Mathf.Min(minAngleDeg, maxAngleDeg);
            float hi = Mathf.Max(minAngleDeg, maxAngleDeg);
            return Mathf.Clamp(angle, lo, hi);
        }

        private float SnapToDetent(float normalized)
        {
            int steps = detents - 1;
            if (steps <= 0)
                return normalized;

            return Mathf.Round(normalized * steps) / steps;
        }

        private void ApplyAngle(float target)
        {
            float delta = target - _angle;
            if (Mathf.Abs(delta) < 1e-4f)
                return;

            _angle = target;

            if (axisLocal.sqrMagnitude > 1e-6f)
            {
                ControlTransform.Rotate(axisLocal.normalized, delta, Space.Self);
            }

            Emit(CockpitEventType.DialTurned, NormalizedValue, false);
        }
    }
}
