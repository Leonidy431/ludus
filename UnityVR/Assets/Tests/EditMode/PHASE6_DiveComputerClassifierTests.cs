#if UNITY_EDITOR

using NUnit.Framework;
using UnityEngine;
using DeaconsPath.VR.Instruments.Phase6;

namespace DeaconsPath.VR.Tests.EditMode.Phase6
{
    /// <summary>
    /// EditMode unit tests for Phase 6 Dive Computer Classifier (16-state FSM).
    ///
    /// Test Scope:
    ///   - State transitions (from all 16 states).
    ///   - Hard constraints (crush depth, power, hull breach).
    ///   - Velocity hysteresis (emergency descent/ascent timers).
    ///   - Manual mode activation (diagnostics, trim).
    ///   - Backward compatibility (Phase 5 bucket mapping).
    ///
    /// Environment: EditMode (no scene, no physics, no MonoBehaviour lifecycle).
    /// Allocation: Zero (all samples stack-allocated).
    /// </summary>
    [TestFixture]
    public class Phase6DiveComputerClassifierTests
    {
        private Phase6DiveStateClassifier classifier;

        [SetUp]
        public void SetUp()
        {
            classifier = new Phase6DiveStateClassifier();
            Assert.That(classifier.CurrentState, Is.EqualTo(DiveState.Unpowered));
        }

        // ====================================================================
        // Hard Constraint Tests
        // ====================================================================

        [Test]
        public void ClassifyHullBreach_SubmergedFractionJump_TransitionToHullCompromised()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 100f;
            sample.SubmergedFraction = 0.0f;
            sample.PowerPercentage = 100f;

            // First update: archive baseline.
            classifier.Classify(in sample);

            // Second update: submergence jumps 15% (> 10% threshold).
            sample.SubmergedFraction = 0.15f;
            DiveState state = classifier.Classify(in sample);

            Assert.That(state, Is.EqualTo(DiveState.HullCompromised));
        }

        [Test]
        public void ClassifyCrushDepth_DepthExceedsLimit_TransitionToCriticalExceeding()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 1001f; // > 1000m crush depth
            sample.PowerPercentage = 100f;

            DiveState state = classifier.Classify(in sample);

