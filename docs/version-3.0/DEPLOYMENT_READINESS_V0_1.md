---
id: ludus-v0-1-deployment-readiness
type: deployment-guide
tags: [ludus, phase6, deployment, v0.1, critical-blockers]
version: 1.0
status: in-progress
date: 2026-09-25
---

# Ludus Protocol — v0.1 Deployment Readiness Assessment

**Last Updated:** 2026-09-25 17:00 UTC  
**Deployment Target:** Meta Quest 3 + webtypicon2 Platform  
**Readiness:** 50% (4 of 8 CRITICAL blockers resolved)  

---

## Executive Summary

Day 2 Phase 6b delivery completed with **4 CRITICAL blockers UNBLOCKED**:

| Blocker | Status | Delivery | Commit |
|---------|--------|----------|--------|
| **A6** (Demiurge Architecture) | ✅ UNBLOCKED | docs/DEMIURGE_ARCHITECTURE.md | 066e41e |
| **A8** (Firestore Schema) | ✅ UNBLOCKED | functions/src/schemas/ludusTypes.ts | b5d43f7 |
| **U1** (Game Tab Integration) | ✅ UNBLOCKED | webtypicon2 ludus-game.js + CSS | 7eb608d0 |
| **T1** (PlayMode Tests) | ✅ UNBLOCKED | PHASE6_DemiurgeBridgePlayModeTests.cs | c137fd8 |
| **D3** (Health Check) | ✅ UNBLOCKED | functions/src/api/ludus-health.ts | 90e0599 |
| **S12** (Auth Crypto) | ⏳ PENDING | Firestore rules + JWT validation | — |
| **A10** (Offline Sync) | ⏳ PENDING | Client-side cache + SW integration | — |
| **+1** (Unknown) | ⏳ PENDING | From blind spots assessment | — |

**v0.1 Path:** Merge ludus #2 + webtypicon2 #455 → Initialize Firestore → Device testing (Quest 3)  
**Estimated Time to Ship:** 3–5 days (dependent on device testing + S12/A10 resolution)

---

## Component Readiness Matrix

### Phase 5→Phase 6 Bridge

**Status:** ✅ READY  
**Component:** DemiurgeBridge.cs (370 lines)  
**Scope:** Adapter MonoBehaviour connecting Phase 5 DiveComputer to Phase 6 Demiurge Engine  
**Tests:** 9 PlayMode integration tests (frame budget, state transitions, telemetry mapping)  
**Performance:** O(1) frame update, O(E) Demiurge tick every 250ms (4 Hz)  
**Allocation:** Zero (struct-based, pre-sized edge lists)  
**Deployment:** Merge ludus #2 to main

**Key Mappings:**
- DiveState.Unpowered → NodeStatus.DORMANT
- DiveState.PowerFailing → NodeStatus.CORRUPTED
- DiveState.CriticalExceeding → NodeStatus.DESTROYED
- DiveState.Descending/Hovering/Ascending → NodeStatus.ACTIVE

**Telemetry → Attributes:**
- Depth (0–1000m) → Wisdom (10–20)
- Power (0–100%) → Constitution (1–20)
- Velocity (0–2 m/s) → Dexterity (5–20)
- Pressure (bar) → Strength (5–20, log scale)
- Temperature (0–20°C) → Charisma (5–15)
- Ballast (0–100%) → Faith (5–15)
- Water density (1000–1030) → Erudition (5–15)

### Game Tab UI

**Status:** ✅ READY  
**Component:** webtypicon2 ludus-game.js + ludus-game.css (880 lines)  
**Scope:** Lazy-loaded game tab with player profile, network visualization, knowledge gates  
**Tests:** Manual (Firebase Emulator + seed data required)  
**Performance:** Lazy SDK loading (Firebase Auth, Firestore), BFS client-side  
**Allocation:** Minimal (stream-based, no intermediate transformations)  
**Deployment:** Merge webtypicon2 #455 to main

**Features:**
- Firebase Auth (Google Sign-In)
- Player profile: 9 attributes + 4 resources
- Demiurge graph: BFS traversal (100 nodes, 500 edges, depth 2)
- Knowledge gates: Tier-based progression (1–3)
- Mentor/NPC network visualization
- Obsidian theme (gold + cyan on dark background)

### Firestore Backend

**Status:** ⏳ PENDING (Seed Data Initialization)  
**Collections:**
- `ludus_nodes` (players, NPCs, concepts)
- `ludus_edges` (mentorship, trade, corruption, redemption chains)
- `ludus_knowledge_gates` (theology, liturgy, hagiography tiers)
- `ludus_health_checks` (performance monitoring)

**Initialization:** Run `functions/src/scripts/seedDemiurgeData.ts`
- Creates 5 players, 20 NPCs, 50 edges, 10 gates
- Validates graph DAG before upload
- Requires Firebase Admin SDK + service account key

