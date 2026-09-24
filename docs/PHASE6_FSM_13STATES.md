---
id: phase6-fsm-13-states
type: architecture
tags: [rov, phase6, fsm, state-machine, dive-computer, underwater, submarine]
related: [[HLD_PHASE5_DETAILED.md], [DiveComputer.cs], [DiveState.cs]]
version: 1.0
status: draft
last_updated: 2026-09-24
---

# Phase 6: Extended Dive State Machine (13 Operational States)

**Summary:** Expands the Phase 5 classification system from 6 basic states to 13 operational states, covering emergency scenarios, ballast failure modes, hull integrity degradation, and crew override states. Designed for Snapdragon XR2 with predictive alarm hooks and sensor fusion readiness.

---

## 1. Executive Overview

### 1.1 Why 13 States?

Phase 5's 6-state FSM (`Unpowered`, `Surfaced`, `Descending`, `Hovering`, `Ascending`, `Critical`) conflates distinct operational scenarios:

- **Descending ≠ Emergency Descent** (ballast valve working vs. jammed open).
- **Hovering ≠ Diagnostic Hovering** (normal station-keeping vs. system test mode).
- **Critical ≠ Crush Depth Exceeded** (approaching limit vs. already past safe envelope).
- **Unpowered ≠ Hull Compromised** (engine shutdown vs. catastrophic leak).

A 13-state FSM provides:
- **Granular pilot feedback** — pilot sees exact failure mode, not generic "critical".
- **Predictive alarm hooks** — Phase 6b can tie ETA-to-crush-depth to specific states.
- **Graceful degradation** — subsystems fail independently; vessel doesn't jump to `Unpowered` on first minor issue.
- **Backward compatibility** — code expecting Phase 5 states sees a "collapsed" view: map 13 states → 6 buckets when needed.

### 1.2 State Taxonomy

```
┌─ POWER STATES (Unpowered family)
│  ├─ Unpowered (engine dead)
│  └─ PowerFailing (critical battery, < 5 min reserve)
│
├─ SURFACE OPERATIONS (0–2m)
│  ├─ Surfaced (ballast full, ready to dive)
│  └─ SurfaceHold (rough seas, cannot safely submerge)
│
├─ DESCENT OPERATIONS (depth > 2m, vvel < -0.1 m/s)
│  ├─ Descending (normal, controlled)
│  └─ EmergencyDescent (ballast valve stuck open, uncontrolled sink)
│
├─ STATIONARY OPERATIONS (|vvel| < 0.1 m/s, depth > 2m)
│  ├─ Hovering (normal neutral buoyancy)
│  ├─ HoveringTrimming (fine-tuning ballast)
│  └─ HoveringDiagnostics (running system self-test)
│
├─ ASCENT OPERATIONS (vvel > 0.1 m/s)
│  ├─ Ascending (normal, controlled)
│  ├─ EmergencyAscent (ballast valve stuck closed, uncontrolled rise)
│  └─ BallastBleeding (emergency surface procedure)
│
├─ DEPTH-CRITICAL STATES
│  ├─ CriticalApproaching (80% crush depth, warning threshold)
│  ├─ CriticalExceeding (> crush depth, hard limit breached)
│  └─ Beached (depth ≈ 0, hull on obstacle or seafloor)
│
└─ FAILURE STATES
   └─ HullCompromised (water ingress > threshold)
```

---

## 2. State Definitions

### 2.1 UNPOWERED

```csharp
/// <summary>
/// Engine off or power system critically damaged. No propulsion, no ballast control.
/// Vessel sinks (if submerged) or drifts (if on surface). Pilot must trigger manual
/// ballast blow (Phase 8) or emergency ascent protocol.
/// </summary>
Unpowered = 0,
```

**Entry conditions:**
- Operator manually shuts down engine.
- Power reserve falls to 0% (battery fully depleted).
- Fire/explosion detected in engine room (future Phase 8).

**Exit conditions:** Engine restart (manual command, Phase 8).

**Telemetry published:** `StateChanged(Unpowered)` → cockpit HUD shows "NO POWER" (red).

---

### 2.2 POWERFAILING

```csharp
/// <summary>
/// Critical power low: < 5 minutes of reserve at current draw rate. All systems
/// operational but pilot must surface immediately or lose propulsion mid-maneuver.
/// </summary>
PowerFailing = 1,
```

**Entry condition:** Battery % < 5% (energy reserve < 5 min at 100W nominal draw).

