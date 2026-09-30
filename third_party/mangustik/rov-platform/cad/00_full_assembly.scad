// ============================================================================
// DiveGuard heavy-class ROV - FULL ASSEMBLY (rov-platform/HLD.md, all 6
// mechanical phases)
//
// IMPORTANT - READ BEFORE TRUSTING ANY NUMBER IN THIS FILE:
//
// The 12 individual part files (01-12) were each authored independently in
// the original design dialogue (pasted into BACKLOG.md on main, 2026-08
// batch) with their OWN ad hoc local coordinate origin - the dialogue never
// established a shared assembly coordinate system, and no inter-part mounting
// dimension (rail spacing vs. hull diameter, thruster standoff, buoyancy
// offset from centerline, etc.) was ever specified anywhere in the source
// material. Every translate()/rotate() below is therefore this session's
// best-effort geometric placement, reverse-engineered from:
//   (a) each part's own stated real-world dimensions (frame envelope,
//       hull diameter/length, rail position) - these ARE real numbers from
//       the source dialogue, and
//   (b) each part's stated real-world role/mounting description in
//       rov-platform/HLD.md (e.g. "manipulator mounts on the front lower
//       frame", "vertical thrusters integrate into deck wells") - these are
//       real constraints, but the exact millimeter offset satisfying them
//       is this session's placement choice, not a value taken from source.
//
// This file exists to (1) give a first visual sense of the whole ROV and
// (2) let a real OpenSCAD/CAD session check for gross interferences (parts
// overlapping) before real engineering starts - it is explicitly NOT a
// certified assembly.
//
// Update 2026-08-08: OpenSCAD IS available in this sandbox (installed via
// apt for this verification pass; previously assumed unavailable, that
// assumption was wrong, corrected repo-wide - see BACKLOG.md). This file has
// been rendered (preview PNG, several camera angles) and the hull/aux-tube
// interference it originally had was found and fixed this way - see the
// per-part notes below for exactly what was found and how it was corrected.
// A full manifold STL render of *this* file (unioning all 11 parts) was
// attempted and timed out (~2 min) - the individual parts are each confirmed
// valid manifolds (see their own file headers), but a merged CSG boolean
// across all 11 was not completed in this pass. Isolated 2-3-part renders
// were used instead to verify each fix precisely (see commit history for the
// exact render commands). Not yet done: bolt patterns, thruster
// count/vector layout, and an engineer sign-off - still real, open items.
//
// Global frame convention chosen for this assembly (not specified in source):
//   +X = bow (forward), -X = stern (aft)
//   +Y = starboard (right), -Y = port (left)
//   +Z = up
//   Origin = geometric center of 01_main_chassis_frame's envelope.
//
// Excluded from this file: 12_fasteners_clamps_dampers.scad - that file is
// an illustrative component catalog (pipe clamp, damper washer, cable gland
// samples laid out for viewing, not real mounting locations), not placed
// assembly geometry - see its own header.
// ============================================================================

use <01_main_chassis_frame.scad>
use <02_main_pressure_hull_port.scad>
use <03_main_pressure_hull_starboard.scad>
use <04_auxiliary_sensor_tubes_top.scad>
use <05_propulsion_horizontal_module.scad>
use <06_propulsion_vertical_module.scad>
use <07_buoyancy_and_ballast_system.scad>
use <08_sensor_and_camera_skid_front.scad>
use <09_manipulator_and_tool_interface.scad>
use <10_tether_rigging_and_protection_bars.scad>
use <11_central_control_pdb_module.scad>

// ----------------------------------------------------------------------------
// 01 - Frame. Reference geometry - everything else is positioned against its
// real, stated envelope: 1200x800x500mm overall, top mounting rails at
// z=150, y=+-100 (see chassis_frame()'s own translate([0,+-100,150]) rail
// cubes), bottom skids at z=-250.
// ----------------------------------------------------------------------------
chassis_frame();

