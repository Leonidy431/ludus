# HLD: VR Submarine / ROV Simulator — Deacon's Path: Issyk-Kul
Version: 0.3 (Phases 1–3)
Scope: Unity/C# client for Meta Quest 3 (Snapdragon XR2).
Relation to CONSTITUTION.md: this document and all code under `UnityVR/`
are self-contained. No dependency on Webtypicon2 or liturgical modules.

## 1. Iteration Focus
This HLD covers **Phase 1: Input Abstraction**, **Phase 2: 6DOF Underwater
Physics & Buoyancy Engine**, and **Phase 3: Interactive Cockpit (Event
System)**. CI/CD (Phase 4) is referenced as a consumer but not implemented
here.

Phases 2 and 3 are delivered as *new, additive* modules under
`UnityVR/Assets/Scripts/Physics/` and `UnityVR/Assets/Scripts/Cockpit/`.
No Phase 1 file is modified.

## 2. Problem
Gameplay systems must run identically:
- In the Unity Editor (no headset, keyboard + mouse).
- On Quest 3 wired/streamed for fast iteration.
- On Quest 3 standalone `.apk`.

Direct `UnityEngine.Input` or raw OpenXR calls scattered through gameplay
make this impossible to test and multiplies platform branches.

## 3. Phase 1 — Input Abstraction

### 3.1 Contract
`IPlayerInput` is the sole surface gameplay sees:

| Member                | Range / Type       | Consumer                        |
|-----------------------|--------------------|---------------------------------|
| `HeadPose`            | `Pose`             | Camera, SONAR cone origin       |
| `IsPrimaryHandTracked`| `bool`             | Cockpit hand rendering          |
| `PrimaryHandPose`     | `Pose`             | Lever ray-cast, tooltips        |
| `MoveAxis`            | `Vector2` [-1..1]  | Thruster lateral/vertical cmd   |
| `LookAxis`            | `Vector2` [-1..1]  | Head/camera assist              |
| `PrimaryTrigger`      | `float` [0..1]     | Thrust magnitude curve / grab   |
| `PrimaryGrip`         | `float` [0..1]     | Ballast blow / grab             |
| `PrimaryButtonPressed`| `event`            | Interact / toggle               |
| `PrimaryButtonReleased`| `event`           | Release hooks (winch, latch)    |
| `SecondaryButtonPressed`| `event`         | Menu / dive computer            |

All analog values are deadzoned and clamped inside the backend so physics
receives clean data. Deadzone = 0.15 (tunable constant).

### 3.2 Implementations
- `MouseSimulatorInput` — Editor/desktop. WASD, mouse look, LMB/RMB triggers,
  Space primary, Tab secondary. Produces the same 0..1 analog values, so
  physics code cannot tell the difference.
- `OpenXRInput` — Quest 3. Uses `UnityEngine.XR.InputDevices`. Head pose via
  `centerEyePosition` / `centerEyeRotation`; right-hand controller for stick,
  trigger, grip and buttons. Device handles are cached and re-resolved lazily
  on drop (headset sleep / reconnect).

### 3.3 Selection & lifetime
`InputProvider` (MonoBehaviour, `DefaultExecutionOrder(-100)`) owns the active
backend and calls `Tick(dt)` once per frame. `InputProvider.Current` exposes
the active backend and `BackendChanged` fires when the backend swaps.

## 4. Phase 2 — 6DOF Physics & Buoyancy Engine

### 4.1 Layering
The module is split so that *data*, *solvers* and *platform glue* never mix:

