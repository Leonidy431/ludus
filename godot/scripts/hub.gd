## The monastery hub: the courtyard of the obitel on the Issyk-Kul shore.
##
## Three paths (docs/HLD_FOLLOWUPS_2026-09-30.md, D4):
##   scriptorium - the four mentors of the gates; talks are birch-bark
##                 boards in the world, from the same dialogue-trees.json
##                 as the web game (TABOO 0.39 point 6);
##   pier        - the ROV on its birch stand; it leads into the dive;
##   gate ladder - six steps whose lanterns burn when a gate is open.
## Beside them: the prayer rope on the lectern (a knot is counted and
## shown, never scored, TABOO 0.35 rule 16) and the corner of stillness.
##
## Three classes of light (TABOO 0.38 point 1): the lampada at 1800 K,
## the hearth at about 2200 K, the instrument light of the pier at
## 6500 K.  No halo anywhere; holiness is light and quiet (TABOO 0.2).
## Rules live in HubCore (tested against the JS); this script draws and
## reads the controls.
extends Node3D

const SAVE_PATH := "user://hub.json"
const REACH_M := 2.2
const WALK_MPS := 1.4
const BOUNDS := Rect2(-7.0, -8.5, 16.0, 16.0)
const RU_ATTR := {"wisdom": "Мудрость", "faith": "Вера",
	"dexterity": "Ловкость", "constitution": "Стойкость",
	"charisma": "Обаяние", "cunning": "Хитрость", "erudition": "Книжность"}
const LAMPADA_K := Color(1.0, 0.52, 0.16)   # About 1800 K.
const HEARTH_K := Color(1.0, 0.62, 0.3)     # About 2200 K.
const INSTRUMENT_K := Color(0.95, 0.97, 1.0)  # About 6500 K.

var trees: Dictionary = {}
var form := HubCore.new_form()
var actions := HubCore.new_actions()
var things: Array = []  # {id, kind, pos, ru}
var yaw := 0.0
var pos := Vector3(0, 0, 3)
var t := 0.0
var xr_active := false
var snap_ready := true
var talk := {}  # {npc, node, choice} while a talk is open.
var select_was := false
var interact_was := false
var stick_was := 0.0
var still_for := 0.0
var message := ""
var message_left := 0.0

var rig: XROrigin3D
var camera: XRCamera3D
var left_hand: XRController3D
var right_hand: XRController3D
var panel: Label3D
var panel_bg: MeshInstance3D
var prompt3d: Label3D
var hud: Label
var form_board: Label3D
var ladder_board: Label3D
var lanterns: Array = []
var hearth: OmniLight3D
var webxr: XRInterface
var vr_button: Button

var shots_dir := ""
var shot_frame := 0


func _ready() -> void:
	trees = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/dialogue-trees.json")).trees
	_load()
	_build_world()
	_build_rig()
	_build_ui()
	_start_xr()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(shots_dir)


# --- World --------------------------------------------------------------------

