# Phase 3: Deployment Checklist
## Oct 1, 2026 | 06:00–12:00 UTC | Full Validation & Go/No-Go Decision

**Purpose:** Step-by-step verification of all Phase 3 readiness criteria before production deployment  
**Owner:** Claude Haiku 4.5  
**Status:** READY FOR EXECUTION  
**Total Time:** 6.5 hours (06:00–12:30 UTC)  
**Decision Point:** 11:00 UTC — GO or NO-GO to Phase 3 testing

---

## 📋 Pre-Session Checklist (05:45 UTC)

Before starting Phase 3A, verify:

- [ ] This file exists: `/ludus/PHASE_3_DEPLOYMENT_CHECKLIST.md`
- [ ] Backlog exists: `/ludus/PHASE_3_FINAL_BACKLOG.md`
- [ ] Scripts executable: `./scripts/phase3-validation.sh` and `./scripts/test-api-endpoints.sh`
- [ ] Test fixtures exist: `functions/src/tests/fixtures/players.json` (10 players)
- [ ] Performance instrumentation added: `functions/src/api/ludus-dialogue.ts` (console.time/timeEnd)
- [ ] Firestore rules updated: `firestore.rules` (all dialogue collections)
- [ ] Jest config exists: `functions/jest.config.js`
- [ ] Local dev guide exists: `docs/version-3.0/LOCAL_DEV_SETUP.md`
- [ ] Web entry point exists: `public/index.html`
- [ ] CSS files present: `public/ludus/ludus-*.css` (2+ files)

**If any checked items are missing:** DO NOT PROCEED. See "Remediation" section below.

---

## 🔧 Phase 3A: Final Validation (06:00–08:00 UTC, 2 hours)

### 3A.1: TypeScript Compilation Check (15 min)

**Objective:** Verify backend code compiles without errors

**Command:**
```bash
cd ludus/functions
npm run build
```

**Expected Output:**
```
> ludus-functions@0.1.0 build
> tsc

(no errors)
```

**Validation Checklist:**
- [ ] Exit code is 0 (success)
- [ ] No "error TS" lines in output
- [ ] Output ends with blank line (successful completion)
- [ ] lib/ directory created with compiled .js files

**If Errors:**
1. Review error output line by line
2. Check files: `functions/src/api/ludus-dialogue.ts`, `functions/src/index.ts`
3. Look for: Type mismatches, undefined references, import issues
4. **Critical:** Do not proceed past 3A.1 if build fails
5. Document error in `PHASE_3_DEPLOYMENT_NOTES.md`

**Evidence:**
- Capture build output: `npm run build 2>&1 | tee /tmp/build-output.log`
- Record timestamp and exit code

---

### 3A.2: Jest Test Runner Verification (15 min)

**Objective:** Verify Jest can discover and list tests (dry-run only)

**Command:**
```bash
cd ludus/functions
npm test -- --listTests
```

**Expected Output:**
```
PASS  src/tests/api/ludus-dialogue.integration.test.ts
```

**Validation Checklist:**
- [ ] Jest launches without errors
- [ ] `ludus-dialogue.integration.test.ts` appears in output
- [ ] No "Cannot find" errors
- [ ] No TypeScript compilation errors during test discovery

**If Jest Fails:**
1. Check `jest.config.js` exists and has correct ts-jest preset
2. Verify `tsconfig.json` is present
3. Check all test files have `.test.ts` extension
4. Document issue in `PHASE_3_DEPLOYMENT_NOTES.md`

**Evidence:**
- Record Jest version: `npm test -- --version`
- List discovered tests: `npm test -- --listTests`

---

### 3A.3: Firestore Rules Syntax Validation (15 min)

**Objective:** Validate firestore.rules has correct syntax (dry-run)

**Command:**
```bash
firebase deploy --only firestore:rules --dry-run
```

**Expected Output:**
```
✓ Deploy complete!
Dry run successful, no changes will be made.
```

**Validation Checklist:**
- [ ] Exit code is 0
- [ ] "Dry run successful" appears in output
- [ ] No "syntax error" or "Parse error" lines
- [ ] No "Invalid rule" errors

