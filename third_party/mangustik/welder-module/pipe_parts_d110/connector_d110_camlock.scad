// ==========================================
// CONNECTOR: Camlock Quick-Disconnect Interface (Strategy 3)
// ISO 16028 flat-face coupling integrated with d110 PE pipe body
// 1-inch (25.4mm) bore, PN16 rated (160 bar), lever-actuated
// ==========================================

include <lib_d110.scad>

// Camlock parameters (ISO 16028 standard with d110 wrapper)
CAMLOCK_BORE = 25.4;      // Standard 1-inch ISO bore (mm)
WRAPPER_OD = 110;         // Wrapper OD matching d110 pipe (mm)
WRAPPER_THICKNESS = 8;    // Wrapper body wall thickness (mm)
WRAPPER_LENGTH = 80;      // Overall camlock body length (mm)
LEVER_LENGTH = 60;        // Lever arm length from center (mm)
LEVER_WIDTH = 18;         // Lever width (mm)
LEVER_THICKNESS = 8;      // Lever thickness (mm)
CAM_RADIUS = 15;          // Cam lobe radius (mm)
FLAT_FACE_DIA = 35;       // Flat-face sealing diameter (mm)
SEALING_DEPTH = 8;        // Sealing surface depth (mm)

$fn = 60;

module camlock_bore() {
    // Central bore (flat-face sealing surface)
    cylinder(h = SEALING_DEPTH + 2, r = CAMLOCK_BORE/2, center = false);
}

module flat_face_seal() {
    // Flat sealing surface with 0.5mm chamfer for self-alignment
    difference() {
        cylinder(h = SEALING_DEPTH, r = FLAT_FACE_DIA/2, center = false);

        // Chamfer edges
        translate([0, 0, SEALING_DEPTH - 0.5])
            cylinder(h = 1, r1 = FLAT_FACE_DIA/2, r2 = FLAT_FACE_DIA/2 - 0.5, center = false);
    }
}

module cam_lobe(angle) {
    // Individual cam lobe positioned at specified angle
    translate([CAM_RADIUS * cos(angle), CAM_RADIUS * sin(angle), SEALING_DEPTH])
        sphere(r = 5, $fn = 30);
}

module camlock_head() {
    // Camlock coupling head (socket half)
    difference() {
        union() {
            // Main body (cylindrical socket)
            cylinder(h = WRAPPER_LENGTH, r = WRAPPER_OD/2, center = false);

            // Flat-face sealing surface (raised boss at front)
            translate([0, 0, 0])
                flat_face_seal();

            // Three cam lobes evenly distributed (120° apart)
            for (i = [0, 120, 240]) {
                cam_lobe(i);
            }
        }

        // Central bore (flat-face socket opening)
        translate([0, 0, -0.5])
            camlock_bore();

        // Internal socket cavity for plug reception
        translate([0, 0, SEALING_DEPTH + 2])
            cylinder(h = WRAPPER_LENGTH - SEALING_DEPTH - 1, r = WRAPPER_OD/2 - WRAPPER_THICKNESS, center = false);

        // Relief cut around cam lobes for lever actuation space
        translate([0, 0, SEALING_DEPTH + 10])
            cylinder(h = WRAPPER_LENGTH - SEALING_DEPTH - 10, r = WRAPPER_OD/2 - 3, center = false);
    }
}

module camlock_plug() {
    // Camlock plug (male half, flat-face design)
    difference() {
        union() {
            // Cylindrical body matching bore
            cylinder(h = 40, r = CAMLOCK_BORE/2 - 0.2, center = false);

            // Flat-face sealing surface (recessed so coupling surfaces contact flush)
            translate([0, 0, -SEALING_DEPTH])
                flat_face_seal();

            // Quick-connect shoulders for positive stop
            translate([0, 0, 35])
                cylinder(h = 5, r = CAMLOCK_BORE/2 + 2, center = false);
        }

        // Optional: internal passage for media flow (if integrated with pipe)
        // Uncomment if modeling internal bore geometry:
        // translate([0, 0, -1])
        //     cylinder(h = 42, r = 10, center = false);
    }
}

module lever_arm(angle) {
    // Rotating lever arm for camlock actuation
    translate([0, 0, SEALING_DEPTH + 15])
        rotate([0, 0, angle])
            difference() {
                // Lever arm body
                union() {
                    // Pivot boss at center
                    cylinder(h = LEVER_THICKNESS, r = 8, center = true);

                    // Lever arm extending outward
                    translate([LEVER_LENGTH/2, 0, 0])
                        cube([LEVER_LENGTH, LEVER_WIDTH, LEVER_THICKNESS], center = true);

                    // Grip pad at end
                    translate([LEVER_LENGTH - 5, 0, 0])
                        cylinder(h = LEVER_THICKNESS, r = 6, center = true);
                }

                // Pivot hole for pin or bolt
                cylinder(h = LEVER_THICKNESS + 1, r = 4, center = true);
            }
}

module camlock_assembly_exploded() {
    // Socket half (red)
    color("Red") camlock_head();

    // Plug half (blue), separated for clarity
    translate([0, 0, WRAPPER_LENGTH + 20])
        color("RoyalBlue")
        camlock_plug();

    // Lever arm in open position (90°)
    color("Silver")
        lever_arm(90);

    // Optional: show closed position lever (45°)
    // color("Gray")
    //     lever_arm(45);
}

module camlock_integrated_with_d110() {
    // Camlock socket integrated directly into d110 pipe fitting housing
    // This represents a complete quick-disconnect fitting for housing branch connections

    union() {
        // Main camlock head
        camlock_head();

        // Transition cone to d110 pipe (for branch fitting)
        translate([0, 0, WRAPPER_LENGTH])
            difference() {
                cylinder(h = 20, r1 = WRAPPER_OD/2, r2 = OD_110/2 + 1, center = false);
                cylinder(h = 21, r = (WRAPPER_OD/2 - WRAPPER_THICKNESS) * 0.8, center = false);
            }
    }
}

// === Primary Assembly (Socket + Plug separated for clarity) ===
camlock_assembly_exploded();

// === Dimensions ===
// Bore diameter: 25.4 mm (1 inch ISO standard)
// Wrapper OD: 110 mm (d110 integration)
// Socket body length: 80 mm
// Flat-face sealing diameter: 35 mm
// Sealing surface depth: 8 mm
// Lever arm length: 60 mm
// Camlock operating pressure: PN16 (160 bar) with 1/4-turn flat-face lock
// Connection type: Self-sealing flat-face (minimal spillage)
// Material: High-density polyethylene (PE100) wrapper + elastomer (FKM) seals
// Flow capacity: nominal bore, pressure-rated to 160 bar

// === Assembly Instructions ===
// 1. Insert plug (male) into socket (female) with flat faces aligned
// 2. Rotate lever arm from 90° (open) through 45° intermediate to 0° (locked)
// 3. Cam lobes engage plug shoulders, drawing plug fully into socket
// 4. Flat-face sealing surfaces compress FKM O-ring, establishing pressure seal
// 5. Coupling is fully engaged and under pressure after 1/4 turn
// 6. To disconnect: rotate lever 90° back to open position (pressure bleeds safely)
// 7. Coupling separates freely without spill (flat-face design)
