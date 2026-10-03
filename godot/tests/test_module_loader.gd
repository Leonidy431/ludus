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


## A scene file named in a string: "res://scenes/<name>.tscn".
const SCENE_RE := "\"res://scenes/[^\"]+\\.tscn\""


## The lines of a script that open a scene synchronously, in any of the
## three ways the frame of the press would carry the whole module:
##   * change_scene_to_file anywhere;
##   * change_scene_to_packed outside module_loader.gd, the one helper
##     that may change scene, and only behind its black;
##   * load or preload of a scene file, by its literal path or by a
##     constant of the same script that holds one (ResourceLoader.load
##     too; load_threaded_request is not a load and is not reported).
## A line that is a comment is skipped.
static func sync_changes(path: String) -> Array:
	var out := []
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var helper := path.get_file() == "module_loader.gd"
	var loads := [SCENE_RE]
	var consts := RegEx.create_from_string("^const\\s+(\\w+)\\s*(?::\\s*"
		+ "\\w+\\s*)?:?=\\s*" + SCENE_RE)
	for line in lines:
		var m := consts.search(line.strip_edges())
		if m != null:
			loads.append(m.get_string(1) + "\\b")
	var load_re := RegEx.create_from_string("\\b(?:pre)?load\\s*\\(\\s*(?:"
		+ "|".join(loads) + ")")
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("#"):
			continue
		var hit := "change_scene_to_file" in line
		hit = hit or (not helper and "change_scene_to_packed" in line)
		hit = hit or load_re.search(line) != null
		if hit:
			out.append("%s:%d %s" % [path, i + 1, line])
	return out


func run(t: Object) -> void:
	# 1. No synchronous change of scene anywhere in the game's scripts:
	# all the scenes of the game are big modules.
	var found := []
	for path in scripts_in("res://scripts"):
		found.append_array(sync_changes(path))
	t._check(found.is_empty(),
		"no synchronous scene change or scene load in godot/scripts: %s"
		% [found])
	# The check itself sees each way: a line written as the old hub had
	# it, a packed change, a load by path and by constant, a preload;
	# and it lets pass a comment, a threaded request, a constant alone
	# and a model's load.
	var probe := "user://module_loader_probe.gd"
	var f := FileAccess.open(probe, FileAccess.WRITE)
	f.store_string("\n".join([
		"const LOCKS := \"res://scenes/lock.tscn\"",
		"\tget_tree().change_scene_to_file(\"res://scenes/dive.tscn\")",
		"\tget_tree().change_scene_to_packed(ps)",
		"\tvar ps := load(\"res://scenes/witness.tscn\") as PackedScene",
		"\tvar p2 = ResourceLoader.load(LOCKS)",
		"const P := preload(\"res://scenes/hub.tscn\")",
		"# change_scene_to_file in a comment",
		"# load(\"res://scenes/dive.tscn\") in a comment",
		"\tResourceLoader.load_threaded_request(\"res://scenes/dive.tscn\")",
		"\tvar m := load(\"res://models/rov/mangustik.glb\")",
		"\tvar q := load(LOCKS_EXTRA)",
	]) + "\n")
	f.close()
	var seen := sync_changes(probe)
	t._check(seen.size() == 5, "the scan finds the five synchronous "
		+ "ways and skips the rest: %s" % [seen])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))
	t._check(sync_changes("res://scripts/module_loader.gd").is_empty(),
		"the helper's own packed change, behind its black, is allowed")
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
	await _lock(t, ml)
	await _missing(t, ml)


## The lock is a module the hub can reach (phase F3 of docs/HLD_
## CHORUS24_FIXES_2026-10-03.md), and B or Esc lead out of it.
func _lock(t: Object, ml: Node) -> void:
	var lock: String = ml.LOCK
	t._check(ResourceLoader.exists(lock), "the lock scene exists: " + lock)
	ml.prefetch(lock)
	t._check(ml.modules[lock].items == [lock],
		"the lock module is its scene alone (it loads no model)")
	var n := 0
	while not ml.is_ready(lock) and n < WAIT_FRAMES:
		await t.process_frame
		n += 1
	t._check(ml.modules[lock].held.get(lock) is PackedScene,
		"the lock scene is loaded ahead in %d frames" % n)
	# The way in names the lock; the scene takes the id once.
	ml.go_lock("buoy_hearing")
	t._check(ml.pending == lock and ml.lock_id == "buoy_hearing",
		"go_lock goes to the lock scene with its lock")
	ml.release(lock)
	t._check(ml.pending == "" and ml.modules.is_empty(),
		"release calls off the way to the lock")
	t._check(ml.take_lock_id() == "buoy_hearing"
		and ml.take_lock_id() == "", "the lock id is taken once")
	var nav: Node = t.root.get_node_or_null("Nav")
	t._check(nav != null and lock in nav.EXITS
		and nav.EXITS.has(ml.DIVE) and nav.EXITS.has(ml.WITNESS),
		"B and Esc lead out of the lock, the dive and the witness")
	for i in 40:
		await t.process_frame


## Catches the errors the loader pushes, so the test can see the path.
## The loader pushes them from the main thread, in its _process; an
## error of the engine's own loader thread may come in too, and only
## appends a line.
class Catch:
	extends Logger
	var lines: PackedStringArray = []

	func _log_error(_function: String, _file: String, _line: int,
			code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array) -> void:
		lines.append(rationale if rationale != "" else code)

	func has(text: String) -> bool:
		for l in lines:
			if text in l:
				return true
		return false


## A scene that does not load is named, not lost: push_error with its
## path, the way over is called off and the black lifts.
func _missing(t: Object, ml: Node) -> void:
	var nope := "res://scenes/no_such_module.tscn"
	var catch := Catch.new()
	OS.add_logger(catch)
	print("test_module_loader: two errors about %s are expected" % nope)
	var before: Node = t.current_scene
	ml.go(nope)
	var n := 0
	while (ml.pending != "" or ml.phase != "") and n < WAIT_FRAMES:
		await t.process_frame
		n += 1
	OS.remove_logger(catch)
	t._check(nope in ml.failed, "the failed path is recorded: %s"
		% [ml.failed])
	t._check(catch.has("ModuleLoader") and catch.has(nope),
		"push_error names the scene that failed to load")
	t._check(ml.pending == "" and ml.modules.is_empty()
		and t.current_scene == before,
		"a scene that fails to load calls the way over off")
	t._check(ml.phase == "" and ml.alpha == 0.0,
		"the black lifts after a failed way over")
