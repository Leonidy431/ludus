
## 5. Interfaces to later phases
- **Phase 2 (Physics):** samples `InputProvider.Current.PrimaryTrigger` and
  `MoveAxis` as commands; maps to buoyancy/thruster forces.
- **Phase 3 (Cockpit):** ray-casts from `PrimaryHandPose`, drives lever
  visuals from `PrimaryGrip`.
- **Phase 4 (CI/CD):** build treats `InputProvider` as the only input entry
  point, so an Android `.apk` needs no scene edits.

## 6. Open Items / Next Iteration
- Add `XR_HANDS` skeletal path when hand-tracking-only mode is required.
- Phase 2: thermocline density + 6DOF model.
- Phase 4: GitHub Actions YAML for Quest 3 `.apk`.
