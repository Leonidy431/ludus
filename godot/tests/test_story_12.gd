## The 12 stories walked on foot (StoryRoute, data/story-12.json;
## docs/HLD_12_STORIES_HEADSET_2026-10-02.md, phase S4, track D).
##
## Every story is walked from the board (MissionCore.start, the board's
## "set out") to its end only through the hearts of its places
## (LocationHeart open / choose), with the hub's save written and read
## between the steps (LocationCore.write_state / read_state), and the
## dive's "walk on" taken where the hub takes it.  The walk is replayed
## on the board's own path (MissionCore choose, apply_effects, advance)
## with the same choices: FORM, rule and road must come out the same, so
## FORM changes only by MissionCore's rules.  At every step no other
## place's heart offers the step; no route goes through a holy thing.
## Called from run_hub_tests.gd.
extends RefCounted

const DAY := "2026-10-02"
const SAVE := "user://test_story_12_hub.json"
const DIVE_SAVE := "user://test_story_12_dive.json"

var data := LocationCore.load_data()
var ctx := LocationHeart.context()
var story := StoryRoute.load_data()
var mdata := MissionCore.load_data()


func fresh(missions: Dictionary) -> Dictionary:
	var trials := TrialCore.empty_state()
	for g in TrialCore.GATE_IDS:
		trials.trials[g] = true
	return {"form": HubCore.new_form(), "actions": RuleCore.normalize({}),
		"trials": trials, "passions": PassionCore.normalize_record({}),
		"chronicle": null, "atlas_given": [], "deeds": {}, "day": DAY,
		"missions": missions}


## The road as it stands when this mission is next: every runnable
## mission before it walked, every threshold crossed.
func before(mission_id: int) -> Dictionary:
	var done := {}
	for act in mdata.acts:
		for id in act.missions:
			if id == mission_id:
				return {"done": done, "current": null, "flags": {},
					"lines": {}}
			if not mdata.chorus.has(id):
				done[str(id)] = true
	return {}


## The first open choice that is not a lure: the plain way through.
func pick(list: Array) -> String:
	for c in list:
		if not c.disabled and not c.get("lure", false) \
				and not c.id in ["own", "away"]:
			return c.id
	return ""


func index_of(list: Array, id: String) -> int:
	for i in list.size():
		if list[i].id == id:
			return i
	return -1


func run(t: Object) -> void:
	var c0: int = t.checks
	var f0: int = t.failures
	_run(t)
	print("story 12: %d checks, %d failures" % [t.checks - c0,
		t.failures - f0])


func _run(t: Object) -> void:
	_data(t)
	_routes(t)
	var first := {}
	for s in story.stories:
		var a := walk(t, s)
		var b := walk(t, s)
		t._check(not a.is_empty() and var_to_str(a) == var_to_str(b),
			"story %d: the walk is deterministic" % s.mission)
		first[s.mission] = a
	_fall(t)
	_journal(t, first)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIVE_SAVE))


## The file: 12 stories, the pool counted, the prologue first, every act
## at least once and none more than twice, a Constitution line each.
func _data(t: Object) -> void:
	var stories: Array = story.stories
	t._check(stories.size() == 12, "12 stories (%d)" % stories.size())
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		StoryRoute.DATA))
	t._check(int(raw.pool_size) >= stories.size(),
		"the pool (%d) holds the 12" % int(raw.pool_size))
	t._check(MissionCore.act_of(mdata, int(stories[0].mission)) == 0,
		"the prologue first")
	var per := {}
	for s in stories:
		var ai := MissionCore.act_of(mdata, int(s.mission))
		per[ai] = int(per.get(ai, 0)) + 1
		var c := str(s.constitution)
		t._check(c.contains("ФОРМА") and c.contains("ДЕЙСТВИЕ")
			and c.contains("ЦЕЛЬ"), "story %d: Constitution line" % s.mission)
		var pr: String = s.route[1].practice
		t._check(c.contains(MissionCore.PRACTICE_RU[pr].label.to_lower()),
			"story %d: the line names the deed as the game does" % s.mission)
		t._check(not mdata.chorus.has(int(s.mission)),
			"story %d is not on rewrite" % s.mission)
	for ai in mdata.acts.size():
		t._check(int(per.get(ai, 0)) >= 1 and int(per.get(ai, 0)) <= 2,
			"act %s: 1-2 stories (%d)" % [mdata.acts[ai].id,
				int(per.get(ai, 0))])
	# The hearts build MissionCore's data from what they already read.
	var md: Dictionary = ctx.mission_data
	for k in ["acts", "titles", "chorus", "order"]:
		t._check(var_to_str(md[k]) == var_to_str(mdata[k]),
			"the hearts' mission data: " + k)


