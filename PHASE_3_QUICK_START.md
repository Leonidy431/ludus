# Phase 3: Quick Start Guide (TL;DR)
## Oct 1, 2026 | 06:00–12:00 UTC | Essential Commands Only

**What:** Final validation before Phase 3 testing deployment  
**When:** Oct 1, 06:00 UTC start  
**Duration:** 6.5 hours  
**Goal:** Go/No-Go decision at 11:00 UTC

---

## 🚀 The Five Critical Commands

### Command 1: Validate Everything (2 min)
```bash
./scripts/phase3-validation.sh
```
**Does:** Checks all Phase 3 readiness criteria  
**Expected:** `✓ ALL TESTS PASSED - READY FOR PHASE 3!`  
**Output:** `PHASE_3_VALIDATION_RESULTS.md`

### Command 2: Start Emulator (1 min setup, runs 2+ hours)
```bash
firebase emulators:start --only firestore,functions
```
**Does:** Starts local Firestore and Cloud Functions for testing  
**Keep This Running:** Don't close this terminal  
**Expected:** `All emulators ready! It is now safe to connect your app.`

### Command 3: Seed Test Data (2 min, in new terminal)
```bash
export FIREBASE_EMULATOR_HOST="127.0.0.1:8080"
npx ts-node functions/src/scripts/seedDialogueData.ts
```
**Does:** Populates Firestore with 2 test NPCs  
**Expected:** `✅ All dialogue trees seeded successfully!`

### Command 4: Test All Endpoints (5 min)
```bash
./scripts/test-api-endpoints.sh http://localhost:5001
```
**Does:** Automated curl tests for all 5 API endpoints  
**Expected:** `✓ All tests passed!` (15/15 pass)

### Command 5: Deploy (5 min)
```bash
firebase deploy --only functions,firestore:rules
```
**Does:** Deploys backend to Firebase (only if Command 1 passed)  
**Expected:** `✓ Deploy complete!`

---

## ⏰ Timeline (06:00–12:00 UTC)

| Time | Phase | Task | Duration |
|------|-------|------|----------|
| **06:00** | 3A | Build & validate code | 15 min |
| **06:15** | 3A | Jest test discovery | 15 min |
| **06:30** | 3A | Firestore rules validation | 15 min |
| **06:45** | 3A | Test fixtures verification | 15 min |
| **07:00** | 3A | Performance instrumentation check | 15 min |
| **07:15** | 3B | Start Firebase emulator | 30 min |
| **07:45** | 3B | Seed dialogue data | 15 min |
| **08:00** | 3B | Test all 5 API endpoints | 60 min |
| **09:00** | 3B | Verify Firestore data + error handling | 30 min |
| **09:30** | 3C | Code compilation & linting | 20 min |
| **09:50** | 3C | TypeScript strict mode | 10 min |
| **10:00** | 3C | Firestore rules final check | 15 min |
| **10:15** | 3C | Frontend files verification | 15 min |
| **10:30** | 3C | Documentation review | 15 min |
| **10:45** | 3D | Compile validation results | 10 min |
| **11:00** | 3D | **GO/NO-GO DECISION** | — |
| **11:15** | — | Deploy (if GO) or fix issues (if NO-GO) | 45 min |

---

## ✅ Go/No-Go Criteria

**GO if (deploy now):**
- [ ] TypeScript: 0 errors
- [ ] All 5 API endpoints: HTTP 200 responses
- [ ] Test data: Seeded (2 NPCs)
- [ ] Security: Admin auth working
- [ ] Firestore rules: Validated
- [ ] P0 blockers: 0 remaining

**NO-GO if (fix first):**
- Any TypeScript errors
- API returns 500 error
- Test data not seeded
- Security vulnerability found
- 4+ failures in validation

---

## 📋 Pre-Session Checklist (Run at 05:45 UTC)

