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
## The surfaces things rest on, metres (top faces of the boxes below).
const FLOOR_Y := 0.0
const TABLE_Y := 0.765
const SHELF_Y := 1.365
const SILT_Y := 0.0
## The distorted echo on the lake floor (TABOO 0.016 items 1-2): the
## operator's own things, smaller, rusted, tipped where they fell; a
## trail from the seat towards the amphora.  [name, place, scale]
const ECHO := [["EchoMug", Vector3(0.30, 0, -1.55), 0.6],
	["EchoBook", Vector3(0.50, 0, -2.15), 0.55],
	["EchoCoil", Vector3(1.10, 0, -2.55), 0.45]]
const ROOM_LIGHT := Color(1.0, 0.78, 0.55)
const LAMP_LIGHT := Color(0.92, 0.96, 1.0)

var data := {}
var t := 0.0
var speed := 1.0
var reduced := false
## Whether the tether's jerk may turn the world (opt-in, see _jerk).
var world_turn := false
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
var hand: Node3D
var drams: Node3D
var khachkar: Node3D
var console_level := 1.0
## Named things the details act on (pilot-details.json "show", "hide",
## "move").
var things := {}
## Every thing set down by _land: {node, surface, name}; the gravity test
## measures each again (TABOO 0.016 item 3).
var grounded: Array = []
## The 55 details (godot/data/pilot-details.json), each with its second
## on the episode's clock; the next to fire; the ids fired, for tests.
var details: Array = []
var detail_i := 0
var fired: Array[String] = []
## Short effects of details: {k, until, v, ...}; they lie over what
## _sync sets and end by the clock.
var effects: Array = []
## The rising wonder of the episode (WowStage over WowCore's curve).
var wow: WowStage
## The operator's volumetric laser-bubble screen beside the console
## (docs/HLD_VOLUMETRIC_LASER_SCREEN_2026-10-03.md, TABOO 0.022).
var volume: VolumetricScreen
## The hero's AI «Клауд» (TABOO 0.026): its lines, the ones already
## said this run, its line on the right wrist and its draft voice.
var companion := {}
var said_by_claud: Array[String] = []
var claud_line: Label3D
var claud_voice: AudioStreamPlayer
## The deepest dip of the machine's sound asked by a live detail, dB.
var duck_db := 0.0
## The room's clues (Pandora V1): seconds each has been held in view,
## the ids found, and the crouch (a seated player's Ctrl, as in Tex).
var clue_hold := {}
var clues_found: Array[String] = []
var crouched := false
var crouch_was := false
## Set by a test: {head, forward} in place of the camera.
var clue_override := {}
## The glasses (the close-up swap, docs/HLD_SWAP_RENDERING_2026-10-02.md):
## on the face or not; the thing in close-up ("" if none) and for how
## long; the seconds of gaze on a candidate; things already examined.
var glasses_on := false
var examining := ""
var examine_open_s := 0.0
var examine_hold := {}
var examine_rest := ""
var examined: Array[String] = []
var close_up: MeshInstance3D
var glasses_was := false
## The examine video (TABOO 0.019): a flipbook atlas from the pack,
## played on the close-up; its clip.json; the frame clock; the voice.
var clip := {}
var clip_t := 0.0
var clip_check_s := 0.0
var narrator: AudioStreamPlayer
## Decoded examine videos kept in memory after their close-up closes:
## id -> {clip, idle}; a second look within CLIP_KEEP_S starts at once,
## later the atlas leaves memory (operator, 2026-10-02: keep a cache and
## clear it after two minutes).  The pack itself stays on disk.
const CLIP_KEEP_S := 120.0
var clip_cache := {}
## The narrator (TABOO 0.019, 0.020): the chorus' lines of
## data/pilot-narration.json, a subtitle under the scribe's line and,
## when the pack brings it, the recorded voice; seconds left on screen;
## the keys already spoken.
var narration := {}
var narr: Label3D
var narr_left := 0.0
var narrated: Array[String] = []
## The language of subtitles and voice: "ru" by default, or "lang" in
## user://settings.json (en, de, fr, es, it; the chorus' translation in
## data/pilot-narration-i18n.json).
var lang := "ru"
var i18n := {}

# Insights: flashbacks called by place, order, clock, depth, the step of
# the thought or stillness (InsightCore, godot/data/pilot-insights.json).
# While one plays the clock stands, as under the glasses.
var insights := {}
var events: Array[String] = []
var shown: Array[String] = []
var insight := {}
var insight_s := 0.0
var insight_dur := 0.0
var since_insight := INF
var look_s := {}
var still_s := 0.0
var last_head := Vector3.ZERO
var last_fwd := Vector3.FORWARD
var skip := {}
var skip_progress := 0.0
var skip_override := {}
var skipped: Array[String] = []
var veil: MeshInstance3D

# The operator's own instruments (TABOO 0.022, ApparatusCore): a panel
# for the robot and one for the surface, their video drawn from the
# scene's telemetry by ScreenFeed.
var apparatus := {}
var panels := {}
var panel_s := 0.0
var field_log: Array = []
var track: Array = []
var track_s := 0.0
var memory: MeshInstance3D
var skip_icon: Label3D
var ins_duck := 0.0

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
## The suite «Наука. Любовь. Познание.»: the music of each beat's node
## of Entelechy (CosmosSynth), on its own bus with the space's reverb.
var music := CosmosSynth.new()
var music_player: AudioStreamPlayer
var music_playback: AudioStreamGeneratorPlayback


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--pilot-speed="):
			speed = maxf(1.0, float(a.get_slice("=", 1)))
	Glyphs.install()
	reduced = "--reduced-motion" in args or Haptics.prefers_reduced()
	world_turn = "--world-turn" in args or _setting("world_turn")
	if seen() and not replay and not "--pilot-replay" in args:
		ModuleLoader.go(ModuleLoader.HUB)
		finished = true
		return
	data = PilotCore.load_data()
	details = PilotCore.load_details(data)
	narration = PilotCore.load_narration()
	lang = PilotCore.language()
	i18n = PilotCore.load_i18n()
	insights = InsightCore.load_data()
	apparatus = ApparatusCore.load_data()
	# The insights' lines speak through the narrator like the others.
	var lines := {}
	for x in insights.get("insights", []):
		lines[x.id] = {"line_ru": x.line_ru, "bridge_to": x.bridge_to}
	narration["insights"] = lines
	passion = _passion(data.taboo.passion)
	state = PassionCore.start(passion)
	body = PilotCore.body_start()
	_build_rig()
	_build_world()
	_build_room()
	_build_lake()
	_build_screens()
	_build_sound()
	_build_close_up()
	_start_xr()
	_place_console()
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
	# The wonder is staged in front, below the horizon, at arm's length
	# and more, so it is seen without turning the neck (pilot-wow.json).
	wow = WowStage.new()
	wow.position = Vector3(0, 0.9, -1.5)
	rig.add_child(wow)
	# The volumetric screen stands at the right of the console, at arm's
	# length and a little below the eyes: the lake's own data in the
	# lake, layers, oxygen and the floor in light on bubbles.
	volume = VolumetricScreen.new()
	volume.position = Vector3(0.75, 0.85, -1.3)
	volume.scale = Vector3.ONE * 0.6
	rig.add_child(volume)


