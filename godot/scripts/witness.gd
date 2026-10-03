## The path of the witness in the headset (docs/HLD_APK_PRIORITY A3).
##
## Seven scene kits in the dark, each lit by its own lamp (1800 K) or
## its dawn, along one path.  The player walks, stands, turns, bows the
## head and leaves; the path's edge is every kit's witness line.  There
## is no prompt, no counter, no reward and no record of the visit, and
## no microphone is ever opened (TABOO 0.26 point 10).  The sound is the
## room's own tone (never digital zero), the ison of the brethren a
## cappella by the kit one stands at, and the far monastery's bells at
## the hours the Typikon sets (WitnessAudio, docs/HLD_WITNESS_SOUND_
## 2026-09-30.md).  Nothing the walker does rings a bell.  B or Esc:
## back to the courtyard (Nav).  --now=YYYY-MM-DDTHH:MM sets the clock
## (for shots and listening tests).
extends Node3D

const WALK_MPS := 1.2
const LAMPADA_K := LocationCore.LAMPADA_K   # 1800 K, one source.
const DAWN := Color(1.0, 0.72, 0.5)

var bays: Array = []
var pos := WitnessCore.START
var yaw := -PI / 2.0  # Facing +X, down the path.
var t := 0.0
var xr_active := false
var snap_ready := true

var rig: XROrigin3D
var camera: XRCamera3D
var left_hand: XRController3D
var right_hand: XRController3D
var tone: AudioStreamGeneratorPlayback
var audio := WitnessAudio.new()
var webxr: XRInterface
var vr_button: Button

var shots_dir := ""
var shot_frame := 0


func _ready() -> void:
	var now := Time.get_datetime_dict_from_system()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--now="):
			var text := arg.trim_prefix("--now=")
			if text.length() == 16:
				text += ":00"
			now = Time.get_datetime_dict_from_datetime_string(text, false)
	audio.set_now(now)
	_build_world()
	_build_bays()
	_build_rig()
	_build_tone()
	_start_xr()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(shots_dir)


func _mat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.95
	return m


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.3, 0.28)
	env.ambient_light_energy = 0.3
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.035
	env.fog_light_color = Color(0.05, 0.05, 0.07)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The path: packed earth with an oak edge on each side, the witness
	# line made visible as a low wooden kerb, not as a glowing marker.
	var n := WitnessCore.ORDER.size()
	var length := WitnessCore.path_end(n) - WitnessCore.START.x + 4.0
	var mid := (WitnessCore.path_end(n) + WitnessCore.START.x) / 2.0
	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(length + 20.0, 0.1, 60.0)
	ground.mesh = plane
	ground.material_override = _mat(Color(0.2, 0.18, 0.16))
	ground.position = Vector3(mid, -0.06, 0)
	add_child(ground)
	for side in [-1.0, 1.0]:
		var kerb := MeshInstance3D.new()
		var k := BoxMesh.new()
		k.size = Vector3(length, 0.08, 0.12)
		kerb.mesh = k
		kerb.material_override = _mat(Color(0.36, 0.25, 0.15))
		kerb.position = Vector3(mid, 0.04, side * (WitnessCore.PATH_HALF
			+ 0.06))
		add_child(kerb)
	var board := Label3D.new()
	board.text = "Тропа свидетеля\n\nСтоять можно. Подходить — до черты.\n" \
		+ "B или Esc — назад во двор."
	board.font_size = 40
	board.pixel_size = 0.004
	board.modulate = Color(0.95, 0.85, 0.65)
	board.position = Vector3(WitnessCore.START.x - 1.2, 1.6, 0)
	board.rotation_degrees = Vector3(0, -90, 0)
	add_child(board)


## Find the kit's witness line (its node "witness-line") and its lamps.
func _nodes_named(root: Node, part: String) -> Array:
	var out := []
	for c in root.find_children("*", "Node3D", true, false):
		if String(c.name).to_lower().contains(part):
			out.append(c)
	return out


