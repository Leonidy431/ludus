---
id: ludus-rov-meta-integration
type: comprehensive-guide
tags: [ludus, rov, meta-quest-3, integration, architecture, deployment, telemetry]
version: 1.0
status: design-ready
date: 2026-09-28
---

# Ludus ROV Meta Integration — Complete System Architecture

**Scope:** End-to-end system integrating Meta Quest 3 VR headset + ROV DiveComputer telemetry + Ludus game backend  
**Timeline:** Phase 2 (Sep 28) → Phase 3 (Sep 29–Oct 1) → Production (Oct 2)  
**Components:** OVRInput → DiveComputerController → DemiurgeBridge → Firestore → webtypicon2 UI

---

## 1. System Architecture (3-Tier)

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          TIER 1: VR HARDWARE                             │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  Meta Quest 3 (8GB RAM, Snapdragon XR2 Gen 2)                     │  │
│  │  ├─ Display: Dual 1800×1920 OLED, 90 Hz refresh                  │  │
│  │  ├─ Trackers: 6-DOF headset + hand controllers                   │  │
│  │  ├─ Controllers: Left + Right Touch (joystick + triggers)        │  │
│  │  └─ Runtime: Android 13 + Unity Engine 2022 LTS                  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                              │                                            │
│                              ▼                                            │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  Ludus VR Application (C# / Unity)                                │  │
│  │  ├─ OVRManager: Hardware initialization + tracking               │  │
│  │  ├─ DiveComputerController: Joystick polling + ROV state         │  │
│  │  ├─ DemiurgeBridge: Telemetry buffering + attribute mapping      │  │
│  │  └─ Scene Controller: VR UI rendering + input handling           │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
                               │
        ┌──────────────────────┴──────────────────────┐
        │                                             │
        ▼                                             ▼
┌──────────────────────────────┐          ┌──────────────────────────────┐
│  TIER 2: CLOUD BACKEND       │          │  TIER 3: WEB FRONTEND        │
│  (Google Cloud Platform)     │          │  (webtypicon2)               │
│                              │          │                              │
│ • Firestore Database         │          │ • ludus-game.js              │
│ • Cloud Functions            │          │ • ROV Lake tab               │
│ • Cloud Logging              │          │ • Real-time Firestore sync   │
│ • Cloud Monitoring           │          │ • Browser UI (90FPS support) │
└──────────────────────────────┘          └──────────────────────────────┘
```

---

## 2. Data Flow — Complete Journey

### 2.1 Input Path (VR → Cloud)

```
1. HARDWARE INPUT (30 Hz poll rate)
   OVRInput.Get(Axis2D.PrimaryThumbstick) → { x: 0.5, y: -0.8 }
   OVRInput.Get(Axis1D.PrimaryIndexTrigger) → 0.75 (analog 0-1)
   
2. CONTROLLER PROCESSING (Unity Update loop)
   DiveComputerController.PollControllers()
   └─ Map joystick axes → ROV velocity vectors
   └─ Trigger → Depth modulation
   └─ Buttons → Gate attempts / waypoints
   
3. TELEMETRY BUFFERING (30 samples collected over 1 second)
   Queue: [
     { depth: 150m, velocity: 1.2 m/s, power: 0.75 },
     { depth: 151m, velocity: 1.3 m/s, power: 0.76 },
     ...
   ]
   
4. ATTRIBUTE MAPPING (Every 1 second)
   Depth (150m) → Wisdom attribute (15)
   Power (0.75) → Constitution attribute (14)
   Velocity (1.2 m/s) → Dexterity attribute (12)
   
5. CLOUD POSTING (1 Hz to Firestore)
   POST /ludus_nodes/{playerNodeId}
   {
     "attributes": { "wisdom": 15, "constitution": 14, "dexterity": 12 },
     "telemetry": { "lastDepth": 150, "lastVelocity": 1.2, "lastPower": 0.75 },
     "lastTelemetryUpdate": "2026-09-28T14:30:45.123Z"
   }
```

### 2.2 Output Path (Cloud → UI)

```
1. FIRESTORE REAL-TIME SUBSCRIPTION
   webtypicon2/public/ludus-game.js
   ├─ Listens to ludus_nodes/{playerNodeId}
   └─ Triggers onSnapshot() callback on every write
   
2. BROWSER RECEIVES UPDATE
   {
     "nodeId": "player-001",
     "attributes": { "wisdom": 15, "constitution": 14, "dexterity": 12 },
     "telemetry": { "lastDepth": 150, "lastVelocity": 1.2 }
   }
   
3. UI RENDER (React/Vue component)
   <AttributeDisplay>
     Wisdom: 15 ✓ (was 14)
     Constitution: 14
     Dexterity: 12 ✓ (was 11)
   </AttributeDisplay>
   
4. VISUAL FEEDBACK
   Player sees real-time attribute changes
   Latency: ~500-2000 ms (Firestore sync time)
```

---

## 3. Component Details

### 3.1 VR Layer — DiveComputerController

**Location:** `UnityVR/Assets/Scripts/DiveComputer/DiveComputerController.cs`

**Responsibility:** Bridge between OVRInput hardware events and ROV telemetry

**Key Methods:**

```csharp
void Update()                          // Called every frame (90 times/sec on Quest 3)
{
  // Poll controllers every 1/30th of a frame
  if (Time.time - lastPollTime >= 1f/30f) {
    PollControllers();
    lastPollTime = Time.time;
  }
}

ControllerInput PollControllers()     // Read current joystick/trigger state
{
  return new ControllerInput {
    leftThumbstick = OVRInput.Get(OVRInput.Axis2D.PrimaryThumbstick),
    rightThumbstick = OVRInput.Get(OVRInput.Axis2D.SecondaryThumbstick),
    leftTrigger = OVRInput.Get(OVRInput.Axis1D.PrimaryIndexTrigger),
    rightTrigger = OVRInput.Get(OVRInput.Axis1D.SecondaryIndexTrigger),
  };
}

void ProcessInput(ControllerInput input)  // Convert to ROV state
{
  // Map physical joystick → movement vectors
  velocity.z = input.rightThumbstick.y * MAX_VELOCITY;
  velocity.x = input.rightThumbstick.x * MAX_VELOCITY;
  
  // Depth control via trigger
  depth = Mathf.Lerp(currentDepth, input.leftTrigger * MAX_DEPTH, 0.1f);
  
  // Send to DemiurgeBridge for buffering
  demiurgeBridge.EnqueueTelemetry(new ROVTelemetry { velocity, depth, ... });
}
```

**Output:** `ROVTelemetry` struct (timestamp, velocity, depth, heading, power)

---

### 3.2 Bridge Layer — DemiurgeBridge

**Location:** `ludus/functions/src/scripts/seedDemiurgeData.ts` (or live streaming endpoint)

**Responsibility:** Buffer telemetry, map to D&D attributes, sync to Firestore

**Telemetry Buffer:**

```
Time (sec)   Depth (m)   Velocity (m/s)   Power   Buffer State
0.0          100         0.0              0.0     [0]
0.033        100         0.5              0.2     [0, 1]
0.066        101         0.8              0.3     [0, 1, 2]
...
1.0          130         1.2              0.75    [0..29] → FLUSH
```

**Mapping Functions:**

```csharp
// Telemetry → D&D Attributes (every 1 second)
int wisdom = MapToAttribute(avgDepth, 0, 300, 8, 18);           // 8-18
int constitution = MapToAttribute(avgPower, 0, 1, 8, 18);      // 8-18
int dexterity = MapToAttribute(avgVelocity, 0, 5, 8, 18);      // 8-18

// Linear interpolation example:
// If depth = 150m (midpoint of 0-300 range)
// Wisdom = Lerp(8, 18, 0.5) = 13
```

**Firestore Sync:**

```json
POST /ludus_nodes/{playerNodeId}
{
  "attributes": {
    "wisdom": 13,
    "constitution": 15,
    "dexterity": 12
  },
  "telemetry": {
    "lastDepth": 150,
    "lastVelocity": 1.2,
    "lastPower": 0.75,
    "lastHeading": 45
  },
  "lastTelemetryUpdate": "2026-09-28T14:30:45.123Z"
}
```

**Frequency:** 1 Hz (every 1 second)

---

### 3.3 Backend Layer — Firestore + Cloud Functions

**Collections:**
- `ludus_nodes` — Player + NPC profiles (attributes, telemetry)
- `ludus_edges` — Relationships (immutable)
- `ludus_knowledge_gates` — Gate attempts + answers
- `ludus_rate_limits` — Rate limit counters (per user)
- `ludus_health_checks` — Performance metrics

**Security Rules:**

```javascript
// Players can WRITE own player node
match /ludus_nodes/{nodeId} {
  allow read: if isAuthenticated();
  allow update: if isNodeOwner(nodeId) && 
                   !isRateLimited(nodeId);
}

// Rate limiting via document counter
function isRateLimited(uid) {
  let counter = get(/databases/$(database)/documents/ludus_rate_limits/$(uid));
  let now = request.time.toMillis();
  
  // Reset if older than 60 seconds
  if (counter == null || (now - counter.data.lastUpdate) > 60000) {
    return false;  // Allow
  }
  
  // Enforce limit: 30 updates/minute per player
  return counter.data.count >= 30;
}
```

**Cloud Functions:**

```typescript
// Health check endpoint (rate limited)
export const ludusHealth = functions.https.onRequest(async (req, res) => {
  const rateLimiter = rateLimit(rateLimitPresets.healthEndpoint);
  
  // Check limit first
  if (!await rateLimiter.check(req.ip)) {
    return res.status(429).json({ error: 'Rate limited' });
  }
  
  // Then verify health
  const db = getFirestore();
  const nodeCount = await db.collection('ludus_nodes').count().get();
  
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    components: {
      firestore: { status: 'ok', nodeCount: nodeCount.data().count },
      // ...
    }
  });
});
```

---

### 3.4 Frontend Layer — webtypicon2

**File:** `webtypicon2/public/ludus-game.js`

**ROV Lake Tab Component:**

```javascript
class RovLakeManager {
  constructor(playerNodeId) {
    this.playerNodeId = playerNodeId;
    this.subscriptions = [];
  }

