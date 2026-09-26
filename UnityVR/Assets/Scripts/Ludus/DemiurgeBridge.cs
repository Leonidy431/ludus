using System;
using System.Collections.Generic;
using UnityEngine;
using DeaconsPath.VR.Instruments.Phase6;

namespace DeaconsPath.VR.Ludus
{
    /// <summary>
    /// DemiurgeBridge — Adapter connecting Phase 5 DiveComputer to Phase 6 Demiurge Engine.
    ///
    /// Purpose: Map dive telemetry (depth, velocity, power) → Demiurge node state mutations.
    /// - DiveState enum values transition to DemiurgeNode status.
    /// - Real-world sensor inputs update node attributes (attributes → gameplay feedback).
    /// - Zero allocations; runs at same frequency as DiveComputer (0.1ms budget per frame).
    /// </summary>
    public class DemiurgeBridge : MonoBehaviour
    {
        [SerializeField] private Phase6DiveStateClassifier diveComputer;
        private DemiurgeSimulator demiurgeEngine;
        private string playerNodeId;

        // Cached references for per-frame updates
        private int playerNodeIndex = -1;
        private long lastUpdateMs;

        private void Start()
        {
            // Initialize Demiurge engine
            demiurgeEngine = new DemiurgeSimulator();
            playerNodeId = $"player-{SystemInfo.deviceUniqueIdentifier.GetHashCode():x8}";

            // Create player node in Demiurge
            var playerNode = DemiurgeNodeFactory.CreatePlayer(playerNodeId, "Local Player", "navigator");
            demiurgeEngine.AddNode(playerNode);

            lastUpdateMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        }

        private void Update()
        {
            if (diveComputer == null || demiurgeEngine == null)
                return;

            // Get current dive state from Phase 5 classifier
            var diveState = diveComputer.CurrentState;
            var sample = diveComputer.LastSample;

            // Map dive state → Demiurge node status
            UpdateNodeStatusFromDiveState(diveState);

            // Map telemetry → node attributes
            UpdateNodeAttributesFromTelemetry(sample);

            // Trigger Demiurge simulation tick (every 250ms = 4 Hz)
            var nowMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            if (nowMs - lastUpdateMs >= 250)
            {
                demiurgeEngine.Tick();
                lastUpdateMs = nowMs;
            }
        }

        // ====================================================================
        // State Mapping: Phase 5 → Phase 6
        // ====================================================================

        /// <summary>
        /// Map DiveState (Phase 5) to DemiurgeNode status (Phase 6).
        /// </summary>
        private void UpdateNodeStatusFromDiveState(DiveState diveState)
        {
            if (playerNodeIndex < 0)
                return;

            // Query player node from Demiurge
            var reachable = demiurgeEngine.PhaseTopologicalQuery(playerNodeId, maxDepth: 0);
            if (reachable.Count == 0)
                return;

            var playerNode = reachable[0];

            // Map Phase 5 state → Phase 6 status
            var newStatus = DiveStateToNodeStatus(diveState);
            if (playerNode.Status != newStatus)
            {
                playerNode.Status = newStatus;
                // Update in Demiurge (would persist to Firestore in production)
                Debug.Log($"[Bridge] DiveState {diveState} → NodeStatus {newStatus}");
            }
        }

        /// <summary>
        /// Phase 5 DiveState → Phase 6 NodeStatus mapping.
        /// </summary>
        private NodeStatus DiveStateToNodeStatus(DiveState diveState)
        {
            return diveState switch
            {
                DiveState.Unpowered => NodeStatus.DORMANT,           // No power = dormant
                DiveState.PowerFailing => NodeStatus.CORRUPTED,      // System failure = corruption
                DiveState.Surfaced => NodeStatus.DORMANT,            // On surface = inactive
                DiveState.SurfaceHold => NodeStatus.DORMANT,
                DiveState.Descending => NodeStatus.ACTIVE,           // In motion = active
                DiveState.EmergencyDescent => NodeStatus.ACTIVE,
                DiveState.Hovering => NodeStatus.ACTIVE,
                DiveState.HoveringDiagnostics => NodeStatus.ACTIVE,
                DiveState.HoveringTrimming => NodeStatus.ACTIVE,
                DiveState.Ascending => NodeStatus.ACTIVE,
                DiveState.EmergencyAscent => NodeStatus.ACTIVE,
                DiveState.BallastBleeding => NodeStatus.CORRUPTED,   // System malfunction = corruption
                DiveState.CriticalApproaching => NodeStatus.CORRUPTED, // Danger = corruption state
                DiveState.CriticalExceeding => NodeStatus.DESTROYED,  // Crush depth exceeded = destroyed
                DiveState.Beached => NodeStatus.DORMANT,
                DiveState.HullCompromised => NodeStatus.DESTROYED,   // Hull breach = terminal
                _ => NodeStatus.ACTIVE,
            };
        }

