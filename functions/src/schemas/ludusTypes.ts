/**
 * ludusTypes.ts — Firestore schema TypeScript interfaces for Ludus game
 *
 * Defines contract-first interfaces for all ludus_* collections.
 * All writes are validated against these types; compilation requires strict mode.
 */

import { Timestamp } from "firebase-admin/firestore";

// ============================================================================
// DEMIURGE ENGINE (Graph-based world sim)
// ============================================================================

export enum NodeType {
  PLAYER = "player",
  NPC = "npc",
  FACTION = "faction",
  CONCEPT = "concept",
  ARTIFACT = "artifact",
  LOCATION = "location",
}

export enum NodeStatus {
  ACTIVE = "active",
  DORMANT = "dormant",
  CORRUPTED = "corrupted",
  DESTROYED = "destroyed",
}

export enum EdgeType {
  INFLUENCE = "influence",
  MENTORSHIP = "mentorship",
  CONFLICT = "conflict",
  TRADE = "trade",
  ALLIANCE = "alliance",
  CORRUPTION = "corruption",
  REDEMPTION = "redemption",
  PROPHECY = "prophecy",
}

export interface AristotelianCausality {
  matter: string;   // Material substrate (e.g., "bronze", "flesh")
  form: string;     // Formal cause (e.g., "sword", "merchant")
  action: string;   // Efficient cause (e.g., "strike", "trade")
  goal: string;     // Final cause (e.g., "win battle", "redemption")
}

export interface DemiurgeNode {
  nodeId: string;
  nodeType: NodeType;
  createdAtMs: number;
  status: NodeStatus;
  attributes: Record<string, number>;   // {strength: 10, wisdom: 8, ...}
  resources: Record<string, number>;    // {gold: 500, faith: 75, ...}
  inboundEdges: string[];
  outboundEdges: string[];
  causality: AristotelianCausality;
  tags: string[];
  locale: string;
}

export interface DemiurgeEdge {
  edgeId: string;
  sourceNodeId: string;
  targetNodeId: string;
  createdAtMs: number;
  type: EdgeType;
  strength: number;  // 0.0 → 1.0
  causality: {
    action: string;
    pathos: string;     // "fear", "gratitude", "rage", etc.
    consequence: string;
  };
  activeFromMs: number;
  activeUntilMs?: number;
  cycleCount: number;
  tags: string[];
  logicalProof?: {
    questionHash: string;
    answerHash: string;
    verified: boolean;
  };
}

export interface TopoIndex {
  sourceNodeId: string;
  reachableNodeIds: string[];
  lastRecomputedAtMs: number;
}

// ============================================================================
// PLAYER & CHARACTER STATE
// ============================================================================

export enum PlayerRole {
  ANALYST = "analyst",      // Logic, patterns, data
  ENGINEER = "engineer",    // Building, fixing, systems
  TRANSLATOR = "translator", // Language, meaning, connection
}

export interface PlayerProfile {
  userId: string;           // Firebase Auth UID
  nodeId: string;           // Reference to DemiurgeNode
  displayName: string;
  role: PlayerRole;
  hashId: string;           // 0x... hex identity (cryptographic)
  createdAtMs: number;
  locale: string;           // "en-US", "es-ES", "sw-KE", etc.
  avatar?: {
    colorHex: string;       // e.g., "#FFD700"
    emoji: string;          // e.g., "🧙‍♂️"
  };
  stats: {
    level: number;
    experience: number;
    questsCompleted: number;
    knowledgeGatesUnlocked: number;
  };
}

export interface CharacterAttributes {
  playerId: string;
  // Six core stats (D&D-style)
  strength: number;      // 1–20
  dexterity: number;
  constitution: number;
  intelligence: number;
  wisdom: number;
  charisma: number;
  // Custom ludus attributes
  faith: number;         // 0–100 (spiritual alignment)
  cunning: number;       // 0–100 (deception / OSINT skill)
  erudition: number;     // 0–100 (knowledge / liturgy mastery)
  updatedAtMs: number;
}

