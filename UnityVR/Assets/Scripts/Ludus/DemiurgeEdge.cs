using System;
using UnityEngine;

namespace DeaconsPath.VR.Ludus
{
    /// <summary>
    /// DemiurgeEdge — Causality chain linking two nodes.
    /// Edges represent interactions: mentorship, trade, conflict, corruption, redemption, etc.
    /// Includes versioning for optimistic locking against Firestore race conditions.
    /// </summary>
    [System.Serializable]
    public struct DemiurgeEdge
    {
        // ====================================================================
        // Identity
        // ====================================================================
        public string EdgeId;
        public string SourceNodeId;
        public string TargetNodeId;
        public long CreatedAtMs;

        // ====================================================================
        // Interaction Type & Strength
        // ====================================================================
        public EdgeType Type;
        public float Strength;             // 0.0 (weak) → 1.0 (absolute)

        // ====================================================================
        // Causality Semantics (Aristotelian)
        // ====================================================================
        [System.Serializable]
        public struct CausalityData
        {
            public string Action;          // "teaches", "corrupts", "trades", "heals"
            public string Pathos;          // Emotional resonance: "fear", "gratitude", "rage"
            public string Consequence;     // Expected outcome
        }
        public CausalityData Causality;

        // ====================================================================
        // Temporal Dynamics
        // ====================================================================
        public long ActiveFromMs;
        public long ActiveUntilMs;         // 0 = no expiry (permanent)
        public int CycleCount;             // Incremented each simulation cycle

        // ====================================================================
        // Versioning (for Firestore optimistic locking)
        // ====================================================================
        public int Version;                // Increment on mutation

        // ====================================================================
        // Metadata
        // ====================================================================
        public string[] Tags;              // e.g., ["blessed", "cursed"]

        // ====================================================================
        // Proof-of-Knowledge (optional gate validation)
        // ====================================================================
        [System.Serializable]
        public struct ProofData
        {
            public string QuestionHash;    // SHA-256(question)
            public string AnswerHash;      // SHA-256(correct answer)
            public bool Verified;
        }
        public ProofData? LogicalProof;    // Nullable

        // ====================================================================
        // Validation & Accessors
        // ====================================================================

        public bool IsActive(long nowMs)
        {
            return nowMs >= ActiveFromMs && (ActiveUntilMs == 0 || nowMs < ActiveUntilMs);
        }

        public bool IsExpired(long nowMs)
        {
            return ActiveUntilMs > 0 && nowMs >= ActiveUntilMs;
        }

        public bool IsValid()
        {
            return !string.IsNullOrEmpty(EdgeId) &&
                   !string.IsNullOrEmpty(SourceNodeId) &&
                   !string.IsNullOrEmpty(TargetNodeId) &&
                   CreatedAtMs > 0 &&
                   Strength >= 0f && Strength <= 1f;
        }

        public override string ToString()
        {
            return $"DemiurgeEdge(id={EdgeId}, {SourceNodeId}-{Type}->{TargetNodeId}, v{Version})";
        }
    }

    // ========================================================================
    // Enumerations
    // ========================================================================

    public enum EdgeType
    {
        INFLUENCE = 0,          // One entity sways another
        MENTORSHIP = 1,         // Knowledge transfer
        CONFLICT = 2,           // Opposition / hostility
        TRADE = 3,              // Resource exchange
        ALLIANCE = 4,           // Mutual commitment
        CORRUPTION = 5,         // Hamartia introduction
        REDEMPTION = 6,         // Healing / resolution
        PROPHECY = 7,           // Future causality (pre-declared outcome)
    }

    // ========================================================================
    // Helper: Static factory methods
    // ========================================================================

    public static class DemiurgeEdgeFactory
    {
        /// <summary>
        /// Create a mentorship edge (knowledge transfer).
        /// </summary>
        public static DemiurgeEdge CreateMentorship(
            string edgeId,
            string mentorNodeId,
            string studentNodeId,
            float strength = 0.8f)
        {
            return new DemiurgeEdge
            {
                EdgeId = edgeId,
                SourceNodeId = mentorNodeId,
                TargetNodeId = studentNodeId,
                CreatedAtMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                Type = EdgeType.MENTORSHIP,
                Strength = strength,
                Causality = new DemiurgeEdge.CausalityData
                {
                    Action = "teaches",
                    Pathos = "gratitude",
                    Consequence = "student gains wisdom",
                },
                ActiveFromMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                ActiveUntilMs = 0,  // Permanent
                CycleCount = 0,
                Version = 1,
                Tags = new[] { "educational" },
                LogicalProof = null,
            };
        }

