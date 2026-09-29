---
id: ludus-phase2-local-deployment
type: deployment-guide
tags: [ludus, deployment, phase2, local-execution, firebase-cli]
version: 1.0
status: ready-to-execute
date: 2026-09-28
---

# Phase 2: Local Deployment Guide — Execute on Your Machine

**Purpose:** This guide helps you execute Phase 2 deployment on your local machine (macOS/Linux/Windows)  
**Duration:** ~82 minutes  
**Prerequisites:** Node.js 18+, Firebase CLI, gcloud CLI, Firebase project access

---

## Pre-Execution Setup (One-Time)

### 1. Ensure Prerequisites Installed

```bash
# Check Node.js
node --version
# Expected: v18.0.0 or later

# Check Firebase CLI
npm install -g firebase-tools
firebase --version
# Expected: v12.0.0 or later

# Check gcloud CLI
gcloud --version
# Expected: Google Cloud SDK 400+

# Check git
git --version
```

### 2. Authenticate with Firebase

```bash
# This will open a browser to authenticate
firebase login

# Select the correct project
firebase use ludus-dev
firebase projects:list  # Verify ludus-dev is selected
```

### 3. Clone/Pull Latest Code

```bash
cd /path/to/ludus  # Your local ludus repository
git pull origin main
# Verify you have the latest deployment docs + rate limiting middleware
ls -la docs/PHASE2_*
ls -la functions/src/middleware/rateLimit.ts
```

---

## Phase 2 Execution (Follow These Steps Sequentially)

### STEP 1: Download Service Account Key (5 min — MANUAL)

**Why:** The seed script needs credentials to initialize Firestore.

**Steps:**

1. Open: https://console.firebase.google.com/project/ludus-dev/settings/serviceaccounts/adminsdk
2. Click **Firebase Admin SDK**
3. Language: **Node.js**
4. Click **Generate New Private Key**
5. File downloads as `ludus-dev-*.json`
6. Move/rename to: `functions/service-account.json`

**Verify:**
```bash
ls -la functions/service-account.json
# Expected: JSON file with { "type": "service_account", ... }
```

**⚠️ SECURITY:** Never commit this file to git. Add to `.gitignore` (already done).

---

### STEP 2: Build Cloud Functions (10 min)

```bash
cd /path/to/ludus

echo "📦 Building Cloud Functions..."
cd functions
npm install  # Install dependencies if needed
npm run build
cd ..

# Verify build succeeded
ls -lh functions/lib/middleware/rateLimit.js
ls -lh functions/lib/api/ludus-health.js

echo "✅ Build complete"
```

**Expected Output:**
```
> ludus-functions@0.1.0 build
> tsc

✅ lib/ directory contains all compiled JavaScript
```

---

### STEP 3: Deploy to Firebase (15 min)

```bash
echo "🚀 Deploying to Firebase..."
firebase deploy --project ludus-dev --only functions,firestore:rules

# Watch for confirmation
# Expected:
# ✔ Deploy complete!
#
# Function URL (ludusHealth): https://us-central1-ludus-dev.cloudfunctions.net/ludusHealth
# Function URL (ludusMetrics): https://us-central1-ludus-dev.cloudfunctions.net/ludusMetrics
#
# Firestore rules published successfully
```

**If deploy fails:**
```bash
# Check authentication
firebase auth:export --project ludus-dev  # Should not error

# Try verbose mode to see what's wrong
firebase deploy --debug --project ludus-dev --only functions,firestore:rules
```

---

### STEP 4: Verify Deployment (10 min)

**4A. List deployed functions:**
```bash
firebase functions:list --project ludus-dev

# Expected output:
# ✔ ludusHealth: https://...
# ✔ ludusMetrics: https://...
```

**4B. Test health endpoint (without Firestore data yet):**
```bash
HEALTH_URL=$(firebase functions:describe ludusHealth \
  --project ludus-dev --format='json' | jq -r '.httpsTrigger.url')

echo "Testing: $HEALTH_URL"
curl -s "$HEALTH_URL" | jq '.'

# Expected:
# {
#   "status": "down",
#   "components": {
#     "firestore": { "status": "error", "message": "Collections not initialized" }
#   }
# }
# (This is expected until we seed data)
```

---

### STEP 5: Seed Firestore Data (15 min)

**This step initializes 25 game nodes.**

```bash
cd /path/to/ludus/functions

# Set credentials for this session
export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/service-account.json

# Run seed script
echo "🌱 Seeding Firestore data..."
npm run ts-node src/scripts/seedDemiurgeData.ts

# Capture exit code
SEED_EXIT=$?

if [ $SEED_EXIT -eq 0 ]; then
  echo "✅ Seed data complete"
else
  echo "❌ Seed script failed (exit code: $SEED_EXIT)"
  exit 1
fi

# Unset credentials (security)
unset GOOGLE_APPLICATION_CREDENTIALS
cd ..
```

**Expected Output:**
```
[Seed] Initializing Demiurge graph...
[Seed] Creating 5 players...
[Seed] Creating 20 NPCs...
[Seed] Creating 50 edges...
[Seed] Creating 10 knowledge gates...
[Seed] Seed data complete! ✅
  - Nodes: 25
  - Edges: 50
  - Gates: 10
  - Avg edge density: 0.17
```

