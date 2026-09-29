#!/bin/bash

# Ludus API Endpoint Test Suite
# Usage: ./scripts/test-api-endpoints.sh [base_url]
# Example: ./scripts/test-api-endpoints.sh http://localhost:5000

set -e

BASE_URL="${1:-http://localhost:5000}"
RESULTS_FILE="${2:-.test-results.json}"
PASS_COUNT=0
FAIL_COUNT=0

echo "================================================"
echo "Ludus API Endpoint Test Suite"
echo "================================================"
echo "Base URL: $BASE_URL"
echo "Results: $RESULTS_FILE"
echo ""

# Helper function to test endpoint
test_endpoint() {
    local METHOD=$1
    local ENDPOINT=$2
    local DATA=$3
    local EXPECTED_STATUS=$4
    local DESCRIPTION=$5

    echo "Testing: $DESCRIPTION"
    echo "  Request: $METHOD $BASE_URL$ENDPOINT"

    if [ "$METHOD" = "GET" ]; then
        RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL$ENDPOINT" 2>&1 || echo "000\nConnection failed")
    else
        RESPONSE=$(curl -s -w "\n%{http_code}" -X "$METHOD" \
            -H "Content-Type: application/json" \
            -d "$DATA" \
            "$BASE_URL$ENDPOINT" 2>&1 || echo "000\nConnection failed")
    fi

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -n -1)

    echo "  Response Status: $HTTP_CODE"
    echo "  Expected Status: $EXPECTED_STATUS"

    if [ "$HTTP_CODE" = "$EXPECTED_STATUS" ]; then
        echo "  ✓ PASS"
        ((PASS_COUNT++))
    else
        echo "  ✗ FAIL"
        echo "  Response body: $BODY"
        ((FAIL_COUNT++))
    fi
    echo ""
}

# ============================================================
# 1. Test getDialogueTree endpoint
# ============================================================
echo "Phase 1: Dialogue Tree Tests"
echo "----------------------------"

test_endpoint "GET" \
    "/api/ludus/dialogue/tree/elder_sergius" \
    "" \
    "200" \
    "Get dialogue tree for elder_sergius (should succeed if seeded)"

test_endpoint "GET" \
    "/api/ludus/dialogue/tree/nonexistent_npc" \
    "" \
    "404" \
    "Get dialogue tree for nonexistent NPC (should return 404)"

test_endpoint "GET" \
    "/api/ludus/dialogue/tree" \
    "" \
    "400" \
    "Get dialogue tree without npcId (should return 400)"

# ============================================================
# 2. Test getNpcMemory endpoint
# ============================================================
echo "Phase 2: NPC Memory Tests"
echo "-------------------------"

test_endpoint "GET" \
    "/api/ludus/dialogue/memory/elder_sergius/test-player-001" \
    "" \
    "200" \
    "Get NPC memory for test player (should return 200 with firstMeeting=true)"

test_endpoint "GET" \
    "/api/ludus/dialogue/memory/elder_sergius" \
    "" \
    "400" \
    "Get NPC memory without playerId (should return 400)"

# ============================================================
# 3. Test persistDialogueState endpoint
# ============================================================
echo "Phase 3: Dialogue State Persistence Tests"
echo "-----------------------------------------"

PERSIST_PAYLOAD='{
  "playerId": "test-player-001",
  "npcId": "elder_sergius",
  "currentNodeId": "greeting_1",
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

test_endpoint "POST" \
    "/api/ludus/dialogue/state" \
    "$PERSIST_PAYLOAD" \
    "200" \
    "Persist dialogue state with valid player data"

test_endpoint "POST" \
    "/api/ludus/dialogue/state" \
    '{"playerId": "test-player-001"}' \
    "400" \
    "Persist dialogue state with missing fields (should return 400)"

# ============================================================
# 4. Test getDialogueStats endpoint
# ============================================================
echo "Phase 4: Dialogue Stats Tests"
echo "------------------------------"

test_endpoint "GET" \
    "/api/ludus/dialogue/stats/test-player-001" \
    "" \
    "200" \
    "Get dialogue stats for test player"

test_endpoint "GET" \
    "/api/ludus/dialogue/stats/nonexistent-player" \
    "" \
    "404" \
    "Get stats for nonexistent player (should return 404)"

test_endpoint "GET" \
    "/api/ludus/dialogue/stats" \
    "" \
    "400" \
    "Get stats without playerId (should return 400)"

# ============================================================
# 5. Test upsertDialogueTree endpoint (ADMIN ONLY)
# ============================================================
echo "Phase 5: Admin Dialogue Tree Upsert Tests"
echo "-----------------------------------------"

TREE_PAYLOAD='{
  "npcName": "Test Elder",
  "theology": "Hesychasm",
  "startNode": "greeting",
  "nodes": [
    {
      "id": "greeting",
      "text": "Peace be with you, seeker.",
      "branches": [
        {
          "text": "Seek wisdom",
          "nextNodeId": "wisdom_path",
          "attributeBonuses": {"wisdom": 1}
        }
      ]
    },
    {
      "id": "wisdom_path",
      "text": "Understanding comes through contemplation.",
      "branches": [
        {
          "text": "Thank you for your guidance",
          "nextNodeId": null
        }
      ]
    }
  ]
}'

test_endpoint "POST" \
    "/api/ludus/dialogue/tree/test_elder" \
    "$TREE_PAYLOAD" \
    "401" \
    "Upsert dialogue tree without auth token (should return 401)"

# ============================================================
# Summary
# ============================================================
echo "================================================"
echo "Test Summary"
echo "================================================"
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "TOTAL: $TOTAL"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
