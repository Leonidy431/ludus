---
id: ludus-phase2-execution-checklist
type: deployment-guide
tags: [ludus, deployment, phase2, firestore-init, critical-blockers, quest-3]
version: 1.0
status: ready-for-execution
date: 2026-09-28
---

# Phase 2 Execution Checklist — Firestore Initialization & Critical Blockers

**Timeline:** 3 days to Quest 3 device testing (Sep 28 → Oct 1)  
**Phase 2 Duration:** ~2.5 hours total  
**Status:** All blockers identified + rate limiting middleware implemented + documentation complete

---

## Pre-Execution Checklist (Do These First)

### Prerequisites Verification

- [ ] **Firebase CLI installed**
  ```bash
  firebase --version
  ```
  Expected: v12.0.0 or later

- [ ] **gcloud CLI installed**
  ```bash
  gcloud --version
  ```

- [ ] **Logged into Firebase**
  ```bash
  firebase login
  ```

- [ ] **Project configured**
  ```bash
  firebase use ludus-dev
  ```

- [ ] **Service account NOT yet downloaded** (will download in Step 1)

- [ ] **Git working directory clean**
  ```bash
  cd /home/user/ludus && git status
  ```
  Should show "nothing to commit, working tree clean"

- [ ] **Rate limiting middleware compiled**
  ```bash
  ls -la functions/lib/middleware/rateLimit.js
  ```
  Expected: File exists (269 bytes)

### Dependencies Check

```bash
# Verify functions/package.json has all dependencies
cd /home/user/ludus/functions
npm ls firebase-admin firebase-functions
```

Expected output:
```
├── firebase-admin@11.0.0 (or later)
└── firebase-functions@4.0.0 (or later)
```

---

## Phase 2 Execution Steps

### Step 1: Download Service Account Key (5 min)

**Why:** Seed script needs credentials to initialize Firestore data.

**Steps:**

1. Open Firefox/Chrome
2. Go to: https://console.firebase.google.com
3. Select project: **ludus-dev**
4. Click **Settings** (⚙️) → **Service Accounts**
5. Tab: **Firebase Admin SDK**
6. Language: **Node.js**
7. Click **Generate New Private Key**
8. Save file as: **`functions/service-account.json`** (NOT committed to git)

**Verify:**
```bash
ls -la /home/user/ludus/functions/service-account.json
file -b /home/user/ludus/functions/service-account.json
# Expected: JSON data, UTF-8 Unicode text
```

**⚠️ Security:** This file contains credentials. Never commit to git. Delete after seed completes.

### Step 2: Build & Deploy Cloud Functions (20 min)

**Includes:** Health endpoint, metrics endpoint, rate limiting middleware, Firestore rules.

```bash
cd /home/user/ludus

# 1. Build TypeScript → JavaScript
echo "📦 Building Cloud Functions..."
cd functions && npm run build && cd ..
if [ $? -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi
echo "✅ Build complete (functions/lib/)"

# 2. Deploy to Firebase
echo "🚀 Deploying to Firebase..."
firebase deploy --project ludus-dev --only functions,firestore:rules

if [ $? -ne 0 ]; then
  echo "❌ Deploy failed"
  exit 1
fi
echo "✅ Deploy complete"
```

**Expected Output:**
```
✔ Deploy complete!

Function URL (ludusHealth): https://us-central1-ludus-dev.cloudfunctions.net/ludusHealth
Function URL (ludusMetrics): https://us-central1-ludus-dev.cloudfunctions.net/ludusMetrics

Firestore rules published successfully
```

**Verify Deployment:**
```bash
# List functions
firebase functions:list --project ludus-dev

# Expected: Both ludusHealth and ludusMetrics listed
```

### Step 3: Initialize Firestore with Seed Data (15 min)

**Includes:** 5 players, 20 NPCs, 50 edges, 10 knowledge gates.

```bash
cd /home/user/ludus/functions

# Set credentials
export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/service-account.json

# Run seed script
echo "🌱 Seeding Firestore data..."
npm run ts-node src/scripts/seedDemiurgeData.ts

SEED_EXIT=$?
if [ $SEED_EXIT -ne 0 ]; then
  echo "❌ Seed data failed (exit code: $SEED_EXIT)"
  exit 1
fi

echo "✅ Seed data complete"

# Clean up credentials (security)
unset GOOGLE_APPLICATION_CREDENTIALS
cd ..
```

