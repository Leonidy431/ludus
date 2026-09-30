## The dive scene: the ROV goes down the Issyk-Kul shore.
##
## Everything the player sees is built here from data, so the scene is
## deterministic and reviewable in a diff (docs/HLD_HEADSET_BUILD_*).
## The rules come from DiveCore (a port of public/ludus/dive/
## dive-core.js); this script only draws them and reads the controls.
##
## World axes: x is the distance from the shore (m), y is minus the
## depth (m), z runs along the shore.
extends Node3D

const THERMO_Y := -DiveCore.THERMOCLINE_M
const LAMP_COLOUR := Color(0.95, 0.97, 1.0)  # Instrument light, 6500 K.
const FLOW_SHAPES := ["current", "eddy", "intwave", "plume", "langmuir",
	"upwelling", "layer", "cloud"]
const ZONE_SHAPES := ["ripples", "gravel", "silt", "meadow", "swarm",
	"fuzz", "shells", "particles", "cloud", "light", "bubbles", "sherds"]
const SAVE_PATH := "user://dive.json"
const REACH_M := 4.0

var rov := DiveCore.new_rov()
var placed: Array = []
var schools: Array = []
var bag := {"kept": [], "released": [], "handed_over": []}
var game := DiveCore.new_game()
var messages: Array = []
# Sound (scripts/audio): water, breath, sonar and its echo after the
# real 2 * range / c, the ison and the shore bell, spatial water and
# haptics.  This scene only calls its hooks.
var audio: DiveAudio
var t := 0.0
var xr_active := false
var mouse_look := false
var pitch := 0.0
var message := ""
var message_left := 0.0

var env: Environment
var sun: DirectionalLight3D
var rig: Node3D
var camera: Camera3D
var lamp: SpotLight3D
var hud_label: Label
var hud_prompt: Label
var xr_label: Label3D
var xr_prompt: Label3D
# The pilot's console (CockpitPanel in a SubViewport): on the screen a
# strip at the bottom, in the headset a panel under the gaze.
const CONSOLE_PX := Vector2i(1256, 124)
var console_view: SubViewport
var console: CockpitPanel
var console_screen: TextureRect
var console_xr: MeshInstance3D
var console_alpha := 1.0
# Holy things on the lake floor (the bulla bears a cross): near them the
# console goes out (TABOO 0.4 rule 2).
var holy_points: Array = []
# The Mangustik's body (godot/models/rov/mangustik.glb, the operator's
# drawings).  Third person: the camera rides behind and above it, as a
# chase camera; first person: the camera is the ROV's own eye and the
# body is hidden.  V on the keyboard, Y on the left controller.
# A little to the right of the stern, over the shoulder: straight
# behind, the tether from the shore ran through the middle of the view.
const CHASE := Vector3(0.45, 0.85, 2.6)
const CHASE_PITCH := -0.22
const CHASE_YAW := 0.17
var body: Node3D
var third_person := true
var view_was := false
var left_hand: XRController3D
var right_hand: XRController3D
var fish_meshes: Array = []
var flow_mesh: ImmediateMesh
var tether_mesh: ImmediateMesh
var webxr: XRInterface
var vr_button: Button
var snap_ready := true
var interact_was := false
var lamp_was := false
# Proof frames for CI and review: --shots=<dir> renders fixed depths.
var shots_dir := ""
var shot_plan := [3.0, 12.0, 35.0, 60.0, 120.0]
var shot_frame := 0


func _ready() -> void:
	var lake: Dictionary = _load_json("res://data/lake-objects-99.json")
	var fish: Dictionary = _load_json("res://data/issyk-kul-fish.json")
	placed = DiveCore.place_objects(lake.objects)
	schools = DiveCore.fish_schools(fish.fish)
	_load_bag()
	_build_environment()
	_build_floor()
	_build_surface()
	_build_thermocline()
	_build_objects()
	_build_stones()
	_build_fish()
	_build_lines()
	_build_snow()
	_build_rig()
	_build_body()
	_build_hud()
	_start_xr()
	_build_audio()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(shots_dir)


