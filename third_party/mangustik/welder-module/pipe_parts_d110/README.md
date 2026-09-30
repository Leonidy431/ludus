# d110 PE pipe parts kit — 3D models + drawings + assembly

A comprehensive parametric kit of PE (polyethylene) pipe parts for modular
electrofusion welder controller systems. Includes straight segments, 
electrofusion fittings (муфта / coupling, отвод / elbow, тройник / T-junction), 
end caps (заглушки), and complete housing assemblies, all sized for nominal 
outside diameter **d110** (PN10/PN16 SDR17/SDR11). Built with OpenSCAD (3D) 
parametric design + Python-generated GOST-style 2D drawing sheets, following 
this repo's verify-before-fabricate discipline (see root `CLAUDE.md`'s "Bugs 
found while writing tests" / fix-vs-document rule — the same honesty standard 
applies to CAD dimensions, not just code).

## What's here

```
lib_d110.scad                    — shared OpenSCAD parameters + reusable modules
pipe_segment_d110.scad           — instantiates a standalone pipe segment
coupling_d110.scad               — instantiates a straight coupling (муфта)
elbow90_d110.scad                — instantiates a 90-degree elbow (отвод)
tee_d110.scad                    — instantiates a T-junction (тройник)
cap_d110.scad                    — instantiates an end cap (заглушка)
housing_d110_assembly.scad       — complete modular housing assembly (500mm×300mm×250mm)
generate_drawings.py             — generates 2D GOST-style SVG drawing sheets
models/*.stl                     — exported 3D solids (binary STL format)
drawings/*_iso.png               — isometric reference renders (3D visualization)
drawings/*.svg                   — 2D dimensioned drawing sheets (GOST чертежи)
```

## Sourcing — what's GOST-verified vs. an engineering estimate

This sandbox's network egress is restricted to GitHub-related domains (see
root `CLAUDE.md`), so the primary GOST PDF text itself could not be fetched
directly — search-engine snippets and commercial-catalog citations were the
only source available. The numbers below are split accordingly; **do not
treat the "estimate" column as a certified GOST or manufacturer figure.**

| Parameter | Value | Status |
|---|---|---|
| Pipe nominal OD, d110 | 110.0 mm | **GOST 18599-2001 verified** — cross-confirmed across ≥4 independent commercial citations of the standard (ssd.ru, santech.ru, nf-truba.ru, prombase.ru) |
| Wall thickness, SDR17 (PN10) | 6.6 mm | **GOST 18599-2001 verified** — same cross-check |
| Wall thickness, SDR11 (PN16) | 10.0 mm | **GOST 18599-2001 verified** — same cross-check |
| Fitting body wall thickness | 10.0 mm (= SDR11 pipe wall) | Engineering estimate — fittings are conventionally sized to at least the heavier mating SDR for a strength margin; not read off a manufacturer datasheet |
| Socket engagement depth | 55 mm (≈0.5×OD) | Engineering rule-of-thumb, not a GOST 32415-2013 table value |
| Socket bore clearance | +1.0 mm total (0.5 mm/side) | Typical engineering fit clearance, not a datasheet value |
| Coupling center-land length | 15 mm | Engineering estimate (the 3D model does not actually cut a distinct center-stop step — see "Known simplifications" below) |
| T-junction (Тройник) center sphere diameter | 20 mm | Visual placeholder for junction consolidation point; actual center-junction geometry depends on flow characteristics |
| T-junction socket spacing | 3 main sockets + 2 branch perpendicular | Standard configuration; allows for center-line flow and perpendicular bypass paths |
| End cap (Заглушка) dome radius | 55 mm (0.5×OD) | Hemispherical sealing surface; engineered estimate matching socket depth for closure grip |
| Elbow bend radius (centerline) | 165 mm (1.5×OD) | Common "long-radius" elbow rule of thumb, not a specific manufacturer's figure |
| Housing assembly main height | 500 mm | Demo assembly height; real installations scale per pressure vessel requirements and pipeline routing |
| Housing assembly branch width | 300 mm | Demo lateral extension; allows space for instrumentation and maintenance access |
| Heater terminal pin size/spacing | ⌀4mm, 20mm inset (top/middle), 5mm inset (lower) | Visual placeholder — the real spiral heater-wire layout is not modeled at all; varies per fitting type |
| Demo pipe segment length | 300 mm | **Not a GOST value at all** — a benchtop/test-rig sample length; real stock ships in 12 m lengths per the same sources |
| Mass estimates in title blocks | computed | Volume × 0.95 g/cm³ (standard PE100 density reference) from the modeled geometry above — only as accurate as that geometry, i.e. exact for the pipe segment, approximate for the fittings |