func _mat(colour: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	return m


func _box(size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(colour)
	mi.position = at
	add_child(mi)
	return mi


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# Evening over the lake: the hour of vespers, when the day of the
	# typikon begins.
	sm.sky_top_color = Color(0.2, 0.3, 0.5)
	sm.sky_horizon_color = Color(0.85, 0.62, 0.45)
	sm.ground_horizon_color = Color(0.5, 0.45, 0.4)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.004
	env.fog_light_color = Color(0.8, 0.65, 0.55)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-18, -60, 0)
	sun.light_color = Color(1.0, 0.8, 0.6)
	sun.light_energy = 0.7
	add_child(sun)
	# Flagstones of the courtyard, the lake to the east.
	_box(Vector3(16, 0.2, 16), Vector3(1, -0.1, -0.5), Color(0.55, 0.52, 0.47))
	var lake := _box(Vector3(400, 0.05, 400), Vector3(209, -0.35, 0),
		Color(0.16, 0.36, 0.52))
	lake.material_override.roughness = 0.2
	# Whitewashed walls with oak eaves: one material logic (TABOO 0.38).
	var white := Color(0.9, 0.87, 0.8)
	var oak := Color(0.42, 0.29, 0.17)
	_box(Vector3(0.4, 3.2, 16), Vector3(-7.2, 1.6, -0.5), white)
	_box(Vector3(16, 3.2, 0.4), Vector3(1, 1.6, -8.7), white)
	_box(Vector3(0.6, 0.25, 16.4), Vector3(-7.1, 3.3, -0.5), oak)
	_box(Vector3(16.4, 0.25, 0.6), Vector3(1, 3.3, -8.6), oak)
	# Mountains of the Terskey range beyond the lake, far and simple.
	for i in 14:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 60.0 + (i * 37) % 40
		cm.height = 70.0 + (i * 53) % 50
		cm.radial_segments = 6
		cone.mesh = cm
		cone.material_override = _mat(Color(0.42, 0.44, 0.5))
		var a := -1.2 + i * 0.18
		cone.position = Vector3(cos(a) * 330.0, cm.height / 2.0 - 10.0,
			sin(a) * 330.0)
		add_child(cone)
	_build_scriptorium(oak)
	_build_pier(oak)
	_build_ladder()
	_build_practice(oak)


func _build_scriptorium(oak: Color) -> void:
	# An open workshop of the word: a long oak table, shelves, the lamp.
	_box(Vector3(1.0, 0.8, 5.6), Vector3(-5.6, 0.4, 0), oak)
	_box(Vector3(0.3, 2.4, 5.0), Vector3(-6.8, 1.2, 0), oak.darkened(0.2))
	# The lampada: a small red glass on the wall, 1800 K, not amplified
	# and not compared with anything (TABOO 0.38 point 1).
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.035
	cm.height = 0.1
	cup.mesh = cm
	var glass := _mat(Color(0.7, 0.1, 0.08), 0.2)
	glass.emission_enabled = true
	glass.emission = LAMPADA_K
	glass.emission_energy_multiplier = 0.8
	cup.material_override = glass
	cup.position = Vector3(-6.6, 1.9, 0)
	add_child(cup)
	var lamp := OmniLight3D.new()
	lamp.light_color = LAMPADA_K
	lamp.light_energy = 0.6
	lamp.omni_range = 3.0
	lamp.position = Vector3(-6.4, 1.95, 0)
	add_child(lamp)
	# The four mentors: people, not statues, without halos (TABOO 0.2).
	var cloth := {"elder_sergius": Color(0.1, 0.1, 0.11),
		"theodora": Color(0.2, 0.17, 0.22),
		"abba_john": Color(0.25, 0.2, 0.15),
		"sister_catherine": Color(0.12, 0.12, 0.16)}
	var i := 0
	for m in HubCore.MENTORS:
		var p := Vector3(-4.6, 0, -2.4 + i * 1.6)
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.24
		cap.height = 1.5
		body.mesh = cap
		body.material_override = _mat(cloth[m])
		body.position = p + Vector3(0, 0.75, 0)
		add_child(body)
		var head := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.12
		sp.height = 0.26
		head.mesh = sp
		head.material_override = _mat(Color(0.78, 0.62, 0.5))
		head.position = p + Vector3(0, 1.62, 0)
		add_child(head)
		var name_label := Label3D.new()
		name_label.text = trees[m].get("npcName_ru", m)
		name_label.font_size = 30
		name_label.pixel_size = 0.004
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.position = p + Vector3(0, 2.0, 0)
		name_label.modulate = Color(0.95, 0.9, 0.8)
		add_child(name_label)
		things.append({"id": m, "kind": "mentor", "pos": p,
			"ru": "Поговорить: " + trees[m].get("npcName_ru", m)})
		i += 1


func _build_pier(oak: Color) -> void:
	# The pier with the ROV on its birch stand: the instrument world.
	_box(Vector3(6, 0.15, 1.6), Vector3(10, -0.1, 0), oak.lightened(0.1))
	var birch := Color(0.88, 0.86, 0.8)
	_box(Vector3(0.1, 0.7, 0.1), Vector3(8.4, 0.3, -0.4), birch)
	_box(Vector3(0.1, 0.7, 0.1), Vector3(8.4, 0.3, 0.4), birch)
	# The vehicle is the operator's own Mangustik, built from his
	# OpenSCAD drawings (scripts/meta3d/mangustik_rov.py), bow to the
	# lake.  Its lowest point (the ballast tubes) is 0.34 m under its
	# origin, so it rests on the 0.65 m stand.
	var scene := load("res://models/rov/mangustik.glb") as PackedScene
	if scene:
		var rov := scene.instantiate() as Node3D
		rov.position = Vector3(8.4, 1.0, 0)
		rov.rotation_degrees = Vector3(0, -90, 0)
		add_child(rov)
	else:
		_box(Vector3(0.9, 0.45, 0.6), Vector3(8.4, 0.85, 0),
			Color(0.88, 0.63, 0.25))
	var light := SpotLight3D.new()
	light.light_color = INSTRUMENT_K
	light.light_energy = 2.0
	light.spot_range = 8.0
	light.position = Vector3(8.9, 0.9, 0)
	light.rotation_degrees = Vector3(-20, -90, 0)
	add_child(light)
	things.append({"id": "rov", "kind": "pier",
		"pos": Vector3(8.4, 0, 0), "ru": "Спустить ROV в озеро"})


func _build_ladder() -> void:
	# Six low steps north of the courtyard, each with its lantern.
	for i in 6:
		var step := _box(Vector3(2.4, 0.18 * (i + 1), 0.8),
			Vector3(1.0, 0.09 * (i + 1), -4.2 - i * 0.8),
			Color(0.62, 0.58, 0.52))
		step.name = "Step%d" % i
		var l := OmniLight3D.new()
		l.light_color = HEARTH_K
		l.omni_range = 2.0
		l.position = Vector3(2.4, 0.4 + 0.18 * (i + 1), -4.2 - i * 0.8)
		add_child(l)
		lanterns.append(l)
	things.append({"id": "ladder", "kind": "ladder",
		"pos": Vector3(1.0, 0, -4.0), "ru": "Лестница врат"})
	ladder_board = Label3D.new()
	ladder_board.font_size = 30
	ladder_board.pixel_size = 0.004
	ladder_board.width = 700
	ladder_board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ladder_board.position = Vector3(-1.6, 1.8, -4.4)
	ladder_board.rotation_degrees = Vector3(0, 20, 0)
	ladder_board.modulate = Color(0.2, 0.15, 0.1)
	ladder_board.outline_size = 0
	add_child(ladder_board)
	_board_back(ladder_board.position + Vector3(0, -0.25, -0.02),
		Vector2(2.9, 1.9), ladder_board.rotation_degrees)


func _build_practice(oak: Color) -> void:
	# The lectern with the prayer rope, and the corner of stillness.
	_box(Vector3(0.5, 1.1, 0.4), Vector3(-3.0, 0.55, 3.2), oak)
	things.append({"id": "rope", "kind": "rope",
		"pos": Vector3(-3.0, 0, 3.2), "ru": "Вервица: завязать узел"})
	_box(Vector3(1.6, 0.45, 0.4), Vector3(4.0, 0.22, 4.4), oak)
	hearth = OmniLight3D.new()
	hearth.light_color = HEARTH_K
	hearth.light_energy = 1.4
	hearth.omni_range = 6.0
	hearth.position = Vector3(2.2, 0.6, -2.4)
	add_child(hearth)
	_box(Vector3(0.8, 0.3, 0.8), Vector3(2.2, 0.15, -2.4),
		Color(0.3, 0.26, 0.22))
	things.append({"id": "stillness", "kind": "stillness",
		"pos": Vector3(4.0, 0, 3.8), "ru": "Угол безмолвия: постой здесь"})


func _board_back(at: Vector3, size: Vector2, rot: Vector3) -> void:
	# Birch bark behind a board: the interface is a charter (TABOO 0.38).
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	q.mesh = qm
	q.material_override = _mat(Color(0.93, 0.88, 0.76))
	q.position = at
	q.rotation_degrees = rot
	add_child(q)


# --- Rig and interface --------------------------------------------------------

func _build_rig() -> void:
	rig = XROrigin3D.new()
	add_child(rig)
	camera = XRCamera3D.new()
	camera.current = true
	camera.position = Vector3(0, 1.6, 0)
	camera.near = 0.05
	camera.far = 900.0
	rig.add_child(camera)
	left_hand = XRController3D.new()
	left_hand.tracker = &"left_hand"
	rig.add_child(left_hand)
	right_hand = XRController3D.new()
	right_hand.tracker = &"right_hand"
	rig.add_child(right_hand)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 20)
	layer.add_child(hud)
	# The talk is a board of birch bark in front of the eyes.
	panel_bg = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 0.7)
	panel_bg.mesh = qm
	var bark := _mat(Color(0.93, 0.88, 0.76))
	bark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# The charter is read in front of the eyes, never hidden behind a
	# mentor's shoulder (first eye check of the hub).
	bark.no_depth_test = true
	bark.render_priority = 1
	panel_bg.material_override = bark
	panel_bg.position = Vector3(0, -0.05, -0.92)
	panel_bg.visible = false
	camera.add_child(panel_bg)
	panel = Label3D.new()
	panel.font_size = 40
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
	form_board = Label3D.new()
	form_board.font_size = 30
	form_board.pixel_size = 0.004
	form_board.position = Vector3(-2.2, 1.7, 6.9)
	form_board.rotation_degrees = Vector3(0, 180, 0)
	form_board.modulate = Color(0.2, 0.15, 0.1)
	form_board.outline_size = 0
	add_child(form_board)
	_board_back(form_board.position + Vector3(0, -0.15, 0.02),
		Vector2(2.0, 1.8), form_board.rotation_degrees)