## Each route is the mission's own four steps, each at a built place
## that hosts it; no step is a holy thing; the heart keeps clear of the
## place's holy thing.
func _routes(t: Object) -> void:
	for s in story.stories:
		var m := MissionCore.build_mission(mdata, int(s.mission))
		t._check(m.title == s.title, "story %d: title" % s.mission)
		for i in 4:
			var r: Dictionary = s.route[i]
			var st: Dictionary = m.steps[i]
			var tag := "story %d step %d" % [s.mission, i]
			t._check(r.kind == st.kind, tag + ": kind")
			var loc := LocationCore.by_id(data, r.place)
			t._check(not loc.is_empty(), tag + ": place " + r.place)
			if loc.is_empty():
				continue
			var h: Dictionary = loc.heart
			match r.kind:
				"find":
					t._check(r.object == st.object, tag + ": object")
					var here: bool = h.get("object", "") == st.object
					for sl in loc.slots:
						if str(data.things[sl.object].source) \
								== "lake:" + st.object:
							here = true
					if r.how == "dive":
						t._check(h.core == "DiveCore", tag + ": dive place")
					else:
						t._check(here, tag + ": the thing is in the place")
				"practice":
					t._check(r.practice == st.practice
						and h.get("id", "") == st.practice,
						tag + ": the heart is the deed")
				"dialogue":
					t._check(r.npc == st.npc and h.get("npc", "") == st.npc,
						tag + ": the heart is the person")
				"dive":
					t._check(r.object == st.object and h.core == "DiveCore",
						tag + ": dive from a dive heart")
			if r.has("object"):
				var o: Dictionary = mdata.lake.get(r.object, {})
				t._check(not o.is_empty()
					and not o.flags.get("holy", false)
					and o.category != "fish",
					tag + ": a real, not holy object the dive places")
				if loc.holy_place != null:
					t._check(loc.holy_place.thing != r.object,
						tag + ": never the place's holy thing")
			var p := LocationCore.plan(loc, data.things, {}, {})
			t._check(LocationCore.holy_fade_target(p, p.heart) == 1.0,
				tag + ": the heart is clear of the holy thing")


## One story from the board to its end.  Returns what the walk left
## (FORM, rule, road) or {} on a break.
func walk(t: Object, s: Dictionary) -> Dictionary:
	var id := int(s.mission)
	var st := fresh(before(id))
	var ms := StoryRoute.mstate(st)
	t._check(MissionCore.can_start(mdata, ms, id).ok,
		"story %d can be set out on" % id)
	# The board's "set out".
	var started := MissionCore.start(mdata, ms, id)
	StoryRoute.keep(st, started, false)
	# The board's own path, kept beside: the same choices.
	var board := {"ms": started.duplicate(true), "form": st.form.duplicate(),
		"actions": st.actions.duplicate(true)}
	LocationCore.write_state(st, SAVE)
	st = LocationCore.read_state(SAVE, DIVE_SAVE, DAY)
	for i in 4:
		var r: Dictionary = s.route[i]
		var tag := "story %d step %d (%s at %s)" % [id, i, r.kind, r.place]
		var go := StoryRoute.go_line(story, StoryRoute.mstate(st))
		t._check(go.contains(str(r.place_ru)), tag + ": the board names it")
		# No other place's heart offers the step.
		var wrong := 0
		for loc in data.locations:
			if loc.id == r.place:
				continue
			var o := LocationHeart.open(loc, st, ctx)
			if o.panel.get("kind", "") == "mission":
				wrong += 1
		t._check(wrong == 0, tag + ": no other heart offers it (%d)" % wrong)
		var loc := LocationCore.by_id(data, r.place)
		var o := LocationHeart.open(loc, st, ctx)
		t._check(o.panel.get("kind", "") == "mission",
			tag + ": its heart shows the step")
		if o.panel.get("kind", "") != "mission":
			return {}
		var p: Dictionary = o.panel
		t._check(LocationHeart.text(p, loc, st, ctx).contains("шаг %d из 4"
			% (i + 1)), tag + ": the panel words the step")
		var list := LocationHeart.choices(p, loc, st, ctx)
		var cid := pick(list)
		t._check(cid != "", tag + ": an open choice")
		var res := LocationHeart.choose(p, loc, st, ctx, index_of(list, cid))
		t._check(res.save, tag + ": the choice is saved")
		st = res.st
		# The same choice on the board's path.
		var bc := MissionCore.choose(mdata, board.ms, cid, board.form,
			board.actions)
		var ap := MissionCore.apply_effects(board.form, board.actions,
			bc.effects, DAY)
		board.ms = bc.state
		board.form = ap.form
		board.actions = ap.actions
		t._check(var_to_str(st.form) == var_to_str(board.form),
			tag + ": FORM as the board gives it")
		p = res.panel
		if r.how == "dive":
			t._check(not p.is_empty(), tag + ": the heart waits to dive")
			list = LocationHeart.choices(p, loc, st, ctx)
			t._check(list[0].id == "descend" and not list[0].disabled,
				tag + ": the ROV is let down from the heart")
			# Before the dive the step cannot be closed anywhere.
			t._check(StoryRoute.choose(mdata, story, StoryRoute.mstate(st),
				st.form, st.actions, "next", DAY).ok == false,
				tag + ": no walk on before the dive")
			res = LocationHeart.choose(p, loc, st, ctx, 0)
			t._check(res.scene == StoryRoute.DIVE_SCENE and res.save,
				tag + ": down to the dive")
			st = res.st
			LocationCore.write_state(st, SAVE)
			var target := StoryRoute.dive_target(story, mdata.lake, SAVE)
			t._check(target.get("id", "") == r.object,
				tag + ": the dive names its thing")
			# Back in the courtyard: the board's "walk on" closes it.
			st = LocationCore.read_state(SAVE, DIVE_SAVE, DAY)
			var ms2 := StoryRoute.mstate(st)
			t._check(StoryRoute.returned(story, ms2),
				tag + ": back, the board closes the step")
			var nx := StoryRoute.choose(mdata, story, ms2, st.form,
				st.actions, "next", DAY)
			t._check(nx.ok, tag + ": walk on at the board")
			StoryRoute.keep(st, nx.state, false)
		else:
			list = LocationHeart.choices(p, loc, st, ctx)
			t._check(list.size() >= 1 and list[0].id == "next",
				tag + ": walk on at the heart")
			res = LocationHeart.choose(p, loc, st, ctx, 0)
			st = res.st
		var adv := MissionCore.advance(mdata, board.ms)
		board.ms = adv.state
		LocationCore.write_state(st, SAVE)
		st = LocationCore.read_state(SAVE, DIVE_SAVE, DAY)
	var end := StoryRoute.mstate(st)
	t._check(end.current == null and end.done.get(str(id), false),
		"story %d walked to its end" % id)
	t._check(var_to_str(st.actions) == var_to_str(board.actions)
		and var_to_str(end.lines) == var_to_str(board.ms.lines)
		and var_to_str(end.done) == var_to_str(board.ms.done),
		"story %d: rule and road as on the board" % id)
	for f in end.flags:
		t._check(f in board.ms.flags or str(f).contains(".dove."),
			"story %d: only the dive's own flag is added (%s)" % [id, f])
	return {"form": st.form, "actions": st.actions, "missions": st.missions}


