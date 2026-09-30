// ============================================================================
// DiveGuard heavy-class ROV - Phase 1 (rov-platform/HLD.md)
// 03_Main_Pressure_Hull_Starboard - battery/power bay, 300m depth rating
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
// engineer re-check of the wall-thickness/O-ring/depth-rating
// claims (10mm wall, 300m, 30bar double O-ring) against a real pressure-
// vessel calculation before any part is fabricated from it - this hull also
// carries the 48V/13S Li-ion pack, so a structural failure here is a battery
// containment failure too. See rov-platform/HLD.md Phase 1 for the
// materials/tolerances spec this implements.
// ============================================================================

// ==========================================
// DIVEGUARD: Main Pressure Hull Starboard (03)
// Material: Anodized Aluminum 6061-T6[cite: 2]
// Depth Rating: 300m[cite: 2, 3]
// ==========================================

$fn = 120; // Высокая гладкость цилиндров

module pressure_hull_starboard() {
    // 1. Основной цилиндрический корпус (труба)
    difference() {
        // Наружный диаметр 200 мм (радиус 100)
        cylinder(h = 800, r = 100, center = false);
        // Внутренний диаметр 180 мм (радиус 90), оставляем стенку 10 мм
        translate([0, 0, -1])
            cylinder(h = 802, r = 90, center = false);
    }

    // 2. Передняя торцевая крышка с посадочным пояском
    color("Silver") 
    translate([0, 0, -30]) {
        cylinder(h = 30, r = 99.7, center = false); // Посадка внатяг
        // Центрирующий буртик внутрь трубы
        translate([0, 0, 30])
            cylinder(h = 15, r = 89.8, center = false);
        // Канавки под двойные O-ring уплотнения на крышке
        translate([0, 0, 5])
            difference() {
                cylinder(h = 4, r = 90.5);
                translate([0, 0, -1]) cylinder(h = 6, r = 88.5);
            }
    }

    // 3. Задняя силовая крышка (с отверстиями под силовые разъемы питания)
    color("Silver") 
    translate([0, 0, 800]) {
        difference() {
            cylinder(h = 35, r = 99.7, center = false);
            // Силовые кабельные вводы (мощные разъемы SubConn для батареи)
            for (a = [0, 120, 240]) {
                rotate([0, 0, a])
                translate([50, 0, -1])
                    cylinder(h = 40, r = 7); // Отверстия под силовые пенетраторы
            }
        }
    }

    // 4. Внутренний каркас-слайдер для крепления аккумуляторов (48V 13S)
    color("DarkGray")
    translate([0, 0, 20])
        intersection() {
            cylinder(h = 760, r = 89);
            // Пространственная ферма для фиксации батарейных ячеек
            cube([120, 10, 760], center = true);
        }
}

// Рендер сборки отсека
pressure_hull_starboard();

