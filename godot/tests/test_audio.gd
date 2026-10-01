## Sound of the dive: the rules that can be proved without a headset.
## Called from run_tests.gd; every check goes through its _check().
##
## The tables below are also read by tests/ludus-audio-parity.test.js,
## which checks them against the JS modules (ludus-glas.js,
## ludus-liturgical-clock.js, ludus-sacred-synth.js).  So GDScript ==
## table here, and table == JS there.
extends RefCounted

## [local date, tone (0 = none), period, rank]: the dates of
## tests/ludus-glas.test.js first, then edges of the year.
const GLAS_FIXTURE := [
	["2026-04-19T10:00", 1, "ordinary", "great"],
	["2026-04-26T10:00", 2, "ordinary", "great"],
	["2024-06-30T10:00", 8, "ordinary", "great"],
	["2026-04-25T17:00", 1, "ordinary", "daily"],
	["2026-04-25T19:00", 2, "ordinary", "great"],
	["2026-04-10T10:00", 0, "great-friday", "daily"],
	["2026-04-12T10:00", 1, "pascha", "pascha"],
	["2026-04-13T10:00", 2, "bright-week", "daily"],
	["2026-04-14T10:00", 3, "bright-week", "daily"],
	["2026-04-15T10:00", 4, "bright-week", "daily"],
	["2026-04-16T10:00", 5, "bright-week", "daily"],
	["2026-04-17T10:00", 6, "bright-week", "daily"],
	["2026-04-18T10:00", 8, "bright-week", "daily"],
	["2026-03-01T10:00", 5, "great-lent", "great"],
	["2026-09-29T12:00", 8, "ordinary", "daily"],
	["2026-09-30T12:00", 8, "ordinary", "daily"],
	["2025-01-07T09:00", 3, "ordinary", "great"],
	["2025-04-19T10:00", 0, "great-saturday", "daily"],
	["2025-04-20T08:00", 1, "pascha", "pascha"],
	["2025-12-31T23:30", 4, "ordinary", "daily"],
	["2027-05-01T17:59", 0, "great-saturday", "daily"],
	["2027-05-01T18:00", 1, "pascha", "pascha"],
	["2024-05-05T10:00", 1, "pascha", "pascha"],
	["2024-03-10T10:00", 7, "ordinary", "great"],
]
## ludus-sacred-synth.js bellSpec(0).partials: [freq, split], ring 9.
const BELL_FIXTURE := [
	[66.33878177994762, 0.385765094012022],
	[130.81, 0.13267201751470564],
	[156.09376990498268, 0.17573562616482377],
	[196.2902026047223, 0.35835157928988337],
	[260.7335313011429, 0.3480362179502845],
]
const RATE := DiveSynth.MIX_RATE

var t: Object
var report: Array = []


static func at(text: String) -> Dictionary:
	var d := text.split("T")[0].split("-")
	var h := text.split("T")[1].split(":")
	return {"year": int(d[0]), "month": int(d[1]), "day": int(d[2]),
		"hour": int(h[0]), "minute": int(h[1]), "second": 0}


func _db(x: float) -> float:
	return 20.0 * log(maxf(x, 1e-12)) / log(10.0)


func _rms(a: PackedFloat32Array, from := 0, to := -1) -> float:
	if to < 0:
		to = a.size()
	var s := 0.0
	for i in range(from, to):
		s += a[i] * a[i]
	return sqrt(s / maxf(1.0, to - from))


## A local date moved on by some seconds (the dates are naive local).
static func later(base: Dictionary, seconds: float) -> Dictionary:
	var u := Time.get_unix_time_from_datetime_dict(base) + int(seconds)
	return Time.get_datetime_dict_from_unix_time(u)


## Run a scene; with a start date the clock moves with the sound.
func _run(s: DiveSynth, scene: Dictionary, seconds: float,
		fps := 60.0, start := {}) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var frames := int(RATE / fps)
	for k in int(seconds * fps):
		if not start.is_empty():
			s.set_now(later(start, k / fps))
		s.update(scene, 1.0 / fps)
		out.append_array(s.generate(frames))
	return out


