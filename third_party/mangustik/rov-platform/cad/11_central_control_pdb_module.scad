// ============================================================================
// DiveGuard heavy-class ROV - rov-platform/HLD.md
// Central Control & PDB Module - power distribution + hydrophone buffer interconnect (Phase 2)
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
// part is fabricated from it. Physically mounts between hulls 02/03 per HLD.md Phase 2.
// ============================================================================

// ==========================================
// DIVEGUARD: Central Control & PDB Module
// Material: Anodized Al6061 / Polycarbonate Lid
// ==========================================

$fn = 60;

module central_control_unit() {
    // 1. Алюминиевое шасси блока
    color("DimGray")
    difference() {
        cube([180, 140, 60], center = true);
        // Внутреннее пространство для плат
        translate([0, 0, 5])
            cube([164, 124, 52], center = true);
    }

    // 2. Прозрачная крышка из поликарбоната
    color("Cyan", 0.4)
    translate([0, 0, 32])
        cube([180, 140, 4], center = true);

    // 3. Плата распределения питания (PDB) внутри
    color("Green")
    translate([0, 0, 0])
        cube([150, 110, 3], center = true);

    // 4. Силовые клеммники M4
    color("Gold") {
        translate([-60, -50, 15]) cylinder(h=15, r=3, center=true);
        translate([-60, -35, 15]) cylinder(h=15, r=3, center=true);
        translate([60, -50, 15]) cylinder(h=15, r=3, center=true);
    }
}

central_control_unit();

