## Episode 1 "Taboo" in the headset (phase P2 of
## docs/HLD_20MB_PILOT_2026-10-02.md; CLAUDE.md TABOO 0.015).
##
## The first launch opens here, cold: no menu, no logo.  The player's
## room (the headset's passthrough where it has one, a grey cell of the
## operator elsewhere) fills with lake water, the world turns into the
## lake at 38 m, and the 18 beats of godot/data/pilot-1.json play by
## the clock.  At the lure the body drives the ladder of a thought
## (PilotCore.taboo_step); at the khachkar the console goes out; the
## diary breaks off mid-word; the room comes back with the comet on the
## player's hand; the title; then the courtyard, through ModuleLoader.
## A second launch goes straight to the courtyard.
##
## Args (after --): --pilot-replay plays it again, --pilot-speed=N runs
## the clock N times faster (tests), --reduced-motion keeps the tether
## jerk as a fade only.  Nothing here is random.
extends Node3D

const SAVE := "user://pilot.json"
## The lake things the beats light, in metres from the seat.
const AMPHORA_AT := Vector3(0.7, 0.05, -3.0)
const DRAMS_AT := Vector3(-0.35, 0.02, -1.9)
const KHACHKAR_AT := Vector3(0.0, 0.0, -4.6)
const DIARY_AT := Vector3(0.9, 0.05, -3.4)
const DEPTH_START := 38.0
const DEPTH_LAYER := 52.0
const ROOM_HALF := 2.0
const WATER_TOP := 1.75
## Light classes (TABOO 0.38): human work light in the room, the
## instrument's 6500 K lamp under water.
const ROOM_LIGHT := Color(1.0, 0.78, 0.55)
const LAMP_LIGHT := Color(0.92, 0.96, 1.0)

var data := {}
var t := 0.0
var speed := 1.0
var reduced := false
var beat_id := ""
## Beats entered, in order, for tests and the proof frames.
var reached: Array[String] = []
var finished := false
## Set by a test before the scene enters the tree: play even if seen,
## stay when done, and write the record elsewhere.
var replay := false
var stay := false
var save_path := SAVE

var rig: XROrigin3D
var camera: XRCamera3D
var left_hand: XRController3D
var right_hand: XRController3D
var xr_active := false
var passthrough := false
var world := "room"

var room: Node3D
var water: MeshInstance3D
var lake: Node3D
var env: Environment
var lamp: SpotLight3D
var screen: Label3D
var line: Label3D
var title: Label3D
var mark: Node3D
var drams: Node3D
var khachkar: Node3D
var console_level := 1.0

var passion := {}
var state := {}
var body := {}
## The last frame's body, set by the scene or by a test.
var override := {}
var echo := {}
var jerk_from := -1.0
var trigger_was := false

var synth := DiveSynth.new()
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--pilot-speed="):
			speed = maxf(1.0, float(a.get_slice("=", 1)))
	reduced = "--reduced-motion" in args or Haptics.prefers_reduced()
	if seen() and not replay and not "--pilot-replay" in args:
		ModuleLoader.go(ModuleLoader.HUB)
		finished = true
		return
	data = PilotCore.load_data()
	passion = _passion(data.taboo.passion)
	state = PassionCore.start(passion)
	body = PilotCore.body_start()
	_build_rig()
	_build_world()
	_build_room()
	_build_lake()
	_build_screens()
	_build_sound()
	_start_xr()
	_set_world("room")


static func seen() -> bool:
	if not FileAccess.file_exists(SAVE):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	return d is Dictionary and d.get("seen", false)


func _passion(id: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/passions.json"))
	for p in d.passions:
		if p.id == id:
			return p
	return {}


# --- Build --------------------------------------------------------------------

func _mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)


func _build_rig() -> void:
	rig = XROrigin3D.new()
	add_child(rig)
	camera = XRCamera3D.new()
	camera.current = true
	camera.position = Vector3(0, 1.2, 0)
	camera.near = 0.05
	camera.far = 200.0
	rig.add_child(camera)
	left_hand = XRController3D.new()
	left_hand.tracker = &"left_hand"
	rig.add_child(left_hand)
	right_hand = XRController3D.new()
	right_hand.tracker = &"right_hand"
	rig.add_child(right_hand)


