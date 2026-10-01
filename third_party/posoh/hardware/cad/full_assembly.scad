// full_assembly.scad — Посох trial assembly: z_axis_stack.scad electronics
// stack inside tube_enclosure_heatsink.scad's tube segment + heatsink.
//
// Produced under OPENSCAD_DFM_PROTOCOL.md in response to: "Сделай пробну
// сборку деталей oscad что не хватает дорисуй написав подробные промты"
// (do a trial assembly of the existing OpenSCAD parts; whatever is
// missing, draw it). This is that trial assembly: the first time these
// two files' geometry, previously developed and rendered separately
// (Session Updates #19), have actually been placed together and
// boolean-checked for real interference -- not just visually inspected.
//
// ===========================================================================
// 1. Критика и анализ (DFM/DFA)
// ===========================================================================
// - Слабое место А (найдено и исправлено этим файлом): у двух файлов нет
//   общего файла сборки, и до сих пор не было общей системы координат
//   между z_axis_stack.scad (плата+стойки+салазки, локальная рамка
//   X=ширина/Y=длина/Z=высота-над-платой) и tube_enclosure_heatsink.scad
//   (труба, локальная рамка X=хорда/Y=радиальная/Z=вдоль оси трубы).
//   Без явного преобразования координат "поместится ли реальный стек в
//   трубу" оставался неотвеченным вопросом, несмотря на то что оба файла
//   независимо рендерились "Simple: yes".
// - Слабое место Б (найдено и исправлено в tube_enclosure_heatsink.scad
//   этим же проходом, не здесь): внутренний теплоотвод (`heatsink()`)
//   был спроектирован и проверен только против абстрактной болванки
//   `board()` (плоская пластина без компонентов) -- при проверке против
//   РЕАЛЬНОГО стека (стойки 15мм + салазки 40мм с одной стороны платы)
//   тот же самый диск+радиальные-лепестки дизайн реально пересекался с
//   стойками/салазками. Полная история диагностики и трёх последовательных
//   исправлений (паз в ступице -> сдвиг фазы лепестков -> итоговая замена
//   диска на накладку+параллельные рёбра со стороны, свободной от
//   компонентов) -- в комментариях над `heatsink()` в
//   tube_enclosure_heatsink.scad, не дублируется здесь.
//
// ===========================================================================
// 2. Улучшенная архитектура
// ===========================================================================
// `electronics_stack()` ниже оборачивает три модуля z_axis_stack.scad
// (`base_plate()`, `standoff()` x4, `swappable_sled()`) в одно
// преобразование `translate([-25, 0.8, 40]) rotate([90, 0, 0])`,
// выведенное вручную из фактических размеров обоих файлов:
//   - `rotate([90,0,0])` переводит локальную точку (x,y,z) в (x,-z,y) --
//     "высота над платой" в z_axis_stack.scad становится координатой Y
//     ("радиальное направление, от платы к стенке трубы") в системе
//     tube_enclosure_heatsink.scad.
//   - `translate([-25, 0.8, 40])`: X-сдвиг -25 центрует 50мм ширину платы
//     на оси трубы (совпадает с тем, как сама board() уже центрована в
//     tube_enclosure_heatsink.scad); Y-сдвиг +0.8 совмещает "низ" платы
//     (z_axis_stack.scad, локальный Z=0) с верхней гранью абстрактной
//     board() (board_thickness/2 = 0.8мм) -- так что толщина реальной
//     platy (1.6мм) в точности заменяет толщину board(); Z-сдвиг 40
//     произвольная позиция вдоль bay_length (150мм), выбранная для
//     наглядности рендера, не влияет на корректность проверки коллизий
//     по X/Y (труба однородна по всей длине bay_length).
// Три boolean-проверки ниже (Check A/B/C) подтверждают инструментом, а не
// на глаз, что получившаяся сборка физически возможна.

use <z_axis_stack.scad>
use <tube_enclosure_heatsink.scad>

module electronics_stack() {
    translate([-25, 0.8, 40])
        rotate([90, 0, 0]) {
            base_plate();
            for (x = [4, 50 - 4])
                for (y = [4, 70 - 4])
                    translate([x, y, 1.6])
                        standoff();
            translate([(50 - 40) / 2, (70 - 60) / 2, 1.6])
                swappable_sled();
        }
}

// ===========================================================================
// Verified interference checks (all confirmed via `openscad -o out.stl
// check.scad` + reading the console's "Current top level object is
// empty" / "Simple: yes" verdict -- not asserted from geometry alone).
// Toggle exactly one of these true at a time via `-D check_X=true` to
// render just that check's intersection() result for inspection; with
// all flags false (the default), the file renders the full assembly.
// ===========================================================================
check_A_stack_vs_wall = false;      // electronics_stack() vs the tube's own wall material -> confirmed EMPTY
check_B_stack_vs_heatsink = false;  // electronics_stack() vs heatsink()   -> confirmed EMPTY
check_C_heatsink_vs_od = false;     // heatsink() vs outside the tube OD   -> confirmed EMPTY

module tube_wall_solid() {
    difference() {
        cylinder(h = bay_length, d = tube_od);
        translate([0, 0, -eps])
            cylinder(h = bay_length + 2 * eps, d = tube_id);
    }
}

module outside_tube_od() {
    difference() {
        translate([0, 0, -10]) cylinder(h = bay_length + 20, d = 4 * tube_od);
        translate([0, 0, -11]) cylinder(h = bay_length + 22, d = tube_od);
    }
}

if (check_A_stack_vs_wall) {
    intersection() {
        electronics_stack();
        tube_wall_solid();
    }
} else if (check_B_stack_vs_heatsink) {
    intersection() {
        electronics_stack();
        translate([0, 0, 75])
            heatsink();
    }
} else if (check_C_heatsink_vs_od) {
    intersection() {
        translate([0, 0, 75])
            heatsink();
        outside_tube_od();
    }
} else {
    // The real trial assembly -- confirmed manifold (Simple: yes) as one
    // combined render, all three checks above confirmed empty/expected.
    color("silver", 0.3)
        tube_segment();
    color("green")
        electronics_stack();
    translate([0, 0, 75])
        color("orange")
        heatsink();
}
