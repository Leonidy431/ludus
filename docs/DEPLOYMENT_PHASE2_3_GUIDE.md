---
id: ludus-deployment-phase2-3
type: deployment-guide
tags: [ludus, deployment, firestore, device-testing, quest-3]
version: 1.0
status: ready-to-execute
date: 2026-09-28
---

# Ludus v0.1: Phase 2–3 Deployment Guide

**Goal:** Initialize Firestore + prepare for Quest 3 device testing  
**Timeline:** 3 days to device testing (2026-09-28 → 2026-10-01)  
**Status:** All code merged to main (✅ A10 + S12 + A6 + A8 + U1 + T1 + D3)

---

## Phase 2: Firestore Initialization (30 min)

### 2.1 Prerequisites

**Local:**
- [ ] Firebase CLI installed: `firebase --version`
- [ ] Logged in: `firebase login`
- [ ] Project set: `firebase use ludus-dev` (or production)

**Cloud:**
- [ ] Firebase project created (Console)
- [ ] Firestore Database initialized (mode: native)
- [ ] Service account created (Console → Service Accounts → Generate Key)

### 2.2 Deploy Functions & Rules

```bash
# From repo root
cd /home/user/ludus

# Build functions
cd functions && npm run build && cd ..

# Deploy to Firebase
firebase deploy --only functions,firestore:rules

# Verify
firebase functions:list
```

**Expected output:**
```
✔  Deploy complete!

ludusHealth (https://...)
ludusMetrics (https://...)

Firestore rules published successfully
```

### 2.3 Initialize Firestore with Seed Data

**Step 1: Get service account key**
- Firebase Console → Project Settings → Service Accounts
- Click "Generate new private key"
- Save to: `functions/service-account.json` (NOT COMMITTED)

**Step 2: Run seed script**
```bash
cd functions
export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/service-account.json
npm run ts-node src/scripts/seedDemiurgeData.ts
```

**Expected output:**
```
[Seed] Initializing 5 players...
[Seed] Creating 20 NPCs...
[Seed] Creating 50 edges...
[Seed] Creating 10 knowledge gates...
[Seed] Seed data complete! ✅
  - Nodes: 25
  - Edges: 50
  - Gates: 10
```

**Step 3: Verify health check**
```bash
curl https://YOUR_PROJECT.cloudfunctions.net/ludusHealth
```

**Expected response:**
```json
{
  "status": "ok",
  "timestamp": "2026-09-28T...",
  "components": {
    "firestore": {
      "status": "ok",
      "nodeCount": 25,
      "edgeCount": 50,
      "gateCount": 10
    },
    "seed_data": {
      "status": "ok",
      "playerCount": 5,
      "npcCount": 20,
      "expectedPlayers": 5,
      "expectedNpcs": 20
    },
    "simulation": {
      "status": "ok",
      "lastCycleDurationMs": 0,
      "cycleCountSinceInit": 0
    }
  }
}
```

### 2.4 Cleanup

```bash
# Delete service account key (sensitive!)
rm functions/service-account.json

# Verify Firestore has data
firebase firestore:inspect ludus_nodes | head -5
```

---

## Phase 3: Quest 3 Device Testing Prep (3 days)

### 3.1 Day 1 (Today): Build & Test Setup

**Tasks:**
- [ ] Merge A10 + S12 to main ✅ DONE
- [ ] Deploy functions + Firestore rules ← Phase 2
- [ ] Initialize seed data ← Phase 2
- [ ] Verify health endpoint responds
- [ ] Generate test user tokens (Firebase Console → Authentication)

**Test Users to Create:**
```
1. test-player-1@ludus.dev (analyst, can read profile + graph)
2. test-player-2@ludus.dev (engineer, can read/write own profile)
3. test-admin@ludus.dev (admin, full Firestore access)
```

**Assign Custom Claims (Firebase Console → Users → Custom Claims):**
```json
{
  "admin": false,
  "playerNodeId": "player-001",
  "role": "player"
}
```

### 3.2 Day 2: webtypicon2 Integration & Manual Testing

**Tasks:**
- [ ] Integrate A10 offline support in webtypicon2 ludus-game.js
  ```javascript
  import { initializeOfflineSupport } from '/ludus/optimistic-mutations.js';
  await initializeOfflineSupport();
  ```

- [ ] Test offline scenarios locally (Chrome DevTools → Offline)
  - [ ] Update player attribute → shows "pending"
  - [ ] Reconnect → syncs automatically
  - [ ] Service Worker caches static assets

- [ ] Test auth flow
  - [ ] Sign in with test user
  - [ ] Bearer token in API calls
  - [ ] Health endpoint works
  - [ ] Metrics endpoint requires admin token

- [ ] Test Firestore subscriptions
  - [ ] Player profile loads from ludus_nodes
  - [ ] Graph edges render (friends, NPCs)
  - [ ] Knowledge gates available

### 3.3 Day 3: Build APK & Device Setup

**Tasks:**
- [ ] Build Unity APK for Quest 3
  ```
  File → Build Settings → Build (Debug)
  Target: Meta Quest 3 (arm64-v8a)
  ```

- [ ] Connect Quest 3 via ADB
  ```bash
  adb devices  # Should list Quest
  adb logcat | grep Ludus  # Monitor logs
  ```

- [ ] Deploy APK to device
  ```bash
  adb install -r build.apk
  ```

