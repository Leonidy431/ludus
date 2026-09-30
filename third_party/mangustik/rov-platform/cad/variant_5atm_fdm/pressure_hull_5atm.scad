// ============================================================================
// DiveGuard rov-platform - 5-ATM FDM-printable WORKING/PROTOTYPE hull variant
// (2026-08-08, explicit user request: "делаем рабочую модель до 5 атмосфер")
//
// This is a SEPARATE variant from the 300m/30-bar machined-aluminum hulls in
// rov-platform/cad/02_.../03_... (those are UNCHANGED by this file and
// remain the real flight-hardware design - see this session's earlier
// pushback on why FDM snap-fit conventions don't belong on a 300m pressure
// vessel). This file is for a shallow (~50m / 5 bar gauge) 3D-printed
// prototype - a genuinely different depth class where FDM-appropriate design
// (print tolerances, minimized external hardware, symmetric/interchangeable
// parts) is real engineering, not a shortcut.
//
// ----------------------------------------------------------------------------
// WALL THICKNESS - derived, not guessed
// ----------------------------------------------------------------------------
// Long-tube external-pressure collapse formula (thin cylindrical shell,
// length >> diameter): Pcr = 2E/(1-nu^2) * (t/D)^3
//   Design pressure: 5 bar gauge (500,000 Pa) - the user's stated target.
//   Safety factor: 4x (isotropic-material safety factor, common practice
//     for amateur/prosumer printed pressure housings).
//   FDM knockdown: additional 2x on top of the above - the collapse formula
//     assumes an isotropic material; FDM parts are anisotropic (layer
//     adhesion is weaker than in-plane strength) and the formula does not
//     capture that. This knockdown is an engineering judgment call, not a
//     value from a datasheet.
//   Material assumed: PETG (E ~= 2.1 GPa, nu ~= 0.30) - chosen over PLA/ABS
//     for better water resistance and toughness; a real material's data
//     sheet should replace this assumption before printing.
//   Required Pcr = 500,000 * 4 * 2 = 4,000,000 Pa (40 bar).
//   Solving for t at OD=120mm: t = D*(Pcr*(1-nu^2)/(2E))^(1/3) ~= 11.4mm,
//   rounded up to 12mm (actual Pcr at 12mm ~= 46 bar, a ~9.2x margin over
//   the 5 bar design pressure using this isotropic-material estimate).
//
// THIS IS A DESIGN ESTIMATE, NOT A CERTIFICATION. FDM anisotropy, print
// quality (infill, layer adhesion, wall count), and long-term creep under
// sustained pressure are not captured by the formula above. A real
// hydrostatic pressure test of a printed sample (ideally to well past
// 5 bar, with a safety exclusion zone - pressure-testing plastic can fail
// violently) is mandatory before this touches water with anything attached
// that matters. Same verification-caveat discipline as the rest of this
// repo's KiCad/Docker/OpenSCAD work - a calculation is not a test.
//
// ----------------------------------------------------------------------------
// UNIFICATION PRINCIPLE: symmetric/interchangeable end caps
// ----------------------------------------------------------------------------
// Both ends of the tube use the SAME `end_cap()` module - one printed part,
// mounted in either orientation, rather than a distinct "front cap" /
// "rear cap" design. The connector cutouts (from the shared JSON interface,
// see standoff_coords.scad) are cut into whichever cap is logically the
// "connector end" via a parameter, not via a second geometry.
//
// ----------------------------------------------------------------------------
// FASTENING: heat-set inserts, not snap-fit, for the pressure seal
// ----------------------------------------------------------------------------
// The brief asked to minimize external hardware via snap-fits or a single
// heat-set-insert pattern. For the PRESSURE-SEALING joint (end cap to tube),
// this file uses the heat-set-insert option, not snap-fits: a snap-fit
// pressure boundary on a hand-loaded prototype is a real leak/blow-off risk
// even at 5 bar (a person's hand, not an engineered latch spring, is what
// would be "holding" the pressure until the snap fully seats and O-ring
// compresses evenly) - screws into heat-set inserts give controllable,
// even, inspectable clamping force on the O-ring, which snap-fit ribs don't.
// This is the one unification-brief request this file deliberately does not
// follow literally, for a safety reason specific to this part's job -
// flagged explicitly rather than silently deviated from.
// ============================================================================

include <standoff_coords.scad>

// ----------------------------------------------------------------------------
// Global parametric conventions (per the unification brief)
// ----------------------------------------------------------------------------
print_tolerance = 0.2;   // FDM clearance fit allowance, mm (per brief)
eps = 0.01;              // difference() overlap epsilon, prevents Z-fighting

