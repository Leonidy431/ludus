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
	t._check(PilotCore.check(word).is_empty(),
		"a church word is allowed now (lifted by the operator)")
	t._check(LocationsCore.find_church_word("Где икона?") != "",
		"the stop-list still finds it")

	var flat := d.duplicate(true)
	for b in flat.beats:
		b.erase("broken")
	t._check(not PilotCore.check(flat).is_empty(),
		"a story that does not break off fails")
	var nobody := d.duplicate(true)
	for b in nobody.beats:
		b.erase("reads")
	t._check(not PilotCore.check(nobody).is_empty(),
		"a first minute without who reads whom fails")

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
	clues(t)
	var nr := PilotCore.load_narration()
	var tr := PilotCore.load_i18n()
	for lg in ["en", "de", "fr", "es", "it"]:
		var missing := 0
		for g in ["beats", "objects"]:
			for k in nr[g]:
				var ru := str(nr[g][k].get("line_ru", ""))
				var x := PilotCore.narration_text(nr, tr, g, k, lg)
				if ru != "" and (x == ru or x.length() > 140):
					missing += 1
				if ru == "" and x != "":
					missing += 1
		t._check(missing == 0, "narration in %s: every line, silent at "
			% lg + "the holy, ≤ 140 (%d off)" % missing)
	var nb := PilotCore.check_narration(d, PilotCore.load_narration())
	t._check(nb.is_empty(), "the narrator's lines keep TABOO 0.020: %s"
		% [nb])
	var spoken := PilotCore.load_narration().duplicate(true)
	spoken.beats.khachkar.line_ru = "Камень говорит."
	t._check(not PilotCore.check_narration(d, spoken).is_empty(),
		"a narrator at the holy fails")
	t._check(PilotCore.check_ads(d).is_empty(), "the ad slot is a "
		+ "placeholder without brands: %s" % [PilotCore.check_ads(d)])
	var brand := d.duplicate(true)
	brand.ad_slots[0].text_en = "DRINK FIZZCOLA"
	t._check(not PilotCore.check_ads(brand).is_empty(),
		"a brand on the slot fails")
	var fb := PilotCore.check_finds(d)
	t._check(fb.is_empty(), "the classes of finds keep their laws: %s"
		% [fb])
	var cheat := d.duplicate(true)
	cheat.find_classes.holy["path"] = true
	t._check(not PilotCore.check_finds(cheat).is_empty(),
		"leaving the holy alone may not feed the path")
	var bow := d.duplicate(true)
	bow.find_classes.effort["path"] = true
	t._check(not PilotCore.check_finds(bow).is_empty(),
		"bending the body may not score a virtue")


## Pandora V1: the clues under the table and on the ceiling are found by
## the body only.
func clues(t: Object) -> void:
	var d := PilotCore.load_data()
	var under: Dictionary = d.clues[0]
	var over: Dictionary = d.clues[1]
	var to_drive := Vector3(0.05, 0.70, -1.15)
	var seated := Vector3(0, 1.2, 0)
	var low := Vector3(0, 0.7, 0)
	t._check(not PilotCore.clue_seen(seated, to_drive - seated, under),
		"sitting up, the drive under the table is not seen")
	t._check(PilotCore.clue_seen(low, to_drive - low, under),
		"crouched and looking under, it is")
	t._check(not PilotCore.clue_seen(low, Vector3.BACK, under),
		"crouched but looking away, it is not")
	var stain := Vector3(0.35, 2.6, -0.7)
	t._check(PilotCore.clue_seen(seated, stain - seated, over),
		"head up at the ceiling: the stain is seen")
	t._check(not PilotCore.clue_seen(seated, Vector3(0.35, 1.0, -0.7)
		- seated, over), "looking level: not seen")
	for c in d.clues:
		t._check(LocationsCore.church_word(str(c.line_ru)) == "",
			"clue %s has no church word" % c.id)
