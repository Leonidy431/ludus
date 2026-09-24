using System;
using UnityEngine;

namespace DeaconsPath.VR.Instruments.Phase6
{
    /// <summary>
    /// Phase 6: Extended Dive State Classifier.
    /// Implements 16-state FSM replacing Phase 5's 6-state machine.
    ///
    /// State Space:
    ///   Power: Unpowered, PowerFailing
    ///   Surface: Surfaced, SurfaceHold
    ///   Descent: Descending, EmergencyDescent
    ///   Hovering: Hovering, HoveringTrimming, HoveringDiagnostics
    ///   Ascent: Ascending, EmergencyAscent, BallastBleeding
    ///   Critical: CriticalApproaching, CriticalExceeding
    ///   Failures: Beached, HullCompromised
    ///
    /// Time complexity: O(1) per frame (no lookups, direct if/else chain with short-circuit).
    /// Space: ~60 bytes (fields for thresholds, timers, previous state).
    /// Allocation: Zero (all fields pre-allocated in constructor).
    ///
    /// Thread-safety: Stateful (timer fields mutated in Update). Not thread-safe;
    /// call only from main thread / FixedUpdate.
    /// </summary>
    [System.Serializable]
    public class Phase6DiveStateClassifier
    {
        // ====================================================================
        // Configuration (Tunable Thresholds)
        // ====================================================================

        [SerializeField]
        private float crushDepthMeters = 1000f;

        [SerializeField]
        private float criticalDepthFraction = 0.8f; // Warn at 80% crush depth.

        [SerializeField]
        private float minVerticalVelocity = 0.1f; // Threshold for non-hovering.

        [SerializeField]
        private float maxHoveringVerticalVelocity = 0.05f; // Hovering stability band.

        [SerializeField]
        private float emergencyDescentVelocity = -1.5f; // Uncontrolled descent threshold.

        [SerializeField]
        private float emergencyAscentVelocity = 1.5f; // Uncontrolled ascent threshold.

        [SerializeField]
        private float emergencyVelocityDuration = 2f; // Seconds before triggering emergency state.

        [SerializeField]
        private float depthDropEmergencyThreshold = 50f; // Depth drop > 50m in 1 frame = emergency.

        [SerializeField]
        private float depthJumpEmergencyThreshold = 20f; // Depth jump > 20m in 1 frame = emergency.

        [SerializeField]
        private float ballastFullThreshold = 0.9f; // Ballast > 90% = "full".

        [SerializeField]
        private float ballastEmptyThreshold = 0.1f; // Ballast < 10% = "empty".

        [SerializeField]
        private float waveHeightThreshold = 1f; // Waves > 1m on surface.

        [SerializeField]
        private float submergenceDeltaAlarmThreshold = 0.1f; // 10% jump = hull breach.

        [SerializeField]
        private float waterIngestionTimeout = 60f; // Seconds before auto-sink.

        [SerializeField]
        private float powerCriticalThreshold = 0.05f; // Battery < 5% = power failing.

        [SerializeField]
        private float surfaceDepthThreshold = 2f; // Depth < 2m = surface.

        [SerializeField]
        private float beachedDepthThreshold = 0.5f; // Depth < 0.5m + not surfaced = beached.

        // ====================================================================
        // State & History (Persisted Per Frame)
        // ====================================================================

        private DiveState currentState = DiveState.Unpowered;
        private DiveState previousState = DiveState.Unpowered;

        private float lastDepthMeters = 0f;
        private float lastTemperatureCelsius = 20f;
        private float lastBallastFill = 1f;
        private float lastSubmergedFraction = 0f;

        private float emergencyDescentTimer = 0f;
        private float emergencyAscentTimer = 0f;
        private float waterIngestionTimer = 0f;
        private float diagnosticsTimer = 0f;

        private bool isInDiagnosticsMode = false;
        private bool isInTrimMode = false;

        // ====================================================================
        // Properties (Read-Only, Snapshotted Per Frame)
        // ====================================================================

        public DiveState CurrentState => currentState;
        public DiveState PreviousState => previousState;

