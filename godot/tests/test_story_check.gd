## The tester's entry to the 12 stories (StoryCheck, SaveSlot; debug
## builds only).  For each story the built test save lets MissionCore
## start it (can_start ok, honestly, through the road's own rules) and
## StoryRoute.where points at its first place; the player's own save is
## never written by the entry; in a release run (debug injected false)
## the entry is hidden, enter() does nothing and the test slot is never
## active, whatever marker lies on disk.  Called from run_hub_tests.gd.
##
## Constitution: FORM (the tester in the headset) -> ACTION (open any of
## the 12 stories in a separate test save) -> GOAL (the operator checks
## the teaching of every story without walking the campaign; a release
## build has no such door).
extends RefCounted

const PATHS := {"hub": "user://test_story_check_hub.json",
	"dive": "user://test_story_check_dive.json",
	"marker": "user://test_story_check_marker"}

var story := StoryRoute.load_data()
var mdata := MissionCore.load_data()


func _snapshot(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "<none>"
	return FileAccess.get_file_as_string(path).sha256_text()


func run(t: Object) -> void:
	var c0: int = t.checks
	var f0: int = t.failures
	_run(t)
	print("story check: %d checks, %d failures" % [t.checks - c0,
		t.failures - f0])


func _run(t: Object) -> void:
	var real_hub := _snapshot(SaveSlot.HUB)
	var real_dive := _snapshot(SaveSlot.DIVE)
	var real_marker := FileAccess.file_exists(SaveSlot.MARKER)
	_slots(t)
	_atomic(t)
	_stories(t)
	_release(t)
	StoryCheck.leave(PATHS)
	t._check(_snapshot(SaveSlot.HUB) == real_hub,
		"the player's hub save is never written by the entry")
	t._check(_snapshot(SaveSlot.DIVE) == real_dive,
		"the player's dive save is never written by the entry")
	t._check(FileAccess.file_exists(SaveSlot.MARKER) == real_marker,
		"the real marker is not touched by the test")


## A save is replaced whole (SaveSlot.write_json): the new JSON reads
## back, no <path>.part is left, and a half-written .part from a crash
## does not touch the save beside it.
func _atomic(t: Object) -> void:
	var path := "user://test_story_check_atomic.json"
	t._check(SaveSlot.write_json(path, {"a": 1}), "write_json writes")
	t._check(SaveSlot.write_json(path, {"a": 2, "b": [1, 2]}),
		"write_json replaces an existing save")
	var back = JSON.parse_string(FileAccess.get_file_as_string(path))
	t._check(back is Dictionary and int(back.get("a", 0)) == 2,
		"the replaced save reads back whole")
	t._check(not FileAccess.file_exists(path + ".part"),
		"no .part is left after a write")
	var torn := FileAccess.open(path + ".part", FileAccess.WRITE)
	torn.store_string("{\"a\": 3, \"b\": [")
	torn.close()
	back = JSON.parse_string(FileAccess.get_file_as_string(path))
	t._check(back is Dictionary and int(back.get("a", 0)) == 2,
		"a torn .part from a crash leaves the save as it was")
	# A save spoiled on disk: the reader falls back to the last good
	# copy, and the next write does not copy the spoiled file over it.
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string("{\"a\": ")
	bad.close()
	t._check(int(SaveSlot.read_json(path).get("a", 0)) == 1,
		"a spoiled save reads its last good copy (.bak)")
	SaveSlot.write_json(path, {"a": 5})
	var kept = JSON.parse_string(FileAccess.get_file_as_string(path + ".bak"))
	t._check(kept is Dictionary and int(kept.get("a", 0)) == 1,
		"a spoiled save never overwrites the last good copy")
	t._check(SaveSlot.read_json("user://test_story_check_none.json") == {},
		"no save and no copy read as a fresh start")
	for f in [path, path + ".part", path + ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


## The slots: the test files are other files than the player's, and the
## active slot follows the marker only in a debug build.
func _slots(t: Object) -> void:
	for k in ["hub", "dive", "marker"]:
		t._check(not SaveSlot.test_paths()[k] in [SaveSlot.HUB,
			SaveSlot.DIVE], "the test slot's %s is not the real save" % k)
	t._check(SaveSlot.hub(true, PATHS.marker) == SaveSlot.HUB
		and SaveSlot.dive(true, PATHS.marker) == SaveSlot.DIVE,
		"without the marker the real save is used")
	var res := StoryCheck.enter(mdata, int(story.stories[0].mission), true,
		{"hub": SaveSlot.HUB, "dive": PATHS.dive, "marker": PATHS.marker})
	t._check(not res.ok, "enter refuses the real save as its target")
	t._check(not FileAccess.file_exists(PATHS.marker),
		"a refused enter sets no marker")


func _stories(t: Object) -> void:
	t._check(StoryCheck.listing(story).size() == 12,
		"the entry lists the 12 stories")
	for s in story.stories:
		var id := int(s.mission)
		var built := StoryCheck.build_state(mdata, id)
		t._check(built.ok, "story %d: test state builds (%s)" % [id,
			built.reason])
		if not built.ok:
			continue
		# The state before start must let MissionCore start this very
		# mission: the road and the gates as act_lock asks, nothing more.
		var before: Dictionary = MissionCore.normalize_state(
			built.save.missions)
		before.current = null
		before.trials = built.save.trials.trials.duplicate()
		t._check(MissionCore.can_start(mdata, before, id).ok,
			"story %d: MissionCore.can_start ok" % id)
		t._check(MissionCore.next_mission(mdata, before) == id,
			"story %d: it is the next mission of the road" % id)
		var ai := MissionCore.act_of(mdata, id)
		for g in TrialCore.GATE_IDS:
			var want: bool = g in StoryCheck.gates_for(mdata, id)
			t._check(built.save.trials.trials.get(g, false) == want,
				"story %d: gate %s crossed only if act %d needs it"
					% [id, g, ai])
		t._check(built.save.form == HubCore.new_form(),
			"story %d: FORM is a guest's" % id)
		# Written and read as the game reads it.
		var res := StoryCheck.enter(mdata, id, true, PATHS)
		t._check(res.ok, "story %d: entered (%s)" % [id, res.reason])
		t._check(SaveSlot.testing(true, PATHS.marker),
			"story %d: the test slot is active" % id)
		var st := LocationCore.read_state(PATHS.hub, PATHS.dive,
			"2026-10-02")
		var ms := StoryRoute.mstate(st)
		t._check(ms.current != null and int(ms.current.id) == id
			and int(ms.current.step) == 0,
			"story %d: under way at its first step" % id)
		var r := StoryRoute.where(story, ms)
		t._check(not r.is_empty() and r.place == s.route[0].place,
			"story %d: the route points at %s (%s)" % [id,
				s.route[0].place, r.get("place", "")])
		var v := MissionCore.view(mdata, ms, st.form, st.actions)
		var plain := false
		for c in v.get("step", {}).get("choices", []):
			plain = plain or (not c.disabled and not c.get("lure", false))
		t._check(plain, "story %d: a guest has a plain choice" % id)
		t._check(MissionCore.normalize_state(built.save.missions).done.size()
			== st.missions.done.size(),
			"story %d: the earlier missions read back done" % id)
		StoryCheck.leave(PATHS)
		t._check(not SaveSlot.testing(true, PATHS.marker),
			"story %d: leaving removes the marker" % id)


## A release build: the entry is hidden, enter() writes nothing, and the
## test slot is never active, even with a marker on disk.
func _release(t: Object) -> void:
	t._check(not StoryCheck.shown(false), "release: the entry is hidden")
	t._check(StoryCheck.shown(true), "debug: the entry is shown")
	var res := StoryCheck.enter(mdata, int(story.stories[0].mission), false,
		PATHS)
	t._check(not res.ok and not FileAccess.file_exists(PATHS.hub)
		and not FileAccess.file_exists(PATHS.marker),
		"release: enter writes nothing")
	var m := FileAccess.open(PATHS.marker, FileAccess.WRITE)
	m.store_string("left over")
	m.close()
	t._check(not SaveSlot.testing(false, PATHS.marker)
		and SaveSlot.hub(false, PATHS.marker) == SaveSlot.HUB
		and SaveSlot.dive(false, PATHS.marker) == SaveSlot.DIVE,
		"release: a marker on disk does not open the test slot")
	t._check(SaveSlot.testing(true, PATHS.marker),
		"debug: the same marker opens it")
	# The source of the hub keeps the entry behind StoryCheck.shown().
	var src := FileAccess.get_file_as_string("res://scripts/hub.gd")
	t._check(src.contains("if StoryCheck.shown():\n\t\tout += _check_doors()"),
		"hub: the board's entry is behind the debug check")
	t._check(src.contains("func _choose_check(id: String) -> void:\n"
		+ "\tif not StoryCheck.shown():"), "hub: choosing it is too")
	for p in ["res://scripts/hub.gd", "res://scripts/dive.gd",
			"res://scripts/location_core.gd", "res://scripts/story_route.gd",
			"res://scripts/journal_book.gd"]:
		var code := FileAccess.get_file_as_string(p)
		t._check(not code.contains("\"user://hub.json\"")
			and not code.contains("\"user://dive.json\""),
			"%s: the save path comes from SaveSlot" % p.get_file())
