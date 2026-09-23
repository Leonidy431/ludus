using System;
using DeaconsPath.VR.Cockpit;
using UnityEngine;

namespace DeaconsPath.VR.Instruments
{
    /// <summary>
    /// The one Phase 5 -> Phase 3 bridge. Subscribes to <see cref="DiveComputer"/>'s
    /// C# events and republishes them as <see cref="CockpitEvent"/>s on a
    /// <see cref="CockpitEventBus"/>, so a cockpit HUD, audio cues and haptics can
    /// react to dive state without the classification module taking a Cockpit
    /// dependency. Symmetric with the other bridges in the project:
    ///
    ///   Phase 1 (Input)   -> Phase 2 (Physics) : InputCommandAdapter
    ///   Phase 3 (Cockpit) -> Phase 2 (Physics) : CockpitCommandSource
    ///   Phase 2 (Physics) -> Phase 5 (Instr.)  : SixDofTelemetrySource
    ///   Phase 5 (Instr.)  -> Phase 3 (Cockpit) : DiveCockpitBridge   <- this file
    ///
    /// The <see cref="CockpitEventType"/> enum declared by the frozen Phase 3
    /// <c>CockpitEvent.cs</c> has no dive-specific members, and that file is not
    /// edited by this pass. The bridge therefore publishes with the nearest
    /// generic type (<see cref="CockpitEventType.Toggled"/>) and encodes the
    /// semantics in <c>controlId</c>, which is exactly what <c>controlId</c> is
    /// for: an opaque string a subscriber matches on. The two well-known ids are
    /// <see cref="StateControlId"/> and <see cref="AlarmControlId"/>, so the HUD,
    /// the audio director and any mission script agree by construction.
    ///
    /// Bus resolution order in <c>Awake</c>:
    /// 1. A bus bound explicitly via <see cref="Bind(CockpitEventBus)"/>.
    /// 2. The shared <see cref="CockpitManager.Instance"/>.Bus, when a manager
    ///    exists in the scene and <see cref="autoBindSharedBus"/> is enabled.
    /// 3. A private <see cref="CockpitEventBus"/> owned by this component, so
    ///    a bare test / tool scene with no cockpit manager still emits events.
    ///
    /// <see cref="CockpitManager"/> runs at <c>DefaultExecutionOrder(-95)</c>,
    /// ahead of this bridge at <c>-45</c>, so on normal scene load its
    /// <c>Instance</c> is guaranteed to be set before this <c>Awake</c> runs.
    ///
    /// CONSTITUTION.md: pure game code, isolated by branch and directory. No
    /// Webtypicon2 or liturgical reference.
    /// </summary>
    [DefaultExecutionOrder(-45)]
    [DisallowMultipleComponent]
    public sealed class DiveCockpitBridge : MonoBehaviour
    {
        /// <summary>
        /// controlId for a <see cref="DiveState"/> telegram.
        /// <c>value</c> carries (float)state, <c>state</c> is true for every
        /// phase that is not <see cref="DiveState.Unpowered"/>.
        /// </summary>
        public const string StateControlId = "dive.state";

        /// <summary>
        /// controlId for a <see cref="DiveAlarm"/> telegram.
        /// <c>value</c> carries (float)alarm, <c>state</c> is true when the alarm
        /// is actionable (anything other than <see cref="DiveAlarm.None"/>).
        /// </summary>
        public const string AlarmControlId = "dive.alarm";

        // ---- Wiring ----------------------------------------------------------
        [SerializeField]
        [Tooltip("Source of dive state/alarm events. Resolved from the hierarchy in Awake if left blank.")]
        private DiveComputer computer;

        [SerializeField]
        [Tooltip("If no bus is explicitly bound, adopt the shared CockpitManager.Instance.Bus when a manager exists in the scene.")]
        private bool autoBindSharedBus = true;

        private CockpitEventBus externalBus;
        private bool subscribed;

        // ---- Public surface --------------------------------------------------
        /// <summary>
        /// The bus this bridge raises onto. After <c>Awake</c> it is either the
        /// shared <see cref="CockpitManager"/> bus, a bus bound via
        /// <see cref="Bind(CockpitEventBus)"/>, or the bridge's own private
        /// fallback. Never null once <c>Awake</c> has run.
        /// </summary>
        public CockpitEventBus Bus { get; private set; }

        /// <summary>The <see cref="DiveComputer"/> currently wired, or null.</summary>
        public DiveComputer Computer { get { return computer; } }

        /// <summary>True while the bridge is attached to a live computer.</summary>
        public bool IsSubscribed { get { return subscribed; } }