func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## The operator's room where there is no passthrough: four walls, a
## table, one warm lamp.  The water plane rises in it either way.
func _build_room() -> void:
	room = Node3D.new()
	add_child(room)
	var wall := _mat(Color(0.42, 0.40, 0.37))
	var h := 2.6
	_box(room, Vector3(ROOM_HALF * 2, 0.05, ROOM_HALF * 2),
		Vector3(0, -0.025, 0), _mat(Color(0.30, 0.25, 0.20)))
	_box(room, Vector3(ROOM_HALF * 2, h, 0.05),
		Vector3(0, h / 2, -ROOM_HALF), wall)
	_box(room, Vector3(ROOM_HALF * 2, h, 0.05),
		Vector3(0, h / 2, ROOM_HALF), wall)
	_box(room, Vector3(0.05, h, ROOM_HALF * 2),
		Vector3(-ROOM_HALF, h / 2, 0), wall)
	_box(room, Vector3(0.05, h, ROOM_HALF * 2),
		Vector3(ROOM_HALF, h / 2, 0), wall)
	_box(room, Vector3(1.2, 0.05, 0.6), Vector3(0, 0.74, -1.1),
		_mat(Color(0.45, 0.32, 0.20)))
	var light := OmniLight3D.new()
	light.light_color = ROOM_LIGHT
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.position = Vector3(0.6, 1.3, -1.0)
	room.add_child(light)
	water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ROOM_HALF * 2, ROOM_HALF * 2)
	water.mesh = pm
	var wm := _mat(Color(0.05, 0.16, 0.20, 0.72), 0.15)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	wm.roughness = 0.05
	water.material_override = wm
	water.position.y = -0.01
	add_child(water)


func _glb(path: String, at: Vector3, parent: Node3D) -> Node3D:
	var ps := load(path) as PackedScene
	var n: Node3D = ps.instantiate() if ps else Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


## The lake at night: silt below, the knight's traces lit one by one.
func _build_lake() -> void:
	lake = Node3D.new()
	add_child(lake)
	# The silt a little below the seat, so the traces lie in the lower
	# half of the view, where a seated head looks without strain.
	_box(lake, Vector3(30, 0.1, 30), Vector3(0, -0.05, -6),
		_mat(Color(0.20, 0.19, 0.15)))
	var amphora := _glb("res://models/atlas/atlas-amphora.glb",
		AMPHORA_AT, lake)
	amphora.rotation.z = 1.2
	khachkar = _glb("res://models/atlas/atlas-khachkar.glb",
		KHACHKAR_AT, lake)
	khachkar.set_meta("noInteract", true)
	khachkar.set_meta("noLoot", true)
	khachkar.visible = false
	var diary := _glb("res://models/atlas/atlas-diary.glb", DIARY_AT, lake)
	diary.name = "Diary"
	diary.visible = false
	# The walls the sonar finds: straight lines among the stones.
	var stone := _mat(Color(0.33, 0.31, 0.27))
	var walls := Node3D.new()
	walls.name = "Walls"
	walls.visible = false
	lake.add_child(walls)
	_box(walls, Vector3(4.0, 0.5, 0.4), Vector3(-1.5, 0.25, -6.5), stone)
	_box(walls, Vector3(0.4, 0.5, 3.0), Vector3(-3.5, 0.25, -5.2), stone)
	# The lure: silver drams that shine without the lamp (the shine is
	# the prilog's sign, TABOO 0.2 item 8).
	drams = Node3D.new()
	drams.position = DRAMS_AT
	drams.visible = false
	lake.add_child(drams)
	var silver := _mat(Color(0.86, 0.86, 0.80), 0.9)
	silver.metallic = 1.0
	for i in 7:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.035
		cm.height = 0.006
		c.mesh = cm
		c.material_override = silver
		c.position = Vector3(0.05 * (i % 4) - 0.08, 0.004 * i,
			0.05 * (i / 4))
		c.rotation.x = 0.15 * (i % 3)
		drams.add_child(c)
	lamp = SpotLight3D.new()
	lamp.light_color = LAMP_LIGHT
	lamp.light_energy = 0.0
	lamp.spot_range = 9.0
	lamp.spot_angle = 24.0
	camera.add_child(lamp)


func _label(size: int, at: Vector3, c: Color) -> Label3D:
	var l := Label3D.new()
	l.font_size = size
	l.pixel_size = 0.0012
	l.modulate = c
	l.outline_size = 6
	l.no_depth_test = true
	l.render_priority = 2
	l.width = 900
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = at
	camera.add_child(l)
	return l


func _build_screens() -> void:
	# The second screen of the console, cyan of the instrument; lines of
	# the scribe and the diary below it, warm; the title in the middle.
	screen = _label(34, Vector3(0.28, 0.12, -1.0), Color(0.55, 0.92, 1.0))
	line = _label(30, Vector3(0, -0.22, -1.0), Color(1.0, 0.88, 0.66))
	title = _label(64, Vector3(0, 0.02, -1.2), Color(0.95, 0.93, 0.88))
	title.visible = false
	# The comet on the hand: a dim head and a tail, no glow (node 99).
	mark = Node3D.new()
	mark.visible = false
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.006
	sm.height = 0.012
	head.mesh = sm
	var ink := _mat(Color(0.32, 0.20, 0.16))
	head.material_override = ink
	mark.add_child(head)
	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.035, 0.002, 0.004)
	tail.mesh = tm
	tail.material_override = ink
	tail.position = Vector3(0.02, 0, 0.002)
	tail.rotation.y = 0.2
	mark.add_child(tail)
	left_hand.add_child(mark)