func _load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# --- World ------------------------------------------------------------------

## Colour of the water around the ROV: surface light scattered by clear
## water and dimmed band by band (Beer-Lambert, ludus-water.js).
func water_colour(depth: float) -> Color:
	var left := DiveCore.light_left(depth)
	var k := 1.0 / (1.0 + depth / 60.0)
	return Color((40.0 * left.red * k + 4.0) / 255.0,
		(150.0 * left.green * k + 8.0) / 255.0,
		(190.0 * left.blue * k + 14.0) / 255.0)


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-75, 20, 0)
	add_child(sun)


## Sand in the shallows, gravel on the shelf, silt in the deep.
func _floor_colour(depth: float) -> Color:
	var sand := Color(0.78, 0.72, 0.56)
	var gravel := Color(0.58, 0.55, 0.5)
	var silt := Color(0.33, 0.31, 0.28)
	if depth < 30.0:
		return sand.lerp(gravel, depth / 30.0)
	return gravel.lerp(silt, clampf((depth - 30.0) / 90.0, 0.0, 1.0))


func _build_floor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 5.0
	var nx := int(DiveCore.LENGTH_M / step)
	var nz := int(DiveCore.HALF_WIDTH_M * 2.0 / step)
	for i in nx:
		for j in nz:
			var x0 := i * step
			var z0 := -DiveCore.HALF_WIDTH_M + j * step
			var quad := [Vector2(x0, z0), Vector2(x0 + step, z0),
				Vector2(x0 + step, z0 + step), Vector2(x0, z0 + step)]
			for k in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = quad[k]
				var d := DiveCore.floor_depth(p.x, p.y)
				# Ripple banding: light and shade across the sand, so
				# the floor reads as a surface and not a flat fill.
				var band := 0.92 + 0.08 * sin(p.x * 0.9 + p.y * 0.3)
				st.set_color(_floor_colour(d) * band)
				st.add_vertex(Vector3(p.x, -d, p.y))
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	# Both faces: the first web frame showed water through the floor.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = mat
	add_child(mesh)


func _build_surface() -> void:
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(DiveCore.LENGTH_M * 4.0, DiveCore.LENGTH_M * 2.0)
	plane.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Under fog like everything else: from the deep the surface fades
	# out instead of hanging as a bright sheet (first eye check).
	mat.albedo_color = Color(0.75, 0.92, 0.95, 0.55)
	plane.material_override = mat
	plane.position = Vector3(DiveCore.LENGTH_M / 2.0, 0.0, 0.0)
	add_child(plane)


## The thermocline is a boundary one can see: a faint shimmering sheet.
func _build_thermocline() -> void:
	var sheet := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(DiveCore.LENGTH_M, DiveCore.HALF_WIDTH_M * 2.0)
	sheet.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.72, 0.85, 0.9, 0.07)
	sheet.material_override = mat
	sheet.position = Vector3(DiveCore.LENGTH_M / 2.0 + 150.0, THERMO_Y, 0.0)
	add_child(sheet)


func _build_objects() -> void:
	for p in placed:
		if p.where == "water" or p.shape in ZONE_SHAPES:
			# Water phenomena are flow lines, and flat fields (ripples,
			# silt, meadows) are the floor itself: their slab proxies
			# lay on the sand as huge pale wedges in the first frame.
			continue
		var node: Node3D
		if p.category == "bird":
			node = _blob(Color(p.colour), Vector3(0.45, 0.18, 0.2))
		else:
			var path := "res://models/lake/lake-%s.glb" % str(p.id).replace(
				".", "-")
			var scene: PackedScene = load(path) if ResourceLoader.exists(
				path) else null
			node = scene.instantiate() if scene else _blob(Color(p.colour),
				Vector3.ONE * maxf(0.3, p.size))
		node.position = Vector3(p.x, -p.depth, p.z)
		node.rotation.y = p.yaw
		add_child(node)
		if str(p.id).begins_with("bulla"):
			holy_points.append(node.position)