func _build_bays() -> void:
	var kits := {}
	var witness_z := {}
	for id in WitnessCore.ORDER:
		var scene := load("res://models/scene/sacrament-%s.glb" % id) \
			as PackedScene
		var kit := scene.instantiate() as Node3D
		kits[id] = kit
		var lines := _nodes_named(kit, "witness")
		if not lines.is_empty():
			witness_z[id] = (lines[0] as Node3D).position.z
	bays = WitnessCore.bays(witness_z)
	for b in bays:
		var kit: Node3D = kits[b.id]
		kit.position = Vector3(b.x, 0, b.z)
		kit.rotation.y = b.yaw
		add_child(kit)
		_cut_away(kit, b.witness_z)
		# The kit's own light: its lamp before the icon at 1800 K, or
		# the dawn over the shore for the scenes by the water.
		var light := OmniLight3D.new()
		var dawn: bool = "dawn" in b.meta.get("lights", [])
		light.light_color = DAWN if dawn else LAMPADA_K
		light.light_energy = 2.2 if dawn else 2.0
		light.omni_range = 11.0 if dawn else 7.0
		var lamps := _nodes_named(kit, "lampada")
		var at := Vector3(0, 2.2, 0)
		if not lamps.is_empty():
			at = (lamps[0] as Node3D).position + Vector3(0, 0.3, 0)
		light.position = at
		kit.add_child(light)
		# A plain plaque at the path's edge with the kit's own title
		# (never the word for the rite: TABOO 0.39 rule 3).
		var plaque := Label3D.new()
		plaque.text = b.meta.title
		plaque.font_size = 36
		plaque.pixel_size = 0.0028
		plaque.modulate = Color(0.9, 0.8, 0.62)
		plaque.position = Vector3(b.x - 3.0, 1.1,
			b.side * (WitnessCore.PATH_HALF + 0.15))
		# It turns to the walker about the vertical only, so it reads
		# from anywhere on the path and never lies on the ground.
		plaque.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(plaque)
		# The kit's static parts that are not holy are drawn together
		# (Б-1: 100 draw calls a frame); holy objects keep their nodes.
		WitnessBatch.batch_kit(kit, b.meta.get("holyObjects", []))
	# B2 hook: the preparation sheet at the corner of repentance.
	ConfessionSheet.place(self, bays[WitnessCore.ORDER.find("confession")])


## A doll's-house cut: tall parts that stand between the path and the
## witness line (a west wall, a chapel wall) are hidden, so the path
## looks in from the line instead of at an outer wall.  Low things on
## the walker's side (the bench of those waiting) stay.
func _cut_away(kit: Node3D, witness_z: float) -> void:
	for m in kit.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		# In the kit's own frame, walked through the parents, so the path
		# builds the same outside the tree (test_witness.gd).
		var box := WitnessBatch.relative(mi, kit) * mi.get_aabb()
		if box.get_center().z > witness_z + 0.2 and box.size.y > 1.6:
			mi.visible = false


func _build_rig() -> void:
	rig = XROrigin3D.new()
	add_child(rig)
	camera = XRCamera3D.new()
	camera.current = true
	camera.position = Vector3(0, 1.6, 0)
	camera.near = 0.05
	camera.far = 200.0
	rig.add_child(camera)
	left_hand = XRController3D.new()
	left_hand.tracker = &"left_hand"
	rig.add_child(left_hand)
	right_hand = XRController3D.new()
	right_hand.tracker = &"right_hand"
	rig.add_child(right_hand)


func _build_tone() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = WitnessAudio.MIX_RATE
	gen.buffer_length = 0.3
	var player := AudioStreamPlayer.new()
	player.stream = gen
	add_child(player)
	player.play()
	tone = player.get_stream_playback() as AudioStreamGeneratorPlayback


## Leaving the path: a bell clip still rendering on the worker thread
## finishes first, so the thread never outlives the synth it writes to.
func _exit_tree() -> void:
	if audio.bells.task != -1:
		WorkerThreadPool.wait_for_task_completion(audio.bells.task)
		audio.bells.task = -1