**Exit conditions:**
- Battery recharged (docking station, Phase 8).
- Transition to `Unpowered` if reserve fully exhausted.

**Telemetry:** `AlarmRaised(PowerCritical)` (pulsing tone, haptic warning).

---

### 2.3 SURFACED

```csharp
/// <summary>
/// On surface, ballast tanks full, ready to dive. Water calm, no obstacles above.
/// DepthMeters < 2, BallastFill > 0.9, VerticalVelocity ≈ 0.
/// </summary>
Surfaced = 2,
```

**Entry conditions:** `Hovering` + depth < 2m + ballast > 90%.

**Exit:** `Descending` when ballast starts bleeding.

---

### 2.4 SURFACEHOLD

```csharp
/// <summary>
/// On surface but cannot safely submerge: waves > 1m, or obstacle above
/// detected by forward sonar. Pilot must wait for weather to improve
/// or manually override (Phase 8 risky move).
/// </summary>
SurfaceHold = 3,
```

**Entry:** `Surfaced` + (wave height > 1m OR obstacle above).

**Exit:** Wave detection clears.

**Telemetry:** `AlarmRaised(ManualOverride)` if pilot forces descent.

---

### 2.5 DESCENDING

```csharp
/// <summary>
/// Normal controlled descent: ballast valve opening, depth increasing,
/// vvel < -0.1 m/s. Buoyancy trim is stable; pilot expects to reach
/// target depth and transition to Hovering.
/// </summary>
Descending = 4,
```

**Entry:** `Hovering` + ballast < 90% + vvel < -0.1.

**Exit:** vvel ≈ 0 → `Hovering`, OR emergency detection → `EmergencyDescent`.

---

### 2.6 EMERGENCYDESCENT

```csharp
/// <summary>
/// Uncontrolled descent: ballast valve jammed open OR depth decrease > 50m/sec.
/// Pilot must close main vent or trigger emergency blow (Phase 8).
/// High G-loading, potential crush depth breach if uncorrected.
/// </summary>
EmergencyDescent = 5,
```

**Entry conditions:**
- `Descending` + (vvel < -1.0 m/s) for > 2 sec.
- Manual valve status: "stuck open".
- Depth drop > 50m in 1 frame.

**Exit:** Valve closes (manual command, Phase 8) or crush depth hit.

**Alarms:** `PressureSurge`, `CrushDepth` (stacked).

---

### 2.7 HOVERING

```csharp
/// <summary>
/// Neutral buoyancy, depth stable. |vvel| < 0.1 m/s, ballast fill ≈ 50%.
/// Pilot can hover indefinitely (battery permitting) and conduct observations.
/// </summary>
Hovering = 6,
```

**Entry:** From `Ascending`/`Descending` when vvel → 0.

**Exit:** Any vertical command triggers `Ascending` or `Descending`.

---

### 2.8 HOVERINGTRIMMING

```csharp
/// <summary>
/// Fine-tuning buoyancy: small ballast adjustments (±0.5% per sec).
/// Pilot is in manual trim mode (Phase 8), making micro-corrections.
/// Duration: typically 10–30 sec per trim cycle.
/// </summary>
HoveringTrimming = 7,
```

**Entry:** `Hovering` + trim mode activated (manual command).

**Exit:** Trim mode deactivated OR |vvel| > 0.1 → back to `Hovering`/`Descending`/`Ascending`.

---

### 2.9 HOVERINGDIAGNOSTICS

```csharp
/// <summary>
/// System self-test at depth. Propeller thrust, rudder authority, sonar sweep,
/// camera focus all tested automatically. No manual input accepted during test.
/// Duration: ~60 sec. If test fails, pilot is notified; vessel stays in Hovering.
/// </summary>
HoveringDiagnostics = 8,
```

**Entry:** Operator triggers "Run Diagnostics" (Phase 8).

**Exit:** Test complete (success or failure) → back to `Hovering`.

**Telemetry:** `ManualOverride` alarm if pilot interrupts.

---

### 2.10 ASCENDING

```csharp
/// <summary>
/// Normal controlled ascent: ballast blowing, depth decreasing, vvel > 0.1 m/s.
/// Buoyancy trim is stable. Pilot expects to reach surface or target shallow depth.
/// </summary>
Ascending = 9,
```

**Entry:** `Hovering` + ballast > 90% + vvel > 0.1.