function hole_diameter(nominal) = nominal + print_tolerance;
function peg_diameter(nominal) = nominal - print_tolerance;

// Pilot bore for an M3 self-tapper cutting into printed plastic. This is an
// interference bore (thread must bite), so hole_diameter()'s clearance
// formula does NOT apply here - audit 2026-08-28 #32: the old expression
// hole_diameter(sd - 3.2 + 3.2) produced 3.4 mm, larger than the M3 major
// diameter (3.0), so the screw had nothing to grip.
selftap_pilot_mm = 2.5;

// PCB deck tray (audit 2026-08-28 #33: the four standoff bosses used to
// float in mid-air with nothing connecting them to each other or the tube -
// unprintable as a part, and the PCB had nothing holding it). The deck is a
// chord-truncated disc keyed to the tube ID: peg_diameter() slip fit into
// the bore, flats at y = +/- deck_chord_half_mm leave two cable channels
// along the hull wall. Bosses stand ON the deck, one printed part.
deck_thickness_mm = 4;
deck_chord_half_mm = 30;   // board is 50 tall (+/-25 centered) - fully supported

// ----------------------------------------------------------------------------
// Hull dimensions (derived above)
// ----------------------------------------------------------------------------
hull_od_mm = 120.0;
hull_wall_mm = 12.0;
hull_id_mm = hull_od_mm - 2 * hull_wall_mm;   // 96.0
hull_length_mm = 300.0;                        // fits common FDM print beds

// O-ring groove - real standard cross-section (3mm CS, common metric O-ring
// size e.g. 90x3 or similar - re-confirm exact ID against the O-ring
// actually purchased before cutting). Groove depth ~80% of CS per standard
// static-seal design guidance (allows compression without full bottoming).
oring_cs_mm = 3.0;
// Gland stack-up (HARDWARE_AUDIT_2026-08-28 #30): the old fixed depth of
// 0.8*CS ignored the radial extrusion gap between the spigot and the
// tube bore. Total gland height = groove depth + radial gap, and for a
// static seal it must be ~0.75..0.8 * CS (20-25% squeeze). With the
// spigot at peg_diameter(hull_id-2) the radial gap is
// (hull_id - spigot)/2 = 1.1 mm, so depth is derived, not fixed:
oring_spigot_d_mm    = peg_diameter(hull_id_mm - 2);            // 93.8
oring_radial_gap_mm  = (hull_id_mm - oring_spigot_d_mm) / 2;    // 1.1
oring_groove_depth_mm = 0.75 * oring_cs_mm - oring_radial_gap_mm; // 1.15
oring_groove_width_mm = oring_cs_mm * 1.4;    // standard static-groove width guidance

// Heat-set insert (M3, common brass insert: ~4.0mm body OD, ~5.7mm deep)
heatset_hole_diameter_mm = hole_diameter(4.0);
heatset_depth_mm = 6.0;
n_cap_screws = 6;   // evenly spaced around the flange, even O-ring compression

// ----------------------------------------------------------------------------
// Tube body
// ----------------------------------------------------------------------------
module hull_tube() {
    difference() {
        cylinder(h = hull_length_mm, d = hull_od_mm, center = false, $fn = 96);
        translate([0, 0, -eps])
            cylinder(h = hull_length_mm + 2 * eps, d = hull_id_mm, $fn = 96);
    }
}

// ----------------------------------------------------------------------------
// End cap - ONE module, used for both ends (unification: interchangeable
// parts). `with_connectors` selects whether this instance gets the
// connector_cutouts from standoff_coords.scad cut into it.
// ----------------------------------------------------------------------------
module end_cap(with_connectors = false) {
    flange_od = hull_od_mm + 8;       // proud of the tube OD for the screw ring
    spigot_h = 8;                     // register that locates the cap in the tube ID

