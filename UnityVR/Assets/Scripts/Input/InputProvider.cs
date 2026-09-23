using System;
using UnityEngine;

namespace DeaconsPath.VR.Input
{
    public enum InputBackend
    {
        Auto,
        MouseSimulator,
        OpenXR
    }

    /// <summary>
    /// Single MonoBehaviour that owns the active <see cref="IPlayerInput"/> and
    /// drives its per-frame <c>Tick</c>. Gameplay code grabs <see cref="Current"/>
    /// and never touches platform APIs.
    ///
    /// Backend selection: <see cref="InputBackend.Auto"/> picks OpenXR when an
    /// XR display is active, otherwise the mouse simulator. This lets the same
    /// scene run in the Editor and stream to Quest 3 without code changes.
    /// </summary>
    [DefaultExecutionOrder(-100)]
    public sealed class InputProvider : MonoBehaviour
    {
        [Header("Rig")]
        [SerializeField] private Transform _head;
        [SerializeField] private Transform _hand;

        [Header("Backend")]
        [SerializeField] private InputBackend _backend = InputBackend.Auto;

        /// <summary>
        /// Global access point. Set in <c>Awake</c>; valid for the scene lifetime.
        /// </summary>
        public static IPlayerInput Current { get; private set; }

        /// <summary>Raised when the active backend changes (e.g. XR device connect).</summary>
        public static event Action<IPlayerInput> BackendChanged;

        private IPlayerInput _impl;

        private void Awake()
        {
            ResolveRig();
            _impl = CreateBackend();
            Current = _impl;
            BackendChanged?.Invoke(_impl);
        }

        private void OnDestroy()
        {
            if (ReferenceEquals(Current, _impl))
            {
                Current = null;
            }
        }

        private void Update()
        {
            _impl?.Tick(Time.deltaTime);
        }

        private void ResolveRig()
        {
            if (_head == null)
            {
                var cam = Camera.main != null ? Camera.main.transform : null;
                _head = cam;
            }
            if (_head == null)
            {
                throw new InvalidOperationException(
                    "InputProvider: no head transform. Assign 'Head' or tag a Main Camera.");
            }
            if (_hand == null)
            {
                _hand = _head; // degrade gracefully; hands optional in sim mode
            }
        }

        private IPlayerInput CreateBackend()
        {
            bool xrActive = _backend == InputBackend.OpenXR ||
                            (_backend == InputBackend.Auto && IsXrActive());

            return xrActive
                ? (IPlayerInput)new OpenXRInput(_head, _hand)
                : new MouseSimulatorInput(_head, _hand);
        }

        private static bool IsXrActive()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            return true; // Quest build is always XR-first
#else
            var xr = UnityEngine.XR.XRSettings.isDeviceActive;
            return xr;
#endif
        }
    }
}