**If Rules Validation Fails:**
1. Open `firestore.rules` in editor
2. Check syntax: `rules_version = '2';` on line 1
3. Verify all `match /collection/{path} {` blocks have closing `}`
4. Check helper functions: `function isAdmin()`, `function isAuthenticated()`
5. Document error details and line numbers
6. **Do not proceed** until rules validate

**Collections Verified in firestore.rules:**
- [ ] `ludus_nodes` — Demiurge graph nodes
- [ ] `ludus_edges` — Demiurge graph edges
- [ ] `ludus_knowledge_gates` — Knowledge tests
- [ ] `ludus_gate_attempts` — Player submissions
- [ ] `ludus_dialogue_trees` — Dialogue content
- [ ] `ludus_players` — Player profiles
- [ ] `ludus_npc_memory` — NPC interaction history
- [ ] `ludus_dialogue_states` — Dialogue session history
- [ ] `ludus_demiurge_nodes` — Demiurge simulation
- [ ] `ludus_demiurge_edges` — Demiurge simulation edges
- [ ] `ludus_rov_telemetry` — ROV dive data

---

### 3A.4: Test Fixtures Creation & Verification (30 min)

**Objective:** Verify test fixtures are in place and correctly structured

**Files to Check:**

**A. Player Fixtures** (`functions/src/tests/fixtures/players.json`)
```bash
cat functions/src/tests/fixtures/players.json | jq 'length'
```

**Expected:** 10 players

**Validation Checklist:**
- [ ] File exists and is valid JSON (no parse errors)
- [ ] Exactly 10 player objects
- [ ] Each player has: `playerId`, `name`, `form` (attributes), `actions`, `goal`
- [ ] All attribute arrays contain 7 attributes: wisdom, faith, dexterity, constitution, charisma, cunning, erudition
- [ ] Player IDs range: `test-player-001` through `test-player-010`
- [ ] Sample player 001 has Wisdom=3, Faith=5 (novice)
- [ ] Sample player 010 has Wisdom=11, Faith=9 (advanced)

**Quick Check Command:**
```bash
jq '.[] | {id: .playerId, wisdom: .form.wisdom, faith: .form.faith, engagement: .goal.enlightenmentLevel}' functions/src/tests/fixtures/players.json
```

**B. Dialogue Paths Fixture** (`functions/src/tests/fixtures/dialogue-paths.json`)
```bash
cat functions/src/tests/fixtures/dialogue-paths.json | jq 'keys'
```

**Expected:** `["faith_path", "practice_path", "wisdom_path"]`

**Validation Checklist:**
- [ ] File exists and is valid JSON
- [ ] Contains exactly 3 paths: wisdom_path, faith_path, practice_path
- [ ] Each path has: `name`, `description`, `attributeFocus`, `minRequired*`, `dialogueTree`, `testCases`
- [ ] wisdom_path: min Wisdom 8
- [ ] faith_path: min Faith 7
- [ ] practice_path: min Constitution 6
- [ ] Each path has 3+ test cases
- [ ] Test cases include: expected outcome, bonus amount, description

**Quick Check Command:**
```bash
jq '.[] | {path: .name, required: .minRequiredWisdom // .minRequiredFaith // .minRequiredConstruction, testCases: (.testCases | length)}' functions/src/tests/fixtures/dialogue-paths.json
```

**Evidence:**
- Save JSON validation output: `jq . functions/src/tests/fixtures/*.json > /tmp/fixture-validation.txt`

---

### 3A.5: Performance Instrumentation Verification (15 min)

**Objective:** Verify all 5 API endpoints have performance instrumentation

**Check 1: console.time calls**
```bash
grep -n "console.time" functions/src/api/ludus-dialogue.ts
```

**Expected:** 5 matches (one per endpoint)

**Check 2: console.timeEnd calls**
```bash
grep -n "console.timeEnd" functions/src/api/ludus-dialogue.ts
```

**Expected:** Multiple matches (return paths in each endpoint)

**Instrumentation Checklist:**
- [ ] `getDialogueTree`: perfLabel = `getDialogueTree[${npcId}]`
- [ ] `getNpcMemory`: perfLabel = `getNpcMemory[${npcId}/${playerId}]`
- [ ] `persistDialogueState`: perfLabel = `persistDialogueState[${playerId}/${npcId}]`
- [ ] `getDialogueStats`: perfLabel = `getDialogueStats[${playerId}]`
- [ ] `upsertDialogueTree`: perfLabel = `upsertDialogueTree[${npcId}]`

