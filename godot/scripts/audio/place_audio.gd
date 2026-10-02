## The sound of a place in the scene: the plan of PlaceSound played
## from loops PlaceSynth renders once (track A of docs/HLD_APK_GRAPHICS_
## SOUND_2026-10-01.md).
##
## The bed is unplaced (room tone and one's own breath are everywhere);
## each craft is an AudioStreamPlayer3D at the thing that makes it, and
## the machine at its instrument (under water: the ROV one sits in, so
## unplaced).  The loops and their 16-bit samples are made off the
## frame: in the APK each voice is a task of the worker pool; in the Web
## build (no threads) one render is paced (PlaceSynth.Pace) and takes
## at most PACE_USEC_WEB of a frame, resuming on the next.  Nothing is
## rendered on the frame but a few hundred samples of live room tone.
##
## From the first frame a place is never at digital zero (TABOO 0.4
## rule 2, 0.35 rule 8): the hush, live room tone at the bed's level,
## plays until the bed is rendered and has faded in over it; then the
## hush goes, and the crafts and the machine fade in as each is done_loops.
## Only the machine layer moves after that: it goes to -60 dBFS when
## one stands by a holy thing, over CockpitCore.FADE_SECONDS, as the
## interface goes.
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
## The Web build's share of a frame for rendering loops (2 ms of the
## 13.9 ms of a 72 Hz frame; the bell's warm-up is apart from it).
const PACE_USEC_WEB := 2000
## The hush: live room tone at the bed's room level and pole (indoors
## the darker one), with a short buffer so its first frame is cheap.
const HUSH_BUFFER_SEC := 0.1
const HUSH_SEED := 0x4C554455

var plan: Dictionary = {}
## Voices whose 16-bit loops are done but are not players yet.
var done_loops: Dictionary = {}
var players: Dictionary = {}   # "bed" / "craft:<i>" / "machine" / ...
var gains: Dictionary = {}     # Each loop's own fade-in, 0..1.
## APK: the worker task of each voice still rendering, and the box it
## writes into (read by the main thread only once it is complete).
var tasks: Dictionary = {}
var boxes: Dictionary = {}
## Tasks of a place left before its loops were done: waited for once
## they complete, so leaving a place never waits for its synth.
var orphans: Array = []
## Web: the paced render and what it hands over ({"loops", "done"}).
## paced_render can be set before start() to take this path anywhere
## (tests and the revisor measure it headless).
var paced_render := OS.has_feature("web")
var pace: PlaceSynth.Pace
var paced_out: Dictionary = {}
var machine_open := 1.0
## Offset of the crafts' loudness in dB, set by the scene: the surf and
## the rain of a storm settle while the player waits it out (StormCalm).
var craft_db := 0.0
var listener := Vector3.ZERO
var hush_tone: AudioStreamGeneratorPlayback
var hush_state: Dictionary = {}
var hush_level := 0.0
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
	_start_hush()
	if paced_render:
		pace = PlaceSynth.Pace.new(PACE_USEC_WEB)
		paced_out = {"loops": {}, "done": false}
		# A coroutine: it waits for the first resume() in _process.
		_render_paced.call(pl, voices(pl), pace, paced_out)
	else:
		# The bed first: the pool starts tasks in the order they come.
		for v in voices(pl):
			var box := {}
			boxes[v[0]] = box
			# A static callable with its own deep copy of the plan: the
			# worker holds no reference to this node and shares no
			# container with the main thread (a CI run of
			# measure_locations crashed with a node notification called
			# from a worker thread).
			tasks[v[0]] = WorkerThreadPool.add_task(
				PlaceAudio._render_on_worker.bind(pl.duplicate(true),
					v.duplicate(), box))
	if pl.bell:
		_start_bell(now)


static func _render_on_worker(pl: Dictionary, v: Array,
		into: Dictionary) -> void:
	# Written only here and read by the main thread after the task is
	# complete (WorkerThreadPool.is_task_completed).
	into["bytes"] = PlaceSynth.pcm16(render_voice(pl, v))


