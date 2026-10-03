## The physics and data of the volumetric laser screen (HLD
## docs/HLD_VOLUMETRIC_LASER_SCREEN_2026-10-03.md, phase V1).
##
## A port of the operator's VoxelMapper, BubbleGenerator and
## LaserController (repo Leonidy431/laser_buble_monitor_control, commit
## 2a468ba): the gradients, the sparse fill and the surface tension are
## the same numbers, checked against godot/tests/fixtures/
## volumetric_fixture.json, which scripts/godot/make_volumetric_fixture.py
## writes from the Python source.  Everything is static and
## deterministic: the same input gives the same frame, no randomness
## (CLAUDE.md TABOO 0.35 rule 15).  The screen shows data, never an
## arrow or an answer (HLD, chorus 2).
##
## Constitution: FORM (laser light on microbubbles, the water's own
## numbers) -> ACTION (the hero reads layers, oxygen and the floor in
## volume) -> GOAL (honest, open knowledge: the water's truth is
## visible, the protocol's lie is not).
class_name VolumetricCore
extends RefCounted

const DATA := "res://data/volumetric-display.json"

## Gradient stops as [fraction, [r, g, b]], the operator's values.
const TEMPERATURE_GRADIENT := [[0.0, [30, 60, 220]],
	[0.5, [60, 200, 120]], [1.0, [220, 50, 40]]]
const OXYGEN_GRADIENT := [[0.0, [200, 30, 30]],
	[0.5, [230, 200, 40]], [1.0, [40, 200, 90]]]
const TEMPERATURE_RANGE := [0.0, 30.0]
const OXYGEN_RANGE := [0.0, 12.0]
## Turbidity has no gradient of its own in the source (it falls back to
## the temperature one), so we give it a range of its own: 0-50 NTU.
const TURBIDITY_RANGE := [0.0, 50.0]
const GRID_DEFAULT := Vector3i(100, 100, 100)
const SPARSE_STEP := 4

const TENSION_FRESH := 0.0728
const TENSION_SEA := 0.0679
const SALINITY_REF_PSU := 35.0
const GAMMA_AIR := 1.4
const RHO_FRESH := 998.0
const RHO_SEA := 1025.0

## Laser: 450-490 nm goes furthest through water (laser_control.py).
const OPTIMAL_NM := [450.0, 490.0]
## Pure-water absorption (1/m) by wavelength; the blue, green and red
## anchors are DiveCore.ABSORPTION so the screen and the dive agree.
const ABSORPTION_NM := [[400.0, 0.020], [450.0, 0.009], [470.0, 0.010],
	[490.0, 0.014], [530.0, 0.057], [580.0, 0.15], [630.0, 0.34],
	[700.0, 0.65]]
## Scattering by suspended matter, 1/m per NTU.  Not wavelength
## dependent here: a deliberate simplification, the ranking of
## wavelengths then comes from absorption alone.
const SCATTER_PER_NTU := 0.04


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


## Python's round() goes to the even neighbour on .5; GDScript's goes
## away from zero.  The port must give the same integers as the source.
static func _round_even(x: float) -> int:
	var f := floorf(x)
	var diff := x - f
	if diff < 0.5:
		return int(f)
	if diff > 0.5:
		return int(f) + 1
	return int(f) if int(f) % 2 == 0 else int(f) + 1


static func _fraction(value: float, low: float, high: float) -> float:
	if high <= low:
		return 0.0
	return clampf((value - low) / (high - low), 0.0, 1.0)


## VoxelMapper._interpolate_gradient: returns [r, g, b] integers.
static func _gradient(fraction: float, stops: Array) -> Array:
	for i in range(stops.size() - 1):
		var a: float = stops[i][0]
		var b: float = stops[i + 1][0]
		if a <= fraction and fraction <= b:
			var span := b - a
			var t := 0.0 if span == 0.0 else (fraction - a) / span
			var out := []
			for k in 3:
				var ca: float = stops[i][1][k]
				var cb: float = stops[i + 1][1][k]
				out.append(_round_even(ca + (cb - ca) * t))
			return out
	return (stops[-1][1] as Array).duplicate()


## The colour of a reading as integers [r, g, b].
static func rgb_for(metric: String, value: float) -> Array:
	match metric:
		"dissolved_oxygen":
			return _gradient(_fraction(value, OXYGEN_RANGE[0],
				OXYGEN_RANGE[1]), OXYGEN_GRADIENT)
		"turbidity":
			return _gradient(_fraction(value, TURBIDITY_RANGE[0],
				TURBIDITY_RANGE[1]), TEMPERATURE_GRADIENT)
	return _gradient(_fraction(value, TEMPERATURE_RANGE[0],
		TEMPERATURE_RANGE[1]), TEMPERATURE_GRADIENT)


## The same colour as a Color, for the scene.
static func color_for(metric: String, value: float) -> Color:
	var c := rgb_for(metric, value)
	return Color(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)


static func _voxel(x: int, y: int, z: int, rgb: Array) -> Dictionary:
	return {"x": x, "y": y, "z": z, "rgb": rgb,
		"color": Color(rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0)}


