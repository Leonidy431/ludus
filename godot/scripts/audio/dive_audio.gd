## The dive's sound in the scene: feeds DiveSynth into a generator,
## places quiet water sources in space and gives the controllers their
## haptic share of the response triad (CLAUDE.md TABOO 0.35 rule 17).
##
## dive.gd owns the visuals and controls; it only calls the hooks here:
## build(), update(), on_lamp_toggled(), on_taken().  None of them can
## ring the bell: the bell belongs to the clock (DiveSynth).
class_name DiveAudio
extends Node

const BUS := "LudusDive"
const BUFFER_SEC := 0.25
## Water movement near fish and flow lines: quiet, close, no music.
const WATER_DB := -20.0
const WATER_UNIT_M := 3.0
const WATER_MAX_M := 25.0
const WATER_LOOP_SEC := 4.0
## Haptics: the pulses (lamp, take, echo and the crossing of the
## thermocline, felt with the layer's scatter and its shimmering sheet)
## live in the shared table, Haptics.PULSES "dive_*" (TABOO 0.35 rule
## 17; DEF-008).

var synth := DiveSynth.new()
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var right_hand: XRController3D
var xr_active := false
## Reduced motion: no ambient pulses (echo), halved action pulses.
## Set by --reduced-motion or {"reduced_motion": true} in
## user://settings.json.
var reduced_motion := false
## A fixed local date for tests and renders; empty means the system
## clock of the device.
var fixed_now := {}
var sources: Array = []  # [AudioStreamPlayer3D, kind, index]
var pulses: Array = []   # Logged [kind, amplitude, duration] for tests.


func _ready() -> void:
	_read_reduced_motion()


func _read_reduced_motion() -> void:
	if "--reduced-motion" in OS.get_cmdline_user_args():
		reduced_motion = true
	var path := "user://settings.json"
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.get("reduced_motion", false):
			reduced_motion = true


## Create the dive bus at runtime (project.godot stays untouched): a
## hard limiter with a -1 dB ceiling is only a safety net; the levels
## of DiveSynth are set to stay below it on their own.
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


## Build the generator, the listener and the water sources.  camera is
## the XR camera: the listener rides on the head.
func build(camera: Camera3D, right: XRController3D, schools: Array,
		water_things: Array) -> void:
	ensure_bus()
	right_hand = right
	player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = DiveSynth.MIX_RATE
	gen.buffer_length = BUFFER_SEC
	player.stream = gen
	player.bus = BUS
	# A generator must be mixed by the engine, also on the web, where
	# players default to browser sample playback.
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	player.play()
	playback = player.get_stream_playback()
	var ear := AudioListener3D.new()
	camera.add_child(ear)
	ear.make_current()
	var loop := water_loop()
	for i in schools.size():
		_add_source(loop, "school", i)
	for i in water_things.size():
		_add_source(loop, "flow", i)
		sources[-1][0].position = Vector3(water_things[i].x,
			-water_things[i].depth, water_things[i].z)


func _add_source(loop: AudioStreamWAV, kind: String, index: int) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = loop
	p.bus = BUS
	p.volume_db = WATER_DB
	p.unit_size = WATER_UNIT_M
	p.max_distance = WATER_MAX_M
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(p)
	# Each source starts at its own place in the loop, so twenty
	# schools do not swish in unison; the offset is fixed, not random.
	p.play(fmod(index * 0.61803 * WATER_LOOP_SEC, WATER_LOOP_SEC))
	sources.append([p, kind, index])


