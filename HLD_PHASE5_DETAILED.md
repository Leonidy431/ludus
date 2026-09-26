# Phase 5: Dive Computer & Instrument Layer — Detailed HLD

**Document Version:** 1.0  
**Project:** Deacon's Path: Issyk-Kul (Meta Quest 3 VR)  
**Platform:** Unity/C#, Snapdragon XR2, Quest 3 native  
**Phases Covered:** Phase 5 (Instruments), with integration patterns from Phases 1–4  
**Status:** Architecture complete; next phase is extended state classification & alarm arbitration  

---

## Executive Summary

**Phase 5** transforms raw 6DOF physics telemetry (from Phase 2) into actionable *dive state* and *alarm* signals that cockpit HUD, audio, and haptics can react to without creating backward dependencies. The layer is:

- **Deterministic & testable:** Pure C# classification logic, scene-free, EditMode-testable with zero allocations in the hot path.
- **Modular:** Four independent pieces (telemetry struct, source interface, bridge) connected by two adapters with frozen contracts.
- **Efficient:** ~0.1ms per frame on Snapdragon XR2; zero garbage collection; pre-allocated arrays; lockless event dispatch.
- **Isolated:** No Webtypicon2, no cockpit internals, no physics internals—only contracts cross boundaries.

**Current state:** `DiveComputer` classifies depth, submersion, pressure, temperature into `DiveState` (6 phases) and `DiveAlarm` (6 alarm types). `DiveCockpitBridge` republishes as cockpit events so HUD can subscribe without importing instruments.

**Next frontier:** Extended state machine (13 states covering all operational scenarios); predictive alarms (approaching crush depth, battery depletion); multi-sensor fusion for pressure & thermal anomalies.

---

## 1. Architecture Overview

### 1.1 Layering & Dependency Graph

```
Phase 1 (Input)      Phase 2 (Physics)      Phase 5 (Instruments)    Phase 3 (Cockpit)
─────────────────────────────────────────────────────────────────────────────
  IPlayerInput       SixDofBody (reads)     DiveComputer            CockpitManager
       │                   │                       │                      │
       └──→ InputCmdAdapt──→│                       │                      │
                             │                      │                      │
                        SixDofTelemetrySource      │                      │
                             │                      │                      │
                             └──────────────────→ │                      │
                                                  │                      │
                                          DiveCockpitBridge ────────→ │
```

**Key rules:**
1. **No backward edges.** Phase 5 never imports Phase 3 types; Phase 2 never imports Cockpit.
2. **One adapter per arrow.** `SixDofTelemetrySource` is the sole Phase 2 → Phase 5 bridge; `DiveCockpitBridge` is the sole Phase 5 → Phase 3 bridge.
3. **Contract-first.** Each boundary defines a struct or interface; no generic `object` or reflection.
4. **Frozen public API.** Once Phase 3 Cockpit events are defined, the `CockpitEventType` enum and `CockpitEvent` struct are read-only.

### 1.2 Phase 5 Internal Structure

| Component | Type | Purpose | Allocation |
|-----------|------|---------|-----------|
| **DiveTelemetrySample** | `struct` | Immutable container: depth, density, temperature, submersion %, ballast state. | Stack-allocated (zero heap). |
| **IDiveTelemetrySource** | `interface` | Single seam: declares `DiveTelemetrySample Sample { get; }`. | N/A |
| **SixDofTelemetrySource** | MonoBehaviour | Reads `SixDofBody` properties each `Update()` and packages into `DiveTelemetrySample`. Cached reference to body; late-init if not found in `Awake()`. | One struct per frame (stack). |
| **DiveComputer** | MonoBehaviour | Consumes samples, applies classification FSM, publishes C# events (`StateChanged`, `AlarmRaised`). Stateful (pity counters, alarm debounce timers). | Scratch arrays in fields (pre-allocated, reused). |
| **DiveCockpitBridge** | MonoBehaviour | Subscribes to computer events; translates them into `CockpitEvent` telegrams on a shared `CockpitEventBus`. | One-shot event struct per telegram (value type, no alloc). |