        /// <summary>
        /// True when the bus being raised onto is the shared
        /// <see cref="CockpitManager"/> bus (i.e. a plain HUD subscribed to
        /// <c>CockpitManager.Instance.Bus</c> will receive dive telegrams).
        /// False when the bridge is using its private fallback or an
        /// explicitly bound external bus.
        /// </summary>
        public bool UsingSharedBus
        {
            get
            {
                CockpitManager manager = CockpitManager.Instance;
                return externalBus != null
                    && manager != null
                    && ReferenceEquals(externalBus, manager.Bus);
            }
        }

        /// <summary>
        /// Explicitly set the bus to publish onto. Call before scene load or at
        /// any time (the reassignment is immediate); a later call overrides the
        /// auto-adopted shared bus. Passing null falls back to a private bus.
        /// </summary>
        public void Bind(CockpitEventBus bus)
        {
            externalBus = bus;
            EnsureBus();
        }

        /// <summary>
        /// Test / cutscene entry point. Matches the Bind pattern already used by
        /// <c>SixDofBody.Bind</c>, <c>InputCommandAdapter.Bind</c>,
        /// <c>SixDofTelemetrySource.Bind</c>, so all four bridges wire identically
        /// in a harness. Unsubscribes first so a rebind to the same computer
        /// cannot double-deliver events.
        /// </summary>
        public void Bind(DiveComputer source)
        {
            Unsubscribe();
            computer = source;
            SubscribeIfReady();
        }

        // ---- Lifecycle -------------------------------------------------------
        private void Awake()
        {
            if (computer == null)
            {
                computer = GetComponentInChildren<DiveComputer>();
            }

            if (computer == null)
            {
                computer = GetComponentInParent<DiveComputer>();
            }

            AdoptSharedBusIfAvailable();
            EnsureBus();
            SubscribeIfReady();
        }

        private void OnDestroy()
        {
            Unsubscribe();
        }

        // ---- Internals -------------------------------------------------------
        /// <summary>
        /// Pull <see cref="CockpitManager.Instance"/>.Bus unless an explicit bus
        /// has already been bound or auto-binding is disabled. A manager that is
        /// added to the scene *after* this Awake (dynamically, without the -95
        /// execution order applying) will not be picked up automatically; call
        /// <see cref="Bind(CockpitEventBus)"/> in that case.
        /// </summary>
        private void AdoptSharedBusIfAvailable()
        {
            if (externalBus != null || !autoBindSharedBus)
            {
                return;
            }

            CockpitManager manager = CockpitManager.Instance;
            if (manager != null)
            {
                externalBus = manager.Bus;
            }
        }

        private void EnsureBus()
        {
            // Never let Bus go null once Awake has run: a subscriber that grabbed
            // the reference before an external bind must keep seeing events on a
            // live object, even if the external bus is later cleared.
            Bus = externalBus ?? new CockpitEventBus();
        }

        private void SubscribeIfReady()
        {
            if (subscribed || computer == null || Bus == null)
            {
                return;
            }

            computer.StateChanged += OnStateChanged;
            computer.AlarmRaised += OnAlarmRaised;
            subscribed = true;
        }

        /// <summary>
        /// Detaches from the computer. Called from <see cref="OnDestroy"/> and
        /// before any rebind, so destroying or rewiring a bridge can never leave
        /// a dangling delegate on a computer's event list.
        /// </summary>
        private void Unsubscribe()
        {
            if (!subscribed)
            {
                return;
            }

            if (computer != null)
            {
                computer.StateChanged -= OnStateChanged;
                computer.AlarmRaised -= OnAlarmRaised;
            }

            subscribed = false;
        }

        private void OnStateChanged(DiveState state)
        {
            CockpitEventBus target = Bus;
            if (target == null)
            {
                return;
            }

            target.Raise(BuildEvent(
                StateControlId,
                (float)state,
                state != DiveState.Unpowered));
        }

        private void OnAlarmRaised(DiveAlarm alarm)
        {
            CockpitEventBus target = Bus;
            if (target == null)
            {
                return;
            }

            target.Raise(BuildEvent(
                AlarmControlId,
                (float)alarm,
                alarm != DiveAlarm.None));
        }

        /// <summary>
        /// A <see cref="CockpitEvent"/> is a value type with no managed fields, so
        /// building one here does not allocate. <c>control</c> is deliberately
        /// null: this is an instrument telegram with no physical control behind
        /// it, and a subscriber discriminates on <c>controlId</c>. <c>timeSeconds</c>
        /// is stamped from <see cref="Time.time"/> so the same telegram is
        /// timestamp-consistent across every bus subscriber.
        /// </summary>
        private CockpitEvent BuildEvent(string controlId, float value, bool state)
        {
            CockpitEvent e;
            e.type = CockpitEventType.Toggled;
            e.control = null;
            e.controlId = controlId;
            e.value = value;
            e.state = state;
            e.worldPosition = transform.position;
            e.timeSeconds = Time.time;
            return e;
        }
    }
}
