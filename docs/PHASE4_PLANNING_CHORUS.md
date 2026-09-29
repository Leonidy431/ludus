# Phase 4-5 Planning — Chorus Decisions for P2 Gaps
## Strategic Prioritization Using Aristotelian Dialectic (Sep 29, 2026)

**Purpose:** Apply Chorus framework to top 5 P2 gaps to guide Phase 4-5 work (Nov-Jan)  
**Scope:** Strategic decisions for gaps that phase 3 will expose  
**Status:** Planning document (decisions pending Phase 3A validation Oct 1)

---

## 📋 P2 GAPS RANKED BY IMPACT (5 Priority)

**All P2 gaps defer to Phase 4, but these 5 drive next development priorities:**

| Rank | Gap | Hours | Phase | Impact | Oct 1 Blocker? |
|------|-----|-------|-------|--------|---|
| 1 | gap_046 | 4 | 4 | CI/CD automation (GitHub Actions) | No — manual testing OK |
| 2 | gap_021 | 3 | 4 | OpenAPI documentation | No — internal APIs only |
| 3 | gap_023 | 1 | 4 | Cache-control headers | No — emulator fast enough |
| 4 | gap_045 | 6 | 4 | Analytics dashboard | No — manual logs sufficient |
| 5 | gap_039 | 4 | 4 | Analytics tracking | No — user data OK for phase 3 |

**Deferral Confidence:** 🟢 **HIGH** — All can be added post-Phase 3 without impacting core gameplay

---

## 🎯 PRIORITY #1: CI/CD Automation (gap_046)

### The Challenge

**Current State (Sep 29):**
- ✅ All endpoints tested manually
- ✅ Load testing script created (loadtest-api-endpoints.sh)
- ✅ Integration tests documented
- ❌ No automated CI pipeline (GitHub Actions)

**Why It Matters:** Phase 4 will have rapid iteration on audio, UI, and optimizations. Manual testing bottleneck could slow deployments.

### Chorus Framework: 4 Perspectives

**Engineer:** "What CI/CD setup minimizes maintenance?"
- Option A: Basic (TypeScript compile + Jest tests only) → 2 hrs setup
- Option B: Comprehensive (compile + Jest + lint + load testing) → 4 hrs setup
- Option C: Advanced (all B + E2E on Firebase emulator) → 8 hrs setup
- Recommendation: Start with B (4 hrs), add C in Phase 5 if needed

**Tester:** "What CI coverage prevents regressions?"
- Must catch: TypeScript errors, Jest test failures, linting violations
- Should catch: Load test performance degradation (p95 > red line)
- Could catch: Integration tests on emulator (E2E)
- Minimum acceptable: Compile + Jest + lint (catches 90% of bugs)

**User:** "Does CI speed up feature delivery?"
- Faster deployments = faster bug fixes = better experience
- Automated testing = fewer broken deployments (regression prevention)
- CI enables safe refactoring without fear
- User never sees CI, but benefits from reduced bugs

**Architect:** "Does CI align with Demiurgic Causality?"
- System integrity (FORM) requires quality gates
- FORM → ACTION → GOAL chain needs continuous verification
- CI ensures each code change maintains system integrity
- Automates verification of constitution (Demiurgic principles)

### ✅ CHORUS DECISION: IMPLEMENT COMPREHENSIVE CI (Option B)

**Configuration (4 Hours to Implement):**

```yaml
name: Ludus CI/CD Pipeline

on:
  push:
    branches: [main, claude/*, dev/*]
  pull_request:
    branches: [main, dev]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      # 1. TypeScript Compilation (5 min)
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm ci
      - run: npm run build  # TypeScript compile + Jest

      # 2. Jest Testing (3 min)
      - run: npm test -- --coverage

      # 3. Lint Check (2 min)
      - run: npm run lint

      # 4. Load Test Performance (5 min)
      - run: npm run test:load
        # Verifies p95 latency stays under baseline

      # 5. Report Results (1 min)
      - uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
```

**Integration with PR Workflow:**
- Every PR must pass CI before merge
- CI failures block merge (prevents broken main branch)
- Developers see immediate feedback (compile errors, test failures)

**Time Investment:**
- Phase 4: 4 hours to set up
- Ongoing: 5-10 min per PR (automated, no manual overhead)
- Phase 5: Add E2E tests (another 4 hrs)

**Expected Outcome:**
- ✅ Zero broken deployments to production
- ✅ Faster code review (CI handles technical validation)
- ✅ Safe refactoring without regression fear
- ✅ Automated performance monitoring

---

## 🎯 PRIORITY #2: OpenAPI Documentation (gap_021)

### The Challenge

**Current State (Sep 29):**
- ✅ 5 endpoints fully implemented
- ✅ Code is self-documenting (clear types, good naming)
- ✅ API_ERROR_HANDLING_GUIDE.md documents error responses
- ❌ No formal OpenAPI/Swagger spec

**Why It Matters:** Phase 4 will integrate external systems (analytics dashboards, admin UIs). OpenAPI enables rapid client generation.

