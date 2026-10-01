## The sound of the dive, sample by sample (HLD_FOLLOWUPS D5, HLD shlema
## P6).  There are no recordings: every layer is computed here, and
## nothing is random.  The noise is an integer xorshift seeded by a name,
## so a run sounds the same every time and a test can measure it.
##
## Layers (CLAUDE.md TABOO 0.35 rules 8-10, 19-20; TABOO 0.4 rules 2-3,
## 13; TABOO 0.38 point 4):
##   room    brown water rumble and surface hiss; the hiss comes from
##           the surface (wavelets, bubbles), so it thins with depth and
##           the room grows darker.  Below the thermocline it drops a
##           step: the layer is a boundary one can hear.
##   hum     the thrusters, following thrust.  Harmonics carry the low
##           fundamental to the small headset speakers (rule 13).
##   breath  one's own breathing near -45 dBFS, on the hesychast timings
##           of BREATH (ported from ludus-sacred-synth.js).
##   sonar   the ping and its echo after 2 * range / c, moved here
##           unchanged from dive.gd.
##   ison    wordless voices on the tonic of the week's tone, vowel "o",
##           heard very quietly from far away, only in deep silence.
##   bell    the благовестник of the shore monastery (kolokol model: five
##           partials, doublets) calling to Vespers at the hour the
##           Typikon sets; heard only at the surface.
## The ison and the bell never sound together, and nothing but the
## clock can start the bell.  Silence is room tone plus breath, never
## digital zero.
class_name DiveSynth
extends RefCounted

const MIX_RATE := 22050.0
const BLOCK := 64

## Jesus Prayer breathing, seconds: inhale, hold after inhale, exhale,
## hold after exhale.  Copied from ludus-sacred-synth.js BREATH, which
## copies hesychasm-meditation-module breathing_patterns.py.  Rule 20:
## this table must equal the module; tests/ludus-audio-parity.test.js
## compares it with the JS table.
const BREATH := {
	"basic": {"inhale": 4.0, "hold_in": 0.0, "exhale": 6.0, "hold_out": 0.0},
	"athonite": {"inhale": 5.0, "hold_in": 1.0, "exhale": 8.0,
		"hold_out": 1.0},
	"optina": {"inhale": 4.5, "hold_in": 0.0, "exhale": 5.5,
		"hold_out": 0.0},
	"sinaite": {"inhale": 6.0, "hold_in": 2.0, "exhale": 8.0,
		"hold_out": 0.0},
	"ignatius": {"inhale": 5.0, "hold_in": 0.5, "exhale": 6.0,
		"hold_out": 0.5},
}
## The player's breath follows the basic 4:6 pattern, as the breathing
## cue of ludus-sacred-synth.js does; the ison breathes the Athonite
## cycle, as its ison_glas_N cues do.
const PLAYER_BREATH := "basic"
const ISON_BREATH := "athonite"

## Vowel "o" formants (Hz, bandwidth, gain), Peterson and Barney, as
## in ludus-sacred-synth.js VOWELS.o.
const VOWEL_O := [[570.0, 140.0, 1.0], [840.0, 160.0, 0.55],
	[2410.0, 220.0, 0.18]]
const TABLE := 2048

## kolokol ch. 12: hum, prime, tierce (minor), quint, nominal as ratios
## to the prime, with the fixed detuning bound ("drift") of old Russian
## bells and relative decay (ludus-sacred-synth.js BELL_PARTIALS).
const BELL_PARTIALS := [
	{"name": "hum", "ratio": 0.5, "amp": 0.55, "decay": 1.0, "drift": 0.015},
	{"name": "prime", "ratio": 1.0, "amp": 0.6, "decay": 0.75, "drift": 0.0},
	{"name": "tierce", "ratio": 1.2, "amp": 0.45, "decay": 0.55,
		"drift": 0.006},
	{"name": "quint", "ratio": 1.5, "amp": 0.25, "decay": 0.4,
		"drift": 0.006},
	{"name": "nominal", "ratio": 2.0, "amp": 0.5, "decay": 0.22,
		"drift": 0.01},
]
## The largest bell of the ensemble (ENSEMBLE[0] in the JS synth).
const BLAGOVESTNIK := {"name": "blagovestnik", "prime": 130.81}

