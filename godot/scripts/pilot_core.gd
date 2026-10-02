## Episode 1 of "The Water Atlas", "Taboo": the first fifteen minutes
## as a series pilot (CLAUDE.md TABOO 0.015,
## docs/story/PILOT_EPISODE_1_TABU_2026-10-02.md).
##
## The rhythm lives in godot/data/pilot-1.json: 18 beats over 900 s,
## each with the question it leaves the viewer.  check() fails the build
## when a hook is more than max_hook_gap_s away from the last, when the
## cold open needs more than 10 s, when a holy beat carries a message,
## a taboo or a jolt, or when a line holds a church word.
##
## The player's taboo is read from the body, not from words or eyes (a
## Quest 3S has no eye tracking and the headset's voice input is off,
## TABOO 0.26 item 9): the head holding the lure in a 12 degree cone,
## the hand reaching it, the head turned away, three breaths on the
## rope.  These drive the same ladder of a thought as PassionCore
## (prilog, converse, consent, captive; stillness, virtue), so the
## pilot adds no attribute and no randomness (Constitution).
class_name PilotCore
extends RefCounted

const DATA := "res://data/pilot-1.json"
const COLD_OPEN_MAX_S := 10.0
const DETAILS := "res://data/pilot-details.json"
## What a detail may do at the holy: dip the machine, dim the light,
## settle the murk, leave the line empty (TABOO 0.4 item 2).
const QUIET := ["duck", "lamp", "fog", "line"]
const PRIMS := ["say", "line", "lamp", "flicker", "haptic", "sfx", "duck",
	"fog", "move", "show", "hide", "water"]


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


## The beat playing at time t: the last one that has begun.
static func beat_at(data: Dictionary, t: float) -> Dictionary:
	var cur := {}
	for b in data.beats:
		if float(b.t) <= t:
			cur = b
	return cur


## The longest stretch without a new question, end of episode included.
static func longest_gap(data: Dictionary) -> float:
	var last := 0.0
	var gap := 0.0
	for b in data.beats:
		gap = maxf(gap, float(b.t) - last)
		last = float(b.t)
	return maxf(gap, float(data.length_s) - last)


## Every rule the episode breaks; empty when it is sound.
static func check(data: Dictionary) -> Array:
	var bad := []
	if data.is_empty() or data.get("beats", []).is_empty():
		return ["no beats"]
	if float(data.beats[0].t) > COLD_OPEN_MAX_S:
		bad.append("cold open starts after %d s" % int(data.beats[0].t))
	if longest_gap(data) > float(data.max_hook_gap_s):
		bad.append("a hook gap of %d s" % int(longest_gap(data)))
	var prev := -1.0
	var cuts := 0
	var ids := {}
	for b in data.beats:
		if float(b.t) <= prev:
			bad.append("beat %s is out of order" % b.id)
		prev = float(b.t)
		if ids.has(b.id):
			bad.append("beat %s twice" % b.id)
		ids[b.id] = true
		if str(b.get("hook_ru", "")) == "":
			bad.append("beat %s leaves no question" % b.id)
		if str(b.get("sound", "")) == "":
			# Beyond the 96 degree field of view only sound reaches.
			bad.append("beat %s has no sound anchor" % b.id)
		if b.get("hard_cut", false):
			cuts += 1
		if b.get("holy", false):
			# At the holy the world goes quiet: no lure, no message,
			# no jolt, no cut (TABOO 0.4 item 2, TABOO 0.015 item 5).
			for k in ["taboo", "message_ru", "haptic", "hard_cut"]:
				if b.has(k):
					bad.append("holy beat %s carries %s" % [b.id, k])
		for k in ["hook_ru", "message_ru", "line_ru", "title_ru"]:
			var w := LocationsCore.church_word(str(b.get(k, "")))
			if w != "":
				bad.append("beat %s says «%s»" % [b.id, w])
	# The Cloud Atlas idea, kept plain (TABOO 0.015 item 8): the eras
	# nest, the first minute says who reads whom, and an era's story
	# breaks off in the middle of a word.
	if data.get("nesting", []).size() < 2:
		bad.append("no nesting of eras")
	var reads := false
	var broken := false
	for b in data.beats:
		if b.get("reads", false) and float(b.t) <= 60.0:
			reads = true
		if b.get("broken", false) and str(b.get("line_ru", "")).ends_with(
				"—"):
			broken = true
	if not reads:
		bad.append("the first minute does not say who reads whom")
	if not broken:
		bad.append("no story breaks off mid-word")
	if cuts > int(data.comfort.hard_cuts):
		bad.append("%d hard cuts, %d allowed" % [cuts,
			int(data.comfort.hard_cuts)])
	for k in data.choice_echo:
		var w := LocationsCore.church_word(str(
			data.choice_echo[k].get("message_ru", "")))
		if w != "":
			bad.append("echo %s says «%s»" % [k, w])
	return bad


