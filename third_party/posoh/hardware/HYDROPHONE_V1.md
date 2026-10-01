# Hydrophone "Model 1" — Toothbrush Piezo + ESP32

**Status**: DESIGN + first parametric enclosure, not yet built/field-tested.
**Trigger**: «есть зубная щетка с вибро пьезо элементом. построй корпус
гидрофона на основе знаний о звуковом аппарате дельфинов и встрой туда
элемент зубной щетки а управлять будем через esp32 ... сделай простую
рабочую модель номер один» — build a hydrophone enclosure using an
electric toothbrush's piezo vibration element, controlled by an ESP32; a
simple working "model 1", not a lab-grade instrument.

Produced under `OPENSCAD_DFM_PROTOCOL.md`. CAD: `hardware/cad/hydrophone_v1.scad`
(rendered/manifold-checked via `openscad`, three boolean interference
checks confirmed empty — see that file's own header comment for detail).
Render: `hardware/cad/renders/hydrophone_v1.png`. Firmware:
`hardware/firmware/hydrophone_v1/hydrophone_v1.ino`.

---

## 1. Why this can work, and where "model 1" honestly stops

### The piezo disc is a receiver here, not an actuator

An electric toothbrush's vibration element is a piezoelectric disc: apply
a voltage, it deforms and vibrates (that's how the toothbrush uses it).
The same physical effect runs in reverse — deform the disc mechanically
(e.g. with a passing pressure wave in water) and it generates a small
voltage across its electrodes. That's the entire principle behind a
piezo-disc contact-mic/hydrophone: no rewiring the device, just repurpose
the disc as a passive sensor.

Two consequences that shape the whole design:
- **The signal is tiny** (single-digit to low tens of millivolts for a
  small disc at typical underwater sound pressures) — it needs a
  preamplifier before it can drive an ADC that expects a 0–3.3V swing.
- **A bare piezo disc floating in air over a circuit input is useless as
  a sensor** — it needs a DC bias/bleed path (a large resistor to ground)
  or the amplifier's input just drifts, and it needs direct mechanical
  coupling to water (not an air gap, which reflects almost all incident
  sound at a water/air boundary) — hence potting it in epoxy rather than
  leaving it behind an air-backed window.

### Dolphin vocalization range vs. what an ESP32's built-in ADC can capture

Two broad categories, well-established in bioacoustics (general textbook
knowledge, not a project-specific measurement, so no single citation is
attached — this is the same "known biology, not invented" register this
project's own `src/acoustic/dolphin_decoder.py` uses):
- **Whistles** (social communication): roughly 4–20 kHz fundamental,
  well within reach of modest sampling rates.
- **Echolocation clicks**: broadband, energy extending up to
  ~100–150 kHz — this needs sample rates well above 200 kHz to capture
  properly (Nyquist), which the ESP32's built-in successive-approximation
  ADC cannot sustain in continuous mode at any usable resolution.

**Honest scope for model 1**: the firmware below samples around 40 kHz
(Nyquist ≈ 20 kHz), which covers the *whistle* band and the low end of
click energy, but will alias or miss the bulk of a real echolocation
click's spectral content. This is the same kind of explicit bandwidth
disclosure this repo already applies elsewhere (e.g.
`src/acoustic/dolphin_decoder.py`'s bandwidth-estimation notes) — stated
here rather than silently implying "model 1" hears everything a dolphin
does. A model 2 with an external high-speed ADC (or the ESP32's I2S
peripheral driving a proper delta-sigma ADC chip) is the real path to
click-bandwidth capture; out of scope for this pass.

---

## 2. Circuit (model 1 — breadboard-simple, not a KiCad layout)

```
 Piezo disc                 Preamp (single-supply op-amp, e.g. MCP6002/LM358)
 ┌────────┐   C1 (1uF)      ┌────────────────────────────────────┐
 │  +  ── ├───||──┬─────────┤ +in                                │
 │        │       │         │              op-amp   ┌── R2 ──┐   │
 │  -  ── ├───────┴── R1 ───┤ (bias net,   (gain =   │        │  ├── ADC out ──> ESP32 GPIO34 (ADC1_CH6)
 └────────┘   (1-10 MOhm    │  Vcc/2 via   1+R2/R3)  R3        │  │        (through anti-alias RC below)
              bleed to GND) │  R4=R5=100k) └─────────┴────────┘  │
                             └────────────────────────────────────┘
                                        │
                          Anti-alias low-pass: R6 (10k) + C2 (330pF)
                          -> ~48 kHz corner, ahead of ESP32 ADC pin
```

- **R1 (1–10 MΩ)** across the piezo's own terminals: bleeds static
  charge, gives the disc a DC reference instead of floating — standard
  practice for any piezo pickup, not specific to this project.
- **C1 (~1 µF)**: AC-couples the piezo into the preamp, blocks DC offset.
- **Bias network (R4=R5=100 kΩ)**: splits the single 3.3V supply to
  Vcc/2, so the op-amp's non-inverting input sits mid-rail — required
  for a single-supply op-amp to swing a signal that goes both above and
  below its rest point (an AC pickup signal does).
- **Gain (R2/R3)**: pick for roughly ×20–×50 depending on the disc's real
  output level, adjusted empirically on the bench (this is exactly why
  "model 1" stays on a breadboard/perfboard, not a fixed PCB — the real
  gain needed for the specific piezo disc pulled from the specific
  toothbrush is unknown ahead of time; flagged `[UNVERIFIED]` rather than
  guessed at a specific resistor value).
- **Anti-alias RC (R6/C2)**: a simple single-pole low-pass ahead of the
  ADC, corner frequency picked below the ESP32's sampling Nyquist so
  aliased noise doesn't fold back into the whistle band.
- **ESP32 ADC pin**: `GPIO34` (ADC1, input-only pin, doesn't conflict
  with WiFi-shared ADC2) — a deliberate choice, not arbitrary; ADC2 pins
  are unusable while WiFi is active on the ESP32, which model 1's
  firmware doesn't need yet but a model 2 streaming over WiFi would.

---

## 3. Assembly order (AK-74-simple) and Neptune 4 Pro print prep

**Guru-chorus DFM re-pass, 2026-09-19** — triggered by the first render
(`hardware/cad/renders/hydrophone_v1.png`) coming back looking blank.
Root cause, found with real `openscad` runs, not guessed: the render's
`--camera` translate target was `(90,40,60)` — outside the model's actual
envelope (a ⌀56×104mm cylinder centered on the Z axis) — so the camera
was pointed at empty space, not a rendering/geometry defect. Fixed by
centering the camera translate on the model (`0,0,52`) and adding a
`section_view` cutaway toggle (same pattern already used in
`hardware/cad/tube_enclosure_heatsink.scad`, for the same reason: this
repo's PNG export doesn't composite `color()` alpha, so a solid tube
wall hides the internals from any outside angle). Both the full-assembly
and section renders were verified non-blank by decoding the PNG's own
pixel data (zlib-inflating the IDAT stream and checking real color
variance), not by eyeballing — Pillow isn't installed in this sandbox.

**Part count, unchanged by this pass** (already minimal): 2 printed
parts (`tube_body`, `end_cap`) + 4 identical printed `standoff` pegs +
off-the-shelf/salvaged electronics (piezo disc, preamp board, ESP32
devkit). Nothing was added — Rule 99 Round 2 (necessity-gated) — the
request to "add details but minimally" is satisfied by clarifying the
*documentation* (assembly order, print orientation), not the part count.

**Assembly order — one sequence, no branches, no left/right parts**
(the AK-74-field-strip-level unambiguity the guru chorus asked for):

1. Epoxy-pot the piezo disc into `tube_body`'s sensor-end cavity.
2. Glue the 4 (identical) standoffs into the dry bay.
3. Screw the preamp board onto its 2 standoffs, then the ESP32 onto its
   2 standoffs (M2 self-tap).
4. Wire piezo → preamp → ESP32 through the central channel.
5. Seat the O-ring in `end_cap`'s groove, slide it into the tube's open
   end until the flange meets the tube face.

**Neptune 4 Pro print readiness**: real, published build volume
(225×225×265mm) is now an `assert()` in `hydrophone_v1.scad` itself
(tube_od ≈ 56.4mm, tube_total_length ≈ 103.5mm — comfortably inside, so
the assert is a regression guard against a future parameter change, not
a live constraint today). Each part's modeled orientation (flat face at
z=0) already IS its correct print orientation — axis vertical, no
rotation needed before slicing, no supports (both `tube_body` and
`end_cap` are axisymmetric with only horizontal internal floors, no
overhangs steeper than that). Per-part STL export:
`openscad -D 'print_part="tube_body"' -o tube_body.stl hydrophone_v1.scad`
(same for `"end_cap"` and `"standoff"`) — exported and manifold-checked
this session into `hardware/cad/stl/` (not committed as binary STL
churn; regenerate on demand from the `.scad` source, same convention
this repo already uses for `z_axis_stack.scad`/`tube_enclosure_heatsink.scad`).

## 4. Mechanical enclosure (`hardware/cad/hydrophone_v1.scad`)

Three zones along one sealed tube (full derivation and DFM critique in
the `.scad` file's own header comment, not duplicated here):

1. **Sensor end** — closed by the tube's own printed wall (no seam), with
   a potting cavity sized generously (piezo diameter + 8mm) over the
   piezo's real dimensions, since the exact toothbrush part's size is
   unmeasured (`[UNVERIFIED]`, see the `.scad` file). Filled with marine
   epoxy at assembly time, which also acoustically couples the piezo to
   the water (matched impedance, unlike an air gap).
2. **Dry bay** — the preamp board and an ESP32 devkit, on M2 standoffs,
   mounted lengthwise (same orientation convention as this repo's
   `z_axis_stack.scad`).
3. **Removable end cap** — O-ring-sealed slip-fit (no threads — a
   bench-prototype "model 1" doesn't need them, Rule 99 Round 2:
   necessity-gated, don't over-engineer), giving USB access for
   programming/charging without disturbing the potted sensor end.

Verified via real `openscad` boolean checks (`Current top level object is
empty` for all three — piezo vs. tube wall, boards vs. tube wall, end cap
plug vs. outside the tube ID), not eyeballed.

---

## 5. Bill of materials (model 1)

| Part | Notes |
|------|-------|
| Toothbrush piezo disc | Salvaged, unmeasured — verify real diameter/thickness before potting; the CAD cavity has margin either way |
| ESP32 DevKitC (or equivalent) | Any common ~28×55mm devkit |
| Single-supply op-amp (MCP6002, LM358, or similar) | Rail-to-rail input preferred |
| Resistors: 1–10 MΩ (bleed), 2× 100 kΩ (bias), gain pair (empirical), 10 kΩ (anti-alias) | |
| Capacitors: 1 µF (AC couple), 330 pF (anti-alias) | |
| 3D-printed enclosure per `hydrophone_v1.scad` | PETG or ABS for water contact, not PLA (poor long-term water/UV resistance) |
| 2-part marine/waterproof epoxy | Potting compound for the sensor end |
| O-ring cord, ~2.5mm section | Cut to length for the end-cap groove; groove sizing is a DIY approximation, `[UNVERIFIED]` against a real O-ring datasheet — fine for bench use |

---

## 6. Verification caveat (same discipline as this repo's Docker/KiCad notes)

Neither `arduino-cli` nor `platformio` is available in this sandbox (checked:
`which arduino-cli platformio pio` — none found), so
`hydrophone_v1.ino` has been hand-reviewed but **not compiled**. Do not
treat it as verified-buildable without an actual `arduino-cli compile
--fqbn esp32:esp32:esp32` (or PlatformIO) run on a machine with the ESP32
board package installed — the same "reviewed, not build-tested" caveat
this repo already applies to its Dockerfiles.

## 7. Firmware (`hardware/firmware/hydrophone_v1/hydrophone_v1.ino`)

Simple, honest "model 1" scope: sample the ADC on a timer at ~40 kHz,
report a running peak level over serial, and flag a simple
threshold-crossing "possible whistle" event — not a full detector, not
integrated with this repo's own `src/acoustic/dolphin_decoder.py` (that
module's pipeline is built around HackRF/RF-domain spectrum frames, a
different signal chain entirely; wiring an ESP32 audio stream into it is
a real follow-up, not assumed done here).

---

## 8. Known limitations / model 2 candidates

- Click-band (up to ~150 kHz) capture needs a real high-speed ADC path
  (I2S + external delta-sigma ADC), not the ESP32's built-in SAR ADC.
- No calibrated sensitivity (dB re 1 µPa) — this is a relative-level
  detector, not a measurement instrument, until a reference calibration
  pass is done against a known source.
- Gain resistor values are placeholders pending real bench measurement
  of the specific piezo disc's output.
- No integration yet with this repo's own detection pipeline
  (`src/acoustic/dolphin_decoder.py`, `src/signal_classifier.py`) — those
  operate on this project's RF/HackRF-domain data model; bridging an
  ESP32 audio stream into that pipeline is unscoped follow-up work, not
  claimed here.
