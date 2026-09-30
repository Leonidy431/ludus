// tube_enclosure_heatsink.scad — Посох tube electronics bay + internal heatsink
//
// Produced under OPENSCAD_DFM_PROTOCOL.md in response to: "нарисуй мне
// чертеж корпуса под чертеж как платы в посох трубу уместить рассчитай
// диаметр и лепестки теплоотвода прилегающие к трубе. рассчитай сколько
// тепла на макс мощности надо выводить."
//
// Full calculation and citations: hardware/thermal/THERMAL_BUDGET.md.
// No tube diameter existed anywhere in the repo before this file --
// dimensions below are a derived design decision (documented as such,
// not a recovered spec), sized against the z_axis_stack.scad board
// footprint (50x70mm) and a real 6.1W max-power heat budget built from
// this repo's own HackRF/sensor current figures.
//
// ===========================================================================
// 1. Критика и анализ (DFM/DFA)
// ===========================================================================
// - Слабое место А: если плату (50x70мм) ориентировать поперёк круглого
//   сечения трубы, минимальный внутренний диаметр должен перекрывать её
//   диагональ (86.0мм) -- нереалистично толсто для предмета, который
//   держат как посох. Решение: длинная сторона платы (70мм) идёт ВДОЛЬ
//   оси трубы, только ширина (50мм) ограничивает диаметр сечения.
// - Слабое место Б: расчёт (THERMAL_BUDGET.md §3) показывает, что голая
//   труба уже даёт запас по конвекционной площади -- внешние рёбра на
//   наружной поверхности не нужны и были бы избыточным усложнением
//   (Правило 99, Раунд 2: не делай того, что не требуется расчётом).
//   Реальное узкое место -- внутренний тепловой мост от малого корпуса
//   HackRF к стенке трубы, отсюда ступица + "лепестки" внутри, не снаружи.
// - Слабое место В: лепестки должны ПРИЖИМАТЬСЯ к внутренней стенке трубы
//   без зазора (воздушный зазор убивает теплопроводность) -- зазор
//   `petal_fit_clearance` держит посадку скользящей/прессовой, а не
//   "впритык", как и остальные соединения в этом проекте.
//
// ===========================================================================
// 2. Улучшенная архитектура
// ===========================================================================
// Труба (tube_id/tube_od) окружает электронный отсек. Плата (board_width x
// board_length, как в z_axis_stack.scad) лежит вдоль оси трубы на своей
// половине хорды. Теплоотвод -- см. heatsink() ниже -- термически связан с
// алюминиевой подложкой платы под HackRF (см. HARDWARE_INTEGRATION.md:
// "FPGA -> PCB vias -> aluminum backing plate") и передаёт тепло к стенке
// трубы через `petal_count` рёбер, прижимающихся торцами к внутренней
// стенке -- это и есть проводящий тепловой мост, посчитанный в
// THERMAL_BUDGET.md §4 (ΔT ≈ 5°C при полной нагрузке 6.1Вт). Геометрия
// самого моста (накладка + параллельные рёбра, а не диск + радиальные
// лепестки) обновлена версией ниже (2026-09-18, пробная сборка против
// реального стека z_axis_stack.scad) -- см. полное обоснование в
// комментарии прямо над heatsink().

// ===========================================================================
// Global parameters (all dimensions in mm)
// ===========================================================================
$fn = 64;
eps = 0.01;

// Tube (derived in THERMAL_BUDGET.md §2 -- a design decision, not a spec)
tube_id = 70;                 // Board width (50) + 10mm clearance each side
tube_wall = 3;                // Standard structural aluminum tube wall
tube_od = tube_id + 2 * tube_wall;   // 76mm -- "3-inch nominal" stock size
bay_length = 150;             // Electronics-bay length used in the convection check

// Board (matches hardware/cad/z_axis_stack.scad's real footprint)
board_width = 50;             // Spans as a chord across the tube ID
board_length = 70;            // Runs axially along the tube
board_thickness = 1.6;

// Internal heatsink: hub + petals (THERMAL_BUDGET.md §4)
hub_diameter = 30;            // hub_radius = 15mm, per the thermal calc
hub_thickness = 4;
petal_count = 4;
petal_width = 10;             // Circumferential width at the hub
petal_thickness = 3;          // Axial thickness
petal_fit_clearance = 0.3;    // Slightly compressible press-fit against tube ID,
                               // not a bare touch -- keeps real thermal contact
hub_slot_clearance = 0.3;     // Kept for the pad's board-clearance offset below
                               // (renamed in spirit by the 2026-09-18 pad
                               // redesign, see the collision note near
                               // heatsink() -- no longer a slot, a standoff gap)

// ===========================================================================
// Modules
// ===========================================================================

// Tube segment (hollow cylinder) -- the electronics bay only, not the full staff.
module tube_segment() {
    difference() {
        cylinder(h = bay_length, d = tube_od);
        translate([0, 0, -eps])
            cylinder(h = bay_length + 2 * eps, d = tube_id);
    }
}

