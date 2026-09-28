/**
 * optimistic-mutations.ts — Client-side mutation queue for Ludus
 *
 * Implements optimistic UI updates with automatic reconciliation.
 * Mutations are queued locally and synced to Firestore on reconnection.
 */

import { ludusCache, PendingMutation } from "./idb-schema";
import {
  DemiurgeNode,
  DemiurgeEdge,
  PlayerGateAttempt,
} from "../../functions/src/schemas/ludusTypes";

// ============================================================================
// TYPES
// ============================================================================

export interface MutationResult {
  success: boolean;
  mutationId: string;
  isPending: boolean;
  error?: string;
}

export interface SyncResult {
  synced: number;
  failed: number;
  errors: string[];
}

// ============================================================================
// OPTIMISTIC MUTATION MANAGER
// ============================================================================

export class OptimisticMutationManager {
  private syncInProgress = false;
  private mutationCallbacks: Map<
    string,
    (mutation: PendingMutation) => void
  > = new Map();

  /**
   * Update a Demiurge node optimistically
   * Shows update immediately, syncs in background
   */
  async updateNode(
    nodeId: string,
    updates: Partial<DemiurgeNode>
  ): Promise<MutationResult> {
    const mutationId = this.generateId("node-update");

    try {
      // Get current node from cache
      const currentNode = await ludusCache.getNode(nodeId);
      if (!currentNode) {
        return {
          success: false,
          mutationId,
          isPending: false,
          error: "Node not found in cache",
        };
      }

      // Apply optimistic update locally
      const updatedNode: DemiurgeNode = {
        ...currentNode,
        ...updates,
        createdAtMs: currentNode.createdAtMs, // Preserve creation time
      };

      await ludusCache.putNode(updatedNode);

      // Enqueue mutation for sync
      const mutation: PendingMutation = {
        id: mutationId,
        type: "node-update",
        target: updatedNode,
        enqueuedAtMs: Date.now(),
        synced: false,
      };

      await ludusCache.enqueueMutation(mutation);

      // Notify listeners (UI can show pending indicator)
      this.notifyMutationListeners(mutation);

      return {
        success: true,
        mutationId,
        isPending: true,
      };
    } catch (error) {
      console.error("Optimistic node update failed:", error);
      return {
        success: false,
        mutationId,
        isPending: false,
        error: error instanceof Error ? error.message : "Unknown error",
      };
    }
  }

  /**
   * Update a Demiurge edge optimistically
   */
  async updateEdge(
    edgeId: string,
    updates: Partial<DemiurgeEdge>
  ): Promise<MutationResult> {
    const mutationId = this.generateId("edge-update");

    try {
      const currentEdge = await ludusCache.getEdge(edgeId);
      if (!currentEdge) {
        return {
          success: false,
          mutationId,
          isPending: false,
          error: "Edge not found in cache",
        };
      }

      const updatedEdge: DemiurgeEdge = {
        ...currentEdge,
        ...updates,
        createdAtMs: currentEdge.createdAtMs,
      };

      await ludusCache.putEdge(updatedEdge);

      const mutation: PendingMutation = {
        id: mutationId,
        type: "edge-update",
        target: updatedEdge,
        enqueuedAtMs: Date.now(),
        synced: false,
      };

      await ludusCache.enqueueMutation(mutation);
      this.notifyMutationListeners(mutation);

      return {
        success: true,
        mutationId,
        isPending: true,
      };
    } catch (error) {
      console.error("Optimistic edge update failed:", error);
      return {
        success: false,
        mutationId,
        isPending: false,
        error: error instanceof Error ? error.message : "Unknown error",
      };
    }
  }

  /**
   * Submit a knowledge gate attempt
   */
  async submitGateAttempt(
    attempt: PlayerGateAttempt
  ): Promise<MutationResult> {
    const mutationId = this.generateId("gate-attempt");

    try {
      await ludusCache.putGateAttempt(attempt);

      const mutation: PendingMutation = {
        id: mutationId,
        type: "gate-attempt",
        target: attempt,
        enqueuedAtMs: Date.now(),
        synced: false,
      };

      await ludusCache.enqueueMutation(mutation);
      this.notifyMutationListeners(mutation);

      return {
        success: true,
        mutationId,
        isPending: true,
      };
    } catch (error) {
      console.error("Gate attempt submission failed:", error);
      return {
        success: false,
        mutationId,
        isPending: false,
        error: error instanceof Error ? error.message : "Unknown error",
      };
    }
  }

