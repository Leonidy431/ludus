# Phase 3: Quest 3 Real Device Testing Checklist
## Oct 1-5, 2026 — After Oct 1 AM Validation & Deployment

**Purpose:** Prepare for actual testing on Meta Quest 3 VR headset after Cloud Functions deploy  
**Scope:** What's needed for 09:00 UTC Oct 1 onwards (Quest 3 device testing)  
**Status:** Pre-planning checklist to close gaps before real testing starts

---

## 🎮 QUEST 3 REAL DEVICE REQUIREMENTS

### What's Different From Emulator

| Aspect | Emulator (Oct 1 AM) | Quest 3 Real Device (Oct 1 09:00+) |
|--------|-------|--------|
| **Network** | localhost:5001 | Firebase production or staging domain |
| **CORS** | No CORS headers needed (same origin) | ⚠️ CORS REQUIRED if frontend on different domain |
| **Latency** | Measured in Node.js console | Measured end-to-end through WiFi 6 |
| **Audio/Spatial** | N/A (no speakers) | ✅ Full spatial audio, 3D positioning |
| **Hand Tracking** | N/A (no controllers) | ✅ Real Quest 3 hand tracking API |
| **Frame Rate** | N/A (no rendering) | ✅ 90 FPS Quest 3 target, <20ms input-to-visual |
| **VR Display** | N/A | ✅ 1832×1920 per-eye resolution |
| **Error Context** | Generic errors OK | ⚠️ VR-specific errors needed (what went wrong in 3D?) |

---

## 🔴 P2 GAPS THAT BECOME P1 FOR QUEST 3 TESTING

### Critical Path: Oct 1 AM → Oct 1 09:00+ Quest 3 Start

| Gap ID | Issue | Impact if Missing | Workaround | Fix Time |
|--------|-------|-------------------|-----------|----------|
| **gap_022** | CORS incomplete | Frontend can't call backend API from Quest 3 | ❌ NO WORKAROUND | 1 hr |
| **gap_025** | VR-specific errors | Errors show generic messages, not VR context | Use generic + log in-headset | 2 hrs |
| **gap_026** | Inconsistent logging | Hard to debug issues on real device | Use grep to parse logs | 1 hr |
| **gap_042** | VR latency profiling | Can't measure performance on real device | Guess p50/p95 from emulator | 3 hrs |
| **gap_040** | Hand presence tracking | Can't detect hand gestures in-game | Defer to Phase 4 (only keyboard) | — |

### Must-Fix Before Oct 1 09:00 (4 hrs total)

1. **gap_022 (CORS)** — 1 hr
   - Add `Access-Control-Allow-Origin: *` to all Cloud Functions
   - Or configure specific Quest 3 domain allowlist
   - Test: `curl -i -H "Origin: https://ludus-app.firebase.app" localhost:5001`

2. **gap_025 (VR-specific errors)** — 2 hrs
   - Add error context: "DialogueTree not found for NPC: elder_sergius (checked 4 loaded)"
   - Include recovery hint: "Try restarting dialogue or checking network connection"
   - Example: `"error": "NPC memory unavailable. Device position: (x,y,z). Signal: 3 bars"`

3. **gap_026 (Log formatting)** — 1 hr
   - Standardize: `[LUDUS] [ENDPOINT] [LEVEL] [TIMESTAMP] MESSAGE`
   - Example: `[LUDUS] [API] [INFO] 2026-10-01T09:15:30Z getDialogueTree[elder_sergius]: 45ms`

4. **gap_042 (VR latency profiling)** — 3 hrs (defer 1 hr, do 2 hrs pre-test)
   - Add Quest 3 frame timing capture
   - Setup frame counter + latency tracking
   - Document expected p50/p95 on actual device

### Can Defer to Phase 4 (Won't Block Phase 3)

- **gap_040 (Hand presence tracking)** — Phase 3 uses keyboard input, hands in Phase 4
- **gap_041 (Safety zone docs)** — Quest 3 has built-in safety, doc in Phase 4
- **gap_044 (Wwise integration)** — Audio only, test without audio in Phase 3

---

## 📋 PHASE 3 QUEST 3 TESTING PLAN (Oct 1 PM — Oct 5)

### Oct 1, 09:00 UTC: Go Live on Quest 3

**Pre-Test Checklist (30 min):**
- [ ] Quest 3 device fully charged (100%)
- [ ] WiFi 6 connected to same network as dev machine
- [ ] Cloud Functions deployed and confirmed live
- [ ] CORS headers verified (test endpoint from headset browser)
- [ ] Player account created on device
- [ ] Dialogue trees loaded successfully

