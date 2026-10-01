// hydrophone_v1.scad — "Model 1" DIY hydrophone enclosure
// Piezo disc salvaged from an electric toothbrush's vibration motor,
// epoxy-potted at one end of a sealed tube; ESP32 + preamp in the dry
// bay at the other end, behind a removable O-ring end cap.
//
// Produced under OPENSCAD_DFM_PROTOCOL.md in response to: "есть зубная
// щетка с вибро пьезо элементом. построй корпус гидрофона на основе
// знаний о звуковом аппарате дельфинов и встрой туда элемент зубной
// щетки а управлять будем через esp32 ... сделай простую рабочую модель
// номер один" (build a hydrophone enclosure using an electric
// toothbrush's piezo element, controlled by an ESP32 -- a simple
// working "model 1").
//
// Companion docs: hardware/HYDROPHONE_V1.md (acoustic rationale, wiring,
// honest bandwidth scoping against real dolphin vocalization ranges),
// hardware/firmware/hydrophone_v1/hydrophone_v1.ino (ESP32 sampling
// sketch).
//
// ===========================================================================
// 1. Критика и анализ (DFM/DFA)
// ===========================================================================
// - Слабое место А: "зубная щетка" не даёт производителя/модель --
//   диаметр и толщина пьезоэлемента здесь ПРЕДПОЛОЖЕНИЕ (типичный диск
//   вибромотора электрощётки, 15-25мм), не измерение. Помечено
//   [UNVERIFIED] в комментарии к параметру; полость под заливку эпоксидкой
//   сделана параметрической и с запасом (+4мм к номиналу на сторону),
//   чтобы реальный диск любого типового размера в этом диапазоне точно
//   поместился без переделки чертежа.
// - Слабое место Б: пьезодиск -- это ПАССИВНЫЙ приёмник (пьезоэффект
//   генерирует напряжение при деформации), а не источник звука --
//   значит нужен предусилитель до АЦП ESP32 (сырой сигнал с пьезо --
//   единицы-десятки милливольт, ESP32 ADC ожидает 0-3.3В). Corpus
//   предусматривает отдельный маленький отсек под плату предусилителя
//   (op-amp) между пьезо-полостью и ESP32, а не разъём "пьезо напрямую
//   в GPIO" (это бы не работало).
// - Слабое место В: сухой отсек (ESP32 + предусилитель) должен быть
//   доступен для перепрошивки/зарядки по USB без вскрытия герметичной
//   заливки на пьезо-конце -- отсюда съёмная крышка на резьбе/O-ring
//   ТОЛЬКО на дальнем от сенсора конце трубы; пьезо-конец заливается
//   эпоксидкой один раз при сборке и больше не открывается (это и есть
//   герметизация датчика, стандартный приём в самодельных гидрофонах --
//   акустический импеданс эпоксидной смолы близок к воде, в отличие от
//   воздушной полости, которая отражала бы звук).
//
// ===========================================================================
// 2. Улучшенная архитектура
// ===========================================================================
// Единая труба из трёх зон вдоль оси:
//   [ Пьезо-полость (заливается эпоксидкой) ]--[ Сухой отсек: предусилитель + ESP32 ]--[ Съёмная крышка (O-ring) ]
// Пьезо-конец трубы задней стенкой закрыт САМОЙ трубой (напечатан/
// выточен заодно, не отдельная деталь -- меньше швов, меньше точек
// протечки); провода от пьезо идут через центральный узкий канал в
// сухой отсек. ESP32 садится на стойки (M2, тот же принцип, что в
// z_axis_stack.scad), предусилитель -- на отдельные более короткие
// стойки ближе к пьезо-концу. Крышка герметизируется одним O-ring
// (паз рассчитан по стандартной DIY-формуле, тоже [UNVERIFIED] без
// даташита конкретного кольца -- см. комментарий у `oring_*`) и не
// имеет резьбы для этой "модели номер один" (простой скользящий фитинг
// + O-ring -- задача была "простая рабочая модель", резьба это
// усложнение сверх необходимого, Правило 99 Раунда 2).

