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
# The threshold of a gate (TrialCore): {gate, choice, reply} while open.
var trial := {}
var trial_data := TrialCore.load_data()
var trial_state := TrialCore.empty_state()
var sun: DirectionalLight3D
# The road beyond the wicket: a passion met as a thought (PassionCore,
# ludus-passion.js).  record is the player's history with each passion;
# encounter is the meeting in progress.
const STILL_BREATH_SECONDS := 5.0  # As in ludus-game.js.
const ROAD_AT := Vector3(-5.6, 0, 7.0)
var passion_data: Dictionary = JSON.parse_string(
	FileAccess.get_file_as_string("res://data/passions.json"))
var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(
	"res://data/antagonist-manifest.json")).manifest
var passion_record := {}
var encounter := {}
var encounter_still := -1.0  # Seconds left of the three breaths.
var road_sprite: Sprite3D
# The Water Atlas on the lectern of the scriptorium (AtlasCore).
var atlas: Dictionary = AtlasCore.load_data()
var atlas_page := 0
var atlas_board: Label3D
# The chronicle of the knight (AtlasTraces): written once at the
# scriptorium table; chron is {choice, reply} while its page is open.
const DIVE_SAVE := "user://dive.json"
var chronicle := ""
var chron := {}
# The road of the obitel: the campaign of missions (MissionCore,
# ludus-missions.js) on a birch-bark board in the courtyard.  The fall
# and the crossed thresholds stay in trial_state (one state in the web);
# mission_state keeps the rest.  mission is the open panel: {choice,
# start}, where start is the mission offered at the board (-1 once one
# is under way).
const MISSION_BOARD_AT := Vector3(3.6, 0, 1.2)
var mission_data: Dictionary = MissionCore.load_data()
var mission_state := {"done": {}, "current": null, "flags": {},
	"lines": {}}
var mission := {}
var mission_board: Label3D
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
	sun = DirectionalLight3D.new()
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
	_build_witness_gate(oak)
	_build_road(oak)
	_build_refectory(oak)
	_build_atlas(oak)
	_build_chronicle(oak)
	_build_mission_board(oak)
	# B2 hook: the journal of the way on its lectern (JournalBook).
	things.append(JournalBook.place(self))


## The way out to the path of the witness: a plain oak arch on the south
## side of the courtyard, lit by nothing but the evening.
func _build_witness_gate(oak: Color) -> void:
	var at := Vector3(1.2, 0, 7.2)
	_box(Vector3(0.25, 2.6, 0.25), at + Vector3(-0.9, 1.3, 0), oak)
	_box(Vector3(0.25, 2.6, 0.25), at + Vector3(0.9, 1.3, 0), oak)
	_box(Vector3(2.3, 0.25, 0.35), at + Vector3(0, 2.7, 0), oak)
	things.append({"id": "witness", "kind": "witness", "pos": at,
		"ru": "Тропа свидетеля: постоять у черты"})


## A lectern at the end of the scriptorium with "The Water Atlas": one
## page at a time, the frame first (TABOO 0.03).  Birch-bark board,
## hearth light; reading counts nothing.
func _build_atlas(oak: Color) -> void:
	var at := Vector3(-4.4, 0, 3.6)
	_box(Vector3(0.12, 1.0, 0.12), at + Vector3(0, 0.5, 0), oak)
	_box(Vector3(0.7, 0.05, 0.5), at + Vector3(0, 1.05, 0), oak)
	atlas_board = Label3D.new()
	atlas_board.font_size = 26
	atlas_board.pixel_size = 0.0022
	atlas_board.width = 900
	atlas_board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	atlas_board.modulate = Color(0.2, 0.15, 0.1)
	atlas_board.outline_size = 0
	# Read from the front only: from the scriptorium table behind it the
	# page showed through mirrored.
	atlas_board.double_sided = false
	atlas_board.position = at + Vector3(0, 2.0, -0.35)
	add_child(atlas_board)
	_board_back(atlas_board.position + Vector3(0, 0, -0.02),
		Vector2(2.2, 1.9), Vector3.ZERO)
	atlas_board.text = AtlasCore.page_text(atlas, atlas_page)
	things.append({"id": "atlas", "kind": "atlas", "pos": at,
		"ru": "Аналой: «Атлас воды» — читать дальше"})


