using System;
using System.Collections.Generic;
using UnityEngine;

namespace DeaconsPath.VR.Ludus
{
    /// <summary>
    /// DemiurgeNode — Entity in the graph-based world simulation.
    /// Nodes = players, NPCs, factions, concepts, artifacts, locations.
    /// Allocation-free struct; backed by Firestore ludus_nodes collection.
    /// </summary>
    [System.Serializable]
    public struct DemiurgeNode
    {
        // ====================================================================
        // Identity
        // ====================================================================
        public string NodeId;           // UUID v4 or "npc-merlin-001"
        public NodeType Type;
        public long CreatedAtMs;

        // ====================================================================
        // State
        // ====================================================================
        public NodeStatus Status;

        // Attributes: strength, wisdom, dexterity, etc. (1–20 scale)
        [System.Serializable]
        public struct AttributesData
        {
            public float Strength;
            public float Dexterity;
            public float Constitution;
            public float Intelligence;
            public float Wisdom;
            public float Charisma;
            public float Faith;      // Spiritual alignment (0–100)
            public float Cunning;    // Deception/OSINT skill
            public float Erudition;  // Knowledge/liturgy mastery
        }
        public AttributesData Attributes;

        // Resources: gold, faith, knowledge, influence
        [System.Serializable]
        public struct ResourcesData
        {
            public float Gold;
            public float Faith;
            public float Knowledge;
            public float Influence;
        }
        public ResourcesData Resources;

        // ====================================================================
        // Relationships
        // ====================================================================
        public string[] InboundEdgeIds;    // Incoming edges (up to 32)
        public string[] OutboundEdgeIds;   // Outgoing edges (up to 32)

        // ====================================================================
        // Aristotelian Causality Framework
        // ====================================================================
        [System.Serializable]
        public struct CausalityData
        {
            public string Matter;      // Material substrate (e.g., "flesh", "bronze")
            public string Form;        // Essence/definition (e.g., "merchant", "priest")
            public string Action;      // Efficient cause (e.g., "teaches", "trades")
            public string Goal;        // Telos/final cause (e.g., "redemption", "profit")
        }
        public CausalityData Causality;

        // ====================================================================
        // Metadata
        // ====================================================================
        public string[] Tags;              // e.g., ["mortal", "aligned-light"]
        public string Locale;              // "en-US", "es-ES", "sw-KE"

        // ====================================================================
        // Validation
        // ====================================================================
        public bool IsValid()
        {
            return !string.IsNullOrEmpty(NodeId) &&
                   !string.IsNullOrEmpty(Causality.Form) &&
                   CreatedAtMs > 0;
        }

        public override string ToString()
        {
            return $"DemiurgeNode(id={NodeId}, type={Type}, status={Status}, form={Causality.Form})";
        }
    }

    // ========================================================================
    // Enumerations
    // ========================================================================

    public enum NodeType
    {
        PLAYER = 0,
        NPC = 1,
        FACTION = 2,
        CONCEPT = 3,
        ARTIFACT = 4,
        LOCATION = 5,
    }

    public enum NodeStatus
    {
        ACTIVE = 0,           // Participating in causality chains
        DORMANT = 1,          // Exists but not engaged
        CORRUPTED = 2,        // Hamartia active; awaiting redemption
        DESTROYED = 3,        // Terminal; read-only archival
    }

    // ========================================================================
    // Helper: Static factory methods
    // ========================================================================

    public static class DemiurgeNodeFactory
    {
        /// <summary>
        /// Create a new player node.
        /// </summary>
        public static DemiurgeNode CreatePlayer(string nodeId, string displayName, string role)
        {
            return new DemiurgeNode
            {
                NodeId = nodeId,
                Type = NodeType.PLAYER,
                CreatedAtMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                Status = NodeStatus.ACTIVE,
                Causality = new DemiurgeNode.CausalityData
                {
                    Matter = "flesh and spirit",
                    Form = role,  // "analyst", "engineer", "translator"
                    Action = "seeks truth",
                    Goal = "redemption and wisdom",
                },
                Tags = new[] { "mortal", "player" },
                Locale = "en-US",
                InboundEdgeIds = new string[0],
                OutboundEdgeIds = new string[0],
            };
        }

        /// <summary>
        /// Create a new NPC node.
        /// </summary>
        public static DemiurgeNode CreateNpc(string nodeId, string name, string role, NodeStatus initialStatus = NodeStatus.ACTIVE)
        {
            return new DemiurgeNode
            {
                NodeId = nodeId,
                Type = NodeType.NPC,
                CreatedAtMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                Status = initialStatus,
                Causality = new DemiurgeNode.CausalityData
                {
                    Matter = "flesh",
                    Form = role,  // "mentor", "merchant", "bishop"
                    Action = "guides",
                    Goal = "service",
                },
                Tags = new[] { "mortal", "npc" },
                Locale = "en-US",
                InboundEdgeIds = new string[0],
                OutboundEdgeIds = new string[0],
            };
        }

        /// <summary>
        /// Create a concept node (e.g., "Truth", "Mercy").
        /// </summary>
        public static DemiurgeNode CreateConcept(string nodeId, string name)
        {
            return new DemiurgeNode
            {
                NodeId = nodeId,
                Type = NodeType.CONCEPT,
                CreatedAtMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                Status = NodeStatus.ACTIVE,
                Causality = new DemiurgeNode.CausalityData
                {
                    Matter = "ideas",
                    Form = name,
                    Action = "illuminates",
                    Goal = "understanding",
                },
                Tags = new[] { "abstract", "concept" },
                Locale = "en-US",
                InboundEdgeIds = new string[0],
                OutboundEdgeIds = new string[0],
            };
        }
    }
}
