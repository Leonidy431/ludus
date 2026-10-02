## One location of our plots in the headset (CLAUDE.md TABOO 0.013,
## docs/HLD_LOCATIONS_99_2026-09-30.md phase L4).
##
## The place is built from data (LocationCore.plan, LocationBuild): its
## shell and light, its real things on their slots, one heart in the
## middle of it and the way back to the courtyard of the obitel.  At the
## heart the player does the place's one practice or action on a
## birch-bark panel (LocationHeart), with the same rules and the same
## save as the hub, so what is done here counts there and back.
##
## Which place: location_id when a caller sets it before the node enters
## the tree, else the one chosen at the hub's "road of places"
## (LocationCore.go), else --location=<id>.  The way back is the door
## (or, under water, the line up to the surface); B or Esc also brings
## the player back.  Controls as in the hub: stick or WASD to walk,
## right stick or Q/E to turn, trigger, E or Space to act, the stick or
## the arrows and 1-4 to choose on a panel.
##
## --shots=<dir> --locations=a,b,c renders each place as it is entered,
## at its heart with the prompt read, and with its heart's panel open,
## for the eye check (TABOO 0.013 item 7); nothing is saved while proof
## frames are taken.
extends Node3D

const WALK_MPS := 1.4
const HUB := "res://scenes/hub.tscn"
const SHOT_FRAMES := 20
## Where the frames at the heart are taken: inside its reach (2.2 m),
## in front of it, as a player stands to act.
const SHOT_NEAR_M := 1.3

## Set by a caller before the node enters the tree (tests, tools).
var location_id := ""
var data: Dictionary = {}
var loc: Dictionary = {}
var p: Dictionary = {}
var ctx: Dictionary = {}
var st: Dictionary = {}
var heart_panel: Dictionary = {}
var world: Node3D
var things: Array = []
var pos := Vector3.ZERO
var yaw := 0.0
var t := 0.0
var xr_active := false
var snap_ready := true
var interact_was := false
var stick_was := 0.0
var back_was := false
var keys_was := {}
var message := ""
var message_left := 0.0
var proof := false
## How visible the interface is: it goes near the place's holy thing
## (LocationCore.holy_fade_target) over 1.75 s and comes back after.
var ui_alpha := 1.0

var rig: XROrigin3D
var camera: XRCamera3D
var left_hand: XRController3D
var right_hand: XRController3D
var panel: Label3D
var panel_bg: MeshInstance3D
var prompt3d: Label3D
var hud: Label
var figure: Sprite3D
var webxr: XRInterface
var vr_button: Button
## The place's sound (PlaceSound, PlaceAudio; track A of docs/HLD_APK_
## GRAPHICS_SOUND_2026-10-01.md).
var sound: PlaceAudio
## The felt answer to a step of the heart's act (ActCue): its sound and
## the place's lamp, brightened for a moment when the act closes.
var cue_player: AudioStreamPlayer3D
var lamp: OmniLight3D
var lamp_energy := 0.0
var lamp_glow := 0.0
## Standing still while an act asks to wait (StormCalm): the stick's
## watch with its dead zone and grace, and the calm the place shows
## (-1 where the act asks no waiting).
var still_watch := StormCalm.new_watch()
var storm_shown := -1.0
## The kinds of ActCue answered in this visit, for tests (not saved).
var cues: Array = []

var shots_dir := ""
var shot_list: Array = []
var shot_frame := 0


func _ready() -> void:
	data = LocationCore.load_data()
	ctx = LocationHeart.context()
	var id := location_id
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--location="):
			id = arg.trim_prefix("--location=")
		elif arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--locations="):
			shot_list = Array(arg.trim_prefix("--locations=").split(",",
				false))
	proof = shots_dir != ""
	if proof:
		DirAccess.make_dir_recursive_absolute(shots_dir)
		if shot_list.is_empty():
			shot_list = [id if id != "" else data.locations[0].id]
		id = shot_list[0]
	if id == "":
		id = LocationCore.chosen(get_tree())
	if LocationCore.by_id(data, id).is_empty():
		id = data.locations[0].id
	st = LocationCore.read_state()
	_build_rig()
	_build_ui()
	open_place(id)
	_start_xr()