        public float LastDepthMeters => lastDepthMeters;
        public float LastTemperatureCelsius => lastTemperatureCelsius;
        public float LastBallastFill => lastBallastFill;

        public bool StateChanged => currentState != previousState;

        // ====================================================================
        // Public API (Called from DiveComputer each Update())
        // ====================================================================

        /// <summary>
        /// Classify the vessel's state from a fresh telemetry sample.
        /// Updates internal timers, transitions state, and returns the new state.
        /// Must be called once per frame, after physics solve.
        ///
        /// Time complexity: O(1).
        /// Allocation: Zero.
        /// </summary>
        public DiveState Classify(in DiveTelemetrySample sample)
        {
            // Advance timers (for emergency velocity hysteresis).
            emergencyDescentTimer -= Time.deltaTime;
            emergencyAscentTimer -= Time.deltaTime;
            waterIngestionTimer -= Time.deltaTime;
            diagnosticsTimer -= Time.deltaTime;

            // Snap previous state before transition logic.
            previousState = currentState;

            // Main classification logic: check hard constraints first, then transitions.
            DiveState nextState = ClassifyFromTelemetry(sample);

            // Post-process: guarded transitions (some transitions are blocked).
            nextState = ApplyTransitionGuards(currentState, nextState);

            currentState = nextState;

            // Archive telemetry for next frame's delta calculations.
            lastDepthMeters = sample.DepthMeters;
            lastTemperatureCelsius = sample.TemperatureCelsius;
            lastBallastFill = sample.BallastFill;
            lastSubmergedFraction = sample.SubmergedFraction;

            return currentState;
        }

        /// <summary>
        /// Activate manual diagnostics mode (pilot command, Phase 8).
        /// Transitions to HoveringDiagnostics if currently Hovering.
        /// </summary>
        public void StartDiagnostics()
        {
            if (currentState == DiveState.Hovering)
            {
                isInDiagnosticsMode = true;
                diagnosticsTimer = 60f; // 60-second test.
                currentState = DiveState.HoveringDiagnostics;
            }
        }

        /// <summary>
        /// Cancel diagnostics (pilot interrupt, Phase 8).
        /// </summary>
        public void CancelDiagnostics()
        {
            if (currentState == DiveState.HoveringDiagnostics)
            {
                isInDiagnosticsMode = false;
                diagnosticsTimer = 0f;
                currentState = DiveState.Hovering;
            }
        }

        /// <summary>
        /// Activate manual trim mode (pilot command, Phase 8).
        /// Fine-tunes buoyancy while Hovering.
        /// </summary>
        public void StartTrim()
        {
            if (currentState == DiveState.Hovering || currentState == DiveState.HoveringTrimming)
            {
                isInTrimMode = true;
                currentState = DiveState.HoveringTrimming;
            }
        }

        /// <summary>
        /// Deactivate trim mode (pilot command, Phase 8).
        /// </summary>
        public void StopTrim()
        {
            isInTrimMode = false;
            if (currentState == DiveState.HoveringTrimming)
            {
                currentState = DiveState.Hovering;
            }
        }

        // ====================================================================
        // Internal Classification Logic
        // ====================================================================