        // ====================================================================
        // Telemetry Mapping: Sensor Data → Node Attributes
        // ====================================================================

        /// <summary>
        /// Update Demiurge node attributes from dive telemetry.
        /// Maps physical sensor data to gameplay-relevant attributes.
        /// </summary>
        private void UpdateNodeAttributesFromTelemetry(DiveTelemetrySample sample)
        {
            if (playerNodeIndex < 0)
                return;

            var reachable = demiurgeEngine.PhaseTopologicalQuery(playerNodeId, maxDepth: 0);
            if (reachable.Count == 0)
                return;

            var playerNode = reachable[0];

            // Depth → Wisdom (deeper → more introspection/knowledge)
            // 0m = 10, 1000m = 20 (clamped)
            playerNode.Attributes.Wisdom = Mathf.Lerp(10f, 20f, Mathf.Clamp01(sample.DepthMeters / 1000f));

            // Power → Constitution (battery = health/endurance)
            // 0% = 1, 100% = 20
            playerNode.Attributes.Constitution = Mathf.Lerp(1f, 20f, sample.PowerPercentage / 100f);

            // Velocity → Dexterity (fast movement = agility)
            // |velocity| 0–2 m/s → 5–20 dexterity
            var absVelocity = Mathf.Abs(sample.VerticalVelocityMsec);
            playerNode.Attributes.Dexterity = Mathf.Lerp(5f, 20f, Mathf.Clamp01(absVelocity / 2f));

            // Pressure (implicit from depth) → Strength (pressure resistance)
            var pressureBar = 1.0f + (sample.DepthMeters / 10f);  // ~1 bar per 10m
            playerNode.Attributes.Strength = Mathf.Lerp(5f, 20f, Mathf.Clamp01(Mathf.Log(pressureBar) / 3f));

            // Temperature → Charisma (cold = less charismatic, warm = more)
            // 0°C = 5, 20°C = 15
            playerNode.Attributes.Charisma = Mathf.Lerp(5f, 15f, Mathf.Clamp01((sample.TemperatureCelsius + 10f) / 30f));

            // Ballast fill → Faith (buoyancy = spiritual equilibrium)
            // 0% = 5, 100% = 15
            playerNode.Attributes.Faith = Mathf.Lerp(5f, 15f, sample.BallastFill);

            // Water density (salinity indicator) → Erudition (knowledge of environment)
            // 1000 = fresh, 1030 = salt
            playerNode.Attributes.Erudition = Mathf.Lerp(5f, 15f, Mathf.Clamp01((sample.WaterDensityKgPerCubicMeter - 1000f) / 30f));

            // Resources: energy consumption
            var powerConsumptionRate = 0.1f;  // % per second
            playerNode.Resources.Gold = Mathf.Max(0f, playerNode.Resources.Gold - powerConsumptionRate);
            playerNode.Resources.Faith = Mathf.Max(0f, playerNode.Resources.Faith - powerConsumptionRate * 0.5f);
        }

        // ====================================================================
        // Public API: Query Demiurge state
        // ====================================================================

        /// <summary>
        /// Get current player node from Demiurge engine.
        /// </summary>
        public DemiurgeNode GetPlayerNode()
        {
            var reachable = demiurgeEngine.PhaseTopologicalQuery(playerNodeId, maxDepth: 0);
            return reachable.Count > 0 ? reachable[0] : default;
        }

        /// <summary>
        /// Get all nodes reachable from player (BFS, maxDepth=5).
        /// </summary>
        public List<DemiurgeNode> GetReachableNodes(int maxDepth = 5)
        {
            return demiurgeEngine.PhaseTopologicalQuery(playerNodeId, maxDepth);
        }

        /// <summary>
        /// Inject an edge (e.g., mentorship from NPC, corruption from environment).
        /// </summary>
        public void InjectEdge(DemiurgeEdge edge)
        {
            demiurgeEngine.AddEdge(edge);
        }

        /// <summary>
        /// Get cycle count (for debugging/telemetry).
        /// </summary>
        public int GetCycleCount() => demiurgeEngine.CycleCount;
    }
}
