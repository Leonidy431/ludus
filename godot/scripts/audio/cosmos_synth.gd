## The suite «Наука. Любовь. Познание.»: cosmic background music for
## the nine nodes of Entelechy (CLAUDE.md, TABOO 0, section
## «Энтелехия»; data godot/data/entelechy-99.json, written by
## scripts/story/entelechy.py).
##
## The operator asked for an analogue of Eduard Artemyev's cosmic music.
## The analogue is of method, not of notes: Artemyev drew sound on the
## ANS, Murzin's photo-optical synthesizer of pure sine tones in 72
## steps to the octave, and let clusters of them glide and bloom slowly.
## This synth does the same with six sine voices and quotes none of his
## themes.  Every layer carries a meaning (the digest: a sound is a
## language):
##   love      six voices start as a cluster on the 72-step grid and
##             glide geometrically toward just ratios and back over a
##             cycle: love as the gravity that draws them into accord;
##   knowledge the octave partial of each voice rises in turn across the
##             cycle: the spectrum unfolds as a thing is known;
##   science   sparse pure tones on a just grid, placed by a seeded
##             integer generator: measuring the dark, one point at a
##             time (on the node of signals each is answered by its echo);
##   drone     the root with harmonics 1-4, so the low end lives on the
##             headset's small speakers (TABOO 0.4 rule 13);
##   wind      band-filtered noise, decorrelated left and right.
## No formant voices (nothing imitates church singing, TABOO 0.2 point
## 5) and no inharmonic bell partials.  Nothing is random: the noise and
## the sparkles come from xorshift seeded by the cue's name.
##
## A new cue does not cut in: every number of the sound picture moves
## toward the new one over MORPH_S, so the voices glide from node to
## node, as Artemyev's clusters do.  The pilot fades the player, not
## the synth, at the khachkar (-60 dB with the console).
class_name CosmosSynth
extends RefCounted

const DATA := "res://data/entelechy-99.json"
const BUS := "Music"
const MIX_RATE := 16000.0
const BLOCK := 64
const VOICES := 6
const TABLE := 4096
const MORPH_S := 8.0
const MAX_SPARKS := 3
const SPARK_ATTACK_S := 0.35
const SPARK_TAU_S := 1.6
const SPARK_LEN_S := 5.0
const ECHO_DELAY_S := 1.2
## The whole picture's gain: a bed under the dive, not over it.
const GAIN := 0.22

var data: Dictionary = {}
var cue_id := ""
var sample := 0
## The current and the wanted picture: numbers that morph.
var cur := {}
var want := {}
var _sin := PackedFloat32Array()
var _ph := PackedFloat32Array()
var _ph2 := PackedFloat32Array()
var _dph := PackedFloat32Array()
var _rng := 0
var _lp := [0.0, 0.0, 0.0, 0.0]
var _sparks: Array = []
var _next_spark := 0.0


func _init(d: Dictionary = {}) -> void:
	data = d if not d.is_empty() else load_data()
	_sin.resize(TABLE)
	for i in TABLE:
		_sin[i] = sin(TAU * float(i) / TABLE)
	_ph.resize(VOICES)
	_ph2.resize(VOICES)
	_dph.resize(4)
	_ph.fill(0.0)
	_ph2.fill(0.0)
	_dph.fill(0.0)


## The music's own bus: a long, dark reverb (the space the ANS clusters
## lived in) and a limiter at -1 dBFS (TABOO 0.4 rule 13).  The reverb
## is the engine's own, so it costs no script time.
static func ensure_bus() -> int:
	var idx := AudioServer.get_bus_index(BUS)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_send(idx, "Master")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.9
	rev.damping = 0.6
	rev.spread = 1.0
	rev.wet = 0.35
	rev.dry = 0.8
	AudioServer.add_bus_effect(idx, rev)
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(idx, lim)
	return idx


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


## The node whose music plays at a beat of the pilot, or "" for silence
## (the khachkar) and for beats outside the suite.
## A voice's pitch: the cluster step on the 72-step octave at g = 0,
## the just ratio at g = 1, a geometric glide between (a glissando that
## sounds even, as pitch is heard in ratios).
static func voice_hz(center: float, step: float, ratio: float,
		g: float) -> float:
	var f_spread := center * pow(2.0, step / 72.0)
	return f_spread * pow(center * ratio / f_spread, g)


