# Posoh: hydrophone drawing and hardware notes (first-party, operator's repo)

Copied on 2026-09-30 for docs/HLD_POSOH_HYDROPHONE_2026-09-30.md from
`Leonidy431/posoh` @ `55f44d0` (read-only clone, not modified).
The repo is the operator's own and carries no licence file; the files
are the game author's own work, not third-party raw material, so they
are not passed through the raw runner (TABOO 0.1). They are listed in
THIRD_PARTY_NOTICES.md all the same.

| Here | Source path (same in the repo) |
|---|---|
| `hardware/HYDROPHONE_V1.md` | `hardware/HYDROPHONE_V1.md` |
| `hardware/cad/hydrophone_v1.scad` | `hardware/cad/hydrophone_v1.scad` |
| `hardware/cad/tube_enclosure_heatsink.scad` | `hardware/cad/tube_enclosure_heatsink.scad` |
| `hardware/cad/z_axis_stack.scad` | `hardware/cad/z_axis_stack.scad` |
| `hardware/cad/full_assembly.scad` | `hardware/cad/full_assembly.scad` |
| `hardware/cad/renders/*.png` (5) | `hardware/cad/renders/` |
| `hardware/firmware/hydrophone_v1/hydrophone_v1.ino` | same |
| `hardware/thermal/THERMAL_BUDGET.md` | same |
| `BOM_SENSORS.md`, `HARDWARE_INTEGRATION.md`, `OPENSCAD_DFM_PROTOCOL.md` | repo root |
| `docs/HARDWARE_BOM.md` | `docs/HARDWARE_BOM.md` |

## What the game takes from here

- `scripts/meta3d/posoh_hydrophone.py` renders every part of
  `hardware/cad/hydrophone_v1.scad` with OpenSCAD 2021.01 and writes
  `godot/models/posoh/hydrophone.glb` (lod "proxy").
- `godot/scripts/posoh_core.gd` uses the firmware's sample rate
  (40 kHz), its 500 ms report interval, the preamp's R6/C2 and C1/R4/R5
  values and the drawing's sizes.

## Real numbers found, and numbers that do not exist

| Quantity | Value | Where |
|---|---|---|
| Sample rate | 40 000 Hz (Nyquist 20 kHz) | `hydrophone_v1.ino` `SAMPLE_RATE_HZ` |
| ADC | ESP32 12-bit, GPIO34 (ADC1_CH6) | `.ino`, `HYDROPHONE_V1.md` §2 |
| Anti-alias RC | 10 kOhm + 330 pF, ~48 kHz | `HYDROPHONE_V1.md` §2 |
| AC coupling | 1 uF into 100k/100k bias (~3.2 Hz) | same |
| Preamp gain | x20 to x50, [UNVERIFIED] | same |
| Design band | dolphin whistles 4-20 kHz; clicks to ~150 kHz not captured | §1 |
| Piezo disc | 20 mm x 0.5 mm, [UNVERIFIED] (toothbrush part, unmeasured) | `.scad` |
| Tube | OD 56.4 mm, ID 50.4 mm, length 103.5 mm, wall 3 mm, PETG/ABS | `.scad` (derived), §5 |
| Sensitivity (dB re 1 V/uPa) | **none**: "No calibrated sensitivity (dB re 1 µPa) — this is a relative-level detector" | §8 |
| Depth rating | **none**: bench prototype, slip-fit O-ring "revisit before a real dive-rated build" | `.scad` O-ring comment |
| Firmware build | **not compiled** by its author ("hand-reviewed but not compiled") | §6 |

Also noted, not used by the game: `BOM_SENSORS.md` lists the MS5837-30BA
depth sensor as "0–300 mbar (0–3000 m depth)"; the -30BA part is a
30 bar (about 300 m) sensor, so that line looks like a unit slip in the
source. The Z-axis tube (`tube_enclosure_heatsink.scad`, 76 mm OD, 6.1 W
budget) is the staff's electronics bay, not the hydrophone.