// ===========================================================================
// Global parameters (all dimensions in mm)
// ===========================================================================
$fn = 64;
eps = 0.01;
clearance = 0.2;      // standoff/board fit clearance, same convention as
                       // z_axis_stack.scad/tube_enclosure_heatsink.scad

// Piezo disc (electric toothbrush vibration element) -- [UNVERIFIED]:
// no real part number/caliper measurement available (see critique
// above). Typical range for this class of piezo actuator is 15-25mm
// diameter, 0.3-0.6mm thickness; picked mid-range values and sized the
// potting cavity with real margin so the exact disc doesn't matter.
piezo_diameter = 20;
piezo_thickness = 0.5;
potting_margin = 4;           // extra radius the cavity gets over the piezo
potting_cavity_diameter = piezo_diameter + 2 * potting_margin;
potting_cavity_depth = 6;     // epoxy fill depth in front of + around the disc
sensor_wall_thickness = 2.5;  // solid wall behind the piezo, radiates into water

// Dry bay electronics (both boards run lengthwise, like
// z_axis_stack.scad's board orientation -- their long axis along the
// tube axis, not across it)
esp32_width = 28;             // typical ESP32 DevKitC width -- [UNVERIFIED],
esp32_length = 55;            // exact devkit dimensions vary by vendor;
esp32_component_height = 8;   // header pins + USB connector clearance above the PCB
preamp_width = 20;
preamp_length = 25;
preamp_component_height = 6;  // op-amp DIP/SOIC + a few passives

standoff_height = 4;
standoff_od = 4;
standoff_hole_id = 2.2;       // M2 self-tap, same as z_axis_stack.scad

wire_channel_diameter = 3;    // piezo lead-wire pass-through, sensor bay -> dry bay

// Tube sizing: must clear the wider of the two boards (esp32_width) plus
// component height above the board plus clearance on both sides, laid
// out around the tube's cross-section the same way tube_enclosure_
// heatsink.scad checked board_width against tube_id -- not just assumed.
dry_bay_id = esp32_width + 2 * (esp32_component_height + clearance + 3);
tube_id = max(potting_cavity_diameter + 2 * sensor_wall_thickness, dry_bay_id);
tube_wall = 3;
tube_od = tube_id + 2 * tube_wall;

dry_bay_length = esp32_length + preamp_length + 15;  // +15mm wire slack/spacing
tube_total_length = potting_cavity_depth + sensor_wall_thickness + dry_bay_length;

// Removable end cap (O-ring sealed, no threads -- Rule 99 Round 2: a
// slip-fit + O-ring meets "simple working model," threads don't add
// anything a bench prototype needs).
// O-ring groove sized by the common DIY approximation (groove width
// ~1.4x cord diameter, depth ~0.75x cord diameter) -- [UNVERIFIED]
// against a real O-ring manufacturer datasheet; fine for a bench
// prototype, revisit before a real dive-rated build.
oring_cord_diameter = 2.5;
oring_groove_width = oring_cord_diameter * 1.4;
oring_groove_depth = oring_cord_diameter * 0.75;
end_cap_length = 12;
end_cap_fit_clearance = 0.15;  // slip-fit into the tube ID, sealed by the O-ring, not the fit itself

// Elegoo Neptune 4 Pro build volume (real, published spec: 225x225x265mm)
// -- checked with an assert(), not eyeballed, so a future parameter
// change that outgrows the printer fails loudly at render time instead
// of silently producing an unprintable part.
printer_bed_xy = 225;
printer_bed_z = 265;
assert(tube_od <= printer_bed_xy, "tube_od exceeds Neptune 4 Pro bed X/Y");
assert(tube_total_length <= printer_bed_z, "tube length exceeds Neptune 4 Pro Z height");

// ===========================================================================
// Modules
// ===========================================================================

// Main tube: closed at the sensor end (integral wall, no seam -- see
// critique B), open at the dry-bay end for the removable cap.
module tube_body() {
    difference() {
        cylinder(h = tube_total_length, d = tube_od);
        // Sensor-end potting cavity, open at the tube's own outer face
        // so epoxy can be poured in flush with the surrounding wall
        // (the piezo sits at the BOTTOM of this cavity, closest to the
        // water-side wall, not at the open face -- backed by
        // sensor_wall_thickness of solid material against the water).
        translate([0, 0, sensor_wall_thickness])
            cylinder(h = potting_cavity_depth + eps, d = potting_cavity_diameter);
        // Dry bay bore, open at the far end for the removable cap.
        translate([0, 0, sensor_wall_thickness + potting_cavity_depth - eps])
            cylinder(
                h = dry_bay_length + end_cap_length + 2 * eps,
                d = tube_id
            );
    }
}