## The chronicle on the scriptorium table: an open codex.  What the
## knight did under the vault of Sis is written here once; the lake
## keeps the trace of it (TABOO 0.03 rule 3).
func _build_chronicle(oak: Color) -> void:
	_box(Vector3(0.42, 0.05, 0.3), Vector3(-5.5, 0.83, 2.2),
		Color(0.93, 0.88, 0.76))
	_box(Vector3(0.44, 0.03, 0.32), Vector3(-5.5, 0.81, 2.2), oak.darkened(0.3))
	things.append({"id": "chronicle", "kind": "chronicle",
		"pos": Vector3(-5.0, 0, 2.2), "ru": "Летопись обители: 1375 год"})


## What the scribe says of the knight's things handed over in the dive.
func _scribe_page() -> String:
	if not FileAccess.file_exists(DIVE_SAVE):
		return ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(DIVE_SAVE))
	if not data is Dictionary:
		return ""
	var given = data.get("bag", {}).get("atlas", [])
	return AtlasTraces.scribe_page(atlas, given if given is Array else [])


## The board of the road: birch bark on two oak posts with a lantern of
## the hearth (about 2200 K), the same material logic as the other
## boards (TABOO 0.38).  It lists the acts, their locks and the open
## missions of the act under way; at the board the player sets out.
func _build_mission_board(oak: Color) -> void:
	var at := MISSION_BOARD_AT
	_box(Vector3(0.14, 2.4, 0.14), at + Vector3(0.1, 1.2, -1.05), oak)
	_box(Vector3(0.14, 2.4, 0.14), at + Vector3(0.1, 1.2, 1.05), oak)
	_box(Vector3(0.14, 0.12, 2.3), at + Vector3(0.1, 2.42, 0), oak)
	mission_board = Label3D.new()
	mission_board.font_size = 26
	mission_board.pixel_size = 0.0021
	mission_board.width = 900
	mission_board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_board.modulate = Color(0.2, 0.15, 0.1)
	mission_board.outline_size = 0
	mission_board.position = at + Vector3(0, 1.45, 0)
	mission_board.rotation_degrees = Vector3(0, -90, 0)
	add_child(mission_board)
	_board_back(at + Vector3(0.03, 1.45, 0), Vector2(2.0, 1.8),
		mission_board.rotation_degrees)
	var lantern := OmniLight3D.new()
	lantern.light_color = HEARTH_K
	lantern.light_energy = 0.5
	lantern.omni_range = 3.2
	lantern.position = at + Vector3(-0.5, 2.3, 1.05)
	add_child(lantern)
	things.append({"id": "missions", "kind": "missions",
		"pos": at + Vector3(-0.6, 0, 0),
		"ru": "Доска дороги: миссии обители"})
	_refresh_mission_board()


## The refectory table, bare: today's fast is kept here once a day,
## by the player's own calendar date (the rite of the third gate).
func _build_refectory(oak: Color) -> void:
	_box(Vector3(2.0, 0.08, 0.8), Vector3(5.0, 0.75, -3.4), oak)
	for dx in [-0.9, 0.9]:
		_box(Vector3(0.08, 0.75, 0.7), Vector3(5.0 + dx, 0.37, -3.4), oak)
	_box(Vector3(2.0, 0.4, 0.3), Vector3(5.0, 0.2, -2.7), oak)
	things.append({"id": "fast", "kind": "fast",
		"pos": Vector3(5.0, 0, -2.6),
		"ru": "Трапезная: держать сегодняшний пост"})


