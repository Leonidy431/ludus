// ============================================================================
// Mangustik welder-module — d110 PE pipe + electrofusion fitting parametric
// library (OpenSCAD 2021.01)
// ============================================================================
// See README.md in this directory for the full sourcing breakdown. Summary:
//   - OD_110 / WALL_SDR17 / WALL_SDR11 are GOST 18599-2001 pipe dimensions,
//     cross-confirmed against >=3 independent commercial citations of the
//     standard (this sandbox's network egress to non-GitHub domains is
//     blocked, so the primary GOST PDF text itself could not be fetched
//     directly — see README.md "Sourcing" section for the exact citations).
//   - Everything under "Fitting geometry — ENGINEERING ESTIMATES" is a
//     reasonable parametric placeholder, NOT taken from a GOST 32415-2013
//     dimension table or a specific manufacturer datasheet (neither was
//     reachable in this sandbox). Real electrofusion-fitting body dimensions
//     vary per manufacturer TU; swap these constants for a real datasheet's
//     numbers before using this model for anything beyond a demo/test rig.
//
// Units: millimetres throughout.

$fn = 96;

// ---- GOST 18599-2001 verified pipe parameters (PE100, nominal d110) ------
OD_110     = 110.0; // nominal outside diameter, mm
WALL_SDR17 = 6.6;   // SDR17 -> PN10 (cold water supply)
WALL_SDR11 = 10.0;  // SDR11 -> PN16 (higher pressure / gas)

// ---- Fitting geometry — ENGINEERING ESTIMATES (see README.md) ------------
SOCKET_DEPTH      = 55;             // ~0.5x OD, typical electrofusion socket engagement
SOCKET_CLEARANCE  = 1.0;            // total bore oversize vs. pipe OD (0.5mm/side)
CENTER_LAND       = 15;             // center stop length inside a straight coupling
FITTING_WALL      = WALL_SDR11;     // fittings sized to the heavier SDR for strength margin
TERMINAL_DIA      = 4.0;
TERMINAL_LEN      = 8.0;
TERMINAL_INSET    = 20;             // distance of terminal pin from socket end
ELBOW_BEND_RADIUS = 1.5 * OD_110;   // long-radius elbow, common 1.5xD rule of thumb

// ---- Demo/test-bench only (NOT a GOST value — real stock ships in 12m
// lengths per the same sources; this is just a benchtop sample length) -----
DEMO_PIPE_LENGTH  = 300;

function pipe_id(wall)       = OD_110 - 2*wall;
function socket_bore()       = OD_110 + SOCKET_CLEARANCE;
function fitting_od(wall)    = OD_110 + 2*wall;

// A straight pipe segment, wall thickness selectable by SDR.
module pipe_segment(length=DEMO_PIPE_LENGTH, wall=WALL_SDR17) {
    difference() {
        cylinder(h=length, d=OD_110);
        translate([0, 0, -1])
            cylinder(h=length + 2, d=pipe_id(wall));
    }
}

// Electrofusion straight coupling (муфта электросварная), two sockets
// with a center land stop, plus two visual terminal bosses (the real
// spiral heater-wire layout is not modeled — see README.md).
module coupling(wall=FITTING_WALL) {
    total_len = 2 * SOCKET_DEPTH + CENTER_LAND;
    od = fitting_od(wall);
    difference() {
        cylinder(h=total_len, d=od);
        translate([0, 0, -1])
            cylinder(h=total_len + 2, d=socket_bore());
    }
    for (z = [TERMINAL_INSET, total_len - TERMINAL_INSET])
        translate([0, 0, z])
            rotate([0, 90, 0])
                cylinder(h=od/2 + TERMINAL_LEN, d=TERMINAL_DIA);
}

// 90-degree elbow (отвод): a long-radius torus bend (centerline radius
// ELBOW_BEND_RADIUS, an engineering rule-of-thumb — see README.md) with a
// straight socket leg welded onto each open end. The two legs are built as
// one leg placed at the bend's angle=0 end, then the *same* leg rotated 90
// degrees about Z to land exactly on the angle=90 end — by construction of
// rotate_extrude() this guarantees the legs are flush with the bend, no
// hand-derived alignment math to get wrong.
module elbow90(wall=FITTING_WALL) {
    od  = fitting_od(wall);
    id  = socket_bore();
    leg = SOCKET_DEPTH;
    r   = ELBOW_BEND_RADIUS;

    module bend() {
        rotate_extrude(angle=90)
            translate([r, 0])
                difference() {
                    circle(d=od);
                    circle(d=id);
                }
    }
    module leg_a() {
        translate([r, 0, 0])
            rotate([90, 0, 0])
                difference() {
                    cylinder(h=leg, d=od);
                    translate([0, 0, -1]) cylinder(h=leg + 2, d=id);
                }
    }
    module leg_b() {
        rotate([0, 0, 90]) leg_a();
    }