## Stones and pebbles that dress the floor of the dive corridor.  They
## are scenery, not lake objects: placed by seed, never loot.
func _build_stones() -> void:
	var r := DiveCore.rng("dive:stones")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var s := SphereMesh.new()
	s.radial_segments = 8
	s.rings = 4
	mm.mesh = s
	mm.instance_count = 900
	for i in mm.instance_count:
		var x: float = 5.0 + r.call() * (DiveCore.LENGTH_M - 10.0)
		var z: float = (r.call() * 2.0 - 1.0) * DiveCore.CORRIDOR_M * 1.6
		var d := DiveCore.floor_depth(x, z)
		# Boulders roll down the slope; the shallows keep small pebbles.
		var size: float = (0.08 + r.call() * 0.3) * (1.0 + minf(3.0, d / 40.0))
		var basis := Basis(Vector3.UP, r.call() * TAU).scaled(
			Vector3(size * (1.0 + r.call()), size * 0.6, size))
		mm.set_instance_transform(i, Transform3D(basis,
			Vector3(x, -d + size * 0.15, z)))
		var grey: float = 0.35 + r.call() * 0.3
		mm.set_instance_color(i, Color(grey, grey * 0.97, grey * 0.9))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	inst.material_override = mat
	add_child(inst)


func _blob(colour: Color, size: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	m.mesh = s
	m.scale = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	m.material_override = mat
	return m


## A fish of unit length along +x: a flattened spindle and a tail fork.
func _fish_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := 8
	var rows := [[0.5, 0.0], [0.35, 0.1], [0.1, 0.16], [-0.15, 0.13],
		[-0.35, 0.06], [-0.42, 0.02]]
	for r in rows.size() - 1:
		for k in ring:
			var a0 := TAU * k / ring
			var a1 := TAU * (k + 1) / ring
			var pts := []
			for rr in [r, r + 1]:
				for a in [a0, a1]:
					var rad: float = rows[rr][1]
					pts.append(Vector3(rows[rr][0], rad * sin(a),
						rad * 0.45 * cos(a)))
			for idx in [0, 2, 1, 1, 2, 3]:
				st.add_vertex(pts[idx])
	# Tail fork.
	for v in [Vector3(-0.4, 0, 0), Vector3(-0.62, 0.16, 0),
			Vector3(-0.55, 0, 0), Vector3(-0.4, 0, 0),
			Vector3(-0.55, 0, 0), Vector3(-0.62, -0.16, 0)]:
		st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _build_fish() -> void:
	var mesh := _fish_mesh()
	for s in schools:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = s.count
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(s.colour)
		mat.metallic = 0.3
		mat.roughness = 0.5
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		inst.material_override = mat
		add_child(inst)
		fish_meshes.append(inst)


func _line_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _build_lines() -> void:
	flow_mesh = ImmediateMesh.new()
	var flows := MeshInstance3D.new()
	flows.mesh = flow_mesh
	flows.material_override = _line_material()
	add_child(flows)
	tether_mesh = ImmediateMesh.new()
	var tether := MeshInstance3D.new()
	tether.mesh = tether_mesh
	tether.material_override = _line_material()
	add_child(tether)


## Marine snow drifts down around the ROV wherever it goes.
func _build_snow() -> void:
	var snow := CPUParticles3D.new()
	snow.amount = 400
	snow.lifetime = 12.0
	snow.preprocess = 12.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(12, 8, 12)
	snow.direction = Vector3(0, -1, 0)
	snow.initial_velocity_min = 0.02
	snow.initial_velocity_max = 0.08
	snow.gravity = Vector3(0, -0.01, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.9, 0.95, 0.95, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = mat
	snow.mesh = q
	snow.name = "Snow"
	add_child(snow)


func _build_rig() -> void:
	rig = XROrigin3D.new()
	add_child(rig)
	camera = XRCamera3D.new()
	camera.current = true
	camera.near = 0.1
	camera.far = 300.0
	rig.add_child(camera)
	lamp = SpotLight3D.new()
	lamp.light_color = LAMP_COLOUR
	lamp.light_energy = 4.0
	lamp.spot_range = 22.0
	lamp.spot_angle = 32.0
	camera.add_child(lamp)
	left_hand = XRController3D.new()
	left_hand.tracker = &"left_hand"
	rig.add_child(left_hand)
	right_hand = XRController3D.new()
	right_hand.tracker = &"right_hand"
	rig.add_child(right_hand)


## The ROV's body from the operator's drawings, with the lamp on its
## front camera skid when it is seen from behind.
func _build_body() -> void:
	var scene := load("res://models/rov/mangustik.glb") as PackedScene
	body = scene.instantiate() if scene else Node3D.new()
	add_child(body)
	_place_view()


## Put the lamp where the eye is: on the camera in first person, on the
## body's front skid (0.7 m ahead of its centre) in third person, so the
## light comes from the vehicle the player sees.
func _place_view() -> void:
	body.visible = third_person
	var holder: Node3D = body if third_person else camera
	if lamp.get_parent() != holder:
		lamp.reparent(holder, false)
	lamp.position = Vector3(0, 0.02, -0.72) if third_person else Vector3.ZERO
	lamp.rotation = Vector3(-0.12, 0, 0) if third_person else Vector3.ZERO


# --- Telemetry and messages ---------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_prompt = Label.new()
	hud_prompt.position = Vector2(24, 20)
	hud_prompt.add_theme_font_size_override("font_size", 20)
	layer.add_child(hud_prompt)
	# The pilot's console sits below the window on the water (operator,
	# 2026-09-30: "телеметрию ниже, а выше окно"), drawn once into its
	# own viewport so the screen and the headset show the same panel.
	console_view = SubViewport.new()
	console_view.transparent_bg = true
	console_view.size = CONSOLE_PX
	console_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(console_view)
	console = CockpitPanel.new()
	console.position = Vector2(8, 8)
	console_view.add_child(console)
	console_screen = TextureRect.new()
	console_screen.texture = console_view.get_texture()
	console_screen.anchor_left = 0.5
	console_screen.anchor_right = 0.5
	console_screen.anchor_top = 1.0
	console_screen.anchor_bottom = 1.0
	console_screen.offset_left = -CONSOLE_PX.x / 2.0
	console_screen.offset_top = -CONSOLE_PX.y - 8.0
	layer.add_child(console_screen)
	# The task line rides just above the console.
	hud_label = Label.new()
	hud_label.anchor_top = 1.0
	hud_label.anchor_bottom = 1.0
	hud_label.offset_top = -CONSOLE_PX.y - 40.0
	hud_label.offset_left = 24
	hud_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(hud_label)
	# In the headset the same console is a panel under the gaze, tilted
	# towards the eyes like a pult.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.62, 0.62 * CONSOLE_PX.y / CONSOLE_PX.x)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_texture = console_view.get_texture()
	console_xr = MeshInstance3D.new()
	console_xr.mesh = quad
	console_xr.material_override = mat
	console_xr.position = Vector3(0, -0.34, -0.72)
	console_xr.rotation_degrees = Vector3(-25, 0, 0)
	console_xr.visible = false
	camera.add_child(console_xr)
	for which in ["telemetry", "prompt"]:
		var l := Label3D.new()
		l.pixel_size = 0.0007
		l.font_size = 32
		l.no_depth_test = true
		l.fixed_size = false
		l.modulate = Color(0.85, 0.95, 1.0)
		l.position = Vector3(0, -0.19 if which == "telemetry" else 0.12,
			-0.8)
		l.visible = false
		camera.add_child(l)
		if which == "telemetry":
			xr_label = l
		else:
			xr_prompt = l


## The spoken line above the console: the task, and the diver's rule
## in words when the ascent is too fast (the card turns red as well).
func _console_line(tel: Dictionary) -> String:
	var line := _task_line()
	if tel.ascent_too_fast:
		line = "Всплытие %.0f м/мин — быстрее 10 м/мин. Сбавь ход.\n" \
			% tel.ascent_m_per_min + line
	return line


# --- Controls ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		mouse_look = event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	elif event is InputEventMouseMotion and mouse_look and not xr_active:
		rov.yaw += event.relative.x * 0.004
		pitch = clampf(pitch - event.relative.y * 0.003, -1.2, 1.2)


func _key(a: Key, b: Key) -> float:
	return float(Input.is_key_pressed(a)) - float(Input.is_key_pressed(b))


func _stick(hand: XRController3D) -> Vector2:
	var v := hand.get_vector2("primary")
	if v == Vector2.ZERO:
		v = hand.get_vector2("thumbstick")
	return v


func _read_input() -> Dictionary:
	var inp := {
		"forward": _key(KEY_W, KEY_S), "strafe": _key(KEY_D, KEY_A),
		"vertical": _key(KEY_R, KEY_F), "turn": _key(KEY_E, KEY_Q),
	}
	var interact := Input.is_key_pressed(KEY_SPACE)
	var lamp_key := Input.is_key_pressed(KEY_L)
	if xr_active:
		var move := _stick(left_hand)
		var aux := _stick(right_hand)
		# Move where the head looks, so the body follows the eyes.
		var head := camera.transform.basis.z
		var phi := atan2(-head.x, -head.z)
		var f := move.y
		var s := move.x
		inp.forward = f * cos(phi) - s * sin(phi)
		inp.strafe = f * sin(phi) + s * cos(phi)
		inp.vertical = aux.y
		# Snap turn of 30 degrees: smooth turning makes people sick.
		if absf(aux.x) > 0.7 and snap_ready:
			rov.yaw += deg_to_rad(30.0) * signf(aux.x)
			snap_ready = false
		elif absf(aux.x) < 0.3:
			snap_ready = true
		interact = interact or right_hand.is_button_pressed("trigger_click")
		lamp_key = lamp_key or right_hand.is_button_pressed("ax_button")
	var view_key := Input.is_key_pressed(KEY_V) or (xr_active
		and left_hand.is_button_pressed("by_button"))
	if view_key and not view_was:
		third_person = not third_person
		_place_view()
	view_was = view_key
	if interact and not interact_was:
		_interact()
	interact_was = interact
	if lamp_key and not lamp_was:
		rov.lamp = not rov.lamp
		audio.on_lamp_toggled(rov.lamp)
	lamp_was = lamp_key
	return inp


func _interact() -> void:
	var things: Array = placed.duplicate()
	for s in schools:
		var p := DiveCore.fish_at(s, 0, t)
		things.append({"id": s.id, "loot": s.loot, "x": p.x, "z": p.z,
			"depth": p.depth, "ru": s.ru, "category": "fish"})
	var hit := DiveCore.nearest(rov, things, REACH_M)
	if hit.is_empty():
		_say("Рядом ничего нет. Подойди ближе.")
		return
	var res := DiveCore.loot_action(hit.thing, bag)
	bag = res.bag
	_save_bag()
	audio.on_taken(res.rule)
	_say("%s. %s" % [hit.thing.ru, res.text])


func _say(text: String) -> void:
	message = text
	message_left = 7.0


## The next task not yet done, in the order of the bands downwards.
func _task_line() -> String:
	if game.fallen:
		return "Остановка безопасности: стой на месте %d с." % maxi(0,
			roundi(DiveCore.SAFETY_STOP_SEC - game.still_for))
	for task in DiveCore.TASKS:
		if not task.id in game.done:
			return task.ru
	return "Все задачи погружения пройдены."


func _save_bag() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"bag": bag, "done": game.done}))