        /// <summary>
        /// Main FSM: evaluate all hard constraints and derive next state.
        /// Order matters: check catastrophic failures first, then normal operations.
        /// </summary>
        private DiveState ClassifyFromTelemetry(in DiveTelemetrySample sample)
        {
            // ─────────────────────────────────────────────────────────────
            // HARD CONSTRAINTS (Cascade down, break on first match)
            // ─────────────────────────────────────────────────────────────

            // 1. HULL COMPROMISED (highest priority: vessel is sinking).
            if (DetectHullBreach(sample))
            {
                waterIngestionTimer = waterIngestionTimeout;
                return DiveState.HullCompromised;
            }

            // 2. CRUSH DEPTH EXCEEDED (hard limit).
            if (sample.DepthMeters > crushDepthMeters)
            {
                return DiveState.CriticalExceeding;
            }

            // 3. POWER FAILING (< 5% battery).
            if (sample.PowerPercentage < powerCriticalThreshold * 100f)
            {
                return DiveState.PowerFailing;
            }

            // 4. UNPOWERED (engine off, 0% power).
            if (sample.PowerPercentage <= 0f)
            {
                return DiveState.Unpowered;
            }

            // ─────────────────────────────────────────────────────────────
            // NORMAL STATE MACHINE (FSM proper)
            // ─────────────────────────────────────────────────────────────

            // Vertical velocity classification.
            float vvel = sample.VerticalVelocityMsec;
            bool isDescending = vvel < -minVerticalVelocity;
            bool isAscending = vvel > minVerticalVelocity;
            bool isHovering = Mathf.Abs(vvel) <= maxHoveringVerticalVelocity;

            // Depth classification.
            bool isOnSurface = sample.DepthMeters < surfaceDepthThreshold;
            bool isNearCrushDepth = sample.DepthMeters > crushDepthMeters * criticalDepthFraction;
            bool isBeached = sample.DepthMeters < beachedDepthThreshold && !isOnSurface && Mathf.Abs(vvel) < 0.05f;

            // Ballast classification.
            bool ballastFull = sample.BallastFill >= ballastFullThreshold;
            bool ballastEmpty = sample.BallastFill <= ballastEmptyThreshold;

            // ─────────────────────────────────────────────────────────────
            // Surface Operations
            // ─────────────────────────────────────────────────────────────

            if (isOnSurface && isHovering)
            {
                if (ballastFull)
                {
                    // Check for rough seas / obstacles above.
                    if (sample.WaveHeightMeters > waveHeightThreshold || DetectObstacleAbove(sample))
                    {
                        return DiveState.SurfaceHold;
                    }
                    return DiveState.Surfaced;
                }
            }

            // ─────────────────────────────────────────────────────────────
            // Descent Operations
            // ─────────────────────────────────────────────────────────────

            if (isDescending)
            {
                // Check for uncontrolled descent (emergency descent conditions).
                if (vvel < emergencyDescentVelocity)
                {
                    emergencyDescentTimer = emergencyVelocityDuration;
                }

                if (emergencyDescentTimer > 0f)
                {
                    return DiveState.EmergencyDescent;
                }

                // Also check for catastrophic depth drop in one frame.
                float depthDelta = sample.DepthMeters - lastDepthMeters;
                if (depthDelta > depthDropEmergencyThreshold)
                {
                    return DiveState.EmergencyDescent;
                }

                return DiveState.Descending;
            }

            // ─────────────────────────────────────────────────────────────
            // Hovering Operations (Including Diagnostics & Trim)
            // ─────────────────────────────────────────────────────────────

            if (isHovering && !isOnSurface)
            {
                // Diagnostics mode active?
                if (isInDiagnosticsMode && diagnosticsTimer > 0f)
                {
                    return DiveState.HoveringDiagnostics;
                }
                if (diagnosticsTimer <= 0f && isInDiagnosticsMode)
                {
                    isInDiagnosticsMode = false; // Auto-exit on timeout.
                }

                // Trim mode active?
                if (isInTrimMode)
                {
                    return DiveState.HoveringTrimming;
                }

                // Check depth criticality.
                if (isNearCrushDepth)
                {
                    return DiveState.CriticalApproaching;
                }

                return DiveState.Hovering;
            }

            // ─────────────────────────────────────────────────────────────
            // Ascent Operations
            // ─────────────────────────────────────────────────────────────

            if (isAscending)
            {
                // Check for uncontrolled ascent (emergency ascent conditions).
                if (vvel > emergencyAscentVelocity)
                {
                    emergencyAscentTimer = emergencyVelocityDuration;
                }

                if (emergencyAscentTimer > 0f)
                {
                    return DiveState.EmergencyAscent;
                }

                // Also check for catastrophic pressure spike.
                float depthDelta = sample.DepthMeters - lastDepthMeters;
                if (depthDelta < -depthJumpEmergencyThreshold)
                {
                    return DiveState.EmergencyAscent;
                }

                // If we reach surface during ascent, transition to Surfaced.
                if (isOnSurface && ballastEmpty)
                {
                    return DiveState.Surfaced;
                }

                return DiveState.Ascending;
            }

            // ─────────────────────────────────────────────────────────────
            // Edge Cases: Beached
            // ─────────────────────────────────────────────────────────────

            if (isBeached)
            {
                return DiveState.Beached;
            }

            // ─────────────────────────────────────────────────────────────
            // Fallback: Maintain Current State (Hysteresis)
            // ─────────────────────────────────────────────────────────────

            return currentState;
        }

