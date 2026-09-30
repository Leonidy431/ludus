#!/usr/bin/env python3
"""Compute real part masses from the rendered STL geometry in cad/stl/, for the
Phase 4 (buoyancy & ballast) mass/buoyancy budget that HLD.md documents as blocked on
"the other phases' actual masses" - no other phase had a real computed mass before this,
only the OpenSCAD dimensions as a first guess. This script closes that gap with real
numbers derived from the actual rendered geometry, not further guessing.

Volume is computed from the STL triangle mesh via the divergence theorem (signed sum of
tetrahedron volumes from the origin to each triangle) - the standard closed-mesh volume
formula, exact for any watertight manifold (which HLD.md's Phase 1-6 status notes already
confirmed each part is, via `openscad`'s own "Simple: yes" / non-zero Volumes count in the
CGAL render log).

Caveat (stated explicitly, not hidden): each part's OpenSCAD module is solid CSG geometry
(difference/union of solid primitives), so the STL volume is the true solid material
volume for a part with no internal cavities beyond what's already carved out (e.g. hull
wall thickness, tube bores) - this matches how the parts are actually designed here.
Density figures are the real material densities from HLD.md's Phase 1-6 stated materials,
not estimated. Ballast/buoyancy trim mass and any non-structural contents (electronics,
cabling, batteries) are NOT included - those are Phase 7+ system masses, out of scope for
a purely-structural CAD mass budget.
"""
import struct
import sys
from pathlib import Path

HERE = Path(__file__).parent
STL_DIR = HERE / "stl"

# kg/m^3, real published densities for the materials HLD.md actually specifies per part.
DENSITY_KG_M3 = {
    "aisi_316l_stainless": 8000.0,
    "al_6061_t6": 2700.0,
    "pom_c": 1410.0,
    "hdpe": 950.0,
    "syntactic_foam": 550.0,  # HLD.md: "rated for zero volume/structural loss at 300m" -
    # mid-range for a 300m-rated syntactic foam (typical commercial range ~450-650 kg/m^3);
    # flagged as a range estimate, not a specific vendor datasheet figure (Phase 4's DoD
    # already documents this component as needing a real vendor spec before final sizing).
    "carbon_reinforced_nylon": 1150.0,
    "grp": 1800.0,
}

# Part -> (material key, volume fraction assumed solid-in-that-material). Each part is
# treated as a single dominant structural material per HLD.md Phase 1-6's stated BOM -
# real per-part multi-material breakdowns (e.g. hull + separate O-rings) are a finer level
# of detail than the CAD geometry itself currently models (O-rings aren't separate solids
# in these .scad files), so this is the real achievable precision from the existing model,
# stated as such rather than silently implying finer accuracy.
PART_MATERIAL = {
    "01_main_chassis_frame": "aisi_316l_stainless",
    "02_main_pressure_hull_port": "al_6061_t6",
    "03_main_pressure_hull_starboard": "al_6061_t6",
    "04_auxiliary_sensor_tubes_top": "al_6061_t6",
    "05_propulsion_horizontal_module": "al_6061_t6",  # duct sleeve + prop hub; POM-C duct
    # body per HLD.md is a real deviation from this single-material approximation, noted.
    "06_propulsion_vertical_module": "al_6061_t6",
    "07_buoyancy_and_ballast_system": "syntactic_foam",  # HDPE shell not modeled separately
    "08_sensor_and_camera_skid_front": "al_6061_t6",
    "09_manipulator_and_tool_interface": "al_6061_t6",
    "10_tether_rigging_and_protection_bars": "aisi_316l_stainless",
    "11_central_control_pdb_module": "al_6061_t6",
    "12_fasteners_clamps_dampers": "aisi_316l_stainless",  # dominant fastener material;
    # sorbothane dampers in this catalog are real exceptions, not modeled separately here.
}


