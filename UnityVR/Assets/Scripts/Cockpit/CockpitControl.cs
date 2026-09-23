using UnityEngine;

namespace DeaconsPath.VR.Cockpit
{
    /// <summary>
    /// Shared behaviour for every interactive cockpit part: identity, hover
    /// bookkeeping, optional highlight, and event emission. Concrete controls
    /// (lever, button, toggle, dial) override only the callbacks they need.
    ///
    /// This class never references the input layer; the
    /// <see cref="CockpitInteractor"/> owns that bridge. Highlighting uses a
    /// <see cref="MaterialPropertyBlock"/> so no material instance is created.
    /// </summary>
    public abstract class CockpitControl : MonoBehaviour, ICockpitControl
    {
        [Header("Identity")]
        [SerializeField] private string controlId = "control";

        [Header("State")]
        [SerializeField] private bool interactable = true;

        [Header("Highlight (optional)")]
        [SerializeField] private Renderer highlightRenderer = null;
        [SerializeField] private Color idleColor = new Color(0.82f, 0.82f, 0.82f, 1f);
        [SerializeField] private Color hoverColor = new Color(0.72f, 0.86f, 1f, 1f);
        [SerializeField] private Color grabbedColor = new Color(1f, 0.85f, 0.36f, 1f);

        private MaterialPropertyBlock _block;
        private bool _hovered;
        private bool _grabbed;

        public string ControlId => controlId;
        public Transform ControlTransform => transform;
        public bool IsEnabled => interactable && isActiveAndEnabled;

        public bool IsHovered => _hovered;
        public bool IsGrabbed => _grabbed;

        protected virtual void Awake()
        {
            _block = new MaterialPropertyBlock();
            ApplyVisual(idleColor);

            CockpitManager manager = CockpitManager.Instance;
            if (manager != null)
            {
                manager.Register(this);
            }
        }

        protected virtual void OnDestroy()
        {
            CockpitManager manager = CockpitManager.Instance;
            if (manager != null)
            {
                manager.Unregister(this);
            }
        }

        public virtual void HoverEnter(in CockpitInteractionContext ctx)
        {
            if (!IsEnabled || _hovered)
                return;

            _hovered = true;
            ApplyVisual(_grabbed ? grabbedColor : hoverColor);
            Emit(CockpitEventType.HoverEnter, 0f, false);
        }

        public virtual void HoverExit(in CockpitInteractionContext ctx)
        {
            if (!_hovered)
                return;

            _hovered = false;
            ApplyVisual(_grabbed ? grabbedColor : idleColor);
            Emit(CockpitEventType.HoverExit, 0f, false);
        }

        public virtual void GrabBegin(in CockpitInteractionContext ctx)
        {
            if (!IsEnabled || _grabbed)
                return;

            _grabbed = true;
            ApplyVisual(grabbedColor);
            Emit(CockpitEventType.GrabBegin, 0f, false);
        }

        public virtual void GrabTick(in CockpitInteractionContext ctx)
        {
        }

        public virtual void GrabEnd(in CockpitInteractionContext ctx)
        {
            if (!_grabbed)
                return;

            _grabbed = false;
            ApplyVisual(_hovered ? hoverColor : idleColor);
            Emit(CockpitEventType.GrabEnd, 0f, false);
        }

        public virtual void ButtonDown(in CockpitInteractionContext ctx)
        {
        }

        public virtual void ButtonUp(in CockpitInteractionContext ctx)
        {
        }

        /// <summary>Broadcast a fact about this control on the shared bus.</summary>
        protected void Emit(CockpitEventType type, float value, bool state)
        {
            CockpitManager manager = CockpitManager.Instance;
            if (manager == null)
                return;

            CockpitEvent e = new CockpitEvent
            {
                type = type,
                control = this,
                controlId = controlId,
                value = value,
                state = state,
                worldPosition = transform.position,
                timeSeconds = Time.time,
            };

            manager.Bus.Raise(e);
        }

        protected void ApplyVisual(Color color)
        {
            if (highlightRenderer == null || _block == null)
                return;

            highlightRenderer.GetPropertyBlock(_block);
            _block.SetColor("_BaseColor", color);
            _block.SetColor("_Color", color);
            highlightRenderer.SetPropertyBlock(_block);
        }
    }
}
