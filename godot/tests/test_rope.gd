## The prayer rope as a breath metronome (RopeCore, RopeBreath).  The
## table must equal the one the dive breathes by (DiveSynth.BREATH, which
## tests/ludus-audio-parity.test.js ties to ludus-sacred-synth.js), and
## tests/rope-breath.test.js ties it to the hesychasm module itself.
## Called from run_hub_tests.gd.
extends RefCounted


func run(t: Object) -> void:
	# Rule 20: one table of timings.
	t._check(RopeCore.BREATH.size() == 5, "five patterns")
	for name in RopeCore.ORDER:
		t._check(RopeCore.BREATH.has(name), name + " in order")
		t._check(RopeCore.BREATH[name] == DiveSynth.BREATH[name],
			name + " equals DiveSynth.BREATH")
		t._check(RopeCore.RU.has(name), name + " has a name")
	var cycles := {"basic": 10.0, "athonite": 15.0, "optina": 10.0,
		"sinaite": 16.0, "ignatius": 12.0}
	for name in cycles:
		t._check(is_equal_approx(RopeCore.cycle(name), cycles[name]),
			"%s cycle %.2f" % [name, RopeCore.cycle(name)])
		t._check(is_equal_approx(RopeCore.knots_per_minute(name),
			60.0 / cycles[name]), name + " pace")
	# Phases of the Athonite breath: 5 in, 1 held, 8 out, 1 quiet.
	var want := [[0.0, "inhale"], [4.9, "inhale"], [5.0, "hold_in"],
		[5.9, "hold_in"], [6.0, "exhale"], [13.9, "exhale"],
		[14.0, "hold_out"], [14.9, "hold_out"], [15.0, "inhale"],
		[21.5, "exhale"]]
	for w in want:
		var ph := RopeCore.phase_at("athonite", w[0])
		t._check(ph.phase == w[1], "athonite @%.1f %s vs %s" % [w[0],
			ph.phase, w[1]])
	t._check(RopeCore.phase_at("athonite", 21.5).cycle == 1, "cycle count")
	# The basic breath has no holds: they are skipped, never zero-long.
	for q in [0.0, 3.99, 4.0, 9.99]:
		var ph := RopeCore.phase_at("basic", q)
		t._check(ph.phase in ["inhale", "exhale"], "basic @%.2f" % q)
	# One knot per breath, only on the outgoing half.
	var st := RopeCore.new_state("basic")
	var a := HubCore.new_actions()
	var tied := 0
	var why := {}
	var clock := 0.0
	while clock < 60.0:  # One press every half second for a minute.
		st.clock = clock
		var r := RopeCore.tie(st, a)
		st = r.state
		a = r.actions
		if r.tied:
			tied += 1
		else:
			why[r.why] = true
		clock += 0.5
	t._check(tied == 6, "basic: 6 knots in a minute, got %d" % tied)
	t._check(int(a.prayerCount) == 6, "the knot is HubCore's knot")
	t._check(why.has("inhale") and why.has("same"), "reasons said")
	# A press on the inhale ties nothing and changes nothing.
	var st2 := RopeCore.new_state("sinaite")
	st2.clock = 3.0
	var r2 := RopeCore.tie(st2, HubCore.new_actions())
	t._check(not r2.tied and r2.why == "inhale"
		and float(r2.actions.prayerCount) == 0.0, "inhale ties nothing")
	st2.clock = 7.5  # Still the hold after the inhale.
	t._check(not RopeCore.tie(st2, HubCore.new_actions()).tied, "hold_in")
	st2.clock = 9.0
	t._check(RopeCore.tie(st2, HubCore.new_actions()).tied, "exhale ties")
	# Turning the pattern starts a new breath.
	var st3 := RopeCore.turn({"pattern": "ignatius", "clock": 7.0,
		"last_cycle": 3}, 1)
	t._check(st3.pattern == "basic" and st3.clock == 0.0
		and st3.last_cycle == -1, "turn wraps and restarts")
	t._check(RopeCore.turn(RopeCore.new_state(), -1).pattern == "ignatius",
		"turn back")
	t._check(RopeCore.new_state("unknown").pattern == "basic", "unknown")
	# Cues for the hand: one exhale and one inhale per cycle.
	var cues := RopeCore.cues_between("athonite", 0.0, 30.0)
	var kinds := []
	for c in cues:
		kinds.append([c.kind, c.at])
	t._check(kinds == [["exhale", 6.0], ["inhale", 15.0], ["exhale", 21.0],
		["inhale", 30.0]], "athonite cues %s" % [kinds])
	var sum := 0
	var tt := 0.0
	while tt < 30.0:  # Frame by frame, nothing lost or doubled.
		sum += RopeCore.cues_between("athonite", tt, tt + 1.0 / 72.0).size()
		tt += 1.0 / 72.0
	t._check(sum == 4, "cues frame by frame %d" % sum)
	# The breath heard at the lectern: deterministic, quiet, never zero.
	for name in RopeCore.ORDER:
		var pcm := RopeBreath.render(name)
		t._check(pcm.size() == int(round(RopeCore.cycle(name)
			* RopeBreath.RATE)), name + " one cycle")
		var s2 := 0.0
		var peak := 0.0
		var quiet := 1.0
		for i in pcm.size():
			s2 += pcm[i] * pcm[i]
			peak = maxf(peak, absf(pcm[i]))
		# The quietest 50 ms window: room tone, not digital zero.
		var win := int(0.05 * RopeBreath.RATE)
		var i0 := 0
		while i0 + win < pcm.size():
			var e := 0.0
			for j in win:
				e += pcm[i0 + j] * pcm[i0 + j]
			quiet = minf(quiet, sqrt(e / win))
			i0 += win
		var db := 20.0 * log(sqrt(s2 / pcm.size())) / log(10.0)
		t._check(absf(db + 45.0) <= 3.0, "%s breath %.1f dBFS RMS"
			% [name, db])
		t._check(peak < 0.5, "%s peak %.2f" % [name, peak])
		t._check(quiet > 0.0, "%s never digital zero" % name)
		t._check(RopeBreath.render(name) == pcm, name + " deterministic")