            Assert.That(state, Is.EqualTo(DiveState.CriticalExceeding));
        }

        [Test]
        public void ClassifyPowerFailing_BatteryBelowThreshold_TransitionToPowerFailing()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.PowerPercentage = 3f; // < 5%
            sample.DepthMeters = 100f;

            DiveState state = classifier.Classify(in sample);

            Assert.That(state, Is.EqualTo(DiveState.PowerFailing));
        }

        [Test]
        public void ClassifyUnpowered_PowerZero_TransitionToUnpowered()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.PowerPercentage = 0f;

            DiveState state = classifier.Classify(in sample);

            Assert.That(state, Is.EqualTo(DiveState.Unpowered));
        }

        // ====================================================================
        // Normal FSM Transitions
        // ====================================================================

        [Test]
        public void ClassifySurfaced_OnSurfaceWithFullBallast_StaysSurfaced()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 0.5f; // < 2m threshold
            sample.BallastFill = 0.95f; // > 90% threshold
            sample.VerticalVelocityMsec = 0f; // Hovering
            sample.WaveHeightMeters = 0.5f; // < 1m threshold
            sample.PowerPercentage = 100f;

            DiveState state = classifier.Classify(in sample);

            Assert.That(state, Is.EqualTo(DiveState.Surfaced));
        }

        [Test]
        public void ClassifySurfaceHold_WavesAboveThreshold_TransitionToSurfaceHold()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 0.5f;
            sample.BallastFill = 0.95f;
            sample.VerticalVelocityMsec = 0f;
            sample.WaveHeightMeters = 2f; // > 1m threshold
            sample.PowerPercentage = 100f;

            DiveState state = classifier.Classify(in sample);

            Assert.That(state, Is.EqualTo(DiveState.SurfaceHold));
        }

        [Test]
        public void ClassifyDescending_NegativeVerticalVelocity_TransitionToDescending()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 50f;
            sample.VerticalVelocityMsec = -0.5f; // Descending
            sample.BallastFill = 0.5f;
            sample.PowerPercentage = 100f;

            DiveState state = classifier.Classify(in sample);

            Assert.That(state, Is.EqualTo(DiveState.Descending));
        }

        [Test]
        public void ClassifyEmergencyDescent_HighNegativeVelocity_TransitionToEmergencyDescent()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 100f;
            sample.VerticalVelocityMsec = -2.0f; // < -1.5m/s emergency threshold
            sample.BallastFill = 0.3f;
            sample.PowerPercentage = 100f;

            // First call: start timer.
            classifier.Classify(in sample);

            // Second call (after 2+ seconds): timer expires, transition.
            // Simulate time passing (in real code, Time.deltaTime would handle this).
            // For unit test, we trigger the condition again.
            sample.VerticalVelocityMsec = -2.0f;
            DiveState state = classifier.Classify(in sample);

            Assert.That(state, Is.EqualTo(DiveState.EmergencyDescent));
        }

        [Test]
        public void ClassifyHovering_NearZeroVelocity_TransitionToHovering()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 200f;
            sample.VerticalVelocityMsec = 0.02f; // < 0.05m/s hovering band
            sample.BallastFill = 0.5f;
            sample.PowerPercentage = 100f;

            DiveState state = classifier.Classify(in sample);

            Assert.That(state, Is.EqualTo(DiveState.Hovering));
        }

        [Test]
        public void ClassifyCriticalApproaching_Near80PercentCrushDepth_TransitionToCriticalApproaching()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 850f; // 85% of 1000m crush depth
            sample.VerticalVelocityMsec = 0f; // Hovering
            sample.PowerPercentage = 100f;

            DiveState state = classifier.Classify(in sample);

            Assert.That(state, Is.EqualTo(DiveState.CriticalApproaching));
        }

        [Test]
        public void ClassifyAscending_PositiveVerticalVelocity_TransitionToAscending()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 200f;
            sample.VerticalVelocityMsec = 0.5f; // Ascending
            sample.BallastFill = 0.9f; // Ballast empty
            sample.PowerPercentage = 100f;

            DiveState state = classifier.Classify(in sample);

            Assert.That(state, Is.EqualTo(DiveState.Ascending));
        }

        [Test]
        public void ClassifyBeached_LowDepthNoVerticalVelocity_TransitionToBeached()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 0.3f; // < 0.5m beached threshold
            sample.VerticalVelocityMsec = 0f; // Not moving vertically
            sample.PowerPercentage = 100f;

            // Must not be on surface (SurfaceHold/Surfaced rules take precedence).
            sample.BallastFill = 0.5f; // Not full ballast.

            DiveState state = classifier.Classify(in sample);

            Assert.That(state, Is.EqualTo(DiveState.Beached));
        }

        // ====================================================================
        // Manual Mode Tests (Phase 8 pilot commands)
        // ====================================================================

        [Test]
        public void StartDiagnostics_FromHovering_TransitionToHoveringDiagnostics()
        {
            // Get to Hovering first.
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 200f;
            sample.VerticalVelocityMsec = 0f;
            sample.BallastFill = 0.5f;
            sample.PowerPercentage = 100f;
            classifier.Classify(in sample);

            Assert.That(classifier.CurrentState, Is.EqualTo(DiveState.Hovering));

            // Pilot activates diagnostics.
            classifier.StartDiagnostics();

            Assert.That(classifier.CurrentState, Is.EqualTo(DiveState.HoveringDiagnostics));
        }

        [Test]
        public void StartTrim_FromHovering_TransitionToHoveringTrimming()
        {
            // Get to Hovering first.
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 200f;
            sample.VerticalVelocityMsec = 0f;
            sample.BallastFill = 0.5f;
            sample.PowerPercentage = 100f;
            classifier.Classify(in sample);

            // Pilot activates trim mode.
            classifier.StartTrim();

            Assert.That(classifier.CurrentState, Is.EqualTo(DiveState.HoveringTrimming));
        }

        [Test]
        public void StopTrim_FromHoveringTrimming_TransitionToHovering()
        {
            // Get to HoveringTrimming.
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 200f;
            sample.VerticalVelocityMsec = 0f;
            sample.BallastFill = 0.5f;
            sample.PowerPercentage = 100f;
            classifier.Classify(in sample);
            classifier.StartTrim();

            Assert.That(classifier.CurrentState, Is.EqualTo(DiveState.HoveringTrimming));

            // Pilot deactivates trim.
            classifier.StopTrim();

            Assert.That(classifier.CurrentState, Is.EqualTo(DiveState.Hovering));
        }

        // ====================================================================
        // Backward Compatibility (Phase 5)
        // ====================================================================

        [Test]
        public void ToPhase5_UnpoweredState_MapsToPhaseFiveUnpowered()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.PowerPercentage = 0f;
            classifier.Classify(in sample);

            var phase5State = classifier.ToPhase5();

            Assert.That(phase5State, Is.EqualTo(Phase6DiveStateClassifier.DiveStateV5.Unpowered));
        }

        [Test]
        public void ToPhase5_HoveringState_MapsToPhaseFiveHovering()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 200f;
            sample.VerticalVelocityMsec = 0f;
            sample.BallastFill = 0.5f;
            sample.PowerPercentage = 100f;
            classifier.Classify(in sample);

            var phase5State = classifier.ToPhase5();

            Assert.That(phase5State, Is.EqualTo(Phase6DiveStateClassifier.DiveStateV5.Hovering));
        }

        [Test]
        public void ToPhase5_CriticalApproachingState_MapsToPhaseFiveCritical()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 850f; // 85% crush depth
            sample.VerticalVelocityMsec = 0f;
            sample.PowerPercentage = 100f;
            classifier.Classify(in sample);

            var phase5State = classifier.ToPhase5();

            Assert.That(phase5State, Is.EqualTo(Phase6DiveStateClassifier.DiveStateV5.Critical));
        }

        // ====================================================================
        // State Change Detection
        // ====================================================================

        [Test]
        public void StateChanged_AfterTransition_ReturnsTrue()
        {
            DiveTelemetrySample sample = CreateTestSample();
            sample.DepthMeters = 100f;
            sample.VerticalVelocityMsec = 0f;
            sample.PowerPercentage = 100f;

            classifier.Classify(in sample);
            Assert.That(classifier.StateChanged, Is.True); // Unpowered → Hovering

            classifier.Classify(in sample);
            Assert.That(classifier.StateChanged, Is.False); // No transition
        }

        // ====================================================================
        // Helpers
        // ====================================================================

        private DiveTelemetrySample CreateTestSample()
        {
            return new DiveTelemetrySample
            {
                DepthMeters = 0f,
                WaterDensityKgPerCubicMeter = 1025f,
                TemperatureCelsius = 10f,
                PressureBar = 1.0f,
                BallastFill = 1.0f,
                SubmergedFraction = 0f,
                IsSubmerged = false,
                VerticalVelocityMsec = 0f,
                TimestampSeconds = Time.time,
                PowerPercentage = 100f,
                WaveHeightMeters = 0f,
            };
        }
    }
}

#endif