// ============================================================================
// RESOURCES & INVENTORY
// ============================================================================

export interface ResourcePool {
  playerId: string;
  resourceType:
    | "gold"              // Currency (earned via trades, quests)
    | "faith"             // Spiritual capital (liturgy study)
    | "knowledge"         // Concept points (from Phenomenon Explorer)
    | "influence"         // Political sway (mentorship, alliances)
    | "artifacts";        // Item count (Proof-of-Knowledge badges)
  amount: number;
  updatedAtMs: number;
  source?: string;        // e.g., "quest:redeem-the-bishop", "trade:npc-merlin"
}

export interface Artifact {
  artifactId: string;
  name: string;
  description: string;
  nodeId: string;         // Reference to DemiurgeNode with type=ARTIFACT
  rarity: "common" | "uncommon" | "rare" | "legendary";
  effect?: {              // Optional: stat bonuses or special abilities
    attributeBonus?: Record<string, number>;
    resistances?: string[];
  };
  acquiredAtMs: number;
  source: string;         // e.g., "knowledge-gate-pass", "artifact-hunt"
}

// ============================================================================
// KAIROTIC TASKS (Gamified Real-Life Activities)
// ============================================================================

export enum TaskStatus {
  AVAILABLE = "available",
  ACTIVE = "active",
  COMPLETED = "completed",
  FAILED = "failed",
  EXPIRED = "expired",
}

export interface KairoticTask {
  taskId: string;
  nodeId: string;         // Associated NPC or location
  title: string;
  description: string;
  category:
    | "spiritual"         // Liturgy study, prayer
    | "interpersonal"     // Conversation, mentorship
    | "intellectual"      // Research, writing, teaching
    | "civic"             // Community service
    | "creative";         // Art, music, writing
  difficulty: 1 | 2 | 3 | 4 | 5;
  status: TaskStatus;
  assignedPlayerId?: string;
  requirements?: {
    minimumLevel?: number;
    prerequisiteTasks?: string[];
    knowledgeGateRequired?: string;
  };
  rewards: {
    experience: number;
    resources: Record<string, number>;  // {faith: 50, gold: 25}
  };
  deadline?: number;      // Unix timestamp; null = no deadline
  createdAtMs: number;
  completedAtMs?: number;
}

// ============================================================================
// KNOWLEDGE GATES (Proof-of-Knowledge Auth)
// ============================================================================

export enum GateStatus {
  LOCKED = "locked",
  UNLOCKED = "unlocked",
  MASTERED = "mastered",
}

export interface KnowledgeGate {
  gateId: string;
  nodeId: string;         // Associated concept node
  title: string;          // e.g., "Theology of the Incarnation"
  description: string;
  subject:
    | "liturgy"
    | "theology"
    | "hagiography"
    | "hymnography"
    | "canon-law"
    | "history"
    | "philosophy";
  tier: 1 | 2 | 3;        // 1=basic, 2=intermediate, 3=advanced
  question: string;       // The actual question (encrypted in transit)
  questionHash: string;   // SHA-256(question) for deduplication
  acceptableAnswers: {
    answerHash: string;   // SHA-256(answer)
    score: number;        // 0–100 (how correct)
  }[];
  createdAtMs: number;
  source: string;         // e.g., "ponomar:tropologion:sunday-of-orthodoxy"
}

export interface PlayerGateAttempt {
  attemptId: string;
  gateId: string;
  playerId: string;
  answerHash: string;     // SHA-256(their answer)
  score: number;          // 0–100
  passed: boolean;
  status: GateStatus;
  attemptedAtMs: number;
  feedback?: string;      // Optional: "Correct! The Incarnation unites..."
}

// ============================================================================
// FACTIONS & ALLIANCES
// ============================================================================