func _refresh_boards() -> void:
	var lines := ["ФОРМА"]
	for a in HubCore.ATTRIBUTES:
		lines.append("%s — %d" % [RU_ATTR[a], int(form[a])])
	form_board.text = "\n".join(lines)
	var ladder := HubCore.evaluate_ladder(form, actions)
	var out := ["ЛЕСТНИЦА ВРАТ"]
	for i in ladder.size():
		var c: Dictionary = ladder[i]
		var gate: Dictionary = HubCore.GATES[i]
		lanterns[i].light_energy = 1.2 if c.open else 0.0
		var need := []
		for m in c.missing:
			match m:
				"form":
					need.append("мудрость %d" % gate.wisdom)
				"dialogue":
					need.append("беседа")
				"rite":
					need.append("%d/%d %s" % [c.rite.have, c.rite.need,
						c.rite.ru])
				"gift":
					need.append("поклон «не мне»")
				"ladder":
					need.append("сперва нижняя ступень")
		out.append("%d. %s — %s" % [i + 1, gate.ru,
			"открыты" if c.open else ", ".join(need)])
	ladder_board.text = "\n".join(out)


# --- Save ---------------------------------------------------------------------

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"form": form, "actions": actions}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		for a in HubCore.ATTRIBUTES:
			form[a] = int(data.get("form", {}).get(a, form[a]))
		var act: Dictionary = data.get("actions", {})
		for k in ["prayerCount", "fastDays", "meditationHours"]:
			actions[k] = float(act.get(k, 0.0))
		actions.met = act.get("met", {})
		actions.gifts = act.get("gifts", {})


