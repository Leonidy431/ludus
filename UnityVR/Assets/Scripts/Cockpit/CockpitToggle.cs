using UnityEngine;

namespace DeaconsPath.VR.Cockpit
{
    /// <summary>
    /// Two-position latching switch. Toggles on a discrete button press or on a
    /// grab, and animates its lever between <see cref="offAngleDeg"/> and
    /// <see cref="onAngleDeg"/>.
    ///
    /// The switch is assumed to be authored in its neutral (0°) pose; Awake
    /// offsets it to the starting state, and the animation runs from there.
    /// </summary>
    public sealed class CockpitToggle : CockpitControl
    {
        [Header("Hinge")]
        [SerializeField] private Vector3 hingeAxisLocal = Vector3.right;
        [SerializeField] private float offAngleDeg = -25f;
        [SerializeField] private float onAngleDeg = 25f;
        [SerializeField] private float animateDegreesPerSecond = 480f;

        [Header("Initial state")]
        [SerializeField] private bool startOn = false;

        private bool _isOn;
        private float _angle;
        private float _targetAngle;

        /// <summary>True when the switch is in its "on" position.</summary>
        public bool IsOn => _isOn;

        protected override void Awake()
        {
            base.Awake();

            _isOn = startOn;
            _targetAngle = _isOn ? onAngleDeg : offAngleDeg;
            _angle = _targetAngle;

            if (hingeAxisLocal.sqrMagnitude > 1e-6f)
            {
                ControlTransform.Rotate(hingeAxisLocal.normalized, _angle, Space.Self);
            }
        }

        public override void ButtonDown(in CockpitInteractionContext ctx)
        {
            if (!IsEnabled)
                return;

            SetState(!_isOn, true);
        }

        public override void GrabBegin(in CockpitInteractionContext ctx)
        {
            base.GrabBegin(in ctx);
            if (!IsEnabled)
                return;

            SetState(!_isOn, true);
        }

        /// <summary>Programmatic state change, used by tests and mission scripts.</summary>
        public void SetState(bool on, bool raiseEvent)
        {
            _isOn = on;
            _targetAngle = _isOn ? onAngleDeg : offAngleDeg;

            if (raiseEvent)
            {
                Emit(CockpitEventType.Toggled, _isOn ? 1f : 0f, _isOn);
            }
        }

        private void Update()
        {
            if (Mathf.Abs(_angle - _targetAngle) < 1e-3f)
                return;

            float next = Mathf.MoveTowards(_angle, _targetAngle, animateDegreesPerSecond * Time.deltaTime);
            float delta = next - _angle;
            _angle = next;

            if (hingeAxisLocal.sqrMagnitude > 1e-6f)
            {
                ControlTransform.Rotate(hingeAxisLocal.normalized, delta, Space.Self);
            }
        }
    }
}
