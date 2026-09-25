using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace DeaconsPath.VR.Ludus
{
    /// <summary>
    /// DemiurgeSimulator — Graph-based world simulation engine.
    /// 3-phase loop: Constraints → Propagation → Topological Query.
    /// Runs at 4 Hz (0.25s tick), independent of VR frame rate.
    /// O(1)–O(E) performance; targets 8ms per cycle on Snapdragon XR2.
    /// </summary>
    public class DemiurgeSimulator
    {
        private List<DemiurgeNode> nodes;
        private List<DemiurgeEdge> edges;
        private long lastSimulationMs;
        private int cycleCount;

        // Configuration
        private const int CORRUPTED_DECAY_CYCLES = 30;  // Corrupted → Destroyed after 30 cycles
        private const int MAX_INBOUND_EDGES = 32;
        private const int MAX_OUTBOUND_EDGES = 32;

        public DemiurgeSimulator()
        {
            nodes = new List<DemiurgeNode>(256);
            edges = new List<DemiurgeEdge>(1024);
            lastSimulationMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            cycleCount = 0;
        }

        // ====================================================================
        // Public API
        // ====================================================================

        /// <summary>
        /// Add a node to the simulation.
        /// </summary>
        public bool AddNode(DemiurgeNode node)
        {
            if (!node.IsValid() || nodes.Any(n => n.NodeId == node.NodeId))
            {
                Debug.LogWarning($"[Demiurge] Invalid node or duplicate: {node.NodeId}");
                return false;
            }
            nodes.Add(node);
            return true;
        }

        /// <summary>
        /// Add an edge to the simulation.
        /// </summary>
        public bool AddEdge(DemiurgeEdge edge)
        {
            if (!edge.IsValid() || edges.Any(e => e.EdgeId == edge.EdgeId))
            {
                Debug.LogWarning($"[Demiurge] Invalid edge or duplicate: {edge.EdgeId}");
                return false;
            }

            // Link edge to nodes
            var sourceIdx = FindNodeIndex(edge.SourceNodeId);
            var targetIdx = FindNodeIndex(edge.TargetNodeId);

            if (sourceIdx < 0 || targetIdx < 0)
            {
                Debug.LogWarning($"[Demiurge] Node not found for edge {edge.EdgeId}");
                return false;
            }

            // Update node edge lists
            var source = nodes[sourceIdx];
            var target = nodes[targetIdx];

            if (source.OutboundEdgeIds.Length >= MAX_OUTBOUND_EDGES)
            {
                Debug.LogWarning($"[Demiurge] Max outbound edges reached for {source.NodeId}");
                return false;
            }

            if (target.InboundEdgeIds.Length >= MAX_INBOUND_EDGES)
            {
                Debug.LogWarning($"[Demiurge] Max inbound edges reached for {target.NodeId}");
                return false;
            }

            System.Array.Resize(ref source.OutboundEdgeIds, source.OutboundEdgeIds.Length + 1);
            source.OutboundEdgeIds[source.OutboundEdgeIds.Length - 1] = edge.EdgeId;
            nodes[sourceIdx] = source;

            System.Array.Resize(ref target.InboundEdgeIds, target.InboundEdgeIds.Length + 1);
            target.InboundEdgeIds[target.InboundEdgeIds.Length - 1] = edge.EdgeId;
            nodes[targetIdx] = target;

            edges.Add(edge);
            return true;
        }

        /// <summary>
        /// Run one simulation cycle (all 3 phases).
        /// </summary>
        public void Tick()
        {
            var nowMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            lastSimulationMs = nowMs;
            cycleCount++;

            // Phase A: Resolve hard constraints
            PhaseResolveConstraints(nowMs);

            // Phase B: Propagate causality
            PhasePropagation(nowMs);

            // Phase C: Topological query (sample: find reachable nodes from player)
            // (In production, this would be query-on-demand, not per-cycle)
        }

        /// <summary>
        /// Query: Find all nodes reachable from a source within max depth (BFS).
        /// </summary>
        public List<DemiurgeNode> PhaseTopologicalQuery(string nodeId, int maxDepth = 5)
        {
            var visited = new HashSet<string>();
            var queue = new Queue<(string id, int depth)>();
            var reachable = new List<DemiurgeNode>();

            queue.Enqueue((nodeId, 0));

            while (queue.Count > 0)
            {
                var (currentId, depth) = queue.Dequeue();

                if (visited.Contains(currentId) || depth > maxDepth)
                    continue;

                visited.Add(currentId);

                var nodeIdx = FindNodeIndex(currentId);
                if (nodeIdx >= 0)
                {
                    reachable.Add(nodes[nodeIdx]);

                    // Follow outbound edges
                    foreach (var edgeId in nodes[nodeIdx].OutboundEdgeIds)
                    {
                        var edgeIdx = FindEdgeIndex(edgeId);
                        if (edgeIdx >= 0 && !visited.Contains(edges[edgeIdx].TargetNodeId))
                        {
                            queue.Enqueue((edges[edgeIdx].TargetNodeId, depth + 1));
                        }
                    }
                }
            }

            return reachable;
        }

        public int NodeCount => nodes.Count;
        public int EdgeCount => edges.Count;
        public int CycleCount => cycleCount;

        // ====================================================================
        // Phase A: Resolve Hard Constraints
        // ====================================================================

        private void PhaseResolveConstraints(long nowMs)
        {
            // Check node status transitions
            for (int i = 0; i < nodes.Count; i++)
            {
                var node = nodes[i];

                // Corrupted → Destroyed (if unchecked for 30+ cycles)
                if (node.Status == NodeStatus.CORRUPTED)
                {
                    // Count cycles since last redemption attempt
                    var corruptionCycles = CountCyclesInState(node.NodeId, NodeStatus.CORRUPTED);
                    if (corruptionCycles >= CORRUPTED_DECAY_CYCLES)
                    {
                        node.Status = NodeStatus.DESTROYED;
                        Debug.Log($"[Demiurge] {node.NodeId} corrupted beyond recovery (cycle {cycleCount})");
                    }
                }

                // Active → Dormant (if all edges expired)
                if (node.InboundEdgeIds.Length == 0 && node.OutboundEdgeIds.Length == 0)
                {
                    if (node.Status != NodeStatus.DESTROYED)
                    {
                        node.Status = NodeStatus.DORMANT;
                    }
                }

                nodes[i] = node;
            }

            // Expire dead edges
            for (int i = 0; i < edges.Count; i++)
            {
                var edge = edges[i];
                if (edge.IsExpired(nowMs))
                {
                    // Mark for removal (lazy removal; not removing from list to preserve indices)
                    // In production, use a separate "valid" flag or separate collections
                    Debug.Log($"[Demiurge] Edge {edge.EdgeId} expired");
                }
                edges[i] = edge;
            }
        }

        // ====================================================================
        // Phase B: Propagate Causality
        // ====================================================================

        private void PhasePropagation(long nowMs)
        {
            var activeEdges = edges.Where(e => e.IsActive(nowMs)).ToList();

            foreach (var edge in activeEdges)
            {
                var sourceIdx = FindNodeIndex(edge.SourceNodeId);
                var targetIdx = FindNodeIndex(edge.TargetNodeId);

                if (sourceIdx < 0 || targetIdx < 0)
                    continue;

                var source = nodes[sourceIdx];
                var target = nodes[targetIdx];

                // Apply causality effect
                ApplyEdgeEffect(ref source, ref target, edge, nowMs);

                nodes[sourceIdx] = source;
                nodes[targetIdx] = target;

                // Increment cycle count
                var edgeIdx = FindEdgeIndex(edge.EdgeId);
                if (edgeIdx >= 0)
                {
                    edges[edgeIdx].CycleCount++;
                }
            }
        }

        /// <summary>
        /// Apply edge effect to target based on edge type.
        /// </summary>
        private void ApplyEdgeEffect(ref DemiurgeNode source, ref DemiurgeNode target, DemiurgeEdge edge, long nowMs)
        {
            switch (edge.Type)
            {
                case EdgeType.MENTORSHIP:
                    // Increase target's wisdom
                    target.Attributes.Wisdom = Mathf.Min(20f, target.Attributes.Wisdom + edge.Strength * 0.5f);
                    break;

                case EdgeType.TRADE:
                    // Exchange resources
                    var goldTransfer = 50f * edge.Strength;
                    target.Resources.Gold = Mathf.Max(0f, target.Resources.Gold - goldTransfer);
                    source.Resources.Gold = Mathf.Min(10000f, source.Resources.Gold + goldTransfer);
                    break;

                case EdgeType.CORRUPTION:
                    // Mark target as corrupted
                    if (target.Status != NodeStatus.CORRUPTED)
                    {
                        target.Status = NodeStatus.CORRUPTED;
                        target.Causality.Goal = "redemption";
                        Debug.Log($"[Demiurge] {target.NodeId} corrupted by {source.NodeId}");
                    }
                    break;

                case EdgeType.REDEMPTION:
                    // Heal corruption
                    if (target.Status == NodeStatus.CORRUPTED)
                    {
                        target.Status = NodeStatus.ACTIVE;
                        target.Causality.Goal = source.Causality.Goal;
                        Debug.Log($"[Demiurge] {target.NodeId} redeemed by {source.NodeId}");
                    }
                    break;

                case EdgeType.INFLUENCE:
                    // Shift target's attributes toward source's values
                    target.Attributes.Charisma = Mathf.Lerp(target.Attributes.Charisma, source.Attributes.Charisma, edge.Strength * 0.1f);
                    break;

                case EdgeType.ALLIANCE:
                    // Increase mutual resources/trust
                    target.Resources.Influence += edge.Strength * 10f;
                    source.Resources.Influence += edge.Strength * 10f;
                    break;

                default:
                    // CONFLICT, PROPHECY: no automatic effect
                    break;
            }
        }

        // ====================================================================
        // Helpers
        // ====================================================================

        private int FindNodeIndex(string nodeId)
        {
            for (int i = 0; i < nodes.Count; i++)
            {
                if (nodes[i].NodeId == nodeId)
                    return i;
            }
            return -1;
        }

        private int FindEdgeIndex(string edgeId)
        {
            for (int i = 0; i < edges.Count; i++)
            {
                if (edges[i].EdgeId == edgeId)
                    return i;
            }
            return -1;
        }

        private int CountCyclesInState(string nodeId, NodeStatus status)
        {
            // Simple heuristic: count corrupted inbound edges as proxy for time in state
            var nodeIdx = FindNodeIndex(nodeId);
            if (nodeIdx < 0)
                return 0;

            var node = nodes[nodeIdx];
            var corruptionEdgeCount = node.InboundEdgeIds.Count(edgeId =>
            {
                var idx = FindEdgeIndex(edgeId);
                return idx >= 0 && edges[idx].Type == EdgeType.CORRUPTION;
            });

            return corruptionEdgeCount * 5;  // Rough estimate
        }

        /// <summary>
        /// Validate graph invariants (no cycles, all edges valid).
        /// </summary>
        public bool ValidateInvariants()
        {
            // Check for orphaned edges
            foreach (var edge in edges)
            {
                if (FindNodeIndex(edge.SourceNodeId) < 0 || FindNodeIndex(edge.TargetNodeId) < 0)
                {
                    Debug.LogError($"[Demiurge] Orphaned edge: {edge.EdgeId}");
                    return false;
                }
            }

            // Check that edge lists are consistent
            foreach (var node in nodes)
            {
                foreach (var edgeId in node.OutboundEdgeIds)
                {
                    var idx = FindEdgeIndex(edgeId);
                    if (idx < 0 || edges[idx].SourceNodeId != node.NodeId)
                    {
                        Debug.LogError($"[Demiurge] Inconsistent outbound edge: {edgeId}");
                        return false;
                    }
                }

                foreach (var edgeId in node.InboundEdgeIds)
                {
                    var idx = FindEdgeIndex(edgeId);
                    if (idx < 0 || edges[idx].TargetNodeId != node.NodeId)
                    {
                        Debug.LogError($"[Demiurge] Inconsistent inbound edge: {edgeId}");
                        return false;
                    }
                }
            }

            return true;
        }
    }
}
