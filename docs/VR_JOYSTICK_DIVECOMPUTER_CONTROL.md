---
id: ludus-vr-joystick-rov-control
type: feature-specification
tags: [ludus, vr, meta-quest-3, joystick, divecomputer, rov, input-mapping]
version: 1.0
status: design-ready
date: 2026-09-28
---

# VR Joystick & ROV DiveComputer Control — Meta Quest 3 Integration

**Purpose:** Map physical joystick input (Meta Quest 3 controllers) to ROV telemetry + D&D attribute updates  
**Input Source:** OVRInput (Meta Quest 3 native API)  
**Output:** DemiurgeBridge telemetry → Firestore ludus_nodes attribute sync  
**Startup Behavior:** Auto-detect controllers → calibrate → ready for telemetry stream

---

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Meta Quest 3 Runtime                             │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  OVRInput (Native Quest 3 API)                                 │ │
│  │  ├─ OVRInput.GetAxis(OVRInput.Axis2D.PrimaryThumbstick)       │ │
│  │  │  └─ Returns: { x: [-1.0, 1.0], y: [-1.0, 1.0] }           │ │
│  │  └─ OVRInput.GetAxis(OVRInput.Axis1D.PrimaryHandTrigger)      │ │
│  │     └─ Returns: [0.0, 1.0] (analog grip value)                │ │
│  └────────────────────────────────────────────────────────────────┘ │
│           │                                                          │
│           ▼                                                          │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  DiveComputerController (Unity C#)                             │ │
│  │  ├─ Polls OVRInput at fixed timestep (Update)                 │ │
│  │  ├─ Maps joystick → ROV velocity vectors                       │ │
│  │  ├─ Reads triggers → pressure/depth modulation                │ │
│  │  └─ Outputs: { velocity, depth, pressure, heading }           │ │
│  └────────────────────────────────────────────────────────────────┘ │
│           │                                                          │
│           ▼                                                          │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  DemiurgeBridge (Telemetry Manager)                            │ │
│  │  ├─ Buffers telemetry: 30 values/sec                          │ │
│  │  ├─ Maps to D&D attributes (Wisdom, Constitution, Dexterity)  │ │
│  │  └─ Posts to Firestore every 1 second                         │ │
│  └────────────────────────────────────────────────────────────────┘ │
│           │                                                          │
└───────────┼──────────────────────────────────────────────────────────┘
            │
            ▼
    ┌──────────────────────────┐
    │  Firestore ludus_nodes   │
    │  playerNodeId: attributes│
    │  - wisdom: 15            │
    │  - constitution: 14      │
    │  - dexterity: 12         │
    │  - lastTelemetryUpdate   │
    └──────────────────────────┘
```

---

## 2. Startup Sequence (How It Works When You Start the Game)

### 2.1 Game Launch (t=0)

**What Happens:**
1. Meta Quest 3 boots app (`ludus.apk` installed)
2. Unity engine initializes
3. OVRManager component awakens → `OVRManager.Awake()`
4. Detects attached controllers (left + right)
5. Calibrates touch surface + button mappings

**Code (pseudo):**
```csharp
// UnityVR/Assets/Scripts/VR/OVRManager.cs
void Awake() {
  if (!OVRManager.isUserPresent) {
    Debug.Log("[VR] Headset not detected, headless mode");
    return;
  }
  
  bool leftControllerConnected = OVRInput.IsControllerConnected(OVRInput.Controller.LTouch);
  bool rightControllerConnected = OVRInput.IsControllerConnected(OVRInput.Controller.RTouch);
  
  Debug.Log($"[VR] Controllers: Left={leftControllerConnected}, Right={rightControllerConnected}");
}
```

**Output:**
```
[VR] Controllers: Left=true, Right=true
[VR] Handedness: Right
```

### 2.2 Game Scene Load (t=0.5s)

**DiveComputerController Initializes:**

```csharp
// UnityVR/Assets/Scripts/DiveComputer/DiveComputerController.cs

public class DiveComputerController : MonoBehaviour {
  [SerializeField] float pollRateHz = 30f;  // Poll controller 30x/sec
  private float pollInterval;
  private float timeSinceLastPoll;
  
  private struct ControllerInput {
    public Vector2 leftThumbstick;
    public Vector2 rightThumbstick;
    public float leftTrigger;      // 0.0 to 1.0 (pressure)
    public float rightTrigger;     // 0.0 to 1.0 (depth mod)
    public bool primaryButton;     // X button (left) or A (right)
    public bool secondaryButton;   // Y button (left) or B (right)
  }
  
  void Start() {
    pollInterval = 1f / pollRateHz;
    timeSinceLastPoll = 0f;
    
    Debug.Log("[DiveComputer] Initialized @ 30 Hz poll rate");
  }
  
  void Update() {
    timeSinceLastPoll += Time.deltaTime;
    
    if (timeSinceLastPoll >= pollInterval) {
      PollControllers();
      timeSinceLastPoll = 0f;
    }
  }
  
  void PollControllers() {
    ControllerInput input = new ControllerInput {
      leftThumbstick = OVRInput.Get(OVRInput.Axis2D.PrimaryThumbstick),
      rightThumbstick = OVRInput.Get(OVRInput.Axis2D.SecondaryThumbstick),
      leftTrigger = OVRInput.Get(OVRInput.Axis1D.PrimaryIndexTrigger),
      rightTrigger = OVRInput.Get(OVRInput.Axis1D.SecondaryIndexTrigger),
      primaryButton = OVRInput.GetDown(OVRInput.Button.PrimaryIndexTrigger),
      secondaryButton = OVRInput.GetDown(OVRInput.Button.SecondaryIndexTrigger),
    };
    
    ProcessInput(input);
  }
}
```

### 2.3 Input Mapping (How Joystick Maps to Movement)

**Physical Layout — Meta Quest 3 Controllers:**

```
LEFT CONTROLLER          RIGHT CONTROLLER
│                        │
├─ X/Y Buttons          ├─ A/B Buttons
│  (top)                 │  (top)
│                        │
├─ Left Thumbstick      ├─ Right Thumbstick
│  (center, pressable)   │  (center, pressable)
│                        │
├─ Index Trigger        ├─ Index Trigger
│  (analog, 0.0–1.0)    │  (analog, 0.0–1.0)
│                        │
└─ Middle Finger        └─ Middle Finger
   (grip sensor)           (grip sensor)
```

**Mapping Rules (Joystick → ROV Movement):**

| Input | Axis | Range | Maps To | Function |
|-------|------|-------|---------|----------|
| Left Thumbstick | X (lateral) | -1.0 to 1.0 | Yaw (heading) | Turn left/right |
| Left Thumbstick | Y (vertical) | -1.0 to 1.0 | Pitch | Look up/down |
| Right Thumbstick | X | -1.0 to 1.0 | Roll | Tilt ROV side-to-side |
| Right Thumbstick | Y | -1.0 to 1.0 | Velocity (forward/back) | Move ROV forward/backward |
| Left Trigger | Analog 0-1 | 0.0 to 1.0 | Depth (meters) | Press = go deeper |
| Right Trigger | Analog 0-1 | 0.0 to 1.0 | Power/Thrust | Press = increase thrust |
| A/X Button | Press | momentary | Record Waypoint | Mark current location |
| B/Y Button | Press | momentary | Emergency Surface | Fast ascend |

**Code — Processing Input to ROV State:**

```csharp
void ProcessInput(ControllerInput input) {
  // 1. Horizontal movement (forward/back/strafe)
  Vector3 velocity = Vector3.zero;
  velocity.z = input.rightThumbstick.y * MAX_VELOCITY;  // Forward/backward
  velocity.x = input.rightThumbstick.x * MAX_VELOCITY;  // Strafe left/right
  
  // 2. Vertical movement (pitch)
  float pitch = input.leftThumbstick.y * MAX_PITCH;  // -90° to +90°
  
  // 3. Turning (yaw)
  float yaw = input.leftThumbstick.x * MAX_YAW;      // -180° to +180°
  
  // 4. Depth (controlled by left trigger — 0m to 300m typical)
  float triggerDepth = input.leftTrigger * MAX_DEPTH;  // Lerp between current + max
  
  // 5. Thrust (power — right trigger modulates velocity multiplier)
  float thrustModifier = 1f + (input.rightTrigger * 2f);  // 1x to 3x speed
  
  // 6. Emergency buttons
  if (input.secondaryButton) {
    EmergencySurface();  // Fast ascend
  }
  
  if (input.primaryButton) {
    RecordWaypoint();    // Mark location
  }
  
  // Compile telemetry packet
  ROVTelemetry telemetry = new ROVTelemetry {
    timestamp = Time.time,
    velocity = velocity * thrustModifier,
    depth = triggerDepth,
    pitch = pitch,
    yaw = yaw,
    power = input.rightTrigger,
    heading = transform.eulerAngles.y + yaw,
  };
  
  // Send to DemiurgeBridge for buffering
  demiurgeBridge.EnqueueTelemetry(telemetry);
}

private const float MAX_VELOCITY = 2.5f;       // m/s
private const float MAX_DEPTH = 300f;          // meters
private const float MAX_PITCH = 90f;           // degrees
private const float MAX_YAW = 180f;            // degrees per frame
```

### 2.4 Telemetry Buffering & Transmission (t=0.1–1.0s)

**DemiurgeBridge accumulates 30 telemetry samples, then posts every 1 second:**

```csharp
// functions/src/scripts/seedDemiurgeData.ts (or live stream endpoint)

public class DemiurgeBridge {
  private Queue<ROVTelemetry> telemetryBuffer = new Queue<ROVTelemetry>();
  private float lastSyncTime;
  private float syncInterval = 1f;  // Post to Firestore every 1 second
  
  void Update() {
    if (Time.time - lastSyncTime >= syncInterval) {
      SyncTelemetryToFirestore();
      lastSyncTime = Time.time;
    }
  }
  
  void SyncTelemetryToFirestore() {
    // Average the 30 buffered telemetry samples
    float avgDepth = 0f, avgPower = 0f, avgPitch = 0f, avgVelocity = 0f;
    
    while (telemetryBuffer.Count > 0) {
      var sample = telemetryBuffer.Dequeue();
      avgDepth += sample.depth;
      avgPower += sample.power;
      avgPitch += sample.pitch;
      avgVelocity += sample.velocity.magnitude;
    }
    
    int sampleCount = Mathf.Max(telemetryBuffer.Count, 1);
    avgDepth /= sampleCount;
    avgPower /= sampleCount;
    avgPitch /= sampleCount;
    avgVelocity /= sampleCount;
    
    // Map to D&D attributes (as per DEMIURGE_ARCHITECTURE.md)
    int wisdom = MapToAttribute(avgDepth, 0f, 300f, 8, 18);        // Depth → Wisdom
    int constitution = MapToAttribute(avgPower, 0f, 1f, 8, 18);    // Power → Constitution
    int dexterity = MapToAttribute(avgVelocity, 0f, 5f, 8, 18);    // Velocity → Dexterity
    
    Debug.Log($"[DemiurgeBridge] Telemetry: Depth={avgDepth:F1}m, Power={avgPower:F2}, Velocity={avgVelocity:F2}m/s");
    Debug.Log($"[DemiurgeBridge] Attributes: WIS={wisdom}, CON={constitution}, DEX={dexterity}");
    
    // POST to Firestore
    PostPlayerAttributesAsync(playerNodeId, new {
      wisdom,
      constitution,
      dexterity,
      lastTelemetryUpdate = ServerTimestamp(),
    });
  }
  
  private int MapToAttribute(float value, float minVal, float maxVal, int minAttr, int maxAttr) {
    float normalized = Mathf.Clamp01((value - minVal) / (maxVal - minVal));
    return Mathf.RoundToInt(Mathf.Lerp(minAttr, maxAttr, normalized));
  }
}
```

### 2.5 Startup Timeline (Complete)

| Time | Event | Status |
|------|-------|--------|
| t=0s | App launches on Quest 3 | ⏳ Loading... |
| t=0.1s | OVRManager detects controllers | ✅ Left + Right detected |
| t=0.2s | DiveComputerController initializes | ✅ Poll rate: 30 Hz |
| t=0.3s | Initial Firestore connection established | ✅ Connected |
| t=0.5s | Player node loads from Firestore | ✅ Loaded (playerNodeId=XYZ) |
| t=1.0s | First telemetry batch ready | ✅ 30 samples buffered |
| t=1.1s | First POST to Firestore (attributes) | ✅ Sent |
| t=2.0s | Player sees updated attributes in UI | ✅ Wisdom/Constitution/Dexterity visible |

**Game Ready:** t ≈ 1.5 seconds after launch

---

## 3. Runtime Loop — How It Works During Gameplay

### 3.1 Per-Frame (30 Hz)

```csharp
void Update() {
  // 1. Poll OVRInput
  ControllerInput input = PollControllers();
  
  // 2. Process to ROV state
  ROVState state = ProcessInput(input);
  
  // 3. Render VR view (camera follows ROV)
  UpdateCameraPosition(state.transform);
  
  // 4. Buffer telemetry
  demiurgeBridge.EnqueueTelemetry(state.ToTelemetry());
}
```

### 3.2 Per Second (1 Hz)

```csharp
// Every 1 second:
// 1. Average 30 telemetry samples
// 2. Map to D&D attributes
// 3. POST to Firestore ludus_nodes/{playerNodeId}/attributes
// 4. Receive updated node state (if other players modified it)
// 5. Render changes in UI (if applicable)
```

### 3.3 Persistent State (Firestore)

Player node document updated in real-time:

```json
{
  "nodeId": "player-001",
  "nodeType": "player",
  "userId": "user123abc",
  "attributes": {
    "wisdom": 15,
    "constitution": 14,
    "dexterity": 12,
    "strength": 10,
    "intelligence": 11,
    "charisma": 9
  },
  "telemetry": {
    "lastDepth": 287.5,
    "lastPower": 0.85,
    "lastVelocity": 1.23,
    "lastHeading": 42
  },
  "lastTelemetryUpdate": "2026-09-30T14:23:45.123Z"
}
```

---

## 4. Error Handling & Fallbacks

### 4.1 Controller Not Connected at Startup

```csharp
void Start() {
  if (!OVRInput.IsControllerConnected(OVRInput.Controller.LTouch) ||
      !OVRInput.IsControllerConnected(OVRInput.Controller.RTouch)) {
    
    Debug.LogError("[VR] Controllers not detected!");
    ShowUIMessage("Controllers not found. Check battery + pairing.");
    
    // Retry detection every 2 seconds
    InvokeRepeating("RetryControllerDetection", 2f, 2f);
    
    // Allow gamepad fallback
    EnableGamepadFallback();
  }
}
```

### 4.2 Firestore Offline During Telemetry

```csharp
async Task PostPlayerAttributesAsync(string nodeId, object attributes) {
  try {
    await firebaseRef.Child($"ludus_nodes/{nodeId}/attributes").SetValueAsync(attributes);
  } catch (Exception ex) {
    Debug.LogWarning($"[DemiurgeBridge] Firestore offline: {ex.Message}");
    
    // Cache locally (IndexedDB equivalent in Unity)
    localCache.Save($"attributes_pending_{nodeId}", attributes);
    
    // Retry next sync cycle
  }
}
```

### 4.3 Joystick Deadzone (Ignore Tiny Movements)

```csharp
// Dead zone: ignore input < 0.15 magnitude
Vector2 thumbstick = OVRInput.Get(OVRInput.Axis2D.PrimaryThumbstick);
if (thumbstick.magnitude < DEADZONE_THRESHOLD) {
  thumbstick = Vector2.zero;
}
// This prevents drift (controller generating tiny random values)
```

---

## 5. Testing Checklist (Before Device Testing)

### Startup Sequence Test

- [ ] Launch ludus.apk on Quest 3
- [ ] Controllers automatically detected (< 0.5s)
- [ ] DiveComputerController logs "Initialized @ 30 Hz"
- [ ] Player node loads from Firestore
- [ ] No red errors in logcat

### Joystick Input Test

```bash
# Connect Quest 3 via ADB
adb logcat | grep DiveComputer

# Move LEFT thumbstick forward
# Expected: [DiveComputer] Pitch: 45.0°

# Move RIGHT thumbstick left
# Expected: [DiveComputer] Velocity: -2.5 m/s (backward)

# Press LEFT trigger halfway
# Expected: [DiveComputer] Depth: 150.0m
```

### Telemetry Sync Test

- [ ] Make 10 distinct joystick movements
- [ ] Wait 2 seconds (2 sync cycles)
- [ ] Check Firestore ludus_nodes/{playerNodeId}/attributes
- [ ] Verify Wisdom/Constitution/Dexterity changed accordingly
- [ ] Check browser webtypicon2 tab updates in real-time

---

## 6. Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Poll latency | < 10 ms | OVRInput.Get() → buffer |
| Telemetry sync | < 500 ms | Firestore write latency |
| Attribute update visible | < 2s | Player sees UI change |
| FPS (VR) | 90 FPS | Quest 3 native refresh |
| Input-to-output lag | < 100 ms | Total end-to-end |

---

## 7. References

- **OVRInput API:** `UnityVR/Assets/Plugins/OVRInput.cs` (Meta SDK)
- **DemiurgeBridge:** `ludus/functions/src/scripts/seedDemiurgeData.ts`
- **D&D Attribute Mapping:** `ludus/docs/DEMIURGE_ARCHITECTURE.md` § Ludus Game State
- **Firestore Schema:** `ludus/functions/src/schemas/ludusTypes.ts`

---

**Status:** Design-ready, awaiting Quest 3 device testing  
**Owner:** Claude Haiku 4.5  
**Session:** 2026-09-28 10:54 UTC  
**Next:** Verify on Meta Quest 3 during Phase 3 (Sep 30)