    difference() {
        union() {
            // Flange disc
            cylinder(h = 8, d = flange_od, $fn = 96);
            // Spigot register - peg_diameter() so it's a real FDM clearance
            // fit into the tube's ID, not nominal-on-nominal.
            translate([0, 0, 8])
                cylinder(h = spigot_h, d = peg_diameter(hull_id_mm - 2), $fn = 96);
        }

        // O-ring groove, cut into the spigot's outer face.
        // Audit #30: the old annulus went OUTWARD from the spigot surface
        // (outer d = spigot + depth, inner d = spigot - eps), shaving a
        // 0.005 mm skin instead of cutting a groove INTO the spigot. A
        // groove is: outer boundary just past the spigot surface, inner
        // boundary at the groove root, spigot - 2*depth.
        translate([0, 0, 8])
            difference() {
                cylinder(h = oring_groove_width_mm,
                         d = oring_spigot_d_mm + 2 * eps,
                         $fn = 96);
                translate([0, 0, -eps])
                    cylinder(h = oring_groove_width_mm + 2 * eps,
                             d = oring_spigot_d_mm - 2 * oring_groove_depth_mm,
                             $fn = 96);
            }

        // Cap screw ring - n_cap_screws holes on the flange, heat-set
        // inserts go in the TUBE-side mating flange (not modeled as a
        // separate part here - a real design needs a matching flange boss
        // on the tube end, noted as a follow-up, not invented here without
        // a print test), through-holes here so a screw passes through the
        // cap into that insert.
        for (i = [0 : n_cap_screws - 1]) {
            angle = i * 360 / n_cap_screws;
            rotate([0, 0, angle])
                translate([(flange_od / 2) - 6, 0, -eps])
                    cylinder(h = 8 + 2 * eps, d = hole_diameter(3.2), $fn = 24);
        }

        // Connector cutouts, only on the designated connector-end cap -
        // driven entirely by standoff_coords.scad's connector_cutouts array
        // (the same data the KiCad board generator reads), so the panel
        // holes and the PCB's own edge connectors can't silently disagree
        // about where they are.
        if (with_connectors) {
            for (c = connector_cutouts) {
                edge_x = c[0]; edge_y = c[1]; shape = c[2]; d1 = c[3]; d2 = c[4];
                // Board-local (x,y) -> cap-local polar placement: board is
                // assumed centered in the cap, so map board edge position to
                // an angle around the circular cap face.
                board_cx = board_width_mm / 2;
                board_cy = board_height_mm / 2;
                rel_x = edge_x - board_cx;
                rel_y = edge_y - board_cy;
                place_angle = atan2(rel_y, rel_x);
                place_r = (hull_id_mm / 2) - 4;
                translate([place_r * cos(place_angle), place_r * sin(place_angle), -eps])
                    if (shape == "rect") {
                        cube([hole_diameter(d1), hole_diameter(d2), 16 + 2 * eps], center = true);
                    } else {
                        cylinder(h = 16 + 2 * eps, d = hole_diameter(d1), $fn = 32);
                    }
            }
        }
    }
}

// ----------------------------------------------------------------------------
// Internal standoff bosses for the PCB, on a mounting deck inside the tube.
// Driven by standoffs[] from standoff_coords.scad (the shared interface with
// the KiCad board generator).
// ----------------------------------------------------------------------------
module pcb_standoff_deck() {
    deck_z = 30;   // arbitrary axial position inside the tube - clear of both end caps
    translate([0, 0, deck_z])
        difference() {
            union() {
                // Deck tray (audit #33) - the plate the bosses stand on.
                translate([0, 0, -deck_thickness_mm])
                    intersection() {
                        cylinder(h = deck_thickness_mm, d = peg_diameter(hull_id_mm), $fn = 96);
                        translate([0, 0, deck_thickness_mm / 2])
                            cube([hull_id_mm + 2, 2 * deck_chord_half_mm,
                                  deck_thickness_mm + 2 * eps], center = true);
                    }
                for (s = standoffs)
                    translate([s[0] - board_width_mm / 2, s[1] - board_height_mm / 2, 0])
                        cylinder(h = standoff_height_mm, d = s[2] + 4, $fn = 24);
            }
            for (s = standoffs)
                translate([s[0] - board_width_mm / 2, s[1] - board_height_mm / 2, -eps])
                    cylinder(h = standoff_height_mm + 2 * eps, d = selftap_pilot_mm, $fn = 16);
                // ^ pilot hole for a self-tapping M3 into the printed
                // boss - not a heat-set insert here (small internal
                // standoff, low load, self-tap is standard practice for
                // light PCB mounting; heat-set inserts reserved for the
                // pressure-critical end-cap joint above). Pilot stops at
                // the deck top: the deck stays solid beneath the boss.
        }
}

// ----------------------------------------------------------------------------
// Full assembly of this variant (rendered when this file is opened directly)
// ----------------------------------------------------------------------------
module hull_5atm_assembly() {
    color("LightBlue", 0.9) hull_tube();
    color("Orange") translate([0, 0, -8]) end_cap(with_connectors = false);
    color("Orange") translate([0, 0, hull_length_mm + 8]) rotate([180, 0, 0]) end_cap(with_connectors = true);
    color("Green") pcb_standoff_deck();
}

hull_5atm_assembly();