func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## The operator's room where there is no passthrough: the rented room
## of an expedition hand on the shore, lived in (the interior chorus,
## docs/story/PILOT_EPISODE_1_TABU_2026-10-02.md §3б).  Every thing in
## it says one thing about him and the story; none is holy (the red
## corner is an open question to the operator, Д-20).  The still
## furniture is merged by StaticBatch so the room keeps to the draw
## call budget; the things the details move stay apart (THINGS).
func _build_room() -> void:
	room = Node3D.new()
	add_child(room)
	var still := Node3D.new()
	still.name = "Furniture"
	room.add_child(still)
	var wall := _mat(Color(0.47, 0.44, 0.39))
	var wood := _mat(Color(0.45, 0.32, 0.20))
	var dark_wood := _mat(Color(0.28, 0.19, 0.12))
	var h := 2.6
	_box(still, Vector3(ROOM_HALF * 2, 0.05, ROOM_HALF * 2),
		Vector3(0, -0.025, 0), _mat(Color(0.33, 0.26, 0.19)))
	_box(still, Vector3(ROOM_HALF * 2, 0.05, ROOM_HALF * 2),
		Vector3(0, h, 0), _mat(Color(0.62, 0.60, 0.56)))
	_box(still, Vector3(ROOM_HALF * 2, h, 0.05),
		Vector3(0, h / 2, -ROOM_HALF), wall)
	_box(still, Vector3(ROOM_HALF * 2, h, 0.05),
		Vector3(0, h / 2, ROOM_HALF), wall)
	_box(still, Vector3(0.05, h, ROOM_HALF * 2),
		Vector3(-ROOM_HALF, h / 2, 0), wall)
	_box(still, Vector3(0.05, h, ROOM_HALF * 2),
		Vector3(ROOM_HALF, h / 2, 0), wall)
	# A felt rug, the way rooms on the Issyk-Kul shore are kept.
	_box(still, Vector3(1.8, 0.012, 1.2), Vector3(0, 0.006, -0.4),
		_mat(Color(0.48, 0.20, 0.16)))
	_box(still, Vector3(1.5, 0.014, 0.9), Vector3(0, 0.008, -0.4),
		_mat(Color(0.62, 0.48, 0.30)))
	# The work table: four legs, the top.
	_box(still, Vector3(1.2, 0.05, 0.6), Vector3(0, 0.74, -1.1), wood)
	for x in [-0.55, 0.55]:
		for z in [-1.35, -0.85]:
			_box(still, Vector3(0.05, 0.72, 0.05), Vector3(x, 0.36, z),
				dark_wood)
	# The laptop with the dive log open: the instrument's cold light in
	# a warm room (TABOO 0.38: 6500 K belongs to the instrument).
	_box(still, Vector3(0.34, 0.02, 0.24), Vector3(-0.28, 0.775, -1.08),
		_mat(Color(0.18, 0.18, 0.20)))
	var scr := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.34, 0.22, 0.01)
	scr.mesh = sb
	scr.material_override = _mat(Color(0.55, 0.75, 0.85), 0.6)
	scr.position = Vector3(-0.28, 0.89, -1.2)
	scr.rotation.x = -0.25
	room.add_child(scr)
	# A mug gone cold beside it: he has been up all night.
	var mug := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.04
	mm.bottom_radius = 0.036
	mm.height = 0.095
	mug.mesh = mm
	mug.material_override = _mat(Color(0.86, 0.84, 0.78))
	mug.position = Vector3(0.18, 0.815, -0.92)
	still.add_child(mug)
	_land(mug, TABLE_Y)
	# The desk lamp: the human work light, 2500 K (TABOO 0.38).
	var lamp_base := MeshInstance3D.new()
	var lb := CylinderMesh.new()
	lb.top_radius = 0.05
	lb.bottom_radius = 0.06
	lb.height = 0.02
	lamp_base.mesh = lb
	lamp_base.material_override = dark_wood
	lamp_base.position = Vector3(0.48, 0.775, -1.28)
	still.add_child(lamp_base)
	_land(lamp_base, TABLE_Y)
	_box(still, Vector3(0.015, 0.34, 0.015), Vector3(0.48, 0.95, -1.28),
		dark_wood)
	var shade := MeshInstance3D.new()
	var sh := CylinderMesh.new()
	sh.top_radius = 0.03
	sh.bottom_radius = 0.09
	sh.height = 0.1
	shade.mesh = sh
	shade.material_override = _mat(Color(0.30, 0.42, 0.30))
	shade.position = Vector3(0.48, 1.13, -1.22)
	still.add_child(shade)
	var light := OmniLight3D.new()
	light.name = "RoomLight"
	light.light_color = ROOM_LIGHT
	light.light_energy = 1.3
	light.omni_range = 6.0
	light.position = Vector3(0.48, 1.05, -1.15)
	room.add_child(light)
	# The window over the lake at night, one upright bar.
	_box(still, Vector3(0.95, 0.75, 0.04), Vector3(-0.95, 1.55, -1.97),
		dark_wood)
	var pane := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.85, 0.65, 0.02)
	pane.mesh = pb
	pane.material_override = _mat(Color(0.05, 0.09, 0.16), 0.4)
	pane.position = Vector3(-0.95, 1.55, -1.95)
	room.add_child(pane)
	_box(still, Vector3(0.03, 0.65, 0.03), Vector3(-0.95, 1.55, -1.93),
		dark_wood)
	# The chart of the lake on the wall, a red pin at the find: the
	# stakes are pinned where he sleeps.
	_box(still, Vector3(0.8, 0.55, 0.01), Vector3(0.75, 1.6, -1.97),
		_mat(Color(0.86, 0.80, 0.66)))
	var lake_map := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.3
	lm.bottom_radius = 0.3
	lm.height = 0.004
	lake_map.mesh = lm
	lake_map.material_override = _mat(Color(0.30, 0.48, 0.62))
	lake_map.position = Vector3(0.75, 1.6, -1.96)
	lake_map.rotation.x = PI / 2
	lake_map.scale = Vector3(1.0, 1.0, 0.42)
	still.add_child(lake_map)
	var pin := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.012
	pm.height = 0.024
	pin.mesh = pm
	pin.material_override = _mat(Color(0.75, 0.10, 0.08))
	pin.position = Vector3(0.83, 1.58, -1.94)
	still.add_child(pin)
	# The bed along the right wall, the blanket thrown back.
	_box(still, Vector3(0.9, 0.35, 1.9), Vector3(1.5, 0.175, 0.7),
		dark_wood)
	_box(still, Vector3(0.86, 0.12, 1.84), Vector3(1.5, 0.41, 0.7),
		_mat(Color(0.80, 0.78, 0.72)))
	_box(still, Vector3(0.88, 0.06, 1.1), Vector3(1.48, 0.49, 1.05),
		_mat(Color(0.32, 0.36, 0.48)))
	_box(still, Vector3(0.6, 0.1, 0.32), Vector3(1.5, 0.52, -0.05),
		_mat(Color(0.90, 0.88, 0.84)))
	# The shelf on the left wall: books, and the souvenir jug (below).
	_box(still, Vector3(0.26, 0.03, 1.3), Vector3(-1.86, 1.35, -0.6),
		dark_wood)
	var book_colors := [Color(0.45, 0.12, 0.10), Color(0.15, 0.25, 0.40),
		Color(0.55, 0.45, 0.25), Color(0.20, 0.32, 0.20),
		Color(0.35, 0.30, 0.28), Color(0.50, 0.18, 0.14)]
	for i in book_colors.size():
		var bh := 0.2 + 0.03 * (i % 3)
		_box(still, Vector3(0.18, bh, 0.045),
			Vector3(-1.86, 1.365 + bh / 2, -1.15 + 0.055 * i),
			_mat(book_colors[i]))
	# The tether coiled on the floor in the corner, yellow as on the
	# slipway: the trade of the man who lives here.
	for i in 3:
		var coil := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.2 - 0.012 * i
		tm.outer_radius = 0.23 - 0.012 * i
		coil.mesh = tm
		coil.material_override = _mat(Color(0.85, 0.66, 0.12))
		coil.position = Vector3(-1.45, 0.0, -1.45)
		still.add_child(coil)
		# Each turn of the coil rests on the one below it.
		_land(coil, FLOOR_Y + 0.03 * i)
	# The console case, black with yellow latches.
	_box(still, Vector3(0.55, 0.22, 0.38), Vector3(1.35, 0.11, -1.55),
		_mat(Color(0.08, 0.08, 0.09)))
	for x in [1.18, 1.52]:
		_box(still, Vector3(0.06, 0.05, 0.02), Vector3(x, 0.15, -1.355),
			_mat(Color(0.85, 0.66, 0.12)))
	_build_things()
	_build_clues()
	_build_glasses()
	_build_ads()
	StaticBatch.merge(still)
	water = MeshInstance3D.new()
	var wp := PlaneMesh.new()
	wp.size = Vector2(ROOM_HALF * 2, ROOM_HALF * 2)
	water.mesh = wp
	var wm := _mat(Color(0.05, 0.16, 0.20, 0.72), 0.15)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	wm.roughness = 0.05
	water.material_override = wm
	water.position.y = -0.01
	add_child(water)