func _build_sound() -> void:
	var bus := DiveAudio.ensure_bus()
	player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = DiveSynth.MIX_RATE
	gen.buffer_length = 0.25
	player.stream = gen
	player.bus = AudioServer.get_bus_name(bus)
	add_child(player)
	if DisplayServer.get_name() != "headless":
		player.play()
		playback = player.get_stream_playback()


# --- XR -----------------------------------------------------------------------

func _start_xr() -> void:
	var openxr := XRServer.find_interface("OpenXR")
	if openxr and openxr.is_initialized():
		get_viewport().use_xr = true
		xr_active = true
		camera.position = Vector3.ZERO
		# The room through the headset's own cameras: the game never
		# sees those frames, it only lets the room show through.
		var modes: Array = openxr.get_supported_environment_blend_modes()
		passthrough = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes


## The room or the lake.  With passthrough the room is the player's
## own, so the grey cell is hidden and the background is clear.
func _set_world(w: String) -> void:
	world = w
	var in_room := w == "room"
	room.visible = in_room and not passthrough
	lake.visible = not in_room
	water.visible = in_room
	if passthrough:
		var xr := XRServer.find_interface("OpenXR")
		xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND \
			if in_room else XRInterface.XR_ENV_BLEND_MODE_OPAQUE
		get_viewport().transparent_bg = in_room
	if in_room:
		env.background_color = Color(0, 0, 0, 0) if passthrough \
			else Color(0.08, 0.08, 0.09)
		env.ambient_light_color = Color(0.35, 0.33, 0.30)
		env.fog_density = 0.0
	else:
		env.background_color = Color(0.01, 0.04, 0.06)
		env.ambient_light_color = Color(0.03, 0.08, 0.10)
		env.fog_light_color = Color(0.02, 0.07, 0.09)
		env.fog_density = 0.12


# --- Clock --------------------------------------------------------------------

func _process(dt: float) -> void:
	if finished or data.is_empty():
		return
	var step := dt * speed
	t += step
	var b := PilotCore.beat_at(data, t)
	if b.get("id", "") != beat_id:
		_enter(b)
	_tick(step)
	if t >= float(data.length_s) + 4.0:
		_finish()


func _enter(b: Dictionary) -> void:
	beat_id = b.id
	reached.append(beat_id)
	if b.has("message_ru"):
		screen.text = b.message_ru
	if b.has("line_ru"):
		line.text = b.line_ru
	if b.has("preload") and not stay:
		# The courtyard comes after the title; it loads while the lake
		# plays (TABOO 0.014), not in the frame of the change.
		ModuleLoader.prefetch(ModuleLoader.HUB)
	if b.has("haptic"):
		var kind := "knot" if b.haptic == "drop" else "act_done"
		Haptics.pulse(right_hand, kind, reduced)
		Haptics.pulse(left_hand, kind, reduced)
	if b.world != world:
		_set_world(b.world)
	match b.id:
		"tether_jerk":
			jerk_from = t
		"choice_echo":
			echo = PilotCore.echo(data, str(state.stage))
			screen.text = echo.message_ru
			line.text = echo.get("scribe_ru", "")
		"khachkar":
			# The machine has nothing to say at the holy; what it said
			# before does not come back after.
			screen.text = ""
			line.text = ""
		"room_drains":
			screen.text = ""
			line.text = ""
			if not xr_active and mark.get_parent() != camera:
				# On a screen the hand is held up in front of the eyes.
				mark.reparent(camera, false)
				mark.position = Vector3(-0.12, -0.12, -0.45)
				mark.scale = Vector3.ONE * 2.0
		"title":
			title.text = b.title_ru
			screen.text = ""
			line.text = ""


## What is lit and shown follows the clock alone, so a frame that skips
## a beat (a dropped frame, a test, a proof shot) shows the same as one
## that walked through it.
func _sync() -> void:
	lamp.light_energy = 3.0 if t >= 70.0 and t < 860.0 else 0.0
	if t >= 590.0:
		# After the choice the lamp is the operator's again.
		lamp.rotation = Vector3.ZERO
	lake.get_node("Walls").visible = t >= 140.0
	drams.visible = t >= 440.0 and t < 590.0
	khachkar.visible = t >= 640.0
	lake.get_node("Diary").visible = t >= 720.0
	mark.visible = t >= 860.0
	title.visible = t >= 900.0