func _load_bag() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Dictionary and data.has("bag"):
			bag.merge(data.bag, true)
			game.done = data.get("done", [])


# --- XR ---------------------------------------------------------------------

func _start_xr() -> void:
	var openxr := XRServer.find_interface("OpenXR")
	if openxr and openxr.is_initialized():
		get_viewport().use_xr = true
		xr_active = true
		_on_xr_started()
		return
	webxr = XRServer.find_interface("WebXR")
	if webxr and webxr.is_initialized():
		# The session survives a scene change: coming back from the hub
		# in the headset, the dive goes straight into it, no button.
		webxr.session_ended.connect(_on_webxr_ended)
		_on_webxr_started()
		return
	if webxr:
		webxr.session_supported.connect(_on_webxr_supported)
		webxr.session_started.connect(_on_webxr_started)
		webxr.session_ended.connect(_on_webxr_ended)
		webxr.is_session_supported("immersive-vr")


func _on_webxr_supported(mode: String, supported: bool) -> void:
	if mode != "immersive-vr" or not supported:
		return
	vr_button = Button.new()
	vr_button.text = "Войти в шлем"
	vr_button.position = Vector2(24, 64)
	vr_button.add_theme_font_size_override("font_size", 28)
	vr_button.pressed.connect(_enter_webxr)
	hud_prompt.get_parent().add_child(vr_button)