**Exit:** vvel ≈ 0 → `Hovering`, OR depth < 2m → `Surfaced`.

---

### 2.11 EMERGENCYASCENT

```csharp
/// <summary>
/// Uncontrolled ascent: ballast valve jammed closed OR vvel > 1.0 m/s.
/// Hull compressed from external forces (cave collapse, strong current).
/// Pilot must use emergency blow or move away from pressure source.
/// Risk: rapid decompression, equipment failure.
/// </summary>
EmergencyAscent = 10,
```

**Entry conditions:**
- `Ascending` + vvel > 1.5 m/s for > 2 sec.
- Ballast valve status: "stuck closed".
- External pressure spike detected (collision, cave-in).

**Exit:** Pressure source removed or emergency blow triggered.

**Alarms:** `PressureSurge`, `ThermalShock` (rapid pressure change).

---

### 2.12 BALLASTBLEEDING

```csharp
/// <summary>
/// Emergency surface procedure: all ballast tanks vented, full ascent at max rate.
/// Pilot is in lifeboat mode. Vessel surfaces in 30–120 sec depending on depth.
/// Hull can sustain damage at surface due to rough seas or collision.
/// </summary>
BallastBleeding = 11,
```

**Entry:** Manual "Emergency Surface" command (Phase 8, big red button).

**Exit:** depth < 2m → `Surfaced` (or `SurfaceHold` if waves detected).

**Telemetry:** Continuous `AlarmRaised(ManualOverride)` warning.

---

### 2.13 CRITICALAPPROACHING

```csharp
/// <summary>
/// Depth > 80% of rated crush depth. No immediate danger, but margin is thin.
/// Pilot must stop descent or begin ascent within ~30 sec (Phase 6b: ETA calculation).
/// Visual HUD flashes amber; audio: steady beep.
/// </summary>
CriticalApproaching = 12,
```

**Entry:** `Descending` + depth > (0.8 * crushDepth).

**Exit:** Depth drops back below threshold OR transitions to `CriticalExceeding`.

**Alarms:** `AlarmRaised(ManualOverride)` (warning, not critical).

---

### 2.14 CRITICALEXCEEDING

```csharp
/// <summary>
/// Hard crush depth exceeded. Hull cannot sustain this pressure.
/// Immediate emergency: vessels either auto-surface (Phase 8 setting)
/// or transition to HullCompromised (water ingress cascade).
/// Pilot has ~10 sec to surface before catastrophic failure.
/// </summary>
CriticalExceeding = 13,
```

**Entry:** Depth > crushDepth.

**Exit:** Ascending back below crushDepth (auto-surface) or catastrophic failure.

**Alarms:** Continuous `CrushDepth` (red, loud).

---

### 2.15 BEACHED

```csharp
/// <summary>
/// Depth ≈ 0, hull resting on seafloor or obstacle. Not moving vertically.
/// Vessel is immobilized; propulsion may be stuck (sand ingestion, weed wrapping).
/// Pilot must back off using thrusters or accept loss-of-vessel condition.
/// </summary>
Beached = 14,
```

**Entry:** depth < 0.5m + |vvel| < 0.1 + not at surface (SurfaceHold or Surfaced rules).

**Exit:** Ascending away (thruster command) or catastrophic (hull integrity loss).

---

### 2.16 HULLCOMPROMISED

```csharp
/// <summary>
/// Water ingress detected: hull submersion % rose unexpectedly.
/// Vessel is losing buoyancy; pilot must surface immediately or vessel sinks.
/// Auto-transitions to Unpowered after ~60 sec without intervention.
/// </summary>
HullCompromised = 15,
```

**Entry:** `SubmergedFraction` jumped > 10% in one frame, OR water ingress timer exceeded.

**Exit:** Manual surface (Phase 8) or auto-transition to `Unpowered`.

**Alarms:** Continuous `HullBreach`.

---

## 3. State Transition Logic

### 3.1 Transition Matrix (Abbreviated)

| Current | Trigger | Next State |
|---------|---------|-----------|
| `Unpowered` | Engine restart | `Hovering` (if depth stable) or `Surfaced` |
| `Surfaced` | Ballast bleed | `Descending` |
| `Descending` | vvel → 0 | `Hovering` |
| `Descending` | vvel < -1.5 for 2s | `EmergencyDescent` |
| `Hovering` | Trim mode on | `HoveringTrimming` |
| `Hovering` | Diagnostics on | `HoveringDiagnostics` |
| `Hovering` | Depth > 80% crush | `CriticalApproaching` |
| `Hovering` | depth < 2m | `Surfaced` |
| `HoveringDiagnostics` | Test complete | `Hovering` |
| `Ascending` | depth < 2m | `Surfaced` |
| `Hovering` | Manual blow | `BallastBleeding` |
| Any | Depth > crush | `CriticalExceeding` |
| Any | Water ingress | `HullCompromised` |
| Any | Power = 0 | `Unpowered` |

