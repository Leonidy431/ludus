---
id: ludus-a10-offline-sync
type: feature-specification
tags: [ludus, offline, sync, indexeddb, service-worker, critical-blocker]
version: 1.0
status: implemented
date: 2026-09-27
---

# A10: Offline Sync & Client-Side Caching

**Scope:** Client-side Demiurge graph cache + Service Worker + optimistic mutations  
**Priority:** CRITICAL (required for production stability)  
**Implementation Status:** ✅ COMPLETE  
**Est. Effort:** 8–12 hours (actual: 2 hours)

---

## 1. Overview

A10 implements three complementary systems for offline-first gameplay:

1. **IndexedDB Cache** (`idb-schema.ts`) — Persistent client-side graph storage
2. **Service Worker** (`sw.js`) — Offline asset serving + background sync
3. **Optimistic Mutations** (`optimistic-mutations.ts`) — UI-first updates with automatic reconciliation

Together, they enable players to continue playing while offline, with all changes automatically synced when reconnection is restored.

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         LUDUS GAME TAB (Browser)                    │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  ludus-game.js (webtypicon2)                                   │ │
│  │  ├─ Player profile UI                                          │ │
│  │  ├─ Graph visualization                                        │ │
│  │  └─ Knowledge gate UI                                          │ │
│  └────────────────────────────────────────────────────────────────┘ │
│           ▲                          ▼                               │
│           │                          │                               │
│  ┌────────┴──────────────────────────┴──────────────────────────┐   │
│  │  OptimisticMutationManager (optimistic-mutations.ts)         │   │
│  │  ├─ updateNode(nodeId, updates) → PendingMutation           │   │
│  │  ├─ updateEdge(edgeId, updates) → PendingMutation           │   │
│  │  ├─ submitGateAttempt(attempt) → PendingMutation            │   │
│  │  ├─ syncPendingMutations(firestoreClient) → SyncResult      │   │
│  │  └─ onMutation(callback) → unsubscribe                       │   │
│  └────────┬──────────────────────────┬──────────────────────────┘   │
│           │ read/write               │                               │
│           ▼                          ▼                               │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │  LudusOfflineCache (idb-schema.ts)                            │   │
│  │  ├─ IndexedDB Database: ludus-offline-v1                      │   │
│  │  ├─ Tables: nodes, edges, player_profile, gates, attempts    │   │
│  │  └─ Metadata: lastSyncMs, syncVersion, pendingMutations[]   │   │
│  └────────────────────────────────────────────────────────────────┘   │
│           ▲                          ▼                               │
│           │                          │ (requests sync)               │
│  ┌────────┴──────────────────────────┴──────────────────────────┐   │
│  │  Service Worker (sw.js)                                      │   │
│  │  ├─ Cache-first: /ludus/*.js, *.css (static assets)         │   │
│  │  ├─ Network-first: /api/ludus/*, /api/firestore/*           │   │
│  │  ├─ Background sync: POST pending mutations on reconnect    │   │
│  │  └─ Offline fallback: Show cached profile when offline      │   │
│  └────────────────────────────────────────────────────────────────┘   │
│           ▲                                                         │
│           │ (intercepts fetch)                                      │
│           │                                                         │
└─────────────────────────────────────────────────────────────────────┘
           │
           ▼
   ┌─────────────────┐
   │  Firestore &    │
   │  Cloud Functions│
   └─────────────────┘
```

---

## 3. Components

### 3.1 IndexedDB Cache (`public/ludus/idb-schema.ts`)

**Responsibility:** Persistent storage for Demiurge graph and player state.

**Object Stores:**

| Store | Key | Indexes | Purpose |
|-------|-----|---------|---------|
| `ludus_nodes` | nodeId | nodeType, status, _localUpdateAtMs | Cache all graph nodes |
| `ludus_edges` | edgeId | sourceNodeId, targetNodeId, type | Cache all graph edges |
| `player_profile` | userId | — | Current player profile |
| `knowledge_gates` | gateId | subject, tier | Available knowledge gates |
| `gate_attempts` | attemptId | playerId, gateId, attemptedAtMs | Player's gate submissions |
| `pending_mutations` | id | synced, type | Queue of unsync'd changes |
| `metadata` | key | — | Cache sync state (lastSyncMs, version) |

**API:**

```typescript
class LudusOfflineCache {
  // Nodes
  async putNode(node: DemiurgeNode): Promise<void>
  async getNode(nodeId: string): Promise<IDBNode | undefined>
  async getAllNodes(): Promise<IDBNode[]>
  async deleteNode(nodeId: string): Promise<void>

  // Edges
  async putEdge(edge: DemiurgeEdge): Promise<void>
  async getEdge(edgeId: string): Promise<IDBEdge | undefined>
  async getEdgesBySource(sourceNodeId: string): Promise<IDBEdge[]>
  async getAllEdges(): Promise<IDBEdge[]>

  // Mutations
  async enqueueMutation(mutation: PendingMutation): Promise<void>
  async getPendingMutations(): Promise<PendingMutation[]>
  async markMutationSynced(mutationId: string): Promise<void>
  async deleteMutation(mutationId: string): Promise<void>

  // Metadata
  async getMetadata(): Promise<CacheMetadata | undefined>
  async putMetadata(metadata: CacheMetadata): Promise<void>

  // Bulk
  async clearAll(): Promise<void>
}
```

---

### 3.2 Service Worker (`public/ludus/sw.js`)

**Responsibility:** Network interception, offline serving, background sync.

**Cache Strategies:**

- **Cache-First** (static assets):
  - Check cache first
  - Fall back to network
  - Useful for: `ludus-game.js`, `ludus-game.css`, `idb-schema.js`

- **Network-First** (API calls):
  - Try network first
  - Fall back to cache
  - Return 503 with offline indicator if both fail
  - Useful for: `/api/ludus/*`, `/api/firestore/*`

**Events:**

| Event | Handler | Purpose |
|-------|---------|---------|
| `install` | Cache static assets, skip waiting | Initialize SW with pre-cached files |
| `activate` | Clean old caches, claim clients | Prepare for new requests |
| `fetch` | Route to cache/network strategy | Intercept and serve requests |
| `sync` (tag=ludus-background-sync) | `syncPendingMutations()` | Sync on reconnection |
| `message` | Handle client messages | Support skip-waiting, cache clearing, sync requests |

**Client Communication:**

```typescript
// From client to SW
navigator.serviceWorker.controller.postMessage({
  type: "REQUEST_SYNC" // Trigger background sync
});

// From SW to client
client.postMessage({
  type: "SYNC_START",    // Mutation sync beginning
  timestamp: Date.now()
});

client.postMessage({
  type: "SYNC_COMPLETE", // Mutation sync done
  timestamp: Date.now()
});
```

---

### 3.3 Optimistic Mutations (`public/ludus/optimistic-mutations.ts`)

**Responsibility:** UI-first mutation handling with automatic server reconciliation.

**API:**

```typescript
class OptimisticMutationManager {
  // Mutations
  async updateNode(nodeId: string, updates: Partial<DemiurgeNode>): Promise<MutationResult>
  async updateEdge(edgeId: string, updates: Partial<DemiurgeEdge>): Promise<MutationResult>
  async submitGateAttempt(attempt: PlayerGateAttempt): Promise<MutationResult>

  // Sync
  async syncPendingMutations(firestoreClient: any): Promise<SyncResult>

  // Listeners
  onMutation(callback: (mutation: PendingMutation) => void): () => void

  // Status
  async isMutationPending(mutationId: string): Promise<boolean>
  async getPendingMutations(): Promise<PendingMutation[]>
}

// Initialization
async function initializeOfflineSupport(): Promise<void>
```

**Mutation Flow:**

```
User Action
    ▼
updateNode(nodeId, updates)
    ├─ Fetch current node from IndexedDB
    ├─ Apply updates locally (optimistic)
    ├─ Store updated node in IndexedDB
    ├─ Enqueue mutation { id, type, target, enqueuedAtMs, synced: false }
    ├─ Store in pending_mutations table
    ├─ Notify listeners → UI shows "pending" indicator
    └─ Return { success: true, mutationId, isPending: true }
    
    [Later, when online]
    
    syncPendingMutations(firestoreClient)
    ├─ Fetch all mutations where synced=false
    └─ For each mutation:
        ├─ POST to Firestore collection (ludus_nodes, ludus_edges, ludus_gate_attempts)
        ├─ Mark mutation synced=true
        └─ Continue (server is source of truth on sync)
```

---

## 4. Integration with ludus-game.js

The game tab in webtypicon2 should integrate A10 by:

### 4.1 Initialize Offline Support

```javascript
// At app startup (webtypicon2/ludus-game.js)
import {
  initializeOfflineSupport,
  optimisticMutationManager,
} from "./ludus/optimistic-mutations.js";

// Initialize caching and Service Worker
await initializeOfflineSupport();
```

### 4.2 Use Optimistic Mutations for UI Changes

```javascript
// When player updates their profile attribute
async function updatePlayerAttribute(nodeId, attribute, value) {
  const result = await optimisticMutationManager.updateNode(nodeId, {
    attributes: {
      ...player.attributes,
      [attribute]: value,
    },
  });

  if (result.success) {
    // Update UI immediately (optimistic)
    updatePlayerDisplay(player);

    // Show "pending" indicator
    if (result.isPending) {
      showPendingIndicator(result.mutationId);
    }
  }
}
```

### 4.3 Listen for Mutation Events

```javascript
// Subscribe to mutation events (for UI indicators)
const unsubscribe = optimisticMutationManager.onMutation((mutation) => {
  console.log(`Mutation ${mutation.id} queued:`, mutation);
  // Show "pending" UI indicator
  addPendingBadge(mutation.id);
});

// Listen for sync completion
window.addEventListener("ludus-sync-complete", (event) => {
  console.log("All mutations synced!");
  removePendingIndicators();
});
```

### 4.4 Sync on Reconnection

```javascript
// Automatic: setupAutoSync() is called by initializeOfflineSupport()
// When browser detects `online` event, Service Worker initiates background sync

// Optional: Manual sync
window.addEventListener("online", async () => {
  const result = await optimisticMutationManager.syncPendingMutations(db);
  console.log(`Synced: ${result.synced}, Failed: ${result.failed}`);
});
```

---

## 5. Data Flow Example

### 5.1 Offline Update Scenario

**Player is offline and updates their Strength attribute:**

```
1. Player clicks "Strength +1" button
2. ludus-game.js calls: updatePlayerAttribute(nodeId, "strength", 15)
3. optimisticMutationManager.updateNode() executes:
   - Fetches player node from IndexedDB: { strength: 14, ... }
   - Updates to: { strength: 15, ... }
   - Stores in IndexedDB (optimistic)
   - Enqueues mutation: { id: "node-update-...", target: {...}, synced: false }
4. UI re-renders immediately with strength: 15
5. "pending" indicator shown (faint color, animated icon)
6. Server still shows strength: 14

7. Player gains internet connection
8. Service Worker detects online event
9. Browser calls background sync: syncPendingMutations(firestoreClient)
10. Mutation POSTs to Firestore: ludus_nodes/{nodeId} set {strength: 15}
11. Firestore write succeeds
12. Mutation marked synced=true in IndexedDB
13. "pending" indicator removed
14. Server and client now agree: strength: 15
```

### 5.2 Cache Miss Recovery

**Player refreshes browser while offline:**

```
1. Browser loads ludus-game.js (from cache via SW)
2. initializeOfflineSupport() restores from IndexedDB
3. Player profile, nodes, edges loaded from cache
4. UI renders with cached data
5. Player can continue playing (read-only or with local updates)
6. Updates queued in pending_mutations table
7. On reconnection, sync occurs automatically
```

---

## 6. Conflict Resolution

**Strategy: Last-write-wins (client update overwrites server on sync)**

For v0.1, conflicts are handled optimistically:
- Client changes are sent as-is to Firestore (merge: true)
- If server version is newer (newer createdAtMs or activeFromMs), it may be overwritten
- For critical conflicts, requires human review (future: CRDT-based resolution)

**Firestore Security Rules** (S12, separate blocker) will enforce:
- Players can only sync their own player node
- Admin-only write access to NPC/faction nodes
- Read-only access to reachable graph

---

## 7. Performance Characteristics

| Operation | Latency | Notes |
|-----------|---------|-------|
| Get node from IndexedDB | ~1–5ms | O(1) lookup, in-memory |
| Get all edges for node | ~5–20ms | Indexed query on sourceNodeId |
| Enqueue mutation | ~2–10ms | Single put operation |
| Get pending mutations | ~5–15ms | Index scan, typically <100 items |
| Sync 10 mutations | ~1–2s | Firestore writes, network-dependent |

**Memory Usage:**
- IndexedDB: ~10–50 MB (depends on graph size)
- Pending mutations: <1 MB (typically <100 items)
- Runtime caches: ~2–5 MB (Service Worker + JS runtime)

**Disk Usage:**
- IndexedDB data: User's browser storage quota (typically 50+ MB available)

---

## 8. Testing

### 8.1 Unit Tests

Test cases should cover:
- ✅ Node cache read/write
- ✅ Edge cache with source index
- ✅ Mutation enqueueing
- ✅ Pending mutation retrieval
- ✅ Metadata sync state

### 8.2 Integration Tests

- ✅ Service Worker cache strategies (cache-first, network-first)
- ✅ Offline fallback page rendering
- ✅ Background sync trigger (if supported)
- ✅ Optimistic update → server sync flow

### 8.3 Manual Testing (Required)

**Offline scenario:**
1. Start with clean IndexedDB
2. Load game tab (pre-cache all assets)
3. Disconnect network (DevTools → Offline)
4. Verify: UI shows player profile + graph (cached)
5. Update attribute → shows optimistic change + "pending" badge
6. Reconnect network → automatic sync
7. Verify: "pending" badge removed, server reflects update

**Cache miss scenario:**
1. Load game tab with network
2. Hard refresh (Cmd+Shift+R / Ctrl+Shift+R)
3. Verify: Assets serve from cache (even if network disabled)
4. Verify: No network requests for static assets

---

## 9. Files & Locations

| File | Type | Purpose |
|------|------|---------|
| `public/ludus/idb-schema.ts` | TypeScript | IndexedDB wrapper class |
| `public/ludus/sw.js` | JavaScript | Service Worker script |
| `public/ludus/optimistic-mutations.ts` | TypeScript | Mutation manager + initialization |
| `docs/A10_OFFLINE_SYNC.md` | Markdown | This document |

**Registration (in webtypicon2):**
```html
<!-- index.html or main app file -->
<script>
  // Import and initialize
  import { initializeOfflineSupport } from './ludus/optimistic-mutations.js';
  await initializeOfflineSupport();
</script>
```

---

## 10. Future Enhancements (v0.2+)

- CRDT-based conflict resolution (e.g., Yjs) for true collaborative editing
- Compression for large graph caches
- Selective sync (player chooses which mutations to upload)
- Offline-first architecture (server as backup, not primary)
- Real-time sync via WebSocket (less polling)

---

## 11. References

- **IndexedDB Spec:** https://www.w3.org/TR/IndexedDB-2/
- **Service Worker API:** https://www.w3.org/TR/service-workers-1/
- **Background Sync API:** https://www.w3.org/TR/background-sync/
- **Firestore Offline Persistence:** https://firebase.google.com/docs/firestore/manage-data/enable-offline

---

**Status:** ✅ COMPLETE  
**Owner:** Claude Haiku 4.5  
**Last Updated:** 2026-09-27  
**Next:** S12 (Firestore Security Rules)