func _enter_webxr() -> void:
	webxr.session_mode = "immersive-vr"
	webxr.requested_reference_space_types = "local-floor, local"
	webxr.required_features = "local"
	webxr.optional_features = "local-floor"
	webxr.initialize()


func _on_webxr_started() -> void:
	get_viewport().use_xr = true
	xr_active = true
	_on_xr_started()


func _on_webxr_ended() -> void:
	get_viewport().use_xr = false
	xr_active = false
	xr_label.visible = false
	xr_prompt.visible = false
	console_xr.visible = false
	console_screen.visible = true


func _on_xr_started() -> void:
	xr_label.visible = true
	xr_prompt.visible = true
	console_xr.visible = true
	console_screen.visible = false
	if vr_button:
		vr_button.visible = false


# --- Frame ------------------------------------------------------------------

func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	t += dt
	var inp := _read_input()
	# The seiche current on the slope carries the ROV sideways.
	inp["drift"] = DiveCore.current(rov.x, t)
	rov = DiveCore.step_rov(rov, inp, dt)
	var out := DiveCore.step_game(game, rov, dt, bag.handed_over.size())
	if out.game.done.size() != game.done.size() or out.game.fallen != game.fallen:
		game = out.game
		_save_bag()
	game = out.game
	for text in out.say:
		_say(text)
	if shots_dir != "":
		_shots()
	var tel := DiveCore.telemetry(rov)
	var at := Vector3(rov.x, -rov.depth, rov.z)
	rig.rotation.y = -(rov.yaw + PI / 2.0)
	body.position = at
	body.rotation.y = rig.rotation.y
	rig.position = at
	if third_person:
		# Behind and above the body, turned with it; never above the
		# surface, where the chase camera would look at the sky.
		rig.position = at + rig.basis * CHASE
		rig.position.y = minf(rig.position.y, -0.25)
	if not xr_active:
		camera.rotation.x = pitch + (CHASE_PITCH if third_person else 0.0)
		# Turn the eye back onto the body (atan(0.45 / 2.6)); in the
		# headset the head does that itself.
		camera.rotation.y = CHASE_YAW if third_person else 0.0
	lamp.visible = rov.lamp and rov.battery > 0.0
	# A fall dims the world until the safety stop is held.
	lamp.light_energy = 1.2 if game.fallen else 4.0
	_update_water(tel)
	audio.update(tel, rov, inp, schools, t, dt, xr_active)
	if game.fallen:
		env.ambient_light_energy *= 0.35
		sun.light_energy *= 0.35
	_update_fish()
	_update_lines()
	($Snow as CPUParticles3D).position = rig.position
	message_left = maxf(0.0, message_left - dt)
	var prompt := message if message_left > 0.0 else _hint()
	var text := _console_line(tel)
	var shown := tel.duplicate()
	shown["lamp"] = rov.lamp
	console.show_cards(CockpitCore.cards(shown, bag))
	_fade_console(dt)
	hud_label.text = text
	hud_prompt.text = prompt
	xr_label.text = text
	xr_prompt.text = prompt


