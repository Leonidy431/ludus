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
	var music_at_khachkar := 0.0
	var cues := {}
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
		cues[p.beat_id] = p.music.cue_id
		if p.beat_id == "khachkar" and p.t > 645.0 \
				and console_at_khachkar < 0.0:
			console_at_khachkar = p.console_level
			music_at_khachkar = p.music_player.volume_db
		if p.wow.current.get("level", 0) > int(p.get_meta("wow_max", 0)):
			p.set_meta("wow_max", p.wow.current.level)
		if p.beat_id == "khachkar":
			p.set_meta("wow_at_khachkar", p.wow.light.light_energy)
			# The last frame of the beat: the ramps have had their time.
			p.set_meta("water_at_khachkar", p.player.volume_db)
			p.set_meta("silence_at_khachkar", p.synth.silence)
	p.set_meta("console_at_khachkar", console_at_khachkar)
	p.set_meta("music_at_khachkar", music_at_khachkar)
	p.set_meta("cues", cues)
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
		t._check(float(p.get_meta("music_at_khachkar")) <= -59.0,
			"%s: the music goes down to -60 dB at the khachkar" % body)
		# The ascent keeps 10 m/min, the limit the console names.
		var keep_t: float = p.t
		var fastest := 0.0
		for i in range(800, 900):
			p.t = float(i)
			var a: float = p._depth()
			p.t = float(i) + 1.0
			fastest = maxf(fastest, (a - p._depth()) * 60.0)
		p.t = keep_t
		t._check(fastest <= DiveCore.MAX_ASCENT_M_PER_MIN + 0.01,
			"%s: the ascent is not faster than 10 m/min (%.1f)"
			% [body, fastest])
		# Room tone and breath stay: only the machine layer goes down.
		t._check(float(p.get_meta("water_at_khachkar", -99.0)) > -20.0,
			"%s: room tone and breath stay at the khachkar" % body)
		var said: Array = p.said_by_claud
		t._check(said.size() >= 5, "%s: Клауд speaks (%d lines)"
			% [body, said.size()])
		t._check(said.filter(func(x): return x.begins_with("khachkar/"))
			.is_empty(), "%s: Клауд is silent at the khachkar" % body)
		t._check(int(p.get_meta("wow_max", 0)) == 10,
			"%s: the wonder rises to level 10" % body)
		t._check(float(p.get_meta("wow_at_khachkar", 1.0)) == 0.0,
			"%s: no wonder at the khachkar" % body)
		# The synth is told: its own ramp then takes the machine layer
		# to -60 dB (DiveSynth.MACHINE_DUCKED, test_audio.gd).
		t._check(bool(p.get_meta("silence_at_khachkar", false)),
			"%s: the synth is told the khachkar's silence" % body)
		var cues: Dictionary = p.get_meta("cues")
		var heard := {}
		for b in cues:
			heard[cues[b]] = true
		t._check(heard.size() == 9 and cues.get("thermocline") == "VI"
			and cues.get("title") == "IX",
			"%s: the nine nodes of Entelechy sound across the episode: %s"
			% [body, cues])
		t._check(p.khachkar.get_meta("noInteract", false)
			and p.khachkar.get_meta("noLoot", false),
			"%s: the khachkar is noInteract and noLoot" % body)
		t._check(p.mark.visible, "%s: the comet is on the hand" % body)
		t._check("beats.drop" in p.narrated and "beats.title" in p.narrated,
			"%s: the narrator speaks from the drop to the title" % body)
		t._check(not "beats.khachkar" in p.narrated,
			"%s: the narrator is silent at the khachkar" % body)
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
	swap(t)
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


## The close-up swap: no glasses, no close-up in the room; the glasses
## are put on by looking at them; a close-up pauses the clock; the holy
## is never one; at the lure the lens is "look closer".
func swap(t: Object) -> void:
	t._check(PilotCore.check_examine(PilotCore.load_data()).is_empty(),
		"the close-ups keep their rules")
	var p: Node = (load("res://scenes/pilot.tscn") as PackedScene) \
		.instantiate()
	p.replay = true
	p.stay = true
	t.root.add_child(p)
	if p.data.is_empty():
		p._ready()
	var head := Vector3(0, 1.2, 0)
	var book: Vector3 = p._xf(p.things["Logbook"]).origin
	p.clue_override = {"head": head, "forward": book - head}
	p._examine(1.0)
	t._check(p.examining == "", "no glasses, no close-up")
	var gp: Array = p.data.glasses.pos
	p.clue_override = {"head": head, "forward": Vector3(gp[0], gp[1],
		gp[2]) - head}
	for i in 10:
		p._examine(0.1)
	t._check(p.glasses_on, "the glasses are put on by looking at them")
	p.clue_override = {"head": head, "forward": book - head}
	for i in 8:
		p._examine(0.1)
	t._check(p.examining == "Logbook", "in glasses the log comes close")
	var before: float = p.t
	for i in 5:
		p._process(0.1)
	t._check(p.t == before, "the clock waits during a close-up")
	p.close_examine()
	t._check(p.examining == "" and not p.close_up.visible,
		"the close-up closes")
	p._examine(1.0)
	t._check(p.examining == "", "and does not reopen until the eye leaves")
	# The memory cache of examine videos: kept two minutes, then freed.
	p.clip_cache["Fake"] = {"clip": {"frames": 1}, "idle": 0.0}
	p.age_clips(60.0)
	t._check(p.clip_cache.has("Fake"), "a clip stays a minute after")
	p.age_clips(61.0)
	t._check(not p.clip_cache.has("Fake"), "and leaves after two")
	t._check(p.cached_clip("Nothing").is_empty(),
		"no pack, no clip: the still stays")
	# Under water at the lure: the lens is "look closer".
	p.t = 445.0
	p._set_world("lake")
	p._sync()
	var dr: Vector3 = p._xf(p.things["Drams"]).origin
	p.clue_override = {"head": head, "forward": dr - head}
	for i in 8:
		p._examine(0.1)
	t._check(p.examining == "Drams", "the drams come close")
	t._check(p.state.stage == "converse",
		"looking at the lure through the lens is a converse")
	p.queue_free()
