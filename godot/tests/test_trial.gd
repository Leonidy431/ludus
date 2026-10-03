## TrialCore against the JS reference: every record of
## godot/tests/trial_fixture.json is replayed with the same inputs.
## Called from run_hub_tests.gd.
extends RefCounted


## The JS state keeps its own names; the port keeps GDScript's.
func _state_in(js: Dictionary) -> Dictionary:
	return {"trials": js.get("trials", {}).duplicate(),
		"trial_wait": js.get("trialWait", {}).duplicate(),
		"fall": js.get("fall")}


func _same_fall(a, b) -> bool:
	if a == null or b == null:
		return a == b
	return a.passion == b.passion and a.teacher == b.teacher \
		and int(a.since.sobriety) == int(b.since.sobriety) \
		and int(a.since.met) == int(b.since.met)


func _same_wait(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k) or int(a[k]) != int(b[k]):
			return false
	return true


func run(t: Object) -> void:
	var data := TrialCore.load_data()
	var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/trial_fixture.json"))
	t._check(fx.records.size() > 90, "trial records %d" % fx.records.size())
	for i in fx.records.size():
		var r: Dictionary = fx.records[i]
		var st := _state_in(r.state)
		var gid: String = r.gateId if r.gateId != null else ""
		var tag := "#%d %s %s %s" % [i, r.op, gid, r.optionId]
		match r.op:
			"view":
				var v := TrialCore.trial_view(data, st, gid, r.form,
					r.actions)
				var want = r.out.view
				if want == null:
					t._check(v.is_empty(), tag + " no trial")
					continue
				var dis := []
				for o in v.options:
					dis.append(o.disabled)
				t._check(v.open == want.open and v.passed == want.passed
					and v.waiting == want.waiting and dis == want.disabled,
					tag + " view %s vs %s" % [[v.open, v.passed, v.waiting,
						dis], [want.open, want.passed, want.waiting,
						want.disabled]])
				t._check(v.locked == bool(want.get("locked", false))
					and v.reason == str(want.get("reason", "")),
					tag + " locked %s/%s" % [v.locked, v.reason])
			"choose":
				var oid: String = r.optionId if r.optionId != null else ""
				var res := TrialCore.choose_trial(data, st, gid, oid,
					r.form, r.actions)
				t._check(res.outcome == r.out.outcome, tag + " outcome %s vs %s"
					% [res.outcome, r.out.outcome])
				t._check(res.reply == (r.out.reply if r.out.reply != null
					else ""), tag + " reply")
				var ws: Dictionary = r.out.state
				t._check(res.state.trials == ws.trials, tag + " trials")
				t._check(_same_wait(res.state.trial_wait, ws.trialWait),
					tag + " wait")
				t._check(_same_fall(res.state.fall, ws.fall), tag + " fall")
			"status":
				var s := TrialCore.fall_status(data, st, r.actions)
				var w: Dictionary = r.out.status
				t._check(s.fallen == w.fallen, tag + " fallen")
				if w.fallen:
					t._check(s.passion == w.passion and s.teacher == w.teacher
						and s.sober == w.sober and s.taught == w.taught
						and s.can_lift == w.canLift, tag + " status %s vs %s"
						% [[s.sober, s.taught, s.can_lift], [w.sober, w.taught,
							w.canLift]])
			"lift":
				var after := TrialCore.lift_fall(data, st, r.actions)
				t._check(_same_fall(after.fall, r.out.state.fall),
					tag + " lift")
	# No option anywhere is marked right: every trial has one through,
	# one return and one fall (a choice by understanding, not a quiz).
	for tr in data.trials.trials:
		var kinds := []
		for o in tr.options:
			kinds.append(o.outcome)
		kinds.sort()
		t._check(kinds == ["fall", "return", "through"],
			"%s: through, return, fall" % tr.gateId)
	_second_fall(t, data)
	_ladder_waits_for_threshold(t)