## The wicket to the road, in the south-west corner.  Beyond it the
## passion shows itself as its figure from the antagonist factory, in
## the cold palette of the passions, never as a monster to fight.
func _build_road(oak: Color) -> void:
	_box(Vector3(0.18, 1.6, 0.18), ROAD_AT + Vector3(-0.6, 0.8, 0), oak)
	_box(Vector3(0.18, 1.6, 0.18), ROAD_AT + Vector3(0.6, 0.8, 0), oak)
	_box(Vector3(1.4, 0.12, 0.2), ROAD_AT + Vector3(0, 1.62, 0), oak)
	road_sprite = Sprite3D.new()
	road_sprite.pixel_size = 0.008
	road_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# At eye height on the road; the words sit lower while it is met, so
	# the figure and the words are seen together.  Unshaded, so the
	# evening sun behind it does not turn it into a black cut-out.
	road_sprite.position = ROAD_AT + Vector3(0, 1.75, 3.4)
	road_sprite.shaded = false
	road_sprite.visible = false
	add_child(road_sprite)
	things.append({"id": "road", "kind": "road", "pos": ROAD_AT,
		"ru": "Калитка на дорогу"})


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
		f.store_string(JSON.stringify({"form": form, "actions": actions,
			"trials": trial_state, "passions": passion_record,
			"chronicle": chronicle, "missions": mission_state}))


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
		var lfd = act.get("lastFastDay")
		actions.lastFastDay = lfd if typeof(lfd) == TYPE_STRING else null
		actions.met = act.get("met", {})
		actions.gifts = act.get("gifts", {})
		# The deeds of the rule that missions ask (MissionCore.do_practice).
		var pr = act.get("practices", {})
		actions.practices = pr if pr is Dictionary else {}
		# Only known shapes come back, as normalizeState does in JS.
		var ts: Dictionary = data.get("trials", {})
		for g in TrialCore.GATE_IDS:
			if ts.get("trials", {}).get(g, false) == true:
				trial_state.trials[g] = true
			var w = ts.get("trial_wait", {}).get(g)
			if typeof(w) in [TYPE_INT, TYPE_FLOAT]:
				trial_state.trial_wait[g] = int(w)
		passion_record = PassionCore.normalize_record(data.get("passions",
			{}))
		chronicle = AtlasTraces.write_chronicle(atlas,
			data.get("chronicle"), "")
		var f = ts.get("fall")
		if f is Dictionary and not TrialCore.passion_of(trial_data,
				f.get("passion")).is_empty():
			trial_state.fall = f
		# The road of missions: only known shapes come back.
		var ms := MissionCore.normalize_state(data.get("missions", {}))
		mission_state = {"done": ms.done, "current": ms.current,
			"flags": ms.flags, "lines": ms.lines}


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
	if event is InputEventKey and event.pressed and _panel_open():
		var n: int = event.keycode - KEY_1
		if n >= 0 and n < 4:
			_select(n)


func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	t += dt
	var move := Vector2(_key(KEY_D, KEY_A), _key(KEY_S, KEY_W))
	var turn := _key(KEY_Q, KEY_E)
	var interact := Input.is_key_pressed(KEY_E) and not _panel_open() \
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
	# While a talk or a threshold is open the stick chooses the line and
	# the body stays.
	if not _panel_open():
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
			if not encounter.is_empty():
				encounter.choice = posmod(encounter.choice - int(signf(nav)),
					maxi(1, _encounter_options().size()))
			elif not chron.is_empty():
				chron.choice = posmod(chron.choice - int(signf(nav)), 2)
			elif not trial.is_empty():
				trial.choice = posmod(trial.choice - int(signf(nav)), 3)
			elif not mission.is_empty():
				mission.choice = posmod(mission.choice - int(signf(nav)),
					maxi(1, _mission_choices().size()))
			else:
				var n := HubCore.open_branches(talk.node, form).size()
				talk.choice = posmod(talk.choice - int(signf(nav)),
					maxi(1, n))
		stick_was = nav
	rig.position = pos
	rig.rotation.y = yaw
	if interact and not interact_was:
		if not encounter.is_empty():
			_select(encounter.choice)
		elif not chron.is_empty():
			_select(chron.choice)
		elif not trial.is_empty():
			_select(trial.choice)
		elif not mission.is_empty():
			_select(mission.choice)
		elif talk.is_empty():
			_interact()
		else:
			_select(talk.choice)
	interact_was = interact
	_stillness(dt, move)
	_check_fall()
	_road_tick(dt)
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
			# A fall closes the road to the deep until it is lifted.
			var fs := TrialCore.fall_status(trial_data, trial_state, actions)
			if fs.fallen:
				_say("Путь в глубину закрыт: %s. Признак: %s Открывают трезвение (угол безмолвия) и беседа с наставником." % [fs.passion_ru, fs.cue])
				return
			_save()
			get_tree().change_scene_to_file("res://scenes/dive.tscn")
		"road":
			_road()
		"atlas":
			var scribe := _scribe_page()
			atlas_page = AtlasCore.next_page(atlas, atlas_page, scribe)
			atlas_board.text = AtlasCore.page_text(atlas, atlas_page, scribe)
		"chronicle":
			if chronicle != "":
				_say(AtlasTraces.option(atlas, chronicle).written_ru)
			else:
				chron = {"choice": 0, "reply": ""}
		"fast":
			var before := float(actions.fastDays)
			actions = HubCore.keep_fast(actions,
				Time.get_date_string_from_system())
			if float(actions.fastDays) > before:
				_say("Пост на сегодня: стол пуст до вечера. Воздержание против чревоугодия (Лествица, слово 14).")
			else:
				_say("Сегодняшний пост уже держишь.")
			_save()
		"witness":
			# Leaving for the path writes nothing about the visit.
			_save()
			get_tree().change_scene_to_file("res://scenes/witness.tscn")
		"ladder":
			_ladder()
		"missions":
			_open_missions()
		"stillness":
			_say("Постой здесь, не двигаясь. Время идёт само.")
		"node":  # B2 hook: a thing that answers for itself (JournalBook).
			th.node.use()