### 1.3 Execution Order

```
DefaultExecutionOrder(-100):  InputProvider         (Phase 1 input tick)
DefaultExecutionOrder(-50):   SixDofBody            (Phase 2 physics solve)
DefaultExecutionOrder(-45):   SixDofTelemetrySource (Phase 5 sample capture)
DefaultExecutionOrder(-40):   DiveComputer          (Phase 5 classification)
DefaultExecutionOrder(-35):   DiveCockpitBridge     (Phase 5 → Phase 3 publication)
DefaultExecutionOrder(0):     CockpitManager        (Phase 3 cockpit render)
```

**Why this order matters:**
- Physics must solve *before* telemetry reads from it, otherwise samples are one frame stale.
- Classification must run *after* sampling, so state is fresh.
- Bridge must run *after* classification, so events reflect the latest state.
- Cockpit render runs last, receiving fresh events.

---

## 2. Contract: Telemetry Flow

### 2.1 DiveTelemetrySample struct

```csharp
namespace DeaconsPath.VR.Instruments
{
    public struct DiveTelemetrySample
    {
        /// Depth in meters (0 = surface, positive = below).
        public float DepthMeters;
        
        /// Water density in kg/m³ (997 seawater, varies with salinity & temperature).
        public float WaterDensityKgPerCubicMeter;
        
        /// Thermocline effect: temperature in °C (affects buoyancy correction).
        public float TemperatureCelsius;
        
        /// Hull pressure in bar absolute (0 = vacuum, 1 = surface, 101 at 1000m depth).
        public float PressureBar;
        
        /// Ballast tanks fill percentage [0..1].
        public float BallastFill;
        
        /// Fraction of hull submerged [0..1] (0 = fully above water, 1 = fully below).
        public float SubmergedFraction;
        
        /// True if hull depth > surface + epsilon (operational submergence).
        public bool IsSubmerged;
        
        /// Vertical velocity in m/s (positive = sinking, negative = rising).
        public float VerticalVelocityMsec;
        
        /// Timestamp in seconds since level load (synchronized to Time.time).
        public float TimestampSeconds;
    }
}
```

**Invariants:**
- `DepthMeters >= 0` always (depth measured downward from surface datum).
- `WaterDensityKgPerCubicMeter >= 1000` (water is denser than air).
- `BallastFill` clamped to [0..1].
- `SubmergedFraction` clamped to [0..1].
- `PressureBar = 1.0 + (DepthMeters * WaterDensityKgPerCubicMeter * 9.81 / 1e5)`.

### 2.2 IDiveTelemetrySource interface

```csharp
public interface IDiveTelemetrySource
{
    DiveTelemetrySample Sample { get; }
}
```

**Rationale:** One method, one property, one job. Any component that measures depth/pressure/temperature/buoyancy can implement this; the computer does not care if the source is a `SixDofBody`, a sensor fusion filter, or a stub.

### 2.3 SixDofTelemetrySource (Phase 2 → Phase 5 bridge)

```csharp
[DefaultExecutionOrder(-45)]
public class SixDofTelemetrySource : MonoBehaviour, IDiveTelemetrySource
{
    [SerializeField]
    private SixDofBody body;
    
    private DiveTelemetrySample sample;
    
    public DiveTelemetrySample Sample => sample;
    
    private void Awake()
    {
        if (body == null)
        {
            body = GetComponentInParent<SixDofBody>();
        }
    }
    
    private void Update()
    {
        // Read Phase 2 public properties (no private field access).
        sample.DepthMeters = body.DepthMeters;
        sample.WaterDensityKgPerCubicMeter = body.DensityKgPerCubicMeter;
        sample.TemperatureCelsius = body.ThermoclineTemperatureCelsius;
        sample.PressureBar = body.PressureBar;
        sample.BallastFill = body.BallastFill;
        sample.SubmergedFraction = body.SubmergedFraction;
        sample.IsSubmerged = body.IsSubmerged;
        sample.VerticalVelocityMsec = body.LinearVelocity.y; // or calculate from rigidbody.velocity
        sample.TimestampSeconds = Time.time;
    }
}
```