## Near a holy thing the console, the task line and the hints go out
## over CockpitCore.FADE_SECONDS; the ROV itself still answers the
## sticks.
func _fade_console(dt: float) -> void:
	var here := Vector3(rov.x, -rov.depth, rov.z)
	var nearest := INF
	for p in holy_points:
		nearest = minf(nearest, here.distance_to(p))
	console_alpha = CockpitCore.fade_step(console_alpha,
		CockpitCore.fade_target(nearest), dt)
	for node in [console_screen, hud_label, hud_prompt]:
		node.modulate.a = console_alpha
	console_xr.transparency = 1.0 - console_alpha
	xr_label.modulate.a = console_alpha
	xr_prompt.modulate.a = console_alpha


## Place the ROV at each planned depth over the slope, facing away from
## the shore, wait for the frame to settle, save it, then quit.
func _shots() -> void:
	# Each depth twice: from the ROV's eye, then from behind its body.
	var n := shot_frame / 40
	if n >= shot_plan.size():
		get_tree().quit()
		return
	var chase := shot_frame % 40 >= 20
	if chase != third_person:
		third_person = chase
		_place_view()
	var depth: float = shot_plan[n]
	rov.x = DiveCore.x_for_depth(depth + 6.0) - 8.0
	rov.z = 0.0
	rov.depth = depth
	rov.yaw = 0.0
	pitch = -0.25
	t = 20.0 + n
	if shot_frame % 20 == 19:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/dive-%03dm%s.png" % [shots_dir, roundi(depth),
			"-3p" if chase else ""])
	shot_frame += 1