## Take down the place standing and build another.
func open_place(id: String) -> void:
	if world != null:
		remove_child(world)
		world.free()
	loc = LocationCore.by_id(data, id)
	p = LocationCore.plan(loc, data.things, LocationCore.load_items(),
		LocationCore.load_kits())
	world = LocationBuild.build(p)
	add_child(world)
	if sound == null:
		sound = PlaceAudio.new()
		sound.name = "PlaceSound"
		add_child(sound)
	sound.start(PlaceSound.plan(p))
	if cue_player == null:
		cue_player = AudioStreamPlayer3D.new()
		cue_player.name = "ActCue"
		add_child(cue_player)
	cue_player.position = p.heart + Vector3(0, 1.0, 0)
	lamp = null
	lamp_glow = 0.0
	storm_shown = -1.0
	still_watch = StormCalm.new_watch()
	for n in ["HearthLight", "InstrumentLight"]:
		var l := world.find_child(n, true, false)
		if l is OmniLight3D:
			lamp = l
			lamp_energy = lamp.light_energy
	things = [{"id": "heart", "pos": p.heart, "reach": LocationCore.REACH_M,
			"ru": p.hint},
		{"id": "exit", "pos": p.exit, "reach": LocationCore.EXIT_REACH_M,
			"ru": LocationCore.exit_ru(p)}]
	figure = Sprite3D.new()
	figure.pixel_size = 0.008
	figure.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# Unshaded, as on the hub's road: the figure is read, not lit.
	figure.shaded = false
	figure.visible = false
	figure.position = p.heart + Vector3(0, 1.75, -0.6)
	world.add_child(figure)
	pos = p.start
	yaw = 0.0
	heart_panel = {}
	ui_alpha = LocationCore.holy_fade_target(p, pos)
	_say(p.title)


# --- Rig and interface ------------------------------------------------------

func _build_rig() -> void:
	rig = XROrigin3D.new()
	add_child(rig)
	camera = XRCamera3D.new()
	camera.current = true
	camera.position = Vector3(0, 1.6, 0)
	camera.near = 0.05
	camera.far = 600.0
	rig.add_child(camera)
	left_hand = XRController3D.new()
	left_hand.tracker = &"left_hand"
	rig.add_child(left_hand)
	right_hand = XRController3D.new()
	right_hand.tracker = &"right_hand"
	rig.add_child(right_hand)


## The panel is the hub's: birch bark in front of the eyes, never hidden
## behind the place's things (TABOO 0.38 item 3).
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 20)
	layer.add_child(hud)
	panel_bg = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 0.72)
	panel_bg.mesh = qm
	var bark := LocationBuild.mat(LocationBuild.BARK)
	bark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bark.no_depth_test = true
	bark.render_priority = 1
	panel_bg.material_override = bark
	panel_bg.position = Vector3(0, -0.05, -0.92)
	panel_bg.visible = false
	camera.add_child(panel_bg)
	panel = Label3D.new()
	panel.font_size = 38
	panel.pixel_size = 0.0007
	panel.width = 1300
	panel.no_depth_test = true
	panel.render_priority = 2
	panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.modulate = Color(0.16, 0.12, 0.08)
	panel.outline_size = 0
	panel.position = Vector3(0, -0.05, -0.9)
	panel.visible = false
	camera.add_child(panel)
	prompt3d = Label3D.new()
	prompt3d.font_size = 28
	prompt3d.pixel_size = 0.0007
	prompt3d.position = Vector3(0, -0.32, -0.9)
	prompt3d.modulate = Color(0.95, 0.9, 0.78)
	camera.add_child(prompt3d)


