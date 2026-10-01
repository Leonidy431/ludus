// z_axis_stack.scad — Feature 1: Modular Z-axis stack (Посох)
//
// First parametric artifact produced under OPENSCAD_DFM_PROTOCOL.md
// (blind spot #85: the protocol had been "ACTIVE" for multiple sessions
// with zero .scad files and no numeric standoff spacing anywhere in the
// repo). Dimensions below are placeholder-but-real initial defaults
// (documented as such, not fabricated-as-final) pending real board
// layout — they are internally consistent and printable/computable, not
// aspirational numbers. No local OpenSCAD/CI renderer is available in
// this environment to confirm a render; geometry was hand-verified
// (rotation matrices, dimension budget) rather than assumed correct.
//
// This design also resolves blind spot #86: the only prior mechanical
// reference (HARDWARE_INTEGRATION.md's M2 nylon standoffs) is a
// threaded-fastener stack that directly contradicts Feature 1's own
// acceptance criterion ("swap HackRF/ultrasonic modules in <5 min
// without tools"). Per the DFM protocol's step 3 (minimize fasteners),
// the swappable RF/ultrasonic module rides on a tool-free dovetail rail
// instead of standoff screws; the fixed base stack (assembled once, not
// user-facing) keeps M2 standoffs since that part of the acceptance
// criterion was never about the structural base.
//
// ===========================================================================
// 1. Критика и анализ (DFM/DFA)
// ===========================================================================
// - Слабое место А: чистый M2-стек (4 винта на слой) для всей сборки
//   противоречит собственному критерию приёмки Feature 1 ("swap ... in
//   <5 min without tools") — снять винтоверткой один модуль занимает
//   больше времени и требует инструмент, которого явно не должно быть.
// - Слабое место Б: без зазора (clearance) между "ласточкиным хвостом"
//   модуля и пазом базовой платы паз будет либо не входить при печати
//   (усадка PLA/ABS), либо люфтить и терять контакт по Z. Нужна явная
//   переменная зазора, а не посадка "впритык".
// - Слабое место В (найдено при ручной проверке геометрии): сменный
//   модуль нельзя моделировать как голую PCB (1.6мм) — паз глубиной
//   rail_height+clearance физически не помещается в плату толщиной
//   1.6мм. Сменный элемент — это печатная 3D "сани" (sled), несущие
//   реальную PCB модуля сверху (крепление PCB — отдельная, вне рамок
//   этого файла задача), а не сама PCB.
//
// ===========================================================================
// 2. Улучшенная архитектура
// ===========================================================================
// Базовая плата (base_plate) остаётся на несъёмном M2-стойка-стеке
// (собирается один раз на заводе/при сборке — вне сферы действия
// критерия "без инструмента"). На верхней грани базовой платы — два
// параллельных рельса "ласточкин хвост" (dovetail), по которым
// печатные "сани" сменного RF/ultrasonic модуля (swappable_sled)
// задвигаются сбоку (вдоль Y) и удерживаются трением/фаской без единого
// винта. Толщина саней рассчитана так, чтобы паз (глубиной
// rail_height+clearance) оставлял минимум min_wall_above_groove
// материала над собой — не голая PCB-толщина "впритык".

// ===========================================================================
// Global parameters (all dimensions in mm)
// ===========================================================================
$fn = 48;
eps = 0.01;              // Small overlap to avoid z-fighting in difference()
clearance = 0.2;         // Standard fit clearance for all mating features

// Base plate (fixed, assembled once — carries the standoff stack)
base_width       = 50;
base_length      = 70;
base_thickness   = 1.6;  // Standard PCB thickness
corner_inset     = 4;    // Standoff hole center distance from each edge

// M2 nylon standoff stack (base plate <-> main control board, non-swap path)
standoff_height  = 15;   // Z-axis spacing between fixed layers
standoff_od      = 5;    // Nylon standoff outer diameter
standoff_hole_id = 2.2;  // M2 clearance hole (2mm screw + 0.2mm clearance)

// Dovetail rail (tool-free swap mechanism for HackRF/ultrasonic module)
rail_length      = 60;   // Runs along base_length; sled slides lengthwise
rail_top_width   = 6;    // Wide (outer) face of the trapezoid
rail_root_width  = 4;    // Narrow (root, at the base plate surface) face
rail_height      = 3;
rail_spacing     = 30;   // Center-to-center distance between the 2 rails