**Verification Command:**
```bash
for endpoint in getDialogueTree getNpcMemory persistDialogueState getDialogueStats upsertDialogueTree; do
  echo "Checking $endpoint..."
  grep -A2 "export const $endpoint" functions/src/api/ludus-dialogue.ts | grep -c "console.time"
done
```

**Expected:** 5 lines of output, each showing "1"

**Evidence:**
- Capture instrumentation points: `grep -B1 -A1 "console.time" functions/src/api/ludus-dialogue.ts > /tmp/instrumentation.txt`

---

## 🎯 Phase 3B: API Verification (08:00–10:00 UTC, 2 hours)

### 3B.1: Firebase Emulator Startup (30 min)

**Objective:** Start local Firebase emulator for testing

**Prerequisites:**
- Firebase CLI installed: `firebase --version`
- `.env.local` or environment variables set: `echo $FIREBASE_PROJECT_ID`

**Command:**
```bash
cd ludus
firebase emulators:start --only firestore,functions
```

**Expected Output (takes 30–60 seconds):**
```
✔  firestore: listening on 127.0.0.1:8080
✔  functions: listening on 127.0.0.1:5001
✔  Emulator UI: listening on 127.0.0.1:4000

┌─────────────────────────────────────────┐
│ All emulators ready! It is now safe to │
│ connect your app.                      │
└─────────────────────────────────────────┘

Emulator UI: http://localhost:4000
```

**Validation Checklist:**
- [ ] Firestore emulator listening on `127.0.0.1:8080`
- [ ] Cloud Functions emulator listening on `127.0.0.1:5001`
- [ ] No "port already in use" errors (may need to kill old process)
- [ ] "All emulators ready" message appears
- [ ] No error stack traces

**If Emulator Fails to Start:**
1. Check if port 5001 is already in use: `lsof -i :5001`
2. Kill conflicting process: `kill -9 <PID>`
3. Check if port 8080 is free: `lsof -i :8080`
4. If ports occupied: choose alternative ports with `--inspect-functions=<port>`
5. Retry startup

**Keep This Terminal Open:** Do not close this terminal; emulator must stay running for Phase 3B.2–3B.5

**Evidence:**
- Screenshot or log: `firebase emulators:start --only firestore,functions 2>&1 | tee /tmp/emulator-startup.log`

---

### 3B.2: Seed Dialogue Data (15 min)

**Objective:** Populate Firestore with test dialogue trees

