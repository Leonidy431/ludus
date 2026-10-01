## The voices of a place's sound plan (PlaceSound), rendered once into
## seamless loops at 44100 Hz: no recording, nothing random.
##
## Every loop is computed from an integer xorshift seeded by the place
## and the craft, so the same place sounds the same every time and a
## test can measure it.  Each loop is scaled to the exact RMS its plan
## asks for; the peak is checked by tests/test_place_sound.gd.
##
## What each voice takes from its reference slot (PlaceSound.ref_of):
##   impacts  the blow's partials are centred on the slot's centroid and
##            ring for its T60; where the slot has none, the material's
##            own fallback (a design choice, see FALLBACK_T60);
##   wheel    band noise at the centroid, turning at the craft's rpm;
##   strokes  noise strokes at the centroid, each as long as the slot's
##            median attack (a pen stroke, a press's creak);
##   lapping  waves of band noise at the centroid, each rising over the
##            median attack;
##   hearth   a slow roar rising over the median attack, and crackle;
##   buzz     band noise at the centroid beating at a bee's wing rate;
##   rain     dense drops at the centroid over a slow swell;
##   air      wind (swells over the median attack) or night insects
##            (chirps as long as the median attack), both at the slot's
##            centroid;
##   machine  a harmonic hum whose centroid is the slot's, and the clicks
##            of the console at its own centroid.
## The impact of a blow begins within a millisecond whatever the
## reference's attack: the median attack of a recording of a smithy
## measures the file's envelope, not the hammer's contact.
class_name PlaceSynth
extends RefCounted

const RATE := PlaceSound.RATE
## The ring of a blow where its reference slot has no T60 (a design
## choice): an anvil rings long, wood and stone are dull.
const FALLBACK_T60 := {"metal": 0.9, "wood": 0.25, "stone": 0.12}
## Partial ratios of a blow, by material (inharmonic for metal).
const PARTIALS := {"metal": [0.5, 1.0, 1.73, 2.61],
	"wood": [0.62, 1.0, 1.58], "stone": [0.7, 1.0, 1.41]}
## Equal-power crossfade at the seam of a noise loop.
const SEAM_SEC := 0.25
## Samples between two computed points of a slow envelope.
const ENV_STEP := 64


## The xorshift state lives in a one-element array so helpers share it.
static func _white(s: PackedInt64Array) -> float:
	var x := s[0]
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	s[0] = x
	return float(x & 0xFFFF) / 32768.0 - 1.0


static func _rng(seed: int) -> PackedInt64Array:
	var s := PackedInt64Array([seed & 0xFFFFFFFF])
	if s[0] == 0:
		s[0] = 1
	return s


## A deterministic number in [0, 1) from the generator.
static func _unit(s: PackedInt64Array) -> float:
	return (_white(s) + 1.0) / 2.0


## RBJ band-pass (constant 0 dB peak): [b0, b2, a1, a2] with b1 = 0.
static func _bp(fc: float, q: float) -> PackedFloat64Array:
	var w := TAU * clampf(fc, 20.0, RATE * 0.45) / RATE
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	return PackedFloat64Array([alpha / a0, -alpha / a0,
		-2.0 * cos(w) / a0, (1.0 - alpha) / a0])


## Band noise of n samples (no envelope).
static func _band_noise(n: int, fc: float, q: float,
		s: PackedInt64Array) -> PackedFloat32Array:
	var c := _bp(fc, q)
	var out := PackedFloat32Array()
	out.resize(n)
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		var x := _white(s)
		var y := c[0] * x + c[1] * x2 - c[2] * y1 - c[3] * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## A noise loop of n samples with no seam: n + seam samples are made
## and the tail is crossfaded over the head at equal power.
static func _noise_loop(n: int, fc: float, q: float,
		s: PackedInt64Array) -> PackedFloat32Array:
	var xf := mini(int(SEAM_SEC * RATE), n / 4)
	var a := _band_noise(n + xf, fc, q, s)
	for i in xf:
		var u := float(i) / xf
		a[i] = a[i] * sin(u * PI / 2.0) + a[n + i] * cos(u * PI / 2.0)
	a.resize(n)
	return a


