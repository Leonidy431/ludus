using DeaconsPath.VR.Cockpit;
using DeaconsPath.VR.Instruments;
using NUnit.Framework;
using UnityEngine;

namespace DeaconsPath.VR.Tests.EditMode
{
    /// <summary>
    /// Behavioural tests for the Phase 5 -> Phase 3 cockpit bridge. Everything is
    /// scene-free: the <see cref="DiveComputer"/> is driven directly against an
    /// in-file fake source and the resulting <see cref="CockpitEvent"/>s are
    /// caught by a plain delegate subscriber. Runs on the headless CI runner.
    ///
    /// These do not re-derive the classification rules (that is
    /// <c>DiveComputerTests</c>); they assert the *bridge contract*: correct
    /// controlId, correct encoded value/state, transition-only firing, bus
    /// resolution (explicit -> shared CockpitManager -> private fallback),
    /// clean unsubscribe on destroy, and no double-publish after a rebind.
    /// </summary>
    [TestFixture]
    public sealed class DiveCockpitBridgeTests
    {
        private GameObject host;
        private GameObject managerHost;

        [SetUp]
        public void SetUp()
        {
            host = new GameObject("DiveCockpitBridgeTests");
            managerHost = null;
        }

        [TearDown]
        public void TearDown()
        {
            // Destroy the manager first so CockpitManager.Instance is cleared
            // before host teardown, keeping the singleton from leaking across
            // fixture methods.
            if (managerHost != null)
            {
                UnityEngine.Object.DestroyImmediate(managerHost);
                managerHost = null;
            }

            UnityEngine.Object.DestroyImmediate(host);
        }

        private sealed class FakeSource : IDiveTelemetrySource
        {
            public DiveTelemetrySample Next;

            public bool IsReady { get { return true; } }

            public DiveTelemetrySample Sample(float deltaTime)
            {
                return Next;
            }
        }

        private static DiveTelemetrySample Sample(float depth, bool submerged)
        {
            return new DiveTelemetrySample
            {
                DepthMeters = depth,
                SubmergedFraction = submerged ? 1f : 0f,
                DensityKgPerCubicMeter = 1000f,
                BallastFill = 0.5f,
                IsSubmerged = submerged,
                Valid = true,
            };
        }

        /// <summary>
        /// Creates a <see cref="CockpitManager"/> host that is destroyed in
        /// TearDown. Because <c>AddComponent</c> triggers <c>Awake</c>
        /// synchronously in the editor, <c>CockpitManager.Instance</c> is set
        /// before any later bridge is created in the same test.
        /// </summary>
        private CockpitManager CreateManager()
        {
            managerHost = new GameObject("CockpitManagerHost");
            return managerHost.AddComponent<CockpitManager>();
        }

        private DiveCockpitBridge NewBridge(out DiveComputer computer)
        {
            computer = host.AddComponent<DiveComputer>();
            computer.Bind(new FakeSource { Next = Sample(0f, true) });

            DiveCockpitBridge bridge = host.AddComponent<DiveCockpitBridge>();
            bridge.Bind(computer);
            return bridge;
        }

        [Test]
        public void AlarmChange_PublishesAlarmControlIdWithEncodedValue()
        {
            DiveComputer computer;
            DiveCockpitBridge bridge = NewBridge(out computer);

            int seen = 0;
            int lastValue = -1;
            bool lastState = false;
            bridge.Bus.Subscribe(delegate(CockpitEvent e)
            {
                if (e.controlId != DiveCockpitBridge.AlarmControlId)
                {
                    return;
                }

                seen++;
                lastValue = (int)e.value;
                lastState = e.state;
            });

            computer.Bind(new FakeSource { Next = Sample(90f, true) });
            computer.Tick(0.5f);

            Assert.AreEqual(1, seen, "exactly one alarm telegram expected");
            Assert.AreEqual((int)DiveAlarm.ApproachingSeabed, lastValue);
            Assert.IsTrue(lastState, "an actionable alarm must set state = true");
        }

        [Test]
        public void StateChange_PublishesStateControlIdWithEncodedValue()
        {
            DiveComputer computer;
            DiveCockpitBridge bridge = NewBridge(out computer);

            int seen = 0;
            int lastValue = -1;
            bridge.Bus.Subscribe(delegate(CockpitEvent e)
            {
                if (e.controlId != DiveCockpitBridge.StateControlId)
                {
                    return;
                }

                seen++;
                lastValue = (int)e.value;
            });

            computer.Bind(new FakeSource { Next = Sample(0f, false) });
            computer.Tick(0.5f);

            Assert.AreEqual(1, seen, "exactly one state telegram expected");
            Assert.AreEqual((int)DiveState.Surfaced, lastValue);
        }

        [Test]
        public void Telegram_CarriesTheToggledCategoryAndNullControl()
        {
            DiveComputer computer;
            DiveCockpitBridge bridge = NewBridge(out computer);

            CockpitEvent captured = default(CockpitEvent);
            bool have = false;
            bridge.Bus.Subscribe(delegate(CockpitEvent e)
            {
                captured = e;
                have = true;
            });

            computer.Bind(new FakeSource { Next = Sample(0f, false) });
            computer.Tick(0.5f);

            Assert.IsTrue(have);
            Assert.AreEqual(CockpitEventType.Toggled, captured.type);
            Assert.IsNull(captured.control);
            Assert.IsNotEmpty(captured.controlId);
        }

