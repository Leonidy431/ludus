## The sound of the path of the witness (docs/HLD_WITNESS_SOUND_
## 2026-09-30.md): what can be proved without a headset.  Called from
## run_hub_tests.gd; every check goes through its _check().
##
##   - the bell is the kolokol ch. 12 bell: five partials, hum and prime
##     doublets, the same благовестник as the dive and the web;
##   - every bell cue declares {order, service, dayRankCondition,
##     meaning} and is started by the clock only;
##   - over nine years of days no трезвон rings on Great Friday, Great
##     Saturday or a weekday of Great Lent, and every day of Bright
##     Week has one (TABOO 0.35 rule 9);
##   - the ison declares {glas, tonic, final, vowel, kliros}, is sung
##     only by the kits whose scene has an ison, and never together
##     with the bell (rule 10);
##   - the room tone is never digital zero and the peak stays at or
##     below -1 dBFS (TABOO 0.4 rules 2 and 13).
extends RefCounted

const RATE := 22050


func _db(x: float) -> float:
	return 20.0 * log(maxf(x, 1e-12)) / log(10.0)


func _stats(buf: PackedVector2Array) -> Dictionary:
	var peak := 0.0
	var acc := 0.0
	var zero_run := 0
	var longest_zero := 0
	for v in buf:
		peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
		acc += (v.x * v.x + v.y * v.y) / 2.0
		if v.x == 0.0 and v.y == 0.0:
			zero_run += 1
			longest_zero = maxi(longest_zero, zero_run)
		else:
			zero_run = 0
	return {"peak_db": _db(peak),
		"rms_db": 10.0 * log(acc / maxf(1.0, buf.size()) + 1e-24) / log(10.0),
		"longest_zero": longest_zero}


func _date(y: int, m: int, d: int) -> Dictionary:
	return {"year": y, "month": m, "day": d}