# Output levels, linear full scale.  They are the final mix: there is
# no master gain after them.  scripts/godot/loudness.py measures the
# result; docs/audit/2026-09-30/sound-loudness.md has the numbers.
const ROOM_LOW := 0.011        # Brown rumble, about -44 dBFS RMS.
const ROOM_HISS := 0.075       # Surface hiss at 0 m, fades with depth.
const HISS_DEPTH_M := 12.0     # E-folding depth of the surface hiss.
const HUM_MAX := 0.6           # Thrusters at full thrust.
const HUM_IDLE := 0.001        # Electronics at rest: -60 dBFS.
const BREATH_LEVEL := 0.052    # Calibrated to about -45 dBFS RMS.
const ISON_GAIN := 0.036       # Far voices: about -44 dBFS RMS.
const BELL_GAIN := 0.25        # Peak of a stroke 30 m from the shore.
const MACHINE_DUCKED := 0.001  # Machines at the sacred: -60 dB.
# The sonar keeps the levels it had in dive.gd: the ping 0.35 and the
# echo 0.12, played through a player at -6 dB.
const PING_EVERY := 4.0
const PING_HZ := 2400.0
const PING_GAIN := 0.35
const ECHO_GAIN := 0.12
const SONAR_PLAYER := 0.501187  # db_to_linear(-6.0)
## The thermocline heard (HLD_DIVE_BIOMES_BUBBLES): the layer's
## temperature microstructure scatters sound, so an echo sounder sees it
## as a band.  Crossing it, the ROV's own sonar hears a short diffuse
## scatter around its ping frequency (not a pitch glide: the frequency
## does not change across a layer, only the wavelength does).  Above
## the layer, over a deeper floor, each ping also gets a faint answer
## from the layer itself (DiveCore.layer_echo).
const SHIMMER_SEC := 0.6
const SHIMMER_GAIN := 0.15
## One-pole low-pass of the scatter noise before it is carried on the
## ping frequency: about 280 Hz, so the band is 2400 +- 280 Hz.
const SHIMMER_LP := 0.08
const SHIMMER_DECAY := 0.18
const LAYER_ECHO_GAIN := 0.04

## The ison enters after the stillness has lasted this long, and the
## bell is heard only this close to the surface.
const ISON_AFTER_SEC := 4.0
const ISON_IN_SEC := 6.0
const ISON_OUT_SEC := 3.0
const BELL_FADE_SEC := 1.5
const DUCK_SEC := 1.5
const SURFACE_M := 2.0
const SHORE_REF_M := 30.0

## Spectral references of the audio pass (docs/HLD_AUDIO_299_2026-09-30,
## scripts/raw_assets/audio_pass.py): per sound slot, medians measured
## from sounds of the 99 repos.  TABOO 0.35 rule 8: a reference, never a
## sample; the file holds numbers only.  A cue takes a median only where
## one is published (at least three single blows); otherwise it keeps its
## own constant, so a thin slot never bends the sound.
const REFERENCES_PATH := "res://data/audio-references.json"
const REFERENCE_MIN_BLOWS := 3
## event_take is the knock of a find at the lens (slot lake.splash); its
## own decay is exp(-age / TAKE_TAU), a T60 of 0.207 s.
const TAKE_SLOT := "lake.splash"
const TAKE_TAU := 0.03

# Which layers are mixed; tests switch single layers on to measure them.
var layers := {"room": true, "hum": true, "breath": true, "sonar": true,
	"ison": true, "bell": true, "events": true}

# The scene as the last update() saw it.
var depth := 1.5
var thrust := 0.0
var shore_m := 30.0
var silence := false
var now := {}
var tonic := 0.0

