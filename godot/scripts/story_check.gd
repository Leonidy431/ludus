## The tester's entry to the 12 stories (debug builds only).
##
## The operator must check every one of the 12 stories (StoryRoute,
## data/story-12.json) in the headset, but a later story opens only after
## the earlier acts are walked and their thresholds crossed
## (MissionCore.act_lock).  This entry writes a separate test save
## (SaveSlot.TEST_HUB) in which the road stands as it would for a player
## who has just reached that story: every runnable mission before it
## marked done, the thresholds its act and the acts before it need
## crossed, and then MissionCore.start for the story's mission, so the
## story starts by MissionCore's own rules (can_start must say ok).
##
## FORM stays a guest's (1 in every attribute).  No step of the 12 needs
## more: every step has a plain choice open to a guest (the find's note,
## the deed, the talk's bow or open branch, the dive's slow rope), and
## the ROV's descent asks no FORM.  The deep answers stay closed with
## their reason, as for a real guest; raising FORM would hide what a
## guest sees.
##
## The player's own save (SaveSlot.HUB, SaveSlot.DIVE) is never written
## here.  In a release build (OS.is_debug_build() false) the entry is
## hidden and enter() does nothing.  The board shows the first line
## BANNER on every panel while the test slot is active, and leave()
## takes the player back to the real save, untouched.
##
## Constitution: FORM (the tester in the headset) -> ACTION (open any of
## the 12 stories in a separate test save) -> GOAL (the operator checks
## the teaching of every story without walking the campaign; a release
## build has no such door).
class_name StoryCheck
extends RefCounted

const BANNER := "ПРОВЕРКА — не настоящее сохранение"
const ENTRY_RU := "Проверка: открыть сюжет…"
const LEAVE_RU := "Выйти из проверки"


## Whether the board offers the entry: debug builds only.
static func shown(debug = null) -> bool:
	return SaveSlot.debug_build(debug)


## The 12 stories as the entry lists them: {mission, title, act_ru}.
static func listing(story: Dictionary) -> Array:
	var out := []
	for s in story.stories:
		out.append({"mission": int(s.mission), "title": str(s.title),
			"act_ru": str(s.get("act_ru", ""))})
	return out


## The gates the road needs crossed for the mission's act: the gate of
## every act from the second (index 2) up to its own (GATE_FOR_ACT).
static func gates_for(mdata: Dictionary, mission_id: int) -> Array:
	var ai := MissionCore.act_of(mdata, mission_id)
	var out := []
	for k in range(2, ai + 1):
		var g: String = MissionCore.GATE_FOR_ACT.get(k, "")
		if g != "":
			out.append(g)
	return out


## The test save in which the story of mission_id is under way at its
## first step: {ok, reason, save}.  save has the hub save's shape (as
## hub.gd _save writes it).  Pure: it reads nothing and writes nothing.
static func build_state(mdata: Dictionary, mission_id: int) -> Dictionary:
	var ai := MissionCore.act_of(mdata, mission_id)
	if ai < 0:
		return {"ok": false, "reason": "нет такой миссии", "save": {}}
	var done := {}
	for i in ai + 1:
		for id in mdata.acts[i].missions:
			if id == mission_id:
				break
			if not mdata.chorus.has(id):
				done[str(id)] = true
	var trials := TrialCore.empty_state()
	for g in gates_for(mdata, mission_id):
		trials.trials[g] = true
	var ms := MissionCore.empty_state()
	ms.done = done
	ms.trials = trials.trials.duplicate()
	var can := MissionCore.can_start(mdata, ms, mission_id)
	if not can.ok:
		return {"ok": false, "reason": can.reason, "save": {}}
	var st := MissionCore.start(mdata, ms, mission_id)
	return {"ok": true, "reason": "", "save": {
		"form": HubCore.new_form(), "actions": HubCore.new_actions(),
		"trials": trials, "passions": {}, "chronicle": "",
		"missions": {"done": st.done, "current": st.current,
			"flags": st.flags, "lines": st.lines},
		"deeds": {}}}


## Open the story in the test slot: write the test save, clear the test
## dive and set the marker.  paths is SaveSlot.test_paths() unless a test
## passes its own.  Returns {ok, reason}.  Never touches the player's
## own save: a path equal to SaveSlot.HUB or SaveSlot.DIVE is refused.
static func enter(mdata: Dictionary, mission_id: int, debug = null,
		paths := {}) -> Dictionary:
	if not shown(debug):
		return {"ok": false, "reason": "только в отладочной сборке"}
	var p: Dictionary = paths if not paths.is_empty() \
		else SaveSlot.test_paths()
	for k in ["hub", "dive", "marker"]:
		if p[k] in [SaveSlot.HUB, SaveSlot.DIVE]:
			return {"ok": false, "reason": "настоящее сохранение не пишется"}
	var built := build_state(mdata, mission_id)
	if not built.ok:
		return {"ok": false, "reason": built.reason}
	var f := FileAccess.open(p.hub, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "reason": "файл проверки не записан"}
	f.store_string(JSON.stringify(built.save))
	f.close()
	# Each check starts the dive clean: no pockets from an earlier check.
	if FileAccess.file_exists(p.dive):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p.dive))
	var m := FileAccess.open(p.marker, FileAccess.WRITE)
	if m == null:
		return {"ok": false, "reason": "метка проверки не записана"}
	m.store_string("story %d\n" % mission_id)
	m.close()
	return {"ok": true, "reason": ""}


## Leave the test slot: the marker and the test files go; the player's
## own save was never touched and is read again.
static func leave(paths := {}) -> void:
	var p: Dictionary = paths if not paths.is_empty() \
		else SaveSlot.test_paths()
	for k in ["marker", "hub", "dive"]:
		if p[k] in [SaveSlot.HUB, SaveSlot.DIVE]:
			continue
		if FileAccess.file_exists(p[k]):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p[k]))