# --- Controls ---------------------------------------------------------------

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
	if event is InputEventKey and event.pressed and not heart_panel.is_empty():
		var n: int = event.keycode - KEY_1
		if n >= 0 and n < 4:
			_select(n)


func _process(dt: float) -> void:
	_light(dt)
	dt = minf(dt, 0.1)
	t += dt
	if proof:
		_shots()
		return
	var move := Vector2(_key(KEY_D, KEY_A), _key(KEY_S, KEY_W))
	var interact := Input.is_key_pressed(KEY_E) and heart_panel.is_empty() \
		or Input.is_key_pressed(KEY_SPACE)
	var nav := _key(KEY_UP, KEY_DOWN)
	var back := Input.is_key_pressed(KEY_ESCAPE)
	if xr_active:
		var l := _stick(left_hand)
		var r := _stick(right_hand)
		move = Vector2(l.x, -l.y)
		nav = r.y
		if absf(r.x) > 0.7 and snap_ready:
			yaw -= deg_to_rad(30.0) * signf(r.x)
			snap_ready = false
		elif absf(r.x) < 0.3:
			snap_ready = true
		interact = interact or right_hand.is_button_pressed("trigger_click")
		back = back or right_hand.is_button_pressed("by_button")
	else:
		yaw += _key(KEY_Q, KEY_E) * 1.5 * dt
	if back and not back_was:
		# Back closes an open panel first (as its "Отойти"), then leaves.
		if heart_panel.is_empty():
			_leave()
			return
		heart_panel = {}
	back_was = back
	if heart_panel.is_empty():
		var heading := yaw
		if xr_active:
			var z := camera.transform.basis.z
			heading = yaw + atan2(z.x, z.z)
		var dir := Vector3(move.x, 0, move.y).rotated(Vector3.UP, heading)
		pos += dir * WALK_MPS * dt
		var m := 0.3
		pos.x = clampf(pos.x, -p.w / 2.0 + m, p.w / 2.0 - m)
		pos.z = clampf(pos.z, -p.d / 2.0 + m, p.d / 2.0 - m)
	elif absf(nav) > 0.6 and absf(stick_was) <= 0.6:
		var n := LocationHeart.choices(heart_panel, loc, st, ctx).size()
		heart_panel.choice = posmod(int(heart_panel.choice)
			- int(signf(nav)), maxi(1, n))
	stick_was = nav
	rig.position = pos
	rig.rotation.y = yaw
	sound.listen(pos)
	if interact and not interact_was:
		if heart_panel.is_empty():
			_interact()
		else:
			_select(int(heart_panel.choice))
	interact_was = interact
	# A tremor of the thumb is not a step (StormCalm.watch).
	still_watch = StormCalm.watch(still_watch, move.length(), dt)
	if not heart_panel.is_empty():
		_apply(LocationHeart.tick(heart_panel, loc, st, ctx, dt,
			still_watch.still), true)
	_storm(dt)
	message_left = maxf(0.0, message_left - dt)
	_fade(dt)
	_refresh()


## The interface goes near the holy thing and returns after, never
## faster than CockpitCore.FADE_SECONDS for the whole way (TABOO 0.4
## item 2).  At the holy thing an open panel closes: nothing there is
## counted, offered or named.
func _fade(dt: float) -> void:
	ui_alpha = CockpitCore.fade_step(ui_alpha,
		LocationCore.holy_fade_target(p, pos), dt)
	if ui_alpha <= 0.0 and not heart_panel.is_empty():
		heart_panel = {}


func _nearest() -> Dictionary:
	var best := {}
	var best_d := INF
	for th in things:
		var d := Vector2(th.pos.x - pos.x, th.pos.z - pos.z).length()
		if d < float(th.reach) and d < best_d:
			best = th
			best_d = d
	return best


func _interact() -> void:
	# Beside the holy thing nothing answers a press.
	if LocationCore.holy_fade_target(p, pos) <= 0.0:
		return
	var th := _nearest()
	if th.is_empty():
		return
	if th.id == "exit":
		_leave()
		return
	_apply(LocationHeart.open(loc, st, ctx))


