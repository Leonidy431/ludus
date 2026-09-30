// ============================================================================
// DiveGuard heavy-class ROV - rov-platform/HLD.md
// 05_Propulsion_Horizontal_Module - ducted marine/turn thrusters
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
// DIVEGUARD: Propulsion Horizontal Module (05)
// Material: POM-C / Anodized Aluminum
// Component: Ducted Thruster Pod (Ø100mm)
// ==========================================

$fn = 100;

module horizontal_thruster_module() {
    // 1. Кольцевая насадка (дута) с профилем канала
    color("MidnightBlue")
    difference() {
        // Внешний контур насадки с утолщением в центральной части
        cylinder(h = 120, r = 58, center = true);
        // Внутренний гидродинамический канал (сужение/диффузор)
        translate([0, 0, -61])
            cylinder(h = 122, r1 = 48, r2 = 52); // Профиль конфузор-диффузор
    }

    // 2. Центральный гермомоторный подмюл (гильза статора)
    color("DarkGray")
    cylinder(h = 90, r = 25, center = true);

    // 3. Обтекаемые аэродинамические стойки крепления мотора к насадке (3 шт)
    color("Silver")
    for (a = [0, 120, 240]) {
        rotate([0, 0, a])
        translate([36, 0, 0])
            cube([24, 8, 80], center = true);
    }

    // 4. Гребной винт (упрощенная параметрическая модель 4-лопастного винта)
    color("Gold")
    translate([0, 0, 35])
    intersection() {
        cylinder(h = 15, r = 47, center = true);
        union() {
            for (i = [0 : 3]) {
                rotate([0, 0, i * 90 + 15])
                cube([85, 12, 12], center = true);
            }
        }
    }
}

horizontal_thruster_module();