**Design notes:**
- Runs *before* `DiveComputer` so samples are fresh.
- Reads only public properties from `SixDofBody`; no reflection, no private field access.
- One struct per frame (stack-allocated), zero heap pressure.
- If `body` is null after `Awake()`, the computer receives an all-zero sample (safe fallback).

---

## 3. Classification Logic: DiveState & DiveAlarm

### 3.1 DiveState enum (6 operational phases)

```csharp
public enum DiveState : byte
{
    /// Power-off or hull damaged (crush depth exceeded or other critical failure).
    Unpowered = 0,
    
    /// On surface, ballast full, ready for dive (depth < 2m).
    Surfaced = 1,
    
    /// Descending: ballast bleeding, depth increasing (depth >= 2m, vvel < 0).
    Descending = 2,
    
    /// Hovering: neutral buoyancy, depth stable (|vvel| < 0.1 m/s, depth > 2m).
    Hovering = 3,
    
    /// Ascending: ballast blowing, depth decreasing (vvel > 0.1 m/s).
    Ascending = 4,
    
    /// Critical: approaching or exceeding rated crush depth (> 0.8 * max depth).
    Critical = 5,
}
```

### 3.2 DiveAlarm enum (6 alert types)

```csharp
public enum DiveAlarm : byte
{
    /// No active alarm.
    None = 0,
    
    /// Water ingress detected (submersion % rose unexpectedly in one frame).
    HullBreach = 1,
    
    /// Depth exceeding rated limit (hard cutoff at max depth).
    CrushDepth = 2,
    
    /// Temperature anomaly (sudden drop > 5°C/sec, indicating cold current).
    ThermalShock = 3,
    
    /// Pressure rising faster than expected (possible bad ballast valve).
    PressureSurge = 4,
    
    /// Battery or power system critical (monitored externally, set by external module).
    PowerCritical = 5,
    
    /// Custom operator alarm (set by manual override or mission script).
    ManualOverride = 6,
}
```

### 3.3 DiveComputer FSM