# Running state.
var sample := 0
var noise_state := 0
var brown := 0.0
var room_lp := 0.0
var hiss_lp := 0.0
var hum_phase := 0.0
var hum_level := 0.0
var bp := [0.0, 0.0, 0.0, 0.0]
var ping_clock := 0.0
var pending: Array = []
var events: Array = []
var silent_for := 0.0
var ison_level := 0.0
var ison_target := 0.0
var ison_lp := 0.0
var ison_phase := [0.0, 0.0, 0.0, 0.0]
var ison_table := PackedFloat32Array()
var okt_table := PackedFloat32Array()
var ison_for := 0.0
var bell_level := 0.0
var bell_target := 0.0
var bell_spec := {}
var strokes: Array = []
var bell_struck := {}
var machine := 1.0
## Samples in which the ison and the bell were both audible: must stay 0.
var overlap_samples := 0
## Every stroke ever started, with the reason the clock gave for it.
var bell_log: Array = []
## Set by generate() when an echo starts; DiveAudio reads and clears it.
var echo_started := false
## Every thermocline crossing heard, "down" or "up", in order.
var crossings: Array = []
var prev_depth := -1.0
var shimmer_lp := 0.0
## The slot medians read at start, and the decay the take cue uses.
var references := {}
var take_tau := TAKE_TAU


func _init() -> void:
	noise_state = DiveCore._hash("dive:water") | 1
	bell_spec = make_bell_spec()
	use_references(load_references())