## Is the target in the head's cone?  Head gaze, not eye gaze.
static func gaze_on(forward: Vector3, to_target: Vector3,
		cone_deg: float) -> bool:
	if forward.is_zero_approx() or to_target.is_zero_approx():
		return false
	return rad_to_deg(forward.angle_to(to_target)) <= cone_deg


static func body_start() -> Dictionary:
	return {"gaze_s": 0.0, "away_s": 0.0, "breaths": 0}


## The step of the ladder the body has taken, or "" while it waits.
static func body_option(stage: String, body: Dictionary,
		hand_m: float, cfg: Dictionary) -> String:
	var away: bool = float(body.away_s) >= float(cfg.turn_after_s)
	match stage:
		"prilog":
			if away:
				return "turn"
			if float(body.gaze_s) >= float(cfg.look_after_s):
				return "look"
		"converse":
			if away:
				return "stop"
			if float(body.gaze_s) >= float(cfg.answer_after_s):
				return "answer"
		"consent":
			if away:
				return "remember"
			if hand_m <= float(cfg.take_within_m):
				return "take"
		"stillness":
			if int(body.breaths) >= int(cfg.still_breaths):
				return "still"
	return ""


## One frame of the taboo.  inp: gaze (bool), away_deg (float), hand_m
## (float, metres from hand or arm to the lure), exhale (bool, a breath
## finished on the rope this frame).  Returns state, body and the option
## taken ("" when none).  The counters start again at every new stage,
## so a look that led on is not counted twice.
static func taboo_step(state: Dictionary, passion: Dictionary,
		body: Dictionary, cfg: Dictionary, dt: float,
		inp: Dictionary) -> Dictionary:
	var b := body.duplicate()
	var looking: bool = inp.get("gaze", false)
	b.gaze_s = float(b.gaze_s) + dt if looking else 0.0
	var turned: bool = float(inp.get("away_deg", 0.0)) \
		>= float(cfg.turn_away_deg)
	b.away_s = float(b.away_s) + dt if turned else 0.0
	if inp.get("exhale", false):
		b.breaths = int(b.breaths) + 1
	var opt := body_option(str(state.get("stage")), b,
		float(inp.get("hand_m", INF)), cfg)
	var s := state
	if opt != "":
		s = PassionCore.choose(state, opt, passion, {}, {})
		if s.get("stage") != state.get("stage"):
			b = body_start()
	return {"state": s, "body": b, "option": opt}


## What the Prior and the scribe answer at the choice_echo beat, and
## which variant episode 2 opens with.  Fixed by the stage reached.
static func echo(data: Dictionary, stage: String) -> Dictionary:
	if stage == "captive":
		return data.choice_echo.captive
	if stage == "virtue":
		return data.choice_echo.virtue
	return data.choice_echo.unresolved