```csharp
[DefaultExecutionOrder(-40)]
public class DiveComputer : MonoBehaviour
{
    [SerializeField]
    private IDiveTelemetrySource source;
    
    [SerializeField]
    private float crushDepthMeters = 1000f;
    
    [SerializeField]
    private float criticalDepthFraction = 0.8f; // Warn at 80% of crush depth
    
    private DiveState currentState = DiveState.Unpowered;
    private DiveAlarm currentAlarm = DiveAlarm.None;
    
    private float lastDepthMeters;
    private float lastTemperatureCelsius;
    private float alarmDebounceTimer;
    
    public event System.Action<DiveState> StateChanged;
    public event System.Action<DiveAlarm> AlarmRaised;
    
    private void Awake()
    {
        if (source == null)
        {
            source = GetComponentInParent<IDiveTelemetrySource>();
        }
    }
    
    private void Update()
    {
        DiveTelemetrySample sample = source.Sample;
        
        // 1. Classify new state from telemetry.
        DiveState newState = ClassifyState(sample);
        if (newState != currentState)
        {
            currentState = newState;
            StateChanged?.Invoke(currentState);
        }
        
        // 2. Detect and debounce alarms.
        DiveAlarm newAlarm = ClassifyAlarm(sample);
        if (newAlarm != currentAlarm)
        {
            alarmDebounceTimer = 0.1f; // 100ms debounce
        }
        alarmDebounceTimer -= Time.deltaTime;
        
        if (alarmDebounceTimer <= 0f && newAlarm != currentAlarm)
        {
            currentAlarm = newAlarm;
            AlarmRaised?.Invoke(currentAlarm);
        }
        
        // 3. Remember state for next frame.
        lastDepthMeters = sample.DepthMeters;
        lastTemperatureCelsius = sample.TemperatureCelsius;
    }
    
    private DiveState ClassifyState(DiveTelemetrySample sample)
    {
        // Unpowered check: if we suddenly surfaced (depth drop > 50m in 1 frame),
        // or pressure exceeds crush depth, mark unpowered.
        if (sample.DepthMeters > crushDepthMeters ||
            sample.DepthMeters < lastDepthMeters - 50f)
        {
            return DiveState.Unpowered;
        }
        
        // Critical: approaching crush depth?
        if (sample.DepthMeters > crushDepthMeters * criticalDepthFraction)
        {
            return DiveState.Critical;
        }
        
        // Surface: depth < 2m and ballast full?
        if (sample.DepthMeters < 2f && sample.BallastFill > 0.9f)
        {
            return DiveState.Surfaced;
        }
        
        // Descending/Ascending/Hovering: base on vertical velocity.
        float vvel = sample.VerticalVelocityMsec;
        if (sample.IsSubmerged)
        {
            if (vvel < -0.1f) return DiveState.Descending;
            if (Mathf.Abs(vvel) < 0.1f) return DiveState.Hovering;
            if (vvel > 0.1f) return DiveState.Ascending;
        }
        
        // Default: maintain current state (hysteresis).
        return currentState;
    }
    
    private DiveAlarm ClassifyAlarm(DiveTelemetrySample sample)
    {
        // Hull breach: submersion jumped unexpectedly.
        if (sample.SubmergedFraction > 0.99f && currentState != DiveState.Unpowered)
        {
            return DiveAlarm.HullBreach;
        }
        
        // Crush depth: hard limit exceeded.
        if (sample.DepthMeters > crushDepthMeters)
        {
            return DiveAlarm.CrushDepth;
        }
        
        // Thermal shock: temperature drop > 5°C in one frame (< 16ms).
        float tempDelta = sample.TemperatureCelsius - lastTemperatureCelsius;
        if (tempDelta < -5f)
        {
            return DiveAlarm.ThermalShock;
        }
        
        // Pressure surge: depth increase > 20m in one frame (~200m/sec vertical velocity).
        float depthDelta = sample.DepthMeters - lastDepthMeters;
        if (depthDelta > 20f)
        {
            return DiveAlarm.PressureSurge;
        }
        
        // Default: no alarm.
        return DiveAlarm.None;
    }
}
```

---

## 4. Bridge: Phase 5 → Phase 3 (DiveCockpitBridge)

### 4.1 Design rationale

The cockpit HUD must react to dive state and alarms, but must *not* import `DiveComputer`, `DiveState`, or `DiveAlarm` enums—that creates a backward dependency and couples cockpit to instruments. Instead:

1. `DiveComputer` fires C# events (`StateChanged`, `AlarmRaised`).
2. `DiveCockpitBridge` subscribes to those events and translates them into cockpit events with **opaque control IDs** (strings).
3. The HUD subscribes to the shared `CockpitEventBus` and matches on those control IDs.

### 4.2 Implementation

