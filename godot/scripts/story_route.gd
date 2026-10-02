## The 12 stories walked on foot (docs/HLD_12_STORIES_HEADSET_2026-10-02.md,
## phase S4, track D; the selection is docs/STORY_12_SELECTION_2026-10-02.md,
## written with data/story-12.json by scripts/story/select_12.py).
##
## A story is one mission of the campaign (MissionCore).  On the board of
## the courtyard every other mission is still read and pressed; a story's
## steps are done only at the hearts of its places: the board names where
## to go, the heart of that place shows the step, and its choice goes to
## MissionCore exactly as the board's does (the same view, the same
## choose and advance, the same FORM bonuses through apply_effects, the
## same fall).  This file is the route and that one shared path; it keeps
## no state of its own.
##
## A step reached by the dive (the dive step, and a find that lies only on
## the floor of the lake) is chosen at the heart, then the ROV goes down
## from there; the step closes on the way back, as the board's dive step
## closes with its "walk on".  That the ROV went down is kept as one more
## flag of the campaign state, "m<id>.dove.<step>": MissionCore keeps any
## flag of its known shape and reads only its own "m<id>.kept".  A fall
## closes the deep: while it holds, the ROV is not let down.
##
## Holy things are never a step's key (TABOO 0.2, 0.4 item 1): no route
## leads through one, and a holy thing has no panel at all.
##
## Constitution: FORM (the mission's places, people, things and water) ->
## ACTION (the player walks from the board to each place and does the step
## at its heart) -> GOAL (the act's teaching is lived in the headset).
class_name StoryRoute
extends RefCounted

const DATA := "res://data/story-12.json"
const DIVE_SCENE := "res://scenes/dive.tscn"
const HOW_RU := {"heart": "у сердца места", "thing": "у сердца места",
	"dive": "спуском аппарата от сердца места"}


static func load_data(path := DATA) -> Dictionary:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path)) \
		if FileAccess.file_exists(path) else null
	var by := {}
	if raw is Dictionary:
		for s in raw.get("stories", []):
			by[int(s.mission)] = s
	return {"stories": raw.get("stories", []) if raw is Dictionary else [],
		"by_mission": by}


## MissionCore's data from what the hearts already read (the trees, the
## lake and the passions), so a place does not parse them twice; only the
## spine is read here.  Same shape as MissionCore.load_data (the test
## compares them).
static func mission_data(trees: Dictionary, lake: Dictionary,
		passions: Dictionary) -> Dictionary:
	var spine: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/campaign-spine.json"))
	var acts := []
	for a in spine.acts:
		var ids := []
		for id in a.missions:
			ids.append(int(id))
		acts.append({"id": a.id, "title_ru": a.title_ru, "missions": ids})
	var titles := {}
	for m in spine.missions:
		titles[int(m.id)] = m.title
	var chorus := {}
	for m in spine.get("needsChorusRewrite", []):
		chorus[int(m.id)] = true
	var order := []
	for id in spine.order:
		order.append(int(id))
	return {"acts": acts, "titles": titles, "chorus": chorus, "order": order,
		"trees": trees, "lake": lake, "passions": passions}


static func story_of(story: Dictionary, mission_id) -> Dictionary:
	if mission_id == null:
		return {}
	return story.by_mission.get(int(mission_id), {})


## The campaign state as MissionCore reads it from a place's state: the
## road's keys (st.missions) with the thresholds and the fall (st.trials),
## as the hub's _mstate does.
static func mstate(st: Dictionary) -> Dictionary:
	var ms := MissionCore.normalize_state(st.get("missions", {}))
	var tr: Dictionary = st.get("trials", TrialCore.empty_state())
	ms.trials = tr.get("trials", {}).duplicate()
	ms.trial_wait = tr.get("trial_wait", {}).duplicate()
	ms.fall = tr.get("fall")
	return ms


## Keep a new campaign state in a place's state: the road's keys, and the
## fall only when a choice has just produced it (as the hub's _mkeep).
static func keep(st: Dictionary, ms: Dictionary, fell: bool) -> void:
	st["missions"] = {"done": ms.done, "current": ms.current,
		"flags": ms.flags, "lines": ms.lines}
	if fell:
		var tr: Dictionary = st.get("trials", TrialCore.empty_state())
		tr = tr.duplicate(true)
		tr.fall = ms.fall
		st["trials"] = tr


static func dive_flag(mission_id: int, step: int) -> String:
	return "m%d.dove.%d" % [mission_id, step]


## The route step of the mission under way: {mission, step, kind, place,
## place_ru, how, ...} from story-12.json, or {} when no story runs.
static func where(story: Dictionary, ms: Dictionary) -> Dictionary:
	if ms.get("current") == null:
		return {}
	var s := story_of(story, ms.current.id)
	if s.is_empty():
		return {}
	var i: int = clampi(int(ms.current.step), 0, s.route.size() - 1)
	var r: Dictionary = s.route[i].duplicate()
	r["mission"] = int(s.mission)
	r["title"] = s.title
	return r


