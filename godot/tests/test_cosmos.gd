## The suite «Наука. Любовь. Познание.» (CosmosSynth) and the 99 signs
## of Entelechy it sounds.  Called from run_hub_tests.gd.
extends RefCounted


func _peak(buf: PackedVector2Array) -> float:
	var m := 0.0
	for v in buf:
		if is_nan(v.x) or is_nan(v.y):
			return INF
		m = maxf(m, maxf(absf(v.x), absf(v.y)))
	return m


func run(t: Object) -> void:
	var d := CosmosSynth.load_data()
	var count := 0
	var keys := ["root_hz", "center_hz", "cluster", "target", "cycle_s",
		"love", "unfold", "drone", "wind", "wind_hz", "sparkle_per_min",
		"sparkle", "echo"]
	var just := true
	for n in d.get("nodes", []):
		count += n.signs.size()
		var c: Dictionary = n.cue
		var ks := c.keys()
		ks.sort()
		var want := keys.duplicate()
		want.sort()
		t._check(ks == want, "node %s: the cue has exactly the picture's "
			% n.id + "numbers (no voice, no bell)")
		t._check(c.cluster.size() == CosmosSynth.VOICES
			and c.target.size() == CosmosSynth.VOICES,
			"node %s: six voices" % n.id)
		# Science on a just grid: every sparkle and target is a ratio of
		# small numbers (denominator <= 8), never an inharmonic partial.
		for r in c.sparkle + c.target:
			var ok := false
			for den in range(1, 9):
				if absf(float(r) * den - roundf(float(r) * den)) < 1e-6:
					ok = true
			just = just and ok
		for s in n.signs:
			if s.has("reading_ru"):
				t._check(str(s.reading_ru).length() > 40,
					"%s.%d: the chorus's reading is there" % [n.id, s.n])
	t._check(d.nodes.size() == 9 and count == 99,
		"nine nodes, ninety-nine signs (%d)" % count)
	t._check(just, "every pitch of the suite stands on a just ratio")
	t._check(CosmosSynth.cue_for_beat(d, "khachkar") == ""
		and "khachkar" in d.silent_beats,
		"no music of its own at the khachkar")

	var pd := PilotCore.load_data()
	var unheard := []
	for b in pd.beats:
		if b.id != "khachkar" and CosmosSynth.cue_for_beat(d, b.id) == "":
			unheard.append(b.id)
	t._check(unheard.is_empty(), "every beat but the khachkar has its "
		+ "node: %s" % [unheard])

	t._check(is_equal_approx(CosmosSynth.voice_hz(200.0, 72.0, 1.5, 0.0),
		400.0) and is_equal_approx(CosmosSynth.voice_hz(200.0, 72.0,
		1.5, 1.0), 300.0),
		"love: a voice glides from its cluster step to its just ratio")

	var a := CosmosSynth.new(d)
	var b := CosmosSynth.new(d)
	a.set_cue("I")
	b.set_cue("I")
	var n1 := int(10.0 * CosmosSynth.MIX_RATE)
	var x := a.generate(n1)
	var y := b.generate(n1)
	t._check(x == y, "the same cue sounds the same every time")
	for n in d.nodes:
		var s := CosmosSynth.new(d)
		s.set_cue(n.id)
		var p := _peak(s.generate(n1))
		t._check(p > 0.02 and p < 0.5,
			"node %s: sounding, no NaN, peak %.3f under -6 dBFS" % [n.id, p])
	# A new node does not cut in: the picture morphs over MORPH_S.
	a.set_cue("IX")
	a.generate(int(CosmosSynth.MIX_RATE))
	var mid: float = a.cur.center_hz
	a.generate(int(6.0 * CosmosSynth.MORPH_S * CosmosSynth.MIX_RATE))
	t._check(mid > 196.5 and mid < 261.0
		and absf(float(a.cur.center_hz) - 261.63) < 1.0,
		"the music glides from node to node (%.1f Hz after 1 s)" % mid)
	var code := FileAccess.get_file_as_string(
		"res://scripts/audio/cosmos_synth.gd")
	t._check(not code.contains("randf") and not code.contains("randi"),
		"no randomness in the music: seeded xorshift only")
	_silent(t, d)


## At the khachkar the music is at -60 dB and cannot be heard, so it is
## not computed (phase F3 of docs/HLD_CHORUS24_FIXES_2026-10-03.md):
## zeros come out, and the voices take up where they stopped.
func _silent(t: Object, d: Dictionary) -> void:
	var s := CosmosSynth.new(d)
	s.follow_volume(-60.0)
	t._check(s.silent, "at -60 dB (the khachkar) the music is silent")
	s.follow_volume(CosmosSynth.SILENT_DB)
	t._check(s.silent, "at the threshold itself it is silent")
	s.follow_volume(-58.0)
	t._check(not s.silent, "at -58 dB it is computed again")
	var n := int(2.0 * CosmosSynth.MIX_RATE)
	var a := CosmosSynth.new(d)
	var b := CosmosSynth.new(d)
	a.set_cue("III")
	b.set_cue("III")
	var a1 := a.generate(n)
	var b1 := b.generate(n)
	a.set_silent(true)
	var zeros := a.generate(n)
	var t0 := Time.get_ticks_usec()
	a.generate(int(CosmosSynth.MIX_RATE))
	var silent_us := Time.get_ticks_usec() - t0
	t._check(_peak(zeros) == 0.0 and zeros.size() == n,
		"silent: exact zeros, as many frames as asked")
	t._check(a.sample == b.sample,
		"silent: the picture's clock stands still (%d)" % a.sample)
	t._check(silent_us < 20000,
		"silent: a second of zeros costs %d us, not a voice" % silent_us)
	a.set_silent(false)
	t._check(a1 == b1 and a.generate(n) == b.generate(n),
		"after the silence the music takes up where it stopped")