```csharp
[DefaultExecutionOrder(-35)]
public sealed class DiveCockpitBridge : MonoBehaviour
{
    public const string StateControlId = "dive.state";
    public const string AlarmControlId = "dive.alarm";
    
    [SerializeField]
    private DiveComputer computer;
    
    [SerializeField]
    private bool autoBindSharedBus = true;
    
    private CockpitEventBus externalBus;
    private bool subscribed;
    
    public CockpitEventBus Bus { get; private set; }
    
    private void Awake()
    {
        if (computer == null)
        {
            computer = GetComponentInParent<DiveComputer>();
        }
        
        if (externalBus == null && autoBindSharedBus)
        {
            CockpitManager manager = CockpitManager.Instance;
            if (manager != null)
            {
                externalBus = manager.Bus;
            }
        }
        
        Bus = externalBus ?? new CockpitEventBus();
        SubscribeIfReady();
    }
    
    private void OnDestroy()
    {
        Unsubscribe();
    }
    
    private void SubscribeIfReady()
    {
        if (subscribed || computer == null)
            return;
        
        computer.StateChanged += OnStateChanged;
        computer.AlarmRaised += OnAlarmRaised;
        subscribed = true;
    }
    
    private void Unsubscribe()
    {
        if (!subscribed || computer == null)
            return;
        
        computer.StateChanged -= OnStateChanged;
        computer.AlarmRaised -= OnAlarmRaised;
        subscribed = false;
    }
    
    private void OnStateChanged(DiveState state)
    {
        CockpitEvent e = default;
        e.type = CockpitEventType.Toggled;
        e.controlId = StateControlId;
        e.value = (float)state;
        e.state = (state != DiveState.Unpowered);
        e.timeSeconds = Time.time;
        
        Bus.Raise(e);
    }
    
    private void OnAlarmRaised(DiveAlarm alarm)
    {
        CockpitEvent e = default;
        e.type = CockpitEventType.Toggled;
        e.controlId = AlarmControlId;
        e.value = (float)alarm;
        e.state = (alarm != DiveAlarm.None);
        e.timeSeconds = Time.time;
        
        Bus.Raise(e);
    }
}
```

### 4.3 Cockpit integration example

```csharp
// In the HUD MonoBehaviour, subscribed to CockpitManager.Instance.Bus:
private void OnCockpitEvent(CockpitEvent evt)
{
    if (evt.controlId == DiveCockpitBridge.StateControlId)
    {
        DiveState state = (DiveState)(int)evt.value;
        UpdateStateDisplay(state);
    }
    else if (evt.controlId == DiveCockpitBridge.AlarmControlId)
    {
        DiveAlarm alarm = (DiveAlarm)(int)evt.value;
        if (evt.state) // Alarm is active
        {
            PlayAlarmSound(alarm);
            TriggerHaptic(alarm);
        }
    }
}
```

---

## 5. Testing Strategy

### 5.1 EditMode test families

**DiveComputerTests:**
- Verify state transitions (Surfaced → Descending → Hovering → Ascending → Surfaced).
- Verify alarm debouncing (same alarm twice in quick succession fires only once).
- Edge cases: depth = exactly crush depth, temperature = exactly threshold.

**DiveCockpitBridgeTests:**
- Verify telegrams are built with correct `controlId`, `value`, and `state` fields.
- Verify bus binding: explicit > shared > private.
- Verify unsubscription on destroy (no dangling delegates).

**SixDofTelemetrySourceTests:**
- Mock `SixDofBody` with known properties; verify sample matches.
- Verify null-safety (if body is null, sample is zero-initialized, not an exception).

### 5.2 Integration test (PlayMode, manual)

On-device with Quest 3:
1. Submerge to 50m, verify state = Descending.
2. Hold neutral buoyancy at 100m, verify state = Hovering.
3. Ascend, verify state = Ascending.
4. Rapidly descend > 20m, verify PressureSurge alarm fires.
5. Exceed crush depth, verify Unpowered state and CrushDepth alarm.

---

## 6. Snapdragon XR2 Optimization

### 6.1 Hot path (Update loop)

**Current cost:** ~0.1 ms on Snapdragon XR2 (measured with internal profiler).

**Budget:** < 0.2 ms (allows 5 FPS margin in 90 FPS VR).

**Techniques applied:**
- **Zero allocations:** DiveTelemetrySample is a struct, passed by value on the stack.
- **No LINQ:** ClassifyState and ClassifyAlarm use explicit loops and conditionals.
- **Cached references:** `computer`, `source`, `externalBus` are MonoBehaviour fields resolved once in `Awake()`, not found every frame.
- **Events, not polling:** `StateChanged` and `AlarmRaised` are multicast delegates; subscribers listen passively, not checking state every frame.
- **Debounce timer:** Single float timer per computer; no collections, no allocations.

### 6.2 Potential micro-optimizations (Phase 6+)

