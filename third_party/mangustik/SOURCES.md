# Mangustik: drawings and panel looks (first-party, operator's repos)

Copied on 2026-09-30 for docs/HLD_MANGUSTIK_COCKPIT_2026-09-30.md.
Both repos are the operator's own private repos and carry no licence
file; the files are the game author's own work, not third-party raw
material, so they are not passed through the raw runner (TABOO 0.1).
They are listed in THIRD_PARTY_NOTICES.md all the same.

| Here | Source repo @ revision | Source path |
|---|---|---|
| `rov-platform/cad/` (15 .scad, 11 .stl, notes) | Leonidy431/Mangustik @ e0dc577 | `rov-platform/cad/` |
| `rov-platform/drawings/` (OpenSCAD renders) | same | `rov-platform/drawings/` |
| `rov-platform/electronics/central_control_check.svg` | same | `rov-platform/electronics/central_control_pcb/kicad/` |
| `dive-buddy/*.scad` | same | `dive-buddy/hardware/chassis/` |
| `welder-module/pipe_parts_d110/` (.scad, .stl, .png, .svg) | same | `welder-module/hardware/mechanical/pipe_parts_d110/` |
| `panels/diveguard/` (Vue dashboard, globals.css) | same | `diveguard/underwater-ai-platform/frontend/` |
| `panels/yacht-blueos/` (globals.css, tailwind, dashboard, compass) | Leonidy431/Mangustik-BlueOs-Yacht-UAV @ 48443c9 | `project (19).zip` |

Not taken: no audio exists in either repo (checked every file and all
13 zip archives); `Lyyn photos/` are frames of other people's videos;
`rov-platform/frame_*.jpg` and the yacht repo's screenshot show another
firm's branded vehicle.

The game builds `godot/models/rov/mangustik.glb` from the STL files here
with `scripts/meta3d/mangustik_rov.py`.