## The "slots" table of the references file, or {} if it is missing or
## malformed (the synth then keeps every constant of its own).
static func load_references(path := REFERENCES_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or not data.has("slots") \
			or typeof(data.slots) != TYPE_DICTIONARY:
		return {}
	return data.slots


## The published T60 median of a slot in seconds, or -1.0 when fewer
## than REFERENCE_MIN_BLOWS single blows stand behind it.
static func reference_t60(refs: Dictionary, slot: String) -> float:
	var s: Dictionary = refs.get(slot, {})
	var v: Variant = s.get("t60_median_s")
	if v == null or int(s.get("t60_n", 0)) < REFERENCE_MIN_BLOWS:
		return -1.0
	return float(v)


## Let the cues follow the references: T60 = tau * ln(1000).
func use_references(refs: Dictionary) -> void:
	references = refs
	var t60 := reference_t60(refs, TAKE_SLOT)
	take_tau = t60 / log(1000.0) if t60 > 0.0 else TAKE_TAU


# --- Pure helpers -----------------------------------------------------------

static func breath_cycle(p: Dictionary) -> float:
	return p.inhale + p.hold_in + p.exhale + p.hold_out


static func _smooth(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


## The breath envelope of ludus-sacred-synth.js breathEnvelope(): the
## voice thins to a floor on the inhale, swells through the hold and
## relaxes over the long exhale; periodic, so loops have no seam.
static func breath_envelope(p: Dictionary, t: float, low: float) -> float:
	var cycle := breath_cycle(p)
	var end := 0.55 if p.hold_out > 0.0 else low
	var q := fposmod(t, cycle)
	if q < p.inhale:
		return low + (1.0 - low) * _smooth(q / p.inhale)
	q -= p.inhale
	if q < p.hold_in:
		return 1.0
	q -= p.hold_in
	if q < p.exhale:
		return 1.0 - (1.0 - end) * _smooth(q / p.exhale)
	q -= p.exhale
	return end - (end - low) * _smooth(q / p.hold_out)


## The благовестник as ludus-sacred-synth.js bellSpec(0) builds it: the
## detuning and the doublet split are seeded by the bell's own name
## with the same mulberry32 and FNV-1a, so the numbers are equal.
static func make_bell_spec() -> Dictionary:
	var r := DiveCore.rng("bell:" + BLAGOVESTNIK.name)
	var partials := []
	for p in BELL_PARTIALS:
		var ratio: float = p.ratio * (1.0 + (r.call() * 2.0 - 1.0) * p.drift)
		var split: float = 0.12 + r.call() * 0.4
		partials.append({"name": p.name, "freq": BLAGOVESTNIK.prime * ratio,
			"split": split, "amp": p.amp, "decay": p.decay})
	var ring := minf(12.0, maxf(1.6, 9.0 * pow(130.81 / BLAGOVESTNIK.prime,
		0.8)))
	return {"prime": BLAGOVESTNIK.prime, "ring": ring, "partials": partials}


## The modes of one stroke (ludus-sacred-synth.js strokeClip): a harder
## strike excites the upper partials more; hum and prime are doublets.
static func stroke_modes(spec: Dictionary, velocity: float) -> Array:
	var v := maxf(0.1, roundf(velocity * 10.0) / 10.0)
	var gain := velocity / v
	var modes := []
	var total := 0.0
	for k in spec.partials.size():
		var p: Dictionary = spec.partials[k]
		var level: float = p.amp * pow(v, 1.0 + 0.35 * k) * gain
		var t60: float = spec.ring * p.decay
		if k < 2:
			modes.append([p.freq - p.split / 2.0, level / 2.0, t60])
			modes.append([p.freq + p.split / 2.0, level / 2.0, t60])
		else:
			modes.append([p.freq, level, t60])
		total += level
	# Normalise by the sum of the mode amplitudes, an upper bound of
	# the peak, so a stroke never exceeds BELL_GAIN.
	for m in modes:
		m[1] /= total
	return modes


func _formant(freq: float) -> float:
	var g := 0.015
	for f in VOWEL_O:
		var x: float = (freq - f[0]) / (f[1] / 2.0)
		g += f[2] / (1.0 + x * x)
	return g


## One period of a band-limited saw weighted by the "o" formants
## (ludus-sacred-synth.js voiceTable): cannot alias, costs one lookup
## per sample.
func _voice_table(f0: float, seed_text: String) -> PackedFloat32Array:
	var r := DiveCore.rng(seed_text)
	var table := PackedFloat32Array()
	table.resize(TABLE + 1)
	var top := minf(MIX_RATE * 0.42, 5200.0)
	var h := 1
	while h * f0 < top:
		var amp := _formant(h * f0) / h
		var phase: float = r.call() * TAU
		for i in TABLE:
			table[i] += amp * sin(TAU * h * i / TABLE + phase)
		h += 1
	var peak := 0.0
	for i in TABLE:
		peak = maxf(peak, absf(table[i]))
	for i in TABLE:
		table[i] /= maxf(peak, 1e-9)
	table[TABLE] = table[0]
	return table


# --- Control ----------------------------------------------------------------

## Set the date; the tone of the week and the bell follow from it.
func set_now(local: Dictionary) -> void:
	now = local
	var t := LudusTypikon.tonic_of(local)
	if t != tonic:
		tonic = t
		ison_table = PackedFloat32Array()


## The scene for the next frames: depth (m), thrust (0..1), distance
## from the shore (m), whether the deep silence holds, the echo delay.
func update(scene: Dictionary, dt: float) -> void:
	depth = scene.get("depth", depth)
	if prev_depth >= 0.0:
		var dir := DiveCore.thermo_crossing(prev_depth, depth)
		if dir != "":
			crossings.append(dir)
			events.append({"kind": "shimmer", "start": sample})
	prev_depth = depth
	thrust = clampf(scene.get("thrust", 0.0), 0.0, 1.0)
	shore_m = scene.get("shore_m", shore_m)
	silence = scene.get("silence", false)
	silent_for = silent_for + dt if silence else 0.0
	ping_clock += dt
	if ping_clock >= PING_EVERY:
		ping_clock = 0.0
		if not layers.sonar:
			pending.clear()
			_after_update()
			return
		pending.append([0.0, PING_HZ, PING_GAIN, false])
		var layer: float = scene.get("layer_echo", -1.0)
		if layer >= 0.0:
			pending.append([layer, PING_HZ, LAYER_ECHO_GAIN, false])
		# The echo returns from the floor below after 2 * range / c.
		pending.append([scene.get("echo_delay", 0.0), PING_HZ, ECHO_GAIN,
			true])
	_after_update()


func _after_update() -> void:
	_update_bell_clock()
	_arbitrate()


## The ison sounds only in the deep silence, on the week's tone, and
## never while the bell is heard; the bell is heard only at the surface
## and never while the ison sounds.  Whoever sounds first keeps it; if
## both would start together, the bell (the hour of the Typikon) wins.
func _arbitrate() -> void:
	var want_ison: bool = layers.ison and silence and tonic > 0.0 \
		and silent_for >= ISON_AFTER_SEC
	var surface := clampf((SURFACE_M + 0.5 - depth) / 1.0, 0.0, 1.0)
	var near := clampf(SHORE_REF_M / maxf(shore_m, 1.0), 0.0, 1.0)
	var want_bell: bool = layers.bell and not strokes.is_empty() \
		and surface > 0.0
	if ison_level > 0.0:
		want_bell = false
	elif bell_level > 0.0:
		want_ison = false
	elif want_bell:
		want_ison = false
	ison_target = 1.0 if want_ison else 0.0
	bell_target = surface * near if want_bell else 0.0


## The bell is started by the clock and by nothing else.  Strokes ring
## on the shore whether or not anyone hears them; the ROV only hears
## them at the surface.
func _update_bell_clock() -> void:
	if now.is_empty():
		return
	var call := LudusTypikon.bell_call(now)
	if not call.ring:
		return
	var day_key := "%04d-%02d-%02d" % [now.year, now.month, now.day]
	var r := DiveCore.rng("blagovest:" + day_key)
	for k in call.stroke_times.size():
		var v: float = 0.9 + r.call() * 0.08
		var key := "%s#%d" % [day_key, k]
		var at: float = call.stroke_times[k]
		if at <= call.since and at > call.since - 1.0 \
				and not bell_struck.has(key):
			bell_struck[key] = true
			_strike(v, call.reason)


func _strike(velocity: float, reason: String) -> void:
	var modes := []
	for m in stroke_modes(bell_spec, velocity):
		var d := pow(10.0, -3.0 / (m[2] * MIX_RATE))
		modes.append([TAU * m[0] / MIX_RATE, m[1], d, int(m[2] * MIX_RATE)])
	strokes.append({"start": sample, "modes": modes})
	bell_log.append({"sample": sample, "reason": reason})


## A lamp relay click: machine sound, short and dry.
func event_click() -> void:
	events.append({"kind": "click", "start": sample})


## The soft knock of a thing taken into the bag.
func event_take() -> void:
	events.append({"kind": "take", "start": sample})


## The manipulator's servos: a small machine whine while the arm moves
## out and back (CockpitCore.arm_phase), quiet while it holds.
func event_servo() -> void:
	events.append({"kind": "servo", "start": sample})


# --- Generation -------------------------------------------------------------

func _white() -> float:
	var x := noise_state
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	noise_state = x
	return float(x) / 2147483648.0 - 1.0


func _ramp(level: float, target: float, seconds: float) -> float:
	var step := BLOCK / (seconds * MIX_RATE)
	if level < target:
		return minf(target, level + step)
	return maxf(target, level - step)


## Render frames of mono sound; returns a PackedFloat32Array.
func generate(frames: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(frames)
	var done := 0
	while done < frames:
		var n := mini(BLOCK, frames - done)
		_block(out, done, n)
		done += n
	return out


func _block(out: PackedFloat32Array, at: int, n: int) -> void:
	var t0 := sample / MIX_RATE
	# Per-block parameters: they move over seconds, far slower than the
	# 3 ms block, so no step can be heard.
	var fc := maxf(250.0, 3500.0 * exp(-depth / 45.0))
	var under := depth > DiveCore.THERMOCLINE_M
	if under:
		fc *= 0.7
	var k_lp := 1.0 - exp(-TAU * fc / MIX_RATE)
	var room_gain := ROOM_LOW * (0.7 if under else 1.0)
	var hiss_gain := ROOM_HISS * exp(-depth / HISS_DEPTH_M)
	# The machines go quiet (-60 dB, TABOO 0.38 point 4) at the sacred
	# and in the deep silence itself: "only one's own breath is heard".
	var sacred := silence or ison_level > 0.0 or bell_level > 0.0 \
		or ison_target > 0.0 or bell_target > 0.0
	machine = _ramp(machine, MACHINE_DUCKED if sacred else 1.0, DUCK_SEC)
	var hum_target := (HUM_IDLE + HUM_MAX * thrust) * machine
	var hum_step := (hum_target - hum_level) / n * minf(1.0,
		BLOCK / (0.3 * MIX_RATE))
	var hum_f := 60.0 + 40.0 * thrust
	var hum_w := hum_f / MIX_RATE
	# Breath: band-passed noise, higher on the inhale, lower on the exhale.
	var bp_p: Dictionary = BREATH[PLAYER_BREATH]
	var bq := (t0 + n / MIX_RATE * 0.5)
	var inhaling: bool = fposmod(bq, breath_cycle(bp_p)) < bp_p.inhale
	var coef := _bandpass(1400.0 if inhaling else 780.0, 1.4)
	var b_env0 := breath_envelope(bp_p, t0, 0.0) * BREATH_LEVEL
	var b_env1 := breath_envelope(bp_p, t0 + n / MIX_RATE, 0.0) \
		* BREATH_LEVEL
	# Ison and bell gains ramp per block.
	var i0 := ison_level
	ison_level = _ramp(ison_level, ison_target,
		ISON_IN_SEC if ison_target > ison_level else ISON_OUT_SEC)
	var bl0 := bell_level
	bell_level = _ramp(bell_level, bell_target, BELL_FADE_SEC)
	if (i0 > 0.0 or ison_level > 0.0) and (bl0 > 0.0 or bell_level > 0.0):
		overlap_samples += n
	var ison_on: bool = layers.ison and (i0 > 0.0 or ison_level > 0.0)
	if ison_on and ison_table.is_empty() and tonic > 0.0:
		ison_table = _voice_table(tonic, "ison:%s" % tonic)
		okt_table = _voice_table(tonic / 2.0, "ison-okt:%s" % tonic)
	var ip: Dictionary = BREATH[ISON_BREATH]
	var ie0 := breath_envelope(ip, ison_for, 0.35) * i0 * ISON_GAIN
	var ie1 := breath_envelope(ip, ison_for + n / MIX_RATE, 0.35) \
		* ison_level * ISON_GAIN
	if ison_on:
		ison_for += n / MIX_RATE
	else:
		ison_for = 0.0
	var bell := PackedFloat32Array()
	bell.resize(n)
	if layers.bell and (bl0 > 0.0 or bell_level > 0.0):
		_bell_block(bell, n, bl0, bell_level)
	_drop_finished_strokes()
	var k_ison := 1.0 - exp(-TAU * 900.0 / MIX_RATE)
	# Locals, not member lookups, inside the per-sample loop: GDScript
	# pays for every dictionary and member access, and this loop runs
	# 22050 times a second on the headset.
	var use_room: bool = layers.room
	var use_hum: bool = layers.hum
	var use_breath: bool = layers.breath
	var use_sonar: bool = layers.sonar and not pending.is_empty()
	var use_events: bool = layers.events
	var use_ison: bool = ison_on and not ison_table.is_empty()
	var b0: float = coef[0]
	var b2: float = coef[2]
	var a1: float = coef[3]
	var a2: float = coef[4]
	var x1: float = bp[0]
	var x2: float = bp[1]
	var y1: float = bp[2]
	var y2: float = bp[3]
	var br := brown
	var rl := room_lp
	var hl := hum_level
	var hp := hum_phase
	var il := ison_lp
	var inc := tonic * TABLE / MIX_RATE
	var inc0 := inc * pow(2.0, -3.0 / 1200.0)
	var inc2 := inc * pow(2.0, 4.0 / 1200.0)
	var p0: float = ison_phase[0]
	var p1: float = ison_phase[1]
	var p2: float = ison_phase[2]
	var p3: float = ison_phase[3]
	var duck := machine * SONAR_PLAYER
	for i in n:
		var v := 0.0
		var w := _white()
		if use_room:
			br = br * 0.998 + w * 0.0632
			rl += k_lp * (br * room_gain + w * hiss_gain - rl)
			v += rl
		if use_hum:
			hl += hum_step
			if hl > 1e-6:
				hp += hum_w
				if hp >= 1.0:
					hp -= 1.0
				var a := TAU * hp
				v += hl * (sin(a) + sin(2.0 * a) / 2.0
					+ sin(3.0 * a) / 3.0 + sin(4.0 * a) / 4.0
					+ sin(5.0 * a) / 5.0 + sin(6.0 * a) / 6.0) / 2.45
		if use_breath:
			var y := b0 * w + b2 * x2 - a1 * y1 - a2 * y2
			x2 = x1
			x1 = w
			y2 = y1
			y1 = y
			v += y * lerpf(b_env0, b_env1, float(i) / n)
		if use_ison:
			p0 = fmod(p0 + inc0, TABLE)
			p1 = fmod(p1 + inc, TABLE)
			p2 = fmod(p2 + inc2, TABLE)
			p3 = fmod(p3 + inc * 0.5, TABLE)
			var s := (_lookup(ison_table, p0) + _lookup(ison_table, p1)
				+ _lookup(ison_table, p2)) * 0.3 \
				+ _lookup(okt_table, p3) * 0.15
			# Far away: the upper formants are lost on the way.
			il += k_ison * (s - il)
			v += il * lerpf(ie0, ie1, float(i) / n)
		v += bell[i]
		if use_sonar:
			v += _sonar_sample() * duck
		if use_events and not events.is_empty():
			v += _event_sample(w) * machine
		out[at + i] = v
		sample += 1
	brown = br
	room_lp = rl
	hum_level = hl
	hum_phase = hp
	ison_lp = il
	bp = [x1, x2, y1, y2]
	ison_phase = [p0, p1, p2, p3]


func _lookup(table: PackedFloat32Array, phase: float) -> float:
	var i := int(phase)
	var f := phase - i
	return table[i] + (table[i + 1] - table[i]) * f


## RBJ band-pass (constant 0 dB peak): [b0, b1, b2, a1, a2] for the
## direct form above (x[n], x[n-1], x[n-2], y[n-1], y[n-2]).
func _bandpass(freq: float, q: float) -> Array:
	var w := TAU * freq / MIX_RATE
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	return [alpha / a0, 0.0, -alpha / a0, -2.0 * cos(w) / a0,
		(1.0 - alpha) / a0]


func _sonar_sample() -> float:
	var v := 0.0
	for p in pending:
		var age: float = -p[0]
		if age >= 0.0 and age < 0.03:
			v += sin(TAU * p[1] * age) * p[2] * (1.0 - age / 0.03)
		if p[3] and age >= 0.0 and age < 1.0 / MIX_RATE:
			echo_started = true
		p[0] -= 1.0 / MIX_RATE
	if not pending.is_empty() and pending[0][0] < -0.05:
		pending = pending.filter(func(q): return q[0] > -0.05)
	return v


func _event_sample(w: float) -> float:
	var v := 0.0
	var keep := false
	for e in events:
		var age: float = (sample - e.start) / MIX_RATE
		if e.kind == "click" and age < 0.006:
			v += w * 0.03 * (1.0 - age / 0.006)
			keep = true
		elif e.kind == "servo" and age < CockpitCore.ARM_SECONDS:
			# Loud only while the phase changes: out, then back.
			var moving := age < 0.48 or age > 0.72
			if moving:
				var f := 320.0 + 90.0 * sin(TAU * 3.0 * age)
				v += (sin(TAU * f * age) + 0.3 * sin(TAU * 2.0 * f * age)) \
					* 0.012
			keep = true
		elif e.kind == "shimmer" and age < SHIMMER_SEC:
			# Narrow-band scatter around the ping: noise carried on the
			# ping frequency, a 20 ms swell and an exponential tail.
			var env := minf(1.0, age / 0.02) * exp(-age / SHIMMER_DECAY)
			shimmer_lp += SHIMMER_LP * (w - shimmer_lp)
			v += shimmer_lp * sin(TAU * PING_HZ * age) * SHIMMER_GAIN * env
			keep = true
		elif e.kind == "take" and age < 4.0 * take_tau:
			v += sin(TAU * 150.0 * age) * 0.05 * exp(-age / take_tau)
			keep = true
	if not keep:
		events.clear()
	return v


## Sum the ringing strokes into buf.  Each mode's phasor is placed from
## its absolute age at the start of the block, so a stroke keeps ringing
## correctly on the shore while it cannot be heard.
func _bell_block(buf: PackedFloat32Array, n: int, g0: float,
		g1: float) -> void:
	var attack := int(0.002 * MIX_RATE)
	for s in strokes:
		var age0: int = sample - s.start
		for m in s.modes:
			var life: int = m[3]
			if age0 >= life:
				continue
			var w: float = m[0]
			var env: float = m[1] * pow(m[2], age0)
			var re := cos(w * age0)
			var im := sin(w * age0)
			var c := cos(w)
			var sn := sin(w)
			var d: float = m[2]
			for i in n:
				var age := age0 + i
				var a := 1.0 if age >= attack else float(age) / attack
				buf[i] += im * env * a
				var nre := re * c - im * sn
				im = re * sn + im * c
				re = nre
				env *= d
	for i in n:
		buf[i] *= BELL_GAIN * lerpf(g0, g1, float(i) / n)


func _drop_finished_strokes() -> void:
	var ring := int(bell_spec.ring * MIX_RATE)
	strokes = strokes.filter(func(s): return sample - s.start < ring)
