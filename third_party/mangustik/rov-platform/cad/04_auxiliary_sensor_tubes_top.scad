// ============================================================================
// DiveGuard heavy-class ROV - rov-platform/HLD.md
// 04_Auxiliary_Sensor_Tubes_Top - hydrophone preamp / DiveGuard acoustic front-end housing
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
// part is fabricated from it. Houses the analog front end feeding diveguard/hydrophone_module's DSP core.
// ============================================================================

// ==========================================
// DIVEGUARD: Auxiliary Sensor Tubes Top (04)
// Material: Anodized Aluminum (Blue), Ø100x400mm
// Purpose: Hydrophone & Telemetry Housing
// ==========================================

$fn = 90;

module auxiliary_sensor_tube() {
    // 1. Основной цилиндрический корпус вспомогательного модуля
    color("RoyalBlue")
    difference() {
        cylinder(h = 400, r = 50, center = false);
        translate([0, 0, -1])
            cylinder(h = 402, r = 44, center = false); // Стенка 6 мм
    }

    // 2. Передняя герметичная крышка с посадочным фланцем
    color("Silver")
    translate([0, 0, -20]) {
        cylinder(h = 20, r = 49.7, center = false);
        translate([0, 0, 20])
            cylinder(h = 10, r = 43.8, center = false);
    }

    // 3. Задняя крышка с гермовводами для акустических датчиков
    color("Silver")
    translate([0, 0, 400]) {
        difference() {
            cylinder(h = 20, r = 49.7, center = false);
            // Центральный порт под гидрофонный кабель (например, Mogami / SubConn)[cite: 5]
            translate([0, 0, -1])
                cylinder(h = 25, r = 8);
        }
    }

    // 4. Внутренняя монтажная плата под малошумящий буфер (OPA1642)[cite: 5]
    color("DarkSlateGray")
    translate([0, 0, 20])
        cube([60, 15, 360], center = true);
}

auxiliary_sensor_tube();

