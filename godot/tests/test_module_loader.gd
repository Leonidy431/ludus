## Big modules load in the background (ModuleLoader, CLAUDE.md TABOO
## 0.014; phase S1 of docs/HLD_12_STORIES_HEADSET_2026-10-02.md).
## Called from run_hub_tests.gd: await run(self).
##
## The check that matters most is the plain one: no script of the game
## opens a big module with change_scene_to_file, which loads the whole
## module in the frame of the press (item 5 of the taboo).
extends RefCounted

## Frames the threaded load may take on a slow host before the test
## calls it stuck.
const WAIT_FRAMES := 2000


## Every .gd under the folder, nested folders too.
static func scripts_in(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(scripts_in(dir.path_join(d)))
	return out


## The lines of a script that change scene synchronously.  Any call at
## all is reported, and the big modules by name; a comment is skipped.
static func sync_changes(path: String) -> Array:
	var out := []
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("#"):
			continue
		if "change_scene_to_file" in line:
			out.append("%s:%d %s" % [path, i + 1, line])
	return out


func run(t: Object) -> void:
	# 1. No synchronous change of scene anywhere in the game's scripts:
	# all the scenes of the game are big modules.
	var found := []
	for path in scripts_in("res://scripts"):
		found.append_array(sync_changes(path))
	t._check(found.is_empty(),
		"no change_scene_to_file in godot/scripts: %s" % [found])
	# The check itself sees a call: a line written as the old hub had it.
	var probe := "user://module_loader_probe.gd"
	var f := FileAccess.open(probe, FileAccess.WRITE)
	f.store_string("\tget_tree().change_scene_to_file(\"res://scenes/"
		+ "dive.tscn\")\n# change_scene_to_file in a comment\n")
	f.close()
	t._check(sync_changes(probe).size() == 1,
		"the scan finds a synchronous change and skips a comment")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))
	# 2. The helper is one, and it is the autoload.
	var ml: Node = t.root.get_node_or_null("ModuleLoader")
	t._check(ml != null, "ModuleLoader is an autoload")
	if ml == null:
		return
	var dive: String = ml.DIVE
	# Nothing asked: nothing ready, no progress.
	t._check(not ml.is_ready(dive), "not ready before it is asked for")
	t._check(ml.progress(dive) == 0.0, "no progress before it is asked")
	# 3. prefetch is idempotent: the second call queues nothing new.
	ml.prefetch(dive)
	var items: Array = ml.modules[dive].items
	t._check(items.size() > 1 and items[0] == dive,
		"the dive module is its scene and its models (%d files)"
		% items.size())
	t._check(items.has("res://models/rov/mangustik.glb")
		and items.has("res://models/posoh/hydrophone.glb"),
		"the dive module holds the ROV and its hydrophone")
	var lake := items.filter(func(s): return s.begins_with(
		"res://models/lake/"))
	t._check(lake.size() == 99, "all 99 lake models are in the dive "
		+ "module (%d)" % lake.size())
	var same: Dictionary = ml.modules[dive]
	ml.prefetch(dive)
	t._check(ml.modules.size() == 1 and is_same(ml.modules[dive], same),
		"a second prefetch changes nothing")
	# Progress is a share, and it only grows.
	var was := -1.0
	var sane := true
	var n := 0
	while not ml.is_ready(dive) and n < WAIT_FRAMES:
		var pr: float = ml.progress(dive)
		sane = sane and pr >= 0.0 and pr <= 1.0 and pr >= was - 1e-6
		was = pr
		await t.process_frame
		n += 1
	t._check(sane, "progress stays in 0..1 and never goes back")
	t._check(ml.is_ready(dive), "the dive is ready after %d frames" % n)
	t._check(ml.progress(dive) == 1.0, "a ready module is at 1.0")
	# 4. go after prefetch hands back the same scene the loader made.
	var held: Resource = ml.modules[dive].held[dive]
	t._check(held is PackedScene, "the scene is held as a PackedScene")
	var got: PackedScene = ml.go(dive)
	t._check(got != null and is_same(got, held),
		"go after prefetch returns the same PackedScene")
	t._check(ml.pending == dive, "go waits for the black before changing")
	# A second go while one is under way is ignored.
	ml.go(ml.WITNESS)
	t._check(ml.pending == dive, "a second go does not take over")
	# release calls the change off and lets the memory go; the scene of
	# the tests is not changed.
	ml.release(ml.WITNESS)
	ml.release(dive)
	t._check(ml.pending == "" and ml.modules.is_empty(),
		"release calls off the go and lets the module go")
	# 5. ahead keeps one module: a second way lets the first go.
	ml.ahead(ml.LOCATION)
	ml.ahead(ml.WITNESS)
	t._check(ml.modules.keys() == [ml.WITNESS],
		"ahead holds one module at a time: %s" % [ml.modules.keys()])
	ml.ahead("")
	t._check(ml.modules.is_empty() and ml.ahead_path == "",
		"ahead with nothing lets the last one go")
	# The loads let go while running are taken and dropped when done,
	# so nothing is left in the loader (a leak at exit otherwise).
	n = 0
	while not ml.dropping.is_empty() and n < WAIT_FRAMES:
		await t.process_frame
		n += 1
	t._check(ml.dropping.is_empty(), "the let-go loads are dropped")
	# Let the black of the called-off go clear before the next tests.
	for i in 40:
		await t.process_frame
	t._check(ml.phase == "" and ml.alpha == 0.0,
		"the black is gone after a called-off go")
