## Proof frames of the volumetric laser screen (docs/HLD_VOLUMETRIC_LASER_
## SCREEN_2026-10-03.md, phase V3; TABOO 0.022).  A small underwater set:
## dark blue water fog, a sandy floor, the edge of the ROV console and the
## VolumetricScreen 1.2 m in front of the eye.  Three modes, two camera
## angles, two depths, one holy-fade frame, and (--seq=dir) a frame
## sequence of the floor-mode sweep for the preview video.
##
##     xvfb-run godot --path godot --rendering-driver opengl3 \
##         -s res://tools/volumetric_shots.gd -- \
##         --out=../docs/audit/2026-10-03/volumetric --seq=/tmp/seq
##
## The clock is held by the tool, so the frames are deterministic.
extends SceneTree

const DEPTHS := [20.0, 60.0]
const MODES := ["layers", "oxygen", "floor"]
## Camera: [name, position, look-at].
const ANGLES := [["front", Vector3(0.0, 1.05, 0.0), Vector3(0.0, 1.0, -1.2)],
	["side", Vector3(0.95, 1.45, -0.55), Vector3(0.0, 0.95, -1.2)]]
const HOLD := 4
const SEQ_FRAMES := 72
const SEQ_DT := 0.1
const SCREEN_AT := Vector3(0.0, 1.0, -1.2)

var out := "user://volumetric-shots"
var seq := ""
var shots: Array = []
var idx := 0
var frame := 0
var screen: VolumetricScreen
var cam: Camera3D
## The diver's glove with the small screen on its back (--glove).
var glove: Node3D
var glove_screen: VolumetricScreen


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--seq="):
			seq = a.trim_prefix("--seq=")
	DirAccess.make_dir_recursive_absolute(out)
	if seq != "":
		DirAccess.make_dir_recursive_absolute(seq)
	root.size = Vector2i(1280, 720)
	_build_set()
	_build_glove()
	var n := 0
	for d in DEPTHS:
		for m in MODES:
			for a in ANGLES.size():
				n += 1
				shots.append({"name": "volumetric-%02d-%s-%s-%dm" % [n, m,
					ANGLES[a][0], int(d)], "mode": m, "depth": d,
					"angle": a, "t": 6.0, "holy": false, "dir": out})
	shots.append({"name": "volumetric-%02d-holy-fade" % (n + 1),
		"mode": "layers", "depth": 20.0, "angle": 0, "t": 6.0,
		"holy": true, "dir": out})
	# The glove under water, as the diver sees it when he turns his
	# wrist: layers at 20 m, the floor at 60 m, and the holy fade.
	for g in [["layers", 20.0, false], ["floor", 60.0, false],
			["layers", 60.0, false]]:
		n += 1
		shots.append({"name": "volumetric-%02d-glove-%s-%dm" % [n + 1, g[0],
			int(g[1])], "mode": g[0], "depth": g[1], "angle": -1,
			"t": 6.0, "holy": g[2], "dir": out})
	if seq != "":
		for i in SEQ_FRAMES:
			shots.append({"name": "seq-%03d" % i, "mode": "floor",
				"depth": 40.0, "angle": 1, "t": 2.0 + i * SEQ_DT,
				"holy": false, "dir": seq})


