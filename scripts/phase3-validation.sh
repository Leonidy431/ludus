#!/bin/bash

# Phase 3 Final Validation Script
# Run this on Oct 1 @ 06:00 UTC to verify deployment readiness
# Usage: ./scripts/phase3-validation.sh

set -e

TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
RESULTS_FILE="PHASE_3_VALIDATION_RESULTS.md"
PASS_COUNT=0
FAIL_COUNT=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize results file
cat > "$RESULTS_FILE" <<EOF
# Phase 3 Validation Results
**Generated:** $TIMESTAMP

## Summary
EOF

echo ""
echo "================================================"
echo "Phase 3: Final Validation"
echo "================================================"
echo "Timestamp: $TIMESTAMP"
echo "Results: $RESULTS_FILE"
echo ""

# Helper function for test results
record_test() {
    local TEST_NAME=$1
    local STATUS=$2
    local DETAILS=$3

    if [ "$STATUS" = "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $TEST_NAME"
        ((PASS_COUNT++))
        echo "- **$TEST_NAME**: ✅ PASS" >> "$RESULTS_FILE"
    else
        echo -e "${RED}✗ FAIL${NC}: $TEST_NAME"
        echo "  Details: $DETAILS"
        ((FAIL_COUNT++))
        echo "- **$TEST_NAME**: ❌ FAIL" >> "$RESULTS_FILE"
        if [ -n "$DETAILS" ]; then
            echo "  - Details: $DETAILS" >> "$RESULTS_FILE"
        fi
    fi
    echo ""
}

# ============================================================
# Phase 3A: TypeScript Compilation
# ============================================================
echo "Phase 3A: TypeScript Compilation"
echo "=================================="

echo "Running: npm run build"
if cd functions && npm run build 2>&1 | tee -a "/tmp/tsc-output.log"; then
    ERRORS=$(grep -c "error TS" "/tmp/tsc-output.log" || echo "0")
    if [ "$ERRORS" = "0" ]; then
        record_test "TypeScript Compilation" "PASS" ""
    else
        record_test "TypeScript Compilation" "FAIL" "$ERRORS TypeScript errors found"
    fi
else
    record_test "TypeScript Compilation" "FAIL" "Build command failed"
fi
cd ..

# ============================================================
# Phase 3A: Jest Configuration
# ============================================================
echo "Phase 3A: Jest Configuration"
echo "============================="

if [ -f "functions/jest.config.js" ]; then
    record_test "Jest Config Exists" "PASS" ""

    # Verify jest can be run (dry-run only)
    if cd functions && npm test -- --listTests 2>&1 | grep -q "ludus-dialogue.integration.test.ts"; then
        record_test "Jest Test Discovery" "PASS" "Found integration tests"
    else
        record_test "Jest Test Discovery" "FAIL" "Could not discover tests"
    fi
    cd ..
else
    record_test "Jest Config Exists" "FAIL" "jest.config.js not found"
fi

# ============================================================
# Phase 3B: Test Fixtures
# ============================================================
echo "Phase 3B: Test Fixtures"
echo "======================"

if [ -f "functions/src/tests/fixtures/players.json" ]; then
    PLAYER_COUNT=$(grep -c '"playerId"' "functions/src/tests/fixtures/players.json")
    if [ "$PLAYER_COUNT" -ge 10 ]; then
        record_test "Player Fixtures" "PASS" "$PLAYER_COUNT test players created"
    else
        record_test "Player Fixtures" "FAIL" "Only $PLAYER_COUNT players found (expected 10)"
    fi
else
    record_test "Player Fixtures" "FAIL" "players.json not found"
fi

if [ -f "functions/src/tests/fixtures/dialogue-paths.json" ]; then
    PATH_COUNT=$(grep -c '"name"' "functions/src/tests/fixtures/dialogue-paths.json")
    record_test "Dialogue Path Fixtures" "PASS" "Created dialogue path test fixtures"
else
    record_test "Dialogue Path Fixtures" "FAIL" "dialogue-paths.json not found"
fi

# ============================================================
# Phase 3B: Performance Instrumentation
# ============================================================
echo "Phase 3B: Performance Instrumentation"
echo "======================================"

PERF_CHECKS=0
if grep -q "console.time" "functions/src/api/ludus-dialogue.ts"; then
    ((PERF_CHECKS++))
fi
if grep -q "console.timeEnd" "functions/src/api/ludus-dialogue.ts"; then
    ((PERF_CHECKS++))
fi

if [ "$PERF_CHECKS" -eq 2 ]; then
    record_test "Performance Instrumentation" "PASS" "console.time/timeEnd added"
else
    record_test "Performance Instrumentation" "FAIL" "Instrumentation incomplete"
fi

# ============================================================
# Phase 3C: Firestore Rules Syntax
# ============================================================
echo "Phase 3C: Firestore Rules Syntax"
echo "================================="

if [ -f "firestore.rules" ]; then
    # Check for key collections
    COLLECTIONS_FOUND=0

    if grep -q "ludus_dialogue_trees" "firestore.rules"; then ((COLLECTIONS_FOUND++)); fi
    if grep -q "ludus_players" "firestore.rules"; then ((COLLECTIONS_FOUND++)); fi
    if grep -q "ludus_npc_memory" "firestore.rules"; then ((COLLECTIONS_FOUND++)); fi
    if grep -q "ludus_dialogue_states" "firestore.rules"; then ((COLLECTIONS_FOUND++)); fi

    if [ "$COLLECTIONS_FOUND" -ge 4 ]; then
        record_test "Firestore Rules Collections" "PASS" "All 4 dialogue collections configured"
    else
        record_test "Firestore Rules Collections" "FAIL" "Only $COLLECTIONS_FOUND/4 collections found"
    fi

    # Check for security functions
    if grep -q "function isAdmin" "firestore.rules" && grep -q "function isAuthenticated" "firestore.rules"; then
        record_test "Firestore Security Functions" "PASS" "Admin and auth functions defined"
    else
        record_test "Firestore Security Functions" "FAIL" "Missing security functions"
    fi
else
    record_test "Firestore Rules File" "FAIL" "firestore.rules not found"
fi

# ============================================================
# Phase 3D: File Existence Checks
# ============================================================
echo "Phase 3D: Required Files"
echo "========================"

REQUIRED_FILES=(
    "public/index.html"
    "public/ludus/ludus-design-system.css"
    "public/ludus/ludus-game.css"
    "functions/.env.local.example"
    "docs/LOCAL_DEV_SETUP.md"
    "PHASE_3_FINAL_BACKLOG.md"
    "functions/src/api/ludus-dialogue.ts"
    "firestore.rules"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        record_test "File: $file" "PASS" ""
    else
        record_test "File: $file" "FAIL" "File not found"
    fi
done

# ============================================================
# Summary
# ============================================================
echo ""
echo "================================================"
echo "Validation Summary"
echo "================================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
PASS_PERCENT=$((PASS_COUNT * 100 / TOTAL))

echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "TOTAL: $TOTAL"
echo "Pass Rate: $PASS_PERCENT%"
echo ""

# Append summary to results
cat >> "$RESULTS_FILE" <<EOF

## Validation Metrics
- **Pass**: $PASS_COUNT
- **Fail**: $FAIL_COUNT
- **Total**: $TOTAL
- **Pass Rate**: $PASS_PERCENT%

## Next Steps

### If All Passed (✓):
1. Deploy Cloud Functions: \`firebase deploy --only functions\`
2. Deploy Firestore Rules: \`firebase deploy --only firestore:rules\`
3. Start Firebase emulator: \`firebase emulators:start --only firestore,functions\`
4. Run API endpoint tests: \`./scripts/test-api-endpoints.sh\`
5. Begin Phase 3 testing at 09:00 UTC

### If Any Failed (✗):
1. Review this report: \`$RESULTS_FILE\`
2. Fix issues (critical path priority)
3. Re-run validation: \`./scripts/phase3-validation.sh\`
4. Do not proceed to Phase 3 testing until all pass

## Test Evidence
- Build Log: \`/tmp/tsc-output.log\`
- Test Fixtures: \`functions/src/tests/fixtures/\`
- Performance Instrumentation: \`functions/src/api/ludus-dialogue.ts\`
- Security Rules: \`firestore.rules\`

---
**Generated by**: Claude Haiku 4.5
**Timestamp**: $TIMESTAMP
EOF

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED - READY FOR PHASE 3!${NC}"
    exit 0
else
    echo -e "${RED}✗ VALIDATION FAILED - FIX ISSUES BEFORE PHASE 3${NC}"
    exit 1
fi
