// ============================================================================
// DiveGuard heavy-class ROV - rov-platform/HLD.md
// 06_Propulsion_Vertical_Module - depth/trim/strafe thrusters
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
// DIVEGUARD: Propulsion Vertical Module (06)
// Material: Anodized Aluminum / POM-C
// Component: Vertical Thruster Pod & Deck Flange
// ==========================================

$fn = 90;

module vertical_thruster_module() {
    // 1. Верхний монтажный палубный фланец (прижимная пластина)
    color("Silver")
    translate([0, 0, 45])
        cube([90, 90, 10], center = true);

    // 2. Вертикальная цилиндрическая гильза мотора
    color("DarkGray")
    cylinder(h = 80, r = 25, center = true);

    // 3. Кольцевой защитный кожух вертикального винта (интегрирован в палубу)
    color("MidnightBlue")
    difference() {
        translate([0, 0, -20])
            cylinder(h = 60, r = 52, center = true);
        translate([0, 0, -20])
            cylinder(h = 62, r = 46, center = true);
    }

    // 4. Лопастной узел вертикального гребного винта
    color("Gold")
    translate([0, 0, -25])
    intersection() {
        cylinder(h = 12, r = 45, center = true);
        union() {
            for (i = [0 : 2]) {
                rotate([0, 0, i * 120])
                cube([80, 10, 10], center = true);
            }
        }
    }
}

vertical_thruster_module();