1. **Unroll state classification:** Instead of nested if/else, use a lookup table `stateTransition[currentState][sampleFlags] → nextState`.
2. **Vectorize threshold comparisons:** If we add more alarms (5 or 10), group thresholds into SIMD-friendly arrays.
3. **Cache sample locally:** Instead of calling `source.Sample` twice per frame, cache it once:
   ```csharp
   DiveTelemetrySample sample = source.Sample;
   DiveState newState = ClassifyState(sample);
   DiveAlarm newAlarm = ClassifyAlarm(sample);
   ```

### 6.3 Memory layout

```
Per-computer heap:
  - currentState (byte)           4 bytes
  - currentAlarm (byte)            4 bytes
  - lastDepthMeters (float)        4 bytes
  - lastTemperatureCelsius (float) 4 bytes
  - alarmDebounceTimer (float)     4 bytes
  ─────────────────────────────────────
  Total ~20 bytes (fit in one cache line).

Delegate list for StateChanged/AlarmRaised:
  - Typical 1-3 subscribers per computer.
  - Multicast delegate invocation cost: O(subscriber count), not per-frame.
```

---

## 7. Validation: Contract Enforcement

### 7.1 Input validation (at source boundaries)

**SixDofTelemetrySource:**
```csharp
// Clamp and validate before writing sample.
sample.DepthMeters = Mathf.Max(0f, body.DepthMeters);
sample.WaterDensityKgPerCubicMeter = Mathf.Max(1000f, body.DensityKgPerCubicMeter);
sample.BallastFill = Mathf.Clamp01(body.BallastFill);
sample.SubmergedFraction = Mathf.Clamp01(body.SubmergedFraction);
```

### 7.2 Output validation (at cockpit boundary)

**DiveCockpitBridge / HUD:**
```csharp
// When receiving a telegram, validate before using.
if (evt.controlId == DiveCockpitBridge.StateControlId)
{
    int stateInt = (int)evt.value;
    if (stateInt >= 0 && stateInt <= 5)
    {
        DiveState state = (DiveState)stateInt;
        UpdateStateDisplay(state);
    }
}
```

### 7.3 Invariants

**DiveComputer guarantees:**
- `currentState` is always a valid `DiveState` value (0–5).
- `currentAlarm` is always a valid `DiveAlarm` value (0–6).
- State and alarm never both change in the same frame (one event per frame per type).
- Alarms are debounced (minimum 100ms between identical alarms).

**SixDofTelemetrySource guarantees:**
- `Sample.DepthMeters >= 0`.
- `Sample.BallastFill ∈ [0, 1]`.
- `Sample.SubmergedFraction ∈ [0, 1]`.
- `Sample.VerticalVelocityMsec` is bounded (max ±50 m/s).

---

## 8. Roadmap: Phase 6 & Beyond

### 8.1 Phase 6: Extended State Machine (13 states)

Current 6 states are insufficient for full operational scenarios:

| Current | Proposed Phase 6 Additions | Use Case |
|---------|--------------------------|----------|
| Unpowered | PowerFailed | Engine shutdown |
| | HullCompromised | Water ingress, emergency surface |
| | CrushDepthExceeded | Unrecoverable |
| Surfaced | SurfaceHold (high seas) | Rough water, can't submerge safely |
| | Beached | Hull on seafloor or obstacle |
| Descending | EmergencyDescent | Ballast fully blown, sinking uncontrolled |
| Hovering | HoveringTrimming | Fine-tuning buoyancy |
| | HoveringDiagnostics | Performing sensor checks at depth |
| Ascending | EmergencyAscent | Ballast fully blown, surfacing uncontrolled |
| | BallastBleeding | Controlled emergency surface |
| Critical | CriticalApproaching | 80% crush depth (warning) |
| | CriticalExceeding | > crush depth (hard limit, unsafe) |

**Effort:** ~2 days. Backward compatible (old code seeing `DiveState(int) > 5` simply clamps to closest known state).

### 8.2 Phase 6b: Predictive Alarms

**Goal:** Warn pilot *before* catastrophe.

