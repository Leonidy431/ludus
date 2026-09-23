using System.Collections.Generic;
using UnityEngine;

namespace DeaconsPath.VR.Cockpit
{
    /// <summary>
    /// Scene-local owner of the cockpit <see cref="CockpitEventBus"/> and the
    /// registry of all <see cref="ICockpitControl"/> instances. Runs before
    /// controls (<c>DefaultExecutionOrder(-95)</c>) so their <c>Awake</c>
    /// registration always succeeds.
    ///
    /// The manager is deliberately scene-local by default: a bus that leaks
    /// across scenes is a classic source of dangling subscribers.
    /// </summary>
    [DefaultExecutionOrder(-95)]
    public sealed class CockpitManager : MonoBehaviour
    {
        public static CockpitManager Instance { get; private set; }

        [Tooltip("Persist this manager (and its event bus) across scene loads.")]
        [SerializeField] private bool persistAcrossScenes = false;

        private readonly CockpitEventBus _bus = new CockpitEventBus();
        private readonly List<ICockpitControl> _controls = new List<ICockpitControl>(64);

        /// <summary>Shared broadcast channel for all cockpit facts.</summary>
        public CockpitEventBus Bus => _bus;

        /// <summary>Registered controls, in registration order.</summary>
        public IReadOnlyList<ICockpitControl> Controls => _controls;

        private void Awake()
        {
            Instance = this;
            if (persistAcrossScenes)
            {
                DontDestroyOnLoad(gameObject);
            }
        }

        private void OnDestroy()
        {
            if (Instance == this)
            {
                Instance = null;
            }
        }

        public void Register(ICockpitControl control)
        {
            if (control == null)
                return;

            for (int i = 0; i < _controls.Count; i++)
            {
                if (ReferenceEquals(_controls[i], control))
                    return;
            }

            _controls.Add(control);
        }

        public void Unregister(ICockpitControl control)
        {
            if (control == null)
                return;

            for (int i = 0; i < _controls.Count; i++)
            {
                if (ReferenceEquals(_controls[i], control))
                {
                    _controls.RemoveAt(i);
                    return;
                }
            }
        }

        /// <summary>
        /// Linear lookup by ControlId. Cockpits are small (≤ 64 controls), so
        /// this is faster and allocation-free compared with a dictionary.
        /// </summary>
        public ICockpitControl Find(string controlId)
        {
            if (string.IsNullOrEmpty(controlId))
                return null;

            for (int i = 0; i < _controls.Count; i++)
            {
                if (_controls[i].ControlId == controlId)
                    return _controls[i];
            }

            return null;
        }
    }
}