func _build_set() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.07, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.4, 0.55)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.12, 0.22)
	env.fog_density = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.55, 0.47, 0.33)
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	plane.material = sand
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = plane
	floor_node.position = Vector3(0, 0, -2.0)
	root.add_child(floor_node)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.7, 0.85, 1.0)
	lamp.light_energy = 1.5
	lamp.omni_range = 6.0
	lamp.position = Vector3(0.5, 2.2, 0.0)
	root.add_child(lamp)

	# The console edge: a graphite slab with a cyan rim, under the glass.
	var graphite := StandardMaterial3D.new()
	graphite.albedo_color = Color(0.12, 0.13, 0.15)
	graphite.roughness = 0.7
	var slab := BoxMesh.new()
	slab.size = Vector3(1.6, 0.12, 0.5)
	slab.material = graphite
	var console := MeshInstance3D.new()
	console.mesh = slab
	console.position = Vector3(0.0, 0.5, -1.2)
	root.add_child(console)
	var rim := StandardMaterial3D.new()
	rim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.albedo_color = Color(0.25, 0.9, 1.0)
	var strip := BoxMesh.new()
	strip.size = Vector3(1.6, 0.01, 0.01)
	strip.material = rim
	var strip_node := MeshInstance3D.new()
	strip_node.mesh = strip
	strip_node.position = Vector3(0.0, 0.57, -0.95)
	root.add_child(strip_node)
	# The glass stands on the slab: its bottom at the slab's top.
	screen = VolumetricScreen.new()
	screen.position = Vector3(0.0, 0.56 + VolumetricScreen.HEIGHT * 0.5,
		-1.2)
	root.add_child(screen)

	cam = Camera3D.new()
	cam.fov = 65.0
	root.add_child(cam)
	cam.make_current()


## A diver's neoprene glove: palm, four fingers, thumb and cuff, with the
## volumetric screen a tenth of a metre across on the back of the wrist,
## as pilot.gd mounts it on the left controller.
func _build_glove() -> void:
	glove = Node3D.new()
	glove.position = Vector3(0.25, 1.35, -0.55)
	glove.rotation = Vector3(0.0, 0.5, 0.0)
	glove.visible = false
	var neo := StandardMaterial3D.new()
	neo.albedo_color = Color(0.16, 0.17, 0.20)
	neo.roughness = 0.85
	var parts := [[Vector3(0.09, 0.03, 0.10), Vector3.ZERO],
		[Vector3(0.08, 0.06, 0.14), Vector3(0, 0, 0.12)]]
	for i in 4:
		parts.append([Vector3(0.018, 0.022, 0.08 - 0.008 * absi(i - 1)),
			Vector3(-0.032 + 0.021 * i, 0, -0.088)])
	parts.append([Vector3(0.022, 0.022, 0.065), Vector3(0.058, -0.004,
		-0.02)])
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.material_override = neo
		mi.position = p[1]
		glove.add_child(mi)
	glove_screen = VolumetricScreen.new()
	glove_screen.position = Vector3(0.0, 0.075, 0.09)
	glove_screen.scale = Vector3.ONE * 0.16
	glove.add_child(glove_screen)
	root.add_child(glove)


func _process(_dt: float) -> bool:
	if idx >= shots.size():
		return true
	var s: Dictionary = shots[idx]
	if frame == 0:
		screen.set_holy(false)
		screen.set_mode(s.mode)
		glove_screen.set_mode(s.mode)
		glove.visible = s.angle < 0
		screen.visible = s.angle >= 0
		if s.angle < 0:
			cam.position = glove.position + Vector3(-0.08, 0.16, 0.34)
			cam.look_at(glove.position + Vector3(0, 0.07, 0.02),
				Vector3.UP)
		else:
			var a: Array = ANGLES[s.angle]
			cam.position = a[1]
			cam.look_at(screen.position + Vector3(0, 0.0, 0), Vector3.UP)
	glove_screen.update(s.t, s.depth, false)
	var t: float = s.t
	if s.holy:
		# Held half way through the 1.75 s fade of the holy ground.
		if frame == 0:
			screen.update(t, s.depth, false)
			screen.set_holy(true)
		screen.update(t + 0.9 if frame > 0 else t, s.depth, false)
	else:
		screen.update(t, s.depth, false)
	frame += 1
	if frame >= HOLD:
		var img := root.get_texture().get_image()
		if s.dir == seq:
			img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		var path: String = str(s.dir).path_join(str(s.name) + ".png")
		img.save_png(path)
		print("shot ", path, " voxels=", screen.voxel_count(),
			" fade=", snappedf(screen.fade_level(), 0.01))
		frame = 0
		idx += 1
	return false