## One-pole low-passed noise loop (room tone, breath), seamless.
static func _lp_loop(n: int, k: float, s: PackedInt64Array,
		poles := 1) -> PackedFloat32Array:
	var xf := mini(int(SEAM_SEC * RATE), n / 4)
	var a := PackedFloat32Array()
	a.resize(n + xf)
	var lp := 0.0
	var lp2 := 0.0
	# Warm the filter so the loop's head is not its start-up.
	for i in 2048:
		lp += k * (_white(s) - lp)
		lp2 += k * (lp - lp2)
	for i in n + xf:
		lp += k * (_white(s) - lp)
		lp2 += k * (lp - lp2)
		a[i] = lp2 if poles == 2 else lp
	for i in xf:
		var u := float(i) / xf
		a[i] = a[i] * sin(u * PI / 2.0) + a[n + i] * cos(u * PI / 2.0)
	a.resize(n)
	return a


## An envelope of events on a loop of n samples: each event rises over
## rise seconds (smoothstep) and decays with time constant fall; an
## event past the end wraps to the head, so the loop has no seam.
static func _events(n: int, at: Array, rise: float, fall: float,
		floor_level: float, gains := []) -> PackedFloat32Array:
	var env := PackedFloat32Array()
	env.resize(n)
	env.fill(floor_level)
	var r := maxi(1, int(rise * RATE))
	var span := mini(n, r + int(fall * 6.0 * RATE))
	for k in at.size():
		var g: float = gains[k] if k < gains.size() else 1.0
		var start := int(float(at[k]) * RATE)
		for j in span:
			var e: float
			if j < r:
				e = DiveSynth._smooth(float(j) / r)
			else:
				e = exp(-float(j - r) / (fall * RATE))
			env[(start + j) % n] += g * e
	return env


static func _times(count: int, loop: float, s: PackedInt64Array,
		jitter: float) -> Array:
	var out := []
	for k in count:
		out.append(fposmod(loop * k / count + (_unit(s) - 0.5) * jitter,
			loop))
	return out


## Scale a loop to the RMS level asked for (dBFS).
static func normalise(a: PackedFloat32Array, rms_db: float) -> void:
	var r := rms(a)
	if r <= 0.0:
		return
	var k := db_to_linear(rms_db) / r
	for i in a.size():
		a[i] *= k


static func rms(a: PackedFloat32Array) -> float:
	var acc := 0.0
	for v in a:
		acc += v * v
	return sqrt(acc / maxf(1.0, a.size()))


static func peak(a: PackedFloat32Array) -> float:
	var m := 0.0
	for v in a:
		m = maxf(m, absf(v))
	return m


static func dbfs(x: float) -> float:
	return linear_to_db(maxf(x, 1e-12))


# --- The bed -----------------------------------------------------------------

## Room tone, breath and the air of the place, each at its own level.
static func render_bed(bed: Dictionary) -> PackedFloat32Array:
	var n := int(round(float(bed.loop) * RATE))
	var s := _rng(int(bed.seed))
	# Indoors, in a cave and under water the room is darker.
	var room := _lp_loop(n, 0.05 if bed.dark else 0.09, s)
	normalise(room, bed.room_db)
	# One's own breath: soft air through the nose, in the pattern's
	# envelope (DiveSynth.breath_envelope, as RopeBreath), not placed.
	var breath := _lp_loop(n, 0.04, s, 2)
	var p: Dictionary = RopeCore.BREATH[bed.breath]
	# The envelope is smooth: computed every ENV_STEP samples and
	# interpolated between, which keeps the render short on the headset.
	var e0 := DiveSynth.breath_envelope(p, 0.0, 0.08)
	for i0 in range(0, n, ENV_STEP):
		var e1 := DiveSynth.breath_envelope(p, float(i0 + ENV_STEP) / RATE,
			0.08)
		for j in mini(ENV_STEP, n - i0):
			breath[i0 + j] *= lerpf(e0, e1, float(j) / ENV_STEP)
		e0 = e1
	normalise(breath, bed.breath_db)
	var out := room
	for i in n:
		out[i] += breath[i]
	if bed.air != "":
		var air := _air(n, bed, s)
		normalise(air, bed.air_db)
		for i in n:
			out[i] += air[i]
	return out