**If seed fails:**
```bash
# Check service account file is valid
cat functions/service-account.json | jq '.type'  # Should output: "service_account"

# Check Firestore is accessible
firebase firestore:inspect ludus_nodes --limit 1 --project ludus-dev

# Run seed again with verbose output
npm run ts-node -- --inspect src/scripts/seedDemiurgeData.ts
```

---

### STEP 6: Verify Health Endpoint with Data (10 min)

**Now Firestore should have data.**

```bash
HEALTH_URL=$(firebase functions:describe ludusHealth \
  --project ludus-dev --format='json' | jq -r '.httpsTrigger.url')

echo "Testing health endpoint: $HEALTH_URL"
curl -s "$HEALTH_URL" | jq '.'

# Expected response (status: ok):
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
#       "npcCount": 20
#     }
#   }
# }
```

**Verification Checklist:**
- [ ] status = "ok" (not "degraded" or "down")
- [ ] nodeCount = 25
- [ ] edgeCount = 50
- [ ] gateCount = 10
- [ ] playerCount = 5
- [ ] npcCount = 20

---

### STEP 7: Test Rate Limiting (10 min)

```bash
HEALTH_URL=$(firebase functions:describe ludusHealth \
  --project ludus-dev --format='json' | jq -r '.httpsTrigger.url')

echo "Testing rate limiting..."
echo "Sending 35 requests in quick succession..."

for i in {1..35}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL")
  echo "Request $i: HTTP $STATUS"
  
  if [ $i -gt 30 ] && [ "$STATUS" = "429" ]; then
    echo "✅ Rate limiting active after request 30"
  fi
  
  sleep 0.1  # 100ms between requests
done

# Expected:
# - Requests 1-30: HTTP 200 ✅
# - Requests 31-35: HTTP 429 (rate limited) ✅
```

---

### STEP 8: Setup Monitoring Dashboard (15 min)

```bash
cd /path/to/ludus

# Create Cloud Logging dashboard
gcloud monitoring dashboards create \
  --config-from-file=monitoring/logging-dashboard.yaml \
  --project ludus-dev

# Verify
gcloud monitoring dashboards list --project ludus-dev --format='value(displayName)'

# Expected output:
# Ludus v0.1 — Cloud Logging Dashboard
```

---

### STEP 9: Enable Firestore Backups (5 min)

```bash
# Create daily backup job
gcloud scheduler jobs create app-engine ludus-backup-daily \
  --project ludus-dev \
  --schedule="0 2 * * *" \
  --http-method=POST \
  --uri="https://us-central1-ludus-dev.cloudfunctions.net/triggerBackup" \
  --oidc-service-account-email=$(gcloud iam service-accounts list \
    --project ludus-dev --format='value(email)' --filter='email~ludus' | head -1)

# Verify
gcloud scheduler jobs list --project ludus-dev --format='value(name)'

# Expected:
# ludus-backup-daily
```

---

### STEP 10: Cleanup Service Account (2 min)

**Remove the sensitive credential file from disk.**

```bash
cd /path/to/ludus/functions

# Remove service account (only after seed completed successfully)
rm -f service-account.json

# Verify it's gone
if [ ! -f service-account.json ]; then
  echo "✅ Service account deleted"
else
  echo "❌ Service account still exists!"
fi
```

---

## Phase 2 Complete ✅

**What's Now Live:**
- ✅ Firestore initialized with 25 game nodes
- ✅ Cloud Functions responding (ludusHealth, ludusMetrics)
- ✅ Rate limiting active (30 req/min per user)
- ✅ Monitoring dashboard created
- ✅ Daily backups scheduled

**Total Time:** ~82 minutes (may be faster or slower depending on network/system)

---

## Next: Phase 3 (Sep 29–Oct 1)

See: `docs/DEPLOYMENT_PHASE2_3_GUIDE.md`

**Phase 3 Tasks:**
1. Integrate ROV Lake tab with webtypicon2
2. Test offline gameplay → sync
3. Build ludus.apk for Quest 3
4. Deploy to device + run device tests

---

## Troubleshooting

### "Failed to authenticate, have you run firebase login?"

```bash
firebase login
firebase use ludus-dev
firebase projects:list  # Verify
```

### "Collections not initialized" after seed

```bash
# Verify seed actually ran
firebase firestore:inspect ludus_nodes --project ludus-dev --limit 1

# If empty, run seed again
cd functions
export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/service-account.json
npm run ts-node src/scripts/seedDemiurgeData.ts
```

### "Rate limiting test shows all 200s (no 429)"

Rate limiting is stored in Firestore. Reset the counter:

```bash
firebase firestore:delete ludus_rate_limits --confirm --project ludus-dev
# Then run rate limit test again
```

### Firestore quota exceeded during testing

Switch to Blaze (pay-as-you-go) plan:
```bash
gcloud billing budgets create --display-name ludus-budget \
  --budget-amount 50 --threshold-rule percent=50,percent=90,percent=100
```

---

## Verification Checklist (Before Phase 3)

- [ ] Health endpoint returns status: "ok"
- [ ] nodeCount = 25, edgeCount = 50, gateCount = 10
- [ ] Rate limiting: 200 for first 30 req/min, 429 for rest
- [ ] Monitoring dashboard visible in Cloud Console
- [ ] Backup schedule confirmed (daily at 2 AM UTC)
- [ ] Service account key deleted from disk
- [ ] No errors in `firebase functions:log`

---

**Owner:** Claude Haiku 4.5  
**Last Updated:** 2026-09-28  
**Next:** Phase 3 starts Sep 29