export interface Faction {
  factionId: string;
  nodeId: string;         // Reference to DemiurgeNode with type=FACTION
  name: string;
  description: string;
  founder: string;        // Player or NPC nodeId
  alignment: {
    axis1: "light" | "neutral" | "dark";      // Spiritual alignment
    axis2: "order" | "neutral" | "chaos";     // Social order
  };
  memberCount: number;
  reputation: Record<string, number>; // {playerId: 50, factionId: -20, ...}
  createdAtMs: number;
}

export interface FactionMembership {
  nodeId: string;         // Player or NPC
  factionId: string;
  role: "member" | "officer" | "leader";
  joinedAtMs: number;
  contributionPoints: number;
}

// ============================================================================
// MARKETPLACE (Phase 4)
// ============================================================================

export interface MarketListing {
  listingId: string;
  sellerId: string;       // Player nodeId
  itemType: "artifact" | "knowledge-badge" | "influence" | "service";
  itemId?: string;        // Reference to artifact/badge if applicable
  price: {
    gold?: number;
    faith?: number;
    knowledgePoints?: number;
  };
  quantity: number;
  listedAtMs: number;
  expiresAtMs?: number;   // Auto-delisting if not sold
  status: "active" | "sold" | "cancelled";
}

export interface MarketTransaction {
  transactionId: string;
  sellerId: string;
  buyerId: string;
  listingId: string;
  itemType: string;
  pricePerUnit: Record<string, number>;
  quantity: number;
  completedAtMs: number;
}

// ============================================================================
// TOPOLOGY INDEX (Denormalized for Fast Queries)
// ============================================================================

export interface TopologyCache {
  sourceNodeId: string;
  maxDepth: number;       // e.g., 5
  reachableNodeIds: string[];
  reachableEdgeIds: string[];
  lastRecomputedAtMs: number;
  invalidateAtMs?: number; // If newer mutations received, recompute
}

// ============================================================================
// SYSTEM METADATA
// ============================================================================

export interface CorpusMapping {
  // Links liturgical texts to game entities
  corpusId: string;       // e.g., "ponomar:tropologion:sunday-of-orthodoxy"
  relatedNodeIds: string[];  // Concept/artifact nodes this text maps to
  knowledgeGateIds: string[];
  createdAtMs: number;
  source: string;         // URL or Ponomar corpus identifier
}

export interface HealthCheck {
  checkId: string;
  timestamp: Timestamp;
  corpusAvailable: boolean;
  nodesCount: number;
  edgesCount: number;
  activePlayersCount: number;
  avgSimulationCycleMs: number;
}

// ============================================================================
// VALIDATION HELPERS
// ============================================================================

export function isValidNodeType(value: unknown): value is NodeType {
  return Object.values(NodeType).includes(value as NodeType);
}

export function isValidNodeStatus(value: unknown): value is NodeStatus {
  return Object.values(NodeStatus).includes(value as NodeStatus);
}

export function isValidEdgeType(value: unknown): value is EdgeType {
  return Object.values(EdgeType).includes(value as EdgeType);
}

export function validatePlayerProfile(p: unknown): p is PlayerProfile {
  if (!p || typeof p !== "object") return false;
  const profile = p as Record<string, unknown>;
  return (
    typeof profile.userId === "string" &&
    typeof profile.nodeId === "string" &&
    typeof profile.displayName === "string" &&
    Object.values(PlayerRole).includes(profile.role as PlayerRole) &&
    typeof profile.hashId === "string" &&
    typeof profile.createdAtMs === "number"
  );
}

export function validateDemiurgeNode(n: unknown): n is DemiurgeNode {
  if (!n || typeof n !== "object") return false;
  const node = n as Record<string, unknown>;
  return (
    typeof node.nodeId === "string" &&
    isValidNodeType(node.nodeType) &&
    typeof node.createdAtMs === "number" &&
    isValidNodeStatus(node.status) &&
    typeof node.attributes === "object" &&
    typeof node.resources === "object" &&
    Array.isArray(node.inboundEdges) &&
    Array.isArray(node.outboundEdges) &&
    typeof node.causality === "object" &&
    Array.isArray(node.tags)
  );
}