- [ ] Open web browser tab (Firefox)
  ```
  Navigate to: https://ludus-game.web.app  (or local)
  Login with test-player-1@ludus.dev
  ```

- [ ] Test game flow
  - [ ] Player profile renders
  - [ ] Demiurge graph visible (100 nodes, 500 edges)
  - [ ] Knowledge gates accessible
  - [ ] VR telemetry → player attributes update

### 3.4 Day 3–4: Device Testing Scenarios

**Scenario 1: Offline Gameplay**
```
1. Disconnect WiFi from Quest
2. Play game (update attributes, submit gate answers)
3. Verify "pending" badges show
4. Reconnect WiFi
5. Verify sync happens automatically
6. Check Firestore has new data
```

**Scenario 2: VR Telemetry Integration**
```
1. Activate VR mode (DiveComputer)
2. Record depth, pressure, velocity
3. Monitor DemiurgeBridge mapping:
   - Depth → Wisdom attribute
   - Power → Constitution attribute
   - Velocity → Dexterity attribute
4. Verify player node updates in real-time
5. Check webtypicon2 reflects changes
```

**Scenario 3: Network Failover**
```
1. Toggle WiFi on/off repeatedly
2. Submit mutations while offline
3. Reconnect → background sync handles it
4. No data loss or duplicates
```

**Scenario 4: Performance Baseline**
```
1. Record FPS (Quest 3 target: 90 FPS)
2. Measure DemiurgeBridge cycle time (target: <8ms)
3. Monitor Firestore latency (target: <1s per query)
4. Check battery impact (VR + WiFi)
```

---

## Monitoring & Observability

### 3.5 Logging & Debugging

**Cloud Logging Dashboard:**
```
Resource: Cloud Function
Filter: resource.labels.function_name=ludusHealth OR ludusMetrics
```

**Expected logs:**
```
[Auth] Token verification failed: ...
[Health] Authenticated request from user: abc123
[Metrics] Admin metrics accessed by: xyz789
[Seed] Initializing...
```

**Local debugging:**
```bash
firebase functions:log --limit 100
firebase firestore:inspect ludus_nodes | jq '.[] | {nodeId, status, attributes}'
```

### 3.6 Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `"Collections not initialized"` | Seed data not run | Execute Phase 2.3 |
| `"Unauthorized"` | Missing Bearer token | Add auth header to requests |
| `"Forbidden"` | Non-admin accessing metrics | Use admin token or health endpoint |
| `"PERMISSION_DENIED"` | Firestore rule violated | Check `firestore.rules` policy |
| `"Offline"` | Network error in SW | Service Worker should cache + sync |

---

## Rollback & Safety

### 3.7 If Something Breaks

**Rollback functions:**
```bash
# Delete functions, keep data
firebase functions:delete ludusHealth ludusMetrics --quiet
firebase functions:delete ludusMetrics --quiet
```

**Clear Firestore (⚠️ DESTRUCTIVE):**
```bash
# Use Firebase Console or:
firebase firestore:delete ludus_nodes ludus_edges ludus_knowledge_gates --confirm
```

**Restore from backup:**
```bash
# Firestore auto-backups (Console → Backups)
# Or restore with gcloud:
gcloud firestore databases restore BACKUP_ID
```

---

## Post-Deployment Checklist

- [ ] Main branch has A10 + S12 + others
- [ ] Functions deployed and responding
- [ ] Firestore seed data initialized (25 nodes, 50 edges, 10 gates)
- [ ] Health endpoint returns 200 ok
- [ ] Metrics endpoint requires admin token
- [ ] Service Worker caches assets
- [ ] Offline mutations work locally
- [ ] webtypicon2 integrated with A10
- [ ] Test users created with custom claims
- [ ] Quest 3 APK built and deployed
- [ ] VR telemetry loop tested
- [ ] No data loss in offline→online sync
- [ ] Performance baselines recorded
- [ ] Error logs monitored

---

## Timeline Summary

| Phase | Date | Duration | Status |
|-------|------|----------|--------|
| Phase 1: Code Integration | Sep 28 | ✅ 2h | COMPLETE |
| Phase 2: Firestore Init | Sep 28 | ⏳ 30m | READY |
| Phase 3A: webtypicon2 Integrate | Sep 29 | ⏳ 4h | READY |
| Phase 3B: Manual Testing | Sep 30 | ⏳ 8h | READY |
| Phase 3C: Device Build & Deploy | Oct 1 | ⏳ 4h | READY |
| Phase 3D: Device Testing | Oct 1–2 | ⏳ 8h+ | READY |
| Phase 4: v0.1 Release | Oct 2 | ⏳ TBD | Pending testing |

---

## References

- **docs/A10_OFFLINE_SYNC.md** — Offline sync + Service Worker
- **docs/S12_FIRESTORE_AUTH.md** — Auth + security rules
- **functions/src/scripts/seedDemiurgeData.ts** — Seed data script (379 lines)
- **firebase.json** — Firebase CLI configuration
- **firestore.rules** — Security rules (Firestore)

---

**Next Steps:**
1. Execute Phase 2 (30 min)
2. Prepare webtypicon2 integration for Sep 29
3. Device testing Sep 30 – Oct 1
4. Release v0.1 once testing passes

**Owner:** Claude Haiku 4.5  
**Last Updated:** 2026-09-28 10:47 UTC