func _only(layer: String) -> DiveSynth:
	var s := DiveSynth.new()
	for k in s.layers:
		s.layers[k] = k == layer
	return s


func run(tree: Object) -> void:
	t = tree
	_glas()
	_tables()
	_bell_rules()
	_exclusive()
	_silence()
	_sonar()
	_haptics()
	_determinism()
	_references()
	for line in report:
		print("  audio: ", line)


func _glas() -> void:
	for row in GLAS_FIXTURE:
		var now := at(row[0])
		t._check(LudusTypikon.glas_of(now) == row[1], "glas %s: %d vs %d"
			% [row[0], LudusTypikon.glas_of(now), row[1]])
		var info := LudusTypikon.describe(now)
		t._check(info.period == row[2] and info.rank == row[3],
			"describe %s: %s %s" % [row[0], info.period, info.rank])
		t._check(LudusTypikon.may_ring("благовест", now),
			"благовест allowed %s" % row[0])
	# The rules of the JS clock that the bell depends on.
	var fri := LudusTypikon.describe(at("2026-04-10T10:00"))
	t._check(not "трезвон" in LudusTypikon.allowed_orders(fri),
		"no трезвон on Great Friday")
	var lent := LudusTypikon.describe(at("2026-03-04T10:00"))
	t._check(LudusTypikon.allowed_orders(lent) == ["благовест", "двои"],
		"Lenten weekday: благовест and двои only")
	var bright := LudusTypikon.describe(at("2026-04-14T10:00"))
	t._check("трезвон" in LudusTypikon.allowed_orders(bright),
		"Bright Week has трезвон")


func _tables() -> void:
	var tonic := {"Pa": 146.83, "Di": 196.0, "Ga": 174.61, "Zo": 116.54,
		"Ni": 130.81}
	for g in range(1, 9):
		t._check(LudusTypikon.GLAS_TONIC[g] == tonic[
			LudusTypikon.GLASY[g].base], "tonic of tone %d" % g)
	var spec := DiveSynth.make_bell_spec()
	t._near(spec.ring, 9.0, "bell ring")
	for k in BELL_FIXTURE.size():
		t._near(spec.partials[k].freq, BELL_FIXTURE[k][0], "partial %d" % k)
		t._near(spec.partials[k].split, BELL_FIXTURE[k][1], "split %d" % k)
	t._check(DiveSynth.stroke_modes(spec, 0.9).size() == 7,
		"five partials, hum and prime as doublets")


