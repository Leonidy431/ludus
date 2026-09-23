using UnityEngine;
using DeaconsPath.VR.Input;

namespace DeaconsPath.VR.Cockpit
{
    /// <summary>
    /// Turns the Phase 1 <see cref="IPlayerInput"/> hand into cockpit
    /// interactions. One interactor drives the *primary* hand:
    ///
    /// - Hover: a short ray from the hand pose, masked to interactable layers.
    /// - Grab: primary trigger held above <see cref="grabThreshold"/>.
    /// - Press: the discrete primary button.
    ///
    /// The interactor is the ONLY file in the cockpit folder that touches the
    /// input layer, so controls remain device-agnostic and cheap to test.
    /// Hover is deliberately frozen while a grab is in flight; otherwise a
    /// lever held under the hand would flicker as the ray sweeps the panel.
    /// </summary>
    [DefaultExecutionOrder(-80)]
    public sealed class CockpitInteractor : MonoBehaviour
    {
        [Header("Binding")]
        [Tooltip("Optional. MonoBehaviour implementing IPlayerInput. Left empty, " +
                 "the interactor searches itself, then its children, then " +
                 "InputProvider.Current.")]
        [SerializeField] private MonoBehaviour inputBehaviour = null;
        [SerializeField] private bool searchChildren = true;

        [Header("Raycast")]
        [SerializeField] private LayerMask interactionMask = ~0;
        [SerializeField] private float rayLengthMeters = 0.4f;
        [SerializeField] private QueryTriggerInteraction triggerInteraction = QueryTriggerInteraction.Collide;

        [Header("Grab thresholds")]
        [SerializeField, Range(0f, 1f)] private float grabThreshold = 0.65f;
        [SerializeField, Range(0f, 1f)] private float releaseThreshold = 0.35f;

        private IPlayerInput _input;
        private ICockpitControl _hovered;
        private ICockpitControl _grabbed;
        private float _previousTrigger;

        private bool _buttonDownPending;
        private bool _buttonUpPending;

        /// <summary>Control currently under the hand ray, if any.</summary>
        public ICockpitControl Hovered => _hovered;

        /// <summary>Control currently held by the trigger, if any.</summary>
        public ICockpitControl Grabbed => _grabbed;

        private void Awake()
        {
            _input = ResolveInput();
            if (_input == null)
            {
                Debug.LogWarning(
                    "[CockpitInteractor] No IPlayerInput found. Call Bind() before use.", this);
                return;
            }

            _input.PrimaryButtonPressed += OnPrimaryButtonPressed;
            _input.PrimaryButtonReleased += OnPrimaryButtonReleased;
        }

        private void OnDestroy()
        {
            if (_input == null)
                return;

            _input.PrimaryButtonPressed -= OnPrimaryButtonPressed;
            _input.PrimaryButtonReleased -= OnPrimaryButtonReleased;
        }

        /// <summary>Explicit binding for tests, cutscenes and non-XR rigs.</summary>
        public void Bind(IPlayerInput input)
        {
            if (_input != null)
            {
                _input.PrimaryButtonPressed -= OnPrimaryButtonPressed;
                _input.PrimaryButtonReleased -= OnPrimaryButtonReleased;
            }

            _input = input;

            if (_input != null)
            {
                _input.PrimaryButtonPressed += OnPrimaryButtonPressed;
                _input.PrimaryButtonReleased += OnPrimaryButtonReleased;
            }
        }

        private void Update()
        {
            if (_input == null)
                return;

            float trigger = _input.PrimaryTrigger;
            CockpitInteractionContext ctx = BuildContext(Time.deltaTime);

            if (_grabbed == null)
            {
                UpdateHover(in ctx);

                if (_buttonDownPending && _hovered != null)
                {
                    _hovered.ButtonDown(in ctx);
                }

                if (_buttonUpPending && _hovered != null)
                {
                    _hovered.ButtonUp(in ctx);
                }

                if (_hovered != null && trigger >= grabThreshold)
                {
                    _grabbed = _hovered;
                    _grabbed.GrabBegin(in ctx);
                }
            }
            else
            {
                if (trigger <= releaseThreshold)
                {
                    _grabbed.GrabEnd(in ctx);
                    _grabbed = null;
                }
                else
                {
                    _grabbed.GrabTick(in ctx);
                }
            }

            _buttonDownPending = false;
            _buttonUpPending = false;
            _previousTrigger = trigger;
        }

        private void UpdateHover(in CockpitInteractionContext ctx)
        {
            ICockpitControl next = null;
            Vector3 hitPoint = Vector3.zero;

            if (Physics.Raycast(
                    ctx.rayOrigin,
                    ctx.rayDirection,
                    out RaycastHit hit,
                    rayLengthMeters,
                    interactionMask,
                    triggerInteraction))
            {
                CockpitControl control = hit.collider.GetComponentInParent<CockpitControl>();
                if (control != null && control.IsEnabled)
                {
                    next = control;
                    hitPoint = hit.point;
                }
            }

            if (ReferenceEquals(next, _hovered))
                return;

            CockpitInteractionContext hoverCtx = ctx;
            hoverCtx.hitPoint = hitPoint;

            if (_hovered != null)
            {
                _hovered.HoverExit(in hoverCtx);
            }

            _hovered = next;

            if (_hovered != null)
            {
                _hovered.HoverEnter(in hoverCtx);
            }
        }

        private CockpitInteractionContext BuildContext(float deltaTime)
        {
            Pose hand = _input.IsPrimaryHandTracked ? _input.PrimaryHandPose : _input.HeadPose;

            return new CockpitInteractionContext
            {
                input = _input,
                handPosition = hand.position,
                rayOrigin = hand.position,
                rayDirection = hand.forward,
                deltaTime = deltaTime,
            };
        }

        private void OnPrimaryButtonPressed()
        {
            _buttonDownPending = true;
        }

        private void OnPrimaryButtonReleased()
        {
            _buttonUpPending = true;
        }

        private IPlayerInput ResolveInput()
        {
            if (inputBehaviour is IPlayerInput direct)
            {
                return direct;
            }

            IPlayerInput local = GetComponent<IPlayerInput>();
            if (local != null)
            {
                return local;
            }

            if (searchChildren)
            {
                MonoBehaviour[] candidates = GetComponentsInChildren<MonoBehaviour>(true);
                for (int i = 0; i < candidates.Length; i++)
                {
                    if (candidates[i] is IPlayerInput found)
                    {
                        return found;
                    }
                }
            }

            return InputProvider.Current;
        }
    }
}
