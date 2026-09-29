# Integration Test Scenarios & Coverage Matrix
## Complete Testing Plan for Phase 3

**Purpose:** Comprehensive test scenarios for all dialogue system interactions  
**Scope:** All 5 API endpoints + data persistence + security  
**Target:** 100% critical path coverage before Phase 3 testing  
**Status:** ✅ Ready for Oct 1  

---

## 📊 Test Coverage Matrix

| # | Scenario | Endpoint(s) | Status | Oct 1? |
|---|----------|------------|--------|--------|
| **TS-001** | Load dialogue tree | getDialogueTree | ✅ Ready | YES |
| **TS-002** | Get first-meeting memory | getNpcMemory | ✅ Ready | YES |
| **TS-003** | Get repeated-meeting memory | getNpcMemory | ✅ Ready | YES |
| **TS-004** | Persist dialogue choice | persistDialogueState | ✅ Ready | YES |
| **TS-005** | Get player stats | getDialogueStats | ✅ Ready | YES |
| **TS-006** | Upsert dialogue tree (admin) | upsertDialogueTree | ✅ Ready | YES |
| **TS-010** | Cross-player access denied | getNpcMemory | ✅ Ready | YES |
| **TS-011** | Admin auth required | upsertDialogueTree | ✅ Ready | YES |
| **TS-020** | Multiple NPCs same player | getDialogueStats | ✅ Ready | YES |
| **TS-021** | Attribute bonus accumulation | persistDialogueState | ✅ Ready | YES |
| **TS-030** | Handle missing parameter | All | ✅ Ready | YES |
| **TS-031** | Handle invalid JSON | All | ✅ Ready | YES |
| **TS-032** | Handle 404 not found | All | ✅ Ready | YES |

---

## 🧪 Detailed Test Scenarios

### Category A: Core Functionality (Happy Path)

---

#### **TS-001: Load Dialogue Tree (Basic)**

**Endpoint:** GET `/api/ludus/dialogue/tree/{npcId}`

**Prerequisites:**
- NPC "elder_sergius" seeded in Firestore

**Test Steps:**
1. Call: `GET http://localhost:5001/api/ludus/dialogue/tree/elder_sergius`
2. Verify response status: 200
3. Verify response structure:
   ```json
   {
     "npcId": "elder_sergius",
     "npcName": "Elder Sergius",
     "theology": "Hesychasm",
     "startNode": "greeting",
     "nodes": [
       { "id": "greeting", "text": "...", "branches": [...] }
     ]
   }
   ```
4. Verify node structure:
   - Each node has: `id`, `text`, `branches[]`
   - Each branch has: `text`, `nextNodeId` (or null), `attributeBonuses`

**Expected Result:** ✅ 200 OK with complete dialogue tree

**Performance:** Should complete in <100ms (p95)

---

#### **TS-002: Get First-Meeting Memory**

**Endpoint:** GET `/api/ludus/dialogue/memory/{npcId}/{playerId}`

**Prerequisites:**
- Player has NOT interacted with NPC before

**Test Steps:**
1. Call: `GET http://localhost:5001/api/ludus/dialogue/memory/elder_sergius/new-player-xyz`
2. Verify response status: 200
3. Verify response for first meeting:
   ```json
   {
     "firstMeeting": true,
     "lastInteraction": undefined,
     "totalInteractions": 0,
     "choiceHistory": []
   }
   ```

**Expected Result:** ✅ 200 OK with firstMeeting flag

**Business Logic:** Next dialogue should play intro sequence

---

#### **TS-003: Get Repeated-Meeting Memory**

**Endpoint:** GET `/api/ludus/dialogue/memory/{npcId}/{playerId}`

**Prerequisites:**
- Player has previously interacted with NPC (memory exists)

**Test Steps:**
1. Pre-populate memory in Firestore:
   ```json
   {
     "firstMeeting": false,
     "lastInteraction": 1704067200000,
     "totalInteractions": 3,
     "choiceHistory": [
       {"nodeId": "greeting", "choice": "Seek wisdom", "timestamp": 1704067200000}
     ]
   }
   ```