**Expected Output:**
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

### Step 4: Verify Health Endpoint (10 min)

**Purpose:** Confirm Firestore has data + endpoints are responding.

```bash
# Get function URL
HEALTH_URL=$(firebase functions:describe ludusHealth --project ludus-dev \
  --format='json' | jq -r '.httpsTrigger.url')

echo "Testing health endpoint: $HEALTH_URL"

# Test without auth
echo "→ Test 1: Unauthenticated request"
curl -s "$HEALTH_URL" | jq '.'

# Expected response:
# {
#   "status": "ok",
#   "timestamp": "2026-09-28T...",
#   "components": {
#     "firestore": {
#       "status": "ok",
#       "nodeCount": 25,
#       "edgeCount": 50,
#       "gateCount": 10
#     },
#     "seed_data": {
#       "status": "ok",
#       "playerCount": 5,
#       "npcCount": 20,
#       "expectedPlayers": 5,
#       "expectedNpcs": 20
#     },
#     "simulation": {
#       "status": "ok",
#       "lastCycleDurationMs": 0,
#       "cycleCountSinceInit": 0,
#       "targetCycleDurationMs": 8
#     }
#   }
# }
```

**Verify Requirements:**
- [ ] Status = "ok" (not "degraded" or "down")
- [ ] nodeCount = 25
- [ ] edgeCount = 50
- [ ] playerCount = 5
- [ ] npcCount = 20

If any checks fail, see §5 (Troubleshooting).

### Step 5: Test Rate Limiting (10 min)

**Purpose:** Verify rate limit middleware is active (prevents endpoint hammering).

```bash
# Bash script to test rate limiting
HEALTH_URL=$(firebase functions:describe ludusHealth --project ludus-dev \
  --format='json' | jq -r '.httpsTrigger.url')

echo "Testing rate limiting (max 30 requests/min)..."
echo "Sending 35 requests in 10 seconds..."

for i in {1..35}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL")
  echo "Request $i: HTTP $STATUS"
  
  if [ $i -lt 35 ]; then
    sleep 0.3  # 300ms between requests
  fi
  
  # After request 30, we should see 429 (Too Many Requests)
  if [ $i -gt 30 ] && [ "$STATUS" != "429" ]; then
    echo "⚠️  Expected 429 after 30 requests, got $STATUS"
  fi
done

echo "✅ Rate limiting test complete"
# Expected: Requests 1-30 = 200, requests 31-35 = 429
```

**Interpretation:**
- Requests 1-30: HTTP 200 ✅
- Requests 31-35: HTTP 429 (rate limited) ✅

If you see 200 for all 35 requests, rate limiting middleware may not be active. Check:
```bash
grep -n "rateLimit" functions/lib/api/ludus-health.js
```

### Step 6: Create Monitoring Dashboard (15 min)

**Purpose:** Real-time observability for Phase 3 testing.

```bash
# Deploy monitoring dashboard
gcloud monitoring dashboards create \
  --config-from-file=monitoring/logging-dashboard.yaml \
  --project ludus-dev

# Verify
gcloud monitoring dashboards list --project ludus-dev --format='value(displayName)'
# Expected: "Ludus v0.1 — Cloud Logging Dashboard"
```

### Step 7: Enable Firestore Backups (5 min)

**Purpose:** Data protection (disaster recovery).

```bash
# Create daily backup schedule
gcloud scheduler jobs create app-engine ludus-backup-daily \
  --project ludus-dev \
  --schedule="0 2 * * *" \
  --http-method=POST \
  --uri="https://us-central1-ludus-dev.cloudfunctions.net/triggerBackup" \
  --oidc-service-account-email=$(gcloud iam service-accounts list \
    --project ludus-dev --format='value(email)' | head -1) \
  --time-zone=UTC

# Verify
gcloud scheduler jobs list --project ludus-dev --format='value(name)'
# Expected: ludus-backup-daily
```

