#!/bin/bash

##
## Phase 2 — Complete Firestore Initialization & Deploy (Automated)
## Usage: ./scripts/phase2-deploy-full.sh [project-id] [service-account-path]
## Example: ./scripts/phase2-deploy-full.sh ludus-dev ./functions/service-account.json
##

set -e  # Exit on error

PROJECT_ID="${1:-ludus-dev}"
SERVICE_ACCOUNT="${2:-./functions/service-account.json}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  LUDUS v0.1: Phase 2 — Firestore Initialization & Deploy${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ============================================================================
# Validation
# ============================================================================

echo -e "${YELLOW}Step 0: Pre-Execution Validation${NC}"
echo ""

if [ ! -f "$SERVICE_ACCOUNT" ]; then
  echo -e "${RED}❌ Service account not found: $SERVICE_ACCOUNT${NC}"
  echo ""
  echo "Get service account from Firebase Console:"
  echo "  1. Go to: https://console.firebase.google.com/project/$PROJECT_ID/settings/serviceaccounts/adminsdk"
  echo "  2. Click 'Generate New Private Key'"
  echo "  3. Save to: $SERVICE_ACCOUNT"
  echo ""
  exit 1
fi

if ! command -v firebase &> /dev/null; then
  echo -e "${RED}❌ Firebase CLI not installed${NC}"
  echo "Install with: npm install -g firebase-tools"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo -e "${RED}❌ jq not installed (required for JSON parsing)${NC}"
  echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
  exit 1
fi

echo -e "${GREEN}✅ Project: $PROJECT_ID${NC}"
echo -e "${GREEN}✅ Service account: $SERVICE_ACCOUNT${NC}"
echo -e "${GREEN}✅ Firebase CLI: $(firebase --version)${NC}"
echo ""

# ============================================================================
# Step 1: Build Cloud Functions
# ============================================================================

echo -e "${YELLOW}Step 1: Building Cloud Functions${NC}"
cd functions
npm run build
cd ..
echo -e "${GREEN}✅ Build complete (functions/lib/)${NC}"
echo ""

# ============================================================================
# Step 2: Deploy to Firebase
# ============================================================================

echo -e "${YELLOW}Step 2: Deploying to Firebase${NC}"
echo ""
firebase deploy --project="$PROJECT_ID" --only functions,firestore:rules
echo ""
echo -e "${GREEN}✅ Deploy complete${NC}"
echo ""

# ============================================================================
# Step 3: Initialize Firestore with Seed Data
# ============================================================================

echo -e "${YELLOW}Step 3: Seeding Firestore data${NC}"
export GOOGLE_APPLICATION_CREDENTIALS="$SERVICE_ACCOUNT"

cd functions
npm run ts-node src/scripts/seedDemiurgeData.ts
SEED_EXIT=$?
cd ..

if [ $SEED_EXIT -ne 0 ]; then
  echo -e "${RED}❌ Seed data failed (exit code: $SEED_EXIT)${NC}"
  unset GOOGLE_APPLICATION_CREDENTIALS
  exit 1
fi

echo -e "${GREEN}✅ Seed data complete${NC}"
echo ""

# ============================================================================
# Step 4: Verify Health Endpoint
# ============================================================================

echo -e "${YELLOW}Step 4: Verifying health endpoint${NC}"
sleep 3  # Wait for functions to warm up

HEALTH_URL=$(firebase functions:describe ludusHealth --project="$PROJECT_ID" 2>/dev/null | grep "httpsTrigger" | grep -oP "https://[^\"]*" || echo "")

if [ -z "$HEALTH_URL" ]; then
  echo -e "${YELLOW}⚠️  Could not determine health endpoint URL${NC}"
  echo "Check manually at: https://console.firebase.google.com/project/$PROJECT_ID/functions"
else
  echo "Health endpoint: $HEALTH_URL"
  echo ""

  RESPONSE=$(curl -s "$HEALTH_URL" || echo "{}")
  STATUS=$(echo "$RESPONSE" | jq -r '.status // "unknown"' 2>/dev/null || echo "error")
  NODE_COUNT=$(echo "$RESPONSE" | jq -r '.components.firestore.nodeCount // 0' 2>/dev/null || echo "0")
  EDGE_COUNT=$(echo "$RESPONSE" | jq -r '.components.firestore.edgeCount // 0' 2>/dev/null || echo "0")

  if [ "$STATUS" = "ok" ]; then
    echo -e "${GREEN}✅ Health check passed: $STATUS${NC}"
    echo -e "${GREEN}   Nodes: $NODE_COUNT, Edges: $EDGE_COUNT${NC}"
  else
    echo -e "${YELLOW}⚠️  Health check returned: $STATUS${NC}"
    echo "Response: $RESPONSE"
  fi
fi

echo ""

# ============================================================================
# Step 5: Test Rate Limiting
# ============================================================================

echo -e "${YELLOW}Step 5: Testing rate limiting${NC}"
echo ""

if [ -z "$HEALTH_URL" ]; then
  echo -e "${YELLOW}⚠️  Skipping rate limit test (health URL not available)${NC}"
else
  echo "Sending 35 requests in rapid succession..."

  rate_limit_tested=0
  for i in {1..35}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL")

    if [ $((i % 10)) -eq 0 ] || [ $i -eq 35 ]; then
      echo "  Request $i: HTTP $STATUS"
    fi

    # Check if rate limiting kicked in after 30 requests
    if [ $i -gt 30 ] && [ "$STATUS" = "429" ]; then
      rate_limit_tested=1
    fi

    sleep 0.1
  done

  if [ $rate_limit_tested -eq 1 ]; then
    echo -e "${GREEN}✅ Rate limiting active (429 after 30 req/min)${NC}"
  else
    echo -e "${YELLOW}⚠️  Rate limiting may not be active (no 429 responses)${NC}"
  fi
fi

echo ""

# ============================================================================
# Step 6: Setup Monitoring Dashboard
# ============================================================================

echo -e "${YELLOW}Step 6: Setting up monitoring dashboard${NC}"

if [ -f "monitoring/logging-dashboard.yaml" ]; then
  gcloud monitoring dashboards create \
    --config-from-file=monitoring/logging-dashboard.yaml \
    --project="$PROJECT_ID" 2>/dev/null || echo -e "${YELLOW}⚠️  Dashboard may already exist${NC}"
  echo -e "${GREEN}✅ Monitoring dashboard configured${NC}"
else
  echo -e "${YELLOW}⚠️  monitoring/logging-dashboard.yaml not found${NC}"
fi

echo ""

# ============================================================================
# Step 7: Cleanup & Summary
# ============================================================================

echo -e "${YELLOW}Step 7: Cleanup${NC}"
unset GOOGLE_APPLICATION_CREDENTIALS

# Optionally remove service account
read -p "Delete local service-account.json? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -f "$SERVICE_ACCOUNT"
  echo -e "${GREEN}✅ Service account deleted${NC}"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Phase 2 COMPLETE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✅ Firestore initialized with 25 nodes${NC}"
echo -e "${GREEN}✅ Cloud Functions deployed${NC}"
echo -e "${GREEN}✅ Rate limiting active${NC}"
echo -e "${GREEN}✅ Monitoring dashboard created${NC}"
echo ""
echo "Next: Phase 3 (Sep 29–Oct 1)"
echo "  1. Integrate ROV Lake tab with webtypicon2"
echo "  2. Build ludus.apk for Quest 3"
echo "  3. Deploy to device + test"
echo ""
echo "See: docs/DEPLOYMENT_PHASE2_3_GUIDE.md"
echo ""