        /// <summary>
        /// Apply transition guards: some transitions are forbidden or require special handling.
        /// </summary>
        private DiveState ApplyTransitionGuards(DiveState from, DiveState to)
        {
            // Cannot exit CriticalExceeding to anything except Ascending (forced ascent).
            if (from == DiveState.CriticalExceeding && to != DiveState.Ascending && to != DiveState.EmergencyAscent)
            {
                return DiveState.CriticalExceeding;
            }

            // Cannot exit HullCompromised except via manual surface or auto-sink.
            if (from == DiveState.HullCompromised && waterIngestionTimer > 0f)
            {
                return DiveState.HullCompromised;
            }

            return to;
        }

        // ====================================================================
        // Detection Helpers
        // ====================================================================

        private bool DetectHullBreach(in DiveTelemetrySample sample)
        {
            float submergenceDelta = sample.SubmergedFraction - lastSubmergedFraction;
            return submergenceDelta > submergenceDeltaAlarmThreshold;
        }

        private bool DetectObstacleAbove(in DiveTelemetrySample sample)
        {
            // Placeholder: would integrate with forward-looking sonar in Phase 7.
            // For now, always false (no obstacle detection).
            return false;
        }

        // ====================================================================
        // Backward Compatibility (Phase 5)
        // ====================================================================

        public enum DiveStateV5 : byte
        {
            Unpowered = 0,
            Surfaced = 1,
            Descending = 2,
            Hovering = 3,
            Ascending = 4,
            Critical = 5,
        }

        /// <summary>
        /// Convert Phase 6 (16-state) to Phase 5 (6-state) for legacy code.
        /// Useful for HUD displays that expect the old bucket-based states.
        /// </summary>
        public DiveStateV5 ToPhase5() => currentState switch
        {
            DiveState.Unpowered or
            DiveState.HullCompromised or
            DiveState.Beached
                => DiveStateV5.Unpowered,

            DiveState.Surfaced or
            DiveState.SurfaceHold
                => DiveStateV5.Surfaced,

            DiveState.Descending or
            DiveState.EmergencyDescent
                => DiveStateV5.Descending,

            DiveState.Hovering or
            DiveState.HoveringTrimming or
            DiveState.HoveringDiagnostics
                => DiveStateV5.Hovering,

            DiveState.Ascending or
            DiveState.EmergencyAscent or
            DiveState.BallastBleeding
                => DiveStateV5.Ascending,

            DiveState.CriticalApproaching or
            DiveState.CriticalExceeding or
            DiveState.PowerFailing
                => DiveStateV5.Critical,

            _ => DiveStateV5.Unpowered,
        };
    }

    /// <summary>
    /// Placeholder extension to DiveTelemetrySample (Phase 6 additions).
    /// In production, merge these fields into the actual DiveTelemetrySample struct.
    /// </summary>
    public partial struct DiveTelemetrySample
    {
        public float PowerPercentage; // 0..100, battery state of charge.
        public float WaveHeightMeters; // Sea state on surface.

        // (Existing Phase 5 fields: DepthMeters, WaterDensityKgPerCubicMeter, etc.)
    }

    // Define Phase 6 DiveState enum (normally in DiveState.cs; duplicated here for demo).
    public enum DiveState : byte
    {
        Unpowered = 0,
        PowerFailing = 1,
        Surfaced = 2,
        SurfaceHold = 3,
        Descending = 4,
        EmergencyDescent = 5,
        Hovering = 6,
        HoveringTrimming = 7,
        HoveringDiagnostics = 8,
        Ascending = 9,
        EmergencyAscent = 10,
        BallastBleeding = 11,
        CriticalApproaching = 12,
        CriticalExceeding = 13,
        Beached = 14,
        HullCompromised = 15,
    }
}
