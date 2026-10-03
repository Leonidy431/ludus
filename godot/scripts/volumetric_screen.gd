## The volumetric laser screen under water (CLAUDE.md TABOO 0.022, phase
## V2 of docs/HLD_VOLUMETRIC_LASER_SCREEN_2026-10-03.md): a clear glass
## cylinder with a cloud of micro-bubbles in which two galvo beams burn
## the lake's own data as voxels: water layers by temperature, oxygen,
## and a point cloud of the lakebed with a find on it.
##
## Constitution: FORM (laser light scattered by bubbles, the water's data
## as matter) -> ACTION (the hero looks at the layers, the oxygen and the
## relief of the floor in volume and chooses the apparatus's path) ->
## GOAL (knowledge made by hands and open: the truth of the water is
## visible, the lie of the protocol is not).  The screen shows data, not
## an answer: no arrows, no "here" marks (TABOO 0.026 item 1).
##
## Light class: instrument, 6500 K, cyan only (TABOO 0.38).  Colours of
## the voxels come from VolumetricCore, never from this node.
##
## Budget (TABOO 0.011): three draw calls, one material each: the glass,
## the bubble cloud (MultiMesh) and the voxels with both beams
## (MultiMesh).  No particle classes: the own engine cuts them
## (scripts/godot/engine/profile.py).  The engine has no physics, so no
## raycast; everything here is arithmetic and deterministic (no random).
##
## Holy places (TABOO 0.4, 0.027): set_holy(true) fades the screen to
## dark within HOLY_FADE seconds and it stays dark until set_holy(false).
class_name VolumetricScreen
extends Node3D

const WIDTH := 0.6
const HEIGHT := 0.8
const HOLY_FADE := 1.75
const MAX_BUBBLES := 320
## Voxel instances come after the two beams in the same MultiMesh.
const MAX_VOXELS := 256
const BEAMS := 2
const MODES := ["layers", "oxygen", "floor"]
## The galvo laser of the apparatus: blue-green, 470 nm.
const BEAM_COLOR := Color(0.25, 0.9, 1.0)
const FLOOR_RGB := [64, 217, 255]
const GRID := Vector3i(16, 16, 16)
const FIND_METRIC := "temperature"
const FIND_VALUE := 12.0

var mode := "layers"
var holy := false
var reduced := false
var depth_m := 20.0

var _fade := 1.0
var _holy_since := -1.0
var _last_t := 0.0
var _key := ""
var _vox_count := 0
var _core = null
var _glass: MeshInstance3D
var _bubbles: MultiMeshInstance3D
var _voxels: MultiMeshInstance3D
var _bubble_mat: StandardMaterial3D
var _glass_mat: StandardMaterial3D
var _voxel_colors: Array = []
var _voxel_pos: Array = []
var _rec_b: Array = []
var _rec_v: Array = []


func _init() -> void:
	_core = VolumetricCore
	_build()
	_refresh(0.0)
	_place(0.0)


func _build() -> void:
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass_mat.albedo_color = Color(0.55, 0.85, 1.0, 0.08)
	var cyl := CylinderMesh.new()
	cyl.top_radius = WIDTH * 0.5
	cyl.bottom_radius = WIDTH * 0.5
	cyl.height = HEIGHT
	cyl.radial_segments = 16
	cyl.rings = 1
	cyl.material = _glass_mat
	_glass = MeshInstance3D.new()
	_glass.name = "Glass"
	_glass.mesh = cyl
	add_child(_glass)

	_bubble_mat = StandardMaterial3D.new()
	_bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble_mat.vertex_color_use_as_albedo = true
	_bubble_mat.albedo_color = Color(0.7, 0.9, 1.0, 0.35)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.006, 0.006)
	quad.material = _bubble_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = MAX_BUBBLES
	_bubbles = MultiMeshInstance3D.new()
	_bubbles.name = "Bubbles"
	_bubbles.multimesh = mm
	add_child(_bubbles)

	# Additive look: dark colour adds nothing, so fading is a scale of
	# the instance colour and needs no second material.
	var vmat := StandardMaterial3D.new()
	vmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	vmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vmat.vertex_color_use_as_albedo = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = vmat
	var vm := MultiMesh.new()
	vm.transform_format = MultiMesh.TRANSFORM_3D
	vm.use_colors = true
	vm.mesh = box
	vm.instance_count = BEAMS + MAX_VOXELS
	_voxels = MultiMeshInstance3D.new()
	_voxels.name = "Voxels"
	_voxels.multimesh = vm
	add_child(_voxels)