**Test Scenario 1: Basic Dialogue Flow (60 min)**
```
1. Launch app on Quest 3
2. Load dialogue tree (getDialogueTree)
3. Select choice from 3 options
4. Observe NPC memory check (getNpcMemory)
5. Persist choice (persistDialogueState)
6. Verify player attributes updated
7. Repeat with 4 different NPCs (elder_sergius, theodora, abba_john, sister_catherine)
```

**Success Criteria:**
- ✅ All dialogue loads in <300ms (visual feedback within 3 frames @ 90 FPS)
- ✅ NPC memory preserved between sessions
- ✅ Player attributes increment correctly
- ✅ No crashes or hangs

**Performance Metrics to Capture:**
- Frame drops (should stay at 90 FPS)
- API response times (p50, p95, p99)
- Hand tracking latency (if tested)
- Audio sync lag (if audio enabled)

### Oct 2, 09:00 UTC: Advanced Testing (60 min)

**Test Scenario 2: Cross-NPC Engagement (30 min)**
```
1. Player interacts with all 4 NPCs in sequence
2. Check getDialogueStats endpoint
3. Verify npcInteractions count = 4
4. Check engagement level = "advanced"
5. Verify attribute aggregation is correct
```

**Test Scenario 3: Error Handling (30 min)**
```
1. Simulate network interruption (toggle WiFi)
2. Attempt API call → expect 500 or timeout
3. Observe error message on-screen
4. Verify game continues (graceful degradation)
5. Restore WiFi and verify recovery
```

**Success Criteria:**
- ✅ Stats correctly aggregated across NPCs
- ✅ Error messages clear and actionable
- ✅ Game doesn't crash on network errors
- ✅ Recovery works after connection restored

### Oct 3-5: Extended Testing & Performance Profiling

**Extended Scenarios:**
- Rapid dialogue switching (stress test)
- Long session (1+ hour of continuous play)
- Multiple player profiles
- Edge case attributes (min/max values)

**Performance Profiling:**
- Measure p50/p95/p99 for all 5 endpoints on real device
- Compare to emulator baseline (should be similar or faster)
- Document any differences
- Identify optimization opportunities if needed

---

## 🔧 IMPLEMENTATION: CORS FIX (gap_022)

**File:** `functions/src/api/ludus-dialogue.ts`

Add CORS headers to all endpoints:

```typescript
// At the start of each endpoint handler:
res.set('Access-Control-Allow-Origin', '*');
res.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
res.set('Access-Control-Allow-Headers', 'Content-Type,Authorization');

// Handle OPTIONS requests:
if (req.method === 'OPTIONS') {
  res.status(204).send('');
  return;
}
```

**Or use middleware (better approach):**

```typescript
// In functions/src/index.ts, before routes:
app.use((req, res, next) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  next();
});
```

**Test:**
```bash
# From Quest 3 (or any browser):
curl -i https://your-firebase-project.cloudfunctions.net/api/ludus/dialogue/tree/elder_sergius

# Should see:
# Access-Control-Allow-Origin: *
# 200 OK
```

---

## 🎯 VR-SPECIFIC ERROR MESSAGES (gap_025)

**Current (generic):**
```json
{ "error": "Dialogue tree not found" }
```

**Improved (VR context):**
```json
{
  "error": "Dialogue tree not found for NPC: elder_sergius",
  "context": {
    "npcId": "elder_sergius",
    "checked": ["ludus_dialogue_trees/elder_sergius"],
    "playerPosition": {"x": 0.5, "y": 1.7, "z": -2.1},
    "networkSignal": "strong"
  },
  "recovery": [
    "Check if NPC is available in this game instance",
    "Restart the dialogue from the NPC menu",
    "If problem persists, check network connection"
  ]
}
```

**Implementation:**
```typescript
// In getDialogueTree endpoint:
const treeDoc = await db.collection('ludus_dialogue_trees').doc(npcId).get();

if (!treeDoc.exists) {
  res.status(404).json({
    error: `Dialogue tree not found for NPC: ${npcId}`,
    context: {
      npcId,
      checked: [`ludus_dialogue_trees/${npcId}`],
      timestamp: new Date().toISOString()
    },
    recovery: [
      `Verify NPC "${npcId}" is available`,
      "Try reloading the scene",
      "Check your internet connection"
    ]
  });
  return;
}
```

---

## 📊 LATENCY PROFILING ON QUEST 3 (gap_042)

### Baseline Targets (Set on Oct 1 AM via emulator)

```
Expected on Quest 3 (with WiFi latency):
- getDialogueTree: p50=60ms, p95=150ms, p99=300ms (vs emulator 50/100/200)
- getNpcMemory: p50=50ms, p95=120ms, p99=250ms (vs emulator 40/80/150)
- persistDialogueState: p50=200ms, p95=400ms, p99=800ms (vs emulator 150/300/500)
- getDialogueStats: p50=130ms, p95=280ms, p99=600ms (vs emulator 100/200/400)

WiFi adds ~50-100ms latency, so expect +50ms on all endpoints
```

