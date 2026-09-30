// dive-buddy pressure housing: standard HDPE (ПНД) electrofusion pipe + coupler
// Not the acrylic-tube-and-printed-flanges concept СинийМангустик.md floated,
// and not a metal (Al 6061) pressure vessel like rov-platform's - the real,
// user-confirmed chassis material is standard 110mm OD HDPE pressure pipe,
// joined section-to-section by electrofusion couplers, welded with the exact
// controller this repo already builds (welder-module/) and using the exact
// coupler-parameter barcode format it already decodes
// (welder-module/protocol/barcode_format.md - diameter field is literally
// "mm/10", i.e. this pipe's 110mm reads as barcode field "11").
//
// What's a real, catalog-verifiable standard here vs. what's parametrized as
// an open item (this sandbox has no network access to a specific
// manufacturer's coupler dimensional drawing - same class of gap as
// beacon_array/'s SubConn series selection):
//
// - pipe_od_mm = 110: user-confirmed, matches СинийМангустик.md's 90-110mm
//   range at its upper bound, matches welder-module's ISO 12176-4-style
//   barcode diameter field, matches welder-module/README.md's GOST citations
//   for PE pipe fittings. Real.
// - SDR (Standard Dimension Ratio) = pipe_od / wall_thickness is a real,
//   standardized PE-pipe designator (ISO 4065 / GOST 18599) - SDR11 (wall =
//   OD/11) is the common rating for pressurized water/gas HDPE pipe and is
//   used as the default here. SDR17 (thinner wall) is offered as the
//   low-pressure alternative. Both formulas are real; the SDR CHOICE for
//   this specific vehicle's actual depth rating was a Phase 2 (structural)
//   confirmation item - see depth_rating_analysis.md (DBHW-9): at SDR11,
//   sustained-load ring buckling (not material hoop stress) governs, with
//   a calculated ~35.6m equivalent-depth collapse pressure under the
//   long-term HDPE creep modulus - well short of the ~130-164m the
//   material-strength check alone would suggest. No target depth is
//   documented anywhere in this repo for dive-buddy, so this is a
//   capability characterization, not a pass/fail against a requirement.
// - Electrofusion coupler socket clearance (how much bigger the coupler ID
//   is than the pipe OD, so the pipe can be inserted before welding) is a
//   real, standardized allowance (ISO 12176 electrofusion practice: a few
//   tenths of a millimetre to under a millimetre) - coupler_socket_clearance_mm
//   below uses a representative, conservative value from that range.
// - Coupler body wall thickness/OD (how much bulkier the welded joint is
//   than the pipe itself) genuinely VARIES between manufacturers and
//   pressure classes - coupler_wall_mm is parametrized with a documented
//   representative value, flagged [UNVERIFIED - confirm against a sourced
//   coupler's real dimensional drawing before cutting the endcap flanges
//   that must clear it].
//
// Root CLAUDE.md's OpenSCAD conventions followed: print_tolerance for FDM-
// printed parts (the end-cap flanges, not the HDPE pipe/coupler itself,
// which are off-the-shelf/welded, not printed), eps for difference()
// z-fighting.

// Standard fitting geometry (equal_coupler and friends) lives in
// pe_fittings.scad, per ГОСТ Р 52779-2007's fitting family - use<> only
// imports its module/function definitions, not its own demo-render
// sweep (OpenSCAD's use vs. include distinction), so this file stays
// the single hull-assembly entry point.
use <pe_fittings.scad>

print_tolerance = 0.2;   // FDM assembly clearance, per root CLAUDE.md
eps = 0.01;              // difference() z-fighting guard, per root CLAUDE.md

// ---- Real, standard PE pipe geometry ----------------------------------
pipe_od_mm = 110;                    // user-confirmed
sdr = 11;                            // SDR11: common pressure-rated PE pipe
pipe_wall_mm = pipe_od_mm / sdr;     // = 10mm at SDR11 (real SDR formula)
pipe_id_mm = pipe_od_mm - 2 * pipe_wall_mm;

section_length_mm = 300;             // one hull section; vehicle-length
                                      // dependent, open item until dive-buddy's
                                      // overall length is fixed elsewhere

module pe_pipe_section(length = section_length_mm) {
    color("DarkOrange")
    difference() {
        cylinder(h = length, d = pipe_od_mm, center = false, $fn = 96);
        translate([0, 0, -eps])
            cylinder(h = length + 2 * eps, d = pipe_id_mm, center = false, $fn = 96);
    }
}

// ---- Avionics end cap ---------------------------------------------------
// Printed part (FDM), not welded - the pipe-side face is a plug that seats
// INSIDE the pipe's real ID with print_tolerance clearance (peg smaller
// than the hole it mates, per root CLAUDE.md's peg/hole formula), sealed
// by an O-ring groove rather than welded, since this end needs to open for
// servicing (unlike a welded mid-hull joint).
endcap_plug_depth_mm = 25;
oring_groove_depth_mm = 2.5;
oring_groove_width_mm = 4;