# --- Controls -----------------------------------------------------------------

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
	if event is InputEventKey and event.pressed and not talk.is_empty():
		var n: int = event.keycode - KEY_1
		if n >= 0 and n < 4:
			_select(n)


func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	t += dt
	var move := Vector2(_key(KEY_D, KEY_A), _key(KEY_S, KEY_W))
	var turn := _key(KEY_Q, KEY_E)
	var interact := Input.is_key_pressed(KEY_E) and talk.is_empty() \
		or Input.is_key_pressed(KEY_SPACE)
	var nav := 0.0
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
	else:
		yaw += turn * 1.5 * dt
		nav = _key(KEY_UP, KEY_DOWN)
	# While a talk is open the stick chooses the line and the body stays.
	if talk.is_empty():
		var heading := yaw
		if xr_active:
			var z := camera.transform.basis.z
			heading = yaw + atan2(z.x, z.z)
		var dir := Vector3(move.x, 0, move.y).rotated(Vector3.UP, heading)
		pos += dir * WALK_MPS * dt
		pos.x = clampf(pos.x, BOUNDS.position.x, BOUNDS.end.x)
		pos.z = clampf(pos.z, BOUNDS.position.y, BOUNDS.end.y)
	else:
		if absf(nav) > 0.6 and absf(stick_was) <= 0.6:
			var n := HubCore.open_branches(talk.node, form).size()
			talk.choice = posmod(talk.choice - int(signf(nav)), maxi(1, n))
		stick_was = nav
	rig.position = pos
	rig.rotation.y = yaw
	if interact and not interact_was:
		if talk.is_empty():
			_interact()
		else:
			_select(talk.choice)
	interact_was = interact
	_stillness(dt, move)
	hearth.light_energy = 1.3 + 0.15 * sin(t * 7.0) * sin(t * 2.3)
	message_left = maxf(0.0, message_left - dt)
	_refresh_boards()
	_refresh_prompt()
	if shots_dir != "":
		_shots()


func _nearest() -> Dictionary:
	var best := {}
	var best_d := REACH_M
	for th in things:
		var d := Vector2(th.pos.x - pos.x, th.pos.z - pos.z).length()
		if d < best_d:
			best = th
			best_d = d
	return best