static func _air(n: int, bed: Dictionary, s: PackedInt64Array) \
		-> PackedFloat32Array:
	var ref: Dictionary = bed.air_ref
	var loop := float(n) / RATE
	if bed.air == "wind":
		# Two gusts a loop, each rising over the median attack.
		var a := _noise_loop(n, ref.centroid, 0.5, s)
		var env := _events(n, _times(2, loop, s, 1.0), ref.attack, 1.6, 0.35)
		for i in n:
			a[i] *= env[i]
		return a
	# Crickets at night: chirps of three pulses at the centroid, each
	# chirp as long as the median attack, about one a second.
	var a := PackedFloat32Array()
	a.resize(n)
	var w: float = TAU * float(ref.centroid) / RATE
	var chirps := maxi(1, int(round(loop)))
	var at := _times(chirps, loop, s, 0.3)
	var dur := int(ref.attack * RATE)
	for t0 in at:
		var start := int(float(t0) * RATE)
		for j in dur:
			var u := float(j) / dur
			var pulse := maxf(0.0, sin(u * 3.0 * PI))
			var e := pulse * sin(u * PI)
			a[(start + j) % n] += e * sin(w * j)
	return a


# --- Crafts ------------------------------------------------------------------

## One craft of the plan, as a loop at its level.
static func render_craft(c: Dictionary) -> PackedFloat32Array:
	var n := int(round(float(c.loop) * RATE))
	var s := _rng(int(c.seed))
	var a: PackedFloat32Array
	match c.voice:
		"impacts":
			a = _impacts(n, c, s)
		"wheel":
			a = _wheel(n, c, s)
		"strokes":
			a = _strokes(n, c, s)
		"lapping":
			a = _lapping(n, c, s)
		"hearth":
			a = _hearth(n, c, s)
		"buzz":
			a = _buzz(n, c, s)
		"rain":
			a = _rain(n, c, s)
		_:
			push_error("PlaceSynth: no voice " + str(c.voice))
			a = PackedFloat32Array()
			a.resize(n)
	normalise(a, c.rms_db)
	return a


## Blows of the craft's rhythm: the smith's two heavy blows and the
## light taps on the anvil between heats; the adze and the loom's
## beater at a working pace with a pause to look.
static func _rhythm(c: Dictionary) -> Array:
	match c.craft:
		"forge":
			return [[0.0, 1.0], [0.6, 1.0], [1.2, 0.9], [1.5, 0.35],
				[1.65, 0.3]]
		"loom":
			return [[0.0, 1.0], [1.2, 0.9], [2.4, 1.0], [3.6, 0.9]]
		_:
			return [[0.0, 1.0], [0.9, 0.95], [1.8, 1.0], [2.7, 0.9]]