## The bell rings by the clock, only; never by a task, a find or the UI.
func _bell_rules() -> void:
	# At noon nothing may ring, whatever the player does.
	var s := DiveSynth.new()
	s.set_now(at("2026-09-29T12:00"))
	var audio := DiveAudio.new()
	audio.synth = s
	audio.fixed_now = at("2026-09-29T12:00")
	var scene := {"depth": 1.0, "thrust": 0.0, "shore_m": 30.0,
		"silence": false, "echo_delay": 0.004}
	for k in 300:
		s.update(scene, 1.0 / 60.0)
		if k % 30 == 0:
			audio.on_lamp_toggled(k % 60 == 0)
			audio.on_taken("keep")
			audio.on_taken("hand-over")
			audio.on_taken(null)
			s.event_click()
			s.event_take()
		s.generate(int(RATE / 60.0))
	audio.free()
	t._check(s.bell_log.is_empty() and s.strokes.is_empty(),
		"no bell from lamp, finds or UI at noon")
	t._check(s.bell_level == 0.0, "bell silent at noon")
	# The only call site of _strike() is the clock.
	var src := FileAccess.get_file_as_string(
		"res://scripts/audio/dive_synth.gd")
	t._check(src.count("_strike(") == 2, "_strike() called only by clock")
	for path in ["res://scripts/dive.gd", "res://scripts/audio/dive_audio.gd"]:
		var other := FileAccess.get_file_as_string(path)
		t._check(not "_strike" in other and not "strokes" in other
			and not "bell_call" in other, "no bell hook in " + path)
	# Positive control: at 17:52 on an ordinary day the call rings and
	# is heard at the surface near the shore.
	var r := DiveSynth.new()
	var surf := _run(r, scene, 12.0, 60.0, at("2026-09-29T17:52"))
	t._check(r.bell_log.size() >= 2, "благовест at 17:52: %d strokes"
		% r.bell_log.size())
	t._check(r.bell_level > 0.0, "bell heard at the surface")
	report.append("bell at the surface, 30 m from shore: peak %.1f dBFS"
		% _db(_peak(surf)))
	# Underwater the same strokes ring on the shore but are not heard.
	var d := DiveSynth.new()
	var deep := scene.duplicate()
	deep.depth = 20.0
	_run(d, deep, 12.0, 60.0, at("2026-09-29T17:52"))
	t._check(d.bell_log.size() >= 2 and d.bell_level == 0.0,
		"bell rings on shore but is not heard at 20 m")
	# Lenten weekday: twelve strokes before Vespers, then quiet.
	var call := LudusTypikon.bell_call(at("2026-03-04T17:51"))
	t._check(call.ring and call.stroke_times.size() == 12,
		"Lenten weekday: 12 strokes before Vespers")
	var ord := LudusTypikon.bell_call(at("2026-09-29T17:51"))
	t._check(ord.stroke_times.size() == 96,
		"ordinary day: measured call, 8 min (bell-rules.json)")
	t._check(not LudusTypikon.bell_call(at("2026-09-29T18:00")).ring,
		"the call ends when Vespers begins")


func _peak(a: PackedFloat32Array) -> float:
	var p := 0.0
	for v in a:
		p = maxf(p, absf(v))
	return p


## The ison and the bell are never heard together.
func _exclusive() -> void:
	var s := DiveSynth.new()
	s.set_now(at("2026-09-29T17:40"))
	var deep := {"depth": 120.0, "thrust": 0.0, "shore_m": 400.0,
		"silence": true, "echo_delay": 0.05}
	_run(s, deep, 14.0, 30.0)
	t._check(s.ison_level > 0.5, "ison sounds in the deep silence: %.2f"
		% s.ison_level)
	# The bell's hour comes while the ison still sounds, and the ROV is
	# (impossibly fast) at the surface: the ison fades first.
	var bell_hour := at("2026-09-29T17:50")
	var up := {"depth": 1.0, "thrust": 0.0, "shore_m": 30.0,
		"silence": false, "echo_delay": 0.004}
	var heard_both := false
	for k in 12 * 30:
		s.set_now(later(bell_hour, k / 30.0))
		s.update(up, 1.0 / 30.0)
		s.generate(int(RATE / 30.0))
		heard_both = heard_both or (s.ison_level > 0.0 and s.bell_level > 0.0)
	t._check(s.bell_level > 0.0, "bell heard after the ison has faded")
	# At the surface with the bell ringing, silence is asked again: the
	# ison must wait.
	for k in 6 * 30:
		s.set_now(later(bell_hour, 12.0 + k / 30.0))
		s.update({"depth": 1.0, "thrust": 0.0, "shore_m": 30.0,
			"silence": true, "echo_delay": 0.004}, 1.0 / 30.0)
		s.generate(int(RATE / 30.0))
		heard_both = heard_both or (s.ison_level > 0.0 and s.bell_level > 0.0)
	t._check(s.ison_level == 0.0, "ison waits while the bell is heard")
	t._check(not heard_both and s.overlap_samples == 0,
		"ison and bell never overlap (%d samples)" % s.overlap_samples)
	# In Holy Week there is no tone, so no ison either.
	var hw := DiveSynth.new()
	hw.set_now(at("2026-04-08T10:00"))
	_run(hw, deep, 12.0, 30.0)
	t._check(hw.ison_level == 0.0, "no ison in Holy Week")
	# Not still: no ison.
	var moving := DiveSynth.new()
	moving.set_now(at("2026-09-29T12:00"))
	var busy := deep.duplicate()
	busy.silence = false
	_run(moving, busy, 12.0, 30.0)
	t._check(moving.ison_level == 0.0, "no ison outside the silence")


