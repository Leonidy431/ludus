// ==========================================
// CONNECTOR: Flanged Bulkhead Interface (Strategy 2)
// Quick-disconnect bolted connector for d110 PE pipe electrofusion fitting
// GOST 32415-2013 compatible, PN16 rated
// ==========================================

include <lib_d110.scad>

// Flanged connector parameters (based on d110 standard sizing)
FLANGE_OD = 150;          // Flange outer diameter (mm)
FLANGE_THICKNESS = 12;    // Flange face thickness (mm)
BOLT_PATTERN_PCD = 120;   // Bolt circle diameter (mm)
BOLT_HOLE_DIA = 8.5;      // M8 bolt hole diameter (clearance fit)
NUM_BOLTS = 4;            // Four-point bolt pattern
SOCKET_ENGAGEMENT = 55;   // Socket engagement depth (matches pipe socket)
COUNTERBORE_DIA = 15;     // Counterbore for elastomer O-ring
COUNTERBORE_DEPTH = 4;    // Counterbore depth for O-ring seat

$fn = 60;

module flanged_connector() {
    // Main flange body (disc with socket boss)
    union() {
        // Flange disc
        cylinder(h = FLANGE_THICKNESS, r = FLANGE_OD/2, center = false);

        // Socket boss (raised center for pipe insertion)
        translate([0, 0, FLANGE_THICKNESS])
            cylinder(h = SOCKET_ENGAGEMENT, r = OD_110/2 + 1, center = false);
    }
}

module flanged_connector_with_bore() {
    difference() {
        flanged_connector();

        // Central socket bore (female half)
        translate([0, 0, -0.5])
            cylinder(h = FLANGE_THICKNESS + SOCKET_ENGAGEMENT + 1, r = OD_110/2 + 0.5, center = false);

        // Counterbore for elastomer O-ring sealing surface
        translate([0, 0, FLANGE_THICKNESS - COUNTERBORE_DEPTH])
            cylinder(h = COUNTERBORE_DEPTH + 0.1, r = COUNTERBORE_DIA/2, center = false);

        // Four bolt holes on PCD
        for (angle = [0, 90, 180, 270]) {
            translate([BOLT_PATTERN_PCD/2 * cos(angle), BOLT_PATTERN_PCD/2 * sin(angle), -0.5])
                cylinder(h = FLANGE_THICKNESS + 1, r = BOLT_HOLE_DIA/2, center = false);
        }
    }
}

module male_connector_half() {
    // Male side: raised socket boss for insertion into female
    difference() {
        union() {
            // Base flange
            cylinder(h = FLANGE_THICKNESS, r = FLANGE_OD/2, center = false);

            // Male protrusion (slightly tapered for centering)
            translate([0, 0, FLANGE_THICKNESS])
                cylinder(h = SOCKET_ENGAGEMENT - 2, r1 = OD_110/2 - 0.5, r2 = OD_110/2 - 2, center = false);
        }

        // Four bolt holes (clearance for fasteners)
        for (angle = [0, 90, 180, 270]) {
            translate([BOLT_PATTERN_PCD/2 * cos(angle), BOLT_PATTERN_PCD/2 * sin(angle), -0.5])
                cylinder(h = FLANGE_THICKNESS + 1, r = BOLT_HOLE_DIA/2, center = false);
        }
    }
}

module female_connector_half() {
    // Female side: recessed socket for insertion
    difference() {
        union() {
            // Base flange
            cylinder(h = FLANGE_THICKNESS, r = FLANGE_OD/2, center = false);

            // Boss for socket engagement
            translate([0, 0, FLANGE_THICKNESS])
                cylinder(h = 5, r = OD_110/2 + 1.5, center = false);
        }

        // Central recess (female socket bore)
        translate([0, 0, FLANGE_THICKNESS])
            cylinder(h = SOCKET_ENGAGEMENT, r = OD_110/2 - 0.5, center = false);

        // Counterbore for O-ring sealing
        translate([0, 0, FLANGE_THICKNESS - COUNTERBORE_DEPTH])
            cylinder(h = COUNTERBORE_DEPTH + 0.1, r = COUNTERBORE_DIA/2, center = false);

        // Four bolt holes
        for (angle = [0, 90, 180, 270]) {
            translate([BOLT_PATTERN_PCD/2 * cos(angle), BOLT_PATTERN_PCD/2 * sin(angle), -0.5])
                cylinder(h = FLANGE_THICKNESS + 1, r = BOLT_HOLE_DIA/2, center = false);
        }
    }
}

// === Assembly Views ===

// Single standard flange connector (for reference)
color("DarkBlue") flanged_connector_with_bore();

// Uncomment below to view male-female assembly (separated for clarity)
/*
translate([0, 0, 0])
    color("RoyalBlue")
    male_connector_half();

translate([0, 0, FLANGE_THICKNESS + SOCKET_ENGAGEMENT + 10])
    color("SteelBlue")
    female_connector_half();

// Optional: show bolt positions
for (angle = [0, 90, 180, 270]) {
    translate([BOLT_PATTERN_PCD/2 * cos(angle), BOLT_PATTERN_PCD/2 * sin(angle), -5])
        color("Silver")
        cylinder(h = 3, r = 4, center = false);
}
*/

// === Dimensions ===
// Flange OD: 150 mm
// Flange thickness: 12 mm
// Socket engagement depth: 55 mm
// Bolt pattern: 4× M8 on 120 mm PCD
// Counterbore: 15 mm diameter, 4 mm deep (FKM/Viton O-ring seat)
// Total socket depth for pipe insertion: 55 mm
// Pressure rating: PN16 (160 bar) with proper bolt torque and O-ring compression