## The Web build's render: every voice in order, a slice a frame.  A
## stopped pace makes every await return at once, so nothing of a place
## that was left stays suspended.
static func _render_paced(pl: Dictionary, list: Array,
		p: PlaceSynth.Pace, into: Dictionary) -> void:
	await p.go
	for v in list:
		if p.stopped:
			return
		var a: PackedFloat32Array
		match v[1]:
			"bed":
				a = await PlaceSynth.bed_co(pl.bed, p)
			"craft":
				a = await PlaceSynth.craft_co(pl.crafts[v[2]], p)
			_:
				a = await PlaceSynth.machine_co(pl.machine, p)
		if p.stopped:
			return
		var b: PackedByteArray = await PlaceSynth.pcm16_co(a, p)
		if p.stopped:
			return
		into.loops[v[0]] = b
	into.done = true


## The hush: live room tone from the first frame until the bed is in.
func _start_hush() -> void:
	hush_state = PlaceSynth.room_tone_state(HUSH_SEED)
	hush_level = 1.0
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = PlaceSound.RATE
	gen.buffer_length = HUSH_BUFFER_SEC
	var player := AudioStreamPlayer.new()
	player.stream = gen
	player.bus = BUS
	player.name = "Hush"
	add_child(player)
	players["hush"] = player
	if not _silent():
		player.play()
		hush_tone = player.get_stream_playback()


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
	for k in tasks:
		orphans.append(tasks[k])
	tasks = {}
	boxes = {}
	if pace != null:
		pace.stop()
		pace = null
	paced_out = {}
	if bell_clock != null and bell_clock.bells.task != -1:
		WorkerThreadPool.wait_for_task_completion(bell_clock.bells.task)
		bell_clock.bells.task = -1
	# Stopped first, so the audio server lets go of each playback before
	# its player is gone.
	for k in players:
		players[k].stop()
		players[k].queue_free()
	players = {}
	gains = {}
	done_loops = {}
	machine_open = 1.0
	hush_tone = null
	hush_level = 0.0
	bell_clock = null
	bell_tone = null


func _exit_tree() -> void:
	_join_all()


## A node freed without leaving the tree (free() on a detached node)
## gets no _exit_tree; its tasks are joined here so none outlives it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_join_all()


func _join_all() -> void:
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
	_collect()
	_build_next()
	for k in gains:
		gains[k] = move_toward(gains[k], 1.0, dt / FADE_IN_SEC)
	if players.has("hush"):
		# The hush gives way as the bed comes in, and then goes.
		hush_level = 1.0 - gains.get("bed", 0.0)
		if hush_level <= 0.0:
			players.hush.stop()
			players.hush.queue_free()
			players.erase("hush")
			hush_tone = null
	machine_open = CockpitCore.fade_step(machine_open,
		PlaceSound.machine_open(plan, listener), dt)
	for k in players:
		if k == "bell":
			continue
		var g: float = hush_level if k == "hush" else gains[k]
		var db := SILENT_DB if g <= 0.0 else linear_to_db(g)
		if k == "machine":
			db += PlaceSound.machine_gain_db(plan, machine_open)
		elif k.begins_with("craft:"):
			db += craft_db
		players[k].volume_db = maxf(SILENT_DB, db)
	_feed_hush()
	_feed_bell()


## Loops that are done move to done_loops: APK tasks that completed, or what
## the Web build's paced render handed over (after its slice of this
## frame).
func _collect() -> void:
	for k in tasks.keys():
		if WorkerThreadPool.is_task_completed(tasks[k]):
			WorkerThreadPool.wait_for_task_completion(tasks[k])
			done_loops[k] = boxes[k].bytes
			tasks.erase(k)
			boxes.erase(k)
	if pace != null:
		pace.resume()
		for k in paced_out.loops:
			done_loops[k] = paced_out.loops[k]
		paced_out.loops = {}
		if paced_out.done:
			pace = null


## One player a frame: the bed first, over the hush; the crafts and the
## machine once the hush is gone, so the place never has more players
## than its plan (PlaceSound.players).
func _build_next() -> void:
	for v in voices(plan):
		if players.has(v[0]) or not done_loops.has(v[0]):
			continue
		if v[1] != "bed" and players.has("hush"):
			return
		_build_player(v)
		return


func _build_player(v: Array) -> void:
	var stream := PlaceSynth.wav(done_loops[v[0]])
	done_loops.erase(v[0])
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
	gains[v[0]] = 0.0


func _feed_hush() -> void:
	if hush_tone == null:
		return
	var n := hush_tone.get_frames_available()
	if n > 0:
		hush_tone.push_buffer(PlaceSynth.room_tone(n,
			0.05 if plan.bed.dark else 0.09, plan.bed.room_db, hush_state))


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
