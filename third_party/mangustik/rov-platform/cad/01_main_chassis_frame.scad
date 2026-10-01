// ============================================================================
// DiveGuard heavy-class ROV - Phase 1 (rov-platform/HLD.md)
// 01_Main_Chassis_Frame - power/structural frame
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
// engineer re-check of wall-thickness/dimension claims before
// any part is fabricated from it. See rov-platform/HLD.md Phase 1 for the
// materials/tolerances spec this implements.
// ============================================================================

// ==========================================
// DIVEGUARD: Main Chassis Frame (01)
// Material: Stainless Steel 316L, Ø38x2 mm
// Dimensions: 1200 x 800 x 500 mm
// ==========================================

$fn = 60;

// Модуль для построения сварной трубы между двумя точками
module tube(p1, p2, r=19) {
    hull() {
        translate(p1) sphere(r);
        translate(p2) sphere(r);
    }
}

module chassis_frame() {
    // 1. Нижний периметр (полозья / скиды рамы)
    color("DimGray") {
        // Продольные трубы
        tube([-600, -400, -250], [600, -400, -250], 19);
        tube([-600, 400, -250], [600, 400, -250], 19);
        // Поперечные трубы основания
        tube([-600, -400, -250], [-600, 400, -250], 19);
        tube([600, -400, -250], [600, 400, -250], 19);
    }
    
    // 2. Верхний силовой периметр (палуба установки корпусов)
    color("Silver") {
        tube([-550, -350, 150], [550, -350, 150], 19);
        tube([-550, 350, 150], [550, 350, 150], 19);
        tube([-550, -350, 150], [-550, 350, 150], 19);
        tube([550, -350, 150], [550, 350, 150], 19);
    }
    
    // 3. Наклонные силовые стойки (HARDWARE_AUDIT_2026-08-28 #16: раньше
    // стойки стояли на (±550,±350) и висели в 50 мм от нижнего периметра
    // (±600,±400) — рама распадалась на 4 несвязанных тела, render
    // подтверждал Volumes: 5. Теперь каждая стойка идёт от угла нижнего
    // периметра к углу верхнего — слегка наклонная распорка, связывающая
    // оба контура в одно сварное тело.)
    color("DarkGray") {
        tube([-600, -400, -250], [-550, -350, 150], 19);
        tube([600, -400, -250], [550, -350, 150], 19);
        tube([-600, 400, -250], [-550, 350, 150], 19);
        tube([600, 400, -250], [550, 350, 150], 19);
    }

    // 4. Интегрированные монтажные рельсы под гермобоксы (Файлы 02 и 03)
    // Аудит #16(b): рельсы удлинены с 1000 до 1140 мм, чтобы их концы
    // реально перекрывали поперечные трубы верхнего периметра на x=±550
    // (раньше они обрывались на x=±500 и висели в воздухе).
    color("SteelBlue") {
        translate([0, -100, 150]) cube([1140, 30, 12], center=true);
        translate([0, 100, 150]) cube([1140, 30, 12], center=true);
    }
}

chassis_frame();