  // Real-time listener on player node
  subscribeToTelemetry() {
    const ref = db.collection('ludus_nodes').doc(this.playerNodeId);
    
    this.subscriptions.push(
      ref.onSnapshot((snap) => {
        const data = snap.data();
        
        // Update UI with live telemetry
        this.renderAttributePanel({
          wisdom: data.attributes.wisdom,
          constitution: data.attributes.constitution,
          dexterity: data.attributes.dexterity,
          telemetry: data.telemetry
        });
        
        // Show data freshness indicator
        const age = Date.now() - data.lastTelemetryUpdate.toMillis();
        this.showDataFreshness(age);  // "Updated 0.5s ago"
      })
    );
  }

  renderAttributePanel(attributes) {
    const html = `
      <div class="rov-lake-panel">
        <h3>ROV Telemetry</h3>
        <div class="attributes">
          <div class="attribute">
            <label>Wisdom (Depth)</label>
            <progress value="${attributes.wisdom}" max="18"></progress>
            ${attributes.wisdom}
          </div>
          <div class="attribute">
            <label>Constitution (Power)</label>
            <progress value="${attributes.constitution}" max="18"></progress>
            ${attributes.constitution}
          </div>
          <div class="attribute">
            <label>Dexterity (Velocity)</label>
            <progress value="${attributes.dexterity}" max="18"></progress>
            ${attributes.dexterity}
          </div>
        </div>
        <div class="telemetry-details">
          <p>Depth: ${attributes.telemetry.lastDepth}m</p>
          <p>Velocity: ${attributes.telemetry.lastVelocity.toFixed(1)} m/s</p>
          <p>Power: ${(attributes.telemetry.lastPower * 100).toFixed(0)}%</p>
        </div>
      </div>
    `;
    
    document.getElementById('rov-lake-container').innerHTML = html;
  }