## At the ladder: the bow when a gift is ready, else the threshold of
## the first open gate not yet crossed, else what is still missing.
func _ladder() -> void:
	for c in HubCore.evaluate_ladder(form, actions):
		if c.ready_for_gift:
			_bow()
			return
	if TrialCore.fall_status(trial_data, trial_state, actions).fallen:
		_say("Сначала трезвение и беседа с наставником: свет потускнел.")
		return
	for gid in TrialCore.GATE_IDS:
		var tv := TrialCore.trial_view(trial_data, trial_state, gid, form,
			actions)
		if tv.is_empty() or not tv.open or tv.passed:
			continue
		if tv.waiting:
			_say("У порога «%s» ждут: сперва вернись к наставнику и поговори." % tv.trial.title_ru)
			return
		trial = {"gate": gid, "choice": 0, "reply": ""}
		return
	_bow()


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
	if not chron.is_empty():
		_write_chronicle(i)
		return
	if not encounter.is_empty():
		_choose_on_road(i)
		return
	if not trial.is_empty():
		_choose_threshold(i)
		return
	if not mission.is_empty():
		_choose_mission(i)
		return
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


## The chronicle is written once; the answer says where its trace is.
## Nothing is scored: mercy is not paid in points (Constitution).
func _write_chronicle(i: int) -> void:
	if chron.reply != "":
		chron = {}
		return
	var opts := AtlasTraces.options(atlas)
	if i >= opts.size():
		return
	chronicle = AtlasTraces.write_chronicle(atlas, chronicle, opts[i].id)
	chron.reply = AtlasTraces.option(atlas, chronicle).written_ru
	_save()


## A choice at the threshold.  After the answer the next press steps
## away; nothing is scored (Constitution: a choice by understanding).
func _choose_threshold(i: int) -> void:
	if trial.reply != "":
		trial = {}
		return
	var tv := TrialCore.trial_view(trial_data, trial_state, trial.gate,
		form, actions)
	var res := TrialCore.choose_trial(trial_data, trial_state, trial.gate,
		tv.options[i].id, form, actions)
	if res.outcome == null:
		trial = {}
		return
	trial_state = res.state
	trial.reply = res.reply
	_save()


## The fall is lifted by itself once sobriety and the mentor's talk are
## both newer than it; then the courtyard's light comes back.
func _check_fall() -> void:
	var fs := TrialCore.fall_status(trial_data, trial_state, actions)
	if fs.fallen and fs.can_lift:
		trial_state = TrialCore.lift_fall(trial_data, trial_state, actions)
		_say("Свет вернулся: %s." % fs.virtue_ru)
		_save()
	sun.light_energy = 0.25 if fs.fallen and not fs.can_lift else 0.7


func _panel_open() -> bool:
	return not talk.is_empty() or not trial.is_empty() \
		or not encounter.is_empty() or not chron.is_empty() or not mission.is_empty()


# --- The road of missions ---------------------------------------------------

## The campaign state as MissionCore reads it: the road's own keys with
## the thresholds and the fall of trial_state.
func _mstate() -> Dictionary:
	var st := mission_state.duplicate(true)
	st.trials = trial_state.trials.duplicate()
	st.trial_wait = trial_state.trial_wait.duplicate()
	st.fall = trial_state.fall
	return st


## Keep a new campaign state.  The fall is written back only when a
## choice has just produced it, so a fall from a threshold is never
## touched by the road.
func _mkeep(st: Dictionary, fell: bool) -> void:
	mission_state = {"done": st.done, "current": st.current,
		"flags": st.flags, "lines": st.lines}
	if fell:
		trial_state.fall = st.fall
	_refresh_mission_board()


