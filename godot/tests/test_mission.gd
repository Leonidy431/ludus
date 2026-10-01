## MissionCore against the JS reference (public/ludus/ludus-missions.js):
## godot/tests/fixtures/missions.json holds the shape of all 99 missions,
## the normalising of stored states, the starts that must be refused
## and two walks through the whole campaign.  A walk is replayed as a
## chain: this side keeps its own state, FORM and rule and compares
## every step with the JS.  Called from run_hub_tests.gd.
extends RefCounted

const DAY := "2026-09-30"  # The day the fixture passes to the rule.
const STOP_WORDS := "(мученик|свят(ой|ая|ое|ые|ого|ому|ым|ых|ую)(?![а-яё])|благодат|таинств|спасени)"

var data := MissionCore.load_data()


## A canonical text of a value, so JSON numbers (floats) and GDScript
## ints compare equal and key order does not matter.
func _canon(v) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT, TYPE_FLOAT:
			return MissionCore.js_num(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(str(v))
		TYPE_ARRAY:
			var parts := []
			for x in v:
				parts.append(_canon(x))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var keys: Array = v.keys()
			keys.sort()
			var parts := []
			for k in keys:
				parts.append(JSON.stringify(str(k)) + ":" + _canon(v[k]))
			return "{" + ",".join(parts) + "}"
	return str(v)


func _same(t: Object, got, want, tag: String) -> bool:
	var a := _canon(got)
	var b := _canon(want)
	t._check(a == b, "%s\n  got  %s\n  want %s" % [tag, a.left(600),
		b.left(600)])
	return a == b


func _sorted_ids(d: Dictionary) -> Array:
	var ids := []
	for k in d:
		ids.append(int(k))
	ids.sort()
	return ids


func _sorted_keys(d: Dictionary) -> Array:
	var ks: Array = d.keys()
	ks.sort()
	return ks


func _fall(st: Dictionary):
	if st.fall == null:
		return null
	return {"passion": st.fall.passion, "teacher": st.fall.teacher,
		"since": st.fall.since}


func _digest(st: Dictionary) -> Dictionary:
	var cur = null
	if st.current != null:
		cur = {"id": st.current.id, "step": st.current.step,
			"scene": st.current.scene}
	return {"done": _sorted_ids(st.done), "current": cur,
		"flags": _sorted_keys(st.flags), "lines": st.lines,
		"trials": _sorted_keys(st.trials), "fall": _fall(st)}


func _light(st: Dictionary) -> Dictionary:
	return {"done": st.done.size(),
		"current": [st.current.id, st.current.step] if st.current != null
			else null,
		"flags": st.flags.size(), "lines": st.lines.size(),
		"fall": _fall(st)}


func _view(v: Dictionary):
	if v.is_empty():
		return null
	var s: Dictionary = v.step
	var choices := []
	for c in s.choices:
		choices.append([c.id, c.text, c.disabled, c.reason, c.cue,
			c.get("deep", false), c.get("lure", false)])
	return {"id": v.mission.id, "index": v.index, "total": v.total,
		"kindRu": v.kind_ru, "last": v.last, "scene": v.scene,
		"step": {"kind": s.kind, "title": s.title, "text": s.text,
			"speaker": s.get("speaker", ""), "node": s.get("node", ""),
			"voice": s.get("voice", ""), "meaning": s.meaning,
			"source": s.source, "choices": choices}}


func _catalog(st: Dictionary) -> Array:
	var out := []
	for act in MissionCore.catalog(data, st):
		var letters := ""
		for m in act.missions:
			letters += m.status[0]
		out.append({"id": act.id,
			"lock": act.lock if act.lock != "" else null,
			"complete": act.complete, "status": letters})
	return out


func _rule(a: Dictionary) -> Dictionary:
	var met := 0
	for k in a.met:
		met += int(a.met[k])
	var pr := 0
	for k in a.get("practices", {}):
		pr += int(a.practices[k].count)
	return {"met": met, "fastDays": a.fastDays, "practices": pr}


func _status(s: Dictionary) -> Dictionary:
	return {"fallen": s.fallen, "passion": s.get("passion"),
		"teacher": s.get("teacher"), "sober": s.get("sober", false),
		"taught": s.get("taught", false),
		"canLift": s.get("can_lift", false)}


## The JS state names trial_wait "trialWait".
func _js_state(raw):
	if not raw is Dictionary:
		return raw
	var r: Dictionary = raw.duplicate(true)
	if r.has("trialWait"):
		r["trial_wait"] = r.trialWait
		r.erase("trialWait")
	return r


func _id(v) -> int:
	return -1 if v == null else int(v)


func _walk(t: Object, w: Dictionary) -> int:
	var st := MissionCore.empty_state()
	var form := {}
	for k in w.form:
		form[k] = int(w.form[k])
	var actions: Dictionary = w.actions.duplicate(true)
	var fails_before: int = t.failures
	var completed := 0
	for i in w.steps.size():
		if t.failures - fails_before >= 10:
			t._check(false, "%s: stopped after 10 failures at #%d"
				% [w.name, i])
			break
		var s: Dictionary = w.steps[i]
		var tag := "%s #%d %s" % [w.name, i, s.do]
		match s.do:
			"catalog":
				_same(t, _catalog(st), s.out, tag)
			"next":
				var n := MissionCore.next_mission(data, st)
				_same(t, n if n >= 0 else null, s.out, tag)
			"pass":
				st.trials[s.gate] = true
			"canStart":
				_same(t, MissionCore.can_start(data, st, _id(s.id)), s.out,
					tag + " %s" % s.id)
			"start":
				st = MissionCore.start(data, st, int(s.id))
				var full: bool = s.out.done is Array
				_same(t, _digest(st) if full else _light(st), s.out,
					tag + " %s" % s.id)
			"advance":
				var res := MissionCore.advance(data, st)
				st = res.state
				if res.completed != null:
					completed += 1
				_same(t, {"completed": res.completed, "state": _light(st)},
					s.out, tag)
			"view":
				_same(t, _view(MissionCore.view(data, st, form, actions)),
					s.out, tag)
			"choose":
				var res := MissionCore.choose(data, st, s.choice, form,
					actions)
				var ap := MissionCore.apply_effects(form, actions,
					res.effects, DAY)
				form = ap.form
				actions = ap.actions
				st = res.state
				_same(t, {"effects": res.effects,
					"scene": st.current.scene if st.current != null
						else null,
					"state": _light(st), "form": form,
					"rule": _rule(actions)}, s.out, tag + " " + s.choice)
			"status":
				_same(t, _status(MissionCore.fall_status(data, st,
					actions)), s.out, tag)
			"still":
				actions = HubCore.add_stillness(actions, float(s.minutes))
			"meet":
				actions = HubCore.record_meeting(actions, s.npc)
			"lift":
				st = MissionCore.lift_fall(data, st, actions)
				_same(t, _digest(st), s.out, tag)
	return completed


func run(t: Object) -> void:
	var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/missions.json"))
	# The spine is read whole: seven acts, 99 missions, seven on rewrite.
	var all := 0
	for a in data.acts:
		all += a.missions.size()
	t._check(data.acts.size() == 7 and all == 99, "7 acts, 99 missions")
	var chorus: Array = data.chorus.keys()
	chorus.sort()
	t._check(chorus == [14, 18, 19, 20, 32, 52, 89], "7 on rewrite")
	t._check(fx.build.size() == 99, "build records")
	for r in fx.build:
		var m := MissionCore.build_mission(data, int(r.id))
		var got := {}
		for k in r.out:
			got[k] = m.get(k)
		_same(t, got, r.out, "build %d" % int(r.id))
	for i in fx.normalize.size():
		var r: Dictionary = fx.normalize[i]
		_same(t, _digest(MissionCore.normalize_state(_js_state(r.raw))),
			r.out, "normalize #%d" % i)
	for r in fx.starts:
		var st := MissionCore.empty_state()
		_same(t, {"can": MissionCore.can_start(data, st, int(r.id)),
			"state": _digest(MissionCore.start(data, st, int(r.id)))}, r.out,
			"start %d" % int(r.id))
	var completed := 0
	for w in fx.walks:
		completed += _walk(t, w)
	t._check(completed == 184, "missions completed in walks: %d"
		% completed)
	# No church word stands on a button or a label (TABOO 0.39 item 3):
	# every line the port writes itself is checked.
	var re := RegEx.create_from_string(STOP_WORDS)
	var own := []
	for p in MissionCore.PRACTICE_RU.values():
		own += [p.label, p.after]
	for l in MissionCore.LURES.values():
		own += l.values()
	for plan in MissionCore.ACT_PLAN.values():
		own += [plan.intro, plan.practiceScene, plan.findPlace]
	own += MissionCore.INTRO.values() + MissionCore.CLOSED_RU.values() \
		+ MissionCore.GATE_TITLE_RU.values()
	for s in own:
		t._check(re.search(s.to_lower()) == null, "stop word in: " + s)
	t._check(re.search("святой путь") != null, "stop list works")
	# No random number is drawn anywhere in the rules (Constitution).
	var src := FileAccess.get_file_as_string(
		"res://scripts/mission_core.gd")
	t._check(src.find("randi") < 0 and src.find("randf") < 0
		and src.find("RandomNumber") < 0,
		"no randomness in mission_core.gd")
	# Prayer is never a mission step (TABOO 0.35 rule 16).
	for plan in MissionCore.ACT_PLAN.values():
		for pr in plan.practices:
			t._check(pr in ["alms", "forgive", "obedience", "fast",
				"secret_deed"], "deed, not prayer: " + pr)