func _build_audio() -> void:
	audio = DiveAudio.new()
	add_child(audio)
	var flows := []
	for p in placed:
		if p.where == "water" and p.shape in FLOW_SHAPES:
			flows.append(p)
	audio.build(camera, right_hand, schools, flows)


func _hint() -> String:
	var things: Array = placed.duplicate()
	var hit := DiveCore.nearest(rov, things, REACH_M)
	if hit.is_empty():
		# The first seconds teach the view switch, then stay quiet.
		return "V (или Y на левом контроллере) — вид: из глаза ROV или " \
			+ "со стороны корпуса" if t < 12.0 else ""
	return "%s — нажми, чтобы взять или рассмотреть" % hit.thing.ru


func _update_water(tel: Dictionary) -> void:
	var c := water_colour(tel.depth)
	env.background_color = c
	env.fog_light_color = c
	# Issyk-Kul is clear: some 25-30 m of view near the surface, less
	# in the dark below the thermocline.
	env.fog_density = 0.035 if tel.depth < DiveCore.THERMOCLINE_M else 0.05
	var left: Dictionary = tel.light
	var avg: float = (left.red + left.green + left.blue) / 3.0
	sun.light_energy = 0.15 + 1.1 * avg
	sun.light_color = Color(0.35 + 0.65 * left.red,
		0.5 + 0.5 * left.green, 0.6 + 0.4 * left.blue)
	env.ambient_light_color = c.lightened(0.3)
	env.ambient_light_energy = 0.25 + 0.6 * avg


func _update_fish() -> void:
	for n in schools.size():
		var s: Dictionary = schools[n]
		var mm: MultiMesh = fish_meshes[n].multimesh
		for i in s.count:
			var p := DiveCore.fish_at(s, i, t)
			var basis := Basis(Vector3.UP, -p.heading).scaled(
				Vector3.ONE * float(s.length))
			mm.set_instance_transform(i, Transform3D(basis,
				Vector3(p.x, -p.depth, p.z)))