2. Call: `GET http://localhost:5001/api/ludus/dialogue/memory/elder_sergius/test-player-001`
3. Verify response includes:
   - `firstMeeting: false`
   - `totalInteractions: 3`
   - `choiceHistory` has previous choices

**Expected Result:** ✅ 200 OK with memory of previous interactions

**Business Logic:** Dialogue can reference prior choices

---

#### **TS-004: Persist Dialogue Choice & Bonuses**

**Endpoint:** POST `/api/ludus/dialogue/state`

**Prerequisites:**
- Test player profile exists in Firestore
- NPC memory exists

**Test Steps:**
1. Call:
   ```bash
   curl -X POST http://localhost:5001/api/ludus/dialogue/state \
     -H "Content-Type: application/json" \
     -d '{
       "playerId": "test-player-001",
       "npcId": "elder_sergius",
       "currentNodeId": "greeting",
       "dialogueHistory": [
         {
           "nodeId": "start",
           "choiceIndex": 0,
           "choiceText": "Seek wisdom",
           "attributeBonuses": {"wisdom": 1},
           "timestamp": 1704067200000
         }
       ],
       "attributeBonuses": {"wisdom": 1}
     }'
   ```
2. Verify response: 200 OK with success flag
3. Verify Firestore writes:
   - Document `ludus_dialogue_states/test-player-001_elder_sergius` created
   - Document `ludus_npc_memory/elder_sergius/players/test-player-001` updated
   - Document `ludus_players/test-player-001` form attributes updated

**Expected Result:** ✅ State persisted, NPC memory updated, player attributes incremented

**Data Verification:**
```javascript
// Check dialogue state saved
db.collection('ludus_dialogue_states')
  .doc('test-player-001_elder_sergius')
  .get()
  .then(doc => {
    assert(doc.data().currentNodeId === 'greeting');
    assert(doc.data().attributeBonusesThisSession.wisdom === 1);
  });

// Check NPC memory updated
db.collection('ludus_npc_memory')
  .doc('elder_sergius')
  .collection('players')
  .doc('test-player-001')
  .get()
  .then(doc => {
    assert(doc.data().totalInteractions === 1);
    assert(doc.data().firstMeeting === false);
  });

// Check player attributes updated
db.collection('ludus_players')
  .doc('test-player-001')
  .get()
  .then(doc => {
    assert(doc.data().form.wisdom >= 1);
  });
```

---

#### **TS-005: Get Player Dialogue Stats**

**Endpoint:** GET `/api/ludus/dialogue/stats/{playerId}`

**Prerequisites:**
- Player has interacted with multiple NPCs
- Dialogue states saved in Firestore

**Test Steps:**
1. Seed dialogue states for player with 3 different NPCs
2. Call: `GET http://localhost:5001/api/ludus/dialogue/stats/test-player-001`
3. Verify response:
   ```json
   {
     "playerId": "test-player-001",
     "npcInteractions": 3,
     "currentAttributes": {
       "wisdom": 7,
       "faith": 6,
       ...
     },
     "totalBonusesEarned": {
       "wisdom": 2,
       "faith": 1
     },
     "dialogueEngagementLevel": "intermediate"
   }
   ```

**Expected Result:** ✅ 200 OK with aggregated stats

**Engagement Level Logic:**
- "beginner" if 0-2 NPCs
- "intermediate" if 3-5 NPCs
- "advanced" if 6+ NPCs

---

#### **TS-006: Upsert Dialogue Tree (Admin)**

**Endpoint:** POST `/api/ludus/dialogue/tree/{npcId}`

**Prerequisites:**
- Valid admin bearer token available
- Admin custom claim set in token

**Test Steps:**
1. Prepare tree data:
   ```json
   {
     "npcName": "Sister Catherine",
     "theology": "Mystical Theology",
     "startNode": "greeting",
     "nodes": [
       {
         "id": "greeting",
         "text": "What does your heart seek?",
         "branches": [...]
       }
     ]
   }
   ```