## Silence is room tone and breath, never digital zero.
func _silence() -> void:
	var s := DiveSynth.new()
	s.set_now(at("2026-04-08T10:00"))  # Holy Week: no ison, pure silence.
	var scene := {"depth": 120.0, "thrust": 0.0, "shore_m": 400.0,
		"silence": true, "echo_delay": 0.05}
	var a := _run(s, scene, 20.0)
	var win := int(RATE / 10.0)
	var zero := false
	for i in range(0, a.size() - win, win):
		var p := 0.0
		for j in range(i, i + win):
			p = maxf(p, absf(a[j]))
		zero = zero or p == 0.0
	t._check(not zero, "no silent 100 ms window in the deep silence")
	var rms := _db(_rms(a, int(3 * RATE)))
	t._check(rms <= -38.0 and rms >= -55.0, "silence RMS %.1f dBFS" % rms)
	report.append("deep silence (room + breath, machines ducked): %.1f dBFS RMS"
		% rms)
	var b := _only("breath")
	var cycle := DiveSynth.breath_cycle(DiveSynth.BREATH.basic)
	var ba := _run(b, scene, cycle * 2.0)
	var brms := _db(_rms(ba, int(cycle * RATE)))
	t._check(absf(brms + 45.0) <= 3.0, "breath %.1f dBFS RMS" % brms)
	report.append("breath alone: %.1f dBFS RMS over a 4:6 cycle" % brms)
	var room := _only("room")
	var ra := _run(room, scene, 6.0)
	report.append("room tone at 120 m: %.1f dBFS RMS"
		% _db(_rms(ra, int(RATE))))
	var room3 := _only("room")
	var shallow := scene.duplicate()
	shallow.depth = 3.0
	var r3 := _run(room3, shallow, 6.0)
	report.append("room tone at 3 m: %.1f dBFS RMS" % _db(_rms(r3, int(RATE))))
	var i := _only("ison")
	i.set_now(at("2026-09-29T12:00"))
	var ia := _run(i, scene, 30.0, 30.0)
	report.append("ison of tone %d (%.2f Hz), last 15 s: %.1f dBFS RMS"
		% [LudusTypikon.glas_of(at("2026-09-29T12:00")), i.tonic,
		_db(_rms(ia, int(15 * RATE)))])


## The sonar keeps the behaviour it had in dive.gd: the echo arrives
## 2 * range / c after the ping.
func _sonar() -> void:
	var s := _only("sonar")
	var delay := 2.0 * 30.0 / 1480.0
	var a := _run(s, {"depth": 10.0, "echo_delay": delay}, 4.5)
	var first := -1
	var echo := -1
	for k in a.size():
		if absf(a[k]) > 0.0:
			if first < 0:
				first = k
			elif echo < 0 and k - first > int(0.035 * RATE):
				echo = k
				break
	t._check(first >= 0 and echo > 0, "ping and echo present")
	var gap := (echo - first) / RATE
	t._check(absf(gap - delay) <= 2.0 / RATE,
		"echo after 2 * range / c: %.4f s vs %.4f s" % [gap, delay])
	var ping_peak := 0.0
	for k in range(first, first + int(0.03 * RATE)):
		ping_peak = maxf(ping_peak, absf(a[k]))
	t._check(absf(ping_peak - 0.35 * DiveSynth.SONAR_PLAYER) < 0.01,
		"ping level as before: %.3f" % ping_peak)