## The room's things the details show, hide or move (pilot-details.json),
## and the souvenir jug: the same amphora as on the lake floor, smaller,
## glazed another colour, lying on the shelf at another angle; the
## viewer sees the rhyme before knowing it (Chekhov's gun).
func _build_things() -> void:
	var jug := _glb("res://models/atlas/atlas-amphora.glb",
		Vector3(-1.86, 1.43, -0.3), room)
	jug.name = "Souvenir"
	# 60 % smaller than the one on the lake floor (TABOO 0.016 item 1).
	jug.scale = Vector3.ONE * 0.4
	# Upright and leaning a little on the wall: a jug kept, not lost.
	jug.rotation = Vector3(0.0, 0.5, PI / 2.0 - 0.12)
	jug.position.x = -1.9
	_paint(jug, _mat(Color(0.18, 0.40, 0.36)))
	_land(jug, SHELF_Y)
	var log_book := _thing("Logbook", Vector3(0.17, 0.025, 0.24),
		Vector3(0.12, 0.778, -1.12), _mat(Color(0.22, 0.13, 0.08)), room)
	log_book.rotation.y = 0.18
	_land(log_book, TABLE_Y)
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.045
	rm.bottom_radius = 0.045
	rm.height = 0.002
	ring.mesh = rm
	ring.material_override = _mat(Color(0.30, 0.21, 0.13))
	ring.position = Vector3(0.38, 0.766, -0.98)
	ring.name = "Ring"
	ring.visible = false
	room.add_child(ring)
	things["Ring"] = ring
	_land(ring, TABLE_Y)
	var floor_dram := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.035
	fm.bottom_radius = 0.035
	fm.height = 0.006
	floor_dram.mesh = fm
	var silver := _mat(Color(0.86, 0.86, 0.80), 0.6)
	silver.metallic = 1.0
	floor_dram.material_override = silver
	floor_dram.position = Vector3(0.25, 0.018, -0.7)
	floor_dram.name = "FloorDram"
	floor_dram.visible = false
	room.add_child(floor_dram)
	things["FloorDram"] = floor_dram
	_land(floor_dram, FLOOR_Y)


## The flash drive taped under the table and the water stain on the
## ceiling in the shape of the lake.  Neither lies on a surface: one is
## taped, one is on the plaster, so neither goes through _land.
func _build_clues() -> void:
	var drive := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.06, 0.012, 0.02)
	drive.mesh = dm
	drive.material_override = _mat(Color(0.20, 0.30, 0.55))
	drive.position = Vector3(0.05, 0.709, -1.15)
	drive.name = "Backup"
	room.add_child(drive)
	# Wide white tape: the eye finds the tape first, then the drive.
	_box(room, Vector3(0.16, 0.002, 0.07), Vector3(0.05, 0.7135, -1.15),
		_mat(Color(0.92, 0.90, 0.82), 0.2))
	var stain := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.35
	sm.bottom_radius = 0.35
	sm.height = 0.002
	stain.mesh = sm
	stain.material_override = _mat(Color(0.40, 0.36, 0.30))
	stain.position = Vector3(0.35, 2.574, -0.7)
	stain.scale = Vector3(1.0, 1.0, 0.42)
	stain.name = "Stain"
	room.add_child(stain)


## The ad slot of the operator's room: a printed flyer pinned to the
## wall, "YOUR AD COULD BE HERE", no brand (operator, 2026-10-02).
func _build_ads() -> void:
	for a in data.get("ad_slots", []):
		var pos: Array = a.pos
		var flyer := Node3D.new()
		flyer.name = "Ad_" + str(a.id)
		flyer.position = Vector3(pos[0], pos[1], pos[2])
		flyer.rotation.y = -PI / 2.0
		_box(flyer, Vector3(0.42, 0.3, 0.004), Vector3.ZERO,
			_mat(Color(0.93, 0.90, 0.80)))
		var big := Label3D.new()
		big.text = str(a.text_en)
		big.font_size = 44
		big.pixel_size = 0.0007
		big.width = 520
		big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		big.modulate = Color(0.12, 0.10, 0.09)
		big.outline_size = 0
		big.position = Vector3(0, 0.03, 0.004)
		flyer.add_child(big)
		var small := Label3D.new()
		small.text = str(a.small_en)
		small.font_size = 22
		small.pixel_size = 0.0007
		small.modulate = Color(0.30, 0.27, 0.24)
		small.outline_size = 0
		small.position = Vector3(0, -0.1, 0.004)
		flyer.add_child(small)
		room.add_child(flyer)
		things[flyer.name] = flyer


## Reading glasses on the table by the laptop: two rims and a bridge.
func _build_glasses() -> void:
	var g := Node3D.new()
	g.name = "Glasses"
	var pos: Array = data.glasses.pos
	g.position = Vector3(pos[0], pos[1] + 0.02, pos[2])
	g.rotation.y = 0.4
	var frame := _mat(Color(0.12, 0.10, 0.09))
	for x in [-0.032, 0.032]:
		var rim := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.022
		tm.outer_radius = 0.026
		rim.mesh = tm
		rim.material_override = frame
		rim.position = Vector3(x, 0, 0)
		g.add_child(rim)
	_box(g, Vector3(0.02, 0.003, 0.004), Vector3.ZERO, frame)
	for x in [-0.058, 0.058]:
		_box(g, Vector3(0.003, 0.003, 0.12), Vector3(x, 0, 0.06), frame)
	room.add_child(g)
	things["Glasses"] = g
	_land(g, TABLE_Y)