## Whether the current step of a story is done at this place's heart.
static func due_here(story: Dictionary, ms: Dictionary, place_id: String) -> bool:
	var r := where(story, ms)
	return not r.is_empty() and r.place == place_id


## Whether the ROV has gone down for the current step.
static func dove(ms: Dictionary) -> bool:
	if ms.get("current") == null:
		return false
	return ms.flags.get(dive_flag(int(ms.current.id),
		int(ms.current.step)), false)


## Back in the courtyard after the dive with the step's choice already
## made: the board's "walk on" closes it.
static func returned(story: Dictionary, ms: Dictionary) -> bool:
	var r := where(story, ms)
	return not r.is_empty() and r.how == "dive" \
		and ms.current.scene != null and dove(ms)


## "Куда идти" for the board: the place and how the step is done there.
static func go_line(story: Dictionary, ms: Dictionary) -> String:
	var r := where(story, ms)
	if r.is_empty():
		return ""
	if returned(story, ms):
		return "Аппарат поднят: шаг закрывается здесь, у доски."
	return "Куда идти: %s — %s." % [r.place_ru, HOW_RU.get(r.how, "")]


## The choices of the step at its heart: MissionCore's own, then after the
## scene either the ROV's descent (a dive step not yet dived) or the
## board's "walk on".
static func choices(mdata: Dictionary, story: Dictionary, ms: Dictionary,
		form: Dictionary, actions: Dictionary) -> Array:
	var v := MissionCore.view(mdata, ms, form, actions)
	if v.is_empty():
		return []
	if v.scene == null:
		return v.step.choices
	var r := where(story, ms)
	if not r.is_empty() and r.how == "dive" and not dove(ms):
		var obj: Dictionary = mdata.lake.get(str(r.get("object", "")), {})
		var fallen: bool = ms.fall != null
		return [{"id": "descend", "text": "Спустить аппарат: к «%s»"
			% str(obj.get("ru", r.get("object", ""))).get_slice(":", 0),
			"disabled": fallen, "cue": "",
			"reason": "путь в глубину закрыт: сперва трезвение и беседа"}]
	return [{"id": "next", "text": "Завершить миссию" if v.last
		else "Дальше", "disabled": false, "reason": "", "cue": ""}]


## One choice, as the board makes it: the new campaign state, FORM and
## rule, whether a fall came, the completed mission, and whether the ROV
## goes down now.  day is the player's calendar day (the rule's day).
static func choose(mdata: Dictionary, story: Dictionary, ms: Dictionary,
		form: Dictionary, actions: Dictionary, id: String,
		day: String) -> Dictionary:
	var out := {"state": ms, "form": form, "actions": actions, "fell": false,
		"completed": null, "descend": false, "say": "", "ok": false}
	var list := choices(mdata, story, ms, form, actions)
	var c := {}
	for x in list:
		if x.id == id:
			c = x
	if c.is_empty():
		return out
	if c.disabled:
		out.say = c.reason
		return out
	out.ok = true
	match id:
		"next":
			var res := MissionCore.advance(mdata, ms)
			out.state = res.state
			out.completed = res.completed
			if res.completed != null:
				out.say = "Миссия %d пройдена." % res.completed
		"descend":
			var st := ms.duplicate(true)
			st.flags[dive_flag(int(st.current.id), int(st.current.step))] = true
			out.state = st
			out.descend = true
		_:
			var res := MissionCore.choose(mdata, ms, id, form, actions)
			var ap := MissionCore.apply_effects(form, actions, res.effects, day)
			out.state = res.state
			out.form = ap.form
			out.actions = ap.actions
			out.fell = res.effects.fall != null
	return out


## The lines of a step, as the board's panel words them (the hub calls
## this too, so the two read alike): the step, its source, the scene a
## choice produced.
static func step_lines(v: Dictionary) -> Array:
	var s: Dictionary = v.step
	var lines := ["%d. %s — шаг %d из %d: %s" % [v.mission.id,
		v.mission.title, v.index + 1, v.total, v.kind_ru], "",
		s.title, s.text]
	if s.source != "":
		lines.append(SourceLabels.line(s.source))
	lines.append("")
	if v.scene != null:
		lines.append("— " + v.scene.choice)
		if v.scene.speaker != "":
			lines.append(v.scene.speaker + ":")
		lines.append(v.scene.text)
		if v.scene.source != "":
			lines.append(SourceLabels.line(v.scene.source))
		lines.append("")
	return lines


## The choices as lines, with the sign of a lure once it is learnt.
static func choice_lines(list: Array, current: int) -> Array:
	var out := []
	for j in list.size():
		var c: Dictionary = list[j]
		var line := "%s%d. %s" % ["▸ " if j == current else "  ", j + 1,
			c.text]
		if c.disabled and c.reason != "":
			line += "  (%s)" % c.reason
		out.append(line)
		if c.get("cue", "") != "":
			out.append("      " + c.cue)
	return out


# --- At the heart of a place (LocationHeart) --------------------------------