func _tick(dt: float) -> void:
	_sync()
	# The water climbs from the floor to the eyes in the 17 s before
	# the lake; at the drain it goes back into the floor.
	if beat_id == "water_rises":
		var k := clampf((t - 8.0) / 17.0, 0.0, 1.0)
		water.position.y = k * WATER_TOP
	elif beat_id == "room_drains":
		var k := clampf((t - 860.0) / 12.0, 0.0, 1.0)
		water.position.y = (1.0 - k) * 0.4
	elif beat_id == "drop":
		water.position.y = -0.01
	_jerk()
	if beat_id in ["lure", "price_rises"]:
		_taboo(dt)
	# At the holy the console goes out in 1.75 s and stays out while
	# the khachkar is in the beam (TABOO 0.4 item 2).
	var target := 0.0 if beat_id == "khachkar" else 1.0
	console_level = move_toward(console_level, target, dt / 1.75)
	screen.modulate.a = console_level
	_sound(dt)


func _jerk() -> void:
	if jerk_from < 0.0:
		return
	var k := clampf((t - jerk_from) / float(data.comfort.jerk_s), 0.0,
		1.0)
	if reduced:
		# Reduced motion: no turn of the world, a dimming instead.
		env.ambient_light_energy = 1.0 - 0.6 * sin(k * PI)
	else:
		rig.rotation.y = deg_to_rad(float(data.comfort.jerk_yaw_deg)) \
			* (1.0 - pow(1.0 - k, 3.0))
	if k >= 1.0:
		jerk_from = -1.0


## The body at the lure: head gaze, the turn away, the nearer hand,
## a breath finished on the rope (a trigger squeeze, or Space on a
## screen).  A test sets `override` instead.
func _body_input() -> Dictionary:
	if not override.is_empty():
		return override
	var fwd := -camera.global_basis.z
	var to := drams.global_position - camera.global_position
	var ang := rad_to_deg(fwd.angle_to(to))
	var hand := INF
	if xr_active:
		for h in [left_hand, right_hand]:
			hand = minf(hand, h.global_position.distance_to(
				drams.global_position))
	var trig := right_hand.is_button_pressed("trigger_click") \
		or Input.is_key_pressed(KEY_SPACE)
	var exhale := trig and not trigger_was
	trigger_was = trig
	return {"gaze": PilotCore.gaze_on(fwd, to,
		float(data.taboo.gaze_cone_deg)), "away_deg": ang, "hand_m": hand,
		"exhale": exhale}


func _taboo(dt: float) -> void:
	var r := PilotCore.taboo_step(state, passion, body, data.taboo, dt,
		_body_input())
	var was: String = state.stage
	state = r.state
	body = r.body
	if state.stage == was:
		return
	match state.stage:
		"converse":
			# The lamp turns to the shine by itself: "I am seen".
			if lamp.is_inside_tree() and lamp.global_position \
					.distance_to(drams.global_position) > 0.01:
				lamp.look_at_from_position(lamp.global_position,
					drams.global_position)
			screen.text = "Цена растёт. Вы же смотрите."
		"consent":
			screen.text = "Оператор «Мангустика». 52 метра. Мы знаем."
		"captive":
			screen.text = "Принято."
		"stillness":
			lamp.rotation = Vector3.ZERO
			screen.text = ""
			line.text = "Три выдоха."
		"virtue":
			line.text = ""


func _depth() -> float:
	if beat_id in ["drop", "water_rises"]:
		return 0.0
	var k := clampf((t - 25.0) / 185.0, 0.0, 1.0)
	var d := lerpf(DEPTH_START, DEPTH_LAYER, k)
	if t > 820.0:
		d = lerpf(d, 5.0, clampf((t - 820.0) / 40.0, 0.0, 1.0))
	return d


## The dive's own synth: the sonar, the water, the layer's shimmer when
## the depth crosses 50 m.  At the khachkar the machine goes down to
## -60 dBFS over the console's 1.75 s, room tone and breath stay.
func _sound(dt: float) -> void:
	if beat_id in ["drop", "room_drains", "prior_last", "title"]:
		synth.update({"depth": 0.0, "thrust": 0.0, "shore_m": 2000.0},
			dt)
	else:
		synth.update({"depth": _depth(), "thrust": 0.15,
			"shore_m": 2000.0, "echo_delay": 2.0 * 2.0 / 1480.0}, dt)
	player.volume_db = lerpf(-60.0, 0.0, console_level)
	if playback:
		var frames := playback.get_frames_available()
		if frames > 0:
			var mono := synth.generate(frames)
			var buf := PackedVector2Array()
			buf.resize(frames)
			for i in frames:
				buf[i] = Vector2(mono[i], mono[i])
			playback.push_buffer(buf)


func _finish() -> void:
	finished = true
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"seen": true,
			"stage": state.get("stage", "prilog"),
			"episode2": echo.get("episode2", "prior_waits")}))
		f.close()
	if not stay:
		ModuleLoader.go(ModuleLoader.HUB)
