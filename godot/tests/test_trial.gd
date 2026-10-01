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
			"choose":
				var res := TrialCore.choose_trial(data, st, gid,
					r.optionId, r.form, r.actions)
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