func _feed_tone() -> void:
	if tone == null:
		return
	# The day's bell strokes are rendered ahead of the hour, so no frame
	# waits for a bell: on a worker thread in the APK, a little every
	# frame in the Web build, which is exported without threads.
	if OS.has_feature("web"):
		audio.bells.warm(WitnessAudio.WARM_PER_FRAME_WEB)
	else:
		audio.bells.warm_async()
	audio.listen(pos, bays)
	var n := tone.get_frames_available()
	if n <= 0:
		return
	tone.push_buffer(audio.generate(n))


func _stick(hand: XRController3D) -> Vector2:
	var v := hand.get_vector2("primary")
	if v == Vector2.ZERO:
		v = hand.get_vector2("thumbstick")
	return v


func _key(a: Key, b: Key) -> float:
	return float(Input.is_key_pressed(a)) - float(Input.is_key_pressed(b))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not xr_active \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.004
		camera.rotation.x = clampf(camera.rotation.x
			- event.relative.y * 0.003, -1.2, 1.2)


func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	t += dt
	var move := Vector2(_key(KEY_D, KEY_A), _key(KEY_S, KEY_W))
	if xr_active:
		var l := _stick(left_hand)
		var r := _stick(right_hand)
		move = Vector2(l.x, -l.y)
		if absf(r.x) > 0.7 and snap_ready:
			yaw -= deg_to_rad(30.0) * signf(r.x)
			snap_ready = false
		elif absf(r.x) < 0.3:
			snap_ready = true
	else:
		yaw += _key(KEY_Q, KEY_E) * 1.5 * dt
	var heading := yaw
	if xr_active:
		var z := camera.transform.basis.z
		heading = yaw + atan2(z.x, z.z)
	var dir := Vector3(move.x, 0, move.y).rotated(Vector3.UP, heading)
	pos = WitnessCore.clamp_walk(pos + dir * WALK_MPS * dt, bays.size())
	rig.position = pos
	rig.rotation.y = yaw
	_feed_tone()
	if shots_dir != "":
		_shots()


# --- XR (as in the hub) -----------------------------------------------

func _start_xr() -> void:
	var openxr := XRServer.find_interface("OpenXR")
	if openxr and openxr.is_initialized():
		get_viewport().use_xr = true
		xr_active = true
		return
	webxr = XRServer.find_interface("WebXR")
	if webxr and webxr.is_initialized():
		get_viewport().use_xr = true
		xr_active = true
		return
	if webxr:
		webxr.session_supported.connect(_on_webxr_supported)
		webxr.session_started.connect(_on_webxr_started)
		webxr.is_session_supported("immersive-vr")


func _on_webxr_supported(mode: String, supported: bool) -> void:
	if mode != "immersive-vr" or not supported:
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	vr_button = Button.new()
	vr_button.text = "Войти в шлем"
	vr_button.position = Vector2(24, 24)
	vr_button.add_theme_font_size_override("font_size", 28)
	vr_button.pressed.connect(_enter_webxr)
	layer.add_child(vr_button)


func _enter_webxr() -> void:
	webxr.session_mode = "immersive-vr"
	webxr.requested_reference_space_types = "local-floor, local"
	webxr.required_features = "local"
	webxr.optional_features = "local-floor"
	webxr.initialize()


func _on_webxr_started() -> void:
	get_viewport().use_xr = true
	xr_active = true
	if vr_button:
		vr_button.visible = false


## --shots=<dir>: the entrance, then the path at three kits.
func _shots() -> void:
	var plan := [[WitnessCore.START, -PI / 2.0, "entrance"],
		[Vector3(bays[0].x - 3.0, 0, -1.2), -PI / 2.0 + 0.9, "shore"],
		[Vector3(bays[2].x - 3.0, 0, -1.2), -PI / 2.0 + 0.9, "west-wall"],
		[Vector3(bays[3].x - 3.0, 0, 1.2), -PI / 2.0 - 0.9, "waiting"],
		[Vector3(bays[3].x - 5.2, 0, 0.4), PI, "confession-sheet"]]
	var n := shot_frame / 20
	if n >= plan.size():
		get_tree().quit()
		return
	pos = plan[n][0]
	yaw = plan[n][1]
	camera.rotation.x = -0.12
	if shot_frame % 20 == 19:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/witness-%s.png" % [shots_dir, plan[n][2]])
	shot_frame += 1