### 3.2 Guarding Rules

**Blocked transitions (ignored by FSM):**
- Cannot go from `Surfaced` → `Hovering` (must pass through `Descending`).
- Cannot exit `CriticalExceeding` to anything except `Ascending` (forced ascent).
- Cannot exit `HullCompromised` except via auto-surface or auto-sink.
- `HoveringDiagnostics` → any state requires manual interrupt (pilot presses "Cancel Diagnostics").

---

## 4. Implementation Architecture (Phase 6 Coding)

### 4.1 Extended DiveState Enum

```csharp
// File: Instruments/DiveState.cs
namespace DeaconsPath.VR.Instruments
{
    /// <summary>
    /// 16-state Dive State FSM (Phase 6 extended).
    /// Maps 16 operational and failure states, with backward-compatible
    /// Phase 5 bucket mapping for legacy code.
    /// </summary>
    public enum DiveState : byte
    {
        // Power & Startup
        Unpowered = 0,
        PowerFailing = 1,

        // Surface
        Surfaced = 2,
        SurfaceHold = 3,

        // Descent
        Descending = 4,
        EmergencyDescent = 5,

        // Hovering
        Hovering = 6,
        HoveringTrimming = 7,
        HoveringDiagnostics = 8,

        // Ascent
        Ascending = 9,
        EmergencyAscent = 10,
        BallastBleeding = 11,

        // Depth Critical
        CriticalApproaching = 12,
        CriticalExceeding = 13,

        // Obstacles & Failure
        Beached = 14,
        HullCompromised = 15,
    }

    /// <summary>
    /// Maps Phase 6 (16) states to Phase 5 (6) buckets for backward compatibility.
    /// </summary>
    public static class DiveStateCompat
    {
        public static DiveStateV5 ToPhase5(DiveState state) => state switch
        {
            DiveState.Unpowered or DiveState.HullCompromised => DiveStateV5.Unpowered,
            DiveState.Surfaced or DiveState.SurfaceHold => DiveStateV5.Surfaced,
            DiveState.Descending or DiveState.EmergencyDescent => DiveStateV5.Descending,
            DiveState.Hovering or DiveState.HoveringTrimming or DiveState.HoveringDiagnostics => DiveStateV5.Hovering,
            DiveState.Ascending or DiveState.EmergencyAscent or DiveState.BallastBleeding => DiveStateV5.Ascending,
            DiveState.CriticalApproaching or DiveState.CriticalExceeding => DiveStateV5.Critical,
            DiveState.PowerFailing => DiveStateV5.Critical,
            DiveState.Beached => DiveStateV5.Unpowered,
            _ => DiveStateV5.Unpowered,
        };
    }
}
```

### 4.2 Phase 6 DiveComputer Classifier

See `PHASE6_DiveComputerClassifier.cs` (next talklog entry: 2026-09-24 21:30).

---

## 5. Roadmap: Phase 6b–8

- **Phase 6b:** Predictive alarms (ETA to crush, battery depletion curve, thermal anomaly trending).
- **Phase 7:** Sensor fusion (pressure + visual + inertial) with Kalman filter.
- **Phase 8:** Pilot override system (manual state transitions, trim mode, emergency procedures).

---

## References

- [Phase 5 HLD](./HLD_PHASE5_DETAILED.md) — Previous-phase baseline.
- [DiveComputer.cs](../UnityVR/Assets/Scripts/Instruments/DiveComputer.cs) — Phase 5 implementation (to be extended).
- [DiveCockpitBridge.cs](../UnityVR/Assets/Scripts/Instruments/DiveCockpitBridge.cs) — Bridge to cockpit.
- [Thermocline Physics](./physics/thermocline.md) — (future link, Phase 7).

**Document Status:** Draft (v1.0), awaiting code review and EditMode test suite.  
**Last Updated:** 2026-09-24 17:45 UTC  
**Next Review:** After Phase 6 code complete (2026-09-25 01:30 UTC).
