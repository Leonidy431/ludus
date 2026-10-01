# Ludus: Comprehensive Project Audit & Gap Analysis
## Sep 29, 2026 | Full Scope Inventory

**Mission:** Identify ALL gaps, missing components, incomplete docs before Phase 3 testing.  
**Coverage:** ludus (backend) + webtypicon2 (frontend) + design specs  
**Date:** 2026-09-29 14:30 UTC  

---

## 📊 Project Scope Summary

**Total Components Identified:** 40+  
**Estimated Work:** 60–80 hours (before Phase 3 testing Oct 1)  
**Critical Path:** 20+ hours (blocking Phase 3)

---

## 🔴 CRITICAL GAPS (P0 — BLOCKING PHASE 3)

### GAP_001: Demiurge Engine NOT Integrated

**Component:** Demiurge Graph Engine (DEMIURGE_ARCHITECTURE.md)  
**Status:** 📄 Documented (400+ lines) but NOT IMPLEMENTED  
**Impact:** Core world simulation system missing  
**Files:**
- ✅ docs/DEMIURGE_ARCHITECTURE.md (exists, 400+ lines)
- ❌ functions/src/api/ludus-demiurge.ts (MISSING)
- ❌ functions/src/schemas/demiurge-node.ts (MISSING)
- ❌ functions/src/schemas/demiurge-edge.ts (MISSING)
- ❌ Seed script for Demiurge entities (MISSING)

**Quick Fix:** 
- Copy architectural doc into TypeScript implementation
- Create Node/Edge interfaces
- Implement graph query functions
- Create seed data for initial entities

**Time:** 8–10 hours  
**Priority:** P0 (Needed for dialogue causality tracking)

---

### GAP_002: ROV Lake 13-State FSM NOT Integrated

**Component:** ROV Dive Computer State Machine (PHASE6_FSM_13STATES.md)  
**Status:** 📄 Documented (300+ lines) but NOT IMPLEMENTED  
**Impact:** ROV telemetry system incomplete  
**Files:**
- ✅ docs/PHASE6_FSM_13STATES.md (exists)
- ❌ public/ludus/rov-lake-fsm.ts (MISSING)
- ❌ public/ludus/dive-computer.ts (MISSING)
- ⚠️ public/ludus/rov-lake-manager.js (EXISTS but needs FSM integration)

**Quick Fix:**
- Implement 13-state enum + transitions
- Wire into rov-lake-manager.js
- Add telemetry → state mapping
- Add UI indicator for current state

**Time:** 6–8 hours  
**Priority:** P0 (Needed for ROV dialogue bonuses)

---

### GAP_003: Offline Sync NOT Fully Integrated

**Component:** IndexedDB + Optimistic Mutations (A10_OFFLINE_SYNC.md)  
**Status:** 📄 Documented (300+ lines), ⚠️ Partial code exists  
**Impact:** Dialogue choices fail offline, no fallback persistence  
**Files:**
- ✅ docs/version-3.0/A10_OFFLINE_SYNC.md (exists, detailed)
- ⚠️ public/ludus/idb-schema.ts (EXISTS, basic)
- ⚠️ public/ludus/optimistic-mutations.ts (EXISTS, needs completion)
- ❌ public/ludus/sync-manager.ts (MISSING — main orchestrator)
- ❌ public/ludus/conflict-resolver.ts (MISSING — handles sync conflicts)

**Quick Fix:**
- Complete optimistic-mutations.ts (add choice queueing)
- Create sync-manager.ts (queue → API → Firestore flow)
- Add offline detection + retry logic
- Wire into ludus-game.js

**Time:** 5–7 hours  
**Priority:** P0 (Needed for Quest 3 offline play)

---

### GAP_004: Firestore Auth Middleware NOT Complete

**Component:** Auth + Rate Limiting (S12_FIRESTORE_AUTH.md)  
**Status:** 📄 Documented (300+ lines), ⚠️ Partial code exists  
**Impact:** API endpoints have no auth, no rate limiting  
**Files:**
- ✅ docs/version-3.0/S12_FIRESTORE_AUTH.md (exists, detailed)
- ⚠️ functions/src/middleware/auth.ts (EXISTS, basic)
- ⚠️ functions/src/middleware/rateLimit.ts (EXISTS, needs deployment)
- ❌ Middleware NOT wired into ludus-dialogue.ts (endpoints unprotected)
- ❌ Firestore rules incomplete (no player data isolation)

**Quick Fix:**
- Wire middleware into all 5 dialogue endpoints
- Enable request auth verification
- Enable rate limiting (100 req/min per IP)
- Update Firestore rules (deny cross-player access)

**Time:** 3–4 hours  
**Priority:** P0 (Security blocker for production)

---

### GAP_005: ludus-game.js NOT Implemented