func set_mode(m: String) -> void:
	if m in MODES:
		mode = m


## Holy ground: the screen goes dark and stays dark (TABOO 0.4).
func set_holy(on: bool) -> void:
	if on and not holy:
		_holy_since = _last_t
	holy = on
	if not on:
		_holy_since = -1.0
		_fade = 1.0


## One step of the screen.  `t` is the scene time in seconds, `depth`
## the apparatus depth in metres, `is_reduced` the reduced-motion flag.
func update(t: float, depth: float, is_reduced: bool) -> void:
	_last_t = t
	reduced = is_reduced
	depth_m = depth
	if holy:
		if _holy_since < 0.0:
			_holy_since = t
		_fade = clampf(1.0 - (t - _holy_since) / HOLY_FADE, 0.0, 1.0)
	_refresh(t)
	_place(t)


func fade_level() -> float:
	return _fade


func is_dark() -> bool:
	return _fade <= 0.0


## Count of the voxels now burned in the cloud.
func voxel_count() -> int:
	return _vox_count


## Colours of the burned voxels, as given by VolumetricCore.
func voxel_colors() -> Array:
	return _voxel_colors


func stats() -> Dictionary:
	var tri := _tris(_glass.mesh)
	var cap := _tris(_bubbles.multimesh.mesh) * MAX_BUBBLES \
		+ _tris(_voxels.multimesh.mesh) * (BEAMS + MAX_VOXELS) + tri
	return {
		"draw_calls": 3,
		"instances": MAX_BUBBLES + BEAMS + MAX_VOXELS,
		"visible_instances": MAX_BUBBLES + BEAMS + _vox_count,
		"triangles": cap,
		"voxels": _vox_count,
	}


## A hash of every transform and colour written, to prove determinism.
## It reads our own record: the headless renderer keeps no buffers.
func frame_hash() -> int:
	return hash([_rec_b, _rec_v])


func _tris(mesh: Mesh) -> int:
	var a := mesh.surface_get_arrays(0)
	var idx = a[Mesh.ARRAY_INDEX]
	if idx != null and idx.size() > 0:
		return idx.size() / 3
	return a[Mesh.ARRAY_VERTEX].size() / 3


## Rebuild the voxel frame when the mode or the metre of depth changes.
func _refresh(_t: float) -> void:
	var key := "%s:%d" % [mode, int(round(depth_m))]
	if key == _key:
		return
	_key = key
	_voxel_pos.clear()
	_voxel_colors.clear()
	if mode == "floor":
		_load_floor()
	else:
		_load_column()
	_vox_count = mini(_voxel_pos.size(), MAX_VOXELS)


func _load_column() -> void:
	var metric := "temperature" if mode == "layers" else "dissolved_oxygen"
	var readings: Array = _core.lake_column(maxf(depth_m, 1.0))
	_take(_core.water_column_frame(readings, metric, GRID))


func _load_floor() -> void:
	var pts: Array = []
	var find: Array = []
	var n := 14
	for ix in n:
		for iz in n:
			var x := float(ix) / (n - 1)
			var z := float(iz) / (n - 1)
			# A gentle ridge and a dip: the lakebed, with no random.
			# The third axis of the cloud is the height, as in the core.
			var h := 0.12 + 0.05 * sin(x * 5.0) * cos(z * 4.0) + 0.06 * x
			var d := Vector2(x - 0.68, z - 0.4).length()
			if d < 0.09:
				# The find: a rounded mound standing out of the silt.
				find.append([x, z, h + 0.2 * (1.0 - d / 0.09)])
			else:
				pts.append([x, z, h])
	_take(_core.point_cloud_frame(pts, FLOOR_RGB, GRID))
	_take(_core.point_cloud_frame(find,
		_core.rgb_for(FIND_METRIC, FIND_VALUE), GRID))