module avionics_endcap() {
    plug_od = pipe_id_mm - print_tolerance;  // peg < hole, per root CLAUDE.md
    flange_od = pipe_od_mm + 10;             // small lip beyond the pipe OD

    color("SlateGray")
    union() {
        // flange cap
        cylinder(h = 8, d = flange_od, center = false, $fn = 96);
        // plug that inserts into the pipe ID
        translate([0, 0, 8])
            difference() {
                cylinder(h = endcap_plug_depth_mm, d = plug_od, center = false, $fn = 96);
                // O-ring groove near the plug's leading face.
                // HARDWARE_AUDIT_2026-08-28 #13: the old subtraction removed
                // a full cylinder (d = plug_od - width) from the plug's core,
                // hollowing a buried internal void that never reached the
                // outer sealing surface. A groove must be an ANNULUS cut
                // into the outer face: full-od ring minus the groove root.
                translate([0, 0, endcap_plug_depth_mm - 8])
                    difference() {
                        cylinder(h = oring_groove_width_mm,
                                 d = plug_od + 2 * eps,
                                 center = false, $fn = 96);
                        translate([0, 0, -eps])
                            cylinder(h = oring_groove_width_mm + 2 * eps,
                                     d = plug_od - 2 * oring_groove_depth_mm,
                                     center = false, $fn = 96);
                    }
            }
    }
}

// Threaded explicitly (not relied on as a silently-matching default
// between this file and pe_fittings.scad's own coupler_length_mm) so the
// assembly's spacing and the fitting's own rendered length can never
// drift apart.
coupler_length_mm = 130;   // mirrors pe_fittings.scad's [UNVERIFIED] default

// ---- Two-section reference assembly (kept for the original DBHW-6
// smoke test / mechanical_check.py-style single-joint reasoning).
// Joint geometry (HARDWARE_AUDIT_2026-08-28 #12): pipe sections butt
// end-to-end and each coupler sleeve is centered over the butt joint,
// overlapping both pipe ends by coupler_length/2 — the way a real PE
// sleeve coupler actually works. The old math advanced the next pipe by
// a full coupler_length, which (combined with the coupler's old
// center=true origin) left a 65 mm open-to-the-sea gap at every joint.
module dive_buddy_hull_assembly() {
    pe_pipe_section();
    translate([0, 0, section_length_mm - coupler_length_mm/2])
        equal_coupler(od_mm = pipe_od_mm, length = coupler_length_mm);
    translate([0, 0, section_length_mm])
        pe_pipe_section();
    // HARDWARE_AUDIT_2026-08-28 #14: flip the cap so the plug enters the
    // pipe ID (it is authored flange-down, plug-up; un-rotated it would
    // rest its flange on the rim with the plug sticking into open air).
    translate([0, 0, 2 * section_length_mm + 8])
        rotate([180, 0, 0])
            avionics_endcap();
}

// ---- Full hull layout per section_layout.md: ESC/power - avionics -
// magnetometer - beacon-array/nose, joined by 3 real coupler fittings.
// Section lengths are `section_length_mm` placeholders (300mm each, an
// open item until real Pi/Pixhawk/battery/ESC dimensions are known - see
// section_layout.md's "still open" list) - equipment itself is NOT
// modeled inside each section, only the hull tube + joints, which is
// what this pass actually resolved (axial vs. radial separation, which
// section holds what).
// Same audit-#12 joint geometry as dive_buddy_hull_assembly(): butt
// joints at each section boundary, coupler sleeve centered over each.
module dive_buddy_full_hull_assembly() {
    z = 0;
    // ESC / power section (high-current source)
    translate([0, 0, z]) pe_pipe_section();
    z1 = z + section_length_mm;                 // joint 1
    translate([0, 0, z1 - coupler_length_mm/2])
        equal_coupler(od_mm = pipe_od_mm, length = coupler_length_mm);

    // Avionics section: Pixhawk 6C + companion Pi
    translate([0, 0, z1]) pe_pipe_section();
    z3 = z1 + section_length_mm;                // joint 2
    translate([0, 0, z3 - coupler_length_mm/2])
        equal_coupler(od_mm = pipe_od_mm, length = coupler_length_mm);

    // Magnetometer section - axially separated from the ESC/power
    // section by the full avionics section + 2 coupler joints
    translate([0, 0, z3]) pe_pipe_section();
    z5 = z3 + section_length_mm;                // joint 3
    translate([0, 0, z5 - coupler_length_mm/2])
        equal_coupler(od_mm = pipe_od_mm, length = coupler_length_mm);

    // Beacon-array / nose section, ending in the serviceable avionics
    // endcap (nearest the 3 SubConn hydrophone penetrators)
    translate([0, 0, z5]) pe_pipe_section();
    z7 = z5 + section_length_mm;
    // Audit #14: same plug-inward flip as in dive_buddy_hull_assembly().
    translate([0, 0, z7 + 8]) rotate([180, 0, 0]) avionics_endcap();
}

dive_buddy_full_hull_assembly();