## At the board: the mission under way, else the next one to set out on,
## else why the road waits (an act not yet crossed, or all walked).
func _open_missions() -> void:
	var st := _mstate()
	if st.current != null:
		mission = {"choice": 0, "start": -1}
		return
	var nxt := MissionCore.next_mission(mission_data, st)
	if nxt >= 0:
		mission = {"choice": 0, "start": nxt}
		return
	for act in MissionCore.catalog(mission_data, st):
		if act.lock != "" and not act.complete:
			_say("%s: %s." % [act.title, act.lock])
			return
	_say("Все миссии, что можно пройти, пройдены.")


## The lines of the open panel to choose from: {id, text, disabled,
## reason, cue}.  The last one always steps away from the board.
func _mission_choices() -> Array:
	var away := {"id": "away", "text": "Отойти: дорога подождёт.",
		"disabled": false, "reason": "", "cue": ""}
	if mission.is_empty():
		return []
	if mission.start >= 0:
		var can := MissionCore.can_start(mission_data, _mstate(),
			mission.start)
		return [{"id": "set_out", "text": "Выйти в путь",
			"disabled": not can.ok, "reason": can.reason, "cue": ""}, away]
	var v := MissionCore.view(mission_data, _mstate(), form, actions)
	if v.is_empty():
		return [away]
	if v.scene != null:
		return [{"id": "next", "text": "Завершить миссию" if v.last
			else "Дальше", "disabled": false, "reason": "", "cue": ""}]
	return v.step.choices + [away]


func _choose_mission(i: int) -> void:
	var choices := _mission_choices()
	if i >= choices.size():
		return
	var c: Dictionary = choices[i]
	if c.disabled:
		_say(c.reason)
		return
	match c.id:
		"away":
			mission = {}
		"set_out":
			_mkeep(MissionCore.start(mission_data, _mstate(), mission.start),
				false)
			mission = {"choice": 0, "start": -1}
			_save()
		"next":
			var res := MissionCore.advance(mission_data, _mstate())
			_mkeep(res.state, false)
			mission.choice = 0
			if res.completed != null:
				mission = {}
				_say("Миссия %d пройдена." % res.completed)
			_save()
		_:
			var res := MissionCore.choose(mission_data, _mstate(), c.id,
				form, actions)
			var ap := MissionCore.apply_effects(form, actions, res.effects,
				Time.get_date_string_from_system())
			form = ap.form
			actions = ap.actions
			_mkeep(res.state, res.effects.fall != null)
			mission.choice = 0
			_save()


func _refresh_mission_board() -> void:
	if mission_board == null:
		return
	var st := _mstate()
	var lines := ["ДОРОГА ОБИТЕЛИ"]
	if st.fall != null:
		lines.append("Свет приглушён: дорога ждёт трезвения и беседы.")
	for act in MissionCore.catalog(mission_data, st):
		var runnable := 0
		var walked := 0
		for m in act.missions:
			if m.status != "chorus":
				runnable += 1
			if m.status == "done":
				walked += 1
		if act.complete:
			lines.append("%s — пройден" % act.title)
		elif act.lock != "":
			lines.append("%s — %s" % [act.title, act.lock])
		else:
			lines.append("%s — %d из %d" % [act.title, walked, runnable])
			var shown := 0
			for m in act.missions:
				if m.status in ["done", "chorus"] or shown >= 5:
					continue
				var mark := "▸" if m.status in ["next", "current"] else "·"
				lines.append("   %s %d. %s" % [mark, m.id, m.title])
				shown += 1
	mission_board.text = "\n".join(lines)


func _passion(id) -> Dictionary:
	for p in passion_data.passions:
		if p.id == id:
			return p
	return {}


## Out through the wicket: the next passion of Evagrius' order that is
## not yet overcome comes to meet the player (its variant from the
## factory, the same as in the web game).
func _road() -> void:
	var next = PassionCore.next_passion(passion_data, passion_record,
		manifest)
	if next == null:
		_say("Дорога тиха.")
		return
	encounter = PassionCore.start(next)
	encounter["choice"] = 0
	var file := str(next.get("art", "")).get_file()
	var tex := load("res://art/derived/DEF-001/" + file) as Texture2D \
		if file != "" else null
	road_sprite.texture = tex
	road_sprite.visible = tex != null


func _encounter_options() -> Array:
	return PassionCore.options(encounter, _passion(encounter.passionId),
		form, actions)