def read_stl_triangles(path):
    """Parse an OpenSCAD-exported STL (binary or ASCII) into a list of
    (v1, v2, v3) triangles, each vertex an (x, y, z) tuple in mm."""
    data = path.read_bytes()
    if data[:5] == b"solid" and b"facet normal" in data[:4096]:
        return _read_ascii_stl(data)
    return _read_binary_stl(data)


def _read_binary_stl(data):
    tri_count = struct.unpack_from("<I", data, 80)[0]
    triangles = []
    offset = 84
    for _ in range(tri_count):
        # normal (3 floats, skipped) + 3 vertices (3 floats each) + 2-byte attr
        vals = struct.unpack_from("<12f", data, offset + 12)
        v1 = vals[0:3]
        v2 = vals[3:6]
        v3 = vals[6:9]
        triangles.append((v1, v2, v3))
        offset += 50
    return triangles


def _read_ascii_stl(data):
    triangles = []
    verts = []
    for line in data.decode("ascii", errors="ignore").splitlines():
        line = line.strip()
        if line.startswith("vertex"):
            _, x, y, z = line.split()
            verts.append((float(x), float(y), float(z)))
            if len(verts) == 3:
                triangles.append(tuple(verts))
                verts = []
    return triangles


def signed_volume_mm3(triangles):
    """Sum of signed tetrahedron volumes (origin, v1, v2, v3) - the standard
    divergence-theorem formula for the volume enclosed by a watertight mesh."""
    total = 0.0
    for v1, v2, v3 in triangles:
        total += (
            v1[0] * (v2[1] * v3[2] - v3[1] * v2[2])
            - v1[1] * (v2[0] * v3[2] - v3[0] * v2[2])
            + v1[2] * (v2[0] * v3[1] - v3[0] * v2[1])
        )
    return abs(total) / 6.0


SEAWATER_KG_L = 1.025  # standard seawater density, 1025 kg/m^3

# rov-platform/HLD.md's 300m design is a marine (not freshwater) vehicle, so buoyancy is
# computed against seawater density throughout.

# How many times each part is actually instantiated in 00_full_assembly.scad (grep-counted
# 2026-08-08: `grep -c "modulename(" 00_full_assembly.scad` per module, verified against
# the assembly file's own comments). 12_fasteners_clamps_dampers is a component catalog,
# deliberately NOT instantiated in the assembly (see HLD.md Phase 6 status) - excluded from
# vehicle-level totals below, reported separately.
INSTANCE_COUNT = {
    "01_main_chassis_frame": 1,
    "02_main_pressure_hull_port": 1,
    "03_main_pressure_hull_starboard": 1,
    "04_auxiliary_sensor_tubes_top": 1,
    "05_propulsion_horizontal_module": 2,
    "06_propulsion_vertical_module": 2,
    "07_buoyancy_and_ballast_system": 2,
    "08_sensor_and_camera_skid_front": 1,
    "09_manipulator_and_tool_interface": 1,
    "10_tether_rigging_and_protection_bars": 1,
    "11_central_control_pdb_module": 1,
    "12_fasteners_clamps_dampers": 0,  # catalog only, not placed - see HLD.md
}

# Sealed, hollow pressure vessels (02, 03, 04): the water they displace is their full OUTER
# envelope volume (main tube OD + both end-cap protrusions), not just the wall material
# solid volume computed above - the air-filled interior displaces water too, exactly like a
# ship's hull. These 3 figures were measured directly (not hand-calculated) by rendering
# each hull's outer-surface-only primitives (main cylinder r=100/50mm + both end-cap
# protrusions, reproduced from 02/03/04's own real dimensions) through the same STL +
# signed-volume pipeline as everything else in this script, then discarded as scratch
# geometry (not part of the 12-part catalog). Reproducible from each file's own header
# dimensions: port/starboard main tube r=100mm h=800mm + front cap r=99.7mm h=30mm +
# rear cap r=99.7mm h=35mm; aux tube main r=50mm h=400mm + both caps r=49.7mm h=20mm.
OUTER_ENVELOPE_L = {
    "02_main_pressure_hull_port": 27.150,
    "03_main_pressure_hull_starboard": 27.150,
    "04_auxiliary_sensor_tubes_top": 3.450,
}