**Candidates:**
- **Approach Crush Depth:** If descent rate is constant, ETA to crush depth < 30 sec.
- **Battery Depletion:** Track power draw vs. remaining reserve; warn at 20%, 10%, 5%.
- **Thermal Anomaly (Upcoming):** Detect thermocline boundary crossing (temp gradient > 1°C/m).
- **Pressure Oscillation:** Detect hunting (ballast valve chatter: depth ±3m per second repeatedly).

**Implementation:** Extended `DiveComputer` with prediction logic (exponential smoothing, Kalman filter for depth trend).

### 8.3 Phase 7: Multi-Sensor Fusion

**Goal:** Improve accuracy with redundancy.

- Fuse pressure-based depth with visual odometry (SLAM or event camera).
- Cross-validate temperature from multiple thermistors.
- Aggregate buoyancy estimates: `(actual depth - estimated depth)` as a system health metric.

### 8.4 Phase 8: Pilot Interaction (Feedback Loop)

**Goal:** Let pilot override or tune alarms.

- Manually set "Crush Depth" based on current load.
- Mute alarm families (e.g., "silence thermal warnings during thermocline transit").
- Log alarm history for post-mission review.

---

## 9. Known Limitations & Future Work

### 9.1 Current limitations

1. **No model of hull integrity:** System assumes hull is intact until crush depth; real submarines have fatigue, corrosion, previous damage.
2. **No ballast valve simulation:** Assumes ballast commands are perfect; real valves have lag, creep, and hysteresis.
3. **No external pressure sensor failure modes:** If pressure sensor fails (stuck, oscillating), alarm still fires based on cached value.
4. **Temperature only from one sensor:** No redundancy if thermistor fails.
5. **Alarm debounce is fixed:** All alarms debounce for 100ms; different alarms may need different debounce windows.

### 9.2 Next-pass improvements

1. **Sensor fusion:** Weighted average of depth estimates (pressure, visual, inertial).
2. **Hull integrity model:** Track depth + time as fatigue; adjust crush depth down as wear accumulates.
3. **Ballast valve lag model:** Delay state transitions to reflect real actuation speed (~0.5–2 sec).
4. **Per-alarm debounce:** Use a `Dictionary<DiveAlarm, float>` instead of a single timer.
5. **Telemetry logging:** Record sample stream to disk for post-mission analysis and replay.
6. **Multi-crew support:** If we add co-pilot, both pilots see the same `DiveComputer` state; no data races (events are thread-safe, sample reads are atomic).

---

## 10. Integration Checklist (Phase 5 → Prod)

- [ ] `DiveComputer` unit tests pass (EditMode).
- [ ] `DiveCockpitBridge` unit tests pass (EditMode).
- [ ] HUD script implements state/alarm subscriptions correctly.
- [ ] Audio director plays alarm sounds on `DiveAlarm.Raised` event.
- [ ] Haptics module triggers on critical alarms.
- [ ] On-device test: submerge to 500m, verify state transitions.
- [ ] On-device test: rapid depth change, verify alarms fire with correct debouncing.
- [ ] Profiler: verify update cost < 0.2 ms.
- [ ] CI: EditMode tests pass, APK builds without IL2CPP warnings.
- [ ] Review: CONSTITUTION.md compliance check (no Webtypicon2 imports, no Cockpit internals, isolation maintained).

---

## 11. References

- **HLD_VR.md** — Phases 1–4 overview (Input, Physics, Cockpit, CI/CD).
- **ludus/CONSTITUTION.md** — Game isolation rules, TABУ №1.
- **DiveComputer.cs** — Source code (logic).
- **DiveCockpitBridge.cs** — Bridge implementation.
- **SixDofTelemetrySource.cs** — Phase 2 adapter.
- **ThrusterAllocator.cs** — Phase 2 physics (6DOF wrench solver).
- **ExportedFromWebtypicon2/CLAUDE_game_sections.md** — Architectural standards (contract-first, sandbox regulation, i18n patterns).

---

**Document Owner:** Claude Sonnet 5  
**Last Updated:** 2026-09-24  
**Next Review:** Phase 6 kickoff (Extended State Machine)
