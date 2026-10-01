# Tube Enclosure Thermal Budget — Посох Z-axis Bay

**Status**: First real calculation (previously **NOT FOUND IN REPO** — no tube
diameter, heatsink sizing, or wattage-based thermal model existed anywhere
in the codebase before this document).
**Trigger**: «подними кикад нарисуй мне чертеж корпуса под чертеж как платы
в посох трубу уместить рассчитай диаметр и лепестки теплоотвода прилегающие
к трубе. рассчитай сколько тепла на макс мощности надо выводить»
**Companion artifact**: `hardware/cad/tube_enclosure_heatsink.scad`
**Renders** (via `openscad --render` under Xvfb, no GPU needed):
`hardware/cad/renders/tube_cross_section.png` (straight down the tube axis —
the clearest view of diameter + petal layout) and
`hardware/cad/renders/tube_longitudinal_section.png` (side cutaway showing
board + heatsink placement along the bay). Regenerate with
`-D cross_section_view=true` / `-D section_view=true` respectively; the
committed default (`section_view=false`) is the real, uncut geometry.

**Tool note**: the request named KiCad, but KiCad is PCB/schematic-layout
software — nothing in this repo needs a schematic or copper layout changed.
The actual ask ("corpus drawing", "tube diameter", "heatsink fins") is
mechanical/CAD, which this project already does in OpenSCAD (see
`hardware/cad/z_axis_stack.scad`, `OPENSCAD_DFM_PROTOCOL.md`). Continued
with that toolchain instead of installing a GUI PCB editor with no display
attached to run it on.

---

## 1. Max-power heat budget (real repo figures where they exist)

| Source | Value | Citation |
|---|---|---|
| HackRF thermal-throttle threshold | 1000 mA @ 5V rail | `BOM_SENSORS.md:34`, `HARDWARE_INTEGRATION.md:45,182` |
| HackRF documented TX-active current | 700–900 mA | `BOM_SENSORS.md:33`, `HARDWARE_INTEGRATION.md:181` |
| HackRF TX RF output cap | 0 dBm = 1 mW | `HARDWARE_INTEGRATION.md:159` |
| Sensor array total (INA219+NTC+MS5837+VL53L0X+BNO055) | 13 mA @ 3.3V | `BOM_SENSORS.md:241` |
| nanoESP32-C6 active current | **[UNVERIFIED]** — not in repo; ESP32-C6 public-datasheet ballpark, ~80 mA @ 3.3V during a WiFi/BT TX burst | no repo citation |

**Design point**: the system's own documented self-protection threshold
(1000 mA thermal-throttle) is the honest "max power" to design around —
not the lower 700–900 mA "documented TX-active" figure, since the
enclosure must survive right up to the point the firmware intervenes, not
just typical operation.

```
HackRF electrical input  @ 1000mA, 5V         = 5.000 W
  RF output (0dBm cap)                        = 0.001 W
  → HackRF heat                               = 4.999 W
nanoESP32-C6 [UNVERIFIED est.]  @ 80mA, 3.3V   = 0.264 W
Sensor array  @ 13mA, 3.3V (BOM_SENSORS.md:241) = 0.043 W
                                               ─────────
Total worst-case heat                          = 5.31 W
+15% safety margin (component tolerances,
  future sensor/MCU additions)                 → 6.10 W design target
```

Ultrasonic driver (`src/acoustic/ultrasonic_driver.py`) is deliberately
excluded from this electronics-bay budget: its only power figure in the
repo is an *acoustic output* model (`power_w = 0.15·V²·coupling`), not an
electrical input current, and the PZT transducer itself is expected to be
in direct contact with water/the external environment, not sealed inside
this electronics bay — it has its own separate thermal path.

**Component temperature ratings vs. this budget**: NTC thermistor rated
−40°C…+125°C, MS5837 −40°C…+85°C, VL53L0X −40°C…+70°C, BNO055
−40°C…+85°C (`BOM_SENSORS.md:62,89,124,161`); rig-level target ambient is
−10°C…+60°C (`CLAUDE.md` Feature 2 acceptance, Feature 52). VL53L0X's
+70°C ceiling is the tightest constraint on internal air temperature — the
design below keeps a healthy margin under it.

---

## 2. Tube diameter — a real design decision, not a spec lookup

No document in this repo states a target diameter for the "Посох"
tube/staff. This section **derives** one; it is a proposed value, not a
recovered fact, and should be revisited once a real ergonomics/BOM
decision is made.