## A lure at a step reached by the dive: the fall closes the deep, the
## ROV is not let down, and nothing closes the step until it lifts.
func _fall(t: Object) -> void:
	var s: Dictionary = story.stories[0]
	var id := int(s.mission)
	var st := fresh(before(id))
	StoryRoute.keep(st, MissionCore.start(mdata, StoryRoute.mstate(st), id),
		false)
	var r: Dictionary = s.route[0]
	t._check(r.how == "dive", "the prologue's find lies on the floor")
	var loc := LocationCore.by_id(data, r.place)
	var o := LocationHeart.open(loc, st, ctx)
	var list := LocationHeart.choices(o.panel, loc, st, ctx)
	var lure := -1
	for i in list.size():
		if list[i].get("lure", false):
			lure = i
	t._check(lure >= 0, "the lure is offered")
	var res := LocationHeart.choose(o.panel, loc, st, ctx, lure)
	t._check(res.st.trials.fall != null, "the lure brings the fall")
	t._check(var_to_str(res.st.form) == var_to_str(st.form),
		"a fall pays nothing")
	list = LocationHeart.choices(res.panel, loc, res.st, ctx)
	t._check(list[0].id == "descend" and list[0].disabled,
		"fallen, the ROV is not let down")
	var again := LocationHeart.choose(res.panel, loc, res.st, ctx, 0)
	t._check(again.scene == "" and not again.save,
		"a closed descent does nothing")


## The book of the way: walked stories say so.
func _journal(t: Object, walked: Dictionary) -> void:
	var s: Dictionary = story.stories[0]
	var lines := StoryRoute.journal_lines(story,
		walked[s.mission].missions)
	t._check(lines.size() == 12 and str(lines[0]).contains("пройден"),
		"the journal says the story is walked")
	var none := StoryRoute.journal_lines(story, {})
	t._check(str(none[0]).contains("впереди"), "and the rest are ahead")
	var pages := JournalCore.pages_ru({"form": HubCore.new_form(),
		"actions": {}, "passions": {}, "passion_data": {},
		"date": DAY, "stories": lines})
	var found := false
	for pg in pages:
		if str(pg).begins_with("СЮЖЕТЫ НОГАМИ"):
			found = true
	t._check(found, "the book has the page of the stories")
