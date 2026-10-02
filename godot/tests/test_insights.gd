## Insights (InsightCore, docs/HLD_INSIGHTS_FLASHBACKS_2026-10-02.md):
## the twelve of episode 1 keep their rules; each factor calls its own
## insight and nothing else does; the holy beat, the cold open and the
## cooldown hold them back; the hands must pull a full second and the
## eyes rest 0.8 s to skip; the pilot scene plays the ones its path
## calls and stops its clock while they play.  Called from
## run_hub_tests.gd.
extends RefCounted


func _ctx(over: Dictionary) -> Dictionary:
	var c := {"t": 100.0, "world": "lake", "beat": "immersion",
		"depth": 40.0, "events": [], "stage": "prilog", "still_s": 0.0,
		"look_s": {}, "shown": [], "since_last": INF, "busy": false}
	c.merge(over, true)
	return c


func _due(d: Dictionary, over: Dictionary) -> String:
	return str(InsightCore.due(d, _ctx(over)).get("id", ""))


func run(t: Object) -> void:
	var d := InsightCore.load_data()
	var pilot := PilotCore.load_data()
	t._check(not d.is_empty(), "insights load")
	var bad := InsightCore.check(d, pilot)
	t._check(bad.is_empty(), "the twelve keep their rules: %s" % [bad])
	t._check(d.insights.size() == 12, "12 insights in episode 1")
	var factors := {}
	for x in d.insights:
		factors[x.factor] = true
	t._check(factors.size() >= 6,
		"at least six factors call them (%d)" % factors.size())

	# Each factor calls its own.
	t._check(_due(d, {"t": 56.0}) == "ink_first_line", "the clock calls")
	t._check(_due(d, {"t": 12.0, "world": "room",
		"look_s": {"bazaar_jug": 1.3}}) == "bazaar_jug",
		"the place held in view calls")
	t._check(_due(d, {"t": 12.0, "world": "room",
		"look_s": {"bazaar_jug": 0.5}}) == "",
		"a glance at the place does not")
	t._check(_due(d, {"t": 14.0, "world": "room",
		"events": ["look:Logbook", "beat:water_rises", "clue:backup"]})
		== "tape_at_night", "the order of finds calls")
	t._check(_due(d, {"t": 14.0, "world": "room",
		"events": ["clue:backup", "look:Logbook"]}) == "",
		"the same finds in the other order do not")
	t._check(_due(d, {"t": 190.0, "depth": 50.2}) == "ford_of_cold",
		"the depth of the layer calls")
	t._check(_due(d, {"t": 190.0, "depth": 49.0}) == "",
		"above the layer nothing")
	t._check(_due(d, {"t": 450.0, "events": ["look:Drams"]})
		== "purse_at_the_gate", "the lure under the lens calls")
	t._check(_due(d, {"t": 500.0, "stage": "captive"})
		== "gate_opened_inside", "a captive thought calls the traitor")
	t._check(_due(d, {"t": 500.0, "stage": "stillness"})
		== "bread_in_siege", "a turn away calls the bread")
	t._check(_due(d, {"t": 730.0, "beat": "diary", "still_s": 5.2})
		== "scribe_lifts_eyes", "stillness over the diary calls")
	t._check(_due(d, {"t": 730.0, "beat": "diary", "still_s": 2.0})
		== "", "a restless head does not")

	# What holds them back.
	t._check(_due(d, {"t": 650.0, "beat": "khachkar", "stage": "captive"})
		== "", "no insight at the khachkar")
	t._check(_due(d, {"t": 8.0, "world": "room",
		"look_s": {"bazaar_jug": 3.0}}) == "", "none in the cold open")
	t._check(_due(d, {"t": 56.0, "since_last": 5.0}) == "",
		"none within the cooldown")
	t._check(_due(d, {"t": 56.0, "busy": true}) == "",
		"none under the glasses")
	t._check(_due(d, {"t": 56.0, "shown": ["ink_first_line"]}) == "",
		"each once")
	t._check(_due(d, {"t": 75.0}) == "", "a window once shut stays shut")
	var holy := false
	for x in d.insights:
		for e in x.trigger.get("after", []):
			if "hachkar" in str(e):
				holy = true
	t._check(not holy, "the holy calls no insight")

	# Same input, same insights (no randomness).
	var a := _due(d, {"t": 500.0, "stage": "captive"})
	var b := _due(d, {"t": 500.0, "stage": "captive"})
	t._check(a == b, "the same path gives the same insight")

	# The skip: a full second of the stick, both grips, or 0.8 s of gaze.
	var cfg: Dictionary = d.skip
	var sk := {}
	var r := {}
	for i in 9:
		r = InsightCore.skip_step(sk, cfg, 0.1, {"stick": 0.9})
		sk = r.state
	t._check(not r.skip, "0.9 s of the stick does not skip")
	r = InsightCore.skip_step(sk, cfg, 0.1, {"stick": 0.9})
	t._check(r.skip, "a full second of the stick skips")
	sk = {}
	for i in 20:
		r = InsightCore.skip_step(sk, cfg, 0.1, {"stick": 0.4})
		sk = r.state
	t._check(not r.skip, "a light touch of the stick never skips")
	sk = {}
	for i in 6:
		r = InsightCore.skip_step(sk, cfg, 0.1, {"stick": 0.9})
		sk = r.state
	r = InsightCore.skip_step(sk, cfg, 0.1, {"stick": 0.0})
	t._check(r.state.stick_s == 0.0, "letting go starts the pull again")
	sk = {}
	for i in 8:
		r = InsightCore.skip_step(sk, cfg, 0.1, {"icon": true})
		sk = r.state
	t._check(r.skip, "the eyes resting 0.8 s on the icon skip")
	sk = {}
	for i in 10:
		r = InsightCore.skip_step(sk, cfg, 0.1, {"grips": true})
		sk = r.state
	t._check(r.skip, "both grips held a second skip")
	var at := InsightCore.icon_at(cfg, Vector3(0, 1.6, 0),
		Vector3(0, 0, -1))
	t._check(at.y < 1.6 and at.x > 0.0 and at.z < 0.0,
		"the icon hangs low, right, ahead (%s)" % [at])
	_scene(t)


func _scene(t: Object) -> void:
	var p: Node = (load("res://scenes/pilot.tscn") as PackedScene) \
		.instantiate()
	p.replay = true
	p.stay = true
	p.save_path = "user://pilot_test_insights.json"
	t.root.add_child(p)
	if p.data.is_empty():
		p._ready()
	var guard := 0
	while p.insight.is_empty() and p.t < 60.0 and guard < 2000:
		guard += 1
		p._process(0.1)
	t._check(str(p.insight.get("id", "")) == "ink_first_line",
		"in the scene the clock calls the first insight (%s)"
		% [p.insight.get("id", "")])
	var at: float = p.t
	for i in 10:
		p._process(0.1)
	t._check(absf(p.t - at) < 0.001, "the clock stands while it plays")
	t._check(p.veil.visible and p.skip_icon.visible,
		"the veil and the skip icon are up")
	p.skip_override = {"stick": 1.0}
	for i in 11:
		p._process(0.1)
	t._check(p.insight.is_empty() and "ink_first_line" in p.skipped,
		"a second of the stick skips it in the scene")
	t._check(not p.veil.visible and p.ins_duck == 0.0,
		"after the skip the veil is gone and the sound is back")
	p.skip_override = {}
	p.queue_free()