```bash
# 1. Verify all Phase 3 files exist
ls -lh PHASE_3_*.md docs/LOCAL_DEV_SETUP.md functions/jest.config.js

# 2. Verify scripts are executable
[ -x scripts/phase3-validation.sh ] && echo "✓ Validation script ready"
[ -x scripts/test-api-endpoints.sh ] && echo "✓ API test script ready"

# 3. Quick build check
cd functions && npm run build 2>&1 | tail -5

# 4. Check test fixtures exist
ls -lh functions/src/tests/fixtures/*.json
```

**If any check fails:** Review `PHASE_3_DEPLOYMENT_CHECKLIST.md` for remediation

---

## 🛑 If Something Breaks

**TypeScript Won't Compile:**
```bash
cd functions && npm run build
# Fix errors shown, then retry
```

**API Returns 500:**
1. Check emulator is running (Terminal #1)
2. Check seed completed: `firebase firestore:console`
3. Restart emulator if needed

**Emulator Won't Start:**
```bash
# Kill old process
pkill -f "firebase emulators"
# Retry
firebase emulators:start --only firestore,functions
```

**Still Stuck?**
- See "Remediation Guide" in `PHASE_3_DEPLOYMENT_CHECKLIST.md`
- Check Firebase logs: `firebase functions:log`
- Don't deploy until all issues fixed

---

## 📊 Success Indicators

| Item | Good Sign | Bad Sign |
|------|-----------|----------|
| Build | "tsc" with no output | "error TS" messages |
| Jest | Test files discovered | "Cannot find module" |
| Emulator | "All emulators ready" | Port already in use |
| Seeding | "seeded successfully" | Connection timeout |
| API Tests | "✓ All tests passed!" | "✗ FAIL" anywhere |
| Firestore | "Dry run successful" | "syntax error" |
| Decision | 0 failures in validation | 4+ failures |

---

## 📎 Key Documents

- **Full Checklist:** `PHASE_3_DEPLOYMENT_CHECKLIST.md` (1000+ lines, detailed)
- **Backlog:** `PHASE_3_FINAL_BACKLOG.md` (gap tracking, priorities)
- **Dev Setup:** `docs/LOCAL_DEV_SETUP.md` (environment configuration)
- **This Guide:** `PHASE_3_QUICK_START.md` (you are here)

---

## 🎯 After 11:00 UTC

**If ✅ GO Approved:**
```bash
# Deploy to production
firebase deploy --only functions,firestore:rules

# Verify deployment
firebase functions:list

# Record success
echo "Deployed at $(date -u)" >> PHASE_3_DEPLOYMENT_NOTES.md

# Begin Phase 3 testing (09:00 UTC on Quest 3)
```

**If ❌ NO-GO:**
```bash
# Document failures
cp PHASE_3_VALIDATION_RESULTS.md PHASE_3_DEPLOYMENT_NOTES.md

# Fix critical issues from backlog

# Re-run validation
./scripts/phase3-validation.sh

# Plan re-deployment for Oct 2
```

---

## ⚠️ Critical Don'ts

- ❌ Don't close the emulator terminal (Terminal #1)
- ❌ Don't deploy without passing validation
- ❌ Don't ignore TypeScript errors ("might work anyway" = false)
- ❌ Don't skip security checks (admin auth, player isolation)
- ❌ Don't proceed past 08:00 UTC if Phase 3A fails
- ❌ Don't make code changes during Phase 3 (test only, no fixes)

---

## ✅ Final Sanity Check

Before hitting deploy at 11:15 UTC:

```bash
# 1. Recompile one last time
cd functions && npm run build

# 2. Check validation results
cat PHASE_3_VALIDATION_RESULTS.md | grep -c "✓ PASS"

# 3. Spot-check an API endpoint
curl -s http://localhost:5001/api/ludus/dialogue/tree/elder_sergius | jq '.npcName'
# Should return: "Elder Sergius"

# 4. Verify no uncommitted changes
git status

# 5. Check timestamp
date -u
```

If all good → Deploy!  
If anything wrong → Fix and re-check.

---

**Status:** ✅ READY FOR OCT 1  
**Last Updated:** Sep 29, 2026  
**Maintained By:** Claude Haiku 4.5