### Measurement Plan

**On Quest 3, add performance tracking:**

```typescript
// Client-side (in ludus-game.js):
async function loadDialogueTree(npcId) {
  const startTime = performance.now();
  const response = await fetch(`/api/ludus/dialogue/tree/${npcId}`);
  const endTime = performance.now();
  const duration = endTime - startTime;
  
  // Log to console + send to telemetry
  console.log(`[PERF] getDialogueTree[${npcId}]: ${duration}ms`);
  
  if (window.ludusMetrics) {
    window.ludusMetrics.push({
      endpoint: 'getDialogueTree',
      npcId,
      duration,
      timestamp: new Date().toISOString()
    });
  }
  
  return response.json();
}

// After 1 hour of testing, export metrics:
// JSON.stringify(window.ludusMetrics) → copy to clipboard → save to file
```

**Analysis (offline):**
```bash
# Parse collected metrics:
node -e "
const metrics = require('./quest3-metrics.json');
const byEndpoint = {};

metrics.forEach(m => {
  if (!byEndpoint[m.endpoint]) byEndpoint[m.endpoint] = [];
  byEndpoint[m.endpoint].push(m.duration);
});

Object.entries(byEndpoint).forEach(([endpoint, times]) => {
  const sorted = times.sort((a,b) => a-b);
  const p50 = sorted[Math.floor(sorted.length * 0.5)];
  const p95 = sorted[Math.floor(sorted.length * 0.95)];
  const p99 = sorted[Math.floor(sorted.length * 0.99)];
  console.log(\`\${endpoint}: p50=\${p50}ms, p95=\${p95}ms, p99=\${p99}ms\`);
});
"
```

---

## 📋 PRE-OCT-1-09:00 CHECKLIST

**Must Complete Before Going Live on Quest 3:**

- [ ] CORS headers added to all 5 endpoints
- [ ] CORS headers tested from browser on different domain
- [ ] VR-specific error messages implemented
- [ ] Log format standardized across all endpoints
- [ ] Firebase deployment confirmed: `firebase functions:list`
- [ ] Test player account created in Firestore
- [ ] Dialogue trees seeded: 4 NPCs with full branching
- [ ] NPC memory initialized for test players
- [ ] Quest 3 WiFi connection tested
- [ ] "Launch app" button ready for Quest 3 (or sideloaded APK ready)

**Documentation Ready:**
- [ ] docs/reports/PHASE_3_TEST_LOG.md prepared for manual entries
- [ ] Performance baseline targets from Oct 1 AM emulator test
- [ ] Error scenario reference (API_ERROR_HANDLING_GUIDE.md)
- [ ] Integration test scenarios (INTEGRATION_TEST_SCENARIOS.md)

---

## 🎯 SUCCESS CRITERIA: PHASE 3 QUEST 3 TESTING

### Minimal Success (Phase 3 passes → Phase 4 approved)
- ✅ All 4 NPCs load successfully on Quest 3
- ✅ Dialogue choices persist correctly
- ✅ Player attributes update across sessions
- ✅ No crashes or hangs during 1-hour test

### Full Success (All systems nominal)
- ✅ 90 FPS maintained (no frame drops)
- ✅ API response times within 50% of emulator baseline (accounting for WiFi)
- ✅ Cross-player access properly blocked (403)
- ✅ All error scenarios handled gracefully
- ✅ VR-specific error messages helpful
- ✅ Audio/spatial features working (if enabled)

### Failure Conditions (Phase 3 repeats Oct 2)
- ❌ Any unhandled exceptions / crashes
- ❌ Any endpoint response >1000ms consistently
- ❌ Player attributes not persisting
- ❌ Security rule bypass (unauthorized access)
- ❌ Frame rate below 70 FPS average

---

## 📞 REFERENCE DOCUMENTS

- **docs/reports/PHASE_3_MASTER_CHECKLIST.md** — Oct 1 AM validation reference
- **docs/reports/OCT_1_MORNING_START.md** — 5-step execution plan
- **docs/version-3.0/API_ERROR_HANDLING_GUIDE.md** — Expected error scenarios
- **docs/PERFORMANCE_PROFILING_BASELINE.md** — Measurement methodology
- **docs/INTEGRATION_TEST_SCENARIOS.md** — Test case details

---

**Prepared:** Sep 29, 2026, 23:00 UTC  
**For:** Oct 1-5, 2026 Phase 3 Quest 3 Real Device Testing  
**Status:** 🟡 PLANNING (CORS + VR errors to implement before 09:00 UTC Oct 1)