func _select(i: int) -> void:
	_apply(LocationHeart.choose(heart_panel, loc, st, ctx, i))


## Keep what a choice changed: the panel, the state, the words, the save
## (never while proof frames are taken) and a change of scene.  A tick
## (from_tick) answers only when it closes the act: the seconds of a
## wait move the act's state every frame, and each of them read as a
## "right" step knocked and pulsed every frame of the wait.
func _apply(r: Dictionary, from_tick := false) -> void:
	var given_before: Array = st.get("atlas_given", [])
	var deed_before = heart_panel.get("deed")
	st = r.st
	heart_panel = r.panel
	var deed_after = r.panel.get("deed")
	if deed_before is Dictionary and deed_after is Dictionary:
		var k := ActCue.kind(deed_before, deed_after)
		if not from_tick or k == "done":
			_cue(k)
	if r.say != "":
		_say(r.say)
	if r.save and not proof:
		LocationCore.write_state(st)
		if st.atlas_given != given_before:
			LocationCore.write_given(st.atlas_given)
	if r.scene != "" and not proof:
		get_tree().change_scene_to_file(r.scene)


## Touch, sound and light for one step of the act, in the same frame.
func _cue(k: String) -> void:
	if k == "":
		return
	cues.append(k)
	Haptics.pulse(right_hand if xr_active else null, "act_" + k,
		Haptics.prefers_reduced())
	if not proof:
		cue_player.stream = ActCue.wav(k)
		cue_player.play()
	if k == "done" and lamp != null:
		lamp_glow = ActCue.LIGHT_SECONDS


## The place's lamp in one place: the brief brightening after an act
## closes, easing back, and the lantern's flicker in a storm.
func _light(dt: float) -> void:
	if lamp == null:
		return
	lamp_glow = maxf(0.0, lamp_glow - dt)
	var e := lamp_energy * lerpf(1.0, ActCue.LIGHT_DONE,
		lamp_glow / ActCue.LIGHT_SECONDS)
	if storm_shown >= 0.0:
		e *= StormCalm.lamp_factor(storm_shown, t)
	lamp.light_energy = e


## While the heart's act asks to wait, the place answers the waiting
## with no number (StormCalm): the lantern steadies and the surf and the
## rain grow quieter as the seconds are stood, and the storm comes back
## when the player moves.  Once the act is done the storm has passed.
func _storm(dt: float) -> void:
	var id := PlaceDeeds.act_of(loc.get("heart", {}))
	if not StormCalm.has_wait(id):
		storm_shown = -1.0
		sound.craft_db = 0.0
		return
	var deed = heart_panel.get("deed")
	var target := storm_shown if storm_shown >= 0.0 else 0.0
	if deed is Dictionary:
		target = StormCalm.calm(id, deed)
	elif storm_shown < 1.0:
		# Away from the panel the wait is not counted: the storm is full.
		target = 0.0
	storm_shown = StormCalm.follow(maxf(storm_shown, 0.0), target, dt)
	sound.craft_db = StormCalm.surf_db(storm_shown)


func _leave() -> void:
	get_tree().change_scene_to_file(HUB)


func _say(text: String) -> void:
	message = text
	message_left = 5.0