## The details of godot/data/pilot-details.json, each with "t", its
## second on the episode's clock, in the order they fire.
static func load_details(data: Dictionary) -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DETAILS))
	if not d is Dictionary:
		return []
	var start := {}
	for b in data.beats:
		start[b.id] = float(b.t)
	var out := []
	for x in d.chosen:
		var y: Dictionary = x.duplicate(true)
		y["t"] = start.get(x.beat, 0.0) + float(x.at)
		out.append(y)
	out.sort_custom(func(a, b): return a.t < b.t or (a.t == b.t
		and a.id < b.id))
	return out


static func _prim(p: Dictionary) -> String:
	for k in PRIMS:
		if p.has(k):
			return k
	return ""


## Every rule a set of details breaks; empty when they are sound.
static func check_details(data: Dictionary, details: Array) -> Array:
	var bad := []
	var beats := {}
	for b in data.beats:
		beats[b.id] = b
	for d in details:
		if not beats.has(d.beat):
			bad.append("%s: no beat %s" % [d.id, d.beat])
			continue
		var holy: bool = beats[d.beat].get("holy", false)
		for p in d["do"]:
			var k := _prim(p)
			if k == "":
				bad.append("%s: unknown primitive" % d.id)
			elif holy and not k in QUIET:
				bad.append("%s: %s at the holy" % [d.id, k])
			elif holy and k == "line" and str(p.line) != "":
				bad.append("%s: words at the holy" % d.id)
			if k in ["say", "line"]:
				var w := LocationsCore.church_word(str(p[k]))
				if w != "":
					bad.append("%s says «%s»" % [d.id, w])
	return bad


## A clue of the room is seen (Pandora's look under the table and up at
## the ceiling, done with the body; docs/HLD_PANDORA_SURPASS_2026-10-02.md
## V1): the head within range and the clue in its cone, and for "under"
## the eyes low enough, for "over" the head tipped up far enough.  Only
## geometry: the own engine has no physics to cast rays with.
static func clue_seen(head: Vector3, forward: Vector3,
		clue: Dictionary) -> bool:
	var pos: Array = clue.pos
	var to := Vector3(pos[0], pos[1], pos[2]) - head
	if to.length() > float(clue.range_m):
		return false
	if not gaze_on(forward, to, float(clue.cone_deg)):
		return false
	match str(clue.need):
		"under":
			return head.y <= float(clue.max_eye_y)
		"over":
			var pitch := rad_to_deg(asin(clampf(forward.normalized().y,
				-1.0, 1.0)))
			return pitch >= float(clue.min_pitch_deg)
	return true


## The laws of the four classes of finds (docs/HLD_PANDORA_SURPASS_
## 2026-10-02.md §7): the holy has no line, no hand and no count; an
## effort is found by the body (a clue with "under" or "over"); and no
## class but a deed towards another feeds the path: bending the body is
## knowing, not a virtue scored (TABOO 0.35 item 16), and leaving the
## holy alone is not a bonus.
static func check_finds(data: Dictionary) -> Array:
	var bad := []
	var classes: Dictionary = data.get("find_classes", {})
	var clue_ids := {}
	for c in data.get("clues", []):
		clue_ids[c.id] = c
	for f in data.get("finds", []):
		var k: Dictionary = classes.get(f["class"], {})
		if k.is_empty():
			bad.append("%s: no class %s" % [f.id, f["class"]])
			continue
		if k.get("path", false):
			bad.append("%s: class %s feeds the path" % [f.id, f["class"]])
		if f["class"] == "holy" and (k.get("line", false)
				or k.get("examine", false)):
			bad.append("%s: the holy is handled or labelled" % f.id)
		if f["class"] == "effort":
			var c: Dictionary = clue_ids.get(f.id, {})
			if not str(c.get("need", "")) in ["under", "over"]:
				bad.append("%s: an effort without the body" % f.id)
	for deed in data.get("path_deeds", []):
		for f in data.get("finds", []):
			if str(deed).begins_with(str(f.id).to_lower()):
				bad.append("path deed %s is a find, not a deed" % deed)
	return bad
