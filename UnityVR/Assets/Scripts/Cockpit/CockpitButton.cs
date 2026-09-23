using UnityEngine;

namespace DeaconsPath.VR.Cockpit
{
    /// <summary>
    /// Momentary push button. Acts on the discrete primary button (or on a
    /// grab) and snaps back with a visible plunger travel. Buttons do not feed
    /// the vehicle command source; they exist for HUD, audio and mission
    /// scripting, which subscribe to <see cref="CockpitEventType.Pressed"/> /
    /// <see cref="CockpitEventType.Released"/>.
    /// </summary>
    public sealed class CockpitButton : CockpitControl
    {
        [Header("Motion")]
        [Tooltip("Visual that translates during a press. Defaults to this transform.")]
        [SerializeField] private Transform plunger = null;
        [SerializeField] private Vector3 pressLocalDirection = Vector3.down;
        [SerializeField] private float travelMeters = 0.012f;
        [Tooltip("Normalised units per second used to animate the plunger.")]
        [SerializeField] private float returnSpeed = 6f;

        private Vector3 _restLocalPosition;
        private float _press;
        private float _targetPress;

        /// <summary>True while the button is logically held down.</summary>
        public bool IsDown => _targetPress > 0.5f;

        protected override void Awake()
        {
            base.Awake();
            if (plunger == null)
            {
                plunger = transform;
            }
            _restLocalPosition = plunger.localPosition;
        }

        public override void ButtonDown(in CockpitInteractionContext ctx)
        {
            if (!IsEnabled)
                return;

            _targetPress = 1f;
            Emit(CockpitEventType.Pressed, 1f, true);
        }

        public override void ButtonUp(in CockpitInteractionContext ctx)
        {
            _targetPress = 0f;
            Emit(CockpitEventType.Released, 0f, false);
        }

        public override void GrabBegin(in CockpitInteractionContext ctx)
        {
            base.GrabBegin(in ctx);
            ButtonDown(in ctx);
        }

        public override void GrabEnd(in CockpitInteractionContext ctx)
        {
            base.GrabEnd(in ctx);
            ButtonUp(in ctx);
        }

        private void Update()
        {
            if (plunger == null || Mathf.Approximately(_press, _targetPress))
                return;

            _press = Mathf.MoveTowards(_press, _targetPress, returnSpeed * Time.deltaTime);

            Vector3 direction = pressLocalDirection.sqrMagnitude > 1e-6f
                ? pressLocalDirection.normalized
                : Vector3.down;

            plunger.localPosition = _restLocalPosition + direction * (_press * travelMeters);
        }
    }
}
