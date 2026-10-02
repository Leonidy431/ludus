## Episode 1 "Taboo" (PilotCore, TABOO 0.015): the rhythm of a series
## pilot holds (cold open under 10 s, no stretch without a question over
## 90 s, one hard cut, quiet at the holy, no church words), and the
## body's taboo walks the ladder of a thought the same way every time.
## Called from run_hub_tests.gd.
extends RefCounted


func _passion(id: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/passions.json"))
	for p in d.passions:
		if p.id == id:
			return p
	return {}


func _run(t: Object, p: Dictionary, cfg: Dictionary, frames: Array) -> Dictionary:
	var st := PassionCore.start(p)
	var body := PilotCore.body_start()
	for f in frames:
		for i in int(f.n):
			var r := PilotCore.taboo_step(st, p, body, cfg, 0.1, f.inp)
			st = r.state
			body = r.body
	return st


func run(t: Object) -> void:
	var d := PilotCore.load_data()
	t._check(not d.is_empty(), "pilot data loads")
	var bad := PilotCore.check(d)
	t._check(bad.is_empty(), "the pilot keeps its rules: %s" % [bad])
	t._check(d.beats.size() == 18, "18 beats")
	t._check(PilotCore.longest_gap(d) <= 90.0,
		"no stretch over 90 s without a question (%d s)"
		% int(PilotCore.longest_gap(d)))
	t._check(PilotCore.beat_at(d, 0.0).id == "drop", "the pilot opens cold")
	t._check(PilotCore.beat_at(d, 300.0).id == "tether_jerk",
		"at 5:00 the tether jerks")
	t._check(PilotCore.beat_at(d, 899.0).id == "prior_last",
		"the last message before the title")
	t._check(PilotCore.beat_at(d, 9999.0).id == "title", "the title ends it")

	# The check catches what it guards.
	var slow := d.duplicate(true)
	slow.beats.remove_at(4)
	slow.beats.remove_at(4)
	t._check(not PilotCore.check(slow).is_empty(),
		"a two-beat hole fails the check")
	var late := d.duplicate(true)
	late.beats[0].t = 30
	t._check(not PilotCore.check(late).is_empty(), "a late cold open fails")
	var loud := d.duplicate(true)
	for b in loud.beats:
		if b.get("holy", false):
			b["message_ru"] = "ЦЕНА"
	t._check(not PilotCore.check(loud).is_empty(),
		"a message at the holy fails")
	var cuts := d.duplicate(true)
	cuts.beats[2]["hard_cut"] = true
	t._check(not PilotCore.check(cuts).is_empty(), "a second hard cut fails")
	var word := d.duplicate(true)
	word.beats[1].hook_ru = "Где икона?"
	t._check(not PilotCore.check(word).is_empty(), "a church word fails")

	# Head gaze in a 12 degree cone.
	var c: float = d.taboo.gaze_cone_deg
	t._check(PilotCore.gaze_on(Vector3.FORWARD, Vector3(0.1, 0, -1), c),
		"6 degrees off is looking")
	t._check(not PilotCore.gaze_on(Vector3.FORWARD, Vector3(0.3, 0, -1), c),
		"17 degrees off is not")
	t._check(not PilotCore.gaze_on(Vector3.ZERO, Vector3.FORWARD, c),
		"no head, no gaze")

	# The ladder by the body.
	var p := _passion(d.taboo.passion)
	t._check(not p.is_empty(), "the pilot's passion exists")
	var cfg: Dictionary = d.taboo
	var look := {"gaze": true, "away_deg": 0.0, "hand_m": 2.0}
	var away := {"gaze": false, "away_deg": 90.0, "hand_m": 2.0}
	var reach := {"gaze": true, "away_deg": 0.0, "hand_m": 0.1}
	var breath := {"gaze": false, "away_deg": 90.0, "exhale": true}
	t._check(_run(t, p, cfg, [{"n": 19, "inp": look}]).stage == "prilog",
		"1.9 s of looking is still a prilog")
	t._check(_run(t, p, cfg, [{"n": 21, "inp": look}]).stage == "converse",
		"2.1 s of looking is a converse")
	var fallen := _run(t, p, cfg, [{"n": 21, "inp": look},
		{"n": 31, "inp": look}, {"n": 1, "inp": reach}])
	t._check(fallen.stage == "captive", "look, hold, reach: captive")
	t._check(PilotCore.echo(d, fallen.stage).episode2 == "order_first",
		"the captive gives the Order the coordinates")
	var kept := _run(t, p, cfg, [{"n": 16, "inp": away},
		{"n": 3, "inp": breath}])
	t._check(kept.stage == "virtue", "turn away, three breaths: virtue")
	t._check(kept.turnedAtPrilog, "turned at the prilog")
	t._check(PilotCore.echo(d, kept.stage).episode2 == "scribe_first",
		"the drams go to the scribe")
	var late_turn := _run(t, p, cfg, [{"n": 21, "inp": look},
		{"n": 31, "inp": look}, {"n": 16, "inp": away}])
	t._check(late_turn.stage == "stillness",
		"turning away at the consent still leads to stillness")
	var waiting := _run(t, p, cfg, [{"n": 21, "inp": look},
		{"n": 10, "inp": {"gaze": false, "away_deg": 20.0}}])
	t._check(PilotCore.echo(d, waiting.stage).episode2 == "prior_waits",
		"an open thought: the Prior waits")
	# A glance that breaks resets: two 1.5 s looks are not one 3 s look.
	var glances := _run(t, p, cfg, [{"n": 15, "inp": look},
		{"n": 1, "inp": {"gaze": false}}, {"n": 15, "inp": look}])
	t._check(glances.stage == "prilog", "broken glances do not add up")
	# Same body, same end: deterministic.
	var again := _run(t, p, cfg, [{"n": 21, "inp": look},
		{"n": 31, "inp": look}, {"n": 1, "inp": reach}])
	t._check(again == fallen, "the same body gives the same ladder")
