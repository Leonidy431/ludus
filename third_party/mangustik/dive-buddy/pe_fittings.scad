// Standard PE (ПНД) electrofusion fitting library, per ГОСТ Р 52779-2007
// ("Фасонные части из полиэтилена. Технические условия") and its
// international counterpart practice (ISO 12176 / DVS 2207) - the fitting
// FAMILY (coupler/reducer/elbow/tee/end cap) is standard industry
// vocabulary, not GOST-specific invention, and welder-module already
// speaks this exact fitting class (its barcode format decodes coupler
// diameter/voltage/resistance per ISO 12176-4 practice).
//
// Real vs. representative, same discipline as pressure_housing.scad:
// - Pipe/socket diameters, SDR wall formula: real, standard.
// - Electrofusion socket clearance: real, standard EF assembly allowance.
// - Exact fitting body wall thickness/flange dimensions PER GOST TABLE:
//   this sandbox has no network access to the GOST Р 52779-2007 text
//   itself (same class of gap as the SubConn/hydrophone datasheet blocks
//   elsewhere in this repo) - those numbers are parametrized as
//   [UNVERIFIED] representative values, not read from the standard's
//   actual dimensional tables. Confirm against a sourced copy of the
//   GOST or a real manufacturer's catalog before cutting anything to fit
//   these fittings.
//
// Five fitting types modeled, covering the "муфта" (coupler) family and
// the other shaped-part types GOST 52779 groups alongside it:
//   1. equal_coupler        - муфта равнопроходная (straight, same OD)
//   2. reducing_coupler     - муфта переходная/редукционная (OD1 -> OD2)
//   3. elbow_90             - отвод 90 градусов
//   4. tee                  - тройник (equal-diameter branch)
//   5. end_cap              - заглушка (welded closed end, NOT the
//                              printed/serviceable avionics endcap in
//                              pressure_housing.scad - this is the
//                              permanently-welded PE closure type)

print_tolerance = 0.2;   // FDM assembly clearance, per root CLAUDE.md
eps = 0.01;              // difference() z-fighting guard, per root CLAUDE.md

coupler_socket_clearance_mm = 0.5;  // real, standard EF assembly allowance
coupler_wall_mm = 12;                // [UNVERIFIED] representative EF body wall
coupler_length_mm = 130;             // [UNVERIFIED] representative EF axial length

function pe_wall_mm(od_mm, sdr) = od_mm / sdr;
function pe_id_mm(od_mm, sdr) = od_mm - 2 * pe_wall_mm(od_mm, sdr);
function socket_id_mm(od_mm) = od_mm + 2 * coupler_socket_clearance_mm;
function socket_od_mm(od_mm) = socket_id_mm(od_mm) + 2 * coupler_wall_mm;

module pe_pipe_stub(od_mm, sdr, length) {
    difference() {
        cylinder(h = length, d = od_mm, $fn = 96);
        translate([0, 0, -eps])
            cylinder(h = length + 2 * eps, d = pe_id_mm(od_mm, sdr), $fn = 96);
    }
}

// 1. Equal-diameter straight coupler ("муфта равнопроходная")
// NOTE (HARDWARE_AUDIT_2026-08-28 #12): this module used to build its
// sleeve center=true (spanning ±length/2) while pressure_housing.scad's
// hull assemblies place it assuming a 0..length span — leaving a real
// 65 mm open gap at every hull joint. The module now spans 0..length,
// matching every placement call site.
module equal_coupler(od_mm = 110, length = coupler_length_mm) {
    color("Orange", 0.85)
    difference() {
        cylinder(h = length, d = socket_od_mm(od_mm), center = false, $fn = 96);
        translate([0, 0, -eps])
            cylinder(h = length + 2 * eps, d = socket_id_mm(od_mm), center = false, $fn = 96);
    }
}

// 2. Reducing coupler ("муфта переходная") - joins od_mm_large to
// od_mm_small; the socket transition is a real geometric feature EF
// reducers have (a stepped or conical throat) - modeled here as a
// stepped throat, the simpler and more common real construction for
// injection-molded PE reducers (vs. the rarer machined conical type).
module reducing_coupler(od_mm_large = 110, od_mm_small = 90,
                        socket_length = coupler_length_mm / 2) {
    color("Orange", 0.85)
    union() {
        translate([0, 0, -socket_length])
            difference() {
                cylinder(h = socket_length, d = socket_od_mm(od_mm_large), $fn = 96);
                translate([0, 0, -eps])
                    cylinder(h = socket_length + 2 * eps,
                             d = socket_id_mm(od_mm_large), $fn = 96);
            }
        difference() {
            cylinder(h = socket_length, d = socket_od_mm(od_mm_small), $fn = 96);
            translate([0, 0, -eps])
                cylinder(h = socket_length + 2 * eps,
                         d = socket_id_mm(od_mm_small), $fn = 96);
        }
    }
}