func _interact() -> void:
	var th := _nearest()
	if th.is_empty():
		return
	match th.kind:
		"mentor":
			var tree: Dictionary = trees[th.id]
			actions = HubCore.record_meeting(actions, th.id)
			talk = {"npc": th.id, "node": HubCore.node_of(tree,
				tree.startNode), "choice": 0}
			_save()
		"rope":
			actions = HubCore.pray_knot(actions)
			_say("Узел завязан. Узлов: %d." % int(actions.prayerCount))
			_save()
		"pier":
			_save()
			get_tree().change_scene_to_file("res://scenes/dive.tscn")
		"ladder":
			_bow()
		"stillness":
			_say("Постой здесь, не двигаясь. Время идёт само.")


## The bow for gates 4-6: "not to me".  It is accepted only when all
## else holds, so it cannot skip a step (ludus-actions.js acceptGift).
func _bow() -> void:
	for c in HubCore.evaluate_ladder(form, actions):
		if c.ready_for_gift:
			actions = HubCore.accept_gift(actions, form, c.id)
			_say("Поклон: «не мне». Свет пришёл сам.")
			_save()
			return
	_say("Лестница: смотри, чего ещё не хватает, на доске слева.")


func _select(i: int) -> void:
	var open := HubCore.open_branches(talk.node, form)
	if i >= open.size():
		return
	var res := HubCore.choose(form, open[i])
	form = res.form
	var tree: Dictionary = trees[talk.npc]
	if res.next == null:
		talk = {}
		_say("Беседа окончена.")
	else:
		talk.node = HubCore.node_of(tree, res.next)
		talk.choice = 0
	_save()


## Stillness counts only while the body is truly still in the corner.
func _stillness(dt: float, move: Vector2) -> void:
	var corner := Vector3(4.0, 0, 3.8)  # The bench of stillness.
	var inside := Vector2(pos.x - corner.x, pos.z - corner.z).length() < 1.5
	if inside and move.length() < 0.1 and talk.is_empty():
		still_for += dt
		if still_for >= 60.0:
			still_for = 0.0
			actions = HubCore.add_stillness(actions, 1.0)
			_say("Минута безмолвия.")
			_save()
	else:
		still_for = 0.0


func _say(text: String) -> void:
	message = text
	message_left = 5.0


func _refresh_prompt() -> void:
	panel.visible = not talk.is_empty()
	panel_bg.visible = panel.visible
	if not talk.is_empty():
		var tree: Dictionary = trees[talk.npc]
		var lines := [tree.get("npcName_ru", talk.npc) + ":",
			str(talk.node.get("text_ru", talk.node.text)), ""]
		var open := HubCore.open_branches(talk.node, form)
		for i in open.size():
			var mark := "▸ " if i == talk.choice else "  "
			lines.append("%s%d. %s" % [mark, i + 1, open[i].get("text_ru",
				open[i].text)])
		panel.text = "\n".join(lines)
	var text := message if message_left > 0.0 else ""
	if text == "" and talk.is_empty():
		var th := _nearest()
		if not th.is_empty():
			text = th.ru
	prompt3d.text = text
	hud.text = text


# --- XR -----------------------------------------------------------------------

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
			# Coming back from the dive: the session is already open.
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


# --- Proof frames -------------------------------------------------------------

## --shots=<dir>: the courtyard, the mentors, a talk, the pier, the ladder.
func _shots() -> void:
	var plan := [
		{"name": "courtyard", "pos": Vector3(0, 0, 5.5), "yaw": 0.0},
		{"name": "mentors", "pos": Vector3(-2.2, 0, 0), "yaw": PI / 2.0},
		{"name": "talk", "pos": Vector3(-3.4, 0, -1.8), "yaw": PI / 2.0,
			"talk": "elder_sergius"},
		{"name": "pier", "pos": Vector3(5.5, 0, 0.6), "yaw": -PI / 2.0},
		{"name": "ladder", "pos": Vector3(1.0, 0, -1.0), "yaw": 0.0},
	]
	var n := shot_frame / 20
	if n >= plan.size():
		get_tree().quit()
		return
	var s: Dictionary = plan[n]
	pos = s.pos
	yaw = s.yaw
	camera.rotation.x = -0.12
	if s.has("talk") and talk.is_empty():
		var tree: Dictionary = trees[s.talk]
		talk = {"npc": s.talk, "node": HubCore.node_of(tree,
			tree.startNode), "choice": 0}
	elif not s.has("talk"):
		talk = {}
	if shot_frame % 20 == 19:
		get_viewport().get_texture().get_image().save_png(
			"%s/hub-%s.png" % [shots_dir, s.name])
	shot_frame += 1
