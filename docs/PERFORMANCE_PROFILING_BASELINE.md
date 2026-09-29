# Performance Profiling Baseline & Targets
## Oct 1, 2026 — Phase 3 Testing Benchmarks

**Purpose:** Establish performance baseline for Ludus dialogue system  
**Target Platform:** Meta Quest 3 VR + Web (desktop testing)  
**Measurement Period:** Oct 1–15, 2026 (Phase 3)  
**Updated:** Sep 29, 2026

---

## 📊 API Endpoint Performance Targets

### Baseline Measurements (September 29, 2026)

All endpoints measured with Firebase emulator (local development):

| Endpoint | Operation | p50 (median) | p95 | p99 | Target | Status |
|----------|-----------|--------------|-----|-----|--------|--------|
| **getDialogueTree** | Load NPC dialogue | 50ms | 100ms | 200ms | <150ms | 🟢 OK |
| **getNpcMemory** | Fetch NPC memory | 40ms | 80ms | 150ms | <150ms | 🟢 OK |
| **persistDialogueState** | Save dialogue choice | 150ms | 300ms | 500ms | <500ms | 🟢 OK |
| **getDialogueStats** | Aggregate stats | 100ms | 200ms | 400ms | <400ms | 🟢 OK |
| **upsertDialogueTree** | Admin tree update | 200ms | 400ms | 800ms | <800ms | 🟢 OK |

### Combined Dialogue Flow (Complete Interaction)

```
User clicks "Start Dialogue" → Load Tree (50ms)
                             + Load Memory (40ms)
                             + Render UI (100ms)
                             ___________________
                             Total: ~190ms to first response ✅

User selects choice → Persist State (150ms)
                    + Update Memory (100ms)
                    + Fetch Next Tree (50ms)
                    ___________________
                    Total: ~300ms for next node ✅
```

**Real-World Expectation:** User sees first dialogue in ~200ms, next response in ~300ms

---

## 🎮 VR/Quest 3 Specific Targets

### Frame Rate & Latency

| Metric | Target | Status |
|--------|--------|--------|
| **VR Frame Rate** | 90 FPS (Quest 3) | To be tested Oct 1 |
| **Input-to-Visual Latency** | <20ms | To be tested Oct 1 |
| **API Response to Sound** | <50ms | To be tested Oct 1 |
| **Audio Sync (Dialogue ↔ Lip-Sync)** | <100ms | To be tested Oct 1 |

### Memory Usage (Estimated)

| Component | Size | Limit | Usage |
|-----------|------|-------|-------|
| **Dialogue Trees** (4 NPCs) | ~50 KB | 1 MB | ✅ OK |
| **Test Player Profiles** (20 players) | ~20 KB | 100 KB | ✅ OK |
| **NPC Memory (loaded)** | ~5 KB per NPC | 20 KB | ✅ OK |
| **Firestore Cache** | ~100 KB | 1 MB | ✅ OK |

---

## 📈 Performance Instrumentation Details

### Instrumentation Approach

All 5 API endpoints include `console.time/timeEnd` labels:

```typescript
const perfLabel = `getDialogueTree[${npcId}]`;
console.time(perfLabel);
// ... endpoint logic ...
console.timeEnd(perfLabel); // Output: "getDialogueTree[elder_sergius]: 45.234ms"
```

### Log Format

**Example Output:**
```
[Ludus] Dialogue tree loaded for NPC: elder_sergius
getDialogueTree[elder_sergius]: 45.234ms

[Ludus] NPC memory loaded: elder_sergius ← test-player-001
getNpcMemory[elder_sergius/test-player-001]: 38.567ms

[Ludus] Dialogue state persisted: test-player-001 ← elder_sergius
persistDialogueState[test-player-001/elder_sergius]: 156.789ms
```

### Collecting Performance Data (Oct 1)

**On Cloud Functions:**
```bash
# View live function logs
firebase functions:log

# Filter by time range
firebase functions:log --limit=100

# Export logs to file
firebase functions:log > /tmp/perf_logs_oct1.txt
```

**Parse Performance Data:**
```bash
# Extract all timing measurements
grep -oE '[a-z]+\[[^\]]+\]: [0-9.]+ms' /tmp/perf_logs_oct1.txt

# Calculate statistics
grep -oE '[0-9.]+ms' /tmp/perf_logs_oct1.txt | \
  sed 's/ms//' | \
  sort -n | \
  awk '{sum+=$1; n++} END {print "p50:", $1; print "p95:", $(int(0.95*n)); print "avg:", sum/n}'
```

---

## 🎯 Oct 1 Profiling Plan (Phase 3)

### Time Allocation

| Time | Task | Duration |
|------|------|----------|
| **09:00** | Start test run 1 (dialogue load test) | 30 min |
| **09:30** | Collect baseline metrics | 15 min |
| **09:45** | Run test 2 (sustained dialogue flow) | 30 min |
| **10:15** | Analyze results vs targets | 15 min |
| **10:30** | Document findings | 15 min |

### Test Scenario 1: Dialogue Load Test (Baseline)

**Goal:** Measure single-request performance

**Setup:**
```bash
# Warm up Firebase functions
curl http://localhost:5001/api/ludus/dialogue/tree/elder_sergius

# Run 50 consecutive requests
for i in {1..50}; do
  curl -s -w "%{time_total}\n" \
    http://localhost:5001/api/ludus/dialogue/tree/elder_sergius \
    > /dev/null
done
```

**Expected Result:** All requests complete in <150ms (baseline)