2. Call:
   ```bash
   curl -X POST http://localhost:5001/api/ludus/dialogue/tree/sister_catherine \
     -H "Authorization: Bearer <valid_admin_token>" \
     -H "Content-Type: application/json" \
     -d '<tree_data>'
   ```
3. Verify response: 200 OK with `{"success": true, "npcId": "sister_catherine"}`
4. Verify Firestore: Document created/updated in `ludus_dialogue_trees/sister_catherine`

**Expected Result:** ✅ 200 OK, tree persisted

---

### Category B: Security & Access Control

---

#### **TS-010: Cross-Player Access Denied**

**Endpoint:** GET `/api/ludus/dialogue/memory/{npcId}/{playerId}`

**Test Scenario:** Player A tries to access Player B's memory

**Test Steps:**
1. Player A (uid="player-a") authenticated
2. Call: `GET /api/ludus/dialogue/memory/elder_sergius/player-b`
   - Request header: `x-firebase-auth-user: player-a`
3. Verify response: 403 Forbidden
4. Verify error message: "Cannot access other player memory"

**Expected Result:** ✅ 403 Forbidden, cross-player access blocked

**Security Validation:**
- [x] Auth user extracted correctly
- [x] Compared to requested playerId
- [x] Mismatch returns 403, not 200

---

#### **TS-011: Admin Auth Required for Tree Upsert**

**Endpoint:** POST `/api/ludus/dialogue/tree/{npcId}`

**Test Cases:**

**TS-011a: No Bearer Token**
- Request: Missing `Authorization` header
- Expected: 401 Unauthorized
- Message: "Unauthorized: Admin token required"

**TS-011b: Invalid/Expired Token**
- Request: `Authorization: Bearer expired_token`
- Expected: 401 Unauthorized
- Message: "Unauthorized: Invalid or expired token"

**TS-011c: Valid Token But Not Admin**
- Request: Valid player ID token (not admin)
- Expected: 403 Forbidden
- Message: "Forbidden: Admin privileges required"

**TS-011d: Valid Admin Token**
- Request: Valid admin token with `admin: true` claim
- Expected: 200 OK, tree created

**Expected Result:** ✅ All three deny scenarios work, admin access granted

---

### Category C: Error Handling

---

#### **TS-030: Missing Required Parameters**

**Test Variants:**

| Endpoint | Missing Param | Expected Status |
|----------|---------------|-----------------|
| getDialogueTree | npcId | 400 |
| getNpcMemory | playerId | 400 |
| getNpcMemory | npcId | 400 |
| persistDialogueState | playerId | 400 |
| persistDialogueState | npcId | 400 |
| persistDialogueState | currentNodeId | 400 |
| getDialogueStats | playerId | 400 |
| upsertDialogueTree | npcId (in path) | 400 |

**Test Example:**
```bash
curl http://localhost:5001/api/ludus/dialogue/tree
# Response: 400 Bad Request
# Body: {"error": "Missing npcId parameter"}
```

**Expected Result:** ✅ All missing parameters return 400

---

#### **TS-031: Malformed JSON**

**Endpoint:** POST endpoints (persistDialogueState, upsertDialogueTree)

**Test Steps:**
1. Send malformed JSON:
   ```bash
   curl -X POST http://localhost:5001/api/ludus/dialogue/state \
     -H "Content-Type: application/json" \
     -d 'not json'
   ```
2. Verify response: 400 Bad Request
3. Verify error message present

**Expected Result:** ✅ 400 Bad Request

---

#### **TS-032: Resource Not Found (404)**

**Test Variants:**

| Endpoint | Nonexistent ID | Expected |
|----------|----------------|----------|
| getDialogueTree | fake_npc_12345 | 404 |
| getDialogueStats | fake_player_99999 | 404 |

**Test Example:**
```bash
curl http://localhost:5001/api/ludus/dialogue/tree/fake_npc
# Response: 404 Not Found
# Body: {"error": "Dialogue tree not found for NPC: fake_npc"}
```

**Expected Result:** ✅ 404 with descriptive message

---

### Category D: Data Integrity & Persistence

---

