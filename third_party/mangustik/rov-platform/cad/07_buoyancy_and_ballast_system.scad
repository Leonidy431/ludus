// ============================================================================
// DiveGuard heavy-class ROV - rov-platform/HLD.md
// 07_Buoyancy_and_Ballast_System - syntactic foam trim/lift
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
// part is fabricated from it. Phase 4 DoD requires re-sizing this against Phases 1-3+5-6's real dry mass - the dimensions here are the source dialogue's first guess, not a computed buoyancy budget (see HLD.md Phase 4).
// ============================================================================

// ==========================================
// DIVEGUARD: Buoyancy and Ballast System (07)
// Material: Syntactic Foam in HDPE Shell (Yellow)
// Component: Cylindrical Buoyancy Pods (Ø110mm)
// ==========================================

$fn = 90;

module buoyancy_module() {
    // 1. Центральный цилиндрический корпус блока плавучести
    color("Gold")
    cylinder(h = 900, r = 55, center = true);

    // 2. Передний носовой обтекатель (конус)
    color("Gold")
    translate([0, 0, 450])
        cylinder(h = 80, r1 = 55, r2 = 20);

    // 3. Задний хвостовой обтекатель (конус)
    color("Gold")
    translate([0, 0, -530])
        cylinder(h = 80, r1 = 20, r2 = 55);

    // 4. Силовые крепежные хомуты для монтажа к раме (Файл 01)
    color("Silver") {
        translate([0, 0, 300])
            cylinder(h = 15, r = 58, center = true);
        translate([0, 0, -300])
            cylinder(h = 15, r = 58, center = true);
    }
}

buoyancy_module();

