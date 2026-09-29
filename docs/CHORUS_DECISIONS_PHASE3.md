# Chorus Decision Framework — Phase 3 Critical Decisions
## Applied Aristotelian Dialectic to 4 Blocking Gaps (Sep 29, 2026)

**Purpose:** Document how 4 P1 blocking gaps were resolved using chorus framework (4 perspectives synthesized into one correct decision)  
**Scope:** Gaps 014, 016, 011, 012 — the blockers for Phase 3 testing  
**Status:** All 4 decisions finalized with full consensus

---

## 📋 CHORUS DECISION FRAMEWORK

**Principle:** Every critical decision involves 4 voices (perspectives):
1. **Engineer (Инженер):** "How do we implement this optimally from a technical perspective?"
2. **Tester (Тестировщик):** "How do we verify this thoroughly without blind spots?"
3. **User (Пользователь):** "What does this mean for the player/end-user experience?"
4. **Architect (Архитектор):** "How does this fit into Demiurgic Causality and the 32-parameter system?"

**Binding Rule:** Decision is correct when:
- All 4 voices are heard
- One clear choice emerges that satisfies all 4 perspectives
- The choice is documented with "WHY" (reasons), not just "WHAT" (facts)

---

## 🎯 DECISION #1: Test Data Volume (gap_014)

### The Question
**Engineer:** "Should we seed 10 baseline test players or 20?"
- 10 players = faster test runs (5 min vs 10 min per full cycle)
- 20 players = more data collection, better edge-case detection

**Tester:** "How many players do we need to find all edge cases?"
- 10 baseline + 10 edge cases = 20 total minimum
- Must cover: max wisdom (14+), min wisdom (<4), mixed attributes, high cunning, etc.
- Without edge cases, will miss corner cases in Phase 3

**User:** "Does the player notice test data volume?"
- No. Player sees only one dialogue tree at a time
- Volume doesn't impact UX quality during Phase 3
- Player wants error-free experience, not test volume

**Architect:** "Does Demiurgic Causality guide us here?"
- FORM (Attributes) → ACTION (Behavior) → GOAL (Spiritual Teaching)
- Testing must verify all FORM variations to ensure ACTION/GOAL work correctly
- 20 players = test all attribute combinations (FORM diversity)
- Aligns with principle: complete spiritual growth paths need complete test coverage

### ✅ DECISION: TAKE 20 PLAYERS

**Consensus Rationale:**
```
Engineer accepts: 10 min extra per test cycle is acceptable cost for robustness
Tester gets: All edge cases covered (max wisdom, min wisdom, balanced, cunning-high)
User benefits: Fewer bugs during Phase 3 testing (better stability)
Architect confirms: 20 players = complete FORM testing = complete system validation
```

**Implementation Details:**
- 10 baseline players: Wisdom 5-8, Faith 6-7, balanced attributes
- 10 edge cases:
  - Player-max-wisdom: Wisdom 14, Faith 4 (tests high-wisdom dialogue paths)
  - Player-min-wisdom: Wisdom 2, Faith 10 (tests low-wisdom restrictions)
  - Player-balanced-high: Wisdom 7, Faith 7, Constitution 7 (mid-range, stable)
  - Player-high-constitution: Wisdom 5, Constitution 12 (tests endurance gating)
  - Player-high-cunning: Wisdom 6, Cunning 10 (tests restricted paths)
  - Player-high-charisma: Charisma 11, Wisdom 6 (tests leadership gating)
  - Plus 4 more for multi-attribute combinations

**Delivered:** ✅ seedComprehensiveTestData.ts (400 lines, all 20 players seeded)

---

## 🎯 DECISION #2: Performance Baseline & Targets (gap_016)

### The Question
**Engineer:** "What latency targets can we achieve?"
- Dialogue tree load: 50ms is optimistic (Firestore + network = ~100-150ms typical)
- NPC memory fetch: 30ms is aggressive (nested collection query)
- Choice persistence: 150ms minimum (3 database operations)

**Tester:** "How do we verify targets without Quest 3 device?"
- Can measure on emulator (Firebase emulator is accurate for latency)
- Can't guarantee Quest 3 network variability
- Need baselines now, verify on real device Oct 1
- Measurement methodology: console.time() + performance instrumentation