- The only existing board footprint is `hardware/cad/z_axis_stack.scad`'s
  `base_width=50mm × base_length=70mm` (placeholder-but-real, per that
  file's own header).
- For a staff-shaped device, the board's long axis (70mm) should run
  **along** the tube's length (axial), not across its circular
  cross-section — otherwise the minimum tube ID would have to clear the
  board's full 86.0mm diagonal (`√(50²+70²)`), which is implausibly thick
  for something meant to be gripped like a staff (for comparison: a large
  flashlight body is ~50mm OD, a baseball bat barrel tops out ~70mm).
- With the 70mm edge axial, only the 50mm width needs to clear the tube's
  circular cross-section as a chord, leaving the radial space **beyond**
  that chord free for the internal heatsink hub+petals (§3) and wiring.

**Chosen**: tube ID = 70mm (50mm board width + 10mm clearance each side
for the heatsink + wiring), wall = 3mm, → **OD = 76mm** — a standard
"3-inch nominal" round aluminum tube stock size, genuinely sourceable, not
an arbitrary number. Aluminum is assumed for the tube material (not
stated anywhere in the repo) specifically because §3's conduction path
needs a thermally conductive tube wall — flagged here as a **material
assumption**, not a recovered spec.

---

## 3. External convection check — does the bare tube even need fins?

Natural convection from a horizontal cylinder in still air uses a modest
heat-transfer coefficient (typical textbook range 5–10 W/m²K for small
diameters and modest ΔT); this uses **h = 7.5 W/m²K** as a mid-range,
uncalibrated placeholder — flagged **[UNVERIFIED]**, pending a real CFD
or empirical measurement.

Target: keep tube surface ΔT ≤ 30 K above a 40°C worst-case field ambient
(within the −10…+60°C target range), i.e. a ~70°C touchable-but-warm
outer surface, comfortably under VL53L0X's +70°C internal-air ceiling
once internal ΔT above the tube skin is accounted for.

```
Required area:  A = Q / (h · ΔT) = 6.10 / (7.5 × 30)   = 27,119 mm²
Bare tube area (OD=76mm, 150mm electronics-bay length):
                A = π · D · L = π × 76 × 150             = 35,814 mm²
Margin: 35,814 / 27,119 = 1.32×
```

**Finding**: the bare 76mm OD tube, over a realistic 150mm electronics-bay
length, already has 32% more external convective area than the 6.1W
budget needs. **External radiating fins on the tube's outer skin are not
required by this heat budget** — adding them would be over-engineering
for a rugged field instrument with no clear thermal need (per
`AUTONOMY_PROTOCOL_99_ROUND2.md` Rule 99: necessity-gated, not
optimization for its own sake), and exposed fins are also one more thing
to catch on brush/gear in the field, or to leak through if unsealed.

The real bottleneck is not tube-to-ambient area — it's getting heat
**out of the small HackRF package and into the tube wall** in the first
place. That's what the internal heatsink actually needs to solve.

---

## 4. Internal heatsink — hub + petals (the actual "лепестки")

Design: a central hub thermally bonded (thermal pad/paste) to the
HackRF board's existing documented heat path (`HARDWARE_INTEGRATION.md`:
"FPGA → PCB thermal vias → aluminum backing plate → heatsink"), with N
petals conducting radially outward to press-fit contact points on the
tube's inner wall.

```
Hub radius              r_hub = 15 mm
Tube ID / 2                     = 35 mm
Petal length          ℓ = 35 − 15 = 20 mm
Petal cross-section    10mm (circumferential) × 3mm (axial) = 30 mm²
Aluminum k (6061-T6, conservative)  ≈ 200 W/(m·K)

R_petal = ℓ / (k · A_c) = 0.020 / (200 × 30e-6) = 3.33 K/W  (one petal)
N = 4 petals in parallel:
R_total = R_petal / N = 3.33 / 4 = 0.833 K/W

ΔT across the petals at Q = 6.10 W:
ΔT = Q · R_total = 6.10 × 0.833 = 5.08 K
```

**Finding**: 4 modest petals (10×3mm cross-section, 20mm long) already
keep the hub-to-tube-wall temperature rise under 6°C at the full 6.1W
design load — again comfortably margined, not marginal. Petal count/size
is a free parameter in `tube_enclosure_heatsink.scad` (`petal_count`,
`petal_width`, `petal_thickness`) if a future real-hardware thermal test
shows more is needed; nothing here should be read as a hard minimum.

**What would change this analysis**: a real nanoESP32-C6 current figure
(currently [UNVERIFIED]), a real tube material/wall-thickness decision,
sustained (not threshold-momentary) TX operation at a duty cycle higher
than the thermal-throttle protection assumes, or a real hydrostatic/IP67
sealing decision that removes air convection entirely (submerged
operation would need this redone against water's much higher convection
coefficient — likely an *easier* case, not harder, but not yet verified).

---

## Revision

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-08-27 | Первичный расчёт: heat budget, tube diameter derivation, external convection check, internal heatsink sizing. No prior version existed. |
