"""Write godot/tests/fixtures/volumetric_fixture.json for VolumetricCore.

Source of the numbers: the operator's repo
Leonidy431/laser_buble_monitor_control, commit 2a468ba, file
backend/app/modules/volumetric/voxel_mapper.py
(gradients, ranges, interpolation, sparse fill) and bubble_generator.py
(surface tension constants, Minnaert formula).

Importing the module is impractical here because it pulls pydantic and
loguru, so the script reads the gradient constants out of the source file
with ``ast`` and falls back to a verbatim copy when the repo is absent.
The interpolation is copied from VoxelMapper._interpolate_gradient and
keeps Python's banker's rounding, which the GDScript port must match.

Constitution: FORM (the operator's gradients) -> ACTION (the port is
checked number by number) -> GOAL (a screen that shows only what the
repo's code can show).
"""
import ast
import json
import math
import os

REPO = "/home/user/leonidy431/laser_buble_monitor_control"
SOURCE = os.path.join(
    REPO, "backend/app/modules/volumetric/voxel_mapper.py")
OUT = os.path.join(
    os.path.dirname(__file__), "..", "..", "godot", "tests", "fixtures",
    "volumetric_fixture.json")

# Verbatim copy of the source constants (commit 2a468ba), used only when
# the operator's repo is not cloned on this machine.
_FALLBACK = {
    "_TEMPERATURE_GRADIENT": [(0.0, (30, 60, 220)), (0.5, (60, 200, 120)),
                              (1.0, (220, 50, 40))],
    "_OXYGEN_GRADIENT": [(0.0, (200, 30, 30)), (0.5, (230, 200, 40)),
                         (1.0, (40, 200, 90))],
    "_TEMPERATURE_RANGE_C": (0.0, 30.0),
    "_OXYGEN_RANGE_PPM": (0.0, 12.0),
}


def load_constants():
    """Read the gradient constants from the source file if present."""
    if not os.path.exists(SOURCE):
        return dict(_FALLBACK), "fallback copy"
    found = {}
    with open(SOURCE, encoding="utf-8") as handle:
        tree = ast.parse(handle.read())
    for node in tree.body:
        if isinstance(node, ast.Assign):
            name = node.targets[0].id
            if name in _FALLBACK:
                found[name] = ast.literal_eval(node.value)
    return found, SOURCE


def clamp_fraction(value, low, high):
    if high <= low:
        return 0.0
    return max(0.0, min(1.0, (value - low) / (high - low)))


def interpolate(fraction, gradient):
    """Copy of VoxelMapper._interpolate_gradient."""
    for (stop_a, col_a), (stop_b, col_b) in zip(gradient, gradient[1:]):
        if stop_a <= fraction <= stop_b:
            span = stop_b - stop_a
            t = 0.0 if span == 0 else (fraction - stop_a) / span
            return [round(a + (b - a) * t) for a, b in zip(col_a, col_b)]
    return list(gradient[-1][1])


def minnaert_um(f_khz, depth_m, salinity):
    """Minnaert radius with ambient pressure growing with depth."""
    rho = 998.0 + (1025.0 - 998.0) * salinity / 35.0
    p0 = (1.01325 + depth_m / 10.2) * 1e5
    f = f_khz * 1000.0
    return (1 / (2 * math.pi * f)) * math.sqrt(3 * 1.4 * p0 / rho) * 1e6


def tension(salinity):
    t = max(0.0, min(1.0, salinity / 35.0))
    return 0.0728 + (0.0679 - 0.0728) * t


def column_frame(layers, metric, grid, gradient, low, high):
    """Same loops as VoxelMapper.frame_from_water_column."""
    width, depth, height = grid
    voxels = []
    for frac, value in layers:
        z = round(frac * (height - 1))
        rgb = interpolate(clamp_fraction(value, low, high), gradient)
        for x in range(0, width, 4):
            for y in range(0, depth, 4):
                voxels.append([x, y, z] + rgb)
    return voxels


def cloud_frame(points, color, grid):
    width, depth, height = grid
    return [[round(px * (width - 1)), round(py * (depth - 1)),
             round(pz * (height - 1))] + list(color)
            for px, py, pz in points]


def main():
    const, where = load_constants()
    temp_g = const["_TEMPERATURE_GRADIENT"]
    oxy_g = const["_OXYGEN_GRADIENT"]
    t_lo, t_hi = const["_TEMPERATURE_RANGE_C"]
    o_lo, o_hi = const["_OXYGEN_RANGE_PPM"]
    fixture = {
        "source": {"repo": "Leonidy431/laser_buble_monitor_control",
                   "commit": "2a468ba", "read_from": where},
        "temperature": [[v, interpolate(clamp_fraction(v, t_lo, t_hi),
                                        temp_g)]
                        for v in [-5, 0, 3.7, 7.5, 15, 22.5, 26.1, 30, 41]],
        "oxygen": [[v, interpolate(clamp_fraction(v, o_lo, o_hi), oxy_g)]
                   for v in [-1, 0, 1.5, 3, 6, 9, 10.7, 12, 15]],
    }
    layers = [(0.0, 4.5), (0.25, 4.6), (0.5, 11.3), (0.8, 17.9),
              (1.0, 18.0)]
    grid = (100, 100, 100)
    col = column_frame(layers, "temperature", grid, temp_g, t_lo, t_hi)
    fixture["column"] = {
        "layers": [[f, v] for f, v in layers], "grid": list(grid),
        "count": len(col), "first": col[0], "last": col[-1],
        "sum_xyz": [sum(v[i] for v in col) for i in range(3)],
        "layer_z": sorted({v[2] for v in col}),
        "rgb_per_z": {str(z): [v for v in col if v[2] == z][0][3:]
                      for z in sorted({v[2] for v in col})},
    }
    pts = [(0.0, 0.0, 0.0), (0.5, 0.25, 0.125), (1.0, 1.0, 1.0),
           (0.333, 0.667, 0.5), (0.005, 0.015, 0.025)]
    cl = cloud_frame(pts, (255, 255, 255), grid)
    fixture["cloud"] = {"points": [list(p) for p in pts],
                        "voxels": cl, "grid": list(grid)}
    fixture["tension"] = [[s, tension(s)] for s in [0, 6, 17.5, 35, 40]]
    fixture["minnaert"] = [[f, d, s, minnaert_um(f, d, s)]
                           for f, d, s in [(40, 0, 6), (40, 50, 6),
                                           (20, 0, 0), (40, 100, 35)]]
    with open(OUT, "w", encoding="utf-8") as handle:
        json.dump(fixture, handle, separators=(",", ":"))
    print("wrote", os.path.normpath(OUT), "from", where)


if __name__ == "__main__":
    main()
