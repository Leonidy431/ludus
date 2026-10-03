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
##
## Once the player is down there (SILENT_DB or lower), the music cannot
## be heard, so it is not computed: set_silent(true) makes generate()
## hand back zeros and stop the clock of the picture, and the voices
## take up again where they were.  Phase F3 of docs/HLD_CHORUS24_FIXES_
## 2026-10-03.md: the pilot's synth time is measured, and the music at
## -60 dB was most of it for nothing.
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
## At this player volume and below (the khachkar's -60 dB) the music is
## not heard and is not computed; one decibel above it still is.
const SILENT_DB := -59.0

var data: Dictionary = {}
var cue_id := ""
var sample := 0
## The current and the wanted picture: numbers that morph.
var cur := {}
var want := {}
var _sin := PackedFloat32Array()
var _ph := PackedFloat32Array()
var _dph := PackedFloat32Array()
var _rng := 0
var _lp := [0.0, 0.0, 0.0, 0.0]
var _sparks: Array = []
var _next_spark := 0.0
## True while the music is below hearing: generate() gives zeros.
var silent := false


func _init(d: Dictionary = {}) -> void:
	data = d if not d.is_empty() else load_data()
	_sin.resize(TABLE)
	for i in TABLE:
		_sin[i] = sin(TAU * float(i) / TABLE)
	_ph.resize(VOICES)
	_dph.resize(1)
	_ph.fill(0.0)
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


## Stop computing the voices while the music cannot be heard, and start
## again where they stopped: the picture's clock does not run in the
## silence, so no spark and no morph is spent on nothing.
func set_silent(on: bool) -> void:
	silent = on


## The pilot's one call: silent when its player is at SILENT_DB or
## lower (the khachkar), sounding otherwise.
func follow_volume(volume_db: float) -> void:
	set_silent(volume_db <= SILENT_DB)


func generate(frames: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames)
	if cur.is_empty() or silent:
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
	var al := PackedFloat32Array()
	var ar := PackedFloat32Array()
	var a2 := PackedFloat32Array()
	for v in VOICES:
		var f := voice_hz(center, cl[v], tg[v], g)
		inc.append(f / MIX_RATE)
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
	var dg: float = cur.drone * 0.12 * (0.8 + 0.2 * sin(TAU * t / 31.0))
	var wind_g: float = cur.wind * 0.35 * (0.6 + 0.4 * sin(TAU * t / 23.0))
	var k1 := 1.0 - exp(-TAU * cur.wind_hz / MIX_RATE)
	var k0 := 1.0 - exp(-TAU * cur.wind_hz * 0.25 / MIX_RATE)
	_spark_due(t)
	# The loop below runs MIX_RATE times a second, so it is written for
	# GDScript's speed (phase F3 of docs/HLD_CHORUS24_FIXES_2026-10-03.md:
	# the pilot's two synths were 66 ms per second of sound against a
	# budget of 50).  The six voices are unrolled into locals, since an
	# array read costs more than the sum it feeds.  The octave partial
	# and the drone's harmonics read the table at a whole multiple of
	# their fundamental's phase, so they need no phase of their own; a
	# phase wraps by one subtraction, as an increment is below one.  The
	# xorshift of the wind is the same as _rand(), inlined.
	var sn := _sin
	var mask := TABLE - 1
	var tb := float(TABLE)
	var tb2 := 2.0 * tb
	var tb3 := 3.0 * tb
	var tb4 := 4.0 * tb
	var p0 := _ph[0]
	var p1 := _ph[1]
	var p2 := _ph[2]
	var p3 := _ph[3]
	var p4 := _ph[4]
	var p5 := _ph[5]
	var i0 := inc[0]
	var i1 := inc[1]
	var i2 := inc[2]
	var i3 := inc[3]
	var i4 := inc[4]
	var i5 := inc[5]
	var o0 := a2[0]
	var o1 := a2[1]
	var o2 := a2[2]
	var o3 := a2[3]
	var o4 := a2[4]
	var o5 := a2[5]
	var l0 := al[0]
	var l1 := al[1]
	var l2 := al[2]
	var l3 := al[3]
	var l4 := al[4]
	var l5 := al[5]
	var r0 := ar[0]
	var r1 := ar[1]
	var r2 := ar[2]
	var r3 := ar[3]
	var r4 := ar[4]
	var r5 := ar[5]
	var q := _dph[0]
	var qi := root / MIX_RATE
	var d1 := dg
	var d2 := 0.6 * dg
	var d3 := 0.35 * dg
	var d4 := 0.2 * dg
	var la: float = _lp[0]
	var lb: float = _lp[1]
	var ra: float = _lp[2]
	var rb: float = _lp[3]
	var x := _rng
	for i in n:
		p0 += i0
		if p0 >= 1.0:
			p0 -= 1.0
		p1 += i1
		if p1 >= 1.0:
			p1 -= 1.0
		p2 += i2
		if p2 >= 1.0:
			p2 -= 1.0
		p3 += i3
		if p3 >= 1.0:
			p3 -= 1.0
		p4 += i4
		if p4 >= 1.0:
			p4 -= 1.0
		p5 += i5
		if p5 >= 1.0:
			p5 -= 1.0
		var s0 := sn[int(p0 * tb)] + o0 * sn[int(p0 * tb2) & mask]
		var s1 := sn[int(p1 * tb)] + o1 * sn[int(p1 * tb2) & mask]
		var s2 := sn[int(p2 * tb)] + o2 * sn[int(p2 * tb2) & mask]
		var s3 := sn[int(p3 * tb)] + o3 * sn[int(p3 * tb2) & mask]
		var s4 := sn[int(p4 * tb)] + o4 * sn[int(p4 * tb2) & mask]
		var s5 := sn[int(p5 * tb)] + o5 * sn[int(p5 * tb2) & mask]
		var l := s0 * l0 + s1 * l1 + s2 * l2 + s3 * l3 + s4 * l4 + s5 * l5
		var r := s0 * r0 + s1 * r1 + s2 * r2 + s3 * r3 + s4 * r4 + s5 * r5
		q += qi
		if q >= 1.0:
			q -= 1.0
		var d := d1 * sn[int(q * tb)] + d2 * sn[int(q * tb2) & mask] \
			+ d3 * sn[int(q * tb3) & mask] + d4 * sn[int(q * tb4) & mask]
		# Wind: a band of noise (low pass minus a slower low pass), its
		# own draw per ear.
		x ^= (x << 13) & 0xffffffff
		x ^= x >> 17
		x ^= (x << 5) & 0xffffffff
		var nl := float(x) / 2147483648.0 - 1.0
		x ^= (x << 13) & 0xffffffff
		x ^= x >> 17
		x ^= (x << 5) & 0xffffffff
		var nr := float(x) / 2147483648.0 - 1.0
		la += (nl - la) * k1
		lb += (nl - lb) * k0
		ra += (nr - ra) * k1
		rb += (nr - rb) * k0
		out[at + i] = Vector2(l + d + (la - lb) * wind_g,
			r + d + (ra - rb) * wind_g) * GAIN
	sample += n
	_ph[0] = p0
	_ph[1] = p1
	_ph[2] = p2
	_ph[3] = p3
	_ph[4] = p4
	_ph[5] = p5
	_dph[0] = q
	_lp[0] = la
	_lp[1] = lb
	_lp[2] = ra
	_lp[3] = rb
	_rng = x
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
