// ============================================================================
// DiveGuard heavy-class ROV - rov-platform/HLD.md
// Fasteners, Clamps & Dampers - pipe clamps, cable glands, sorbothane vibration isolators (Phase 6)
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
// part is fabricated from it. The sorbothane isolation washers here are the mechanical half of Phase 14's passive-hydrophone self-noise item (see HLD.md Phase 6).
// ============================================================================

// ==========================================
// DIVEGUARD: Fasteners, Clamps & Dampers
// Components: Pipe Clamps, Cable Glands, Sorbothane Dampers
// ==========================================

$fn = 80;

module small_parts_assembly() {
    // 1. Силовой хомут крепления главного гермобокса (Ø200 мм) к раме
    color("Silver")
    translate([0, 0, 0])
    difference() {
        cylinder(h = 25, r = 108, center = true);
        cylinder(h = 27, r = 100, center = true); // Посадочное под трубу Ø200
        // Ушки под стяжные болты M8
        translate([100, 0, 0]) cube([30, 20, 25], center = true);
    }

    // 2. Сорботановая виброизоляционная шайба (демпфер)
    color("Black")
    translate([250, 0, 0])
        cylinder(h = 8, r = 18, center = true);
    color("Silver")
    translate([250, 0, 0])
        cylinder(h = 10, r = 4.2, center = true); // Втулка под болт M8

    // 3. Кабельный гермоввод PG-9 (для датчиков)
    color("DarkSlateGray")
    translate([-250, 0, 0]) {
        cylinder(h = 15, r = 8, center = true);
        translate([0, 0, 10]) cylinder(h = 10, r = 11, center = true);
    }
}

small_parts_assembly();