  showDataFreshness(ageMs) {
    const indicator = ageMs < 500 ? '🟢 Live' : '🟡 Cached';
    document.getElementById('data-freshness').textContent = indicator;
  }
}
```

---

## 4. Deployment Sequence

### Phase 2: Cloud Infrastructure (Sep 28, 82 min)

```bash
# Step 1: Download service account (manual)
# → Firebase Console → Service Accounts → Generate Private Key

# Step 2: Build & deploy functions
npm run build
firebase deploy --only functions,firestore:rules

# Step 3: Seed Firestore data
export GOOGLE_APPLICATION_CREDENTIALS=functions/service-account.json
npm run ts-node src/scripts/seedDemiurgeData.ts

# Step 4: Verify health endpoint
curl https://ludus-dev.cloudfunctions.net/ludusHealth
# Expected: { status: "ok", components: { firestore: { nodeCount: 25 } } }

# Step 5: Test rate limiting
# Send 35 requests in rapid succession
# Expected: Requests 1-30 → 200, requests 31-35 → 429

# Step 6-8: Monitoring + backups
gcloud monitoring dashboards create --config-from-file=monitoring/logging-dashboard.yaml
gcloud scheduler jobs create app-engine ludus-backup-daily --schedule="0 2 * * *" ...
```

**Output:** Firestore live, endpoints responding, rate limiting active

### Phase 3A: webtypicon2 Integration (Sep 29)

```bash
# Add ROV Lake tab to ludus-game.js
# Initialize RovLakeManager
# Subscribe to ludus_nodes/{playerNodeId}
# Render real-time attribute updates