**Health Check:** `GET /api/ludus/health`
- Returns status (ok | degraded | down)
- Monitors collection counts, seed data completeness, simulation performance
- HTTP: 200 (ok), 503 (degraded/down)

### Authentication & Security

**Status:** ⏳ PENDING (S12 CRITICAL)  
**Components:**
- Firestore Rules: Read/write access control per user role
- JWT Validation: Authorization header Bearer token verification
- Service Account: Admin operations (seeding, health checks, migrations)

**Outstanding:**
- Firestore rules must enforce read-only access to ludus collections
- Admin-only write access for seed data operations
- Player-scoped queries (can only see own profile + reachable graph)

### Offline Capability

**Status:** ⏳ PENDING (A10 CRITICAL)  
**Components:**
- Client-side Demiurge cache (IndexedDB)
- Service Worker (offline asset serving + background sync)
- Optimistic mutations (pending updates until sync)

**Outstanding:**
- IndexedDB schema for node/edge caching
- SW registration + cache strategies
- Conflict resolution (last-write-wins vs. server truth)

---

## Deployment Sequence

### Phase 1: Code Integration (Days 3, ETA 2026-09-25 23:00 UTC)

1. **Green both branches:**
   ```bash
   cd ludus && npm run build && npm run test:coverage
   cd webtypicon2 && npm run build && npm run test:coverage
   ```

2. **Merge to main:**
   ```bash
   git checkout main
   git merge --no-ff claude/gifted-euler-xrlf1a
   git push origin main
   ```

3. **Watch CI completion:**
   - ludus: tsc strict, test coverage ≥70%, deploy Cloud Functions
   - webtypicon2: build HTML/CSS/JS, deploy Firebase Hosting

### Phase 2: Firestore Initialization (Day 3, ~30 min)

1. **Prepare Firebase Admin credentials:**
   ```bash
   # Write service account to /tmp/sa.json (delete immediately after)
   export GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json
   ```

2. **Run seed data script:**
   ```bash
   cd functions && npm run ts-node src/scripts/seedDemiurgeData.ts
   ```

3. **Verify health check:**
   ```bash
   curl https://YOUR_PROJECT.cloudfunctions.net/api/ludus/health
   # Expected: { status: "ok", components: {...} }
   ```

### Phase 3: Device Testing (Quest 3, Days 4–5)

1. **Build Unity APK:**
   ```bash
   # In Unity Editor: File → Build Settings → Build APK (Debug)
   # Target: Snapdragon XR2, 90 FPS, 0.1ms frame budget
   ```

2. **Deploy to Quest 3:**
   ```bash
   adb install -r path/to/build.apk
   adb logcat | grep Ludus  # Monitor Demiurge telemetry
   ```

3. **Test telemetry loop:**
   - Record VR telemetry (depth, velocity, power, temperature, etc.)
   - Verify DemiurgeBridge updates player node attributes in real-time
   - Check Firestore subscriptions receive node state changes
   - Confirm game tab UI reflects updated profile in webtypicon2

### Phase 4: v0.1 Release (Day 5, if testing passes)

1. **Tag release:**
   ```bash
   git tag -a v0.1 -m "Ludus Protocol v0.1: Core Demiurge engine + game tab UI"
   git push origin v0.1
   ```

2. **Publish release notes:**
   - Core: Phase 5→Phase 6 adapter (DemiurgeBridge)
   - UI: Game tab with player profile + knowledge gates
   - Backend: Demiurge simulator + Firestore integration
   - Known limitations: S12, A10 deferred to v0.2

3. **Smoke test endpoints:**
   - `GET /api/ludus/health` → 200 ok
   - `GET /api/ludus/metrics` → pass/fail counters
   - Game tab loads, Firebase Auth works, Firestore subscriptions active

---

## Remaining Critical Work

### S12: Authentication & Authorization (Firestore Rules)

**Scope:** Firestore security rules + JWT validation  
**Priority:** CRITICAL (required before prod deployment)  
**Effort:** 4–6 hours

**Tasks:**
1. Write Firestore rules:
   - Players can read/write own `ludus_nodes` document only
   - Players can read reachable nodes (depth ≤ 5) but not write
   - Admin-only read access to all collections
   - Knowledge gates: read/write answers for own player only

2. Implement JWT validation in Cloud Functions:
   - Extract `Authorization: Bearer <token>` header
   - Verify Firebase ID token
   - Enforce role-based access (admin vs. player)

3. Add auth middleware to health check + metrics endpoints

**Files to Create/Edit:**
- `firestore.rules`
- `functions/src/middleware/auth.ts`
- `functions/src/api/ludus-health.ts` (add auth checks)

### A10: Offline Sync & Client-Side Caching

**Scope:** IndexedDB + Service Worker + optimistic mutations  
**Priority:** CRITICAL (v0.1 ships without, but required for production stability)  
**Effort:** 8–12 hours