        /// <summary>
        /// Create a trade edge (resource exchange).
        /// </summary>
        public static DemiurgeEdge CreateTrade(
            string edgeId,
            string sellerNodeId,
            string buyerNodeId,
            float gold = 50f,
            float durationMs = 60000f)  // 1 minute by default
        {
            var nowMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            return new DemiurgeEdge
            {
                EdgeId = edgeId,
                SourceNodeId = sellerNodeId,
                TargetNodeId = buyerNodeId,
                CreatedAtMs = nowMs,
                Type = EdgeType.TRADE,
                Strength = Mathf.Min(1f, gold / 100f),  // Normalized to strength
                Causality = new DemiurgeEdge.CausalityData
                {
                    Action = "exchanges resources",
                    Pathos = "mutual benefit",
                    Consequence = "resources transferred",
                },
                ActiveFromMs = nowMs,
                ActiveUntilMs = (long)(nowMs + durationMs),
                CycleCount = 0,
                Version = 1,
                Tags = new[] { "transactional" },
                LogicalProof = null,
            };
        }

        /// <summary>
        /// Create a corruption edge (introduce Hamartia).
        /// </summary>
        public static DemiurgeEdge CreateCorruption(
            string edgeId,
            string corruptorNodeId,
            string victimNodeId,
            string hamartia = "pride")
        {
            return new DemiurgeEdge
            {
                EdgeId = edgeId,
                SourceNodeId = corruptorNodeId,
                TargetNodeId = victimNodeId,
                CreatedAtMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                Type = EdgeType.CORRUPTION,
                Strength = 0.9f,  // High impact
                Causality = new DemiurgeEdge.CausalityData
                {
                    Action = "corrupts",
                    Pathos = "temptation",
                    Consequence = $"victim succumbs to {hamartia}",
                },
                ActiveFromMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                ActiveUntilMs = 0,  // Persists until redemption
                CycleCount = 0,
                Version = 1,
                Tags = new[] { "dangerous", "sin" },
                LogicalProof = null,
            };
        }

        /// <summary>
        /// Create a redemption edge (healing).
        /// </summary>
        public static DemiurgeEdge CreateRedemption(
            string edgeId,
            string redeomerNodeId,
            string victimNodeId)
        {
            return new DemiurgeEdge
            {
                EdgeId = edgeId,
                SourceNodeId = redeomerNodeId,
                TargetNodeId = victimNodeId,
                CreatedAtMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                Type = EdgeType.REDEMPTION,
                Strength = 0.95f,  // High priority
                Causality = new DemiurgeEdge.CausalityData
                {
                    Action = "redeems",
                    Pathos = "grace",
                    Consequence = "victim is healed and restored",
                },
                ActiveFromMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                ActiveUntilMs = 0,
                CycleCount = 0,
                Version = 1,
                Tags = new[] { "blessed", "healing" },
                LogicalProof = null,
            };
        }

        /// <summary>
        /// Create an influence edge.
        /// </summary>
        public static DemiurgeEdge CreateInfluence(
            string edgeId,
            string sourceNodeId,
            string targetNodeId,
            float strength = 0.6f)
        {
            return new DemiurgeEdge
            {
                EdgeId = edgeId,
                SourceNodeId = sourceNodeId,
                TargetNodeId = targetNodeId,
                CreatedAtMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                Type = EdgeType.INFLUENCE,
                Strength = strength,
                Causality = new DemiurgeEdge.CausalityData
                {
                    Action = "influences",
                    Pathos = "persuasion",
                    Consequence = "target's beliefs shift",
                },
                ActiveFromMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                ActiveUntilMs = 0,
                CycleCount = 0,
                Version = 1,
                Tags = new[] { "social" },
                LogicalProof = null,
            };
        }
    }
}