# Test locally with IAP tunnel to VM8
gcloud compute start-iap-tunnel panopticon-mirror-vm 8090 --local-host-port=localhost:8090
# Open http://localhost:8090 in browser
```

### Phase 3B: Device Testing (Sep 30 – Oct 1)

```bash
# Build APK (Debug mode)
# Unity → File → Build Settings → Build

# Deploy to emulator
adb install -r ludus-debug.apk

# Test startup sequence
adb logcat | grep "DiveComputer"
# Expected: "Initialized @ 30 Hz", "Controllers detected"

# Test joystick input
# Physical: Move left stick forward
# Expected: Firestore shows wisdom attribute increasing

# Test latency
# Time from joystick move → browser UI update
# Target: < 2 seconds (Firestore sync time)
```

---

## 5. Performance Targets

| Metric | Target | How Measured |
|--------|--------|--------------|
| Controller detection | < 0.5 s | ADB logcat timestamp |
| Joystick poll latency | < 10 ms | DiveComputerController timing |
| Telemetry buffer → POST | < 500 ms | Firestore write timestamp |
| Browser UI update | < 2 s | OnSnapshot listener delay |
| End-to-end input lag | < 100 ms | VR perception (critical for comfort) |
| VR FPS | 90 FPS | Quest 3 native refresh rate |
| Battery impact | < 15% per hour | Battery drain in sustained use |

---

## 6. Error Handling

### Controller Detection Fails
```csharp
if (!OVRInput.IsControllerConnected(...)) {
  ShowUIMessage("Controllers not detected. Check battery.");
  EnableGamepadFallback();  // Keyboard/mouse input
  RetryDetectionEvery(2f);  // Every 2 seconds
}
```

### Firestore Offline
```csharp
try {
  await firebaseRef.Child($"ludus_nodes/{nodeId}").SetValueAsync(...);
} catch (OfflineException) {
  localCache.Save($"pending_{nodeId}", telemetry);  // Cache locally
  // Retry on next sync (when online)
}
```

### Rate Limit Hit
```javascript
if (response.status === 429) {
  showWarning("Telemetry rate limited. Retrying in 60s.");
  setTimeout(() => retrySync(), 60000);
}
```

---

## 7. Testing Checklist

- [ ] **Startup:** Controllers detected < 0.5s
- [ ] **Input:** Move left stick → see attribute change in browser UI
- [ ] **Sync:** Firestore document updates within 2s of joystick input
- [ ] **Rate Limit:** 31st request in 1 minute returns 429
- [ ] **Offline:** Close browser, play offline, reconnect → data syncs
- [ ] **FPS:** Maintain 90 FPS during gameplay (ADB profiler)
- [ ] **Battery:** < 15% drain per hour sustained play

---

## 8. References

- **VR Control:** `docs/VR_JOYSTICK_DIVECOMPUTER_CONTROL.md`
- **ROV Lake UI:** `docs/ROV_LAKE_FRONTEND_INTEGRATION.md`
- **Backend Auth:** `docs/version-3.0/S12_FIRESTORE_AUTH.md`
- **Offline Sync:** `docs/version-3.0/A10_OFFLINE_SYNC.md`
- **Demiurge:** `docs/DEMIURGE_ARCHITECTURE.md`

---

**Status:** Architecture complete, ready for Phase 2 execution  
**Owner:** Claude Haiku 4.5  
**Session:** 2026-09-28 10:54 UTC  
**Next:** Execute Phase 2 deployment with service account credentials

