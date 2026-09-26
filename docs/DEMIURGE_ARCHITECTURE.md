---
id: ludus-demiurge-engine
type: architecture
tags: [ludus, demiurge, graph-sim, game-loop, world-state]
related: [[docs/PHASE6_FSM_13STATES.md], [LUDUS_PROTOCOL.md], [CONSTITUTION.md]]
version: 1.0
status: active
---

# Ludus Demiurge Engine — Graph-Based World Simulator

**Scope:** Graph-based entity relationship engine for game world simulation. Nodes = entities (players, NPCs, factions, concepts). Edges = interactions, causality chains, and influence vectors.

**Contract:** Deterministic, O(1)–O(E) simulation per frame. Stateless queries + stateful node/edge mutations. No hidden side effects; all causality explicit.

---

## 1. Data Model

### 1.1 Node (Entity)

```typescript
interface DemiurgeNode {
  // Identity
  readonly nodeId: string;           // UUID v4 or "npc-merlin-001"
  readonly nodeType: NodeType;        // "player" | "npc" | "faction" | "concept" | "artifact" | "location"
  readonly createdAtMs: number;
  
  // Core State
  status: NodeStatus;                 // "active" | "dormant" | "corrupted" | "destroyed"
  attributes: Record<string, number>; // {strength: 10, wisdom: 8, ...}
  resources: Record<string, number>;  // {gold: 500, faith: 75, ...}
  
  // Relationships
  inboundEdges: string[];             // [edgeId1, edgeId2, ...] (incoming)
  outboundEdges: string[];            // [edgeId3, edgeId4, ...] (outgoing)
  
  // Causality Tracking (Aristotelian framework)
  causality: {
    matter: string;                   // Material substrate (e.g., "bronze", "flesh")
    form: string;                     // Formal cause (e.g., "sword", "merchant")
    action: string;                   // Efficient cause (e.g., "strike", "trade")
    goal: string;                     // Final cause (e.g., "win battle", "profit")
  };
  
  // Metadata
  tags: string[];                     // e.g., ["mortal", "aligned-light", "quest-giver"]
  locale: string;                     // Language context (e.g., "en-US")
}

enum NodeType {
  PLAYER = "player",
  NPC = "npc",
  FACTION = "faction",
  CONCEPT = "concept",          // Abstract entities (e.g., "Truth", "Mercy")
  ARTIFACT = "artifact",        // Items with agency (e.g., "Holy Grail")
  LOCATION = "location",        // Spatial nodes (e.g., "Church of the Holy Cross")
}

enum NodeStatus {
  ACTIVE = "active",            // Participating in causality chains
  DORMANT = "dormant",          // Exists but not engaged
  CORRUPTED = "corrupted",      // Hamartia active; needs resolution
  DESTROYED = "destroyed",      // Terminal; read-only archival
}
```

### 1.2 Edge (Interaction / Causality Chain)

```typescript
interface DemiurgeEdge {
  // Identity
  readonly edgeId: string;            // UUID v4
  readonly sourceNodeId: string;      // Efficient cause
  readonly targetNodeId: string;      // Patient / recipient
  readonly createdAtMs: number;
  
  // Interaction Type
  type: EdgeType;                     // "influence", "mentorship", "conflict", "trade", etc.
  strength: number;                   // 0.0 (weak) → 1.0 (absolute)
  
  // Causality Semantics (Aristotelian)
  causality: {
    action: string;                   // "teaches", "corrupts", "heals"
    pathos: string;                   // Emotional resonance ("fear", "gratitude", "rage")
    consequence: string;              // Expected outcome
  };
  
  // Temporal Dynamics
  activeFromMs: number;               // When edge takes effect
  activeUntilMs?: number;             // When edge expires (null = permanent)
  cycleCount: number;                 // How many game-loop cycles this edge was active
  
  // Metadata
  tags: string[];                     // e.g., ["blessed", "cursed", "one-time"]
  logicalProof?: {                    // Proof-of-Knowledge gate
    questionHash: string;             // SHA-256(question)
    answerHash: string;               // SHA-256(answer)
    verified: boolean;
  };
}

enum EdgeType {
  INFLUENCE = "influence",            // One entity sways another
  MENTORSHIP = "mentorship",          // Knowledge transfer
  CONFLICT = "conflict",              // Opposition / hostility
  TRADE = "trade",                    // Resource exchange
  ALLIANCE = "alliance",              // Mutual commitment
  CORRUPTION = "corruption",          // Hamartia introduction
  REDEMPTION = "redemption",          // Healing / resolution
  PROPHECY = "prophecy",              // Future causality (pre-declared outcome)
}
```

---

## 2. Simulation Loop (Per Frame)

**Frequency:** 4 Hz (0.25s tick) on primary game thread; independent of VR frame rate (90 FPS).

### 2.1 Phase A: Resolve Hard Constraints