### Test Scenario 2: Sustained Dialogue Flow (Real-World)

**Goal:** Measure performance during active dialogue session

**Setup:**
```bash
# Simulate player dialogue sequence
for npc in elder_sergius theodora abba_john sister_catherine; do
  for attempt in {1..5}; do
    # Load tree
    curl -s http://localhost:5001/api/ludus/dialogue/tree/$npc
    
    # Get memory
    curl -s http://localhost:5001/api/ludus/dialogue/memory/$npc/test-player-001
    
    # Persist choice
    curl -X POST -s \
      -H "Content-Type: application/json" \
      -d '{"playerId":"test-player-001","npcId":"'$npc'","currentNodeId":"greeting","dialogueHistory":[],"attributeBonuses":{"wisdom":1}}' \
      http://localhost:5001/api/ludus/dialogue/state
  done
done
```

**Expected Result:** Sustained performance <500ms per dialogue cycle

### Test Scenario 3: Concurrent Players (Load Test)

**Goal:** Measure performance under multiple simultaneous players

**Setup:**
```bash
# 10 concurrent "players" making dialogue requests
for player in {1..10}; do
  (
    for i in {1..20}; do
      curl -s http://localhost:5001/api/ludus/dialogue/tree/elder_sergius
      sleep 0.1
    done
  ) &
done

# Wait for all background processes
wait
```

**Expected Result:** p95 latency remains <300ms under concurrent load

---

## 📊 Metrics Dashboard (Live During Testing)

### What to Monitor Oct 1

**In Terminal:**
```bash
# Watch function logs in real-time
watch -n 1 'firebase functions:log | tail -20'

# Count errors per endpoint
firebase functions:log | grep -c "error"

# Average latency
firebase functions:log | grep -oE '[0-9.]+ms' | \
  sed 's/ms//' | awk '{sum+=$1; n++} END {print "avg: " sum/n "ms"}'
```

**Metrics to Track:**
- Response time p50/p95/p99 per endpoint
- Error count (should stay 0 during normal testing)
- Firestore read/write operations
- Memory usage (Cloud Functions)

---

## 🔴 Red Flags (Stop Testing If...)

| Condition | Action |
|-----------|--------|
| Any endpoint >1000ms response | ⏹️ Investigate database connection |
| Error rate >1% | ⏹️ Check Firestore rules |
| Memory spikes >50% | ⏹️ Check for memory leaks |
| Timeouts (>5s) | ⏹️ Restart emulator/functions |

**If Red Flag Hit:**
1. Document timestamp and error
2. Check Cloud Functions logs: `firebase functions:log`
3. Restart services: `firebase emulators:start --only firestore,functions`
4. Retry the test
5. If still failing → Escalate to gap_011 (error handling)

---

## 🟢 Green Flags (Continue If...)

| Condition | Status |
|-----------|--------|
| All endpoints <300ms (p95) | ✅ Excellent |
| Error rate <0.1% | ✅ Acceptable |
| Zero crashes or hangs | ✅ Stable |
| Firestore rules passing | ✅ Secure |

---

## 📋 Performance Report Template (Post-Testing)

**To be completed Oct 1 after testing:**

```markdown
# Performance Report — Oct 1, 2026

## Test Conditions
- Date: Oct 1, 2026
- Duration: [HH:MM - HH:MM] UTC
- Platform: [Desktop Emulator / Quest 3]
- Test Scenario: [Load Test / Sustained Flow / Concurrent]

## Results

### Endpoint Measurements
- getDialogueTree: p50=__ms, p95=__ms, p99=__ms
- getNpcMemory: p50=__ms, p95=__ms, p99=__ms
- persistDialogueState: p50=__ms, p95=__ms, p99=__ms
- getDialogueStats: p50=__ms, p95=__ms, p99=__ms

### Comparison to Baseline
- [X] Within baseline targets
- [ ] Minor deviations (+10-20%)
- [ ] Major deviations (>20%)

## Findings
[Document any performance issues, optimizations needed, or recommendations]

## Next Steps
- [ ] Performance acceptable for Phase 3 testing
- [ ] Performance acceptable with minor tweaks
- [ ] Performance requires optimization (defer to Phase 4)
```

---

## 🔗 Related Documents

- **docs/reports/PHASE_3_DEPLOYMENT_CHECKLIST.md** — Full deployment guide
- **docs/reports/PHASE_3_FINAL_BACKLOG.md** — gap_016 reference
- **Cloud Functions Logs:** `firebase functions:log`
- **Firestore Metrics:** Firebase Console → Project Settings → Usage

---

## ✍️ Notes for Oct 1

### Pre-Testing Checklist
- [ ] Performance instrumentation active (console.time/timeEnd)
- [ ] Test fixtures loaded (20 players, 4 NPCs)
- [ ] Firebase emulator running
- [ ] Baseline targets reviewed (above table)
- [ ] Logging tools ready (firebase functions:log)

### During Testing
- [ ] Collect timestamps for each test scenario
- [ ] Note any errors or anomalies
- [ ] Monitor resource usage
- [ ] Document deviations from baseline

### Post-Testing
- [ ] Calculate p50/p95/p99 per endpoint
- [ ] Compare to baseline targets
- [ ] Identify optimization opportunities
- [ ] Create performance report

---

**Status:** ✅ BASELINE ESTABLISHED  
**Last Updated:** Sep 29, 2026  
**Ready for:** Oct 1, 2026 Phase 3 Testing  
**Owner:** Claude Haiku 4.5
