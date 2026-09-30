// ============================================================================
// DiveGuard heavy-class ROV - rov-platform/HLD.md
// 09_Manipulator_and_Tool_Interface - tool-flange mounting plate
//
// Lifted from the design dialogue originally pasted into BACKLOG.md on main
// (2026-08 batch), preserved verbatim as authored there.
//
// Update 2026-08-08: OpenSCAD IS available in this sandbox (installed via apt
// for this verification pass - previously assumed unavailable; that
// assumption was wrong, corrected repo-wide, see BACKLOG.md). This file has
// been rendered (`openscad -o out.stl this.scad`) and confirmed a valid
// 2-manifold solid ("Simple: yes" in the render log) - real geometric
// validity, not just a paren-balance check. STEP export and an independent
// engineer re-check of dimension/tolerance claims before any
// part is fabricated from it.
// ============================================================================

// ==========================================
// DIVEGUARD: Manipulator & Tool Interface (09)
// Material: Anodized Aluminum 6061-T6, Thickness: 15mm
// Assembly Standard: Metric ISO (M8 frame mounts, M6 tool flange)
// ==========================================

$fn = 100;

module manipulator_interface_plate() {
    // 1. Основная силовая монтажная плита (220 x 160 x 15 мм)
    color("LightSteelBlue")
    difference() {
        cube([220, 160, 15], center = true);

        // --- УЗЛЫ КРЕПЛЕНИЯ К СИЛОВОЙ РАМЕ (Файл 01) ---
        // 4 угловых отверстия под болты M8 (диаметр сквозного отверстия 8.4 мм)
        for (x = [-90, 90]) {
            for (y = [-60, 60]) {
                translate([x, y, 0])
                    cylinder(h = 20, r = 4.2, center = true);
                // Цековка под головку болта M8
                translate([x, y, 4])
                    cylinder(h = 10, r = 7.5, center = true);
            }
        }

        // --- БАЗОВЫЕ ШТИФТЫ ДЛЯ ТОЧНОЙ СБОРКИ ---
        // Два штифтовых отверстия Ø6 H7
        translate([-50, 0, 0])
            cylinder(h = 20, r = 3.0, center = true);
        translate([50, 0, 0])
            cylinder(h = 20, r = 3.0, center = true);

        // --- ЦЕНТРАЛЬНЫЙ ТЕХНОЛОГИЧЕСКИЙ КАНАЛ ---
        // Отверстие Ø30 мм под проход кабелей / гидравлики
        cylinder(h = 20, r = 15, center = true);

        // --- ФЛАНЕЦ КРЕПЛЕНИЯ МАНИПУЛЯТОРА ---
        // 6 крепежных отверстий M6 на окружности PCD Ø90 мм
        for (i = [0 : 5]) {
            rotate([0, 0, i * 60])
            translate([45, 0, 0])
                cylinder(h = 20, r = 3.2, center = true);
        }
    }

    // 2. Усиливающие ребра жесткости (интегрированные бобышки)
    color("Silver") {
        translate([0, 72, 0])
            cube([200, 12, 15], center = true);
        translate([0, -72, 0])
            cube([200, 12, 15], center = true);
    }
}

manipulator_interface_plate();