```typescript
function phaseResolveConstraints(nodes: DemiurgeNode[], edges: DemiurgeEdge[]): {
  // Check node status transitions
  for (const node of nodes) {
    // Corrupted → Destroyed (if unchecked for 30+ cycles)
    if (node.status === NodeStatus.CORRUPTED && node.causality.goal === "none") {
      node.status = NodeStatus.DESTROYED;
      logger.info(`Node ${node.nodeId} corrupted beyond recovery`);
    }
    
    // Active → Dormant (if all edges expired)
    if (node.outboundEdges.length === 0 && node.inboundEdges.length === 0) {
      node.status = NodeStatus.DORMANT;
    }
  }
  
  // Expire dead edges
  const now = Date.now();
  for (const edge of edges) {
    if (edge.activeUntilMs && edge.activeUntilMs <= now) {
      edge.activeUntilMs = now;
      logger.debug(`Edge ${edge.edgeId} expired`);
    }
  }
}
```

### 2.2 Phase B: Propagate Causality

```typescript
function phasePropagation(nodes: DemiurgeNode[], edges: DemiurgeEdge[]): void {
  const now = Date.now();
  const activeEdges = edges.filter(e => e.activeFromMs <= now && (!e.activeUntilMs || e.activeUntilMs > now));
  
  // Depth-first traversal: each edge propagates effect to target node
  for (const edge of activeEdges) {
    const source = nodes.find(n => n.nodeId === edge.sourceNodeId);
    const target = nodes.find(n => n.nodeId === edge.targetNodeId);
    
    if (!source || !target) continue;
    
    // Apply causality: source (action) → target (patient)
    applyEdgeEffect(source, target, edge);
    edge.cycleCount++;
  }
}

function applyEdgeEffect(source: DemiurgeNode, target: DemiurgeNode, edge: DemiurgeEdge): void {
  // Dispatch on edge type
  switch (edge.type) {
    case EdgeType.MENTORSHIP:
      // Increase target's attributes based on source's expertise
      target.attributes["wisdom"] = Math.min(20, target.attributes["wisdom"] + edge.strength * 0.5);
      target.tags.push(`mentored-by-${source.nodeId}`);
      break;
      
    case EdgeType.TRADE:
      // Exchange resources (two-way)
      target.resources["gold"] = Math.max(0, target.resources["gold"] - 50 * edge.strength);
      source.resources["gold"] = Math.min(10000, source.resources["gold"] + 50 * edge.strength);
      break;
      
    case EdgeType.CORRUPTION:
      // Mark target as corrupted; introduce Hamartia
      if (target.status !== NodeStatus.CORRUPTED) {
        target.status = NodeStatus.CORRUPTED;
        target.causality.goal = "redemption";
        logger.warn(`Node ${target.nodeId} corrupted by ${source.nodeId}`);
      }
      break;
      
    case EdgeType.REDEMPTION:
      // Heal corruption
      if (target.status === NodeStatus.CORRUPTED) {
        target.status = NodeStatus.ACTIVE;
        target.causality.goal = source.causality.goal; // Inherit parent's goal
      }
      break;
      
    default:
      logger.debug(`Unknown edge type: ${edge.type}`);
  }
}
```

### 2.3 Phase C: Topological Query (Path Finding)

```typescript
function phaseTopologicalQuery(
  nodeId: string,
  nodes: DemiurgeNode[],
  edges: DemiurgeEdge[],
  maxDepth: number = 5
): DemiurgeNode[] {
  // BFS to find all reachable nodes from source
  const visited = new Set<string>();
  const queue: { nodeId: string; depth: number }[] = [{ nodeId, depth: 0 }];
  const reachable: DemiurgeNode[] = [];
  
  while (queue.length > 0) {
    const { nodeId: currentId, depth } = queue.shift()!;
    
    if (visited.has(currentId) || depth > maxDepth) continue;
    visited.add(currentId);
    
    const node = nodes.find(n => n.nodeId === currentId);
    if (node) reachable.push(node);
    
    // Follow outbound edges
    const outEdges = edges.filter(e => e.sourceNodeId === currentId);
    for (const edge of outEdges) {
      if (!visited.has(edge.targetNodeId)) {
        queue.push({ nodeId: edge.targetNodeId, depth: depth + 1 });
      }
    }
  }
  
  return reachable;
}
```

---

## 3. Aristotelian Causality Framework