    union() {
        bend();
        leg_a();
        leg_b();
        // terminal bosses near each socket opening (visual only — real
        // spiral heater-wire layout is not modeled, see README.md)
        translate([r, -(leg - TERMINAL_INSET), 0])
            rotate([90, 0, 0])
                translate([od/2, 0, 0])
                    cylinder(h=TERMINAL_LEN, d=TERMINAL_DIA);
        rotate([0, 0, 90])
            translate([r, -(leg - TERMINAL_INSET), 0])
                rotate([90, 0, 0])
                    translate([od/2, 0, 0])
                        cylinder(h=TERMINAL_LEN, d=TERMINAL_DIA);
    }
}

// T-junction / Tee (тройник): a proper 3-port electrofusion tee.
// Main run is ONE continuous barrel along Z (socket at each end, center
// land between, same layout as coupling()); one branch socket along +Y.
// Rebuilt per HARDWARE_AUDIT_2026-08-28 #2/#3/#4: the old version unioned
// a solid junction sphere that plugged all three bores (render-confirmed
// blind plug, Volumes: 5), pointed its legs +Z/−Y/+X with no collinear
// main run, and left all three terminal bosses floating in mid-air.
// Correct pattern: union all OUTER bodies first, subtract ALL bores last.
function tee_run_length() = 2 * SOCKET_DEPTH + CENTER_LAND;

module tee(wall=FITTING_WALL) {
    od     = fitting_od(wall);
    id     = socket_bore();
    run    = tee_run_length();
    // branch barrel from the run axis out to the +Y socket mouth
    branch = SOCKET_DEPTH + od/2;

    difference() {
        union() {
            // main run barrel (two sockets + center land, like coupling())
            cylinder(h=run, d=od);
            // +Y branch barrel
            translate([0, 0, run/2])
                rotate([-90, 0, 0])
                    cylinder(h=branch, d=od);
            // junction reinforcement collar
            translate([0, 0, run/2])
                sphere(d=od + 2);
        }
        // bores LAST, straight through the junction; overshoot by a full od
        // on each side so the reinforcement sphere (which pokes slightly
        // past the barrel ends) is bored through too
        translate([0, 0, -od])
            cylinder(h=run + 2*od, d=id);
        translate([0, 0, run/2])
            rotate([-90, 0, 0])
                translate([0, 0, -od])
                    cylinder(h=branch + 2*od, d=id);
    }

    // Terminal bosses, radial and half-embedded like coupling()'s
    for (z = [TERMINAL_INSET, run - TERMINAL_INSET])
        translate([0, 0, z])
            rotate([0, 90, 0])
                cylinder(h=od/2 + TERMINAL_LEN, d=TERMINAL_DIA);
    translate([0, 0, run/2])
        rotate([-90, 0, 0])
            translate([0, 0, branch - TERMINAL_INSET])
                rotate([0, 90, 0])
                    cylinder(h=od/2 + TERMINAL_LEN, d=TERMINAL_DIA);
}

// End cap / Blind plug (заглушка): socket barrel + dome OUTSIDE the
// socket. Rebuilt per HARDWARE_AUDIT_2026-08-28 #5: the old full sphere
// centered at the socket mouth filled the bore, cutting pipe engagement
// from 55 mm to ~20 mm — an electrofusion joint spec'd at SOCKET_DEPTH
// engagement could not be welded. The dome (upper hemisphere only) now
// sits entirely above z = SOCKET_DEPTH, leaving the full socket free.
module cap(wall=FITTING_WALL) {
    od  = fitting_od(wall);
    id  = socket_bore();
    socket_len = SOCKET_DEPTH;
    eps = 0.01;

    // Socket barrel (engages with pipe over its full depth)
    difference() {
        cylinder(h=socket_len, d=od);
        translate([0, 0, -1]) cylinder(h=socket_len + 2, d=id);
    }

    // Dome sealing the end: upper hemisphere only, base flush with the
    // barrel top so no material intrudes into the socket.
    translate([0, 0, socket_len - eps])
        difference() {
            sphere(d=od);
            translate([0, 0, -od/2 - 1])
                cylinder(h=od/2 + 1, d=od + 2);
        }

    // Single terminal boss (for heater contact), radial, half-embedded
    translate([0, 0, socket_len - TERMINAL_INSET])
        rotate([0, 90, 0])
            cylinder(h=od/2 + TERMINAL_LEN, d=TERMINAL_DIA);
}