// ----------------------------------------------------------------------------
// 02/03 - Main pressure hulls. Real dimensions: ⌀200mm (r=100), 800mm long,
// built in their own files along their LOCAL Z axis (0..800).
// PLACEMENT-CONFIDENCE: medium. rotate([0,90,0]) maps local Z onto global X
// (hull runs fore-aft, matching "main hulls mount along the frame's rails" -
// HLD.md Phase 1). Centered fore-aft (x: -400..400) inside the frame's
// 1200mm length, leaving 200mm clear at each end for the bow skid (08) and
// stern tether assembly (10) - a real choice, not a source-given number.
//
// REAL INTERFERENCE FOUND AND FIXED (2026-08-08, first OpenSCAD render pass
// in this sandbox - openscad installed via apt for this verification, see
// BACKLOG.md): y=+-100 (directly over the frame's rails, which are at
// y=+-100 in 01_main_chassis_frame.scad) puts two 200mm-diameter hulls'
// centers exactly 200mm apart - zero clearance, confirmed touching in a
// rendered end-on PNG (isolated 2-hull cross-section view). That is a real
// defect in the *source* frame geometry (rail spacing == hull diameter, no
// source-specified clearance) that this placement inherited, not something
// invented here. Fixed by widening to y=+-130, confirmed by re-render -
// visibly separated - sitting 30mm outboard of each rail centerline in a
// wider cradle. CORRECTION (2026-08-08, blind-spot audit): this comment
// originally claimed "100mm clear gap between hull surfaces" - that's
// arithmetically wrong. Centers 260mm apart (130-(-130)) minus two 100mm
// radii = 60mm surface-to-surface gap, not 100mm. Still a real, positive,
// non-interfering clearance (confirmed by the original render and by an
// `intersection()` emptiness check redone during this correction), just
// mislabeled - no geometry changed, only the arithmetic in this comment.
// This is a placement fix, not a claim that 01_main_chassis_frame.scad's
// rail geometry itself is correct; a real design pass should widen the
// rails (or accept hulls sitting outboard of them in a bracket) rather than
// silently rely on this offset. Flagged in rov-platform/HLD.md.
// z=250 (rail top ~156 + hull radius 100, rounded) is a placement guess for
// "hull sits in a saddle cradle above the rail" - the source never specifies
// the cradle height or whether hulls sit above/beside the rails.
// ----------------------------------------------------------------------------
translate([-400, -130, 250]) rotate([0, 90, 0]) pressure_hull_port();
translate([-400, 130, 250]) rotate([0, 90, 0]) pressure_hull_starboard();

// ----------------------------------------------------------------------------
// 04 - Auxiliary sensor tube (hydrophone/telemetry). Real dimensions:
// ⌀100mm (r=50), 400mm long, local Z axis like the hulls.
// PLACEMENT-CONFIDENCE: low. Positioned centered (x: -200..200) on the
// vehicle centerline (y=0), above both hulls - "auxiliary TOP module" in its
// own name/HLD wording is the only real anchor; the exact height/centering
// is this session's choice.
//
// REAL INTERFERENCE FOUND AND FIXED (2026-08-08, same render pass as above):
// the original z=380 put the tube's bottom edge (380-50=330) *below* the
// hulls' top surface (center 250 + radius 100 = 350) - a 20mm overlap,
// confirmed visibly embedded in the hull in a rendered end-on PNG. Fixed to
// z=440 (tube bottom at 390, a real 40mm clearance above the hulls' z=350
// top surface) - re-rendered end-on and confirmed a clean visible gap.
// ----------------------------------------------------------------------------
translate([-200, 0, 440]) rotate([0, 90, 0]) auxiliary_sensor_tube();

// ----------------------------------------------------------------------------
// 11 - Central control/PDB module. Real dimension: 180x140x60mm box,
// centered at its own local origin.
//
// REAL INTERFERENCE FOUND AND FIXED (2026-08-08, blind-spot audit +
// isolated-render verification): the original translate([0,0,180]) put this
// part's local Y-extent (140mm wide, -70..70) and Z-extent (-30..34, so
// global z:150..214) overlapping BOTH main hulls - at y=70 (this part's own
// edge), hull-port (center y=130,z=250,r=100) reaches down to z=170, well
// inside this part's z:150..214 span. Root cause: HLD.md Phase 2's "mounts
// between the two main hulls" reads as "in the horizontal gap between the
// hull surfaces," but that gap is only 60mm wide (see the hull note above)
// and this part is 140mm wide on that axis - it structurally cannot fit
// there at any Z. Not a translate()-offset bug, a real footprint-vs-gap
// conflict; re-orienting/resizing the part to genuinely slot into a 60mm
// channel is a real design decision, not attempted here.
// Fixed instead by relocating the module ABOVE both the hulls and the
// auxiliary sensor tube (04) - z=560 clears the hulls' highest reach
// (z=330 at this part's y=+-70 edges) and the aux tube's top surface
// (z=490) with real margin. Verified empty with a real OpenSCAD
// `intersection()` against hull-port, hull-starboard, the aux tube, and
// 01_main_chassis_frame.scad at this position (all four returned "Current
// top level object is empty" - genuinely no overlap, not just eyeballed).
// PLACEMENT-CONFIDENCE: low (moved off the HLD text's literal "between the
// hulls" wording to resolve a real geometric impossibility - a full design
// pass should decide whether to re-orient/shrink the PDB module for a true
// between-hulls fit instead of a deck-top mount). Flagged in HLD.md.
// ----------------------------------------------------------------------------
translate([0, 0, 560]) central_control_unit();

// ----------------------------------------------------------------------------
// 05 - Horizontal (marine/turn) thrusters. Real dimension: duct r=58,
// h=120 along local Z. HLD.md: "продольного перемещения и разворотов"
// (forward motion + turning) - placed as a port/starboard pair at the
// stern, outboard of the hulls.
// PLACEMENT-CONFIDENCE: low. Count (2), stern position (x=-500), and
// outboard offset (y=+-300, clearing the hulls' +-100 by 200mm) are all
// this session's placement choices - the source dialogue gives the single
// unit's own dimensions but never a vehicle-level thruster count or layout.
// A real 6-DOF thruster layout (how many, what vector angles) is flagged
// as an open item in rov-platform/HLD.md Phase 3 - not resolved here.
// ----------------------------------------------------------------------------
translate([-500, -300, 0]) rotate([0, 90, 0]) horizontal_thruster_module();
translate([-500, 300, 0]) rotate([0, 90, 0]) horizontal_thruster_module();