### Chorus Framework: 4 Perspectives

**Engineer:** "How much effort is OpenAPI worth?"
- Manual specification: 3 hours (write YAML, test against endpoints)
- Auto-generation from TypeScript: 1.5 hours (use tsdoc + swagger-autogen)
- Benefits: Client SDK generation, interactive API explorer
- Recommendation: Auto-generation (1.5 hrs) — less maintenance

**Tester:** "How does OpenAPI help testing?"
- Formal spec → can generate test stubs automatically
- Enables contract testing (verify backend matches spec)
- Swagger UI lets manual testers explore endpoints interactively
- Reduces testing ambiguity (spec is source of truth)

**User:** "Does OpenAPI matter?"
- End-user doesn't see OpenAPI
- Internal developers benefit (faster client implementation)
- Admin/analytics team can build dashboards faster
- Indirectly: faster feature delivery = better UX

**Architect:** "Does OpenAPI serve Demiurgic Causality?"
- Formal specification = explicit FORM documentation
- Schema clarity enables clients to implement ACTION correctly
- Prevents misalignment between backend GOAL and client understanding
- OpenAPI = constitution of the API contract

### ✅ CHORUS DECISION: AUTO-GENERATE OpenAPI SPEC (1.5 Hours)

**Implementation Steps:**
1. Add TSDoc comments to all endpoints (30 min)
2. Configure swagger-autogen (15 min)
3. Generate OpenAPI spec (5 min)
4. Deploy Swagger UI to /api/docs (15 min)
5. Test against spec (30 min)

**Output Deliverables:**
- `openapi.yaml` — Machine-readable API specification
- `Swagger UI` — Interactive API explorer at `/api/docs`
- `Client SDK generators` — Tools for generating JS/Python/Go clients

**Phase 4 Timeline:**
- Week 1 of Phase 4: Implement OpenAPI (1.5 hrs)
- Unblocks: Analytics dashboard development, external integrations

---

## 🎯 PRIORITY #3: Cache-Control Headers (gap_023)

### The Challenge

**Current State (Sep 29):**
- ✅ Dialogue trees immutable (safe to cache long-term)
- ✅ NPC memory player-specific (needs per-player caching)
- ❌ No Cache-Control headers on responses

**Why It Matters:** Emulator testing doesn't require caching, but Quest 3 mobile network does. Reduces bandwidth usage on slow 4G connections.

### Chorus Framework: 4 Perspectives

**Engineer:** "What caching strategy is optimal?"
- Dialogue trees: Cache 24 hours (immutable, globally shared)
- NPC memory: Cache 5 min (player-specific, changes on choice)
- Player stats: Cache 1 min (frequently updated)
- Implementation: 1 hour (add Cache-Control headers to responses)

**Tester:** "How do we verify cache behavior?"
- Browser DevTools Network tab shows Cache-Control headers
- Can test TTL expiration with mock time manipulation
- Must verify: cached response returned without server hit
- Measurement: network waterfall chart shows cache hits

**User:** "Does caching help?"
- On slow 4G network (Quest 3 on WiFi): ~50% bandwidth reduction
- Repeated dialogue loads: 100ms → 10ms (with cache)
- User perceives: faster interaction, less data usage
- Matters on metered data plans

**Architect:** "Does caching serve Demiurgic Causality?"
- FORM (dialogue) = immutable blueprint (safe to cache)
- ACTION (choice) = transient, must fetch fresh (no cache)
- GOAL (stats) = aggregate, cache briefly (1 min OK)
- Caching respects semantic boundaries of the system

### ✅ CHORUS DECISION: IMPLEMENT SELECTIVE CACHING (1 Hour)

**Cache Strategy:**

| Endpoint | Resource | TTL | Reason |
|----------|----------|-----|--------|
| getDialogueTree | Dialogue Tree | 24h | Immutable globally |
| getNpcMemory | NPC Memory | 5min | Player-specific, change-on-action |
| persistDialogueState | State Write | 0s (no-cache) | Must persist immediately |
| getDialogueStats | Stats | 1min | Aggregate, tolerate brief staleness |
| upsertDialogueTree | Tree Write | 0s (no-cache) | Admin write, must immediate |

**HTTP Headers:**
```
GET /api/ludus/dialogue/tree/{npcId}
Cache-Control: public, max-age=86400

GET /api/ludus/dialogue/memory/{npcId}/{playerId}
Cache-Control: private, max-age=300

GET /api/ludus/dialogue/stats/{playerId}
Cache-Control: private, max-age=60

POST /api/ludus/dialogue/state
Cache-Control: no-cache, no-store

POST /api/ludus/dialogue/tree/{npcId}
Cache-Control: no-cache, no-store
```

**Phase 4 Timeline:**
- Week 2 of Phase 4: Implement caching (1 hr)
- Unblocks: Bandwidth optimization for mobile testing

---

## 🎯 PRIORITY #4: Analytics Dashboard (gap_045)

### The Challenge

