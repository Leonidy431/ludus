#!/bin/bash
##
## Phase 2: Firestore Initialization & Cloud Functions Deploy
## Usage: ./scripts/phase2-deploy.sh <project-id> <service-account-path>
##

set -e

PROJECT_ID=${1:-ludus-dev}
SERVICE_ACCOUNT=${2:-./functions/service-account.json}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  LUDUS v0.1: Phase 2 — Firestore Initialization & Deploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================================================
# Validation
# ============================================================================

if [ ! -f "$SERVICE_ACCOUNT" ]; then
  echo "❌ Service account not found: $SERVICE_ACCOUNT"
  echo ""
  echo "Get service account from Firebase Console:"
  echo "  1. Go to: https://console.firebase.google.com/project/$PROJECT_ID/settings/serviceaccounts/adminsdk"
  echo "  2. Click 'Generate New Private Key'"
  echo "  3. Save to: $SERVICE_ACCOUNT"
  exit 1
fi

if ! command -v firebase &> /dev/null; then
  echo "❌ Firebase CLI not installed"
  echo "Install with: npm install -g firebase-tools"
  exit 1
fi

echo "✅ Project: $PROJECT_ID"
echo "✅ Service account: $SERVICE_ACCOUNT"
echo ""

# ============================================================================
# Step 1: Build Cloud Functions
# ============================================================================

echo "📦 Step 1: Building Cloud Functions..."
cd functions
npm run build
cd ..
echo "✅ Build complete (functions/lib/)"
echo ""

# ============================================================================
# Step 2: Deploy to Firebase
# ============================================================================

echo "🚀 Step 2: Deploying to Firebase..."
firebase deploy --project="$PROJECT_ID" --only functions,firestore:rules

echo "✅ Deploy complete"
echo ""

# ============================================================================
# Step 3: Initialize Firestore with Seed Data
# ============================================================================

echo "🌱 Step 3: Seeding Firestore data..."
export GOOGLE_APPLICATION_CREDENTIALS="$SERVICE_ACCOUNT"

cd functions
npm run ts-node src/scripts/seedDemiurgeData.ts
SEED_EXIT=$?
cd ..

if [ $SEED_EXIT -ne 0 ]; then
  echo "❌ Seed data failed (exit code: $SEED_EXIT)"
  exit 1
fi

echo "✅ Seed data complete"
echo ""

# ============================================================================
# Step 4: Verify Health Endpoint
# ============================================================================

echo "🔍 Step 4: Verifying health endpoint..."
sleep 3  # Wait for functions to warm up

HEALTH_URL=$(firebase functions:describe ludusHealth --project="$PROJECT_ID" 2>/dev/null | grep "httpsTrigger" | grep -oP "https://[^\"]*")

if [ -z "$HEALTH_URL" ]; then
  echo "⚠️  Could not determine health endpoint URL"
  echo "Check manually at: https://console.firebase.google.com/project/$PROJECT_ID/functions"
else
  echo "Health endpoint: $HEALTH_URL"

  RESPONSE=$(curl -s "$HEALTH_URL" || echo "{}")
  STATUS=$(echo "$RESPONSE" | jq -r '.status // "unknown"' 2>/dev/null || echo "error")

  if [ "$STATUS" = "ok" ]; then
    echo "✅ Health check passed: $STATUS"
  else
    echo "⚠️  Health check returned: $STATUS"
    echo "Response: $RESPONSE"
  fi
fi

echo ""

# ============================================================================
# Step 5: Cleanup & Summary
# ============================================================================

echo "🧹 Step 5: Cleanup..."
unset GOOGLE_APPLICATION_CREDENTIALS

# Optionally remove service account (sensitive!)
read -p "Delete local service-account.json? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -f "$SERVICE_ACCOUNT"
  echo "✅ Service account deleted"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Phase 2 COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next: Phase 3 (webtypicon2 integration + device testing)"
echo "See: docs/DEPLOYMENT_PHASE2_3_GUIDE.md"
echo ""