func _thing(n: String, size: Vector3, at: Vector3, m: Material,
		parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	mi.name = n
	parent.add_child(mi)
	things[n] = mi
	return mi


## The echo on the silt: the room's mug, logbook and coil again, 40-55 %
## of their size, rust and silt in place of their colours, tipped by
## angles from their names' hash (no randomness).  Shown with the lamp.
func _build_echo() -> void:
	var echo_node := Node3D.new()
	echo_node.name = "Echo"
	lake.add_child(echo_node)
	var rust := _mat(Color(0.36, 0.22, 0.13))
	rust.roughness = 1.0
	for e in ECHO:
		var n := Node3D.new()
		n.name = e[0]
		n.position = e[1]
		echo_node.add_child(n)
		var mi := MeshInstance3D.new()
		match e[0]:
			"EchoMug":
				var cm := CylinderMesh.new()
				cm.top_radius = 0.04
				cm.bottom_radius = 0.036
				cm.height = 0.095
				mi.mesh = cm
			"EchoBook":
				var bm := BoxMesh.new()
				bm.size = Vector3(0.17, 0.025, 0.24)
				mi.mesh = bm
			"EchoCoil":
				var tm := TorusMesh.new()
				tm.inner_radius = 0.2
				tm.outer_radius = 0.23
				mi.mesh = tm
		mi.material_override = rust
		n.add_child(mi)
		n.scale = Vector3.ONE * float(e[2])
		n.rotation = _tip(e[0])
		things[e[0]] = n
		_land(n, SILT_Y)


## A fallen thing's tilt from its name: up to 80 degrees on x and z, any
## heading; the same name always falls the same way.
static func _tip(n: String) -> Vector3:
	var h := n.sha256_text()
	var a := float(h.substr(0, 4).hex_to_int()) / 65535.0
	var b := float(h.substr(4, 4).hex_to_int()) / 65535.0
	var c := float(h.substr(8, 4).hex_to_int()) / 65535.0
	return Vector3(deg_to_rad(80.0 * a), TAU * b, deg_to_rad(80.0 * c))


## The transform of n in the pilot's own space, without the tree (the
## scene may be built before it enters one, as in the tests).
func _xf(n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != self:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## The lowest point of every mesh under n, in the pilot's space.
func bottom_of(n: Node3D) -> float:
	var low := INF
	var stack: Array = [n]
	while not stack.is_empty():
		var c = stack.pop_back()
		if c is MeshInstance3D and c.mesh != null:
			# The real vertices, not the box around them: a tipped
			# cylinder's box reaches lower than its rim, and the thing
			# would hang a centimetre over the silt.
			var xf := _xf(c)
			for v in c.mesh.get_faces():
				low = minf(low, (xf * v).y)
		for k in c.get_children():
			stack.append(k)
	return low


## Set n down so its lowest point lies on the surface at height y
## (TABOO 0.016 item 3: gravity is code, not a word).
func _land(n: Node3D, y: float) -> void:
	var low := bottom_of(n)
	if low == INF:
		return
	n.position.y += y - low
	grounded.append({"node": n, "surface": y, "name": str(n.name)})


## Give every mesh of an imported model one material.
func _paint(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = m
	for c in n.get_children():
		_paint(c, m)


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
	amphora.name = "Amphora"
	things["Amphora"] = amphora
	_land(amphora, SILT_Y)
	khachkar = _glb("res://models/atlas/atlas-khachkar.glb",
		KHACHKAR_AT, lake)
	khachkar.set_meta("noInteract", true)
	khachkar.set_meta("noLoot", true)
	# The stone stands on the silt as it is: set down, never echoed.
	_land(khachkar, SILT_Y)
	khachkar.visible = false
	var diary := _glb("res://models/atlas/atlas-diary.glb", DIARY_AT, lake)
	diary.name = "Diary"
	_land(diary, SILT_Y)
	diary.visible = false
	# The walls the sonar finds: straight lines among the stones.
	var stone := _mat(Color(0.33, 0.31, 0.27))
	var walls := Node3D.new()
	walls.name = "Walls"
	walls.visible = false
	lake.add_child(walls)
	_box(walls, Vector3(4.0, 0.5, 0.4), Vector3(-1.5, 0.25, -6.5), stone)
	_box(walls, Vector3(0.4, 0.5, 3.0), Vector3(-3.5, 0.25, -5.2), stone)
	# The blocked doorway and the comet cut in a stone of the wall: the
	# details show them when the sonar has drawn the walls.
	_thing("Doorway", Vector3(0.7, 0.45, 0.42), Vector3(-0.9, 0.24, -6.48),
		_mat(Color(0.05, 0.05, 0.05)), walls).visible = false
	var wall_mark := _comet(Color(0.16, 0.14, 0.12), 3.0)
	wall_mark.position = Vector3(-2.2, 0.32, -6.28)
	wall_mark.rotation.x = PI / 2.0
	wall_mark.name = "WallMark"
	wall_mark.visible = false
	walls.add_child(wall_mark)
	things["WallMark"] = wall_mark
	# The lure: silver drams that shine without the lamp (the shine is
	# the prilog's sign, TABOO 0.2 item 8).
	drams = Node3D.new()
	drams.position = DRAMS_AT
	drams.visible = false
	drams.name = "Drams"
	lake.add_child(drams)
	things["Drams"] = drams
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
	_land(drams, SILT_Y)
	_build_echo()
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
	# The scribe's line reads over a close-up, never under it.
	line.render_priority = 4
	title = _label(64, Vector3(0, 0.02, -1.2), Color(0.95, 0.93, 0.88))
	narr = _label(28, Vector3(0, -0.33, -1.0), Color(0.93, 0.93, 0.90))
	# Клауд speaks in the instrument's cyan, a little apart from the
	# Prior's screen; in the headset it lives on the right wrist.
	claud_line = _label(26, Vector3(-0.30, 0.12, -1.0),
		Color(0.62, 0.86, 1.0))
	companion = CompanionCore.load_data()
	claud_voice = AudioStreamPlayer.new()
	add_child(claud_voice)
	narr.render_priority = 4
	title.visible = false
	# The left hand with the comet on its back: a dim head and a tail,
	# ink, no glow (node 99).  In the headset it rides the left
	# controller; on a screen it is held up in front of the eyes at the
	# drain, so it reads as a hand and not as a thing in the air.
	hand = Node3D.new()
	hand.name = "Hand"
	hand.visible = false
	var skin := _mat(Color(0.80, 0.62, 0.50))
	_box(hand, Vector3(0.085, 0.026, 0.095), Vector3.ZERO, skin)
	for i in 4:
		_box(hand, Vector3(0.017, 0.02, 0.075 - 0.008 * absi(i - 1)),
			Vector3(-0.03 + 0.02 * i, 0, -0.08), skin)
	var thumb := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.02, 0.02, 0.06)
	thumb.mesh = tb
	thumb.material_override = skin
	thumb.position = Vector3(0.055, -0.004, -0.02)
	thumb.rotation.y = -0.6
	hand.add_child(thumb)
	_box(hand, Vector3(0.07, 0.05, 0.14), Vector3(0, 0, 0.11),
		_mat(Color(0.20, 0.22, 0.26)))
	mark = _comet(Color(0.30, 0.18, 0.14), 1.0)
	mark.position = Vector3(-0.01, 0.0135, 0.0)
	mark.name = "Mark"
	mark.visible = false
	hand.add_child(mark)
	things["Mark"] = mark
	left_hand.add_child(hand)


## A comet of ink: a head and a tail lying flat, `k` times the size of
## the one on the hand.
func _comet(c: Color, k: float) -> Node3D:
	var n := Node3D.new()
	var ink := _mat(c)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.006 * k
	sm.height = 0.004 * k
	head.mesh = sm
	head.material_override = ink
	n.add_child(head)
	var tail := MeshInstance3D.new()
	var tm := PrismMesh.new()
	tm.size = Vector3(0.012 * k, 0.03 * k, 0.001 * k)
	tail.mesh = tm
	tail.material_override = ink
	tail.rotation = Vector3(-PI / 2.0, 0, -PI / 2.0 - 0.3)
	tail.position = Vector3(0.017 * k, 0, 0.005 * k)
	n.add_child(tail)
	return n


func _build_sound() -> void:
	var bus := DiveAudio.ensure_bus()
	player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = DiveSynth.MIX_RATE
	gen.buffer_length = 0.25
	player.stream = gen
	player.bus = AudioServer.get_bus_name(bus)
	add_child(player)
	music_player = AudioStreamPlayer.new()
	music_player.name = "Music"
	var mgen := AudioStreamGenerator.new()
	mgen.mix_rate = CosmosSynth.MIX_RATE
	mgen.buffer_length = 0.3
	music_player.stream = mgen
	music_player.bus = AudioServer.get_bus_name(CosmosSynth.ensure_bus())
	add_child(music_player)
	if DisplayServer.get_name() != "headless":
		player.play()
		playback = player.get_stream_playback()
		music_player.play()
		music_playback = music_player.get_stream_playback()


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


## The close-up: a picture before the eyes, unlit (its light is the
## render's), drawn over the world while the world is paused.
func _build_close_up() -> void:
	close_up = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.4, 0.4)
	close_up.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.render_priority = 3
	close_up.material_override = m
	close_up.position = Vector3(0, 0.09, -0.7)
	close_up.visible = false
	camera.add_child(close_up)
	narrator = AudioStreamPlayer.new()
	narrator.name = "Narrator"
	add_child(narrator)
	_build_insight()
	_build_panels()


## In the headset the Prior's screen lives on the left wrist, read by
## turning the hand, as a gauge on a diver's arm (diegetic interface,
## Into the Radius; docs/HLD_PANDORA_SURPASS_2026-10-02.md §8): text
## nailed to the eyes follows every head turn and tires them.  On a
## screen it stays where it was.
func _place_console() -> void:
	if not xr_active or screen.get_parent() == left_hand:
		return
	screen.reparent(left_hand, false)
	screen.position = Vector3(0.0, 0.04, 0.02)
	screen.rotation = Vector3(-PI / 2.0 + 0.5, 0.0, 0.0)
	screen.pixel_size = 0.0004
	screen.width = 500
	claud_line.reparent(right_hand, false)
	claud_line.position = Vector3(0.0, 0.04, 0.02)
	claud_line.rotation = Vector3(-PI / 2.0 + 0.5, 0.0, 0.0)
	claud_line.pixel_size = 0.0004
	claud_line.width = 500


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
	_examine(dt)
	if examining != "":
		# Pandora's swap: the world waits while the eye reads the thing.
		return
	if _insight(dt):
		# A memory has come: the clock of the dive stands while it plays.
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
	events.append("beat:" + str(b.id))
	narrate("beats", b.id)
	claud("enter")
	if b.has("message_ru"):
		screen.text = _ui(["screen", b.id, "message"], b.message_ru)
		claud("message")
	if b.has("line_ru"):
		line.text = _ui(["screen", b.id, "line"], b.line_ru)
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
			claud("telemetry")
		"choice_echo":
			echo = PilotCore.echo(data, str(state.stage))
			narrate("objects", "echo_" + str(echo.get("episode2", "")
				).replace("order_first", "captive").replace("scribe_first",
				"virtue").replace("prior_waits", "unresolved"))
			screen.text = _ui(["screen", "choice_echo", "outcomes",
				str(state.stage) if str(state.stage) in ["captive", "virtue"]
				else "unresolved", "message"], echo.message_ru)
			line.text = echo.get("scribe_ru", "")
		"khachkar":
			# The machine has nothing to say at the holy; what it said
			# before does not come back after.
			screen.text = ""
			line.text = ""
		"room_drains":
			screen.text = ""
			line.text = ""
			if not xr_active and hand.get_parent() != camera:
				# On a screen the hand is held up in front of the eyes,
				# its back to them.
				hand.reparent(camera, false)
				hand.position = Vector3(-0.07, -0.16, -0.36)
				hand.rotation = Vector3(0.9, 0.35, 0.0)
		"title":
			title.text = b.title_ru
			screen.text = ""
			line.text = ""


## What is lit and shown follows the clock alone, so a frame that skips
## a beat (a dropped frame, a test, a proof shot) shows the same as one
## that walked through it.
func _sync() -> void:
	lamp.light_energy = 3.0 if t >= 70.0 and t < 860.0 else 0.0
	env.fog_density = 0.12 if world == "lake" else 0.0
	if t >= 590.0:
		# After the choice the lamp is the operator's again.
		lamp.rotation = Vector3.ZERO
	lake.get_node("Walls").visible = t >= 140.0
	lake.get_node("Echo").visible = t >= 70.0
	drams.visible = t >= 440.0 and t < 590.0
	khachkar.visible = t >= 640.0
	lake.get_node("Diary").visible = t >= 720.0
	hand.visible = xr_active or t >= 860.0
	# The ink comes up on the skin as on a wet page (detail r04).
	mark.visible = t >= 869.0
	if mark.visible:
		narrate("objects", "Mark")
		claud("mark")
	# At the khachkar Клауд goes out with the console (TABOO 0.026 item 2).
	if beat_id == "khachkar":
		claud_line.text = ""
		if claud_voice.playing:
			claud_voice.stop()
	title.visible = t >= 900.0


func _tick(dt: float) -> void:
	_sync()
	while detail_i < details.size() and float(details[detail_i].t) <= t:
		_do(details[detail_i])
		detail_i += 1
	_effects()
	wow.update(t, reduced, [left_hand, right_hand])
	_volume()
	_panels(dt)
	if world == "room":
		_clues(dt)
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


## The head and its forward, from the camera or a test.
func _head() -> Array:
	return [clue_override.get("head", _xf(camera).origin),
		clue_override.get("forward", -_xf(camera).basis.z)]


## Glasses on, then a close-up on gaze; closed by a press or in time.
func _examine(dt: float) -> void:
	age_clips(dt)
	if narr_left > 0.0:
		narr_left -= dt
		if narr_left <= 0.0:
			narr.text = ""
	# Either hand: the game is played with one hand too (a11y audit).
	var press := Input.is_key_pressed(KEY_G) \
		or right_hand.is_button_pressed("ax_button") \
		or left_hand.is_button_pressed("ax_button")
	var pressed := press and not glasses_was
	glasses_was = press
	if examining != "":
		examine_open_s += dt
		_play_clip(dt)
		clip_check_s += dt
		if clip.is_empty() and clip_check_s >= 0.5:
			# The pack may arrive while the still is up: the video then
			# takes its place without closing the close-up.
			clip_check_s = 0.0
			var c := cached_clip(examining)
			if not c.is_empty():
				for e in data.examine:
					if e.id == examining:
						_start_clip(e, c)
		if pressed or examine_open_s >= float(
				data.examine_rule.close_after_s):
			close_examine()
		return
	var hv := _head()
	var head: Vector3 = hv[0]
	var fwd: Vector3 = hv[1]
	if world == "room" and not glasses_on:
		var g: Dictionary = data.glasses
		var gp: Array = g.pos
		var to := Vector3(gp[0], gp[1], gp[2]) - head
		var near := to.length() <= float(g.range_m) and PilotCore.gaze_on(
			fwd, to, float(g.cone_deg))
		examine_hold["Glasses"] = float(examine_hold.get("Glasses",
			0.0)) + dt if near else 0.0
		if pressed or examine_hold["Glasses"] >= float(g.hold_s):
			put_on_glasses()
		return
	for e in data.get("examine", []):
		if e.world != world or not things.has(e.id):
			continue
		var n: Node3D = things[e.id]
		if not n.visible:
			continue
		var to: Vector3 = _xf(n).origin - head
		var on := to.length() <= float(e.range_m) and PilotCore.gaze_on(
			fwd, to, float(data.examine_rule.cone_deg))
		if not on:
			examine_hold[e.id] = 0.0
			if examine_rest == e.id:
				examine_rest = ""
			continue
		if examine_rest == e.id:
			continue
		examine_hold[e.id] = float(examine_hold.get(e.id, 0.0)) + dt
		if examine_hold[e.id] >= float(data.examine_rule.hold_s):
			open_examine(e)
			return


func put_on_glasses() -> void:
	glasses_on = true
	things["Glasses"].visible = false
	line.text = "Очки."
	narrate("objects", "Glasses")
	# The moment the glasses go on, the pack of examine videos is asked
	# for over the network (TABOO 0.019 item 1).
	_want_pack()


func _want_pack() -> void:
	# Through the tree's root: the scene may be built before it enters
	# the tree (tests), and the autoload is there either way.
	var tree := Engine.get_main_loop() as SceneTree
	var pf: Node = tree.root.get_node_or_null("PackFetch") if tree else null
	if pf and data.has("examine_pack"):
		pf.want(str(data.examine_pack))


## The examine video of a thing, when its pack is mounted: the atlas
## and its layout, or {} (the still from the APK stays).
static func load_clip(id: String) -> Dictionary:
	var base := "res://closeups/%s/" % id.to_lower()
	if not FileAccess.file_exists(base + "clip.json"):
		return {}
	var meta = JSON.parse_string(FileAccess.get_file_as_string(
		base + "clip.json"))
	var img := Image.new()
	if not meta is Dictionary or img.load_jpg_from_buffer(
			FileAccess.get_file_as_bytes(base + "atlas.jpg")) != OK:
		return {}
	var out: Dictionary = meta
	out["texture"] = ImageTexture.create_from_image(img)
	var voice := base + "voice_ru.ogg"
	if FileAccess.file_exists(voice):
		out["voice"] = AudioStreamOggVorbis.load_from_file(voice)
	return out


## Show the clip on the close-up from frame 0; the voice, if recorded,
## lies over it, and the narrator's line replaces the scribe's.
func _start_clip(e: Dictionary, c: Dictionary) -> void:
	clip = c
	clip_t = 0.0
	var m := close_up.material_override as StandardMaterial3D
	m.albedo_texture = c.texture
	m.uv1_scale = Vector3(1.0 / float(c.cols), 1.0 / float(c.rows), 1.0)
	m.uv1_offset = Vector3.ZERO
	close_up.visible = true
	narrate("objects", e.id, true)
	# The thing's own world goes silent under its video: only the
	# narrator is heard (operator, 2026-10-02).
	duck_db = -80.0
	synth.event_click()
	if c.has("voice"):
		narrator.stream = c.voice
		narrator.play()


func _play_clip(dt: float) -> void:
	if clip.is_empty():
		return
	clip_t += dt
	var f := int(clip_t * float(clip.fps)) % int(clip.frames)
	var m := close_up.material_override as StandardMaterial3D
	m.uv1_offset = Vector3(float(f % int(clip.cols)) / float(clip.cols),
		float(f / int(clip.cols)) / float(clip.rows), 0.0)


func open_examine(e: Dictionary) -> void:
	examining = e.id
	examine_open_s = 0.0
	var tex = load(e.image) if ResourceLoader.exists(e.image) else null
	(close_up.material_override as StandardMaterial3D).albedo_texture = tex
	close_up.visible = tex != null
	line.text = _ui(["examine", e.id, "line"], e.line_ru)
	# The narrator's bridge line is spoken at once, pack or no pack: the
	# episode is whole offline (TABOO 0.018 item 1; voice 4 of the audit).
	narrate("objects", e.id)
	claud("look:" + str(e.id))
	clip = {}
	var m := close_up.material_override as StandardMaterial3D
	m.uv1_scale = Vector3.ONE
	m.uv1_offset = Vector3.ZERO
	# The lens focusing: the sound of the close-up.
	synth.event_servo()
	if world == "lake":
		_want_pack()
	var c := cached_clip(e.id)
	if not c.is_empty():
		_start_clip(e, c)
	if not e.id in examined:
		examined.append(e.id)
	events.append("look:" + str(e.id))
	duck_db = -18.0
	if e.get("lure", false) and str(state.get("stage")) == "prilog":
		# Through the lens at the lure: that is "look closer", the
		# first step down the ladder of a thought (PassionCore).
		state = PassionCore.choose(state, "look", passion, {}, {})


## Speak a line of the narrator: its subtitle for seven seconds and its
## voice from the pack (res://narration/<key>.ogg) when recorded.  Each
## line once, unless `again` (the examine video repeats its own).  At
## the holy the line is empty: the narrator is silent (TABOO 0.020).
## The volumetric screen follows the beat: the floor's relief by the
## walls, the water's layers at the thermocline, oxygen by the bookmark;
## at the kayrak it goes dark with the console (TABOO 0.027), and above
## water it is not there at all.
func _volume() -> void:
	volume.visible = world == "lake"
	if not volume.visible:
		return
	var mode: String = {"walls": "floor", "thermocline": "layers",
		"tether_jerk": "layers", "bookmark": "oxygen", "lure": "floor",
		"price_rises": "floor", "choice_echo": "floor"}.get(beat_id, "")
	if mode != "":
		volume.set_mode(mode)
	volume.set_holy(beat_id == "khachkar")
	volume.update(t, _depth(), reduced)


## An on-screen line in the player's language (PilotCore.ui_text).
func _ui(path: Array, ru: String) -> String:
	return PilotCore.ui_text(i18n, path, lang, ru)


## Клауд, the operator's AI, says its line for this beat and event,
## once a run.  CompanionCore keeps it silent at the khachkar whatever
## the data say; its voice is a draft from a pack and plays only when
## the pack is there, the line is always written (TABOO 0.026 item 4).
func claud(event: String) -> void:
	var tag := beat_id + "/" + event
	if tag in said_by_claud:
		return
	var text := CompanionCore.line_for(beat_id, event, lang, companion)
	if text == "":
		return
	said_by_claud.append(tag)
	events.append("claud:" + tag)
	claud_line.text = text
	var x := CompanionCore.entry(companion, beat_id, event)
	var voice := CompanionCore.voice_path(companion, x, lang)
	if FileAccess.file_exists(voice):
		claud_voice.stream = AudioStreamOggVorbis.load_from_file(voice)
		claud_voice.play()


func narrate(group: String, key: String, again := false) -> void:
	var x: Dictionary = narration.get(group, {}).get(key, {})
	var text := PilotCore.narration_text(narration, i18n, group, key,
		lang)
	var tag := group + "." + key
	if text == "" or x.get("voice", true) == false:
		return
	if tag in narrated and not again:
		return
	if not tag in narrated:
		narrated.append(tag)
	narr.text = text
	narr_left = 7.0
	var voice := "res://narration/%s/%s.ogg" % [lang, key]
	if narrator and FileAccess.file_exists(voice):
		narrator.stream = AudioStreamOggVorbis.load_from_file(voice)
		narrator.play()


## The clip of a thing from the memory cache, or decoded from the pack
## and put in it.
func cached_clip(id: String) -> Dictionary:
	if clip_cache.has(id):
		clip_cache[id].idle = 0.0
		return clip_cache[id].clip
	var c := load_clip(id)
	if not c.is_empty():
		clip_cache[id] = {"clip": c, "idle": 0.0}
	return c


## Age the cached clips that are not on screen; drop the old ones.
func age_clips(dt: float) -> void:
	for id in clip_cache.keys():
		if id == examining:
			continue
		clip_cache[id].idle += dt
		if clip_cache[id].idle >= CLIP_KEEP_S:
			clip_cache.erase(id)


func close_examine() -> void:
	clip = {}
	if narrator and narrator.playing:
		narrator.stop()
	examine_rest = examining
	examining = ""
	close_up.visible = false
	line.text = ""


## The body finds the room's clues: hold one in view for its seconds
## and the line is written; each is found once.
func _clues(dt: float) -> void:
	var c_btn := Input.is_key_pressed(KEY_C) \
		or right_hand.is_button_pressed("by_button") \
		or left_hand.is_button_pressed("by_button")
	if c_btn and not crouch_was:
		crouched = not crouched
		rig.position.y = -float(data.crouch_m) if crouched else 0.0
	crouch_was = c_btn
	var hv := _head()
	var head: Vector3 = hv[0]
	var fwd: Vector3 = hv[1]
	for c in data.get("clues", []):
		if c.id in clues_found:
			continue
		if PilotCore.clue_seen(head, fwd, c):
			clue_hold[c.id] = float(clue_hold.get(c.id, 0.0)) + dt
			if clue_hold[c.id] >= float(c.hold_s):
				clues_found.append(c.id)
				events.append("clue:" + str(c.id))
				line.text = _ui(["clues", c.id, "line"], c.line_ru)
				narrate("objects", c.id)
				synth.event_click()
		else:
			clue_hold[c.id] = 0.0


## One detail: every primitive in order; a primitive with "if" plays
## only for the stage the player's thought has reached.
func _do(d: Dictionary) -> void:
	fired.append(d.id)
	for p in d["do"]:
		if p.has("if") and str(p["if"]) != str(state.get("stage")):
			continue
		var k := float(p.get("s", 0.0))
		var strong: bool = p.get("strong", false)
		if p.has("say"):
			screen.text = p.say
		elif p.has("line"):
			line.text = p.line
		elif p.has("lamp"):
			effects.append({"k": "lamp", "until": t + k,
				"v": float(p.lamp) * (1.5 if strong else 1.0),
				"room": p.get("room", false)})
		elif p.has("flicker"):
			effects.append({"k": "flicker", "from": t,
				"until": t + 0.3 * float(p.flicker),
				"room": p.get("room", false)})
		elif p.has("haptic"):
			var kind := str(p.haptic)
			if p.get("hand", "both") != "right":
				Haptics.pulse(left_hand, kind, reduced)
			if p.get("hand", "both") != "left":
				Haptics.pulse(right_hand, kind, reduced)
		elif p.has("sfx"):
			match str(p.sfx):
				"click":
					synth.event_click()
				"take":
					synth.event_take()
				"servo":
					synth.event_servo()
		elif p.has("duck"):
			effects.append({"k": "duck", "until": t + k,
				"v": float(p.duck)})
		elif p.has("fog"):
			effects.append({"k": "fog", "until": t + k,
				"v": float(p.fog) * (1.5 if strong else 1.0)})
		elif p.has("move") and things.has(p.move):
			var n: Node3D = things[p.move]
			var by: Array = p.by
			effects.append({"k": "move", "node": n, "from": t,
				"until": t + maxf(k, 0.01), "start": n.position,
				"by": Vector3(by[0], by[1], by[2])})
		elif p.has("show") and things.has(p.show):
			things[p.show].visible = true
		elif p.has("hide") and things.has(p.hide):
			things[p.hide].visible = false
		elif p.has("water"):
			effects.append({"k": "water", "until": t + k,
				"v": float(p.water)})


## Lay the live effects over the frame and drop the ended ones.  Light
## and murk go back to what _sync set; a moved thing stays moved.
func _effects() -> void:
	var keep := []
	var room_light: OmniLight3D = room.get_node("RoomLight")
	room_light.light_energy = 1.3
	duck_db = 0.0
	for e in effects:
		var done := t >= float(e.until)
		match e.k:
			"lamp":
				if not done:
					if e.room:
						room_light.light_energy = e.v
					else:
						lamp.light_energy = minf(lamp.light_energy, e.v) \
							if beat_id == "khachkar" else e.v
			"flicker":
				# Never to black and never above 3 flashes a second
				# (WCAG 2.3.1): half-periods of 0.2 s dip to 35 %.  With
				# reduced motion one smooth dip replaces the flashes.
				if not done:
					var f := 1.0
					var u := t - float(e.from)
					if reduced:
						f = 1.0 - 0.4 * sin(clampf(u / 0.9, 0.0, 1.0) * PI)
					elif int(u / 0.2) % 2 == 0:
						f = 0.35
					if e.room:
						room_light.light_energy *= f
					else:
						lamp.light_energy *= f
			"duck":
				if not done:
					duck_db = minf(duck_db, e.v)
			"fog":
				if not done and world == "lake":
					env.fog_density = e.v
			"move":
				var k := clampf((t - float(e.from))
					/ (float(e.until) - float(e.from)), 0.0, 1.0)
				e.node.position = e.start + e.by * k
			"water":
				if not done and beat_id == "water_rises":
					# A push of the water, in step with the ping.
					water.position.y += e.v * 0.5
		if not done:
			keep.append(e)
	effects = keep


## A yes/no from the player's settings file (user://settings.json).
static func _setting(key: String) -> bool:
	if not FileAccess.file_exists(Haptics.SETTINGS):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(Haptics.SETTINGS))
	return d is Dictionary and d.get(key, false) == true