**Why the fitting dimensions aren't a single GOST table**: GOST 32415-2013
("Детали соединительные из полиэтилена...") sets material, testing, and
performance requirements for electrofusion fittings — it does not publish a
single universal CAD dimension table the way GOST 18599-2001 does for plain
pipe. Real fitting body dimensions (socket depth, overall length, terminal
layout) vary per manufacturer's own technical specification (ТУ). Treat
every "estimate" row above as a placeholder to replace with a real datasheet
figure before using this kit for anything beyond a demo/test-bench reference.

## Known simplifications (3D models)

- **Coupling bore is uniform**, not stepped — there is no modeled physical
  center-stop ridge, even though `CENTER_LAND` documents an intended
  non-socket middle section length. A uniform bore is still a functionally
  reasonable simplification for a demo part; note it before relying on this
  for a manufacturing drawing.

- **T-junction center consolidation is a simple sphere**, not a complex flow-optimized
  junction bulge. The real electrofusion fitting would have ramped socket transitions
  and internal ribs for structural support; this model is a visual placeholder for
  component layout. **Before manufacturing**: Replace with actual manufacturer geometry
  or run 3D fluid-dynamics (CFD) analysis for pressure/flow verification at PN10/PN16.

- **End cap dome is a perfect hemisphere**, not an optimized seal surface. The real
  closure would include a chamfered edge, surface-roughness specification for the
  sealing contact, and (for electrofusion caps) heater-coil geometry around the
  hemisphere perimeter. This model serves assembly mock-up only.

- **T-junction and cap terminal bosses** are cylindrical visual markers (⌀4mm), not
  the actual spiral heater-wire layout. Real electrofusion heating coils wrap around
  the fitting body with specific pitch/current-path geometry; consult manufacturer ТУ
  (technical specifications) before committing to heater-wire routing.

- **Elbow bend is a smooth constant-radius torus**, not the exact geometry
  of any specific manufacturer's long-radius fitting. The heater-wire coil layout
  is not modeled on any fitting — only visual pin bosses mark where real terminals 
  would be.

- **Housing assembly uses rigid pipe segments connecting fittings** — no modeling
  of thermal expansion, pressure cycling, or flow-induced vibration. Real deployments
  require strain-relief bends, shock-dampening mounts, and thermal-cycle FEA validation.

- All fittings' 2D drawings show wall material via cross-hatching in
  **full longitudinal section** (pipe, coupling, T-junction, cap) or a **schematic 
  double-line view** (elbow — a full section through a 3D bend is not a simple single 2D
  view, so a schematic centerline+wall representation is used instead,
  consistent with how most fitting catalogs show elbows).

## Regenerating 3D models from parametric source

All models rebuild from parametric library (`lib_d110.scad`). Updating a single
parameter (e.g., `SOCKET_DEPTH`) automatically propagates to all components.

```bash
# Individual components -> STL (no GUI/OpenGL needed for export)
openscad -o models/pipe_segment_d110.stl  --export-format=binstl --render=true pipe_segment_d110.scad
openscad -o models/coupling_d110.stl      --export-format=binstl --render=true coupling_d110.scad
openscad -o models/elbow90_d110.stl       --export-format=binstl --render=true elbow90_d110.scad
openscad -o models/tee_d110.stl           --export-format=binstl --render=true tee_d110.scad
openscad -o models/cap_d110.stl           --export-format=binstl --render=true cap_d110.scad

# Complete housing assembly
openscad -o models/housing_d110_assembly.stl --export-format=binstl --render=true housing_d110_assembly.scad

# Isometric PNG renders (needs virtual display via xvfb-run; OpenGL rendering unavailable in headless)
# Note: PNG generation has failed in headless sandbox environment. SVG/PDF export recommended instead.
# xvfb-run -a openscad -o drawings/pipe_segment_d110_iso.png --imgsize=900,700 --render=true --autocenter --viewall pipe_segment_d110.scad
# xvfb-run -a openscad -o drawings/coupling_d110_iso.png     --imgsize=900,700 --render=true --autocenter --viewall coupling_d110.scad
# xvfb-run -a openscad -o drawings/elbow90_d110_iso.png      --imgsize=900,700 --render=true --autocenter --viewall elbow90_d110.scad
# xvfb-run -a openscad -o drawings/tee_d110_iso.png          --imgsize=900,700 --render=true --autocenter --viewall tee_d110.scad
# xvfb-run -a openscad -o drawings/cap_d110_iso.png          --imgsize=900,700 --render=true --autocenter --viewall cap_d110.scad
# xvfb-run -a openscad -o drawings/housing_d110_assembly_iso.png --imgsize=1200,900 --render=true --autocenter --viewall housing_d110_assembly.scad

# 2D GOST-style drawing sheets (SVG)
python3 generate_drawings.py
```

