/**
 * idb-schema.ts — IndexedDB wrapper for Ludus offline caching
 *
 * Provides persistent client-side cache for Demiurge graph nodes and edges.
 * Enables offline-first gameplay with background sync to Firestore.
 */

import {
  DemiurgeNode,
  DemiurgeEdge,
  PlayerProfile,
  KnowledgeGate,
  PlayerGateAttempt,
} from "../../functions/src/schemas/ludusTypes";

// ============================================================================
// TYPES
// ============================================================================

export interface CacheMetadata {
  lastSyncMs: number;
  syncVersion: number;
  pendingMutations: PendingMutation[];
}

export interface PendingMutation {
  id: string;
  type: "node-update" | "edge-update" | "gate-attempt";
  target: DemiurgeNode | DemiurgeEdge | PlayerGateAttempt;
  enqueuedAtMs: number;
  synced: boolean;
}

export interface IDBNode extends DemiurgeNode {
  _localUpdateAtMs?: number;
  _isPending?: boolean;
}

export interface IDBEdge extends DemiurgeEdge {
  _localUpdateAtMs?: number;
  _isPending?: boolean;
}

// ============================================================================
// INDEXEDDB MANAGER
// ============================================================================

export class LudusOfflineCache {
  private db: IDBDatabase | null = null;
  private readonly dbName = "ludus-offline-v1";
  private readonly version = 1;

  private readonly storeNames = {
    NODES: "ludus_nodes",
    EDGES: "ludus_edges",
    PLAYER_PROFILE: "player_profile",
    KNOWLEDGE_GATES: "knowledge_gates",
    GATE_ATTEMPTS: "gate_attempts",
    PENDING_MUTATIONS: "pending_mutations",
    METADATA: "metadata",
  };