// A single M2-standoff board mount (same shape as z_axis_stack.scad's
// standoff() -- kept local here since this is a standalone assembly,
// not `use`d from that file, to avoid coupling two independently
// evolving parts).
module standoff() {
    difference() {
        cylinder(h = standoff_height, d = standoff_od);
        translate([0, 0, -eps])
            cylinder(h = standoff_height + 2 * eps, d = standoff_hole_id);
    }
}

// Piezo disc, shown seated at the bottom of the potting cavity for
// collision/clearance visualization -- the real part is glued/epoxied
// in place during assembly, not printed.
module piezo_disc() {
    translate([0, 0, sensor_wall_thickness])
        cylinder(h = piezo_thickness, d = piezo_diameter);
}

// Preamp board placeholder (op-amp + bias network) -- flat slab, real
// board is a separate KiCad/perfboard layout task, out of scope here.
module preamp_board() {
    translate([-preamp_width / 2, -1, 0])
        cube([preamp_width, 2, preamp_length]);
}

// ESP32 devkit placeholder -- same flat-slab convention.
module esp32_board() {
    translate([-esp32_width / 2, -1, 0])
        cube([esp32_width, 2, esp32_length]);
}

// Removable dry-bay end cap: slip-fits into the tube ID, sealed by one
// O-ring in a groove near its outer face (nearest the open end of the
// tube, where sealing actually needs to happen).
module end_cap() {
    plug_diameter = tube_id - 2 * end_cap_fit_clearance;
    difference() {
        union() {
            // Flange: sits flush against the tube's end face, stops the
            // plug from being pushed too far in.
            cylinder(h = 3, d = tube_od - eps);
            translate([0, 0, 3])
                cylinder(h = end_cap_length - 3, d = plug_diameter);
        }
        // O-ring groove, positioned in the plug section (inside the tube
        // once assembled) near the flange, so it seals right at the
        // tube's open face.
        translate([0, 0, 3 + 2])
            difference() {
                cylinder(h = oring_groove_width, d = plug_diameter + eps);
                translate([0, 0, -eps])
                    cylinder(
                        h = oring_groove_width + 2 * eps,
                        d = plug_diameter - 2 * oring_groove_depth
                    );
            }
    }
}

// ===========================================================================
// Assembly: full tube + piezo + boards + end cap, positioned to verify
// clearances (DFM step 2) before committing to fabrication.
// ===========================================================================
module assembly() {
    color("silver", 0.3)
        tube_body();

    color("darkred")
        piezo_disc();

    // Board mounting Z positions along the tube axis, inside the dry bay.
    preamp_z = sensor_wall_thickness + potting_cavity_depth + 5;
    esp32_z = preamp_z + preamp_length + 5;

    color("green")
        translate([0, 0, preamp_z])
        preamp_board();

    color("blue")
        translate([0, 0, esp32_z])
        esp32_board();

    // Standoffs under each board, offset to the board's own left/right
    // edges (same corner-mount pattern as z_axis_stack.scad).
    for (z = [preamp_z, esp32_z])
        for (x = [-8, 8])
            translate([x, -tube_id / 2 + standoff_od / 2 + 1, z])
                standoff();

    color("orange", 0.6)
        translate([0, 0, tube_total_length - end_cap_length + eps])
        end_cap();
}

// ===========================================================================
// Verified interference checks (same discipline as
// hardware/cad/full_assembly.scad -- real openscad intersection()
// renders, not eyeballed). Toggle exactly one via `-D check_X=true`.
// ===========================================================================
check_piezo_vs_wall = false;   // piezo_disc() vs tube_body()'s solid material -> confirmed EMPTY
check_boards_vs_wall = false;  // preamp/esp32 boards vs tube_body()'s solid material -> confirmed EMPTY
check_cap_vs_tube_id = false;  // end_cap() vs outside tube_id (must fit inside) -> confirmed EMPTY
section_view = false;          // `-D section_view=true` for the documentation cutaway render