## The mission's panel at a place's heart when the current story step is
## done here, else {}.  st is the place's state (LocationCore.read_state).
static func open(loc: Dictionary, st: Dictionary, ctx: Dictionary) -> Dictionary:
	if not st.has("missions") or not ctx.has("story"):
		return {}
	var ms := mstate(st)
	if not due_here(ctx.story, ms, str(loc.id)):
		return {}
	return {"kind": "mission", "choice": 0, "reply": ""}


static func heart_lines(p: Dictionary, loc: Dictionary, st: Dictionary,
		ctx: Dictionary) -> Array:
	var ms := mstate(st)
	var v := MissionCore.view(ctx.mission_data, ms, st.form, st.actions)
	if v.is_empty():
		return [str(p.get("reply", ""))]
	var r := where(ctx.story, ms)
	var head := "Сюжет · " + str(loc.title_ru)
	if not r.is_empty() and r.how == "dive" and v.scene != null \
			and not dove(ms):
		var obj: Dictionary = ctx.mission_data.lake.get(str(r.get("object",
			"")), {})
		var depth = obj.get("depth", [0, 5])
		return [head, ""] + step_lines(v) + ["Аппарат ждёт: вещь лежит на %s–%s м. Шаг закроется, когда он поднимется." % [
			MissionCore.js_num(depth[0]), MissionCore.js_num(depth[1])], ""]
	if not r.is_empty() and r.how == "dive" and v.scene == null:
		return [head, "Вещь лежит на дне: после выбора аппарат спустится от этого места.",
			""] + step_lines(v)
	return [head, ""] + step_lines(v)


static func heart_choices(loc: Dictionary, st: Dictionary,
		ctx: Dictionary) -> Array:
	var ms := mstate(st)
	if not due_here(ctx.story, ms, str(loc.id)):
		return []
	return choices(ctx.mission_data, ctx.story, ms, st.form, st.actions)


## A choice at the heart.  Returns {panel, st, say, save, scene} as the
## hearts do: the panel stays on the mission while its next step is done
## here too, and closes when the road leads elsewhere.
static func heart_choose(p: Dictionary, loc: Dictionary, st: Dictionary,
		ctx: Dictionary, id: String) -> Dictionary:
	var ms := mstate(st)
	var res := choose(ctx.mission_data, ctx.story, ms, st.form, st.actions,
		id, str(st.day))
	var s := st.duplicate(true)
	if not res.ok:
		return {"panel": p, "st": st, "say": res.say, "save": false,
			"scene": ""}
	s.form = res.form
	s.actions = res.actions
	keep(s, res.state, res.fell)
	if res.descend:
		return {"panel": {}, "st": s, "say": "Аппарат уходит под воду.",
			"save": true, "scene": DIVE_SCENE}
	var q := p.duplicate(true)
	q.choice = 0
	if not due_here(ctx.story, mstate(s), str(loc.id)):
		var r := where(ctx.story, mstate(s))
		var say: String = res.say
		if not r.is_empty():
			say = (say + " " if say != "" else "") + go_line(ctx.story,
				mstate(s))
		return {"panel": {}, "st": s, "say": say, "save": true, "scene": ""}
	return {"panel": q, "st": s, "say": res.say, "save": true, "scene": ""}


# --- In the dive ------------------------------------------------------------

## The thing the ROV went down for, read from the hub's save: {ru, depth}
## of the current story step's object once the ROV was let down for it,
## else {}.  The dive shows it in its task line; nothing else changes.
static func dive_target(story: Dictionary, lake: Dictionary,
		hub_path := "") -> Dictionary:
	if hub_path == "":
		hub_path = SaveSlot.hub()
	if not FileAccess.file_exists(hub_path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(hub_path))
	if not data is Dictionary:
		return {}
	var ms := MissionCore.normalize_state(data.get("missions", {}))
	var r := where(story, ms)
	if r.is_empty() or r.how != "dive" or not dove(ms):
		return {}
	var obj: Dictionary = lake.get(str(r.get("object", "")), {})
	if obj.is_empty() or obj.get("flags", {}).get("holy", false):
		return {}
	return {"id": obj.id, "ru": str(obj.ru), "depth": obj.depth,
		"mission": r.mission}


# --- In the journal ---------------------------------------------------------

## One line per story for the book of the way: walked, under way (which
## step, where) or ahead.  missions is the hub save's "missions".
static func journal_lines(story: Dictionary, missions) -> Array:
	var ms := MissionCore.normalize_state(missions)
	var out := []
	for s in story.stories:
		var id := int(s.mission)
		var how := "впереди"
		if ms.done.get(str(id), false):
			how = "пройден"
		elif ms.current != null and int(ms.current.id) == id:
			var r: Dictionary = s.route[clampi(int(ms.current.step), 0,
				s.route.size() - 1)]
			how = "идёт: шаг %d из %d, %s" % [int(ms.current.step) + 1,
				s.route.size(), r.place_ru]
		out.append("%d. %s — %s" % [id, s.title, how])
	return out