#### **TS-020: Multiple NPCs Per Player**

**Scenario:** Player interacts with 4 different NPCs

**Test Steps:**
1. Create dialogue states for same player, 4 different NPCs:
   - player-1 + elder_sergius
   - player-1 + theodora
   - player-1 + abba_john
   - player-1 + sister_catherine

2. Call getDialogueStats:
   - Expected `npcInteractions`: 4
   - Expected `dialogueEngagementLevel`: "advanced"

3. Verify each state is independent:
   - Modifying state for elder_sergius doesn't affect theodora state
   - Each NPC memory is separate

**Expected Result:** ✅ 4 interactions tracked, stats aggregated correctly

---

#### **TS-021: Attribute Bonus Accumulation**

**Scenario:** Player receives bonuses from multiple dialogues

**Test Setup:**
1. Dialogue 1: +2 wisdom
2. Dialogue 2: +1 wisdom, +2 faith
3. Dialogue 3: +3 faith

**Test Steps:**
1. Perform dialogue 1 → player.form.wisdom = 5 + 2 = 7
2. Perform dialogue 2 → player.form.wisdom = 7 + 1 = 8, faith = 6 + 2 = 8
3. Perform dialogue 3 → player.form.faith = 8 + 3 = 11
4. Call getDialogueStats
5. Verify totalBonusesEarned: `{wisdom: 3, faith: 5}`
6. Verify currentAttributes: `{wisdom: 8, faith: 11, ...}`

**Expected Result:** ✅ Bonuses accumulate correctly across dialogues

**Data Verification:**
```javascript
const stats = await fetch('/api/ludus/dialogue/stats/test-player-001');
const data = await stats.json();

assert(data.totalBonusesEarned.wisdom === 3);
assert(data.totalBonusesEarned.faith === 5);
assert(data.currentAttributes.wisdom === 8);
assert(data.currentAttributes.faith === 11);
```

---

## 📋 Test Execution Checklist (Oct 1)

**Phase 3B: API Testing (08:00–10:00 UTC)**

**Category A - Core Functionality:**
- [ ] TS-001: Load dialogue tree
- [ ] TS-002: Get first-meeting memory
- [ ] TS-003: Get repeated-meeting memory
- [ ] TS-004: Persist dialogue choice
- [ ] TS-005: Get player stats
- [ ] TS-006: Upsert dialogue tree (admin)

**Category B - Security:**
- [ ] TS-010: Cross-player access denied
- [ ] TS-011: Admin auth required

**Category C - Error Handling:**
- [ ] TS-030: Missing parameters
- [ ] TS-031: Malformed JSON
- [ ] TS-032: Resource not found

**Category D - Data Integrity:**
- [ ] TS-020: Multiple NPCs per player
- [ ] TS-021: Attribute bonus accumulation

**Total Tests:** 13 scenarios  
**Estimated Time:** 90 minutes  
**Pass/Fail Tracking:** Document in PHASE_3_TEST_LOG.md

---

## 🎯 Success Criteria

**All scenarios PASS if:**
- [x] Correct HTTP status codes (200, 400, 401, 403, 404)
- [x] Valid JSON responses
- [x] Data persists to Firestore correctly
- [x] Security boundaries respected
- [x] No unhandled exceptions
- [x] Performance within targets (<300ms p95)

**Any scenario FAILS if:**
- [ ] Wrong HTTP status code
- [ ] Invalid or missing response
- [ ] Data not persisted
- [ ] Security vulnerability
- [ ] Exception/crash
- [ ] Performance >1000ms

---

## 📎 Related Files

- `PHASE_3_DEPLOYMENT_CHECKLIST.md` — Full deployment guide
- `API_ERROR_HANDLING_GUIDE.md` — Error scenarios (10 cases)
- `scripts/test-api-endpoints.sh` — Automated test runner
- `functions/src/tests/api/ludus-dialogue.integration.test.ts` — Jest tests

---

**Status:** ✅ COMPLETE & READY  
**Owner:** Claude Haiku 4.5  
**Next:** Oct 1, 2026 Phase 3 Execution