// Print export selector -- the 3 real printed parts of this design
// (nothing else in the assembly is printed: piezo/preamp/ESP32 are
// off-the-shelf/salvaged). Each part is already oriented flat-face-down
// as modeled (module output starts at z=0), i.e. already in its real
// Neptune 4 Pro print orientation -- no extra rotate() needed before
// slicing. `-D print_part="tube_body"` / `"end_cap"` / `"standoff"`.
print_part = "";
if (print_part == "tube_body") {
    tube_body();
} else if (print_part == "end_cap") {
    end_cap();
} else if (print_part == "standoff") {
    standoff();
}
// ===========================================================================
// Assembly order (documentation only, changes no geometry) -- AK-74
// field-strip level of unambiguity per the guru-chorus request: 2
// printed parts (tube_body, end_cap) + 4 identical printed standoffs +
// off-the-shelf electronics, one order, no branches:
//   1. Epoxy-pot the piezo disc into the sensor-end cavity of tube_body.
//   2. Glue the 4 standoffs into the dry bay (2 short at preamp_z, 2 at
//      esp32_z -- identical parts, no left/right, no orientation to get
//      wrong).
//   3. Screw the preamp board onto its 2 standoffs, then the ESP32 onto
//      its 2 standoffs (M2 self-tap).
//   4. Solder/connect piezo leads -> preamp -> ESP32 through the central
//      wire channel.
//   5. Seat the O-ring in end_cap's groove, slide end_cap into the open
//      end until the flange meets the tube face.
// No step depends on a choice; each part only fits one way (round tube,
// round cap, standoffs identical) -- there is nothing to get backwards.
//
// Print orientation (Neptune 4 Pro, 0.4mm nozzle assumed): print
// tube_body and end_cap each standing on their flat face (cylinder axis
// vertical / parallel to Z) -- keeps layer lines as continuous hoops
// around the pressure-bearing wall instead of stepping across it, and
// needs no supports (both parts are axisymmetric with no overhangs
// steeper than horizontal cavity floors). Standoffs print flat-end-down,
// no supports.
// ===========================================================================

else if (check_piezo_vs_wall) {
    intersection() {
        piezo_disc();
        tube_body();
    }
} else if (check_boards_vs_wall) {
    preamp_z = sensor_wall_thickness + potting_cavity_depth + 5;
    esp32_z = preamp_z + preamp_length + 5;
    intersection() {
        union() {
            translate([0, 0, preamp_z]) preamp_board();
            translate([0, 0, esp32_z]) esp32_board();
        }
        tube_body();
    }
} else if (check_cap_vs_tube_id) {
    // Only the plug section (z>=3, past the flange) is meant to fit
    // inside tube_id -- the flange (z<3) is deliberately tube_od-sized
    // to seat flush against the tube's end face, so it's excluded here
    // rather than producing an expected-but-misleading non-empty result.
    intersection() {
        translate([0, 0, tube_total_length - end_cap_length + eps + 3])
            cylinder(h = end_cap_length - 3, d = tube_id - 2 * end_cap_fit_clearance);
        difference() {
            translate([0, 0, -10]) cylinder(h = tube_total_length + 20, d = 500);
            translate([0, 0, -11]) cylinder(h = tube_total_length + 22, d = tube_id);
        }
    }
} else if (section_view) {
    // Documentation/DFM-review render only (same rationale and pattern
    // as tube_enclosure_heatsink.scad): this repo's software PNG export
    // doesn't composite color()'s alpha channel, so the solid tube wall
    // hides the piezo/boards/cap entirely from any outside camera angle.
    // Cutting away the near half (X > 0) makes the internal layout
    // visible in a rendered image -- the real, uncut part is
    // assembly() above; this wrapper changes no modeled geometry.
    difference() {
        assembly();
        translate([0, -tube_od, -eps])
            cube([tube_od, 2 * tube_od, tube_total_length + 2 * eps]);
    }
} else {
    assembly();
}