// 3. 90 degree elbow ("отвод 90 градусов") - two sockets joined at a
// right angle. Bend radius [UNVERIFIED] - representative of a compact
// molded elbow, not a sourced GOST table value. MUST exceed the fitting
// body's own radius (socket_od_mm/2) - rotate_extrude()'s swept profile
// has to stay entirely on one side of the rotation axis, so a bend
// radius smaller than the pipe cross-section makes the profile straddle
// X=0 and OpenSCAD silently drops that solid (caught by rendering this
// file for real, not just reading the code - the first draft used 60mm
// against a ~135mm socket OD and produced a disconnected, geometrically
// invalid elbow).
module elbow_90(od_mm = 110, sdr = 11, socket_length = coupler_length_mm / 2,
                bend_radius = 90) {
    assert(bend_radius > socket_od_mm(od_mm) / 2,
          str("elbow_90: bend_radius must exceed socket_od_mm(od_mm)/2 ",
              "or the rotate_extrude() sweep profile straddles the ",
              "rotation axis"));
    color("Orange", 0.85)
    union() {
        // socket 1, along +Z
        translate([0, 0, 0])
            difference() {
                cylinder(h = socket_length, d = socket_od_mm(od_mm), $fn = 96);
                translate([0, 0, -eps])
                    cylinder(h = socket_length + 2 * eps,
                             d = socket_id_mm(od_mm), $fn = 96);
            }
        // socket 2, along +X after the bend
        translate([bend_radius, 0, socket_length])
            rotate([0, 90, 0])
            difference() {
                cylinder(h = socket_length, d = socket_od_mm(od_mm), $fn = 96);
                translate([0, 0, -eps])
                    cylinder(h = socket_length + 2 * eps,
                             d = socket_id_mm(od_mm), $fn = 96);
            }
        // filled body connecting the two sockets at the bend
        translate([0, 0, socket_length])
            rotate([-90, 0, 0])
            rotate_extrude(angle = 90, $fn = 96)
            translate([bend_radius, 0])
            circle(d = socket_od_mm(od_mm), $fn = 48);
    }
}

// 4. Equal-diameter tee ("тройник")
module tee(od_mm = 110, socket_length = coupler_length_mm / 2) {
    module socket() {
        difference() {
            cylinder(h = socket_length, d = socket_od_mm(od_mm), $fn = 96);
            translate([0, 0, -eps])
                cylinder(h = socket_length + 2 * eps,
                         d = socket_id_mm(od_mm), $fn = 96);
        }
    }
    color("Orange", 0.85)
    union() {
        translate([0, 0, -socket_length]) socket();       // run, -Z
        socket();                                          // run, +Z
        translate([0, 0, 0]) rotate([0, 90, 0]) socket();  // branch, +X
    }
}

// 5. Welded end cap ("заглушка") - permanent, all-PE closed end. NOT the
// printed/serviceable O-ring plug in pressure_housing.scad's
// avionics_endcap() - that one opens for service; this one is a
// factory-molded permanent closure for a hull end that never needs
// re-opening (e.g. a nose or tail section).
module end_cap(od_mm = 110, dome_height = 40) {
    color("Orange", 0.85)
    union() {
        cylinder(h = coupler_length_mm / 2, d = socket_od_mm(od_mm), $fn = 96);
        translate([0, 0, coupler_length_mm / 2])
            scale([1, 1, dome_height / (socket_od_mm(od_mm) / 2)])
            sphere(d = socket_od_mm(od_mm), $fn = 96);
    }
}

// Render all five for a visual/dimensional sanity sweep when this file
// is opened directly. `use <pe_fittings.scad>` (as pressure_housing.scad
// does) imports only the modules/functions above, not these top-level
// calls - OpenSCAD's use vs. include distinction - so this sweep never
// fires when the file is consumed as a library.
translate([0, 0, 0]) equal_coupler();
translate([200, 0, 0]) reducing_coupler();
translate([400, 0, 0]) elbow_90();
translate([600, 0, 0]) tee();
translate([800, 0, 0]) end_cap();
