## The sound of a place in the scene: the plan of PlaceSound played
## from loops PlaceSynth renders once (track A of docs/HLD_APK_GRAPHICS_
## SOUND_2026-10-01.md).
##
## The bed is unplaced (room tone and one's own breath are everywhere);
## each craft is an AudioStreamPlayer3D at the thing that makes it, and
## the machine at its instrument (under water: the ROV one sits in, so
## unplaced).  The loops are rendered on a worker thread in the APK and
## one voice a frame in the Web build (no threads), so no frame waits
## for the synth; they fade in when ready.  Only the machine layer
## moves after that: it goes to -60 dBFS when one stands by a holy
## thing, over CockpitCore.FADE_SECONDS, as the interface goes.
##
## In the courtyard the plan has "bell": the bells of the obitel ring
## through WitnessAudio's clock with its room and ison layers off: the
## Typikon (TypikonCore) is the only thing that strikes them.  The
## scene gives this node only the listener's position; nothing a player
## does reaches the bell, and nothing here is counted or saved.
class_name PlaceAudio
extends Node

const BUS := "LudusPlace"
const FADE_IN_SEC := 1.5
const SILENT_DB := -80.0
## Beyond this a craft is not heard at all (inverse distance at 1 m).
const MAX_DISTANCE_M := 30.0
const BELL_BUFFER_SEC := 0.3

var plan: Dictionary = {}
var pcm: Dictionary = {}       # "bed" / "craft:<i>" / "machine" -> loop
var players: Dictionary = {}   # same keys -> player
var task := -1
## What the worker renders into; handed over to pcm once it is done.
var box: Dictionary = {}
## Tasks of a place left before its loops were done: waited for once
## they complete, so leaving a place never waits for its synth.
var orphans: Array = []
var todo: Array = []
var level := 0.0               # The fade-in of the whole place, 0..1.
var machine_open := 1.0
var listener := Vector3.ZERO
## The courtyard's bell clock (WitnessAudio with only its bell layer).
var bell_clock: WitnessAudio
var bell_tone: AudioStreamGeneratorPlayback


## Create the place bus at runtime (project.godot stays untouched): a
## hard limiter at -1 dB as a safety net, as DiveAudio's.
static func ensure_bus() -> int:
	var idx := AudioServer.get_bus_index(BUS)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_send(idx, "Master")
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(idx, lim)
	return idx


## Every loop of a plan, in the order they are played: [key, kind, i].
static func voices(pl: Dictionary) -> Array:
	var out := [["bed", "bed", -1]]
	for i in pl.crafts.size():
		out.append(["craft:%d" % i, "craft", i])
	if pl.machine != null:
		out.append(["machine", "machine", -1])
	return out


static func render_voice(pl: Dictionary, v: Array) -> PackedFloat32Array:
	match v[1]:
		"bed":
			return PlaceSynth.render_bed(pl.bed)
		"craft":
			return PlaceSynth.render_craft(pl.crafts[v[2]])
		_:
			return PlaceSynth.render_machine(pl.machine)


## Every loop of a plan rendered on the calling thread (tests, tools).
static func render_all(pl: Dictionary) -> Dictionary:
	var out := {}
	for v in voices(pl):
		out[v[0]] = render_voice(pl, v)
	return out


## Start the place's sound.  now: the local moment for the bell clock
## ({} means the device's clock).
func start(pl: Dictionary, now := {}) -> void:
	stop()
	plan = pl
	ensure_bus()
	todo = voices(pl)
	if not OS.has_feature("web"):
		var mine := todo.duplicate()
		todo = []
		box = {}
		task = WorkerThreadPool.add_task(_render_on_worker.bind(pl, mine,
			box))
	if pl.bell:
		_start_bell(now)


static func _render_on_worker(pl: Dictionary, list: Array,
		into: Dictionary) -> void:
	# Written only here and read by the main thread after the task is
	# complete (WorkerThreadPool.is_task_completed).
	for v in list:
		into[v[0]] = render_voice(pl, v)


## The courtyard's bell clock: WitnessAudio with its room and ison
## layers off, so only the Typikon's cues sound through it.
static func make_bell_clock(now: Dictionary) -> WitnessAudio:
	var c := WitnessAudio.new()
	c.layers = {"room": false, "ison": false, "bell": true}
	c.set_now(now if not now.is_empty()
		else Time.get_datetime_dict_from_system())
	return c