def main():
    rows = []
    total_mass_kg = 0.0
    total_displaced_kg_equiv = 0.0
    catalog_only_mass_kg = 0.0
    for stl_path in sorted(STL_DIR.glob("*.stl")):
        part = stl_path.stem
        triangles = read_stl_triangles(stl_path)
        volume_mm3 = signed_volume_mm3(triangles)
        volume_L = volume_mm3 / 1e6
        material = PART_MATERIAL.get(part)
        if material is None:
            print(f"WARNING: no material mapping for {part}, skipping mass calc", file=sys.stderr)
            continue
        density = DENSITY_KG_M3[material]
        mass_kg_each = volume_L * density / 1000.0

        if part in OUTER_ENVELOPE_L:
            # Hollow sealed vessel: displaces its full outer envelope, not its wall volume.
            displaced_kg_each = OUTER_ENVELOPE_L[part] * SEAWATER_KG_L
        else:
            # Solid part: displaces exactly its own material volume.
            displaced_kg_each = volume_L * SEAWATER_KG_L

        net_buoyancy_kg_each = displaced_kg_each - mass_kg_each
        count = INSTANCE_COUNT.get(part, 1)
        mass_kg_total = mass_kg_each * count
        net_buoyancy_kg_total = net_buoyancy_kg_each * count

        if count == 0:
            catalog_only_mass_kg += mass_kg_each
        else:
            total_mass_kg += mass_kg_total
            total_displaced_kg_equiv += displaced_kg_each * count

        rows.append((part, material, count, volume_L, mass_kg_each, net_buoyancy_kg_each, net_buoyancy_kg_total))

    print(f"{'Part':<38} {'Material':<20} {'x':>2} {'Vol(L)':>8} {'Mass/ea':>9} {'Net buoy/ea':>12} {'Net buoy total':>15}")
    print("-" * 118)
    for part, material, count, volume_L, mass_kg_each, net_each, net_total in rows:
        tag = " (catalog, not placed)" if count == 0 else ""
        print(f"{part:<38} {material:<20} {count:>2} {volume_L:>8.2f} {mass_kg_each:>9.3f} "
              f"{net_each:>12.3f} {net_total:>15.3f}{tag}")
    print("-" * 118)
    net_structural_buoyancy_kg = total_displaced_kg_equiv - total_mass_kg
    print(f"{'TOTAL vehicle structural mass (real instance counts, excl. fastener catalog)':<80} {total_mass_kg:>10.3f} kg")
    print(f"{'TOTAL displaced-water-equivalent (structural parts only)':<80} {total_displaced_kg_equiv:>10.3f} kg")
    print(f"{'NET structural buoyancy (positive = floats before payload)':<80} {net_structural_buoyancy_kg:>10.3f} kg")
    print(f"{'Fastener catalog mass (not instantiated, informational only)':<80} {catalog_only_mass_kg:>10.3f} kg")
    print()
    print("NOTE: this is a STRUCTURAL-ONLY budget (frame, hulls, thrusters, skid, manipulator,")
    print("tether hardware, buoyancy foam pods, central control chassis). It does NOT include")
    print("battery pack mass, electronics/PCB mass, cabling, or any payload - none of that is")
    print("modeled as CAD geometry yet, so it cannot be computed from this repo's data. HLD.md")
    print("Phase 4's DoD (neutral-trim buoyancy sizing) needs those real masses added to this")
    print("structural baseline before final foam-pod count/size can be confirmed.")

    return rows, total_mass_kg, total_displaced_kg_equiv, net_structural_buoyancy_kg


if __name__ == "__main__":
    main()