**Component:** Main game loop + NPC integration (GAME_TAB_INTEGRATION.md)  
**Status:** 📄 Documented (300+ lines), ⚠️ Skeleton exists only  
**Impact:** No NPC rendering, no dialogue triggering  
**Files:**
- ✅ docs/GAME_TAB_INTEGRATION.md (exists)
- ⚠️ public/ludus/ludus-game.js (EXISTS, 50 lines — TOO SHORT)
- ❌ NPC scene graph NOT implemented
- ❌ Click detection for NPCs NOT implemented
- ❌ Dialogue modal trigger NOT wired

**Quick Fix:**
- Implement 3D scene with 5 core NPCs (visible geometry)
- Add click detection (raycasting or hitboxes)
- Wire NPC click → loadDialogueTree → UI modal
- Add player attribute display HUD
- Add basic movement controls (WASD)

**Time:** 12–15 hours  
**Priority:** P0 (BLOCKING: no game without this)

---

### GAP_006: Testing Suite Completely Missing

**Component:** Unit, Integration, E2E Tests  
**Status:** ❌ NO TESTS AT ALL  
**Impact:** Cannot verify correctness before Phase 3  
**Missing:**
- ❌ tests/unit/ludus-dialogue.test.ts
- ❌ tests/unit/ludus-audio.test.ts
- ❌ tests/integration/api-dialogue.test.ts
- ❌ tests/e2e/quest3-dialogue.test.ts
- ❌ Mock Firestore setup for testing

**Quick Fix:**
- Create Jest config + test harness
- Write unit tests for dialogue branching logic
- Write API integration tests (curl-based)
- Write VR (Playwright) integration tests

**Time:** 8–10 hours  
**Priority:** P1 (Needed for Phase 3 validation)

---

## 🟡 HIGH PRIORITY GAPS (P1 — NEEDED FOR OCT 1)

### GAP_007: API Endpoints Missing Error Handling

**Files:** functions/src/api/ludus-dialogue.ts  
**Issue:** Try-catch blocks exist but error responses not comprehensive  
**Missing:**
- [ ] Validation error messages (bad input)
- [ ] Timeout handling (Firestore slow)
- [ ] Quota exceeded handling
- [ ] Retry-After header (rate limiting)
- [ ] Structured error codes (not just strings)

**Time:** 2–3 hours  
**Priority:** P1

---

### GAP_008: Firestore Rules NOT Validated