## The core returns voxels with grid x, y, z (z is the height) and a
## Color; they map into the glass and never leave its circle.
func _take(frame: Array) -> void:
	var m := float(GRID.x - 1)
	for v in frame:
		var p := Vector3(v.x / m - 0.5, v.z / float(GRID.z - 1) - 0.5,
			v.y / float(GRID.y - 1) - 0.5)
		var flat := Vector2(p.x, p.z)
		if flat.length() > 0.5:
			flat = flat.normalized() * 0.5
		_voxel_pos.append(Vector3(flat.x, p.y, flat.y))
		_voxel_colors.append(v.color)


func _place(t: float) -> void:
	var tt := 0.0 if reduced else t
	_place_bubbles(tt)
	_place_voxels(tt)
	var on := _fade > 0.0
	_bubbles.visible = on
	_voxels.visible = on
	_glass.visible = on
	_glass_mat.albedo_color.a = 0.08 * _fade
	_bubble_mat.albedo_color.a = 0.35 * _fade


## Bubbles rise on a fixed lattice of phases; the cloud is the same for
## the same time.  Reduced-motion holds it still.
func _place_bubbles(tt: float) -> void:
	var mm: MultiMesh = _bubbles.multimesh
	_rec_b.resize(MAX_BUBBLES)
	var r := WIDTH * 0.5 - 0.02
	for i in MAX_BUBBLES:
		var u := fposmod(float(i) * 0.6180339887, 1.0)
		var w := fposmod(float(i) * 0.7548776662, 1.0)
		var a := TAU * u
		var rad := r * sqrt(w)
		var rise := fposmod(u * 7.0 + tt * (0.05 + 0.04 * w), 1.0)
		var y := (rise - 0.5) * (HEIGHT - 0.04)
		var sway := 0.01 * sin(tt * 1.7 + float(i))
		var pos := Vector3(cos(a) * rad + sway, y, sin(a) * rad)
		mm.set_instance_transform(i, Transform3D(Basis(), pos))
		_rec_b[i] = pos


func _place_voxels(tt: float) -> void:
	var mm: MultiMesh = _voxels.multimesh
	_rec_v.clear()
	var cell := Vector3(WIDTH, HEIGHT, WIDTH)
	var size := 0.026
	_place_beams(mm, tt)
	var pulse := 1.0
	if not reduced:
		pulse = 0.9 + 0.1 * sin(tt * TAU * 0.5)
	for i in MAX_VOXELS:
		var idx := BEAMS + i
		if i < _vox_count:
			var p: Vector3 = _voxel_pos[i] * cell * 0.9
			var s := size * (0.8 if mode == "floor" else 1.0)
			mm.set_instance_transform(idx,
				Transform3D(Basis().scaled(Vector3(s, s, s)), p))
			var c: Color = _voxel_colors[i]
			var k := _fade * pulse
			var lit := Color(c.r * k, c.g * k, c.b * k, 1.0)
			mm.set_instance_color(idx, lit)
			_rec_v.append([p, s, lit])
		else:
			mm.set_instance_transform(idx,
				Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	mm.visible_instance_count = BEAMS + _vox_count


## Two galvo beams from the top of the glass sweep the cloud on a fixed
## Lissajous figure; reduced-motion parks them on the middle.
func _place_beams(mm: MultiMesh, tt: float) -> void:
	for b in BEAMS:
		var side := -1.0 if b == 0 else 1.0
		var from := Vector3(side * 0.27, HEIGHT * 0.5, 0.0)
		var to := Vector3(0.0, 0.0, 0.0)
		if not reduced:
			# Under 3 Hz: no flashing, only a slow sweep (TABOO 0.015).
			to = Vector3(0.2 * sin(tt * 1.1 + side),
				0.3 * sin(tt * 0.7 + 1.0 * b), 0.2 * cos(tt * 0.9 + side))
		var d := to - from
		var len := d.length()
		var z := d / len
		var up := Vector3.UP if absf(z.y) < 0.99 else Vector3.RIGHT
		var x := up.cross(z).normalized()
		var y := z.cross(x)
		var basis := Basis(x * 0.003, y * 0.003, z * len)
		var xf := Transform3D(basis, (from + to) * 0.5)
		mm.set_instance_transform(b, xf)
		_rec_v.append([xf, _fade])
		var k := _fade
		mm.set_instance_color(b, Color(BEAM_COLOR.r * k, BEAM_COLOR.g * k,
			BEAM_COLOR.b * k, 1.0))