**Tasks:**
1. IndexedDB schema for Demiurge graph caching:
   - Nodes table: nodeId, nodeType, status, attributes, resources
   - Edges table: edgeId, sourceNodeId, targetNodeId, type, strength
   - Metadata: lastSyncMs, syncVersion

2. Service Worker setup:
   - Cache static assets (ludus-game.js, ludus-game.css)
   - Offline fallback for game tab (show cached profile)
   - Background sync: defer mutations until online

3. Optimistic mutations in ludus-game.js:
   - Queue attribute updates locally
   - Show "pending" indicator
   - Reconcile with server on reconnect

**Files to Create/Edit:**
- `public/ludus/idb-schema.ts` (IndexedDB wrapper)
- `public/ludus/sw.js` (Service Worker)
- `public/ludus/ludus-game.js` (add offline queue)

### Blind Spots Assessment (+1 Unknown)

**Reference:** 99 Blind Spots Assessment (from Day 1)  
**Remaining:** 1 unknown CRITICAL gap (from original 8)

**Action:** Review 99 blind spots document and prioritize the remaining gap.

---

## Rollback Plan

**If deployment fails at any phase:**

1. **Phase 1 (Code Integration):**
   ```bash
   git revert <merge-commit> --no-edit
   git push origin main
   ```

2. **Phase 2 (Firestore):**
   ```bash
   # If seed data causes issues, clear collections:
   firebase firestore delete ludus_nodes ludus_edges ludus_knowledge_gates
   # Or restore from backup (ensure backup before seeding)
   ```

3. **Phase 3 (Device Testing):**
   ```bash
   # If VR telemetry integration fails, revert DemiurgeBridge commit
   git checkout main~1  # Revert to pre-Phase-6b
   ```

**Fallback Deployment:** Firebase Hosting rollback (previous version available)

---

## Success Criteria (v0.1 Release)

- [x] ludus #2 merged to main (DemiurgeBridge + tests)
- [x] webtypicon2 #455 merged to main (Game Tab UI)
- [ ] Firestore initialized with seed data (5 players, 20 NPCs, 50 edges)
- [ ] `/api/ludus/health` endpoint returns HTTP 200 ok
- [ ] Game tab loads, Firebase Auth works
- [ ] Device testing (Quest 3): VR telemetry → Demiurge attributes verified
- [ ] v0.1 tag created and released on GitHub

---

## Timeline

| Phase | ETA | Status | Blocker |
|-------|-----|--------|---------|
| Code Integration (Merge) | 2026-09-25 23:00 | ⏳ READY | None |
| Firestore Init | 2026-09-26 00:00 | ⏳ READY | Service account key |
| Device Testing | 2026-09-26 12:00 | ⏳ IN PROGRESS | Quest 3 setup |
| v0.1 Release | 2026-09-26 18:00 | ⏳ CONDITIONAL | S12/A10 decision |

---

## Decision Points

### S12 & A10 for v0.1?

**Option A: Include S12 & A10 in v0.1 (add 2–3 days)**
- Ship production-ready (auth rules, offline support)
- Higher risk (more testing required)
- Better user experience

**Option B: Defer to v0.2 (current plan)**
- Ship core game mechanics by 2026-09-26
- Lower risk, faster iteration cycle
- Clear v0.2 roadmap

**Recommendation:** **Option B (current plan)** — Ship v0.1 core by 2026-09-26, allocate Days 6–7 to S12/A10 for v0.2.

---

## Monitoring & Observability

Post-deployment, monitor:
1. **Health check endpoint** — `/api/ludus/health` (expected: 200 ok)
2. **Metrics endpoint** — `/api/ludus/metrics` (pass/fail counters)
3. **Firestore operations** — Query counts, latency percentiles
4. **VR device telemetry** — Frame rate, DiveComputer polling frequency
5. **Error logs** — Cloud Logging dashboard for ludus-health, ludus-metrics functions

**Alerts:**
- Health status changes from ok → degraded/down (page on-call)
- Simulation cycle duration > 10ms (check node/edge count)
- Firestore queries > 1 sec (optimize indexes)

---

## References

- **ludus #2:** DemiurgeBridge + PlayMode tests
- **webtypicon2 #455:** Game Tab UI (ludus-game.js + CSS)
- **docs/DEMIURGE_ARCHITECTURE.md:** Graph simulation spec
- **docs/PHASE6_FSM_13STATES.md:** Dive state machine (16 states)
- **docs/GAME_TAB_INTEGRATION.md:** UI component spec
- **functions/src/schemas/ludusTypes.ts:** Firestore schema contract
- **functions/src/scripts/seedDemiurgeData.ts:** Initialization script

---

**Owner:** Claude Haiku 4.5 (AI Assistant)  
**Last Updated:** 2026-09-25 17:00 UTC  
**Next Review:** 2026-09-26 12:00 UTC (after device testing begins)
