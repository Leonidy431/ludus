# HLD: VR Submarine / ROV Simulator — Deacon's Path: Issyk-Kul
Version: 0.6.1 (Phases 1–5)
Scope: Unity/C# client for Meta Quest 3 (Snapdragon XR2).
Relation to CONSTITUTION.md: this document and all code under `UnityVR/`
are self-contained. No dependency on Webtypicon2 or liturgical modules.

## 1. Iteration Focus
This HLD covers **Phase 1: Input Abstraction**, **Phase 2: 6DOF Underwater
Physics & Buoyancy Engine**, **Phase 3: Interactive Cockpit (Event System)**,
**Phase 4: CI/CD (Quest 3 build + headless EditMode harness)** and
**Phase 5: Instruments (Dive Computer)**.

Phases 2–5 are delivered as *new, additive* modules under
`UnityVR/Assets/Scripts/Physics/`, `UnityVR/Assets/Scripts/Cockpit/`,
`UnityVR/Assets/Scripts/Build/` and `UnityVR/Assets/Scripts/Instruments/`.
No Phase 1 file is modified.

## 2. Problem
Gameplay systems must run identically:
- In the Unity Editor (no headset, keyboard + mouse).
- On Quest 3 wired/streamed for fast iteration.
- On Quest 3 standalone `.apk`.

Direct `UnityEngine.Input` or raw OpenXR calls scattered through gameplay
make this impossible to test and multiplies platform branches. The same
argument applies one layer up: instruments that reach into the solver make
the solver impossible to retune without collateral damage, so every boundary
in this project is crossed by exactly one adapter.

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
`VehicleCommand` and `ThrusterSpec` are pure data; `WaterColumn`,
`BuoyancyVolume` and `SixDofBody` are the solver; `InputCommandAdapter` is the
only file that knows Phase 1 exists. `ThrusterAllocator` and
`CommandWrenchMap` (additive, Phase 2 completion) are pure numeric utilities
with no `MonoBehaviour`, `Rigidbody` or `Transform` reference, so they are
EditMode-testable and free of scene state.

### 4.2 Telemetry exposed to higher layers
`SixDofBody` publishes `SubmergedFraction`, `DensityKgPerCubicMeter`,
`BallastFill`, `DepthMeters` and `IsSubmerged` as read-only properties. No
events are published from Physics: publishing would create a
Cockpit/Instruments → Physics dependency and invert the intended arrow.

## 5. Phase 4 — CI/CD (Quest 3 Build & Headless Test Harness)

### 5.1 Goal
Every push to `main` / `oculus-knights-vs-aliens` (and every PR touching
`oculus-knights/UnityVR/**`) must produce, with no human at a workstation:
1. A headless EditMode test result (JUnit XML artifact).
2. An IL2CPP / ARM64 Android `.apk` that can be side-loaded onto a Quest 3.

### 5.2 Why the build logic lives in C#, not in YAML
GitHub Actions YAML is a thin orchestration layer. All knowledge of *how* to
build a Quest 3 target lives in
`Assets/Scripts/Build/Editor/QuestBuildPipeline.cs`, invoked headlessly via
`-executeMethod`. Consequences:
- A developer pressing **Deacons Path ▸ Build ▸ Quest 3 APK** and CI calling
  `QuestBuildPipeline.BuildApk` run the identical code path.
- Player settings (IL2CPP, ARM64, Vulkan-first, linear colour, bundle id,
  min/target SDK, version code) become version-controlled C# and therefore a
  reviewable diff, instead of a hand-edited `ProjectSettings` blob.
- YAML stays portable: moving from a GitHub-hosted to a self-hosted runner
  changes one `runs-on:` line, not the build.

### 5.3 Pipeline stages
| Stage | Runner | Action | Artifact |
|---|---|---|---|
| `editmode-tests` | ubuntu-latest | `game-ci/unity-test-runner@v4`, `testMode: EditMode` | `editmode-results/*.xml` |
| `build-quest3` | ubuntu-latest | `game-ci/unity-builder@v4` → `QuestBuildPipeline.BuildApk` | `DeaconsPath-IssykKul.apk` |

`build-quest3` declares `needs: editmode-tests`, so a red test suite never
burns an IL2CPP compile. The `Library/` cache is keyed on
`Packages/packages-lock.json` and shared by both stages; the APK is then
located with a `find` step so the job does not depend on game-ci's internal
output path.

### 5.4 Licence handling
Unity activation uses the standard game-ci secrets (`UNITY_LICENSE`, or
`UNITY_EMAIL` + `UNITY_PASSWORD` + `UNITY_SERIAL`). The workflow only forwards
`secrets.*`; no licence material is ever written into the repository, and no
Webtypicon2 credential or endpoint is referenced.

### 5.5 Build stamping
`BuildStamp` (runtime-readable, no `UNITY_EDITOR` guard, `System`-only) carries
`Version`, `Channel`, `Commit` and `BuildUtc`. CI overwrites it from `GITHUB_*`
environment variables via `BuildStampWriter.WriteFromEnvironment()` *before*
the player build, so any `.apk` handed to a play-tester is traceable to a
commit without opening the Editor. The committed file holds
`local` / `unknown` defaults, so a developer build can never masquerade as a
CI artifact. `BuildStampWriter.Render` emits the exact byte shape of the
committed file, so a CI rewrite produces a minimal diff.

### 5.6 Test strategy
EditMode only. CI has no GPU and no headset, so PlayMode is deliberately out
of scope. Four families so far: `BuildStampTests` (stamping contract),
`Phase2ApiContractTests` (reflection over the frozen Phase 2 public statics),
and — from Phase 5 — `DiveComputerTests` plus `DiveCockpitBridgeTests`,
described in §6.6 and §6.9.

### 5.7 XR budget / cost
CI adds no runtime cost. `BuildStamp` is four `const string`s and a getter and
compiles away except where read; `QuestBuildPipeline` and `BuildStampWriter`
live under `Editor/` folders and are stripped from the player build entirely.

## 6. Phase 5 — Instruments (Dive Computer)

### 6.1 Goal
Turn the raw Phase 2 telemetry into the two things the pilot actually needs
underwater: *what is the boat doing right now* (`DiveState`) and *what should
I look at* (`DiveAlarm`). The instrument layer is presentation-adjacent, but
its classification logic is not: it is deterministic, scene-free and testable,
so it lives in C# and is exercised in CI rather than being buried in a HUD
script.

### 6.2 Layering
Four pieces, two bridges:

| File | Role |
|---|---|
| `Instruments/DiveTelemetrySample.cs` | Pure struct. No Unity, no Physics, no Cockpit reference. |
| `Instruments/IDiveTelemetrySource.cs` | The single instrument seam (mirrors `IVehicleCommandSource`). |
| `Instruments/SixDofTelemetrySource.cs` | The one Phase 2 → Phase 5 adapter (mirrors `InputCommandAdapter`, `CockpitCommandSource`). |
| `Instruments/DiveComputer.cs` | Classification, filtering, alarm arbitration. Publishes C# events only. |
| `Instruments/DiveCockpitBridge.cs` | The one Phase 5 → Phase 3 adapter. Republishes computer events on a `CockpitEventBus`. |

The dependency graph stays acyclic:

