## RuleCore and the evening watch against the JS reference: every chain
## of godot/tests/fixtures/rule.json (scripts/godot/make_rule_fixture.js)
## is replayed with the same inputs, and the whole rule is compared
## after each step; the fall chains also compare TrialCore's fall
## status, so the watch lifts a fall exactly as the web does.
## Called from run_hub_tests.gd.
extends RefCounted


func _same(a, b) -> bool:
	# JSON numbers come back as floats; the port keeps ints for counts.
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] \
			and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return absf(float(a) - float(b)) < 1e-9
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


func _compare(t: Object, tag: String, a: Dictionary, day, want: Dictionary
		) -> void:
	var n := RuleCore.normalize(a)
	for k in want.actions:
		t._check(_same(n[k], want.actions[k]), "%s %s: %s vs %s" % [tag, k,
			n[k], want.actions[k]])
	for p in RuleCore.PRACTICES:
		var got := RuleCore.practice_tally(a, p.id)
		var w: Dictionary = want.tally[p.id]
		t._check(got.shown == w.shown and got.text == w.text
			and (not w.shown or int(got.value) == int(w.value)),
			"%s tally %s: %s vs %s" % [tag, p.id, got, w])
		t._check(RuleCore.kept_today(a, p.id, day) == want.kept[p.id],
			"%s kept %s" % [tag, p.id])


func run(t: Object) -> void:
	var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/rule.json"))
	t._check(RuleCore.PRACTICES.size() == 12, "twelve practices")
	t._check(fx.chains.size() >= 10, "rule chains %d" % fx.chains.size())
	var data := TrialCore.load_data()
	var form := HubCore.new_form()
	form.wisdom = 14
	for chain in fx.chains:
		var a := RuleCore.normalize(chain.start)
		var st := TrialCore.empty_state()
		# Thresholds below the fall's gate are passed (the ladder asks
		# for gate N's threshold before gate N+1).
		st.trials = chain.get("startTrials", {}).duplicate()
		for i in chain.steps.size():
			var s: Dictionary = chain.steps[i]
			var tag := "%s #%d %s %s" % [chain.name, i, s.op, s.get("id", "")]
			match s.op:
				"practice":
					a = RuleCore.do_practice(a, s.id, s.opts)
				"meet":
					a = HubCore.record_meeting(a, s.id)
				"lift":
					st = TrialCore.lift_fall(data, st, a)
				"fall":
					st = TrialCore.choose_trial(data, st, s.gate, s.option,
						form, a).state
			_compare(t, tag, a, s.day, s.want)
			if s.want.has("status"):
				var fs := TrialCore.fall_status(data, st, a)
				var w: Dictionary = s.want.status
				t._check(fs.fallen == w.fallen
					and fs.get("sober", false) == w.sober
					and fs.get("taught", false) == w.taught
					and fs.get("can_lift", false) == w.canLift,
					tag + " status %s vs %s" % [fs, w])
				t._check((st.fall == null) == (s.want.fall == null),
					tag + " fall kept/dropped")
	# The five deeds a mission asks are the same deeds of the rule.
	var day := "2026-09-30"
	for id in ["alms", "forgive", "obedience", "fast", "secret_deed"]:
		var a := RuleCore.normalize({})
		var b := RuleCore.normalize({})
		for d in [day, day, "2026-10-01", "bad"]:
			a = RuleCore.do_practice(a, id, {"day": d})
			b = RuleCore.normalize(MissionCore.do_practice(b, id, d))
			t._check(_same(a, b), "mission deed %s on %s" % [id, d])
	# The watch never touches FORM and never pays: do_practice has no
	# form at all, and the tally of the secret deed shows no number.
	var secret := RuleCore.practice_tally(RuleCore.do_practice({},
		"secret_deed", {"day": day}), "secret_deed")
	t._check(not secret.shown and not secret.has("value"), "secret unshown")
	t._check(RuleCore.practice("communion").is_empty()
		and RuleCore.practice("confession").is_empty(),
		"no sacrament among the practices (TABOO 0.26)")
