/**
 * seedDemiurgeData.ts — Initialize Firestore with Demiurge graph seed data
 *
 * Initializes:
 * - 5 players (analyst, engineer, translator)
 * - 20 NPCs (mentor, merchant, priest, etc.)
 * - 50 edges (mentorship, trade, corruption, redemption chains)
 * - 10 knowledge gates (liturgy tiers 1-3)
 *
 * Run: node -r ts-node/register functions/src/scripts/seedDemiurgeData.ts
 */

import * as admin from "firebase-admin";
import * as crypto from "crypto";

// Initialize Firebase Admin
const serviceAccount = require("../../service-account.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

interface DemiurgeNode {
  nodeId: string;
  nodeType: string;
  createdAtMs: number;
  status: string;
  attributes: Record<string, number>;
  resources: Record<string, number>;
  inboundEdges: string[];
  outboundEdges: string[];
  causality: {
    matter: string;
    form: string;
    action: string;
    goal: string;
  };
  tags: string[];
  locale: string;
}

interface DemiurgeEdge {
  edgeId: string;
  sourceNodeId: string;
  targetNodeId: string;
  createdAtMs: number;
  type: string;
  strength: number;
  causality: {
    action: string;
    pathos: string;
    consequence: string;
  };
  activeFromMs: number;
  activeUntilMs: number;
  cycleCount: number;
  version: number;
  tags: string[];
  logicalProof?: {
    questionHash: string;
    answerHash: string;
    verified: boolean;
  };
}

function hashString(input: string): string {
  return crypto.createHash("sha256").update(input).digest("hex");
}

function generateId(prefix: string): string {
  return `${prefix}-${Math.random().toString(36).substr(2, 9)}`;
}

// ============================================================================
// Seed Data Generation
// ============================================================================

function createPlayer(id: string, name: string, role: string): DemiurgeNode {
  return {
    nodeId: id,
    nodeType: "player",
    createdAtMs: Date.now(),
    status: "active",
    attributes: {
      strength: Math.random() * 10 + 5,
      dexterity: Math.random() * 10 + 5,
      constitution: Math.random() * 10 + 5,
      intelligence: Math.random() * 10 + 10,
      wisdom: Math.random() * 10 + 10,
      charisma: Math.random() * 10 + 5,
      faith: Math.random() * 50 + 25,
      cunning: Math.random() * 50 + 25,
      erudition: Math.random() * 50 + 25,
    },
    resources: {
      gold: 100,
      faith: 50,
      knowledge: 0,
      influence: 0,
    },
    inboundEdges: [],
    outboundEdges: [],
    causality: {
      matter: "flesh and spirit",
      form: role,
      action: "seeks truth",
      goal: "redemption and wisdom",
    },
    tags: ["mortal", "player"],
    locale: "en-US",
  };
}

function createNpc(id: string, name: string, role: string): DemiurgeNode {
  return {
    nodeId: id,
    nodeType: "npc",
    createdAtMs: Date.now(),
    status: "active",
    attributes: {
      strength: Math.random() * 15 + 5,
      dexterity: Math.random() * 15 + 5,
      constitution: Math.random() * 15 + 5,
      intelligence: Math.random() * 15 + 5,
      wisdom: Math.random() * 15 + 8,
      charisma: Math.random() * 15 + 8,
      faith: Math.random() * 100,
      cunning: Math.random() * 100,
      erudition: Math.random() * 100,
    },
    resources: {
      gold: Math.random() * 500 + 100,
      faith: Math.random() * 100,
      knowledge: Math.random() * 100,
      influence: Math.random() * 50,
    },
    inboundEdges: [],
    outboundEdges: [],
    causality: {
      matter: "flesh",
      form: role,
      action: role === "mentor" ? "teaches" : role === "merchant" ? "trades" : "serves",
      goal: "service",
    },
    tags: ["mortal", "npc"],
    locale: "en-US",
  };
}

function createEdge(
  sourceNodeId: string,
  targetNodeId: string,
  type: string,
  strength: number = 0.8
): DemiurgeEdge {
  const nowMs = Date.now();
  return {
    edgeId: generateId("edge"),
    sourceNodeId,
    targetNodeId,
    createdAtMs: nowMs,
    type,
    strength,
    causality: {
      action: type === "mentorship" ? "teaches" : type === "trade" ? "exchanges" : type === "corruption" ? "corrupts" : "influences",
      pathos: type === "mentorship" ? "gratitude" : type === "trade" ? "benefit" : "temptation",
      consequence: "change occurs",
    },
    activeFromMs: nowMs,
    activeUntilMs: 0, // Permanent
    cycleCount: 0,
    version: 1,
    tags: type === "mentorship" ? ["educational"] : ["social"],
  };
}

function createKnowledgeGate(
  nodeId: string,
  subject: string,
  tier: number,
  question: string
): any {
  const correctAnswer = `The answer to: ${question}`;
  return {
    gateId: generateId("gate"),
    nodeId,
    title: `${subject} Gate (Tier ${tier})`,
    description: `Learn about ${subject}`,
    subject,
    tier,
    question,
    questionHash: hashString(question),
    acceptableAnswers: [
      {
        answerHash: hashString(correctAnswer),
        score: 100,
      },
    ],
    createdAtMs: Date.now(),
    source: `ponomar:${subject}:tier-${tier}`,
  };
}

// ============================================================================
// Main Seed Function
// ============================================================================

async function seedData() {
  console.log("[Seed] Starting Demiurge data initialization...");

  try {
    // 1. Create Players
    console.log("[Seed] Creating 5 players...");
    const players = [
      createPlayer("player-alice", "Alice", "analyst"),
      createPlayer("player-bob", "Bob", "engineer"),
      createPlayer("player-carol", "Carol", "translator"),
      createPlayer("player-dave", "Dave", "analyst"),
      createPlayer("player-eve", "Eve", "engineer"),
    ];

    // 2. Create NPCs
    console.log("[Seed] Creating 20 NPCs...");
    const npcs = [
      createNpc("npc-merlin", "Merlin", "mentor"),
      createNpc("npc-bishop-01", "Bishop Alexander", "priest"),
      createNpc("npc-bishop-02", "Bishop Gregory", "priest"),
      createNpc("npc-merchant-vladimir", "Vladimir the Merchant", "merchant"),
      createNpc("npc-merchant-sophia", "Sophia the Merchant", "merchant"),
      createNpc("npc-scribe", "Scribe Aleksandr", "scholar"),
      createNpc("npc-healer", "Maria the Healer", "healer"),
      createNpc("npc-demon-01", "Temptation Sprite", "tempter"),
      createNpc("npc-demon-02", "Pride Demon", "tempter"),
      createNpc("npc-faction-leader", "Elder Ioannes", "leader"),
      createNpc("npc-knight-01", "Sir Mikhail", "warrior"),
      createNpc("npc-knight-02", "Sir Sergei", "warrior"),
      createNpc("npc-artist", "Painter Icons", "artist"),
      createNpc("npc-musician", "Chorister Pavel", "musician"),
      createNpc("npc-gardener", "Brother Paisios", "gardener"),
      createNpc("npc-blacksmith", "Blacksmith Ivan", "craftsman"),
      createNpc("npc-scholar-01", "Professor Dostoevsky", "scholar"),
      createNpc("npc-scholar-02", "Professor Berdyaev", "scholar"),
      createNpc("npc-pilgrim", "Pilgrim Elias", "pilgrim"),
      createNpc("npc-hermit", "Hermit Sergius", "hermit"),
    ];

    const allNodes = [...players, ...npcs];

    // 3. Batch write nodes to Firestore
    console.log("[Seed] Writing nodes to Firestore...");
    const nodesBatch = db.batch();
    for (const node of allNodes) {
      nodesBatch.set(db.collection("ludus_nodes").doc(node.nodeId), node);
    }
    await nodesBatch.commit();
    console.log(`[Seed] ✓ Wrote ${allNodes.length} nodes`);

    // 4. Create Edges (causality chains)
    console.log("[Seed] Creating 50 edges...");
    const edges: DemiurgeEdge[] = [];

    // Mentorship chains
    edges.push(createEdge("npc-merlin", "player-alice", "mentorship", 0.9));
    edges.push(createEdge("npc-merlin", "player-bob", "mentorship", 0.85));
    edges.push(createEdge("npc-bishop-01", "player-carol", "mentorship", 0.8));

    // Trades
    edges.push(createEdge("npc-merchant-vladimir", "player-alice", "trade", 0.6));
    edges.push(createEdge("npc-merchant-sophia", "player-bob", "trade", 0.65));
    edges.push(createEdge("npc-merchant-vladimir", "npc-merchant-sophia", "trade", 0.7));

    // Corruption chains
    edges.push(createEdge("npc-demon-01", "player-dave", "corruption", 0.7));
    edges.push(createEdge("npc-demon-02", "player-eve", "corruption", 0.75));

    // Redemption arcs
    edges.push(createEdge("npc-healer", "player-dave", "redemption", 0.95));
    edges.push(createEdge("npc-bishop-02", "player-eve", "redemption", 0.9));

    // NPC relationships
    edges.push(createEdge("npc-bishop-01", "npc-bishop-02", "alliance", 0.85));
    edges.push(createEdge("npc-knight-01", "npc-knight-02", "alliance", 0.8));
    edges.push(createEdge("npc-scribe", "npc-scholar-01", "mentorship", 0.7));
    edges.push(createEdge("npc-scholar-02", "npc-pilgrim", "mentorship", 0.75));

    // Influence chains
    edges.push(createEdge("npc-faction-leader", "npc-knight-01", "influence", 0.8));
    edges.push(createEdge("npc-faction-leader", "npc-knight-02", "influence", 0.75));
    edges.push(createEdge("npc-merlin", "npc-faction-leader", "influence", 0.9));

    // More mentorship
    edges.push(createEdge("npc-artist", "player-carol", "mentorship", 0.7));
    edges.push(createEdge("npc-musician", "player-alice", "mentorship", 0.65));
    edges.push(createEdge("npc-hermit", "npc-pilgrim", "mentorship", 0.85));

    // Complex chains
    edges.push(createEdge("player-alice", "player-bob", "alliance", 0.8));
    edges.push(createEdge("player-carol", "player-dave", "alliance", 0.7));
    edges.push(createEdge("player-bob", "npc-merchant-vladimir", "trade", 0.6));
    edges.push(createEdge("npc-blacksmith", "player-alice", "trade", 0.55));

    // Add more edges to reach ~50
    for (let i = 0; i < 15; i++) {
      const source = allNodes[Math.floor(Math.random() * allNodes.length)];
      const target = allNodes[Math.floor(Math.random() * allNodes.length)];
      if (source.nodeId !== target.nodeId) {
        const types = ["influence", "trade", "mentorship"];
        const type = types[Math.floor(Math.random() * types.length)];
        edges.push(createEdge(source.nodeId, target.nodeId, type, Math.random() * 0.5 + 0.4));
      }
    }

    // 5. Batch write edges
    console.log("[Seed] Writing edges to Firestore...");
    const edgesBatch = db.batch();
    for (const edge of edges.slice(0, 50)) {
      edgesBatch.set(db.collection("ludus_edges").doc(edge.edgeId), edge);
    }
    await edgesBatch.commit();
    console.log(`[Seed] ✓ Wrote ${edges.slice(0, 50).length} edges`);

    // 6. Create Knowledge Gates
    console.log("[Seed] Creating 10 knowledge gates...");
    const gates = [
      createKnowledgeGate("npc-bishop-01", "liturgy", 1, "What is the purpose of the Divine Liturgy?"),
      createKnowledgeGate("npc-bishop-02", "theology", 1, "What is the Incarnation?"),
      createKnowledgeGate("npc-scribe", "hagiography", 1, "Who was Saint Nicholas?"),
      createKnowledgeGate("npc-scholar-01", "hymnography", 2, "What is the Kontakion?"),
      createKnowledgeGate("npc-scholar-02", "canon-law", 2, "What are the canons of the Church?"),
      createKnowledgeGate("npc-merlin", "theology", 2, "What is Theosis (Deification)?"),
      createKnowledgeGate("npc-hermit", "liturgy", 3, "Explain the theology of the Epiclesis."),
      createKnowledgeGate("npc-pilgrim", "history", 2, "What was the Great Schism of 1054?"),
      createKnowledgeGate("npc-artist", "hymnography", 1, "What is an icon?"),
      createKnowledgeGate("npc-musician", "hymnography", 2, "What are the eight tones of Byzantine music?"),
    ];

    const gatesBatch = db.batch();
    for (const gate of gates) {
      gatesBatch.set(db.collection("ludus_knowledge_gates").doc(gate.gateId), gate);
    }
    await gatesBatch.commit();
    console.log(`[Seed] ✓ Wrote ${gates.length} knowledge gates`);

    // 7. Validation: Check graph invariants
    console.log("[Seed] Validating graph...");
    for (const edge of edges.slice(0, 50)) {
      const sourceNode = allNodes.find((n) => n.nodeId === edge.sourceNodeId);
      const targetNode = allNodes.find((n) => n.nodeId === edge.targetNodeId);
      if (!sourceNode || !targetNode) {
        console.error(`[Seed] Invalid edge: ${edge.edgeId} references missing node`);
        process.exit(1);
      }
    }
    console.log("[Seed] ✓ Graph validation passed");

    // 8. Create health check
    console.log("[Seed] Creating health check record...");
    await db.collection("ludus_health_checks").add({
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      corpusAvailable: true,
      nodesCount: allNodes.length,
      edgesCount: edges.slice(0, 50).length,
      activePlayersCount: players.length,
      avgSimulationCycleMs: 0,
    });

    console.log("[Seed] ✅ Seed data initialized successfully!");
    console.log(`[Seed] Summary: ${allNodes.length} nodes, ${edges.slice(0, 50).length} edges, ${gates.length} gates`);

    process.exit(0);
  } catch (error) {
    console.error("[Seed] Error:", error);
    process.exit(1);
  }
}

// Run
seedData();