### Step 8: Cleanup Service Account (2 min)

**Security:** Remove local credential file after seed completes.

```bash
cd /home/user/ludus/functions

# Backup location (for recovery, never committed)
# cp service-account.json ~/backups/ludus-service-account-backup.json

# Delete local file
rm -f service-account.json

echo "✅ Service account deleted from disk"

# Verify it's gone
if [ ! -f service-account.json ]; then
  echo "✅ Confirmed: service-account.json no longer exists locally"
else
  echo "❌ ERROR: service-account.json still exists!"
  exit 1
fi
```

---

## Phase 2 Summary

| Step | Task | Time | Status |
|------|------|------|--------|
| 1 | Download service account | 5 min | Ready |
| 2 | Build & deploy functions | 20 min | Ready |
| 3 | Seed Firestore data | 15 min | Ready |
| 4 | Verify health endpoint | 10 min | Ready |
| 5 | Test rate limiting | 10 min | Ready |
| 6 | Monitoring dashboard | 15 min | Ready |
| 7 | Enable backups | 5 min | Ready |
| 8 | Cleanup credentials | 2 min | Ready |
| **TOTAL** | **Phase 2 Complete** | **82 min** | **Ready to Execute** |

---

## Troubleshooting

### Issue: Health endpoint returns 503 "Collections not initialized"

**Cause:** Seed script didn't run or failed.

**Fix:**
```bash
cd /home/user/ludus/functions
export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/service-account.json
npm run ts-node src/scripts/seedDemiurgeData.ts
# Check output for errors
```

### Issue: "Unauthorized" error from metrics endpoint

**Cause:** Missing or invalid Bearer token.

**Fix:**
```bash
# Get admin token (Firebase Console)
firebase auth:export ludus-admin-tokens.json --project ludus-dev

# Then include in request:
curl -H "Authorization: Bearer <admin_token>" \
  https://us-central1-ludus-dev.cloudfunctions.net/ludusMetrics
```

### Issue: Deploy fails with "Missing firestore.rules"

**Cause:** firestore.rules file not in repo root.

**Fix:**
```bash
# Verify file exists
ls -la /home/user/ludus/firestore.rules

# If missing, restore from git
cd /home/user/ludus && git checkout firestore.rules
```

### Issue: Rate limiting test shows all 200s (no 429)

**Cause:** Rate limiting middleware not integrated in handler.

**Check:**
```bash
# Verify build includes rateLimit
grep "rateLimit" functions/lib/middleware/rateLimit.js

# Check if ludus-health imports it
grep "rateLimit" functions/lib/api/ludus-health.js
```

**Action:** Manually apply rate limiting to handlers (see PHASE2_CRITICAL_BLOCKERS.md §1.3).

---

## Post-Phase-2 Validation

**Checklist for Phase 3 (Device Testing):**

- [ ] All 8 blockers resolved
- [ ] Functions deployed and responding (HTTP 200)
- [ ] Firestore has seed data (25 nodes, 50 edges, 10 gates)
- [ ] Rate limiting active (429 after 30 req/min)
- [ ] Monitoring dashboard visible in Cloud Console
- [ ] Backup schedule confirmed (daily at 2 AM UTC)
- [ ] Service account credential deleted from disk
- [ ] No errors in Cloud Logging

**Next Phase:** Phase 3 (Sep 29–Oct 1) — webtypicon2 integration + device testing

---

## Emergency Rollback

**If Phase 2 fails critically:**

```bash
# Delete functions (data remains)
firebase functions:delete ludusHealth ludusMetrics --quiet --project ludus-dev

# Clear Firestore (⚠️ DESTRUCTIVE)
firebase firestore:delete ludus_nodes ludus_edges ludus_knowledge_gates --project ludus-dev --confirm

# Restore from backup
gcloud firestore databases restore BACKUP_ID --project ludus-dev
```

---

**Owner:** Claude Haiku 4.5  
**Session:** https://claude.ai/code/session_015SgoYe2WsjLk8L6xDTU2JU  
**Last Updated:** 2026-09-28 10:54 UTC  
**Status:** ✅ READY FOR EXECUTION