// PCB, shown as a simple slab (real board outline is a separate BOM/layout
// task -- this is a placement/clearance check, not a fabrication drawing).
// Centered on the tube's own axis (both in X and Y) so its plane coincides
// with the heatsink hub's plane below -- the two are meant to be
// thermally bonded face-to-face, not physically separated across the
// tube's cross-section. Only the axial position (Z) varies along the bay.
module board() {
    translate([-board_width / 2, -board_thickness / 2, (bay_length - board_length) / 2])
        cube([board_width, board_thickness, board_length]);
}

// ===========================================================================
// Collision fix, pass 2 (2026-09-18 trial-assembly pass, part B) --
// OPENSCAD_DFM_PROTOCOL.md step 2 run against the REAL combined
// electronics stack this time, not just this file's own abstract
// board() placeholder. Method: `use <z_axis_stack.scad>` +
// `use <tube_enclosure_heatsink.scad>` in a scratch file, wrap
// base_plate()+standoff()x4+swappable_sled() in one module transformed
// by the coordinate map derived below, then
//   intersection() { electronics_stack(); translate([0,0,bay_length/2]) heatsink(); }
// The centered-disc-with-slot heatsink from pass 1 (see git history)
// rendered non-empty here (44 vertices, 4 volumes) even after clearing
// board()'s own bare slab -- because the *real* stack is not a bare
// slab. z_axis_stack.scad's standoffs (15mm tall) and swappable_sled
// (40mm wide) extend well past the board's own 1.6mm thickness on one
// side only (the M2-standoff/sled side), and a slot sized for the bare
// board doesn't clear them.
//
// Coordinate mapping used to place the real stack in this file's frame
// (board_width=50/board_length=70 identical to z_axis_stack.scad's
// base_width/base_length by construction -- see this file's own header
// comment): z_axis_stack.scad's local frame is (X=width, Y=length,
// Z=height-above-plate). `rotate([90,0,0])` sends local (x,y,z) to
// (x,-z,y); the subsequent `translate([-25,0.8,40])` centers X on the
// tube axis, aligns local Z=0 (base_plate's underside) with this file's
// board()-top face at y=+0.8 (board_thickness/2), and picks bay_length/2
// for the Z position. Net result, confirmed by the bbox math below and
// by Check A (electronics_stack() vs the tube WALL -- empty, no
// interference there): the entire real stack -- base_plate, standoffs,
// sled -- occupies y in [-19.2, +0.8] in this file's frame. Nothing
// about it ever crosses y = +0.8 in the +Y direction; only the bare
// board's opposite face does.
//
// 1. Критика и анализ (DFM/DFA)
// - Слабое место: диск-ступица, отцентрованная на оси платы, требует
//   паза, охватывающего САМУЮ ШИРОКУЮ деталь стека по обе стороны --
//   40мм салазки и 15мм стойки с одной стороны платы. Такой паз занял
//   бы весь диск, оставив от "радиатора" почти ничего. Диагноз в корне
//   неверный: сама идея паза-сквозь-центр предполагает, что деталь
//   тонкая и симметричная, а реальный стек асимметричен -- вся
//   электроника (стойки, салазки) лежит по ОДНУ сторону платы (-Y),
//   противоположная сторона (+Y, "тыльная" сторона платы) весь путь до
//   стенки трубы физически пуста.
//
// 2. Улучшенная архитектура
// Вместо диска, охватывающего плату со всех сторон, радиатор становится
// накладкой (pad), прижатой только к свободной (+Y) стороне платы --
// как в реальных клэмп-радиаторах, которые крепятся к одной открытой
// стороне PCB, а не пытаются охватить компоненты на обеих сторонах.
// Рёбра (fins) идут от накладки прямо к стенке трубы вдоль оси Y --
// не радиально из общего центра, а параллельно друг другу, с длиной,
// рассчитанной по хорде окружности трубы в точке X каждого ребра
// (`sqrt((tube_id/2)^2 - x^2)`), чтобы ни одно ребро не проткнуло
// стенку на кромке платы, где хорда короче, чем на оси.
module heatsink() {
    pad_gap = hub_slot_clearance;      // clearance off the board's bare face
    pad_thickness = hub_thickness;     // reuse the same thermal-contact block height
    pad_y0 = board_thickness / 2 + pad_gap;
    // How far the pad itself extends in +Y before the fins take over.
    // Deliberately well short of hub_diameter (30mm): a pad reaching all
    // the way out to hub_diameter left ~0mm of fin length at the pad's
    // own edge fins once the pad-corner fix (pass 3, below) shrank the
    // pad's half-width to keep it inside the tube -- verified by hand
    // arithmetic while diagnosing that fix, not by guessing a smaller
    // number. 15mm keeps every fin, including the outermost, at a real
    // positive length (>=8mm at the pad's own corner, more toward the
    // tube axis) against tube_id=70/hub_diameter=30.
    pad_reach = 15;