func _haptics() -> void:
	var audio := DiveAudio.new()
	audio.on_lamp_toggled(true)
	audio.on_taken("keep")
	audio.on_taken(null)
	t._check(audio.pulses.size() == 2, "lamp and take pulse; look-only not")
	audio.free()
	var calm := DiveAudio.new()
	calm.reduced_motion = true
	calm._pulse("echo", DiveAudio.PULSE_ECHO, 0.0)
	calm.on_lamp_toggled(false)
	t._check(calm.pulses.size() == 1 and calm.pulses[0][1]
		== DiveAudio.PULSE_LAMP[0] * 0.5,
		"reduced motion: no echo pulse, halved lamp pulse")
	calm.free()


func _determinism() -> void:
	var scene := {"depth": 60.0, "thrust": 0.6, "shore_m": 300.0,
		"silence": false, "echo_delay": 0.02}
	var a := _run(DiveSynth.new(), scene, 2.0)
	var b := _run(DiveSynth.new(), scene, 2.0)
	t._check(a == b, "the same scene sounds the same, sample for sample")


## The spectral references of the audio pass reach the synth
## (HLD_AUDIO_299 phase P8): numbers only, a median only over three
## single blows, a cue follows a published median, and an unpublished
## one changes nothing.
func _references() -> void:
	var raw := FileAccess.get_file_as_string(DiveSynth.REFERENCES_PATH)
	t._check(raw != "", "audio-references.json ships in data/")
	t._check(not ".ogg" in raw and not ".wav" in raw and not ".mp3" in raw
		and not "\"path\"" in raw, "references hold numbers, no file paths")
	var refs := DiveSynth.load_references()
	t._check(refs.size() == 23, "23 sound slots: %d" % refs.size())
	var published := 0
	for slot in refs:
		var r: Dictionary = refs[slot]
		if r.t60_median_s != null:
			published += 1
			t._check(int(r.t60_n) >= DiveSynth.REFERENCE_MIN_BLOWS,
				"%s: a median over %d blows" % [slot, int(r.t60_n)])
	var s := DiveSynth.new()
	t._check(s.references == refs, "the synth reads the file at start")
	var t60 := DiveSynth.reference_t60(refs, DiveSynth.TAKE_SLOT)
	if t60 < 0.0:
		t._check(s.take_tau == DiveSynth.TAKE_TAU,
			"no median for the take slot: the take keeps its own decay")
	else:
		t._check(absf(s.take_tau - t60 / log(1000.0)) < 1e-9,
			"the take decays with the published median")
	t._check(DiveSynth.load_references("res://data/missing.json").is_empty(),
		"a missing file leaves every constant as it is")
	# A published median moves the cue; two blows publish nothing.
	var long := _only("events")
	long.use_references({DiveSynth.TAKE_SLOT:
		{"t60_n": 3, "t60_median_s": 0.5}})
	var thin := _only("events")
	thin.use_references({DiveSynth.TAKE_SLOT:
		{"t60_n": 2, "t60_median_s": 0.5}})
	t._check(thin.take_tau == DiveSynth.TAKE_TAU, "two blows publish nothing")
	t._check(absf(long.take_tau - 0.5 / log(1000.0)) < 1e-9,
		"T60 0.5 s gives tau %.4f s" % long.take_tau)
	long.event_take()
	thin.event_take()
	var a := long.generate(int(0.3 * RATE))
	var b := thin.generate(int(0.3 * RATE))
	var tail_a := _rms(a, int(0.15 * RATE), int(0.3 * RATE))
	var tail_b := _rms(b, int(0.15 * RATE), int(0.3 * RATE))
	t._check(tail_a > 0.0 and tail_b == 0.0,
		"a 0.5 s median rings past 0.15 s, the own decay does not")
	report.append("references: %d slots, %d medians published; take tau %.4f s"
		% [refs.size(), published, s.take_tau])