func _start_bell(now: Dictionary) -> void:
	bell_clock = make_bell_clock(now)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = WitnessAudio.MIX_RATE
	gen.buffer_length = BELL_BUFFER_SEC
	var player := AudioStreamPlayer.new()
	player.stream = gen
	player.bus = BUS
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.name = "BellClock"
	add_child(player)
	players["bell"] = player
	if not _silent():
		player.play()
		bell_tone = player.get_stream_playback()


## Headless runs (tests, the revisor's measures) build every player but
## play none: the dummy driver never mixes, so a playback stopped there
## is never released, and nothing could be heard anyway.
static func _silent() -> bool:
	return DisplayServer.get_name() == "headless"


## Take the place's sound down (the scene changes place or leaves).
func stop() -> void:
	if task != -1:
		orphans.append(task)
		task = -1
	if bell_clock != null and bell_clock.bells.task != -1:
		WorkerThreadPool.wait_for_task_completion(bell_clock.bells.task)
		bell_clock.bells.task = -1
	# Stopped first, so the audio server lets go of each playback before
	# its player is gone.
	for k in players:
		players[k].stop()
		players[k].queue_free()
	players = {}
	pcm = {}
	todo = []
	level = 0.0
	machine_open = 1.0
	bell_clock = null
	bell_tone = null


func _exit_tree() -> void:
	stop()
	for t in orphans:
		WorkerThreadPool.wait_for_task_completion(t)
	orphans = []


## Where the listener stands, each frame.
func listen(pos: Vector3) -> void:
	listener = pos


func _process(dt: float) -> void:
	for t in orphans.duplicate():
		if WorkerThreadPool.is_task_completed(t):
			WorkerThreadPool.wait_for_task_completion(t)
			orphans.erase(t)
	if plan.is_empty():
		return
	if not todo.is_empty():
		var v: Array = todo.pop_front()
		pcm[v[0]] = render_voice(plan, v)
	elif task != -1 and WorkerThreadPool.is_task_completed(task):
		WorkerThreadPool.wait_for_task_completion(task)
		task = -1
		pcm = box
	if task == -1 and todo.is_empty() and not players.has("bed") \
			and pcm.has("bed"):
		_build_players()
	level = move_toward(level, 1.0, dt / FADE_IN_SEC)
	machine_open = CockpitCore.fade_step(machine_open,
		PlaceSound.machine_open(plan, listener), dt)
	var fade := SILENT_DB if level <= 0.0 else linear_to_db(level)
	for k in players:
		if k == "bell":
			continue
		var db := fade
		if k == "machine":
			db += PlaceSound.machine_gain_db(plan, machine_open)
		players[k].volume_db = maxf(SILENT_DB, db)
	_feed_bell()


func _build_players() -> void:
	for v in voices(plan):
		var stream := PlaceSynth.stream(pcm[v[0]])
		var at = null
		if v[1] == "craft":
			at = plan.crafts[v[2]].pos
		elif v[1] == "machine":
			at = plan.machine.pos
		var player: Node
		if at == null:
			player = AudioStreamPlayer.new()
		else:
			var p3 := AudioStreamPlayer3D.new()
			p3.position = at
			p3.unit_size = 1.0
			p3.max_distance = MAX_DISTANCE_M
			p3.attenuation_model = \
				AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			player = p3
		player.stream = stream
		player.bus = BUS
		player.volume_db = SILENT_DB
		player.name = v[0].replace(":", "_")
		add_child(player)
		if not _silent():
			player.play()
		players[v[0]] = player
	# The streams hold the 16-bit loops; the float renders go.
	pcm = {}
	box = {}
	level = 0.0


func _feed_bell() -> void:
	if bell_tone == null:
		return
	if OS.has_feature("web"):
		bell_clock.bells.warm(WitnessAudio.WARM_PER_FRAME_WEB)
	else:
		bell_clock.bells.warm_async()
	var n := bell_tone.get_frames_available()
	if n > 0:
		bell_tone.push_buffer(bell_clock.generate(n))
