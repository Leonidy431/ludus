## The pilot scene (phase P2, docs/HLD_20MB_PILOT_2026-10-02.md) played
## through at a coarse clock, twice: a body that looks, holds and
## reaches ends captive, a body that turns away and breathes ends in
## stillness and virtue.  Every beat is entered in order, the console
## is out at the khachkar, the comet is on the hand, the title shows,
## the record is written.  Called from run_hub_tests.gd.
extends RefCounted

const LOOK := {"gaze": true, "away_deg": 2.0, "hand_m": 2.0}
const REACH := {"gaze": true, "away_deg": 2.0, "hand_m": 0.1}
const AWAY := {"gaze": false, "away_deg": 120.0, "hand_m": 3.0}
const IDLE := {"gaze": false, "away_deg": 30.0, "hand_m": 3.0}


func _play(t: Object, body: String) -> Node:
	var p: Node = (load("res://scenes/pilot.tscn") as PackedScene) \
		.instantiate()
	p.replay = true
	p.stay = true
	p.save_path = "user://pilot_test_%s.json" % body
	t.root.add_child(p)
	if p.data.is_empty():
		# Under _initialize the tree has not started, so _ready waits;
		# it is called here once, as the tree would.
		p._ready()
	var dt := 0.1
	var guard := 0
	var console_at_khachkar := -1.0
	var breaths := 0
	while not p.finished and guard < 20000:
		guard += 1
		var at: float = p.t
		if p.beat_id in ["lure", "price_rises"]:
			if body == "fall":
				p.override = REACH if at > 447.0 else LOOK
			else:
				var ex := at > 445.0 and breaths < 3 \
					and int(at * 10.0) % 10 == 0
				if ex:
					breaths += 1
				p.override = AWAY.merged({"exhale": ex})
		else:
			p.override = IDLE
		p._process(dt)
		if p.beat_id == "khachkar" and p.t > 645.0 \
				and console_at_khachkar < 0.0:
			console_at_khachkar = p.console_level
	p.set_meta("console_at_khachkar", console_at_khachkar)
	return p


func run(t: Object) -> void:
	var d := PilotCore.load_data()
	var ids: Array[String] = []
	for b in d.beats:
		ids.append(b.id)
	for body in ["fall", "keep"]:
		var p := _play(t, body)
		t._check(p.reached == ids, "%s: every beat in order" % body)
		t._check(float(p.get_meta("console_at_khachkar")) == 0.0,
			"%s: the console is out at the khachkar" % body)
		t._check(p.khachkar.get_meta("noInteract", false)
			and p.khachkar.get_meta("noLoot", false),
			"%s: the khachkar is noInteract and noLoot" % body)
		t._check(p.mark.visible, "%s: the comet is on the hand" % body)
		t._check(p.title.visible and p.title.text == "АТЛАС ВОДЫ · СЕРИЯ 1 · ТАБУ",
			"%s: the title" % body)
		t._check(p.world == "room", "%s: it ends in the room" % body)
		t._check(not p.lake.visible, "%s: the lake is gone" % body)
		var rec = JSON.parse_string(FileAccess.get_file_as_string(
			p.save_path))
		t._check(rec is Dictionary and rec.seen, "%s: the record" % body)
		if body == "fall":
			t._check(p.state.stage == "captive", "fall: captive")
			t._check(rec.episode2 == "order_first",
				"fall: the Order gets the coordinates")
		else:
			t._check(p.state.stage == "virtue", "keep: virtue")
			t._check(rec.episode2 == "scribe_first",
				"keep: the drams go to the scribe")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
			p.save_path))
		p.queue_free()
	gravity(t)
	scene_clues(t)
	wrist(t)
	# The details fired in the run: all 55 on the clock.
	var last := _play(t, "keep")
	t._check(last.fired.size() == 55, "every detail fired (%d)"
		% last.fired.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		last.save_path))
	last.queue_free()
	# The lake lights only what the beats name: no shine before the lure.
	var code := FileAccess.get_file_as_string("res://scripts/pilot.gd")
	t._check(not "change_scene_to_file" in code,
		"the pilot goes on through ModuleLoader only")
	t._check(not "randf" in code and not "randi" in code,
		"no randomness in the pilot")


## Gravity (TABOO 0.016 item 3): every thing set down lies on its
## surface within 5 mm, measured again from its vertices; the echo is
## 30-60 % smaller than its source and tipped; the holy is never echoed.
func gravity(t: Object) -> void:
	var p: Node = (load("res://scenes/pilot.tscn") as PackedScene) \
		.instantiate()
	p.replay = true
	p.stay = true
	t.root.add_child(p)
	if p.data.is_empty():
		p._ready()
	t._check(p.grounded.size() >= 12, "things are set down (%d)"
		% p.grounded.size())
	for g in p.grounded:
		if not is_instance_valid(g.node):
			# Merged into the still furniture: it was measured when set.
			continue
		var gap: float = p.bottom_of(g.node) - float(g.surface)
		t._check(absf(gap) <= 0.005, "%s rests on its surface (%.4f m)"
			% [g.name, gap])
	for e in p.ECHO:
		var s: float = e[2]
		t._check(s >= 0.4 and s <= 0.7, "%s is 30-60 %% smaller" % e[0])
		var n: Node3D = p.things[e[0]]
		t._check(absf(n.rotation.x) > 0.05 or absf(n.rotation.z) > 0.05,
			"%s lies tipped" % e[0])
		t._check(p._tip(e[0]) == p._tip(e[0]), "%s tips the same way"
			% e[0])
	t._check(not "Khachkar" in p.things.keys(),
		"the holy is not a thing the details move or echo")
	var details := PilotCore.load_details(p.data)
	t._check(details.size() == 55, "55 details")
	t._check(PilotCore.check_details(p.data, details).is_empty(),
		"the details keep the rules: %s"
		% [PilotCore.check_details(p.data, details)])
	p.queue_free()


## The scene finds a clue when the head is held on it, once.
func scene_clues(t: Object) -> void:
	var p: Node = (load("res://scenes/pilot.tscn") as PackedScene) \
		.instantiate()
	p.replay = true
	p.stay = true
	t.root.add_child(p)
	if p.data.is_empty():
		p._ready()
	var low := Vector3(0, 0.7, 0)
	p.clue_override = {"head": low,
		"forward": Vector3(0.05, 0.70, -1.15) - low}
	for i in 12:
		p.override = {"gaze": false}
		p._process(0.1)
	t._check("backup" in p.clues_found, "the drive is found crouching")
	t._check(p.line.text.begins_with("Под столом"), "its line is written")
	p.clue_override = {"head": Vector3(0, 1.2, 0), "forward":
		Vector3(0.35, 1.4, -0.7)}
	for i in 12:
		p._process(0.1)
	t._check("stain" in p.clues_found, "the stain is found looking up")
	t._check(p.clues_found.size() == 2, "each clue is found once")
	p.queue_free()


## In the headset the Prior's words are on the wrist, not on the eyes.
func wrist(t: Object) -> void:
	var p: Node = (load("res://scenes/pilot.tscn") as PackedScene) \
		.instantiate()
	p.replay = true
	p.stay = true
	t.root.add_child(p)
	if p.data.is_empty():
		p._ready()
	t._check(p.screen.get_parent() == p.camera,
		"on a screen the console stays before the eyes")
	p.xr_active = true
	p._place_console()
	t._check(p.screen.get_parent() == p.left_hand,
		"in the headset the console is on the left wrist")
	p.queue_free()