## A choice on the road.  "Be still" takes three breaths before it
## counts; the end (virtue or captive) closes with one more press.
func _choose_on_road(i: int) -> void:
	var stage: String = encounter.stage
	if stage in ["virtue", "captive"]:
		var res := PassionCore.finish(passion_record, encounter)
		passion_record = res.record
		for a in res.attribute_bonuses:
			if a in HubCore.ATTRIBUTES:
				form[a] = int(form[a]) + int(res.attribute_bonuses[a])
		encounter = {}
		road_sprite.visible = false
		_save()
		return
	if encounter_still >= 0.0:
		return
	var opts := _encounter_options()
	if i >= opts.size():
		return
	if opts[i].get("breaths", 0) > 0:
		encounter_still = float(opts[i].breaths) * STILL_BREATH_SECONDS
		encounter["pending"] = opts[i].id
		return
	_take_on_road(opts[i].id)


func _take_on_road(option_id: String) -> void:
	var choice: int = encounter.get("choice", 0)
	encounter = PassionCore.choose(encounter, option_id,
		_passion(encounter.passionId), form, actions)
	encounter["choice"] = 0 if choice >= _encounter_options().size() \
		else choice
	if encounter.stage == "virtue":
		# The thought has passed: the figure is gone from the road.
		road_sprite.visible = false


func _road_tick(dt: float) -> void:
	if encounter_still < 0.0:
		return
	encounter_still -= dt
	if encounter_still <= 0.0:
		encounter_still = -1.0
		_take_on_road(encounter.get("pending", "still"))


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


## The panel of a mission, like the threshold's: the step, its source
## and the choices; a closed choice says why, a lure shows its sign once
## the player has learnt it.
func _mission_panel_text() -> String:
	var choices := _mission_choices()
	var lines := []
	if mission.start >= 0:
		var m := MissionCore.build_mission(mission_data, mission.start)
		lines += [m.actTitle, "%d. %s" % [m.id, m.title], "", m.intro,
			"Источник: " + m.source, ""]
	else:
		var v := MissionCore.view(mission_data, _mstate(), form, actions)
		if v.is_empty():
			return ""
		var s: Dictionary = v.step
		lines += ["%d. %s — шаг %d из %d: %s" % [v.mission.id,
			v.mission.title, v.index + 1, v.total, v.kind_ru], "",
			s.title, s.text]
		if s.source != "":
			lines.append("Источник: " + s.source)
		lines.append("")
		if v.scene != null:
			lines.append("— " + v.scene.choice)
			if v.scene.speaker != "":
				lines.append(v.scene.speaker + ":")
			lines.append(v.scene.text)
			if v.scene.source != "":
				lines.append("Источник: " + v.scene.source)
			lines.append("")
	for j in choices.size():
		var c: Dictionary = choices[j]
		var mark := "▸ " if j == mission.choice else "  "
		var line := "%s%d. %s" % [mark, j + 1, c.text]
		if c.disabled and c.reason != "":
			line += "  (%s)" % c.reason
		lines.append(line)
		if c.cue != "":
			lines.append("      " + c.cue)
	return "\n".join(lines)


func _refresh_prompt() -> void:
	panel.visible = _panel_open()
	# A mission step says more than a talk; its charter uses a smaller
	# hand so it stays inside the birch bark.
	panel.font_size = 36 if not mission.is_empty() else 40
	panel_bg.visible = panel.visible
	var low := -0.3 if not encounter.is_empty() else 0.0
	panel.position.y = -0.05 + low
	panel_bg.position.y = -0.05 + low
	if not encounter.is_empty():
		var p := _passion(encounter.passionId)
		var lines := ["На дороге: %s" % p.name_ru, "", p.lure_ru, ""]
		match encounter.stage:
			"virtue":
				lines += ["Помысел прошёл. %s — %s; %s." % [p.virtue_ru,
					p.source, p.ladder], "", "(нажми — идти дальше)"]
			"captive":
				lines += ["Он повёл тебя. Он вернётся; наставники научат его признаку.",
					"", "(нажми — идти дальше)"]
			_:
				if encounter_still >= 0.0:
					lines.append("Помолчи… %d с" % ceili(encounter_still))
				else:
					var opts := _encounter_options()
					for j in opts.size():
						var mark := "▸ " if j == encounter.choice else "  "
						lines.append("%s%d. %s" % [mark, j + 1,
							opts[j].text_ru])
		panel.text = "\n".join(lines)
	elif not chron.is_empty():
		var lines := ["Летопись обители", "", atlas.chronicle.scene_ru, ""]
		if chron.reply != "":
			lines += [chron.reply, "", "(нажми — закрыть летопись)"]
		else:
			var opts := AtlasTraces.options(atlas)
			for j in opts.size():
				var mark := "▸ " if j == chron.choice else "  "
				lines.append("%s%d. %s" % [mark, j + 1, opts[j].text_ru])
		panel.text = "\n".join(lines)
	elif not trial.is_empty():
		var tv := TrialCore.trial_view(trial_data, trial_state, trial.gate,
			form, actions)
		var tr: Dictionary = tv.trial
		var lines := [tr.title_ru, "", tr.scene_ru, ""]
		if trial.reply != "":
			lines += [trial.reply, "", "(нажми — отойти от порога)"]
		else:
			for j in tv.options.size():
				var mark := "▸ " if j == trial.choice else "  "
				lines.append("%s%d. %s" % [mark, j + 1, tv.options[j].text])
		panel.text = "\n".join(lines)
	elif not mission.is_empty():
		panel.text = _mission_panel_text()
	elif not talk.is_empty():
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
	if text == "" and not _panel_open():
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