## A four-second loop of moving water: band-passed noise whose centre
## sways on whole cycles of the loop, so the seam cannot be heard.
static func water_loop() -> AudioStreamWAV:
	var rate := int(DiveSynth.MIX_RATE)
	var n := int(WATER_LOOP_SEC * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var state := DiveCore._hash("dive:water-loop") | 1
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		state ^= (state << 13) & 0xFFFFFFFF
		state ^= state >> 17
		state ^= (state << 5) & 0xFFFFFFFF
		var w := float(state) / 2147483648.0 - 1.0
		var ph := TAU * i / n
		var f := 520.0 + 180.0 * sin(3.0 * ph) + 90.0 * sin(7.0 * ph + 1.0)
		var wq := TAU * f / rate
		var alpha := sin(wq) / (2.0 * 2.5)
		var a0 := 1.0 + alpha
		var y := (alpha * w - alpha * x2 + 2.0 * cos(wq) * y1
			- (1.0 - alpha) * y2) / a0
		x2 = x1
		x1 = w
		y2 = y1
		y1 = y
		var swell := 0.6 + 0.4 * sin(2.0 * ph) * sin(5.0 * ph + 0.5)
		data.encode_s16(i * 2, int(clampf(y * swell * 0.9, -1.0, 1.0)
			* 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


## The local date the bell and the tone of the week are computed from.
func local_now() -> Dictionary:
	if not fixed_now.is_empty():
		return fixed_now
	return Time.get_datetime_dict_from_system()


## Called every frame by dive.gd.  thrust is the largest stick input.
func update(tel: Dictionary, rov: Dictionary, inp: Dictionary,
		schools: Array, t: float, dt: float, xr: bool) -> void:
	xr_active = xr
	synth.set_now(local_now())
	var thrust := maxf(absf(inp.get("forward", 0.0)), maxf(absf(
		inp.get("strafe", 0.0)), absf(inp.get("vertical", 0.0))))
	# The deep silence of the last task (DiveCore.step_game): below
	# 100 m, lamp off, the ROV still.
	var still := Vector3(rov.vx, rov.vz, rov.vy).length() < 0.05
	var silence: bool = tel.depth > 100.0 and not rov.lamp and still
	var pings := synth.pending.size()
	var crossed := synth.crossings.size()
	synth.update({"depth": tel.depth, "thrust": thrust,
		"shore_m": tel.shore_distance, "silence": silence,
		"echo_delay": tel.echo_delay,
		"layer_echo": DiveCore.layer_echo(tel.depth, tel.floor)}, dt)
	if synth.crossings.size() > crossed:
		# Heard when the queued audio reaches the ear, felt then too.
		_pulse("dive_layer", _queued_sec())
	if synth.pending.size() > pings:
		# A ping has just gone out; the controller answers when its
		# echo is heard: the queued audio plus the echo delay.
		_pulse("dive_echo", tel.echo_delay + _queued_sec())
	for s in sources:
		if s[1] == "school":
			var p := DiveCore.fish_at(schools[s[2]], 0, t)
			s[0].position = Vector3(p.x, -p.depth, p.z)
	if playback:
		var frames := playback.get_frames_available()
		if frames > 0:
			var mono := synth.generate(frames)
			var buf := PackedVector2Array()
			buf.resize(frames)
			for i in frames:
				buf[i] = Vector2(mono[i], mono[i])
			playback.push_buffer(buf)


func _queued_sec() -> float:
	if playback == null:
		return 0.0
	var total := int(BUFFER_SEC * DiveSynth.MIX_RATE)
	return maxf(0.0, total - playback.get_frames_available()) \
		/ DiveSynth.MIX_RATE


## The lamp was switched: light (dive.gd), relay click, pulse.
func on_lamp_toggled(_on: bool) -> void:
	synth.event_click()
	_pulse("dive_lamp", 0.0)


## The manipulator reached out (dive.gd, RovBody.reach): servo whine.
func on_arm() -> void:
	synth.event_servo()


## A thing was handled.  Only things that go into a bag or back into
## the water get a knock and a pulse; what may only be looked at (the
## cross on the bulla, the site, the birds) gets neither: silence.
func on_taken(rule) -> void:
	if rule == null or not rule is String:
		return
	synth.event_take()
	_pulse("dive_take", 0.0)


## One pulse of the shared table; under reduced motion the echo is not
## felt and the rest are halved (Haptics.spec).
func _pulse(kind: String, delay: float) -> void:
	var felt := Haptics.pulse(right_hand if xr_active else null, kind,
		reduced_motion, delay)
	if not felt.is_empty():
		pulses.append([kind, felt[0], felt[1]])