## Flow lines in the manner the operator liked in the 2D view: moving
## polylines that trace the water, each after its own physics.
func _flow_lines(p: Dictionary) -> Array:
	var o := Vector3(p.x, -p.depth, p.z)
	var lines := []
	var shape: String = p.shape
	if shape == "eddy":
		for i in 4:
			var pts := []
			var cx := o.x + i * 3.0 + fmod(t * 0.8, 3.0)
			var side := 1.0 if i % 2 else -1.0
			for k in 14:
				var a := k / 13.0 * TAU * side + t * 2.0
				var r := 0.3 + k * 0.08
				pts.append(Vector3(cx + r * cos(a), o.y + r * 0.6 * sin(a),
					o.z + side * 1.2))
			lines.append(pts)
	elif shape in ["intwave", "layer"]:
		for i in 4:
			var pts := []
			for k in 24:
				pts.append(Vector3(o.x - 30.0 + k * 2.6, THERMO_Y + i * 0.5
					+ 1.5 * sin(k * 0.45 - t * 0.6 + i * 0.3), o.z + i))
			lines.append(pts)
	elif shape == "plume":
		for i in 6:
			var pts := []
			for k in 12:
				pts.append(Vector3(o.x + k * 0.8, o.y + (i - 2.5) * (0.1
					+ k * 0.08), o.z + 0.3 * sin(k + t * 2.0 + i)))
			lines.append(pts)
	elif shape == "langmuir":
		for i in 5:
			var pts := []
			for k in 12:
				pts.append(Vector3(o.x + i * 2.0 + 0.2 * sin(k + t * 1.5),
					-0.4, o.z - 6.0 + k))
			lines.append(pts)
	elif shape == "upwelling":
		for i in 5:
			var pts := []
			for k in 12:
				pts.append(Vector3(o.x + (i - 2) * (0.3 + k * 0.15)
					+ 0.2 * sin(k + t * 2.0), o.y + k * 0.6, o.z))
			lines.append(pts)
	else:
		# The seiche current and drifting clouds: parallel slow lines.
		for i in 5:
			var pts := []
			for k in 12:
				pts.append(Vector3(o.x - 3.0 + k * 0.5, o.y + i * 0.4
					+ 0.2 * sin(k + t * 2.0), o.z + i * 0.3))
			lines.append(pts)
	return lines


func _update_lines() -> void:
	flow_mesh.clear_surfaces()
	# The lines and the tether follow the vehicle, not the camera.
	var here := body.position
	var any := false
	for p in placed:
		if p.where != "water" or not p.shape in FLOW_SHAPES:
			continue
		if Vector3(p.x, -p.depth, p.z).distance_to(here) > 45.0:
			continue
		var col := Color(p.colour)
		col.a = 0.7
		for pts in _flow_lines(p):
			if not any:
				flow_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
				any = true
			for k in pts.size() - 1:
				flow_mesh.surface_set_color(col)
				flow_mesh.surface_add_vertex(pts[k])
				flow_mesh.surface_set_color(col)
				flow_mesh.surface_add_vertex(pts[k + 1])
	if any:
		flow_mesh.surface_end()
	# The tether: from the boat at the shore to the ROV, sagging.
	tether_mesh.clear_surfaces()
	tether_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var a := Vector3(30.0, 0.0, 0.0)
	# The tether leaves the top of the body, by its central module.
	var b := here + Vector3(0, 0.45, 0)
	var mid := (a + b) / 2.0 + Vector3(0, -3.0 - a.distance_to(b) * 0.08, 0)
	for k in 21:
		var u := k / 20.0
		tether_mesh.surface_set_color(Color(0.88, 0.63, 0.25))
		tether_mesh.surface_add_vertex(a.lerp(mid, u).lerp(mid.lerp(b, u),
			u))
	tether_mesh.surface_end()