  /**
   * Initialize IndexedDB with schema (create object stores if needed)
   */
  async init(): Promise<void> {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.dbName, this.version);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        this.db = request.result;
        resolve();
      };

      request.onupgradeneeded = (event) => {
        const db = (event.target as IDBOpenDBRequest).result;

        // Nodes table (indexed by nodeId)
        if (!db.objectStoreNames.contains(this.storeNames.NODES)) {
          const nodeStore = db.createObjectStore(
            this.storeNames.NODES,
            { keyPath: "nodeId" }
          );
          nodeStore.createIndex("nodeType", "nodeType", { unique: false });
          nodeStore.createIndex("status", "status", { unique: false });
          nodeStore.createIndex("_localUpdateAtMs", "_localUpdateAtMs", {
            unique: false,
          });
        }

        // Edges table (indexed by edgeId)
        if (!db.objectStoreNames.contains(this.storeNames.EDGES)) {
          const edgeStore = db.createObjectStore(
            this.storeNames.EDGES,
            { keyPath: "edgeId" }
          );
          edgeStore.createIndex("sourceNodeId", "sourceNodeId", {
            unique: false,
          });
          edgeStore.createIndex("targetNodeId", "targetNodeId", {
            unique: false,
          });
          edgeStore.createIndex("type", "type", { unique: false });
        }

        // Player profile
        if (!db.objectStoreNames.contains(this.storeNames.PLAYER_PROFILE)) {
          db.createObjectStore(this.storeNames.PLAYER_PROFILE, {
            keyPath: "userId",
          });
        }

        // Knowledge gates
        if (!db.objectStoreNames.contains(this.storeNames.KNOWLEDGE_GATES)) {
          const gateStore = db.createObjectStore(
            this.storeNames.KNOWLEDGE_GATES,
            { keyPath: "gateId" }
          );
          gateStore.createIndex("subject", "subject", { unique: false });
          gateStore.createIndex("tier", "tier", { unique: false });
        }

        // Gate attempts
        if (!db.objectStoreNames.contains(this.storeNames.GATE_ATTEMPTS)) {
          const attemptStore = db.createObjectStore(
            this.storeNames.GATE_ATTEMPTS,
            { keyPath: "attemptId" }
          );
          attemptStore.createIndex("playerId", "playerId", { unique: false });
          attemptStore.createIndex("gateId", "gateId", { unique: false });
          attemptStore.createIndex("attemptedAtMs", "attemptedAtMs", {
            unique: false,
          });
        }

        // Pending mutations
        if (!db.objectStoreNames.contains(this.storeNames.PENDING_MUTATIONS)) {
          const mutationStore = db.createObjectStore(
            this.storeNames.PENDING_MUTATIONS,
            { keyPath: "id" }
          );
          mutationStore.createIndex("synced", "synced", { unique: false });
          mutationStore.createIndex("type", "type", { unique: false });
        }

        // Metadata (single doc)
        if (!db.objectStoreNames.contains(this.storeNames.METADATA)) {
          db.createObjectStore(this.storeNames.METADATA, { keyPath: "key" });
        }
      };
    });
  }

  // ========================================================================
  // NODES
  // ========================================================================

  async putNode(node: DemiurgeNode): Promise<void> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    const idbNode: IDBNode = {
      ...node,
      _localUpdateAtMs: Date.now(),
      _isPending: false,
    };

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.NODES],
        "readwrite"
      );
      const store = transaction.objectStore(this.storeNames.NODES);
      const request = store.put(idbNode);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve();
    });
  }

  async getNode(nodeId: string): Promise<IDBNode | undefined> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.NODES],
        "readonly"
      );
      const store = transaction.objectStore(this.storeNames.NODES);
      const request = store.get(nodeId);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result);
    });
  }

  async getAllNodes(): Promise<IDBNode[]> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.NODES],
        "readonly"
      );
      const store = transaction.objectStore(this.storeNames.NODES);
      const request = store.getAll();

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result);
    });
  }

  async deleteNode(nodeId: string): Promise<void> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.NODES],
        "readwrite"
      );
      const store = transaction.objectStore(this.storeNames.NODES);
      const request = store.delete(nodeId);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve();
    });
  }

  // ========================================================================
  // EDGES
  // ========================================================================

  async putEdge(edge: DemiurgeEdge): Promise<void> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    const idbEdge: IDBEdge = {
      ...edge,
      _localUpdateAtMs: Date.now(),
      _isPending: false,
    };

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.EDGES],
        "readwrite"
      );
      const store = transaction.objectStore(this.storeNames.EDGES);
      const request = store.put(idbEdge);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve();
    });
  }

  async getEdge(edgeId: string): Promise<IDBEdge | undefined> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.EDGES],
        "readonly"
      );
      const store = transaction.objectStore(this.storeNames.EDGES);
      const request = store.get(edgeId);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result);
    });
  }

  async getEdgesBySource(sourceNodeId: string): Promise<IDBEdge[]> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.EDGES],
        "readonly"
      );
      const store = transaction.objectStore(this.storeNames.EDGES);
      const index = store.index("sourceNodeId");
      const request = index.getAll(sourceNodeId);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result);
    });
  }

  async getAllEdges(): Promise<IDBEdge[]> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.EDGES],
        "readonly"
      );
      const store = transaction.objectStore(this.storeNames.EDGES);
      const request = store.getAll();

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result);
    });
  }

  // ========================================================================
  // PLAYER PROFILE
  // ========================================================================

  async putPlayerProfile(profile: PlayerProfile): Promise<void> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.PLAYER_PROFILE],
        "readwrite"
      );
      const store = transaction.objectStore(this.storeNames.PLAYER_PROFILE);
      const request = store.put(profile);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve();
    });
  }

  async getPlayerProfile(userId: string): Promise<PlayerProfile | undefined> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.PLAYER_PROFILE],
        "readonly"
      );
      const store = transaction.objectStore(this.storeNames.PLAYER_PROFILE);
      const request = store.get(userId);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result);
    });
  }

  // ========================================================================
  // KNOWLEDGE GATES
  // ========================================================================

  async putKnowledgeGate(gate: KnowledgeGate): Promise<void> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.KNOWLEDGE_GATES],
        "readwrite"
      );
      const store = transaction.objectStore(this.storeNames.KNOWLEDGE_GATES);
      const request = store.put(gate);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve();
    });
  }

  async getKnowledgeGate(gateId: string): Promise<KnowledgeGate | undefined> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.KNOWLEDGE_GATES],
        "readonly"
      );
      const store = transaction.objectStore(this.storeNames.KNOWLEDGE_GATES);
      const request = store.get(gateId);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result);
    });
  }

  // ========================================================================
  // GATE ATTEMPTS
  // ========================================================================

  async putGateAttempt(attempt: PlayerGateAttempt): Promise<void> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.GATE_ATTEMPTS],
        "readwrite"
      );
      const store = transaction.objectStore(this.storeNames.GATE_ATTEMPTS);
      const request = store.put(attempt);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve();
    });
  }

  async getGateAttemptsByPlayer(
    playerId: string
  ): Promise<PlayerGateAttempt[]> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.GATE_ATTEMPTS],
        "readonly"
      );
      const store = transaction.objectStore(this.storeNames.GATE_ATTEMPTS);
      const index = store.index("playerId");
      const request = index.getAll(playerId);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result);
    });
  }

  // ========================================================================
  // PENDING MUTATIONS
  // ========================================================================

  async enqueueMutation(mutation: PendingMutation): Promise<void> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.PENDING_MUTATIONS],
        "readwrite"
      );
      const store = transaction.objectStore(this.storeNames.PENDING_MUTATIONS);
      const request = store.put(mutation);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve();
    });
  }

  async getPendingMutations(): Promise<PendingMutation[]> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.PENDING_MUTATIONS],
        "readonly"
      );
      const store = transaction.objectStore(this.storeNames.PENDING_MUTATIONS);
      const index = store.index("synced");
      const request = index.getAll(false);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result);
    });
  }

  async markMutationSynced(mutationId: string): Promise<void> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.PENDING_MUTATIONS],
        "readwrite"
      );
      const store = transaction.objectStore(this.storeNames.PENDING_MUTATIONS);
      const getRequest = store.get(mutationId);

      getRequest.onsuccess = () => {
        const mutation = getRequest.result as PendingMutation;
        if (!mutation) return reject(new Error("Mutation not found"));

        mutation.synced = true;
        const putRequest = store.put(mutation);

        putRequest.onerror = () => reject(putRequest.error);
        putRequest.onsuccess = () => resolve();
      };

      getRequest.onerror = () => reject(getRequest.error);
    });
  }

  async deleteMutation(mutationId: string): Promise<void> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.PENDING_MUTATIONS],
        "readwrite"
      );
      const store = transaction.objectStore(this.storeNames.PENDING_MUTATIONS);
      const request = store.delete(mutationId);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve();
    });
  }

  // ========================================================================
  // METADATA
  // ========================================================================

  async getMetadata(): Promise<CacheMetadata | undefined> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.METADATA],
        "readonly"
      );
      const store = transaction.objectStore(this.storeNames.METADATA);
      const request = store.get("cache-metadata");

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result);
    });
  }

  async putMetadata(metadata: CacheMetadata): Promise<void> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    const withKey = { key: "cache-metadata", ...metadata };

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(
        [this.storeNames.METADATA],
        "readwrite"
      );
      const store = transaction.objectStore(this.storeNames.METADATA);
      const request = store.put(withKey);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve();
    });
  }

  // ========================================================================
  // BULK OPERATIONS
  // ========================================================================

  async clearAll(): Promise<void> {
    if (!this.db) throw new Error("IndexedDB not initialized");

    const storeNamesList = Object.values(this.storeNames);

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction(storeNamesList, "readwrite");

      storeNamesList.forEach((storeName) => {
        const store = transaction.objectStore(storeName);
        store.clear();
      });

      transaction.onerror = () => reject(transaction.error);
      transaction.oncomplete = () => resolve();
    });
  }
}

// Export singleton instance
export const ludusCache = new LudusOfflineCache();