// ----------------------------------------------------------------------------
// 06 - Vertical/lateral thrusters. Built already oriented along local Z
// (deck flange at top, prop at bottom) - "интегрированы в сквозные шахты
// верхней палубы рамы" (integrated into through-deck wells), so no
// rotation, just positioned at deck level.
//
// REAL INTERFERENCE FOUND AND FIXED (2026-08-08, blind-spot audit +
// isolated-render verification): at z=150, the deck-flange cube
// (90x90mm, corner reach sqrt(45^2+45^2)=63.6mm from the thruster's own
// axis) clipped both main hulls - at both units' own +Y edge (y=45, the
// flange's edge nearest the hulls on the centerline-mounted units), the
// hull's disk (center y=130 or -130, z=250, r=100) reaches down to
// z~197.3, overlapping the flange's z:190..200 span by ~2-3mm.
// Confirmed by a real OpenSCAD `intersection()` (non-empty, real facets)
// against both hulls at z=150 for both units (x=400 and x=-350).
// Fixed by lowering to z=140 (10mm) - re-verified with the same
// `intersection()` check against both hulls AND 01_main_chassis_frame.scad:
// all four returned "Current top level object is empty."
// PLACEMENT-CONFIDENCE: low. Only 2 units placed here (bow/stern on
// centerline, for pitch/depth authority) - a full 6-DOF vertical/lateral
// set (4 units, port+starboard pairs fore/aft, for combined
// depth+roll+strafe control) is the more complete real design and is
// flagged as an open item in rov-platform/HLD.md Phase 3, not resolved
// here to avoid asserting a thruster count the source never specified.
// ----------------------------------------------------------------------------
translate([400, 0, 140]) vertical_thruster_module();
translate([-350, 0, 140]) vertical_thruster_module();

// ----------------------------------------------------------------------------
// 07 - Buoyancy/ballast. Real dimension: ~900mm cylindrical core + ~80mm
// fairings each end (~1060mm total), r=55, centered at local origin along
// local Z. Placed as a port/starboard pair along the lower frame, running
// fore-aft (rotated like the hulls), below the bottom skid line (z=-250)
// per "желтые цилиндрические элементы... в нижней части рамы" (yellow
// cylindrical elements in the frame's lower section, from the source's own
// framing text).
// PLACEMENT-CONFIDENCE: low. y=+-250 (between the hull centerline y=+-100
// and the skid rail y=+-400) and z=-280 are placement choices; Phase 4's
// real DoD is re-sizing/re-positioning this against the actual dry mass of
// every other part once real CAD masses exist (see HLD.md Phase 4) - this
// placement is explicitly a placeholder pending that.
// ----------------------------------------------------------------------------
translate([0, -250, -280]) rotate([0, 90, 0]) buoyancy_module();
translate([0, 250, -280]) rotate([0, 90, 0]) buoyancy_module();

// ----------------------------------------------------------------------------
// 08 - Front sensor skid (camera/sonar). Built with its own local +X
// pointing "forward" (camera viewport at local x=81) - placed at the bow,
// forward of the hull span (hulls end at x=400).
// PLACEMENT-CONFIDENCE: medium (bow position is source-given via HLD.md
// Phase 5; exact standoff x=500 and height z=50 are placement choices).
// ----------------------------------------------------------------------------
translate([500, 0, 50]) front_sensor_skid();

// ----------------------------------------------------------------------------
// 09 - Manipulator interface plate. HLD.md/source: "крепится на переднюю
// нижнюю часть рамы" (mounts on the front lower part of the frame) -
// placed at the bow, low (near the z=-250 skid line, with clearance).
// PLACEMENT-CONFIDENCE: medium (front-lower is source-given; exact
// standoff is a placement choice). NOT checked for interference against
// 08's skid or the bow bumper arches from 01 - a real concern given both
// are bow-mounted, flagged for the real CAD pass.
// ----------------------------------------------------------------------------
translate([500, 0, -200]) manipulator_interface_plate();

// ----------------------------------------------------------------------------
// 10 - Tether/rigging (stern umbilical + lifting eyes). This module's OWN
// internal geometry already uses stern-relative local coordinates
// (x=-530..-580 inside the file, apparently authored assuming its local
// origin sits near a hull's own coordinate space) rather than being
// centered at its local origin like the other parts.
// PLACEMENT-CONFIDENCE: LOW (lowest of any part in this assembly). The
// translate below is a small corrective offset, not a derived dimension -
// re-deriving this module's real position relative to the frame's actual
// x=-600 stern face needs a real CAD session, not arithmetic against
// prose. Treat this placement as "roughly at the stern," not as a
// dimension.
// ----------------------------------------------------------------------------
translate([-50, 0, 150]) tether_and_rigging_assembly();