**Open New Terminal (Terminal #2)** while emulator keeps running in Terminal #1

**Command:**
```bash
cd ludus
export FIREBASE_EMULATOR_HOST="127.0.0.1:8080"
npx ts-node functions/src/scripts/seedDialogueData.ts
```

**Expected Output:**
```
[Seed] Starting dialogue tree population...
[Seed] ✅ Elder Sergius dialogue tree created
[Seed] ✅ Theodora dialogue tree created
[Seed] ✅ All dialogue trees seeded successfully!
```

**Validation Checklist:**
- [ ] Exit code 0 (no errors)
- [ ] Both NPC trees seeded: "Elder Sergius", "Theodora"
- [ ] Success message at end
- [ ] No TypeScript compilation errors

**If Seeding Fails:**
1. Check if emulator is running (should see it in Terminal #1)
2. Verify `FIREBASE_EMULATOR_HOST` is set correctly
3. Check `seedDialogueData.ts` exists: `ls -la functions/src/scripts/seedDialogueData.ts`
4. Review error message for database connection issues
5. Document failure in `PHASE_3_DEPLOYMENT_NOTES.md`

**Verify Seeded Data:**
```bash
# This requires Firestore UI access
# Open: http://localhost:4000
# Navigate to: Firestore > ludus_dialogue_trees
# Verify: 2 documents (elder_sergius, theodora)
```

**Evidence:**
- Save seeding output: `npx ts-node functions/src/scripts/seedDialogueData.ts 2>&1 | tee /tmp/seed-output.log`

---

### 3B.3: Test All 5 API Endpoints (60 min)

**Objective:** Verify each endpoint returns correct response and status

**Use Terminal #2 (emulator still running in Terminal #1)**

**Run Automated Test Suite:**
```bash
./scripts/test-api-endpoints.sh http://localhost:5001
```

**Expected Output:**
```
================================================
Ludus API Endpoint Test Suite
================================================
Base URL: http://localhost:5001
Results: .test-results.json

Testing: Get dialogue tree for elder_sergius...
  Response Status: 200
  Expected Status: 200
  ✓ PASS

[... 14 more tests ...]

================================================
Test Summary
================================================
PASS: 15
FAIL: 0
TOTAL: 15

✓ All tests passed!
```

**Detailed Endpoint Testing:**

**3B.3.1: getDialogueTree Endpoint**
```bash
curl -s http://localhost:5001/api/ludus/dialogue/tree/elder_sergius | jq '.npcName'
```
**Expected:** `"Elder Sergius"`

**Validation Checklist:**
- [ ] HTTP 200 for `elder_sergius` (seeded NPC)
- [ ] HTTP 200 for `theodora` (seeded NPC)
- [ ] HTTP 404 for `nonexistent_npc`
- [ ] HTTP 400 when `npcId` missing
- [ ] Response includes: `npcId`, `npcName`, `theology`, `startNode`, `nodes[]`
- [ ] Each node has: `id`, `text`, `branches[]`
- [ ] Each branch has: `text`, `nextNodeId`, `attributeBonuses`

**3B.3.2: getNpcMemory Endpoint**
```bash
curl -s http://localhost:5001/api/ludus/dialogue/memory/elder_sergius/test-player-001 | jq '.firstMeeting'
```
**Expected:** `true` (first meeting, no prior history)

**Validation Checklist:**
- [ ] HTTP 200 for valid player
- [ ] HTTP 400 when `playerId` missing
- [ ] HTTP 403 when player tries to access another's memory
- [ ] Response for first meeting: `{firstMeeting: true, totalInteractions: 0, choiceHistory: []}`
- [ ] Response has: `lastInteraction`, `attributeBonusesEarned`

**3B.3.3: persistDialogueState Endpoint**
```bash
curl -s -X POST http://localhost:5001/api/ludus/dialogue/state \
  -H "Content-Type: application/json" \
  -d '{
    "playerId": "test-player-001",
    "npcId": "elder_sergius",
    "currentNodeId": "greeting",
    "dialogueHistory": [],
    "attributeBonuses": {"wisdom": 1}
  }' | jq '.success'
```
**Expected:** `true`

**Validation Checklist:**
- [ ] HTTP 200 on success
- [ ] HTTP 405 for non-POST methods
- [ ] HTTP 400 for missing `playerId`, `npcId`, or `currentNodeId`
- [ ] Response includes: `success: true`, `timestamp`, `bonusesApplied: []`
- [ ] Firestore document created: `ludus_dialogue_states/test-player-001_elder_sergius`
- [ ] NPC memory updated with choice history

**3B.3.4: getDialogueStats Endpoint**
```bash
curl -s http://localhost:5001/api/ludus/dialogue/stats/test-player-001 | jq '.npcInteractions'
```
**Expected:** `1` (after one interaction via persistDialogueState)

**Validation Checklist:**
- [ ] HTTP 200 for existing player
- [ ] HTTP 404 for nonexistent player
- [ ] HTTP 400 when `playerId` missing
- [ ] Response includes: `playerId`, `npcInteractions`, `currentAttributes`, `totalBonusesEarned`
- [ ] `dialogueEngagementLevel`: "beginner" (0–2), "intermediate" (3–5), "advanced" (6+)
- [ ] Attributes match player profile

**3B.3.5: upsertDialogueTree Endpoint (ADMIN)**
```bash
# Test without auth (should fail)
curl -s -X POST http://localhost:5001/api/ludus/dialogue/tree/test_npc \
  -H "Content-Type: application/json" \
  -d '{"npcName": "Test", "startNode": "start", "nodes": []}' | jq '.error'
```
**Expected:** `"Unauthorized: Admin token required"`

**Validation Checklist:**
- [ ] HTTP 401 without Bearer token
- [ ] HTTP 403 with invalid/expired token
- [ ] HTTP 400 with missing tree fields
- [ ] HTTP 200 with valid admin token + tree data
- [ ] Dialogue tree created in Firestore

**Full Test Results:**
```bash
cat .test-results.json | jq 'length'
```
**Expected:** 15+ test cases passed

---

### 3B.4: Verify Firestore Data Persistence (15 min)

**Objective:** Confirm data was correctly written to Firestore collections

**Method A: Firestore UI (Visual)**
1. Open: http://localhost:4000 (Firestore Emulator UI)
2. Click on: "Firestore" tab
3. Verify collections exist:
   - [ ] `ludus_dialogue_trees` (2 documents: elder_sergius, theodora)
   - [ ] `ludus_dialogue_states` (1 document: test-player-001_elder_sergius)
   - [ ] `ludus_npc_memory` (1+ documents with subcollections)

**Method B: Firestore CLI**
```bash
firebase firestore:inspect ludus_dialogue_trees/elder_sergius
```

**Validation Checklist:**
- [ ] `ludus_dialogue_trees/elder_sergius` exists with:
  - `npcName: "Elder Sergius"`
  - `theology: "Hesychasm"`
  - `nodes: [...]` (array with 3+ nodes)
  - `startNode: "greeting"`

- [ ] `ludus_dialogue_states/test-player-001_elder_sergius` exists with:
  - `playerId: "test-player-001"`
  - `npcId: "elder_sergius"`
  - `currentNodeId: "greeting"`
  - `timestamp: <number>`

- [ ] `ludus_npc_memory/elder_sergius/players/test-player-001` exists with:
  - `firstMeeting: false` (changed after persist)
  - `totalInteractions: >= 1`
  - `choiceHistory: [...]`

**Evidence:**
- Screenshot or export: `firebase firestore:export /tmp/firestore-backup`

---

### 3B.5: Test Error Handling (15 min)

**Objective:** Verify API returns proper error messages and status codes

**Test Cases:**

**Invalid Input Tests:**
```bash
# Missing required parameter
curl -s http://localhost:5001/api/ludus/dialogue/tree | jq '.error'
# Expected: "Missing npcId parameter"

# Invalid JSON in POST
curl -s -X POST http://localhost:5001/api/ludus/dialogue/state \
  -H "Content-Type: application/json" \
  -d 'invalid json' | jq '.error'
# Expected: 400 error (syntax error)

# Method not allowed
curl -s -X DELETE http://localhost:5001/api/ludus/dialogue/state | jq '.error'
# Expected: "Method not allowed"
```

**Authorization Tests:**
```bash
# Attempt to access another player's data
curl -s -H "x-firebase-auth-user: player-2" \
  http://localhost:5001/api/ludus/dialogue/memory/elder_sergius/player-1 | jq '.error'
# Expected: "Cannot access other player memory" (403)
```

**Validation Checklist:**
- [ ] HTTP 400 for missing required fields (with error message)
- [ ] HTTP 401 for missing auth where required
- [ ] HTTP 403 for insufficient permissions
- [ ] HTTP 404 for nonexistent resources
- [ ] HTTP 405 for wrong HTTP method
- [ ] HTTP 500 only for server errors (should not occur in normal paths)
- [ ] All errors include `.error` field with description

**Evidence:**
- Save error responses: `curl ... 2>&1 | tee /tmp/error-tests.log`

---

## ✅ Phase 3C: Pre-Deployment Checks (10:00–11:00 UTC, 1 hour)

### 3C.1: Compile and Lint Backend (20 min)

**Objective:** Final code quality check

**Command:**
```bash
cd ludus/functions
npm run build
npm run lint
```

**Expected Output:**
```
> ludus-functions@0.1.0 build
> tsc

(no output = success)

> ludus-functions@0.1.0 lint
> eslint src/

(no output = success)
```

**Validation Checklist:**
- [ ] `npm run build` exit code = 0
- [ ] `npm run lint` exit code = 0 (or skipped if no linter configured)
- [ ] No TypeScript errors
- [ ] No ESLint warnings (if configured)

**If Errors:**
1. Review error messages line by line
2. Fix critical issues (TS errors, security issues)
3. Skip optional linting issues if non-blocking
4. Document fixes in `PHASE_3_DEPLOYMENT_NOTES.md`
5. Rebuild to verify fixes

---

### 3C.2: Type Checking (10 min)

**Objective:** Verify strict TypeScript validation

**Command:**
```bash
cd ludus/functions
npx tsc --noEmit
```

**Expected Output:**
```
(no output = success, or warnings only)
```

**Validation Checklist:**
- [ ] Exit code = 0
- [ ] No "error TS" lines
- [ ] All imports resolve correctly
- [ ] All function signatures valid

**If Errors:**
1. List all errors: `npx tsc --listFiles`
2. Fix type mismatches
3. Add type annotations where needed
4. Re-check: `npx tsc --noEmit`

---

### 3C.3: Firestore Rules Final Validation (15 min)

**Objective:** Dry-run rules deployment one final time

**Command:**
```bash
firebase deploy --only firestore:rules --dry-run
```

**Expected Output:**
```
✓ Deploy complete!

Dry run successful, no changes will be made.
```

**Validation Checklist:**
- [ ] Exit code = 0
- [ ] "Dry run successful" message
- [ ] No syntax errors
- [ ] No permission issues

---

### 3C.4: Frontend File Verification (15 min)

**Objective:** Ensure all UI files are in place

**Files Required:**
```
public/
├── index.html                          ← Web app entry point
└── ludus/
    ├── ludus-design-system.css         ← Theme variables
    ├── ludus-game.css                  ← Game styling
    ├── ludus-dialogue.css              ← Dialogue UI
    └── ludus-audio-manager.js          ← Audio system
```

**Verification Command:**
```bash
for file in public/index.html public/ludus/ludus-*.{css,js}; do
  if [ -f "$file" ]; then
    echo "✓ $file ($(wc -l < $file) lines)"
  else
    echo "✗ MISSING: $file"
  fi
done
```

**Validation Checklist:**
- [ ] `public/index.html` exists (80+ lines)
- [ ] `public/ludus/ludus-design-system.css` exists
- [ ] `public/ludus/ludus-game.css` exists
- [ ] `public/ludus/ludus-dialogue.css` exists (if separate from game.css)
- [ ] All files are readable and not empty

**Content Validation:**
```bash
# Check index.html has required divs
grep -c "ludus-game-container\|ludus-dialogue-container\|ludus-rov-container" public/index.html
# Expected: 3 matches

# Check CSS links in index.html
grep -c "<link.*ludus" public/index.html
# Expected: 3+ CSS files linked
```

---

### 3C.5: Documentation Review (10 min)

**Objective:** Ensure all deployment docs are accurate and complete

**Files to Review:**
- [ ] `/ludus/PHASE_3_DEPLOYMENT_CHECKLIST.md` (this file) ← You are here
- [ ] `/ludus/PHASE_3_FINAL_BACKLOG.md` — Backlog summary
- [ ] `/ludus/PHASE_3_QUICK_START.md` — TL;DR version
- [ ] `/ludus/docs/LOCAL_DEV_SETUP.md` — Local setup guide
- [ ] `/ludus/docs/version-3.0/CLOUD_FUNCTIONS_DIALOGUE_API.md` — API reference

**Quick Checks:**
```bash
for file in docs/reports/PHASE_3_DEPLOYMENT_CHECKLIST.md docs/reports/PHASE_3_FINAL_BACKLOG.md docs/version-3.0/LOCAL_DEV_SETUP.md; do
  if [ -f "$file" ]; then
    LINES=$(wc -l < "$file")
    echo "✓ $file ($LINES lines)"
  else
    echo "✗ MISSING: $file"
  fi
done
```

**Validation Checklist:**
- [ ] All deployment docs exist and are readable
- [ ] No critical TODOs or FIXMEs in docs
- [ ] URLs are correct (Firebase console, GitHub, etc.)
- [ ] Contact info is accurate (e.g., email for reporting issues)

---

## 🎯 Phase 3D: Go/No-Go Decision (11:00 UTC)

### Decision Criteria

**✅ GO to Phase 3 Testing if:**

- [x] TypeScript compiles with 0 errors
- [x] Jest test discovery works
- [x] Firestore rules validate (dry-run success)
- [x] All 5 API endpoints respond correctly (getDialogueTree, getNpcMemory, persistDialogueState, getDialogueStats, upsertDialogueTree)
- [x] Test data seeded successfully (2 NPCs, 10 players)
- [x] Error handling returns correct HTTP status codes
- [x] Firestore security rules prevent cross-player access
- [x] Admin auth check working (upsertDialogueTree rejects unauthorized)
- [x] No P0 blockers remaining
- [x] Performance instrumentation active (console.time/timeEnd)

**❌ NO-GO (Do Not Deploy) if:**

- [ ] Any endpoint returns HTTP 500 error
- [ ] TypeScript compilation fails
- [ ] Firestore rules have syntax errors
- [ ] Security vulnerability found (e.g., player can access another's data)
- [ ] Admin auth bypass discovered
- [ ] Test data missing (NPCs not seeded)
- [ ] API responds incorrectly to error cases
- [ ] More than 1 P0 blocker remains unfixed

### Decision Process

**At 11:00 UTC:**

1. **Review Summary** — Open `PHASE_3_VALIDATION_RESULTS.md` (generated by `phase3-validation.sh`)
2. **Count Failures** — How many checks failed?
   - 0 failures → **READY FOR GO**
   - 1-3 failures → **Fix and re-check (can still deploy same day)**
   - 4+ failures → **NO-GO, defer to Oct 2**

3. **Evaluate Risk** — Are failures in:
   - Critical path (API, auth, data persistence)? → **More risk**
   - Optional features (UI, performance optimization)? → **Lower risk**

4. **Make Decision** — Record in `PHASE_3_DEPLOYMENT_NOTES.md`:
   ```markdown
   ## Go/No-Go Decision (11:00 UTC)

   **Status:** ✅ GO / ❌ NO-GO
   **Failures:** 0
   **Critical Issues:** None
   **Decision Time:** 11:00 UTC
   **Decided By:** Claude Haiku 4.5
   **Timestamp:** 2026-10-01 11:00:00 UTC

   **Rationale:**
   - All 5 API endpoints working
   - Security rules validated
   - Test data seeded
   - No TypeScript errors
   - No P0 blockers
   ```

---

## 📝 Post-Decision Actions (11:00–12:00 UTC)

### If ✅ GO Approved

**Deploy to Firebase (Production):**
```bash
# 1. Deploy Cloud Functions
firebase deploy --only functions

# 2. Deploy Firestore Rules
firebase deploy --only firestore:rules

# 3. Verify deployment
firebase functions:list
firebase firestore:indexes list

# 4. Record completion
echo "Deployment complete at $(date -u +%H:%M:%S)" >> PHASE_3_DEPLOYMENT_NOTES.md
```

**Start Phase 3 Testing (09:00 UTC Oct 1):**
- Load app on Quest 3 VR headset
- Test all 5 API endpoints with real players
- Verify audio and visual elements
- Document any issues found
- Follow `docs/reports/PHASE_3_TEST_LOG.md` template

### If ❌ NO-GO Decision

**Do Not Deploy:**
1. Keep emulator running for diagnostics
2. Document all failures in `PHASE_3_DEPLOYMENT_NOTES.md`
3. Assign fixes to backlog
4. Schedule re-validation for Oct 2
5. Update team on status

**Fix Critical Issues:**
1. Prioritize P0 gaps from backlog
2. Implement one fix at a time
3. Re-run `./scripts/phase3-validation.sh` after each fix
4. Document resolution in notes

---

## 📊 Tracking & Reporting

### 3C.6: Generate Final Report (before 11:00 UTC)

**Command:**
```bash
./scripts/phase3-validation.sh > PHASE_3_VALIDATION_RESULTS.md 2>&1
```

**Report Should Include:**
- [x] Pass/fail count for each validation step
- [x] Evidence (timestamps, test output)
- [x] Error details (if any failures)
- [x] Next steps (GO or NO-GO path)

### Document Results

**Create** `PHASE_3_DEPLOYMENT_NOTES.md`:
```markdown
# Phase 3 Deployment Notes
**Date:** Oct 1, 2026
**Session:** https://claude.ai/code/session_015SgoYe2WsjLk8L6xDTU2JU

## Timeline
- 06:00 UTC: Started Phase 3A (validation)
- 08:00 UTC: Started Phase 3B (API tests)
- 10:00 UTC: Started Phase 3C (pre-deployment)
- 11:00 UTC: Go/No-Go decision

## Results Summary
- TypeScript Build: ✅ PASS
- Jest Tests: ✅ PASS
- Firestore Rules: ✅ PASS
- API Endpoints: ✅ PASS (5/5)
- Test Fixtures: ✅ PASS (10 players, 3 paths)
- Performance Instrumentation: ✅ PASS
- Security: ✅ PASS

## Go/No-Go Decision
**Status:** ✅ GO

## Issues Found
None.

## Recommendations
Proceed with Phase 3 testing. Deploy Cloud Functions and Firestore Rules.
```

---

## 🆘 Remediation Guide

### If Phase 3A Fails

**TypeScript Errors:**
1. Read error message carefully (includes file:line:column)
2. Open file in editor
3. Check: type mismatches, undefined variables, wrong imports
4. Fix and re-run `npm run build`
5. Do not proceed until build succeeds

**Jest Not Found:**
1. Check `jest.config.js` exists: `ls functions/jest.config.js`
2. Check `ts-jest` installed: `npm list ts-jest` in functions/
3. If missing: `npm install --save-dev ts-jest @types/jest`
4. Retry test discovery

**Firestore Rules Syntax Error:**
1. Open `firestore.rules`
2. Look for line number in error message
3. Check syntax at that line
4. Common issues:
   - Missing closing `}` bracket
   - Misspelled collection name
   - Invalid rule syntax
5. Fix and re-run dry-run validation

### If Phase 3B Fails

**Emulator Won't Start:**
1. Check if port 5001 in use: `lsof -i :5001`
2. Kill old process: `kill -9 <PID>`
3. Retry: `firebase emulators:start --only firestore,functions`
4. If still fails, try alternative port: `--inspect-functions=5555`

**API Endpoints Return 500:**
1. Check emulator console (Terminal #1) for error messages
2. Common issues:
   - Firestore connection failed
   - Cloud Functions not deployed to emulator
   - Environment variable not set
3. Restart emulator and retry

**Test Data Not Seeded:**
1. Verify emulator is running
2. Check `FIREBASE_EMULATOR_HOST` is set
3. Check `seedDialogueData.ts` exists and is readable
4. Run with verbose output: `DEBUG=* npx ts-node ...`
5. Review seed script for errors

**API Returns 400/404:**
1. Check request format (JSON syntax, required fields)
2. Verify endpoint path is correct
3. Check test data was seeded (query Firestore UI)
4. Review error message for details

### If Phase 3C Fails

**TypeScript Still Has Errors After Rebuild:**
1. Check if changes were actually saved
2. Review full error list: `npx tsc --pretty false | head -20`
3. Fix each error and rebuild incrementally
4. Do not proceed to deployment with errors

**Firestore Rules Dry-Run Fails:**
1. Review rule changes made during Phase 3A
2. Check for missing closing brackets: `grep -c "^}" firestore.rules`
3. Validate JSON in helper functions
4. Use Firebase rules emulator for testing: `firebase emulators:start --only firestore`

**Missing Documentation:**
1. If docs missing, create them immediately
2. Use templates from `/ludus/docs/` directory
3. Ensure they're committed before deployment
4. Verify URLs are correct before linking

---

## 📎 Related Documents

- **docs/reports/PHASE_3_FINAL_BACKLOG.md** — Backlog of all identified gaps, prioritized by severity
- **docs/reports/PHASE_3_QUICK_START.md** — TL;DR summary for quick reference
- **docs/reports/PHASE_3_TEST_LOG.md** — Template for logging Phase 3 test results
- **LOCAL_DEV_SETUP.md** — Complete local development setup guide
- **CLOUD_FUNCTIONS_DIALOGUE_API.md** — Full API reference documentation

---

## 📞 Support

**If You Get Stuck:**

1. Review the error message carefully — it often contains the solution
2. Check this checklist for the specific phase
3. Look in "Remediation Guide" above
4. Review related documentation linked above
5. Check Firebase logs: `firebase functions:log`
6. Open GitHub issue: https://github.com/Leonidy431/ludus/issues

---

## ✅ Sign-Off

**Deployment Checklist Complete:** _____ (Date/Time)  
**Validated By:** _____ (Name/Agent)  
**Approved for GO:** _____ (Yes/No)  
**Phase 3 Testing Start Time:** _____ (Expected: Oct 1, 09:00 UTC)

---

**Status:** ✅ READY FOR EXECUTION  
**Last Updated:** Sep 29, 2026  
**Maintained By:** Claude Haiku 4.5  
**Approver:** Leonidy431