func _jerk() -> void:
	if jerk_from < 0.0:
		return
	var k := clampf((t - jerk_from) / float(data.comfort.jerk_s), 0.0,
		1.0)
	if reduced or not world_turn:
		# No turn of the world unless the player asked for it in
		# user://settings.json ("world_turn": true): a turn the body did
		# not make is the strongest cause of sickness (comfort audit).
		# A dimming tells the jerk instead, with the haptics.
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
	# The breath on the rope is a squeeze of either trigger: the turn
	# away from the lure must not need the right hand (a11y audit).
	var trig := right_hand.is_button_pressed("trigger_click") \
		or left_hand.is_button_pressed("trigger_click") \
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
	events.append("stage:" + str(state.stage))
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
		# The ascent keeps the limit it names: 10 m/min at most
		# (DiveCore.MAX_ASCENT_M_PER_MIN); the rest of the way up is cut
		# by the dark of the room, not hurried (diver's audit 2026-10-03).
		d -= DiveCore.MAX_ASCENT_M_PER_MIN / 60.0 * minf(t - 820.0, 40.0)
	return d


## The dive's own synth: the sonar, the water, the layer's shimmer when
## the depth crosses 50 m.  At the khachkar the synth itself takes its
## machine layer down to -60 dB ("silence"), while room tone and breath
## stay at about -45 dBFS: the stream is not muted as a whole, or the
## sacred would get digital nothing instead of living quiet (TABOO 0.4
## rule 2, TABOO 0.38 item 4).
func _sound(dt: float) -> void:
	var sacred := beat_id == "khachkar"
	if beat_id in ["drop", "room_drains", "prior_last", "title"]:
		synth.update({"depth": 0.0, "thrust": 0.0, "shore_m": 2000.0},
			dt)
	else:
		var d := _depth()
		synth.update({"depth": d, "thrust": 0.0 if sacred else 0.15,
			"shore_m": 2000.0, "silence": sacred,
			"echo_delay": 2.0 * 2.0 / DiveCore.sound_speed(d)}, dt)
	# A glance or a close-up lowers the water, never below -18 dB, so
	# the room tone is still there under the narrator (TABOO 0.019 item 4).
	player.volume_db = minf(maxf(duck_db, -18.0), ins_duck)
	if playback:
		var frames := playback.get_frames_available()
		if frames > 0:
			var mono := synth.generate(frames)
			var buf := PackedVector2Array()
			buf.resize(frames)
			for i in frames:
				buf[i] = Vector2(mono[i], mono[i])
			playback.push_buffer(buf)
	_music()


