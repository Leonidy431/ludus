// ============================================================================
// Mangustik welder-module d110 housing assembly — modular pipe-based enclosure
// ============================================================================
// Rebuilt per HARDWARE_AUDIT_2026-08-28 #1/#6: the previous version used
// `use <lib_d110.scad>` (all layout constants undef), left 20 mm air gaps in
// the spine, and attached branch elbows directly onto the middle of pipes —
// a joint that cannot exist in electrofusion practice. This version:
//   - `include`s the library (constants imported);
//   - every pipe/fitting joint overlaps by exactly SOCKET_DEPTH (55 mm)
//     electrofusion engagement — no air gaps, no mid-pipe attachments;
//   - branches leave ONLY through real tee branch sockets (one per tee).
// Elbows remain library parts exercised by elbow90_d110.scad.
//
// Units: millimetres throughout.

include <lib_d110.scad>

WALL_THICKNESS = WALL_SDR17;

// ---- Derived spine layout (all joints = SOCKET_DEPTH engagement) ----------
// bottom pipe:   0 .. 200
// lower tee:     145 .. 270   (bottom socket swallows pipe top 55)
// middle pipe:   215 .. 365   (enters lower-tee top socket 55)
// upper tee:     310 .. 435   (bottom socket swallows pipe top 55)
// top pipe:      380 .. 480   (enters upper-tee top socket 55)
// top cap:       425 .. 480+  (socket swallows pipe top 55)
BOTTOM_PIPE_LEN = 200;
MIDDLE_PIPE_LEN = 150;
TOP_PIPE_LEN    = 100;
BRANCH_PIPE_LEN = 200;

z_tee_lo   = BOTTOM_PIPE_LEN - SOCKET_DEPTH;                    // 145
z_mid_pipe = z_tee_lo + tee_run_length() - SOCKET_DEPTH;        // 215
z_tee_hi   = z_mid_pipe + MIDDLE_PIPE_LEN - SOCKET_DEPTH;       // 310
z_top_pipe = z_tee_hi + tee_run_length() - SOCKET_DEPTH;        // 380
z_top_cap  = z_top_pipe + TOP_PIPE_LEN - SOCKET_DEPTH + 1;      // 426 (1 mm shy of full engagement so the pipe end face is not coplanar with the cap dome base)

branch_mouth = SOCKET_DEPTH + fitting_od(FITTING_WALL)/2;       // 120 from axis
branch_pipe_start = fitting_od(FITTING_WALL)/2;                 // 65 from axis
branch_cap_start  = branch_pipe_start + BRANCH_PIPE_LEN - SOCKET_DEPTH + 1; // 211 (same 1 mm anti-coplanarity offset)

// Colors for assembly visualization (RGBA, 0-1 range)
color_pipe     = [0.3, 0.3, 0.3, 0.8];
color_fitting  = [0.2, 0.2, 0.2, 0.9];
color_cap      = [0.4, 0.1, 0.1, 0.8];
color_junction = [0.1, 0.1, 0.4, 0.8];

module housing_assembly() {
    // ---- VERTICAL SPINE (main axis Z) ----
    color(color_pipe)
        pipe_segment(length=BOTTOM_PIPE_LEN, wall=WALL_THICKNESS);

    // Lower tee: branch socket along +X
    color(color_junction)
        translate([0, 0, z_tee_lo])
            rotate([0, 0, -90])   // +Y branch -> +X
                tee(wall=FITTING_WALL);

    color(color_pipe)
        translate([0, 0, z_mid_pipe])
            pipe_segment(length=MIDDLE_PIPE_LEN, wall=WALL_THICKNESS);

    // Upper tee: branch socket along -X
    color(color_junction)
        translate([0, 0, z_tee_hi])
            rotate([0, 0, 90])    // +Y branch -> -X
                tee(wall=FITTING_WALL);

    color(color_pipe)
        translate([0, 0, z_top_pipe])
            pipe_segment(length=TOP_PIPE_LEN, wall=WALL_THICKNESS);

    color(color_cap)
        translate([0, 0, z_top_cap])
            cap(wall=FITTING_WALL);

    // ---- BRANCH A (lower tee, along +X) ----
    branch_z_lo = z_tee_lo + tee_run_length()/2;
    color(color_pipe)
        translate([branch_pipe_start, 0, branch_z_lo])
            rotate([0, 90, 0])
                pipe_segment(length=BRANCH_PIPE_LEN, wall=WALL_THICKNESS);
    color(color_cap)
        translate([branch_cap_start, 0, branch_z_lo])
            rotate([0, 90, 0])
                cap(wall=FITTING_WALL);

    // ---- BRANCH B (upper tee, along -X) ----
    branch_z_hi = z_tee_hi + tee_run_length()/2;
    color(color_pipe)
        translate([-branch_pipe_start, 0, branch_z_hi])
            rotate([0, -90, 0])
                pipe_segment(length=BRANCH_PIPE_LEN, wall=WALL_THICKNESS);
    color(color_cap)
        translate([-branch_cap_start, 0, branch_z_hi])
            rotate([0, -90, 0])
                cap(wall=FITTING_WALL);
}

// Render the complete assembly
housing_assembly();

// Optional: Transparent bounding box for reference
%translate([0, 0, 250])
    cube([600, 200, 500], center=true);