func _refresh() -> void:
	var open := not heart_panel.is_empty()
	panel.visible = open
	panel_bg.visible = open
	# While a thought is met the words sit lower, so the figure and the
	# words are seen together (as on the hub's road).
	var low := -0.3 if open and heart_panel.kind == "passion" else 0.0
	panel.position.y = -0.05 + low
	panel_bg.position.y = -0.05 + low
	if open:
		panel.text = LocationHeart.text(heart_panel, loc, st, ctx)
	# The thought's figure stands at the heart while it is met, and goes
	# when it has passed.
	var met: bool = open and heart_panel.kind == "passion" \
		and heart_panel.enc.stage != "virtue"
	if met and figure.texture == null:
		var art := LocationHeart.passion_art(loc, st, ctx)
		if art != "" and ResourceLoader.exists(art):
			figure.texture = load(art) as Texture2D
	figure.visible = met and figure.texture != null
	var text := message if message_left > 0.0 else ""
	if text == "" and not open:
		var th := _nearest()
		if not th.is_empty():
			text = th.ru
	prompt3d.text = text
	hud.text = text
	prompt3d.modulate.a = ui_alpha
	hud.modulate.a = ui_alpha
	panel.modulate.a = ui_alpha
	panel_bg.transparency = 1.0 - ui_alpha
	panel.visible = open and ui_alpha > 0.0
	panel_bg.visible = panel.visible


# --- XR (as in the hub) -------------------------------------------------------

func _start_xr() -> void:
	var openxr := XRServer.find_interface("OpenXR")
	if openxr and openxr.is_initialized():
		get_viewport().use_xr = true
		xr_active = true
		camera.position = Vector3.ZERO
		return
	webxr = XRServer.find_interface("WebXR")
	if webxr:
		if webxr.is_initialized():
			get_viewport().use_xr = true
			xr_active = true
			camera.position = Vector3.ZERO
			return
		webxr.session_supported.connect(_on_webxr_supported)
		webxr.session_started.connect(_on_webxr_started)
		webxr.is_session_supported("immersive-vr")


func _on_webxr_supported(mode: String, supported: bool) -> void:
	if mode != "immersive-vr" or not supported:
		return
	vr_button = Button.new()
	vr_button.text = "Войти в шлем"
	vr_button.position = Vector2(24, 60)
	vr_button.add_theme_font_size_override("font_size", 28)
	vr_button.pressed.connect(_enter_webxr)
	hud.get_parent().add_child(vr_button)


func _enter_webxr() -> void:
	webxr.session_mode = "immersive-vr"
	webxr.requested_reference_space_types = "local-floor, local"
	webxr.required_features = "local"
	webxr.optional_features = "local-floor"
	webxr.initialize()


func _on_webxr_started() -> void:
	get_viewport().use_xr = true
	xr_active = true
	camera.position = Vector3.ZERO
	if vr_button:
		vr_button.visible = false


# --- Proof frames ---------------------------------------------------------------

## Three frames a place: as it is entered (from the door, facing the
## heart: "heart"), standing at the heart with its prompt read and the
## panel closed ("near", TABOO 0.013 item 7: the prompt at the heart
## reads right), and with the heart's panel open ("panel").  The panel
## is opened on the saved state and nothing is written.
const SHOT_VIEWS := ["heart", "near", "panel"]


func _shots() -> void:
	var views := SHOT_VIEWS.size()
	var n := shot_frame / (views * SHOT_FRAMES)
	if n >= shot_list.size():
		get_tree().quit()
		return
	if p.id != shot_list[n]:
		open_place(shot_list[n])
	var view: String = SHOT_VIEWS[(shot_frame / SHOT_FRAMES) % views]
	camera.rotation.x = -0.12
	yaw = 0.0
	match view:
		"heart":
			pos = p.start
			heart_panel = {}
			message_left = 0.0
		"near":
			pos = p.heart + Vector3(0, 0, SHOT_NEAR_M)
			heart_panel = {}
			message_left = 0.0
		"panel":
			pos = p.heart + Vector3(0, 0, SHOT_NEAR_M)
			if heart_panel.is_empty():
				message_left = 0.0
				_apply(LocationHeart.open(loc, st, ctx))
	ui_alpha = LocationCore.holy_fade_target(p, pos)
	rig.position = pos
	rig.rotation.y = yaw
	_refresh()
	if shot_frame % SHOT_FRAMES == SHOT_FRAMES - 1:
		get_viewport().get_texture().get_image().save_png(
			"%s/godot-loc-%s-%s.png" % [shots_dir, p.id, view])
	shot_frame += 1