static func _impacts(n: int, c: Dictionary, s: PackedInt64Array) \
		-> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	var ref: Dictionary = c.ref
	var mat: String = c.get("material", "wood")
	var t60: float = ref.t60 if ref.t60 > 0.0 else FALLBACK_T60[mat]
	var ratios: Array = PARTIALS[mat]
	var ring := mini(n, int(t60 * 1.2 * RATE))
	var click := int(0.004 * RATE)
	var cb := _bp(ref.centroid * 1.5, 0.8)
	for hit in _rhythm(c):
		var start := int(float(hit[0]) * RATE)
		var g: float = hit[1]
		# Each blow strays a little in pitch: no two are the same.
		var detune := 1.0 + (_unit(s) - 0.5) * 0.02
		for k in ratios.size():
			var f: float = ref.centroid * float(ratios[k]) * detune
			var w := TAU * f / RATE
			# Higher partials die faster, as in struck metal and wood.
			var tau := t60 / 6.91 / (1.0 + 0.6 * k)
			var amp := g / (1.0 + k * 0.5)
			for j in ring:
				var e := exp(-float(j) / (tau * RATE))
				if e < 1e-4:
					break
				a[(start + j) % n] += amp * e * sin(w * j)
		# The contact: a short band-limited click, under a millisecond
		# of rise.
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		for j in click * 4:
			var x := _white(s) * exp(-float(j) / click)
			var y := cb[0] * x + cb[1] * x2 - cb[2] * y1 - cb[3] * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			a[(start + j) % n] += 2.0 * g * y
	return a


static func _wheel(n: int, c: Dictionary, s: PackedInt64Array) \
		-> PackedFloat32Array:
	var ref: Dictionary = c.ref
	var a := _noise_loop(n, ref.centroid, 0.7, s)
	# Whole turns in a loop, so the rhythm has no seam.
	var loop := float(n) / RATE
	var turns := maxf(1.0, roundf(float(c.rpm) / 60.0 * loop))
	for i in n:
		var ph := TAU * turns * i / n
		a[i] *= 0.6 + 0.4 * (0.5 + 0.5 * sin(ph)) \
			+ 0.1 * sin(2.0 * ph + 1.0)
	return a


static func _strokes(n: int, c: Dictionary, s: PackedInt64Array) \
		-> PackedFloat32Array:
	var ref: Dictionary = c.ref
	var grain := _noise_loop(n, ref.centroid, 1.2, s)
	var a := PackedFloat32Array()
	a.resize(n)
	var dur := maxi(1, int(ref.attack * RATE))
	# Words of three to five strokes and a pause between them.
	var t := 0.0
	var loop := float(n) / RATE
	var env := PackedFloat32Array()
	env.resize(n)
	env.fill(0.02)
	while t < loop - ref.attack:
		var count := 3 + int(_unit(s) * 3.0)
		for k in count:
			var start := int(t * RATE)
			for j in dur:
				var u := float(j) / dur
				# The pen's fibre: a fast flutter inside each stroke.
				var fl := 0.7 + 0.3 * sin(TAU * 37.0 * j / RATE + k)
				env[(start + j) % n] += sin(u * PI) * fl
			t += ref.attack * (1.1 + 0.4 * _unit(s))
		t += 0.6 + 0.6 * _unit(s)
	for i in n:
		a[i] = grain[i] * env[i]
	return a


static func _lapping(n: int, c: Dictionary, s: PackedInt64Array) \
		-> PackedFloat32Array:
	var ref: Dictionary = c.ref
	var loop := float(n) / RATE
	var a := _noise_loop(n, ref.centroid, 0.8, s)
	# A wave about every 1.5 s, rising over the median attack and
	# running back over half a second.
	var count := maxi(1, int(round(loop / 1.5)))
	var gains := []
	for k in count:
		gains.append(0.6 + 0.4 * _unit(s))
	var env := _events(n, _times(count, loop, s, 0.4), ref.attack, 0.5,
		0.25, gains)
	for i in n:
		a[i] *= env[i]
	return a


static func _hearth(n: int, c: Dictionary, s: PackedInt64Array) \
		-> PackedFloat32Array:
	var ref: Dictionary = c.ref
	var loop := float(n) / RATE
	# The roar, a third of the centroid, swelling over the median attack.
	var a := _noise_loop(n, ref.centroid / 3.0, 0.5, s)
	var env := _events(n, [0.0], ref.attack, loop / 3.0, 0.5)
	for i in n:
		a[i] *= env[i] * 0.5
	# Crackle: short clicks at twice the centroid, about six a second.
	var cb := _bp(ref.centroid * 2.0, 1.0)
	var count := int(loop * 6.0)
	var dur := int(0.006 * RATE)
	for k in count:
		var start := int(_unit(s) * n)
		var g := 0.5 + 1.5 * _unit(s)
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		for j in dur * 3:
			var x := _white(s) * exp(-float(j) / dur)
			var y := cb[0] * x + cb[1] * x2 - cb[2] * y1 - cb[3] * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			a[(start + j) % n] += g * y
	return a