static func cue_for_beat(d: Dictionary, beat: String) -> String:
	for n in d.get("nodes", []):
		if beat in n.beats:
			return n.id
	return ""


static func cue_of(d: Dictionary, id: String) -> Dictionary:
	for n in d.get("nodes", []):
		if n.id == id:
			return n.cue
	return {}


static func _fnv(s: String) -> int:
	var h := 2166136261
	for b in s.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xffffffff
	return h if h != 0 else 1375


func _rand() -> float:
	var x := _rng
	x ^= (x << 13) & 0xffffffff
	x ^= x >> 17
	x ^= (x << 5) & 0xffffffff
	_rng = x & 0xffffffff
	return float(_rng) / 4294967296.0


static func _picture(c: Dictionary) -> Dictionary:
	var p := {}
	for k in ["root_hz", "center_hz", "cycle_s", "love", "unfold",
			"drone", "wind", "wind_hz", "sparkle_per_min", "echo"]:
		p[k] = float(c.get(k, 0.0))
	var fs := PackedFloat32Array()
	var ft := PackedFloat32Array()
	for v in VOICES:
		fs.append(float(c.cluster[v]))
		ft.append(float(c.target[v]))
	p.cluster = fs
	p.target = ft
	p.sparkle = c.get("sparkle", [2.0]).duplicate()
	return p


## Choose the node to sound.  The first cue is set at once; later ones
## morph.  "" keeps the last picture: the pilot's fade carries silence.
func set_cue(id: String) -> void:
	if id == "" or id == cue_id:
		return
	var c := cue_of(data, id)
	if c.is_empty():
		return
	cue_id = id
	_rng = _fnv("cosmos:" + id + ":1375")
	want = _picture(c)
	if cur.is_empty():
		cur = _picture(c)
	_next_spark = float(sample) / MIX_RATE + 1.5


func _morph(k: float) -> void:
	for key in want:
		if key == "sparkle":
			cur.sparkle = want.sparkle
		elif want[key] is PackedFloat32Array:
			var a: PackedFloat32Array = cur[key]
			var b: PackedFloat32Array = want[key]
			for i in a.size():
				a[i] += (b[i] - a[i]) * k
			cur[key] = a
		else:
			cur[key] = lerpf(cur[key], want[key], k)


## A pure tone placed on the just grid: science measuring the dark.
func _spark_due(t: float) -> void:
	var rate := float(cur.sparkle_per_min)
	if rate <= 0.0 or t < _next_spark:
		return
	var grid: Array = cur.sparkle
	var r := float(grid[int(_rand() * grid.size()) % grid.size()])
	var pan := _rand()
	_next_spark = t + 60.0 / rate * (0.5 + _rand())
	if _sparks.size() < MAX_SPARKS:
		_sparks.append({"f": cur.center_hz * r, "t0": t, "pan": pan,
			"amp": 1.0, "ph": 0.0})
		if cur.echo > 0.05 and _sparks.size() < MAX_SPARKS:
			_sparks.append({"f": cur.center_hz * r, "t0": t + ECHO_DELAY_S,
				"pan": 1.0 - pan, "amp": cur.echo, "ph": 0.0})


func generate(frames: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames)
	if cur.is_empty():
		return out
	var done := 0
	while done < frames:
		var n := mini(BLOCK, frames - done)
		_block(out, done, n)
		done += n
	return out