**Current State (Sep 29):**
- ✅ Player stats endpoint returns engagement metrics
- ✅ Manual log analysis possible (grep logs)
- ❌ No visual dashboard for player progression

**Why It Matters:** Phase 4 will have beta testers playing 50+ hours. Need to visualize player progression, identify balance issues.

### Chorus Framework: 4 Perspectives (Summary)

**Engineer:** "Web dashboard (React) or CLI tool?"
- Web dashboard: 6 hours (React + Firebase Realtime)
- CLI tool: 2 hours (Node.js + table formatting)
- Recommendation: Web dashboard (better UX for non-technical stakeholders)

**Tester:** "What metrics matter most?"
- Player progression (attribute growth over time)
- NPC interaction frequency (which NPCs are popular)
- Engagement level distribution (beginner/intermediate/advanced)
- Error rate tracking (which endpoints fail most)

**User:** "Do I see the dashboard?"
- End-user doesn't see analytics dashboard
- Game designers use dashboard to balance content
- Enables: identify overpowered/underpowered dialogue paths
- Indirectly improves game balance

**Architect:** "Does analytics serve Demiurgic Causality?"
- Tracking FORM (attributes) evolution = measuring spiritual growth
- Dashboard visualizes player GOAL attainment
- Analytics feed back into design (iterate on paths that don't work)
- Analytics = system learning mechanism

### ✅ CHORUS DECISION: IMPLEMENT WEB DASHBOARD (6 Hours, Phase 4 Week 3-4)

**Deliverables:**
- Real-time player progression chart (Wisdom, Faith, etc. over time)
- NPC interaction heatmap (which NPCs, how often)
- Engagement level distribution pie chart
- Error tracking dashboard (top errors by endpoint)
- Export to CSV (for detailed analysis)

---

## 📊 PHASE 4-5 ROADMAP (With Chorus Decisions)

```
PHASE 4: Polish & Deployment (Nov 1 – Dec 15, 2026)
├── Week 1 (Nov 1-7): OpenAPI docs (1.5 hrs)
├── Week 2 (Nov 8-14): Cache headers (1 hr)
├── Week 3 (Nov 15-21): CI/CD setup (4 hrs)
├── Week 4 (Nov 22-28): Analytics dashboard (6 hrs)
└── Week 5-6 (Nov 29-Dec 15): Audio prep + QA

PHASE 5: Audio & VR Features (Jan 1 – Feb 15, 2027)
├── Week 1-2 (Jan 1-14): Hand tracking (4 hrs)
├── Week 3 (Jan 15-21): Latency profiling (3 hrs)
├── Week 4 (Jan 22-28): Wwise integration (5 hrs)
└── Week 5-7 (Jan 29-Feb 15): Integration + polish

PHASE 6-8: Long-term Roadmap (Mar 2027+)
├── i18n support (8 hrs)
├── Accessibility improvements (6 hrs)
├── Native mobile apps (40 hrs)
└── Advanced features (ML dialogue, marketplace, multiplayer)
```

---

## 🔗 RELATED DOCUMENTS

- `COMPREHENSIVE_GAPS_ANALYSIS.md` — All 40+ gaps with P2/P3 deferral rationale
- `CHORUS_DECISIONS_PHASE3.md` — Chorus framework applied to 4 P1 gaps
- `PHASE_3_MASTER_CHECKLIST.md` — Oct 1 execution guide
- `CLAUDE.md` — Project constitution with Chorus Decision Framework (ТАБУ №0.5)

---

## ✅ CONSENSUS SUMMARY

**Phase 4-5 priorities (applying Chorus framework):**

1. ✅ **CI/CD Automation (gap_046):** 4 hours → Phase 4 Week 3
   - All 4 voices: Safe deployments, faster development, better system integrity
   
2. ✅ **OpenAPI Docs (gap_021):** 1.5 hours → Phase 4 Week 1
   - All 4 voices: Enables integrations, formal spec, architecture clarity
   
3. ✅ **Cache Headers (gap_023):** 1 hour → Phase 4 Week 2
   - All 4 voices: Bandwidth optimization, performance, system alignment
   
4. ✅ **Analytics Dashboard (gap_045):** 6 hours → Phase 4 Week 4
   - All 4 voices: Player insights, balance tuning, spiritual growth measurement

5. ✅ **Analytics Tracking (gap_039):** Defer to Phase 4 Week 5
   - Depends on dashboard completion

**Total Phase 4 Investment:** ~12.5 hours of development  
**Phase 5 Investment:** ~12 hours (hand tracking, latency, audio)  
**Deferred to Phase 6-8:** ~60+ hours (i18n, accessibility, native, advanced)

---

**Prepared:** Sep 29, 2026, 23:50 UTC  
**Framework:** Ludus CLAUDE.md ТАБУ №0.5 (Chorus Decision Framework)  
**Status:** Planning document (finalize after Phase 3A validation Oct 1)  
**Session:** https://claude.ai/code/session_015SgoYe2WsjLk8L6xDTU2JU