func _render(a: WitnessAudio, pos: Vector3, bays: Array,
		seconds: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var frames := int(seconds * RATE)
	var step := 735  # 30 frames a second, as a headset frame feeds it.
	var done := 0
	while done < frames:
		a.bells.warm(1 << 30)
		a.listen(pos, bays)
		var n := mini(step, frames - done)
		out.append_array(a.generate(n))
		done += n
	return out


func run(t: Object) -> void:
	_bell_model(t)
	_cues(t)
	_calendar(t)
	var witness_z := {}
	for id in WitnessCore.ORDER:
		var kit := (load("res://models/scene/sacrament-%s.glb" % id)
			as PackedScene).instantiate() as Node3D
		for c in kit.find_children("*", "Node3D", true, false):
			if String(c.name).to_lower().contains("witness"):
				witness_z[id] = (c as Node3D).position.z
		kit.free()
	var bays := WitnessCore.bays(witness_z)
	_ison(t, bays)
	_mix(t, bays)
	_sources(t)


func _bell_model(t: Object) -> void:
	var s := BellSynth.spec(0)
	var dive := DiveSynth.make_bell_spec()
	t._check(s.partials.size() == 5, "bell: five principal partials")
	var same := true
	for k in 5:
		same = same and absf(s.partials[k].freq - dive.partials[k].freq) \
			< 1e-9 and absf(s.partials[k].split
			- dive.partials[k].split) < 1e-9
	t._check(same and s.ring == dive.ring,
		"bell: the благовестник equals the dive's (and bellSpec(0))")
	var want := [0.5, 1.0, 1.2, 1.5, 2.0]
	for i in BellSynth.ENSEMBLE.size():
		var b := BellSynth.spec(i)
		var ok := true
		for k in 5:
			var p: Dictionary = b.partials[k]
			var drift: float = DiveSynth.BELL_PARTIALS[k].drift
			ok = ok and absf(p.ratio / want[k] - 1.0) <= drift + 1e-12
		var m := BellSynth.modes(b, 0.9)
		# Hum and prime are doublets: two modes each, 0.12-0.52 Hz apart.
		var split_ok: bool = m.size() == 7 \
			and m[1][0] - m[0][0] > 0.11 and m[1][0] - m[0][0] < 0.53 \
			and m[3][0] - m[2][0] > 0.11 and m[3][0] - m[2][0] < 0.53
		t._check(ok and split_ok, "bell %s: kolokol ratios, doublets"
			% b.name)


func _cues(t: Object) -> void:
	var orders := ["благовест", "трезвон", "перезвон", "перебор", "двои",
		"било"]
	for c in TypikonCore.CUES:
		var keys_ok: bool = c.has("order") and c.has("service") \
			and c.has("dayRankCondition") and c.has("meaning") \
			and String(c.meaning).length() > 10
		t._check(keys_ok and c.order in orders,
			"cue %s declares order, service, dayRankCondition, meaning"
			% c.id)
		t._check(c.trigger == "clock", "cue %s is started by the clock"
			% c.id)
		var bad := false
		for k in c.keys():
			for w in ["reward", "ui", "level", "action", "button",
					"achievement", "xp"]:
				bad = bad or String(k).to_lower().begins_with(w)
		t._check(not bad, "cue %s has no reward, UI or level-up key" % c.id)


## Nine years of days, every cue of every day: the rules of rule 9.
func _calendar(t: Object) -> void:
	var grief_trezvon := 0
	var lent_trezvon := 0
	var bright_days := 0
	var bright_missing := []
	var lent_sundays := 0
	var lent_sunday_trezvon := 0
	var days := 0
	var blagovest_days := 0
	var perebor_or_other := 0
	for y in range(2024, 2033):
		var start := LudusTypikon._day(y, 1, 1)
		var end := LudusTypikon._day(y + 1, 1, 1)
		var d := start
		while d < end:
			var c := Time.get_datetime_dict_from_unix_time(d)
			var civil := _date(c.year, c.month, c.day)
			var plan := TypikonCore.day_plan(civil)
			var noon := LudusTypikon.describe(TypikonCore._moment(civil, 720))
			var has_trezvon := false
			var has_blagovest := false
			for p in plan:
				var lit: Dictionary = p.lit
				if p.cue.order == "трезвон":
					has_trezvon = true
					if lit.period in ["great-friday", "great-saturday"] \
							or noon.period in ["great-friday",
								"great-saturday"]:
						grief_trezvon += 1
					if lit.period == "great-lent" and lit.rank == "daily" \
							and lit.weekday >= 1 and lit.weekday <= 5:
						lent_trezvon += 1
				elif p.cue.order == "благовест":
					has_blagovest = true
				else:
					perebor_or_other += 1
			if noon.period in ["pascha", "bright-week"]:
				bright_days += 1
				if not has_trezvon:
					bright_missing.append(TypikonCore.day_key(civil))
			if noon.period == "great-lent" and noon.weekday == 6:
				# The vigil of a Sunday of Lent keeps its трезвон.
				lent_sundays += 1
				for p in plan:
					if p.cue.id == "vigil-trezvon":
						lent_sunday_trezvon += 1
			if has_blagovest:
				blagovest_days += 1
			days += 1
			d += LudusTypikon.DAY
	t._check(grief_trezvon == 0,
		"no трезвон on Great Friday or Saturday (%d)" % grief_trezvon)
	t._check(lent_trezvon == 0,
		"no трезвон on a weekday of Great Lent (%d)" % lent_trezvon)
	t._check(bright_days == 9 * 7 and bright_missing.is_empty(),
		"трезвон on every day of Bright Week: %d days, missing %s"
		% [bright_days, bright_missing])
	t._check(lent_sundays > 0 and lent_sunday_trezvon == lent_sundays,
		"the vigils of the Sundays of Lent: %d of %d"
		% [lent_sunday_trezvon, lent_sundays])
	t._check(blagovest_days == days, "the call to Vespers every day "
		+ "(%d of %d)" % [blagovest_days, days])
	t._check(perebor_or_other == 0, "the path rings no other order")
	# The guard itself, on the days of 2026 (Pascha 2026-04-12).
	for m in [[4, 10, 12], [4, 10, 19], [4, 11, 12], [4, 11, 19],
			[3, 11, 12], [3, 11, 19]]:
		var at := {"year": 2026, "month": m[0], "day": m[1], "hour": m[2],
			"minute": 0, "second": 0}
		var lit := LudusTypikon.describe(at)
		var noon := LudusTypikon.describe(TypikonCore._moment(
			_date(2026, m[0], m[1]), 720))
		t._check(TypikonCore.trezvon_forbidden(lit, noon) != "",
			"трезвон forbidden at %s (%s)" % [at, lit.period])
	# Known days, by hand: Great Friday 2026-04-10 and Great Saturday
	# 2026-04-11 ring only благовест; Pascha 2026-04-12 rings трезвон;
	# a Lenten Wednesday (2026-03-11) has twelve strokes to Vespers.
	for day in [[2026, 4, 10], [2026, 4, 11]]:
		var orders := []
		for p in TypikonCore.day_plan(_date(day[0], day[1], day[2])):
			orders.append(p.cue.order)
		t._check(not "трезвон" in orders, "%s: %s" % [day, orders])
	var pascha := []
	for p in TypikonCore.day_plan(_date(2026, 4, 12)):
		pascha.append(p.cue.id)
	t._check("bright-trezvon" in pascha and "vigil-trezvon" in pascha,
		"Pascha 2026-04-12: %s" % [pascha])
	for p in TypikonCore.day_plan(_date(2026, 3, 11)):
		if p.cue.id == "vespers-call":
			t._check(p.strokes.size() == 12,
				"Lenten Wednesday: %d strokes to Vespers" % p.strokes.size())
	# Deterministic: the same day gives the same strokes.
	var a := TypikonCore.strokes(TypikonCore.CUES[4], _date(2026, 10, 3))
	var b := TypikonCore.strokes(TypikonCore.CUES[4], _date(2026, 10, 3))
	t._check(a == b and a.size() > 100, "трезвон strokes deterministic "
		+ "(%d strokes)" % a.size())


func _ison(t: Object, bays: Array) -> void:
	var a := WitnessAudio.new()
	a.set_now({"year": 2026, "month": 9, "day": 30, "hour": 12,
		"minute": 0, "second": 0})
	for b in bays:
		var has_ison: bool = b.meta.audio.get("ison") != null
		var d := a.ison_of(b.id)
		var keys := ["glas", "tonic", "final", "vowel", "kliros"]
		var ok := true
		for k in keys:
			ok = ok and d.has(k)
		t._check(has_ison and ok and d.vowel in IsonSynth.VOWELS
			and d.tonic > 0.0 and String(d.meaning).length() > 10,
			"%s: ison declares %s" % [b.id, d])
	# glas 8 on 2026-09-30 (tests/test_audio.gd GLAS_FIXTURE), base Ni.
	var d := a.ison_of("baptism")
	t._check(d.glas == 8 and d.final == "Ni" and d.vowel == "a",
		"ison of the font on 2026-09-30: glas 8 on Ni, vowel a")
	# Holy Week has no tone of its own: nothing is declared, only room.
	a.set_now({"year": 2026, "month": 4, "day": 8, "hour": 12,
		"minute": 0, "second": 0})
	t._check(a.ison_of("baptism").is_empty(),
		"Holy Week: no ison declared")


func _mix(t: Object, bays: Array) -> void:
	var at_font := Vector3(bays[0].x, 0, bays[0].side * 1.5)
	var between := Vector3(bays[0].x + 7.5, 0, 0)
	var noon := {"year": 2026, "month": 9, "day": 30, "hour": 12,
		"minute": 0, "second": 0}
	# Room only, between two kits at noon: -48 dBFS, never zero.
	var a := WitnessAudio.new()
	a.set_now(noon)
	var room := _stats(_render(a, between, bays, 5.0))
	t._check(absf(room.rms_db - WitnessCore.ROOM_TONE_DBFS) < 2.0
		and room.longest_zero < 4,
		"room tone %.1f dBFS, longest zero run %d samples"
		% [room.rms_db, room.longest_zero])
	# The ison at the font's line.
	var b := WitnessAudio.new()
	b.set_now(noon)
	var sung := _render(b, at_font, bays, 20.0)
	var tail := sung.slice(10 * RATE)
	var ison := _stats(tail)
	t._check(ison.rms_db > -40.0 and ison.rms_db < -24.0
		and ison.peak_db <= -1.0, "ison at the font: %.1f dBFS RMS, "
		% ison.rms_db + "peak %.1f dBFS" % ison.peak_db)
	var again := WitnessAudio.new()
	again.set_now(noon)
	t._check(_render(again, at_font, bays, 20.0) == sung,
		"the ison is deterministic")
	# The call to Vespers starts while the walker stands at the font:
	# the ison yields, the bell is heard, never both at once.
	var c := WitnessAudio.new()
	c.set_now({"year": 2026, "month": 9, "day": 30, "hour": 17,
		"minute": 49, "second": 40})
	var call := _stats(_render(c, at_font, bays, 60.0))
	t._check(c.overlap_samples == 0, "ison and bell never together "
		+ "(%d samples)" % c.overlap_samples)
	t._check(c.rung.size() == 1 and c.rung[0].order == "благовест",
		"the call to Vespers rang: %s" % [c.rung])
	t._check(call.peak_db <= -1.0 and call.longest_zero < 4,
		"call to Vespers: peak %.1f dBFS" % call.peak_db)
	# The loudest moment: the трезвон of Pascha day at noon, with its
	# удар во вся.
	var e := WitnessAudio.new()
	e.set_now({"year": 2026, "month": 4, "day": 12, "hour": 11,
		"minute": 59, "second": 58})
	var tz := _stats(_render(e, between, bays, 30.0))
	t._check(e.rung.size() == 1 and e.rung[0].order == "трезвон"
		and tz.peak_db <= -1.0 and tz.peak_db > -12.0,
		"Pascha трезвон: peak %.1f dBFS, %s" % [tz.peak_db, e.rung])
	t._check(e.bells.cold_strokes == 0, "every stroke was warm in time")
	# The tone of the week turns at Vespers on Saturday, not at midnight.
	var sat := {"year": 2026, "month": 10, "day": 3, "hour": 17,
		"minute": 59, "second": 50}
	var g := WitnessAudio.new()
	g.set_now(sat)
	g.listen(at_font, bays)
	var tone_before: int = g.ison.decl.glas
	g.generate(15 * RATE)
	var tone_after: int = g.ison.decl.glas
	var eve := sat.duplicate()
	eve.hour = 18
	eve.minute = 0
	t._check(tone_before == LudusTypikon.glas_of(sat)
		and tone_after == LudusTypikon.glas_of(eve)
		and tone_before != tone_after,
		"the ison's tone turns at Vespers: %d -> %d" % [tone_before,
			tone_after])
	# The headset renders the clips on a worker thread: the same samples.
	var strokes := TypikonCore.strokes(TypikonCore.CUES[2],
		_date(2026, 4, 12))
	var w1 := BellSynth.new()
	var w2 := BellSynth.new()
	w1.prepare(strokes)
	w2.prepare(strokes)
	w1.warm(1 << 30)
	var polls := 0
	while (not w2.jobs.is_empty() or w2.task != -1) and polls < 60000:
		w2.warm_async()
		OS.delay_usec(500)
		polls += 1
	t._check(w2.clips.size() == w1.clips.size() and w2.clips == w1.clips,
		"worker-thread clips equal the direct ones (%d clips)"
		% w2.clips.size())
	# Great Friday at the same noon: nothing rings.
	var f := WitnessAudio.new()
	f.set_now({"year": 2026, "month": 4, "day": 10, "hour": 11,
		"minute": 59, "second": 58})
	_render(f, between, bays, 5.0)
	t._check(f.rung.is_empty(), "Great Friday noon: silence of bells")


## Only the clock strikes a bell: the scene never calls the bell, and
## no audio file speaks of rewards.
func _sources(t: Object) -> void:
	var scene := FileAccess.get_file_as_string("res://scripts/witness.gd")
	t._check(not scene.contains("strike(") and not scene.contains(
		"BellSynth") and not scene.contains("TypikonCore"),
		"witness.gd never strikes a bell")
	var mix := FileAccess.get_file_as_string(
		"res://scripts/audio/witness_audio.gd")
	t._check(mix.count("bells.strike(") == 1 and mix.find(
		"bells.strike(") > mix.find("func _ring_due("),
		"only _ring_due (the clock) strikes")
	for path in ["res://scripts/audio/witness_audio.gd",
			"res://scripts/audio/bell_synth.gd",
			"res://scripts/audio/ison_synth.gd",
			"res://scripts/typikon_core.gd"]:
		var src := FileAccess.get_file_as_string(path).to_lower()
		var hits := []
		for w in ["levelup", "level_up", "achievement", "on_reward",
				"reward(", "pressed.connect", "microphone", "record("]:
			if src.contains(w):
				hits.append(w)
		t._check(hits.is_empty(), "%s: no %s" % [path.get_file(), hits])
