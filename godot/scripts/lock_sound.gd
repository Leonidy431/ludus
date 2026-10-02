## The sound of the lock board (TABOO 0.024, phase Z4b): a relay's dry
## tick on a pick, the thunk of a sealed toggle on a swap, a slow low
## resonance when the matrix is calibrated.  Synthesised, no file; never
## a bell and never a chime of reward (TABOO 0.2 item 5).  A room tone
## stays under it, so the board is never in digital silence.
class_name LockSound
extends Node

const RATE := 22050.0

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var queue: PackedFloat32Array = PackedFloat32Array()
var phase := 0.0
var noise := 1375


func _ready() -> void:
	player = AudioStreamPlayer.new()
	var g := AudioStreamGenerator.new()
	g.mix_rate = RATE
	g.buffer_length = 0.25
	player.stream = g
	player.volume_db = -8.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback()


func _white() -> float:
	noise = (noise * 1103515245 + 12345) & 0x7FFFFFFF
	return float(noise) / float(0x7FFFFFFF) * 2.0 - 1.0


## A relay: 4 ms of noise through a quick decay, two contacts 6 ms apart.
static func relay() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(RATE * 0.03)
	out.resize(n)
	var seed := 7
	for i in n:
		seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
		var w := float(seed) / float(0x7FFFFFFF) * 2.0 - 1.0
		var t := float(i) / RATE
		var e := exp(-t * 900.0) + 0.6 * exp(-maxf(t - 0.006, 0.0) * 900.0) \
			* (1.0 if t >= 0.006 else 0.0)
		out[i] = w * e * 0.6
	return out


## A sealed toggle: a damped 180 Hz body under a click.
static func toggle() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(RATE * 0.12)
	out.resize(n)
	var c := relay()
	for i in n:
		var t := float(i) / RATE
		var body := sin(TAU * 180.0 * t) * exp(-t * 40.0) * 0.5
		out[i] = body + (c[i] if i < c.size() else 0.0)
	return out


## The matrix in resonance: two close low tones beating slowly, rising
## and fading over 1.6 s.
static func resonance() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(RATE * 1.6)
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.3, 1.0) * exp(-maxf(t - 0.3, 0.0) * 2.2)
		out[i] = (sin(TAU * 110.0 * t) + 0.7 * sin(TAU * 112.5 * t)
			+ 0.3 * sin(TAU * 220.0 * t)) * env * 0.25
	return out


func play(kind: String) -> void:
	var s: PackedFloat32Array
	match kind:
		"pick":
			s = relay()
		"swap":
			s = toggle()
		"open":
			s = resonance()
		_:
			return
	# Mixed into what is still queued, not cut: two quick picks overlap.
	if queue.size() < s.size():
		var old := queue
		queue = s.duplicate()
		for i in old.size():
			queue[i] += old[i]
	else:
		for i in s.size():
			queue[i] += s[i]


func _process(_dt: float) -> void:
	if playback == null:
		return
	var frames := playback.get_frames_available()
	if frames <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(frames)
	var take := mini(frames, queue.size())
	for i in frames:
		# Room tone: soft noise far below the events (never digital zero).
		var v := _white() * 0.004
		if i < take:
			v += queue[i]
		buf[i] = Vector2(v, v)
	playback.push_buffer(buf)
	if take > 0:
		queue = queue.slice(take)