static func _buzz(n: int, c: Dictionary, s: PackedInt64Array) \
		-> PackedFloat32Array:
	var ref: Dictionary = c.ref
	var a := _noise_loop(n, ref.centroid, 1.0, s)
	# A honeybee's wing beats about 230 times a second; the hive's
	# swell rises over the median attack.
	var loop := float(n) / RATE
	var beats := roundf(230.0 * loop)
	var env := _events(n, _times(2, loop, s, 0.5), ref.attack, 0.8, 0.5)
	for i in n:
		a[i] *= env[i] * (0.6 + 0.4 * sin(TAU * beats * i / n))
	return a


static func _rain(n: int, c: Dictionary, s: PackedInt64Array) \
		-> PackedFloat32Array:
	var ref: Dictionary = c.ref
	var loop := float(n) / RATE
	var a := _noise_loop(n, ref.centroid, 0.6, s)
	var env := _events(n, [0.0], minf(ref.attack, loop / 2.0), loop / 2.0,
		0.6)
	for i in n:
		a[i] *= env[i]
	var cb := _bp(ref.centroid * 1.6, 2.0)
	var dur := int(0.003 * RATE)
	for k in int(loop * 40.0):
		var start := int(_unit(s) * n)
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		for j in dur * 3:
			var x := _white(s) * exp(-float(j) / dur)
			var y := cb[0] * x + cb[1] * x2 - cb[2] * y1 - cb[3] * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			a[(start + j) % n] += 0.8 * y
	return a


# --- The machine -------------------------------------------------------------

## The hum of an instrument: harmonics of f0 with 1/k amplitudes, where
## f0 is set so the hum's centroid is the reference's, and the clicks
## of the console at its own centroid.
static func render_machine(m: Dictionary) -> PackedFloat32Array:
	var n := int(round(float(m.loop) * RATE))
	var s := _rng(int(m.seed))
	var loop := float(n) / RATE
	var ks := [1, 2, 3, 4, 5, 6, 7, 8]
	var num := 0.0
	var den := 0.0
	for k in ks:
		num += float(k) / (k * k)
		den += 1.0 / (k * k)
	# Centroid of power: sum(k f0 / k^2) / sum(1 / k^2) = centroid.
	var f0: float = m.ref.centroid / (num / den)
	# A whole number of cycles in the loop.
	f0 = roundf(f0 * loop) / loop
	var a := _noise_loop(n, m.ref.centroid, 0.7, s)
	for i in n:
		a[i] *= 0.15
	for k in ks:
		var w: float = TAU * f0 * k / RATE
		for i in n:
			a[i] += sin(w * i) / k
	var cb := _bp(m.click.centroid, 1.5)
	var dur := maxi(1, int(m.click.attack * RATE))
	for t0 in _times(2, loop, s, 0.8):
		var start := int(float(t0) * RATE)
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		for j in dur * 4:
			var x := _white(s) * exp(-float(j) / dur)
			var y := cb[0] * x + cb[1] * x2 - cb[2] * y1 - cb[3] * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			a[(start + j) % n] += 3.0 * y
	normalise(a, m.rms_db)
	return a


## A loop as a 16-bit stream that loops forward over its whole length.
static func stream(pcm: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(pcm.size() * 2)
	for i in pcm.size():
		bytes.encode_s16(i * 2, int(round(clampf(pcm[i], -1.0, 1.0)
			* 32767.0)))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = pcm.size()
	return w