Every action in the world has four causes (Aristotle's teaching):

```typescript
interface AristotelianCausality {
  // Material Cause: What is it made of?
  matter: string;
  // Formal Cause: What is its essence / definition?
  form: string;
  // Efficient Cause: What made it / set it in motion?
  action: string;
  // Final Cause: What is its purpose / telos?
  goal: string;
}

// Example: A sword
const sword: AristotelianCausality = {
  matter: "steel and leather",
  form: "pointed blade on hilt",
  action: "forged by a smith",
  goal: "to cut and defend",
};

// Example: A player on a quest
const player: AristotelianCausality = {
  matter: "flesh and spirit",
  form: "pilgrim seeking truth",
  action: "called by God and community",
  goal: "redemption and wisdom",
};
```

**Causality in Game Logic:**
- If a player's **goal** is "redemption", edges with type `CORRUPTION` automatically become subject to `REDEMPTION` counters.
- If an NPC's **form** is "corrupted bishop", edges it creates have type `CORRUPTION` by default.
- The **matter** determines physical constraints (e.g., a spirit cannot trade gold, only concepts).

---

## 4. Firestore Persistence

### 4.1 Collections

```typescript
// ludus_nodes (primary entity store)
interface FirestoreNode extends DemiurgeNode {
  // Firestore metadata
  __docId: string;                    // Document ID
  __updatedAt: FirebaseTimestamp;
}

// ludus_edges (interaction/causality store)
interface FirestoreEdge extends DemiurgeEdge {
  __docId: string;
  __updatedAt: FirebaseTimestamp;
  __version: number;                  // For optimistic locking
}

// ludus_topology_index (denormalized BFS index for fast queries)
interface TopoIndex {
  sourceNodeId: string;
  reachableNodeIds: string[];         // All nodes reachable from source (maxDepth=5)
  lastRecomputedAtMs: number;
}
```

### 4.2 Idempotent Mutations

```typescript
// All writes use atomic transactions + version checks
async function upsertEdge(edge: DemiurgeEdge, db: Firestore): Promise<void> {
  const docRef = db.collection("ludus_edges").doc(edge.edgeId);
  
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(docRef);
    
    // Conflict detection: only write if local version > remote version
    if (existing.exists && existing.data().__version >= (edge.__version || 0)) {
      throw new Error("Conflict: remote version is newer");
    }
    
    tx.set(docRef, { ...edge, __updatedAt: new Date(), __version: (edge.__version || 0) + 1 });
  });
}
```

---

## 5. Backward Compatibility (Phase 5 Integration)

Phase 5 DiveComputer states map to Demiurge concepts:

```typescript
// Phase 5 dive state → Demiurge node status
const diveStateToNodeStatus: Record<DiveState, NodeStatus> = {
  [DiveState.Surfaced]: NodeStatus.DORMANT,        // No active edges
  [DiveState.Descending]: NodeStatus.ACTIVE,       // Causal chain in progress
  [DiveState.Hovering]: NodeStatus.ACTIVE,         // Stable state
  [DiveState.Ascending]: NodeStatus.ACTIVE,
  [DiveState.CriticalApproaching]: NodeStatus.CORRUPTED,  // Hamartia: near crush depth
  [DiveState.HullCompromised]: NodeStatus.DESTROYED,      // Terminal state
};
```

---

## 6. Contract & Invariants

### 6.1 Hard Guarantees
- **Acyclic.** The graph must be DAG (directed acyclic graph). Cycles trigger a `GraphCycleError` during validation.
- **Causality Monotonic.** Once a node transitions `ACTIVE → CORRUPTED → DESTROYED`, it cannot revert.
- **Edge Existence.** All edges must have valid source & target nodes; orphaned edges are GC'd.

### 6.2 Performance Targets
- **Phase A (Constraints):** O(N) where N = node count. Budget: 1ms for 1000 nodes.
- **Phase B (Propagation):** O(E) where E = active edge count. Budget: 2ms for 5000 edges.
- **Phase C (Query):** O(V+E) BFS per query. Budget: 5ms per query (maxDepth=5).

**Total Loop:** 8ms per cycle (0.25s tick = 4 Hz). Headroom: 242ms until next game frame (90 FPS).

---

## 7. Roadmap

- **Phase 6a (current):** Graph data model + simulation loop (this document).
- **Phase 6b:** Predictive alarms: compute ETA-to-goal for each node + cascade effect analysis.
- **Phase 6c:** Sensor fusion: real depth/velocity/pressure inputs → node attribute updates.
- **Phase 7:** Multi-agent consensus: N players influence one world graph (merge strategies).
- **Phase 8:** Pilot override: manual state transitions + emergency procedures.

---

## 8. Success Criteria (Phase 6a)

- [ ] Graph data model compiles (TypeScript strict mode).
- [ ] Simulation loop runs 4 Hz headless (no scene dependencies).
- [ ] 10 EditMode tests: node creation, edge mutation, BFS query, status transitions.
- [ ] Backward-compat layer tested: DiveState → NodeStatus mappings pass.
- [ ] Firestore schema initialized with seed data (5 players, 20 NPCs, 50 edges).
- [ ] Profile: verify 8ms/cycle budget on Snapdragon XR2 emulation.
- [ ] Zero regressions on Phase 5 DiveComputer.

---

**Next Action:** Implement TypeScript interfaces + EditMode tests (Phase 6a-1, ETA 2026-09-25).