  /**
   * Sync pending mutations to Firestore
   * Called automatically on reconnection or manually
   */
  async syncPendingMutations(
    firestoreClient: any
  ): Promise<SyncResult> {
    if (this.syncInProgress) {
      return { synced: 0, failed: 0, errors: ["Sync already in progress"] };
    }

    this.syncInProgress = true;
    const result: SyncResult = { synced: 0, failed: 0, errors: [] };

    try {
      const pendingMutations = await ludusCache.getPendingMutations();
      console.log(
        `[OptimisticSync] Syncing ${pendingMutations.length} mutations...`
      );

      for (const mutation of pendingMutations) {
        try {
          await this.syncSingleMutation(mutation, firestoreClient);
          await ludusCache.markMutationSynced(mutation.id);
          result.synced++;
        } catch (error) {
          result.failed++;
          result.errors.push(
            `${mutation.id}: ${error instanceof Error ? error.message : "Unknown error"}`
          );
          console.error(`Failed to sync mutation ${mutation.id}:`, error);
        }
      }

      console.log(
        `[OptimisticSync] Sync complete: ${result.synced} synced, ${result.failed} failed`
      );
    } finally {
      this.syncInProgress = false;
    }

    return result;
  }

  /**
   * Sync a single mutation to Firestore
   */
  private async syncSingleMutation(
    mutation: PendingMutation,
    firestoreClient: any
  ): Promise<void> {
    const { type, target } = mutation;

    if (type === "node-update") {
      const node = target as DemiurgeNode;
      await firestoreClient
        .collection("ludus_nodes")
        .doc(node.nodeId)
        .set(node, { merge: true });
    } else if (type === "edge-update") {
      const edge = target as DemiurgeEdge;
      await firestoreClient
        .collection("ludus_edges")
        .doc(edge.edgeId)
        .set(edge, { merge: true });
    } else if (type === "gate-attempt") {
      const attempt = target as PlayerGateAttempt;
      await firestoreClient
        .collection("ludus_gate_attempts")
        .doc(attempt.attemptId)
        .set(attempt);
    }
  }

  /**
   * Register a listener for mutation events (UI updates)
   */
  onMutation(
    callback: (mutation: PendingMutation) => void
  ): () => void {
    const callbackId = this.generateId("listener");
    this.mutationCallbacks.set(callbackId, callback);

    // Return unsubscribe function
    return () => {
      this.mutationCallbacks.delete(callbackId);
    };
  }

  /**
   * Notify all listeners of a new mutation
   */
  private notifyMutationListeners(mutation: PendingMutation): void {
    this.mutationCallbacks.forEach((callback) => {
      try {
        callback(mutation);
      } catch (error) {
        console.error("Mutation listener error:", error);
      }
    });
  }

  /**
   * Check if a mutation is still pending
   */
  async isMutationPending(mutationId: string): Promise<boolean> {
    const metadata = await ludusCache.getMetadata();
    if (!metadata) return false;

    const mutation = metadata.pendingMutations.find((m) => m.id === mutationId);
    return mutation ? !mutation.synced : false;
  }

  /**
   * Get all pending mutations
   */
  async getPendingMutations(): Promise<PendingMutation[]> {
    return ludusCache.getPendingMutations();
  }

  /**
   * Generate unique IDs for mutations
   */
  private generateId(prefix: string): string {
    return `${prefix}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }
}

// Export singleton instance
export const optimisticMutationManager = new OptimisticMutationManager();

// ============================================================================
// INTEGRATION WITH SERVICE WORKER
// ============================================================================

/**
 * Setup automatic sync on reconnection
 */
export function setupAutoSync(): void {
  window.addEventListener("online", async () => {
    console.log("[OptimisticSync] Network restored, initiating sync");

    if ("serviceWorker" in navigator && navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage({
        type: "REQUEST_SYNC",
      });
    }
  });

  // Listen for sync messages from Service Worker
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.addEventListener("message", (event) => {
      const { type } = event.data;

      if (type === "SYNC_START") {
        console.log("[OptimisticSync] Background sync started");
      }

      if (type === "SYNC_COMPLETE") {
        console.log("[OptimisticSync] Background sync completed");
        // Refresh UI to show synced state
        window.dispatchEvent(
          new CustomEvent("ludus-sync-complete", {
            detail: { timestamp: Date.now() },
          })
        );
      }
    });
  }
}

/**
 * Initialize offline support
 */
export async function initializeOfflineSupport(): Promise<void> {
  try {
    // Initialize IndexedDB cache
    await ludusCache.init();
    console.log("[OfflineSupport] IndexedDB initialized");

    // Register Service Worker
    if ("serviceWorker" in navigator) {
      const registration = await navigator.serviceWorker.register(
        "/ludus/sw.js",
        {
          scope: "/",
        }
      );
      console.log("[OfflineSupport] Service Worker registered", registration);

      // Check for updates periodically
      setInterval(() => {
        registration.update();
      }, 60000);
    }

    // Setup automatic sync on reconnection
    setupAutoSync();

    console.log("[OfflineSupport] Offline support fully initialized");
  } catch (error) {
    console.error("[OfflineSupport] Initialization failed:", error);
  }
}