## The music follows the beat's node; at the khachkar it goes down with
## the console, as every machine sound does (-60 dB, TABOO 0.4 rule 2),
## and it gives way to the narrator and to an insight.
func _music() -> void:
	music.set_cue(CosmosSynth.cue_for_beat(music.data, beat_id))
	music_player.volume_db = minf(minf(lerpf(-60.0, 0.0, console_level),
		duck_db), ins_duck * 0.5)
	# At -60 dB (the kayrak) the suite is not computed at all: zeros, its
	# clock held, so the Quest's CPU is not spent on the unheard.
	music.follow_volume(music_player.volume_db)
	if music_playback:
		var frames := music_playback.get_frames_available()
		if frames > 0:
			music_playback.push_buffer(music.generate(frames))


func _finish() -> void:
	finished = true
	SaveSlot.write_json(save_path, {"seen": true,
		"stage": state.get("stage", "prilog"),
		"episode2": echo.get("episode2", "prior_waits")})
	if not stay:
		ModuleLoader.go(ModuleLoader.HUB)


# --- Insights -----------------------------------------------------------------

## The look of a memory: an ink-brown veil darker at the edges, as an old
## page around a lit line, and the thing of the other epoch in its
## middle, warm, as under a lamp (1900 K, the class of human work,
## TABOO 0.38).  The skip icon hangs in the world, not on the eyes.
func _build_insight() -> void:
	veil = MeshInstance3D.new()
	var vq := QuadMesh.new()
	# At 0.5 m it covers the eye of a Quest (about 104 x 96 degrees) and
	# a 16:9 screen, so its dark rim lies at the edge of what is seen.
	vq.size = Vector2(1.6, 1.4)
	veil.mesh = vq
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.45))
	g.set_color(1, Color(1, 1, 1, 1.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	var vm := StandardMaterial3D.new()
	vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vm.no_depth_test = true
	vm.render_priority = 2
	vm.albedo_texture = gt
	vm.albedo_color = Color(0.20, 0.13, 0.07, 0.0)
	veil.material_override = vm
	veil.position = Vector3(0, 0, -0.5)
	veil.visible = false
	camera.add_child(veil)
	memory = MeshInstance3D.new()
	var mq := QuadMesh.new()
	mq.size = Vector2(0.36, 0.36)
	memory.mesh = mq
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.no_depth_test = true
	mm.render_priority = 3
	mm.albedo_color = Color(1.0, 0.80, 0.58, 0.0)
	memory.material_override = mm
	memory.position = Vector3(0, 0.07, -0.72)
	memory.visible = false
	camera.add_child(memory)
	skip_icon = Label3D.new()
	skip_icon.name = "SkipIcon"
	skip_icon.font_size = 40
	skip_icon.pixel_size = 0.0012
	skip_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	skip_icon.no_depth_test = true
	skip_icon.render_priority = 4
	skip_icon.modulate = Color(0.96, 0.86, 0.66)
	skip_icon.outline_size = 8
	skip_icon.visible = false
	add_child(skip_icon)


## One frame of the insights.  Returns true while one plays (the clock
## of the dive then stands).  Between them it keeps what the triggers
## read: the seconds a place is held in view, the seconds of stillness.
func _insight(dt: float) -> bool:
	if insights.is_empty():
		return false
	if not insight.is_empty():
		_play_insight(dt)
		return true
	since_insight += dt
	var hv := _head()
	var head: Vector3 = hv[0]
	var fwd: Vector3 = hv[1]
	var moved := head.distance_to(last_head) / maxf(dt, 0.001)
	var turned := rad_to_deg(fwd.angle_to(last_fwd)) / maxf(dt, 0.001)
	last_head = head
	last_fwd = fwd
	var calm: Dictionary = insights.still
	if moved <= float(calm.move_m_s) and turned <= float(calm.turn_deg_s):
		still_s += dt
	else:
		still_s = 0.0
	for x in insights.insights:
		if InsightCore.on_place(x, head, fwd):
			look_s[x.id] = float(look_s.get(x.id, 0.0)) + dt
		else:
			look_s[x.id] = 0.0
	var ctx := {"t": t, "world": world, "beat": beat_id, "depth": _depth(),
		"events": events, "stage": str(state.get("stage", "")),
		"still_s": still_s, "shown": shown, "since_last": since_insight,
		"look_s": look_s, "busy": examining != ""}
	var due := InsightCore.due(insights, ctx)
	if due.is_empty():
		return false
	open_insight(due)
	return true


## A memory begins: the veil and the thing fade in, the machine sinks to
## a murmur (room tone stays, never a digital zero), a soft click and a
## knot under both hands, the narrator's line, the skip icon low right.
func open_insight(x: Dictionary) -> void:
	insight = x
	insight_s = 0.0
	skip = {}
	skip_progress = 0.0
	shown.append(str(x.id))
	var img := str(x.get("image", ""))
	var tex = load(img) if img != "" and ResourceLoader.exists(img) \
		else null
	(memory.material_override as StandardMaterial3D).albedo_texture = tex
	memory.visible = tex != null
	veil.visible = true
	var hv := _head()
	skip_icon.position = InsightCore.icon_at(insights.skip, hv[0], hv[1])
	skip_icon.visible = true
	_skip_text()
	ins_duck = -24.0
	synth.event_click()
	Haptics.pulse(right_hand, "knot", reduced)
	Haptics.pulse(left_hand, "knot", reduced)
	narrate("insights", str(x.id))
	# The memory lasts at least as long as its voice, so a line is never
	# cut mid-word (the draft Russian voice runs near 9 s).
	insight_dur = float(insights.duration_s)
	if narrator and narrator.playing and narrator.stream:
		insight_dur = maxf(insight_dur,
			narrator.stream.get_length() + float(insights.fade_s))
	narr_left = maxf(narr_left, insight_dur)


func _play_insight(dt: float) -> void:
	insight_s += dt
	var fade := float(insights.fade_s)
	if reduced:
		fade = 0.3
	var dur := insight_dur
	var k := clampf(insight_s / fade, 0.0, 1.0) \
		* clampf((dur - insight_s) / fade, 0.0, 1.0)
	(veil.material_override as StandardMaterial3D).albedo_color.a = 0.82 * k
	(memory.material_override as StandardMaterial3D).albedo_color.a = k
	# The room tone and breath of the synth keep sounding under the memory.
	_sound(dt)
	var r := InsightCore.skip_step(skip, insights.skip, dt, _skip_input())
	skip = r.state
	skip_progress = r.progress
	_skip_text()
	if r.skip:
		skipped.append(str(insight.id))
		close_insight()
	elif insight_s >= dur:
		close_insight()


func close_insight() -> void:
	insight = {}
	since_insight = 0.0
	veil.visible = false
	memory.visible = false
	skip_icon.visible = false
	ins_duck = 0.0
	if narrator and narrator.playing:
		narrator.stop()
	narr.text = ""
	narr_left = 0.0


## The icon fills as the hands pull or the eyes rest: » » and a bar.
func _skip_text() -> void:
	var n := int(round(skip_progress * 6.0))
	skip_icon.text = "» »\n" + "▰".repeat(n) + "▱".repeat(6 - n)


## The hands and eyes asking to skip.  Either thumbstick pulled far, or
## both grips held; the head or a controller's ray on the icon.  On a
## screen, Tab held is the stick.  A test sets skip_override.
func _skip_input() -> Dictionary:
	if not skip_override.is_empty():
		return skip_override
	var stick := 1.0 if Input.is_key_pressed(KEY_TAB) else 0.0
	var grips := xr_active
	var cone := float(insights.skip.icon_cone_deg)
	var hv := _head()
	var on := PilotCore.gaze_on(hv[1], skip_icon.position - hv[0], cone)
	for h in [left_hand, right_hand]:
		if not xr_active:
			break
		var v: Vector2 = h.get_vector2("primary")
		if v == Vector2.ZERO:
			v = h.get_vector2("thumbstick")
		stick = maxf(stick, v.length())
		grips = grips and h.get_float("grip") >= 0.8
		var ray: Vector3 = -h.global_basis.z
		var from: Vector3 = h.global_position
		if PilotCore.gaze_on(ray, skip_icon.position - from,
				cone):
			on = true
	return {"stick": stick, "grips": grips, "icon": on}


# --- Instruments ---------------------------------------------------------------

## Two small screens low in the view, the robot's on the left, the
## surface's on the right, each with the name of the instrument above.
func _build_panels() -> void:
	for side in [["robot", -0.36], ["surface", 0.36]]:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.256, 0.16)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		m.render_priority = 3
		var img := ScreenFeed.blank()
		m.albedo_texture = ImageTexture.create_from_image(img)
		mi.material_override = m
		mi.position = Vector3(side[1], -0.29, -0.62)
		mi.visible = false
		camera.add_child(mi)
		var tag := _label(20, Vector3(side[1], -0.39, -0.62),
			ScreenFeed.INK)
		tag.width = 260
		tag.render_priority = 3
		panels[side[0]] = {"quad": mi, "tag": tag, "img": img, "item": {}}


## The telemetry the screens draw, each tick at 8 Hz: what instrument the
## beat shows in each place, and its picture from the scene as it is.
func _panels(dt: float) -> void:
	if apparatus.is_empty() or panels.is_empty():
		return
	track_s += dt
	if world == "lake" and track_s >= 1.0:
		track_s = 0.0
		var h: Vector3 = _head()[0]
		track.append(Vector2(h.x, h.z))
		if track.size() > 60:
			track.pop_front()
	var h0: Vector3 = _head()[0]
	field_log.append(ScreenFeed.field_nt(h0, _iron()))
	if field_log.size() > ScreenFeed.W:
		field_log.pop_front()
	panel_s += dt
	if panel_s < 0.125:
		return
	panel_s = 0.0
	var quiet := beat_id in ApparatusCore.HOLY_BEATS or not insight.is_empty()
	for where in panels:
		var p: Dictionary = panels[where]
		var it := {} if quiet or (where == "robot" and world != "lake") \
			else ApparatusCore.screen_of(apparatus, beat_id, where)
		p.item = it
		p.quad.visible = not it.is_empty()
		p.tag.visible = not it.is_empty()
		if it.is_empty():
			continue
		p.tag.text = str(it.name_ru)
		p.img.fill(ScreenFeed.BG)
		_draw_feed(p.img, it)
		(p.quad.material_override as StandardMaterial3D).albedo_texture \
			.update(p.img)


func _draw_feed(img: Image, it: Dictionary) -> void:
	var hv := _head()
	var head: Vector3 = hv[0]
	var fwd: Vector3 = hv[1]
	match str(it.video.kind):
		"sonar":
			ScreenFeed.sonar(img, _sonar_ranges(head, fwd), 12.0,
				fmod(t, 2.0) / 2.0)
		"curve":
			var id := str(it.id)
			if "sound_speed" in id:
				var v: Array = []
				for k in 60:
					var d := lerpf(38.0, _depth(), float(k) / 59.0)
					v.append(1480.0 if d < 50.0 else 1435.0)
				ScreenFeed.curve(img, v, 1420.0, 1500.0)
			elif "magnet" in id or "profiler" in id or "compass" in id:
				ScreenFeed.curve(img, field_log, 54950.0, 55450.0, 55150.0)
			else:
				var v2: Array = []
				for k in 60:
					v2.append(_depth() - 0.02 * float(59 - k))
				ScreenFeed.curve(img, v2, 0.0, 60.0)
		"spectrogram":
			var cols: Array = []
			for k in 96:
				var tt := t - float(95 - k) * 0.05
				var ping := 1.0 if fmod(tt, 2.0) < 0.06 else 0.0
				cols.append([0.35, 0.5 if world == "lake" else 0.1, 0.25,
					0.15, 0.1, 0.1, ping, ping * 0.7])
			ScreenFeed.spectrogram(img, cols)
		"range":
			ScreenFeed.range_bar(img, _ahead(head, fwd), 12.0)
		"camera":
			var r := _ahead(head, fwd)
			ScreenFeed.camera_overlay(img, Vector2(0.5, 0.5)
				if r < 3.0 else Vector2(-1, -1))
		"map":
			ScreenFeed.map(img, track, 8.0)
		_:
			ScreenFeed.range_bar(img, 0.0, 1.0)


## What the sonar's beams meet: the walls, the things on the silt; never
## the khachkar's shape as a picture to play with (it stays out).
func _sonar_points() -> Array:
	var pts: Array = []
	if world != "lake":
		return pts
	for n in lake.get_node("Walls").get_children():
		if n is Node3D and (n as Node3D).visible:
			pts.append(_xf(n).origin)
	for id in ["Amphora", "Drams", "EchoMug", "EchoBook", "EchoCoil"]:
		if things.has(id) and (things[id] as Node3D).is_visible_in_tree():
			pts.append(_xf(things[id]).origin)
	return pts


func _sonar_ranges(head: Vector3, fwd: Vector3) -> Array:
	var out: Array = []
	var pts := _sonar_points()
	var f := Vector3(fwd.x, 0.0, fwd.z).normalized()
	for i in 24:
		var a := deg_to_rad(-60.0 + 5.0 * float(i) + 2.5)
		var beam := f.rotated(Vector3.UP, -a)
		var r := 99.0
		for p in pts:
			var to: Vector3 = p - head
			to.y = 0.0
			if to.length() < 12.0 and rad_to_deg(beam.angle_to(to)) <= 4.0:
				r = minf(r, to.length())
		out.append(r)
	return out


func _ahead(head: Vector3, fwd: Vector3) -> float:
	var best := 99.0
	for p in _sonar_points():
		var to: Vector3 = p - head
		if PilotCore.gaze_on(fwd, to, 15.0):
			best = minf(best, to.length())
	return best


## Iron on the silt for the magnetometer: the rusted echoes; silver is
## not magnetic, so the drams leave the curve quiet (the inventory's
## point: the instrument does not flatter the lure).
func _iron() -> Array:
	var out: Array = []
	for id in ["EchoMug", "EchoCoil"]:
		if world == "lake" and things.has(id):
			out.append({"at": _xf(things[id]).origin, "moment": 1600.0})
	return out
