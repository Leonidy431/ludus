#!/bin/bash

# Ludus Load Testing Script (gap_028)
#
# Tests all 5 API endpoints under load to measure performance degradation
# Useful for benchmarking on Oct 1 and identifying bottlenecks
#
# Usage: ./scripts/loadtest-api-endpoints.sh [base_url] [num_requests] [concurrency]
# Example: ./scripts/loadtest-api-endpoints.sh http://localhost:5001 100 10

set -e

BASE_URL="${1:-http://localhost:5001}"
NUM_REQUESTS="${2:-50}"
CONCURRENCY="${3:-5}"
RESULTS_FILE="${4:-.loadtest-results.json}"

echo "================================================"
echo "Ludus API Load Testing Suite"
echo "================================================"
echo "Base URL: $BASE_URL"
echo "Requests per endpoint: $NUM_REQUESTS"
echo "Concurrent requests: $CONCURRENCY"
echo "Results: $RESULTS_FILE"
echo ""

# Cleanup temp file
rm -f "$RESULTS_FILE"

# Helper function to test endpoint repeatedly
loadtest_endpoint() {
    local METHOD=$1
    local ENDPOINT=$2
    local DATA=$3
    local NAME=$4

    echo ""
    echo "📊 Load Testing: $NAME"
    echo "  Endpoint: $METHOD $BASE_URL$ENDPOINT"
    echo "  Requests: $NUM_REQUESTS | Concurrency: $CONCURRENCY"

    # Create temp results file
    local TEMP_RESULTS="/tmp/ludus_loadtest_${NAME}.txt"
    > "$TEMP_RESULTS"

    # Run load tests
    for i in $(seq 1 $NUM_REQUESTS); do
        (
            if [ "$METHOD" = "GET" ]; then
                TIME_RESULT=$(curl -s -w "%{time_total}" "$BASE_URL$ENDPOINT" 2>&1 | grep -oE "^[0-9.]+")
            else
                TIME_RESULT=$(curl -s -w "%{time_total}" -X "$METHOD" \
                    -H "Content-Type: application/json" \
                    -d "$DATA" \
                    "$BASE_URL$ENDPOINT" 2>&1 | grep -oE "^[0-9.]+")
            fi
            echo "$TIME_RESULT" >> "$TEMP_RESULTS"
        ) &

        # Control concurrency
        if [ $((i % CONCURRENCY)) -eq 0 ]; then
            wait
        fi
    done

    # Wait for remaining jobs
    wait

    # Calculate statistics
    if [ -s "$TEMP_RESULTS" ]; then
        local TIMES=$(cat "$TEMP_RESULTS" | sort -n)
        local COUNT=$(echo "$TIMES" | wc -l)
        local MIN=$(echo "$TIMES" | head -1)
        local MAX=$(echo "$TIMES" | tail -1)
        local AVG=$(echo "$TIMES" | awk '{sum+=$1} END {print sum/NR}')
        local P50=$(echo "$TIMES" | sed -n "$((COUNT/2))p")
        local P95=$(echo "$TIMES" | sed -n "$((COUNT*95/100))p")
        local P99=$(echo "$TIMES" | sed -n "$((COUNT*99/100))p")

        echo "  ✓ Completed $COUNT requests"
        echo "  Statistics:"
        printf "    Min:  %7.3fs | p50: %7.3fs | p95: %7.3fs\n" "$MIN" "$P50" "$P95"
        printf "    Avg:  %7.3fs | p99: %7.3fs | Max: %7.3fs\n" "$AVG" "$P99" "$MAX"

        # Append to results
        cat >> "$RESULTS_FILE" << EOF
{
  "endpoint": "$NAME",
  "method": "$METHOD",
  "path": "$ENDPOINT",
  "requests": $COUNT,
  "concurrency": $CONCURRENCY,
  "stats": {
    "min_seconds": $MIN,
    "max_seconds": $MAX,
    "avg_seconds": $AVG,
    "p50_seconds": $P50,
    "p95_seconds": $P95,
    "p99_seconds": $P99
  },
  "timestamp": "$(date -Iseconds)"
}
EOF
        echo "" >> "$RESULTS_FILE"
    else
        echo "  ✗ No results collected (check if endpoint is running)"
    fi

    # Cleanup
    rm -f "$TEMP_RESULTS"
}

# Test all endpoints
loadtest_endpoint "GET" "/api/ludus/dialogue/tree/elder_sergius" "" "getDialogueTree"
loadtest_endpoint "GET" "/api/ludus/dialogue/memory/elder_sergius/test-player-001" "" "getNpcMemory"
loadtest_endpoint "POST" "/api/ludus/dialogue/state" '{"playerId":"test-player-001","npcId":"elder_sergius","currentNodeId":"greeting","dialogueHistory":[],"attributeBonuses":{"wisdom":1}}' "persistDialogueState"
loadtest_endpoint "GET" "/api/ludus/dialogue/stats/test-player-001" "" "getDialogueStats"
loadtest_endpoint "POST" "/api/ludus/dialogue/tree/test_npc" '{"npcName":"Test","startNode":"start","nodes":[]}' "upsertDialogueTree"

echo ""
echo "================================================"
echo "✅ Load Testing Complete!"
echo "================================================"
echo ""
echo "Results saved to: $RESULTS_FILE"
echo ""
echo "📊 Summary:"
cat "$RESULTS_FILE" | grep -E '"endpoint"|"requests"|"p95_seconds"' || echo "No results found"
echo ""
echo "💡 Analysis Tips:"
echo "  1. Compare p95 to baseline targets (see PERFORMANCE_PROFILING_BASELINE.md)"
echo "  2. Look for endpoints with increasing latency (sign of database issues)"
echo "  3. If p95 > 500ms, investigate network or database performance"
echo "  4. Run with higher NUM_REQUESTS to catch cache behavior changes"
echo ""