## Every gate open by the three-part check (as openAll() in the fixture
## script), so only the thresholds and the fall decide.
func _open_all() -> Dictionary:
	var a := HubCore.new_actions()
	for i in 33:
		a = HubCore.pray_knot(a)
	for m in HubCore.MENTORS:
		a = HubCore.record_meeting(a, m)
	a.fastDays = 1.0
	a = HubCore.add_stillness(a, 60.0)
	var f := HubCore.new_form()
	f.wisdom = 14
	for g in ["contemplative", "mystical", "apophatic"]:
		a = HubCore.accept_gift(a, f, g)
	return a


func _wise() -> Dictionary:
	var f := HubCore.new_form()
	f.wisdom = 14
	return f


func _option(data: Dictionary, gate_id: String, kind: String) -> String:
	for o in TrialCore.trial_for(data, gate_id).options:
		if o.outcome == kind:
			return o.id
	return ""


## F9: a second fall never silently overwrites the first.  While a fall
## lasts every threshold is locked with reason "fall", and even a direct
## second fall keeps the first passion and its snapshot.
func _second_fall(t: Object, data: Dictionary) -> void:
	var a := _open_all()
	var st := TrialCore.empty_state()
	st.trials.foundational = true
	var res := TrialCore.choose_trial(data, st, "liturgical",
		_option(data, "liturgical", "fall"), _wise(), a)
	t._check(res.outcome == "fall", "second fall: first fall taken")
	var first = res.state.fall.duplicate(true)
	for gid in TrialCore.GATE_IDS:
		var v := TrialCore.trial_view(data, res.state, gid, _wise(), a)
		var all_off := true
		for o in v.options:
			all_off = all_off and o.disabled
		t._check(v.locked and v.reason == "fall" and all_off,
			"second fall: %s locked while fallen" % gid)
	var again := TrialCore.choose_trial(data, res.state, "liturgical",
		_option(data, "liturgical", "fall"), _wise(),
		HubCore.add_stillness(a, 5.0))
	t._check(again.outcome == null and _same_fall(again.state.fall, first),
		"second fall: fall option closed, first fall kept")
	var other := ""
	for p in data.passions.passions:
		if p.id != first.passion:
			other = p.id
			break
	var st2: Dictionary = res.state.duplicate(true)
	TrialCore._fall_into(data, st2, other, HubCore.add_stillness(a, 5.0))
	t._check(_same_fall(st2.fall, first),
		"second fall: direct fall keeps %s, not %s" % [first.passion, other])
	# Lifting the first fall (sobriety and the teacher's talk) unlocks.
	var b := HubCore.record_meeting(HubCore.add_stillness(a, 1.0),
		first.teacher)
	var lifted := TrialCore.lift_fall(data, res.state, b)
	var v2 := TrialCore.trial_view(data, lifted, "liturgical", _wise(), b)
	t._check(lifted.fall == null and not v2.locked and v2.reason == "",
		"second fall: lifted fall unlocks the thresholds")


## Chorus decision (HLD_TRIALS_LADDER_2026-10-03): the threshold of gate
## N must be passed before gate N+1 opens; a "return" keeps it closed.
func _ladder_waits_for_threshold(t: Object) -> void:
	var a := _open_all()
	var f := _wise()
	var plain := HubCore.evaluate_ladder(f, a)
	t._check(plain[1].open and plain[5].open,
		"ladder without trial state: three-part check alone")
	var none := HubCore.evaluate_ladder(f, a, {})
	t._check(none[0].open and not none[1].open
		and "trial" in none[1].missing and "ladder" in none[2].missing,
		"ladder: liturgical waits for the foundational threshold")
	var one := HubCore.evaluate_ladder(f, a, {"foundational": true})
	t._check(one[1].open and not one[2].open
		and "trial" in one[2].missing,
		"ladder: one threshold passed opens exactly one more gate")
	var every := {}
	for g in TrialCore.GATE_IDS:
		every[g] = true
	var full := HubCore.evaluate_ladder(f, a, every)
	var all_open := true
	for c in full:
		all_open = all_open and c.open
	t._check(all_open, "ladder: all thresholds passed, all gates open")
	# The prayer rope stays a rite condition: more knots never stand in
	# for the threshold, and the threshold never adds to the count.
	var more := a.duplicate(true)
	for i in 100:
		more = HubCore.pray_knot(more)
	t._check(not HubCore.evaluate_ladder(f, more, {})[1].open,
		"ladder: knots on the rope do not replace the threshold")
