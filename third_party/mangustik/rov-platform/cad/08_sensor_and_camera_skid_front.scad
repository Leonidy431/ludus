// ============================================================================
// DiveGuard heavy-class ROV - rov-platform/HLD.md
// 08_Sensor_and_Camera_Skid_Front - HD camera + scanning sonar
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
// DIVEGUARD: Sensor and Camera Skid Front (08)
// Material: Anodized Aluminum / Polycarbonate
// Component: HD Camera Enclosure & Ping360 Sonar[cite: 4]
// ==========================================

$fn = 90;

module front_sensor_skid() {
    // 1. Центральный защитный кожух камеры и электроники (характерный яркий корпус)
    color("DarkOrange")
    translate([0, 0, 0])
        cube([160, 120, 100], center = true);

    // 2. Фронтальный оптический иллюминатор (акрил высокой прозрачности)
    color("Cyan", 0.6)
    translate([81, 0, 0])
        rotate([0, 90, 0])
        cylinder(h = 10, r = 40, center = true);

    // 3. Сканирующий круговой гидролокатор (например, Ping360 под модулем)[cite: 4]
    color("Black")
    translate([20, 0, -65])
        cylinder(h = 35, r = 38, center = true);

    // 4. Боковые кронштейны регулировки наклона и крепления к силовой раме (Файл 01)
    color("Silver") {
        translate([-70, -70, 0]) cube([20, 10, 90], center = true);
        translate([-70, 70, 0]) cube([20, 10, 90], center = true);
    }
}

front_sensor_skid();