## One horizontal layer per reading, every 4th grid cell like the
## source.  readings_by_height: [{"h": 0..1 bottom to top, <metric>:
## value}, ...] with metric in temperature, dissolved_oxygen, turbidity.
static func water_column_frame(readings_by_height: Array, metric: String,
		grid: Vector3i = GRID_DEFAULT) -> Array:
	var voxels := []
	for r in readings_by_height:
		var z := _round_even(float(r.h) * (grid.z - 1))
		var rgb := rgb_for(metric, float(r.get(metric, 0.0)))
		for x in range(0, grid.x, SPARSE_STEP):
			for y in range(0, grid.y, SPARSE_STEP):
				voxels.append(_voxel(x, y, z, rgb))
	return voxels


## A normalised (0-1 per axis) point cloud, e.g. sonar, one colour.
static func point_cloud_frame(points: Array, color: Array = [255, 255, 255],
		grid: Vector3i = GRID_DEFAULT) -> Array:
	var voxels := []
	for p in points:
		voxels.append(_voxel(_round_even(p[0] * (grid.x - 1)),
			_round_even(p[1] * (grid.y - 1)),
			_round_even(p[2] * (grid.z - 1)), color))
	return voxels


## Surface tension (N/m), linear between fresh and 35 PSU sea water.
static func surface_tension(salinity_psu: float) -> float:
	var t := clampf(salinity_psu / SALINITY_REF_PSU, 0.0, 1.0)
	return TENSION_FRESH + (TENSION_SEA - TENSION_FRESH) * t


static func water_density(salinity_psu: float) -> float:
	var t := clampf(salinity_psu / SALINITY_REF_PSU, 0.0, 1.0)
	return RHO_FRESH + (RHO_SEA - RHO_FRESH) * t


## Ambient pressure in pascals at a depth, as DiveCore counts bars.
static func ambient_pa(depth_m: float) -> float:
	return (DiveCore.SURFACE_BAR
		+ maxf(0.0, depth_m) / DiveCore.METRES_PER_BAR) * 1e5


## Minnaert resonance radius in micrometres:
## a = (1 / 2 pi f) * sqrt(3 gamma P0 / rho).  Deeper water is stiffer
## gas spring (P0 grows), so at a fixed drive frequency the resonant
## radius grows with depth.
static func resonant_radius_um(freq_khz: float, depth_m: float,
		salinity_psu: float) -> float:
	var f := maxf(freq_khz, 0.001) * 1000.0
	var a := sqrt(3.0 * GAMMA_AIR * ambient_pa(depth_m)
		/ water_density(salinity_psu)) / (TAU * f)
	return a * 1e6


## Absorption of pure water (1/m) at a wavelength, piecewise linear.
static func absorption_per_m(wavelength_nm: float) -> float:
	var t := ABSORPTION_NM
	if wavelength_nm <= t[0][0]:
		return t[0][1]
	for i in range(1, t.size()):
		if wavelength_nm <= t[i][0]:
			var u: float = (wavelength_nm - t[i - 1][0]) \
				/ (t[i][0] - t[i - 1][0])
			return t[i - 1][1] + (t[i][1] - t[i - 1][1]) * u
	return t[-1][1]


## Share of the laser light left after distance_m (Beer-Lambert).
static func laser_transmission(wavelength_nm: float, distance_m: float,
		turbidity_ntu: float) -> float:
	var k := absorption_per_m(wavelength_nm) \
		+ SCATTER_PER_NTU * maxf(0.0, turbidity_ntu)
	return exp(-k * maxf(0.0, distance_m))


static func is_optimal_wavelength(wavelength_nm: float) -> bool:
	return wavelength_nm >= OPTIMAL_NM[0] and wavelength_nm <= OPTIMAL_NM[1]


## Dissolved oxygen (mg/L) of the lake by depth: well mixed, a little
## less below the thermocline.  A model, not a measurement.
static func oxygen_at(depth_m: float) -> float:
	var k := 1.0 / (1.0 + exp((depth_m - DiveCore.THERMOCLINE_M) / 12.0))
	return 6.8 + (9.2 - 6.8) * k


## Readings from the surface down to depth_max, bottom to top, ready for
## water_column_frame: temperature is DiveCore's (thermocline at 50 m).
## Turbidity is a small deterministic wobble from a hash of the seed.
static func lake_column(depth_max: float, layers: int = 12,
		seed_text: String = "lake") -> Array:
	var out := []
	var n := maxi(layers, 2)
	var base := float(DiveCore._hash(seed_text) % 100) / 100.0
	for i in n:
		var h := float(i) / float(n - 1)
		var depth := depth_max * (1.0 - h)
		out.append({"h": h, "depth": depth,
			"temperature": DiveCore.temperature(depth),
			"dissolved_oxygen": oxygen_at(depth),
			"turbidity": 1.0 + 0.5 * base + 1.5 * (1.0 - h)
				* (1.0 - h)})
	return out


## The lines of a mode, or an empty string at the holy: the screen goes
## dark and the narrator is silent there (TABOO 0.4, 0.020 item 4).
static func narrator_line(data: Dictionary, mode: String,
		beat: String) -> String:
	if is_holy(data, beat):
		return ""
	for n in data.get("narrator", []):
		if n.mode == mode:
			return n.line_ru
	return ""


static func claude_line(data: Dictionary, mode: String,
		beat: String) -> String:
	if is_holy(data, beat):
		return ""
	for n in data.get("claude", []):
		if n.mode == mode:
			return n.line_ru
	return ""


static func is_holy(data: Dictionary, beat: String) -> bool:
	return bool(data.get("holy_silent", true)) \
		and beat in data.get("holy_beats", [])
