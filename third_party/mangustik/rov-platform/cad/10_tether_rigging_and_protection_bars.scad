// ============================================================================
// DiveGuard heavy-class ROV - rov-platform/HLD.md
// 10_Tether_Rigging_and_Protection_Bars - umbilical strain relief + lifting eyes
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
// DIVEGUARD: Tether, Rigging & Protection (10)
// Material: Stainless Steel 316L / Polyurethane
// Assembly Standard: M12 Lifting Eyes, PG-29 Cable Gland
// ==========================================

$fn = 90;

module tether_and_rigging_assembly() {
    // 1. Кормовая силовая пластина крепления кабельного ввода
    color("LightSteelBlue")
    translate([-550, 0, 0])
        cube([12, 180, 80], center = true);

    // 2. Центральный герметичный кабельный ввод (узел разгрузки натяжения умбиликуса)
    color("DarkSlateGray")
    translate([-550, 0, 0])
        rotate([0, 90, 0])
        cylinder(h = 40, r = 18, center = true);

    // Умбиликус (хвостовик кабеля со стандартным радиусом изгиба)
    color("Black")
    translate([-580, 0, 0])
        rotate([0, 90, 0])
        cylinder(h = 100, r = 10, center = true);

    // 3. Защитные кормовые дуги бампера (труба Ø25 мм)
    color("Silver") {
        // Верхняя защитная дуга
        translate([-560, 0, 45])
            rotate([0, 90, 0])
            cylinder(h = 30, r = 12.5, center = true);
        // Нижняя защитная дуга
        translate([-560, 0, -45])
            rotate([0, 90, 0])
            cylinder(h = 30, r = 12.5, center = true);
    }

    // 4. Такелажные рым-болты M12 (точки подъема аппарата)
    color("DimGray") {
        // Левый задний рым-болт
        translate([-530, -320, 150]) {
            cylinder(h = 30, r = 6, center = true); // Резьбовая часть M12
            translate([0, 0, 20])
                torus(r1=15, r2=4); // Кольцо рым-болта
        }
        // Правый задний рым-болт
        translate([-530, 320, 150]) {
            cylinder(h = 30, r = 6, center = true);
            translate([0, 0, 20])
                torus(r1=15, r2=4);
        }
    }
}

// Вспомогательный модуль для торуса (кольца рым-болта)
module torus(r1, r2) {
    rotate_extrude(convexity = 10)
        translate([r1, 0, 0])
        circle(r = r2);
}

tether_and_rigging_assembly();