**Headless rendering note**: PNG isometric visualization requires OpenGL context
and virtual display (`xvfb-run`). STL export works fully in headless mode and is
the primary deliverable for 3D printing/CAM workflows. For documentation, generate
PDF/SVG via `generate_drawings.py` or use CAM-tool viewer (e.g., Fusion 360, 
FreeCAD, Cura) for visual inspection.

## Assembly instructions (Housing d110)

The **housing_d110_assembly.scad** demonstrates a vertical modular layout suitable
for electrofusion welder controller installations:

1. **Main vertical spine** (Z-axis, 500mm total):
   - Bottom: Pipe segment (200mm) with mounting flanges
   - Z=200: T-junction (тройник) — main flow path continues upward; two branch paths extend horizontally
   - Middle: Pipe segment (150mm)
   - Z=350: Second T-junction — additional branch connections
   - Top: Pipe segment (100mm)
   - Z=500: End cap (заглушка) — seals the main axis

2. **Horizontal branches** (XY plane, ±300mm/±250mm):
   - Each branch extends from a T-junction, includes a 90° elbow (отвод) for directional change
   - Terminates with an end cap for safety/sealing
   - Accommodates sensor ports or branch piping connections

3. **Electrofusion heating integration**:
   - Each fitting (coupling, T-junction, elbow, cap) has visible terminal bosses (⌀4mm)
   - Real installations require heater-coil wiring per manufacturer ТУ (specs) and electrical safety codes
   - Terminal positioning allows dual-phase power distribution across upper/middle/lower junction groups

4. **Material flow and pressure distribution** (PN10/PN16 rating):
   - Main path rated to SDR17 (6.6mm wall, PN10) or SDR11 (10.0mm wall, PN16)
   - T-junctions use SDR11 wall thickness for structural margin
   - All sockets sized for 55mm engagement depth (socket_depth = 0.5×OD)

The title blocks are explicitly labelled "УПРОЩЁННЫЙ ШТАМП" (simplified
title block) — they follow the general layout/field spirit of GOST 2.104
form 1 but are not a certified ЕСКД title block, consistent with this
directory's existing `hardware/mechanical/README.md` disclosure practice for
not-independently-verified dimensions.

## Connector elements (разьемы) — quick-disconnect couplings & flanged interfaces

Electrofusion systems require modular assembly/disassembly for maintenance and
field reconfiguration. Three connector strategies are supported:

### Strategy 1: Electrofusion Straight Connector (Self-sealing)
- **Description**: Butt-fusion or snap-fit male/female halves; sealing happens when sockets engage
- **Pros**: Eliminates external connectors; minimal dead volume; direct power routing
- **Cons**: One-time mating cycle; no quick-disconnect after first weld; requires tools to break apart
- **Use case**: Permanent installations where pipes are not expected to be disconnected post-commissioning
- **Parametric model status**: Coupling and T-junction already have built-in socket architecture for this approach

### Strategy 2: Flanged Bulkhead Interface (Bolted)
- **Description**: Flat face + bolt pattern for quick-disconnect without de-electrifying
- **Flange diameter**: 150mm (standardized for d110 fittings)
- **Bolt pattern**: 4× M8 holes on 120mm PCD (bolt circle diameter)
- **Seal type**: Elastomer face seal (FKM/Viton O-ring in counterbore)
- **Status**: Planned for connector_d110_flange.scad (Phase 2)

### Strategy 3: Camlock Quick-Disconnect (ISO 16028)
- **Description**: Lever-actuated camlock couplers; fully separable under pressure with self-sealing
- **Bore size**: 1 inch (25.4mm standard); available in 110mm OD body wrapper
- **Pressure rating**: Typically PN16 equivalent (160 bar)
- **Flat-face design**: Minimizes spillage; suitable for contaminated environments
- **Status**: Planned for connector_d110_camlock.scad (Phase 3)
- **Integration note**: Camlock body wraps around d110 pipe; socket opening accepts standard 1" ISO couplers

### Electrical quick-disconnect (разьемы для электрики)
Separate from pneumatic couplers; planned for sibling directory `electrical_connectors_d110/`:
- Pogo-pin contact arrays (for low-power sensors)
- M16 circular connectors (IEC 61076-2-109) for heater/power distribution
- Bayonet-lock or M20 thread versions for field robustness

**Current recommendation**: Use electrofusion direct-socket strategy (Strategy 1) for the main housing assembly. Stage connector elements for Phase 2 (flange) and Phase 3 (camlock) after initial welding commission and field-testing reveal modularity requirements.