**User:** "What latency matters to the player?"
- <300ms = feels instant (player doesn't notice delay)
- 300-500ms = perceptible delay (player feels lag, but acceptable)
- >500ms = bad (player gets frustrated, questions if game broke)

**Architect:** "Does latency affect Demiurgic Causality?"
- FORM → ACTION → GOAL mapping requires rapid response
- Delayed ACTION breaks the player's spiritual immersion
- Latency is not just technical; it's part of the experience design
- <500ms latency = preserves contemplative flow
- >500ms latency = breaks immersion

### ✅ DECISION: TARGET <300ms (AGGRESSIVE) WITH <500ms AS RED LINE

**Consensus Rationale:**
```
Engineer accepts: Aggressive targets drive optimization
  (Use transaction batching, response caching for repeated trees)
Tester gets: Measurable targets + fallback threshold
  (Baseline now on emulator; verify Oct 1 on Quest 3)
User benefits: Snappy dialogue interactions = better immersion
Architect confirms: <300ms preserves contemplative FORM→ACTION→GOAL flow
```

**Measurement Plan:**
```
Endpoint Target    P50    P95    P99    Red Line
─────────────────────────────────────────────────
getDialogueTree    50ms  100ms  150ms  500ms
getNpcMemory       30ms   75ms  150ms  500ms
persistDialogueState 150ms 250ms 400ms 800ms
getDialogueStats   100ms  200ms  350ms  600ms
```

**Delivered:** ✅ PERFORMANCE_PROFILING_BASELINE.md (329 lines, targets + VR specs + measurement methodology)

---

## 🎯 DECISION #3: Error Handling Coverage (gap_011)

### The Question
**Engineer:** "How many error scenarios should we handle?"
- Core errors (network, 404, 500) = 3 required
- Plus validation (400 bad request) = 4 critical
- Extended errors (auth, timeout, malformed data) = 7-10 scenarios
- Total: 10 comprehensive scenarios

**Tester:** "Will 10 scenarios find all bugs?"
- Phase 3 testing will hit: network failures, missing NPCs, data races, auth issues
- Each error needs: status code + context + recovery hint
- Without comprehensive handling, player sees generic "Something broke"
- Need specific error types so we can debug Oct 1

**User:** "What error messages help me?"
- "Connection error" = too generic
- "Failed to load elder_sergius dialogue. Check your internet or try restarting." = helpful
- Recovery hints matter more than error codes
- Player should never see status codes (500, 403, etc.) — only friendly messages

**Architect:** "Does error handling serve Demiurgic Causality?"
- FORM → ACTION → GOAL requires resilience
- Errors are "failures in causality" — when FORM can't produce ACTION
- Graceful error recovery = system maintains spiritual integrity
- Error messages guide the player back to the path

### ✅ DECISION: IMPLEMENT 10 COMPREHENSIVE ERROR SCENARIOS

**Consensus Rationale:**
```
Engineer accepts: 10 scenarios = good coverage/complexity ratio
  (More is diminishing returns; fewer misses critical cases)
Tester gets: All error paths documented with curl test commands
  (Can reproduce, verify, and measure error handling latency)
User benefits: Clear recovery paths instead of cryptic errors
  (e.g., "Verify NPC is available" instead of "404")
Architect confirms: Graceful error recovery maintains system integrity
  (FORM→ACTION continues even on partial failures)
```

**Error Scenarios (10 Total):**
1. **404 Not Found** — NPC dialogue tree missing
   - Context: npcId, timestamp, device type
   - Recovery: "Verify NPC available", "Reload scene", "Check internet"

2. **403 Forbidden** — Player accessing other player's memory
   - Context: playerId, authUser, attempt timestamp
   - Recovery: "Log in with correct account"

3. **401 Unauthorized** — Missing/expired admin token for upsert
   - Context: endpoint, token status, timestamp
   - Recovery: "Obtain admin credentials"

4. **400 Bad Request** — Missing required fields (playerId, npcId, etc.)
   - Context: missing field names
   - Recovery: "Check request format"

5. **500 Internal Server Error** — Firestore write fails
   - Context: collection, operation (set/update), error type
   - Recovery: "Try again in a moment"

6. **Network Timeout** — Cloud Function unreachable
   - Context: endpoint, timeout duration, retries attempted
   - Recovery: "Check internet connection", "Retry"

7. **CORS Preflight Failure** — Browser blocks cross-origin request
   - Context: origin, method, headers
   - Recovery: "Ensure CORS headers present" (server-side only)

8. **Malformed JSON** — Request body is invalid JSON
   - Context: position in JSON where parse failed
   - Recovery: "Check request format"

9. **Transaction Conflict** — Firestore transaction aborts
   - Context: conflicting fields, retry count
   - Recovery: "Automatic retry (hidden from user)"

10. **Rate Limit** — Too many requests in short time
    - Context: endpoint, rate limit threshold, reset time
    - Recovery: "Try again after [X] seconds"

**Delivered:** ✅ API_ERROR_HANDLING_GUIDE.md (476 lines, curl test commands for all 10 scenarios)

---

## 🎯 DECISION #4: Integration Test Scenarios (gap_012)

### The Question
**Engineer:** "How many integration test scenarios do we need?"
- Minimal: 5 core flows (load dialogue, fetch memory, persist choice, get stats, error handling)
- Standard: 8 flows (add offline sync, CORS preflight, mobile responsiveness)
- Comprehensive: 13 flows (add concurrent calls, state consistency, edge cases)

**Tester:** "What coverage do we need for Phase 3?"
- Must verify all 5 API endpoints work end-to-end
- Must test interactions between endpoints (e.g., persist choice → stats change)
- Must test edge cases (offline mode, concurrent choices, network errors)
- Must measure performance under load
- Need full coverage before real Quest 3 testing Oct 1

**User:** "Do I care about all these tests?"
- No, but player cares that: dialogue loads, choices stick, stats update, errors are clear
- Each integration test = one player-facing flow
- 13 flows = full game session coverage

**Architect:** "Does system architecture require this coverage?"
- Demiurgic Causality = FORM (attributes) → ACTION (dialogue choice) → GOAL (spiritual growth)
- Each ACTION must persist and flow to GOAL
- 13 scenarios = verify all FORM/ACTION/GOAL chains
- Must test: dialogue tree loading (ACTION foundation)
- Must test: choice persistence (ACTION → GOAL bridge)
- Must test: stats aggregation (GOAL measurement)

### ✅ DECISION: IMPLEMENT 13 FULL INTEGRATION TEST SCENARIOS

**Consensus Rationale:**
```
Engineer accepts: 13 scenarios = comprehensive without bloat
  (Each scenario tests distinct interaction pattern)
Tester gets: All flows documented with code examples + curl commands
  (10-minute checklist, repeatable and measurable)
User benefits: Full game session tested = no surprises on Oct 1
Architect confirms: 13 scenarios = complete Demiurgic Causality verification
  (All FORM→ACTION→GOAL chains covered)
```

**Integration Scenarios (13 Total):**

| ID | Scenario | Tests | Duration |
|----|----------|-------|----------|
| INT-001 | Dialogue Loading | getDialogueTree latency, response structure | 60s |
| INT-002 | NPC Memory Fetch | getNpcMemory, first-meeting detection | 30s |
| INT-003 | Choice Persistence | persistDialogueState, attribute updates | 2min |
| INT-004 | Stats Display | getDialogueStats aggregation | 1min |
| INT-005 | Error Recovery | 404 handling, recovery hints | 2min |
| INT-006 | CORS Preflight | OPTIONS request, CORS headers | 1min |
| INT-007 | Offline Sync | WiFi toggle, queue persistence | 2min |
| INT-008 | Mobile Responsiveness | Quest 3 resolution (1832×1920) | 1min |
| INT-009 | Concurrent Choices | 2+ players choosing simultaneously | 2min |
| INT-010 | State Consistency | Choice A → attribute change, stats update | 1.5min |
| INT-011 | Admin Upsert | upsertDialogueTree with auth validation | 1.5min |
| INT-012 | Performance Load | 50 concurrent requests, p95 latency | 5min |
| INT-013 | Full Session Flow | Login → load dialogue → 3 choices → view stats | 10min |

**Delivered:** ✅ FRONTEND_BACKEND_INTEGRATION_TESTING.md (400 lines, code examples + curl commands)

---

## 📊 CHORUS DECISION SUMMARY TABLE

| Gap | Decision | Engineer | Tester | User | Architect | Outcome |
|-----|----------|----------|--------|------|-----------|---------|
| **gap_014** | 20 players (10 baseline + 10 edge cases) | ✅ Accept 10min extra | ✅ All edge cases | ✅ No UX impact | ✅ Complete FORM testing | **APPROVED** |
| **gap_016** | <300ms target, <500ms red line | ✅ Aggressive targets drive optimization | ✅ Measurable + fallback | ✅ Snappy UX | ✅ Preserves immersion | **APPROVED** |
| **gap_011** | 10 comprehensive error scenarios | ✅ Good coverage ratio | ✅ All paths testable | ✅ Clear recovery hints | ✅ System resilience | **APPROVED** |
| **gap_012** | 13 integration test scenarios | ✅ Complete without bloat | ✅ Full coverage | ✅ Full game session | ✅ All ACTION→GOAL chains | **APPROVED** |

---

## 🔗 RELATED DOCUMENTS

- `docs/reports/COMPREHENSIVE_GAPS_ANALYSIS.md` — Full gap audit with status tracking
- `docs/reports/PHASE_3_MASTER_CHECKLIST.md` — Oct 1 deployment checklist
- `docs/reports/PHASE_3_QUEST3_TESTING_CHECKLIST.md` — Quest 3 real device testing
- `API_ERROR_HANDLING_GUIDE.md` — 10 error scenarios with curl tests
- `PERFORMANCE_PROFILING_BASELINE.md` — Latency targets + measurement methodology
- `FRONTEND_BACKEND_INTEGRATION_TESTING.md` — 13 integration test scenarios
- `CLAUDE.md` — Project constitution with Chorus Decision Framework (ТАБУ №0.5)

---

## ✅ CONCLUSION

**All 4 P1 blocking gaps resolved using Chorus framework:**
- 25+ total gaps FIXED (7 P0 + 10 P1 + 8 P2 integration)
- 100% consensus across 4 perspectives (Engineer, Tester, User, Architect)
- Zero blockers remain for Oct 1 Phase 3 testing
- Full documentation enables Oct 1 execution without surprises

**Next Phase:** Apply Chorus framework to P2 gaps during Phase 4-5 planning (gap_021 OpenAPI, gap_023 Cache headers, gap_046 CI/CD automation)

---

**Prepared:** Sep 29, 2026, 23:45 UTC  
**Framework Alignment:** Ludus CLAUDE.md ТАБУ №0.5 (Chorus Decision Framework)  
**Session:** https://claude.ai/code/session_015SgoYe2WsjLk8L6xDTU2JU