**Files:** firestore.rules (needs to exist or update)  
**Issue:** Rules incomplete, no player data isolation  
**Missing:**
- [ ] ludus_players/{playerId} — only player can read own data
- [ ] ludus_dialogue_states/{playerId}_* — auth check
- [ ] ludus_npc_memory/*/players/{playerId} — auth check
- [ ] Deny cross-player access

**Time:** 1–2 hours  
**Priority:** P1

---

### GAP_009: Performance Targets NOT Measured

**Files:** No performance baseline code  
**Issue:** Phase 3 checklist has targets but no way to measure  
**Missing:**
- [ ] Client-side performance instrumentation
- [ ] API latency logging
- [ ] Memory profiling for Quest 3
- [ ] FPS counter (headset-side)
- [ ] Thermal monitoring (Quest sensors)

**Time:** 4–5 hours  
**Priority:** P1

---

### GAP_010: Dialogue Audio Files NOT Mapped

**Files:** docs/SOUND_DESIGN_SYSTEM.md (references tracks but...)  
**Issue:** No actual audio files seeded  
**Missing:**
- [ ] 40+ music tracks uploaded to Cloud Storage
- [ ] 15+ SFX samples uploaded
- [ ] Mapping table (trackKey → GCS URL)
- [ ] CDN cache headers configured

**Time:** 6–8 hours (need actual audio production)  
**Priority:** P1 (blocks audio testing)

---

### GAP_011: VR Controller Input NOT Wired

**Files:** public/ludus/ludus-game.js, ludus-audio-manager.js  
**Issue:** No Meta Quest controller input handling  
**Missing:**
- [ ] XRInputSource listener setup
- [ ] Trigger → choice selection mapping
- [ ] Laser pointer rendering for UI
- [ ] Haptic feedback on choice

**Time:** 3–4 hours  
**Priority:** P1 (Quest 3 testing blocker)

---

### GAP_012: No Mock/Seed Data for Testing

**Files:** Need test data fixtures  
**Issue:** No sample players, dialogue states for manual testing  
**Missing:**
- [ ] Test player profiles (10 variations)
- [ ] Sample dialogue states (various branches taken)
- [ ] NPC memory samples (different interaction counts)
- [ ] Firestore import script for test data

**Time:** 2–3 hours  
**Priority:** P1

---

## 🟢 MEDIUM PRIORITY GAPS (P2 — NICE TO HAVE)

### GAP_013: Documentation Cross-References

**Issue:** Docs reference files that don't exist yet  
**Files:** Multiple docs link to non-existent sections  
**Fix:** Update all docs.to point to existing sections only

**Time:** 1–2 hours  
**Priority:** P2

---

### GAP_014: Accessibility Not Verified

**Issue:** UI may not be WCAG 2.1 AA on all platforms  
**Missing:**
- [ ] Keyboard navigation (desktop)
- [ ] Screen reader testing (NVDA, JAWS)
- [ ] High contrast mode validation
- [ ] Reduced motion (Quest accessibility)

**Time:** 3–4 hours  
**Priority:** P2

---

### GAP_015: Internationalization Structure

**Issue:** All text hardcoded in English  
**Missing:**
- [ ] i18n strings extraction
- [ ] Locale config (en-US, ru-RU, etc)
- [ ] Translation keys for dialogue

**Time:** 4–5 hours  
**Priority:** P2 (defer to Phase 5)

---

### GAP_016: Analytics/Telemetry

**Issue:** No tracking of player actions  
**Missing:**
- [ ] Event logging (dialogue choice, attribute gain)
- [ ] Session tracking (playtime, engagement)
- [ ] Crash reporting (Sentry or Firebase)

**Time:** 4–5 hours  
**Priority:** P2

---

### GAP_017: CI/CD Pipeline

**Issue:** No automated tests/deployments  
**Missing:**
- [ ] GitHub Actions workflow
- [ ] Pre-deploy tests
- [ ] Automatic Firebase function builds
- [ ] PR checks (lint, type, test)

**Time:** 4–6 hours  
**Priority:** P2

---

## 📋 Component Checklist

### Backend (ludus/functions/)

| Component | Status | Lines | Notes |
|-----------|--------|-------|-------|
| ludus-dialogue.ts | ✅ Ready | 450 | 5 endpoints, but needs auth middleware |
| ludus-health.ts | ✅ Ready | 300 | Health checks, monitoring |
| ludus-demiurge.ts | ❌ MISSING | — | Graph engine (8–10 hrs) |
| seedDialogueData.ts | ✅ Ready | 300 | Dialogue trees seeded |
| seedDemiurgeData.ts | ⚠️ Partial | 400 | Needs implementation |
| auth.ts | ⚠️ Partial | 100 | Needs wiring to endpoints |
| rateLimit.ts | ⚠️ Partial | 80 | Needs deployment config |
| firestore.rules | ❌ MISSING | — | Auth rules (2 hrs) |
| **TOTAL** | | **1,620+** | |

### Frontend (webtypicon2/public/ludus/)

| Component | Status | Lines | Notes |
|-----------|--------|-------|-------|
| ludus-game.js | ⚠️ Stub | 50 | Needs scene (12–15 hrs) |
| ludus-npc-dialogue-manager.js | ✅ Ready | 380 | Tree loading + branching |
| ludus-audio-manager.js | ✅ Ready | 420 | 4-layer mixing, spatial |
| ludus-npc-dialogue-ui.js | ✅ Ready | 290 | Modal + choices |
| ludus-dialogue.css | ✅ Ready | 380 | Responsive design |
| ludus-game.css | ⚠️ Partial | 200 | HUD + scene styles |
| ludus-design-system.css | ✅ Ready | 150 | Theme tokens |
| rov-lake-manager.js | ⚠️ Stub | 300 | Needs FSM (6–8 hrs) |
| rov-lake.css | ✅ Ready | 150 | ROV panel styles |
| sync-manager.ts | ❌ MISSING | — | Offline sync (5–7 hrs) |
| conflict-resolver.ts | ❌ MISSING | — | Sync conflicts (2–3 hrs) |
| **TOTAL** | | **2,320+** | |

---

## 🎯 Work Prioritization for Sep 29 Evening

### Critical Path (Must Do Today)

**Order:** 1 → 2 → 3 → 4 → 5

| Order | Gap | Effort | Blocker? | Status |
|-------|-----|--------|----------|--------|
| **1** | GAP_005: ludus-game.js main scene | 12–15 hrs | YES (no game without this) | ⏳ START NOW |
| **2** | GAP_001: Demiurge Graph Engine | 8–10 hrs | YES (causality tracking) | ⏳ QUEUE AFTER #1 |
| **3** | GAP_004: Auth Middleware Wiring | 3–4 hrs | YES (security) | ⏳ QUICK WIN |
| **4** | GAP_008: Firestore Rules | 1–2 hrs | YES (data isolation) | ⏳ QUICK WIN |
| **5** | GAP_003: Offline Sync Completion | 5–7 hrs | YES (Quest offline) | ⏳ QUEUE AFTER |

**Total Critical Path:** 30–38 hours (impossible in one evening!)

### What CAN Get Done Tonight (8 hrs max)

**Realistic Scope:**
1. **ludus-game.js Scene** (6–8 hrs) — Get 5 NPCs + click detection working
2. **Auth Middleware** (2–3 hrs) — Wire into endpoints
3. **Firestore Rules** (1–2 hrs) — Isolation + validation

**Defer to Oct 1 Morning:**
- Demiurge Engine (8–10 hrs) — do after scene is working
- Offline Sync (5–7 hrs) — do after APIs are secure
- ROV FSM (6–8 hrs) — lower priority for Phase 3
- Testing Suite (8–10 hrs) — do on Oct 2

---

## 📝 Backlog (Ranked by Priority)

### SPRINT 0: Tonight (Sep 29, 6–8 hours max)

| ID | Task | Est. | Owner | Status |
|----|------|-----|-------|--------|
| S0-001 | Implement ludus-game.js scene (5 NPCs + click) | 6–8 hrs | Claude | ⏳ |
| S0-002 | Wire auth middleware to dialogue endpoints | 2–3 hrs | Claude | ⏳ |
| S0-003 | Write Firestore rules + deploy | 1–2 hrs | Claude | ⏳ |

### SPRINT 1: Oct 1 Morning (Before 11:00 AM)

| ID | Task | Est. | Owner | Blocks |
|----|------|-----|-------|--------|
| S1-001 | Implement Demiurge Graph Engine | 8–10 hrs | Claude | Phase 3 API tests |
| S1-002 | Create test player fixtures | 2–3 hrs | Claude | Phase 3 testing |
| S1-003 | Add performance instrumentation | 3–4 hrs | Claude | Phase 3 baselines |

### SPRINT 2: Oct 1–2 (Parallel with Phase 3 Testing)

| ID | Task | Est. | Owner | Priority |
|----|------|-----|-------|----------|
| S2-001 | Complete offline sync | 5–7 hrs | Claude | P1 |
| S2-002 | Integrate ROV 13-state FSM | 6–8 hrs | Claude | P1 |
| S2-003 | Add VR controller input | 3–4 hrs | Claude | P1 |
| S2-004 | Create test suite (unit + integration) | 8–10 hrs | Claude | P1 |

### SPRINT 3: Oct 2–5 (During Phase 3 Testing)

| ID | Task | Est. | Owner | Notes |
|----|------|-----|-------|-------|
| S3-001 | Audio files seeding + CDN setup | 6–8 hrs | Audio team | Defer |
| S3-002 | CI/CD pipeline | 4–6 hrs | DevOps | Defer |
| S3-003 | Accessibility compliance check | 3–4 hrs | QA | Defer |

---

## 🎬 Action Plan: Tonight (Sep 29, 20:30–04:30 UTC)

```
20:30 — START LUDUS-GAME.JS (6–8 hours)
        └─ Create scene with 5 NPCs (visible, clickable)
        └─ Add player HUD (attributes display)
        └─ Wire NPC click → dialogue modal
        
02:30–03:00 — Auth Middleware (2–3 hours)
        └─ Wire middleware to 5 endpoints
        └─ Enable Firestore rules
        
03:00–04:00 — Firestore Rules (1–2 hours)
        └─ Write player data isolation rules
        └─ Write permission checks
        
04:00–04:30 — QA Check
        └─ Compile all code
        └─ Verify no TypeScript errors
        └─ Git commit + push

READY FOR OCT 1 @ 09:00 UTC
```

---

## ✅ Success Criteria for Tonight

By 04:30 UTC Sep 30:

- [ ] ludus-game.js can render 5 NPCs with click detection
- [ ] Clicking NPC loads dialogue modal from API
- [ ] Auth middleware protects API endpoints
- [ ] Firestore rules prevent cross-player data access
- [ ] All code compiles (TypeScript 0 errors)
- [ ] Code committed + pushed to claude/gracious-clarke-36w4kh
- [ ] Phase 3 deployment can proceed Oct 1 @ 09:00

---

## 📊 Summary Statistics

**Total Gaps Found:** 17+  
**Critical Gaps (P0):** 6  
**High Priority (P1):** 6  
**Medium Priority (P2):** 5+  

**Total Effort to Full Completion:** 80–100 hours  
**Effort Tonight (Realistic):** 8–10 hours  
**Effort to Unblock Phase 3:** 30–35 hours  

**Path Forward:**
1. ✅ Tonight: Implement ludus-game.js + auth
2. ✅ Oct 1 AM: Implement Demiurge + test data
3. ✅ Oct 1–5: Phase 3 testing (parallel with offline sync + FSM)
4. ⏳ Oct 2+: Audio files + CI/CD + testing suite

---

**Audit Completed:** 2026-09-29 14:45 UTC  
**Prepared By:** Claude Haiku 4.5  
**Next Review:** Oct 1 @ 09:00 UTC (Pre-deployment validation)