func _block(out: PackedVector2Array, at: int, n: int) -> void:
	_morph(minf(1.0, float(BLOCK) / (MORPH_S * MIX_RATE)))
	var t := float(sample) / MIX_RATE
	var cyc := maxf(8.0, cur.cycle_s)
	var phase := fmod(t / cyc, 1.0)
	# Love: 0 at the cycle's ends (the cluster), up to `love` in its
	# middle (the accord), smooth so the glide has no corner.
	var g: float = cur.love * (0.5 - 0.5 * cos(TAU * phase))
	var center: float = cur.center_hz
	var cl: PackedFloat32Array = cur.cluster
	var tg: PackedFloat32Array = cur.target
	var inc := PackedFloat32Array()
	var inc2 := PackedFloat32Array()
	var al := PackedFloat32Array()
	var ar := PackedFloat32Array()
	var a2 := PackedFloat32Array()
	for v in VOICES:
		var f := voice_hz(center, cl[v], tg[v], g)
		inc.append(f / MIX_RATE)
		inc2.append(2.0 * f / MIX_RATE)
		# Each voice breathes on its own slow swell.
		var sw := 0.65 + 0.35 * sin(TAU * (t / (cyc * 0.5) + v / 6.0))
		var amp := sw / VOICES
		var pan := float(v) / (VOICES - 1)
		al.append(amp * sqrt(1.0 - pan * 0.8))
		ar.append(amp * sqrt(0.2 + pan * 0.8))
		# Knowledge: the octave partial of voice v blooms in its own
		# part of the cycle.
		a2.append(cur.unfold * 0.4 * (0.5 - 0.5 * cos(TAU * (phase
			+ float(v) / VOICES))))
	var root: float = cur.root_hz
	var dinc := PackedFloat32Array([root / MIX_RATE, 2.0 * root / MIX_RATE,
		3.0 * root / MIX_RATE, 4.0 * root / MIX_RATE])
	var dw := PackedFloat32Array([1.0, 0.6, 0.35, 0.2])
	var dg: float = cur.drone * 0.12 * (0.8 + 0.2 * sin(TAU * t / 31.0))
	var wind_g: float = cur.wind * 0.35 * (0.6 + 0.4 * sin(TAU * t / 23.0))
	var k1 := 1.0 - exp(-TAU * cur.wind_hz / MIX_RATE)
	var k0 := 1.0 - exp(-TAU * cur.wind_hz * 0.25 / MIX_RATE)
	_spark_due(t)
	var tb := float(TABLE)
	for i in n:
		var l := 0.0
		var r := 0.0
		for v in VOICES:
			var p := _ph[v] + inc[v]
			p -= floorf(p)
			_ph[v] = p
			var p2 := _ph2[v] + inc2[v]
			p2 -= floorf(p2)
			_ph2[v] = p2
			var s := _sin[int(p * tb)] + a2[v] * _sin[int(p2 * tb)]
			l += s * al[v]
			r += s * ar[v]
		var d := 0.0
		for h in 4:
			var q := _dph[h] + dinc[h]
			q -= floorf(q)
			_dph[h] = q
			d += dw[h] * _sin[int(q * tb)]
		d *= dg
		# Wind: a band of noise (low pass minus a slower low pass), its
		# own generator per ear.
		var nl := _rand() * 2.0 - 1.0
		var nr := _rand() * 2.0 - 1.0
		_lp[0] += (nl - _lp[0]) * k1
		_lp[1] += (nl - _lp[1]) * k0
		_lp[2] += (nr - _lp[2]) * k1
		_lp[3] += (nr - _lp[3]) * k0
		l += d + (_lp[0] - _lp[1]) * wind_g
		r += d + (_lp[2] - _lp[3]) * wind_g
		out[at + i] = Vector2(l, r) * GAIN
		sample += 1
	_add_sparks(out, at, n)


func _add_sparks(out: PackedVector2Array, at: int, n: int) -> void:
	var keep: Array = []
	var tb := float(TABLE)
	for sp in _sparks:
		var t0 := float(sample - n) / MIX_RATE
		var age0: float = t0 - sp.t0
		if age0 > SPARK_LEN_S:
			continue
		keep.append(sp)
		var inc: float = sp.f / MIX_RATE
		var pl := sqrt(1.0 - sp.pan)
		var pr := sqrt(sp.pan)
		var ph: float = sp.ph
		for i in n:
			var age := age0 + float(i) / MIX_RATE
			if age < 0.0:
				continue
			var env := minf(1.0, age / SPARK_ATTACK_S) * exp(-maxf(0.0,
				age - SPARK_ATTACK_S) / SPARK_TAU_S)
			ph += inc
			ph -= floorf(ph)
			var s: float = _sin[int(ph * tb)] * env * sp.amp * 0.09 * GAIN
			out[at + i] += Vector2(s * pl, s * pr)
		sp.ph = ph
	_sparks = keep