// Swappable module carrier ("sled" — 3D-printed, carries the module's
// real PCB on top via its own standoffs, out of scope here). Must be
// thick enough that the dovetail groove (depth rail_height+clearance)
// still leaves min_wall_above_groove of solid material above it.
min_wall_above_groove = 1.5;
sled_thickness   = rail_height + clearance + min_wall_above_groove;  // 4.7mm
sled_width       = 40;
sled_length       = rail_length;

// ===========================================================================
// Modules
// ===========================================================================

// A single trapezoidal dovetail rail. Cross-section (width x height) is
// extruded along local Z, then rotated so the extrusion instead runs
// along Y for `length`, protruding upward (+Z) from the surface it's
// placed on — verified via the standard X-axis rotation matrix
// (x,y,z) -> (x,-z,y) for +90°, then translated back into y>=0.
module dovetail_rail(length, top_w, root_w, height) {
    translate([0, length, 0])
        rotate([90, 0, 0])
            linear_extrude(height = length)
                polygon(points = [
                    [-root_w / 2, 0],
                    [root_w / 2, 0],
                    [top_w / 2, height],
                    [-top_w / 2, height],
                ]);
}

// Matching groove: the rail profile inflated by `clearance` on every
// mating face (DFM критика Б), open the full `length` (through-channel,
// so the sled can slide on/off from either end) and poking `eps` below
// the cut surface for a clean boolean (no coincident zero-thickness
// faces).
module dovetail_groove(length, top_w, root_w, height) {
    translate([0, length, 0])
        rotate([90, 0, 0])
            linear_extrude(height = length)
                polygon(points = [
                    [-(root_w / 2 + clearance), -eps],
                    [(root_w / 2 + clearance), -eps],
                    [(top_w / 2 + clearance), height + clearance],
                    [-(top_w / 2 + clearance), height + clearance],
                ]);
}

// M2 nylon standoff: outer cylinder with a through-hole for the screw.
module standoff(height = standoff_height, od = standoff_od, id = standoff_hole_id) {
    difference() {
        cylinder(h = height, d = od);
        translate([0, 0, -eps])
            cylinder(h = height + 2 * eps, d = id);
    }
}

// Base plate: fixed structural layer. Carries 4 corner standoff holes
// (M2, non-swap path) and 2 dovetail rails on its top face for the
// tool-free RF/ultrasonic module sled.
module base_plate() {
    difference() {
        union() {
            cube([base_width, base_length, base_thickness]);
            // Rails run along the plate's length, centered, spaced
            // `rail_spacing` apart across the width.
            for (dx = [-rail_spacing / 2, rail_spacing / 2])
                translate([base_width / 2 + dx, (base_length - rail_length) / 2, base_thickness])
                    dovetail_rail(rail_length, rail_top_width, rail_root_width, rail_height);
        }
        // 4 corner M2 clearance holes for the fixed standoff stack.
        for (x = [corner_inset, base_width - corner_inset])
            for (y = [corner_inset, base_length - corner_inset])
                translate([x, y, -eps])
                    cylinder(h = base_thickness + 2 * eps, d = standoff_hole_id);
    }
}

// Swappable module sled: matching dovetail grooves cut upward into its
// bottom face so it slides onto base_plate's rails without any
// fastener. The module's own PCB mounts on top of this sled (out of
// scope for this file).
module swappable_sled() {
    difference() {
        cube([sled_width, sled_length, sled_thickness]);
        for (dx = [-rail_spacing / 2, rail_spacing / 2])
            translate([sled_width / 2 + dx, 0, 0])
                dovetail_groove(sled_length, rail_top_width, rail_root_width, rail_height);
    }
}

// Full assembly: base plate + standoffs + swappable sled, positioned to
// visually verify fit/collisions before printing (DFM step 2). The
// sled's bottom face (its groove floor, z_local=0) sits exactly at the
// rail root height (base_thickness), so the rail's full height nests
// inside the groove with just `clearance` margin at the groove's top.
module assembly() {
    base_plate();

    for (x = [corner_inset, base_width - corner_inset])
        for (y = [corner_inset, base_length - corner_inset])
            translate([x, y, base_thickness])
                standoff();

    translate([(base_width - sled_width) / 2, (base_length - rail_length) / 2, base_thickness])
        color("orange")
        swappable_sled();
}

assembly();