        [Test]
        public void NoChange_ProducesNoFurtherTelegrams()
        {
            DiveComputer computer;
            DiveCockpitBridge bridge = NewBridge(out computer);

            int seen = 0;
            bridge.Bus.Subscribe(delegate { seen++; });

            computer.Bind(new FakeSource { Next = Sample(0f, false) });
            computer.Tick(0.5f);
            int afterFirst = seen;
            Assert.GreaterOrEqual(afterFirst, 1);

            computer.Tick(0.5f);
            computer.Tick(0.5f);

            Assert.AreEqual(afterFirst, seen);
        }

        [Test]
        public void BoundExternalBus_ReplacesTheOwnedFallback()
        {
            DiveComputer computer;
            DiveCockpitBridge bridge = NewBridge(out computer);

            CockpitEventBus owned = bridge.Bus;
            CockpitEventBus externalBus = new CockpitEventBus();
            bridge.Bind(externalBus);

            Assert.AreSame(externalBus, bridge.Bus);
            Assert.AreNotSame(owned, externalBus);

            int seen = 0;
            externalBus.Subscribe(delegate { seen++; });

            computer.Bind(new FakeSource { Next = Sample(0f, false) });
            computer.Tick(0.5f);

            Assert.AreEqual(1, seen);
        }

        [Test]
        public void DestroyBridge_DetachesFromComputerEvents()
        {
            DiveComputer computer;
            DiveCockpitBridge bridge = NewBridge(out computer);
            CockpitEventBus bus = bridge.Bus;

            int seen = 0;
            bus.Subscribe(delegate { seen++; });

            computer.Bind(new FakeSource { Next = Sample(0f, false) });
            computer.Tick(0.5f);
            int afterFirst = seen;
            Assert.GreaterOrEqual(afterFirst, 1);

            UnityEngine.Object.DestroyImmediate(bridge);

            computer.Bind(new FakeSource { Next = Sample(90f, true) });
            computer.Tick(0.5f);

            Assert.AreEqual(afterFirst, seen, "a destroyed bridge must not keep publishing");
        }

        [Test]
        public void Rebind_DoesNotDoublePublishOnTheSameComputer()
        {
            DiveComputer computer;
            DiveCockpitBridge bridge = NewBridge(out computer);

            int seen = 0;
            bridge.Bus.Subscribe(delegate { seen++; });

            // Rebinding to the same computer must unsubscribe first, or the
            // second subscribe would deliver each event twice.
            bridge.Bind(computer);

            computer.Bind(new FakeSource { Next = Sample(0f, false) });
            computer.Tick(0.5f);

            Assert.AreEqual(1, seen);
        }

        [Test]
        public void NoManager_FallsBackToPrivateBus()
        {
            // No CockpitManager created in this test, so CockpitManager.Instance
            // is null and the bridge must still produce a usable bus.
            DiveComputer computer;
            DiveCockpitBridge bridge = NewBridge(out computer);

            Assert.IsNotNull(bridge.Bus);
            Assert.IsFalse(bridge.UsingSharedBus);

            int seen = 0;
            bridge.Bus.Subscribe(delegate { seen++; });

            computer.Bind(new FakeSource { Next = Sample(0f, false) });
            computer.Tick(0.5f);

            Assert.AreEqual(1, seen);
        }

        [Test]
        public void ManagerSharedBus_IsAdoptedAtAwake()
        {
            CockpitManager manager = CreateManager();

            DiveComputer computer;
            DiveCockpitBridge bridge = NewBridge(out computer);

            Assert.IsNotNull(bridge.Bus);
            Assert.AreSame(manager.Bus, bridge.Bus);
            Assert.IsTrue(bridge.UsingSharedBus);

            int seen = 0;
            manager.Bus.Subscribe(delegate { seen++; });

            computer.Bind(new FakeSource { Next = Sample(0f, false) });
            computer.Tick(0.5f);

            Assert.AreEqual(1, seen, "a subscriber on the manager bus must see the telegram");
        }

        [Test]
        public void ExplicitBindAfterAwake_OverridesManagerSharedBus()
        {
            CreateManager();

            DiveComputer computer;
            DiveCockpitBridge bridge = NewBridge(out computer);

            CockpitEventBus overrideBus = new CockpitEventBus();
            bridge.Bind(overrideBus);

            Assert.AreSame(overrideBus, bridge.Bus);
            Assert.IsFalse(bridge.UsingSharedBus);

            int onOverride = 0;
            overrideBus.Subscribe(delegate { onOverride++; });

            computer.Bind(new FakeSource { Next = Sample(0f, false) });
            computer.Tick(0.5f);

            Assert.AreEqual(1, onOverride, "an explicit bind must win over the shared bus");
        }
    }
}