## --shots=<dir>: the courtyard, the mentors, a talk, the pier, the ladder,
## the thresholds, the road, the atlas and the board of missions.
func _shots() -> void:
	var plan := [
		{"name": "courtyard", "pos": Vector3(0, 0, 5.5), "yaw": 0.0},
		{"name": "mentors", "pos": Vector3(-2.2, 0, 0), "yaw": PI / 2.0},
		{"name": "talk", "pos": Vector3(-3.4, 0, -1.8), "yaw": PI / 2.0,
			"talk": "elder_sergius"},
		{"name": "pier", "pos": Vector3(5.5, 0, 0.6), "yaw": -PI / 2.0},
		{"name": "ladder", "pos": Vector3(1.0, 0, -1.0), "yaw": 0.0},
		{"name": "witness-gate", "pos": Vector3(1.2, 0, 3.4), "yaw": PI},
		{"name": "threshold", "pos": Vector3(1.0, 0, -2.4), "yaw": 0.0,
			"trial": "foundational"},
		{"name": "road", "pos": Vector3(-5.6, 0, 4.6), "yaw": PI,
			"road": true},
		{"name": "atlas", "pos": Vector3(-4.4, 0, 6.2), "yaw": 0.0},
		{"name": "chronicle", "pos": Vector3(-3.8, 0, 2.4), "yaw": PI / 2.0,
			"chronicle": true},
		{"name": "mission-board", "pos": Vector3(0.9, 0, 1.2),
			"yaw": -PI / 2.0},
		{"name": "missions", "pos": Vector3(1.0, 0, 1.2), "yaw": -PI / 2.0,
			"mission": true},
		{"name": "journal", "pos": Vector3(-4.3, 0, -5.0), "yaw": PI / 2.0},
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
	if s.has("road"):
		trial = {}
		if encounter.is_empty():
			_road()
	else:
		# Each proof frame shows one thing: a meeting on the road does
		# not follow the player to the next place.
		encounter = {}
		road_sprite.visible = false
	# The chronicle's page open, nothing written (a proof frame only).
	chron = {"choice": 0, "reply": ""} if s.has("chronicle") else {}
	if s.has("trial") and trial.is_empty():
		# The first gate opened as the ladder asks: Wisdom 4, ten knots,
		# a talk with Theodora (a proof frame only; nothing is saved).
		form.wisdom = 4
		actions.prayerCount = 10.0
		actions.met["theodora"] = 1
		trial = {"gate": s.trial, "choice": 1, "reply": ""}
	if s.has("mission") and mission.is_empty():
		# The first mission set out on at the board, its first step open
		# (a proof frame only; nothing is saved).
		trial = {}
		var st := MissionCore.start(mission_data, _mstate(),
			MissionCore.next_mission(mission_data, _mstate()))
		mission_state = {"done": st.done, "current": st.current,
			"flags": st.flags, "lines": st.lines}
		mission = {"choice": 0, "start": -1}
	elif not s.has("mission"):
		mission = {}
	if shot_frame % 20 == 19:
		get_viewport().get_texture().get_image().save_png(
			"%s/hub-%s.png" % [shots_dir, s.name])
	shot_frame += 1