    // Collision fix, pass 3 (same trial-assembly pass, caught by
    // re-checking this module against the tube's own OUTER surface --
    // `intersection() { translate([0,0,bay_length/2]) heatsink();
    // <tube_od-radius cylinder shell>; }`, a check pass 2 never ran
    // because it only verified against board()/electronics_stack(),
    // not the tube itself): a pad spanning the full board_width (50mm)
    // out to y=hub_diameter (30mm) puts its far corners at
    // sqrt(25^2+30^2) ~= 39.1mm from the tube axis -- outside even the
    // tube's OUTER radius (38mm), let alone the inner wall. A flat
    // rectangular pad's corners are always farther from center than its
    // edge midpoints, so sizing it only against the on-axis chord (as
    // the fins already correctly did) under-constrains a rectangle.
    // Fix: clamp the pad's half-width to the tube ID circle at its own
    // Y-reach (`sqrt((tube_id/2)^2 - pad_reach^2)`) instead of reusing
    // board_width, and keep pad_reach itself well inside hub_diameter
    // so there is still real fin length left between the pad and the
    // wall (a pad reaching all the way to hub_diameter would leave the
    // fins at ~0mm length at the board edges -- see the arithmetic in
    // the commit that introduced this fix).
    pad_half_width = min(
        board_width / 2,
        sqrt(pow(tube_id / 2, 2) - pow(pad_reach, 2)) - petal_fit_clearance
    );

    // Pad: a slab against the board's +Y (bare) face -- thermally bonded
    // there per this file's header architecture note (hub <-> HackRF
    // backing plate), never touching the -Y (standoff/sled) side.
    translate([-pad_half_width, pad_y0, -pad_thickness / 2])
        cube([2 * pad_half_width, pad_reach, pad_thickness]);

    // Fins: parallel blocks running further in +Y from the pad's outer
    // face to just short of the tube's inner wall at each fin's own X
    // position -- never radial, so they can never sweep back across
    // the board's plane the way the old petal(angle) pattern did. Each
    // fin's own length is clamped by the tube ID chord at its X
    // position (not just the pad's), so an edge fin is naturally
    // shorter than a center one -- no separate corner check needed
    // here since a 1D line (the fin's centerline) has no "corner" to
    // exceed the radius at, unlike the pad's 2D rectangle above.
    fin_y0 = pad_y0 + pad_reach;
    for (i = [0 : petal_count - 1]) {
        fin_x = -pad_half_width + 2 * pad_half_width * (i + 0.5) / petal_count;
        fin_y_max = sqrt(pow(tube_id / 2, 2) - pow(fin_x, 2)) - petal_fit_clearance;
        translate([fin_x - petal_width / 2, fin_y0 - eps, -petal_thickness / 2])
            cube([
                petal_width,
                fin_y_max - fin_y0 + eps,
                petal_thickness,
            ]);
    }
}

// Full assembly: tube + board + heatsink, positioned to visually verify
// clearances before committing to real material/fab decisions (DFM step 2).
// The heatsink sits at the board's mid-length, directly at the HackRF
// module's location, extending from the board's bare (+Y) face out to
// the tube's inner wall -- an asymmetric pad+fin bridge, not a disc
// centered on the tube axis (see heatsink()'s own 2026-09-18 comment for
// why the on-axis disc was abandoned), but still the same conductive
// path THERMAL_BUDGET.md §4 costs at ΔT ≈ 5°C for 6.1W.
module assembly() {
    color("silver", 0.35)
        tube_segment();

    color("green")
        board();

    translate([0, 0, bay_length / 2])
        color("orange")
        heatsink();
}

// Documentation/DFM-review render only: this repo's software PNG export
// doesn't composite color()'s alpha channel, so a solid tube wall hides
// the board+heatsink entirely from any outside camera angle. Cutting
// away the near half (X > 0) makes the internal layout actually visible
// in a rendered image -- the real (uncut) part is `assembly()` above;
// this wrapper changes nothing about the modeled geometry itself.
// Default false (real, uncut geometry); override with `-D section_view=true`
// to render the longitudinal cutaway, or `-D cross_section_view=true` for a
// thin Z-slab straight down the tube axis (the clearest view of diameter +
// petal layout, the actual "чертеж" this file exists to produce).
section_view = false;
cross_section_view = false;

if (cross_section_view) {
    slab = 5;
    intersection() {
        assembly();
        translate([-tube_od, -tube_od, bay_length / 2 - slab / 2])
            cube([2 * tube_od, 2 * tube_od, slab]);
    }
} else if (section_view) {
    difference() {
        assembly();
        translate([0, -tube_od, -eps])
            cube([tube_od, 2 * tube_od, bay_length + 2 * eps]);
    }
} else {
    assembly();
}
