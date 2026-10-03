## Big modules load in the background (autoload "ModuleLoader").
##
## CLAUDE.md TABOO 0.014: a big module (the dive with the ROV, the path
## of the witness, a place of the 99, the courtyard) is never loaded in
## the frame of the press.  A scene asks for it while the player walks
## towards it (prefetch), and the way over (go) waits behind a black
## fade until the threaded load is done; only then does the tree change
## scene.  One helper for the whole game, so that no scene writes its
## own loading (item 3).  Phase S1 of docs/HLD_12_STORIES_HEADSET_
## 2026-10-02.md.
##
## A module is its scene plus the models the scene loads in its own
## _ready: the scenes are a root node with a script and build the rest
## by code, so the scene file alone is a few kilobytes and the weight is
## in the .glb files they load().  While this helper holds those
## resources, the scene's own load() finds them in the cache and does
## not touch the disk in the frame of the change.
extends Node

const HUB := "res://scenes/hub.tscn"
const DIVE := "res://scenes/dive.tscn"
const WITNESS := "res://scenes/witness.tscn"
const LOCATION := "res://scenes/location.tscn"
## The lock at arm's length (TABOO 0.024): the scene builds its board,
## its buoy and its sound by code and loads no model, so the module is
## the scene file and its scripts alone.  It still goes through this
## helper, so the way to it is one breath of black and not a cut, and
## Nav's B brings the player back from it (phase F3 of
## docs/HLD_CHORUS24_FIXES_2026-10-03.md).
const LOCK := "res://scenes/lock.tscn"

## The files each scene loads in _ready: a folder takes all its .glb,
## a name with "*" takes what matches it.  The dive loads the lake
## objects, the knight's traces, the ROV and its hydrophone (dive.gd,
## rov_lod.gd, rov_body.gd), the fish atlases (fish_drawings.gd) and the
## stones and weeds of its own drawings (dive.gd OWN_DRAWINGS); the
## witness loads the seven sacrament sets (witness.gd).  A place loads
## only its own few models, chosen by its plan, so it keeps to the
## scene file.
const ASSETS := {
	DIVE: ["res://models/lake/", "res://models/atlas/", "res://models/rov/",
		"res://models/posoh/hydrophone.glb",
		"res://art/derived/DEF-056/*_atlas.png",
		"res://art/derived/DEF-057/own_*.png",
		"res://art/derived/DEF-058/own_*.png",
		"res://art/derived/DEF-059/own_*.png"],
	WITNESS: ["res://models/scene/"],
}

## The black comes in and goes out over this time: long enough not to
## be a cut in the headset, short enough to be one breath.
const FADE_SECONDS := 0.35
## The fade quad sits just past the near plane of every rig (0.05 m in
## the hub and the places, 0.1 m in the dive).
const FADE_DISTANCE := 0.12

## scene path -> {items: Array[String], held: {path: Resource}}.
var modules := {}
## Files of let-go modules whose threaded load was still running.
var dropping: Array[String] = []
## The module looked ahead to (ahead); "" if none.
var ahead_path := ""
## Set by the budget tools only: while true nothing is fetched ahead, so
## a place or a scene is measured alone (TABOO 0.011 item 7); the tool
## asks for a module itself when it measures "scene + module".
var hold_ahead := false
## The scene the player is going to, while the fade holds; "" if none.
var pending := ""
## The lock the lock scene opens on (an id of godot/data/locks.json),
## set by go_lock and taken by the scene in its _ready; "" for the
## scene's own default.
var lock_id := ""
## Every path that failed to load, oldest first, so a test and a log
## can name it; the same line goes to push_error when it happens.
var failed: Array[String] = []
## 0 clear, 1 black.
var alpha := 0.0
## "in" while the black comes, "out" after the change, "" at rest.
var phase := ""
## Frames since the change: the black stays full while the new scene
## builds itself and its camera comes in.
var since_switch := 0
var quad: MeshInstance3D
var layer: CanvasLayer
var rect: ColorRect


## Ask for a module ahead of need.  Asking again for the same module
## does nothing, so a hook may call this every frame the player stands
## near the way in.
func prefetch(path: String) -> void:
	if modules.has(path):
		return
	var items: Array[String] = [path]
	for a in ASSETS.get(path, []):
		items.append_array(_expand(a))
	for it in items:
		# Asked for again before a let-go load finished: it is this
		# module's once more, not to be dropped.
		dropping.erase(it)
		# A new attempt at a file that failed before is reported anew.
		failed.erase(it)
		# A path already in the cache (the ROV of the pier in the hub)
		# is only held, not queued again.
		if ResourceLoader.has_cached(it):
			continue
		var err := ResourceLoader.load_threaded_request(it)
		if err != OK:
			_fail(it, "the request was refused (%s)" % error_string(err))
	modules[path] = {"items": items, "held": {}}


## Go over to the lock scene on one lock: the scene reads the id from
## here in its _ready, so a hub hook needs only this one call.
func go_lock(id: String) -> PackedScene:
	if pending == "" or pending == LOCK:
		lock_id = id
	return go(LOCK)


## The lock id the lock scene was sent to, taken once: a later visit
## with no id opens the scene's own default again.
func take_lock_id() -> String:
	var id := lock_id
	lock_id = ""
	return id


## The one module a scene looks ahead to as the player walks: asking
## for another lets the last one go, and "" lets it go with nothing in
## its place, so the courtyard never holds the dive and a place at once
## (item 4: two big modules together only on the way over).
func ahead(path: String) -> void:
	if hold_ahead:
		path = ""
	if path == ahead_path:
		return
	if ahead_path != "" and ahead_path != pending:
		release(ahead_path)
	ahead_path = path
	if path != "":
		prefetch(path)


## True when the scene and every model it loads are in memory.
func is_ready(path: String) -> bool:
	return modules.has(path) and progress(path) >= 1.0


## From 0 to 1: the share of the module's files loaded so far; 0 for a
## module not asked for.
func progress(path: String) -> float:
	if not modules.has(path):
		return 0.0
	var m: Dictionary = modules[path]
	var done := 0.0
	for it in m.items:
		done += _item_progress(m, it)
	return done / float(maxi(1, m.items.size()))


## Go over to a module: the black comes in, and the scene changes only
## when the module is loaded and the black is full.  Returns the scene
## if it is loaded already, else null (the change still comes, later).
## A second go while one is under way is ignored.
func go(path: String) -> PackedScene:
	if pending != "" and pending != path:
		return null
	prefetch(path)
	if pending == "":
		pending = path
		phase = "in"
		_show_fade()
	if is_ready(path):
		return _held(path) as PackedScene
	return null


## Let a module go: its resources leave memory once nothing else in the
## game holds them.  A pending go to it is called off.
func release(path: String) -> void:
	if pending == path:
		pending = ""
		phase = "out"
		since_switch = 3
	if ahead_path == path:
		ahead_path = ""
	if not modules.has(path):
		return
	# A load still running cannot be stopped, and the loader keeps what
	# it made until it is taken; so it is taken when done and dropped.
	var m: Dictionary = modules[path]
	for it in m.items:
		if not m.held.has(it) and not it in dropping:
			dropping.append(it)
	modules.erase(path)


func _process(dt: float) -> void:
	for path in modules:
		if path != pending:
			_poll(path)
	for it in dropping.duplicate():
		var st := ResourceLoader.load_threaded_get_status(it)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(it)
		if st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			dropping.erase(it)
	match phase:
		"in":
			alpha = minf(1.0, alpha + dt / FADE_SECONDS)
			if alpha >= 1.0 and pending != "" and is_ready(pending):
				_switch()
		"out":
			since_switch += 1
			# The frame of the new scene's _ready is long; its time is
			# not counted, or the black would be gone before it is seen.
			if since_switch > 2:
				alpha = maxf(0.0, alpha - minf(dt, 0.05) / FADE_SECONDS)
			if alpha <= 0.0:
				phase = ""
				_hide_fade()
	if phase != "":
		_show_fade()
		_paint()


## Collect what the loader finished, so the progress of a module waited
## on behind no fade still moves.
func _poll(path: String) -> void:
	var m: Dictionary = modules[path]
	for it in m.items:
		_item_progress(m, it)


func _item_progress(m: Dictionary, it: String) -> float:
	if m.held.has(it):
		return 1.0
	var none := ResourceLoader.load_threaded_get_status(it) \
		== ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	if none and ResourceLoader.has_cached(it):
		# Loaded by someone else before the request: take it from the
		# cache, which costs nothing now.
		m.held[it] = ResourceLoader.load(it)
		return 1.0
	var pr := []
	var st := ResourceLoader.load_threaded_get_status(it, pr)
	match st:
		ResourceLoader.THREAD_LOAD_LOADED:
			m.held[it] = ResourceLoader.load_threaded_get(it)
			return 1.0
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return float(pr[0]) if pr.size() > 0 else 0.0
		_:
			# A failed file is counted done: the scene keeps its own
			# fallback (a blob for a missing model) and the player is
			# not held in the black for ever.  It is named, though: a
			# way over that silently comes to nothing cannot be fixed.
			m.held[it] = null
			if st == ResourceLoader.THREAD_LOAD_FAILED:
				# Taken even so, or the loader keeps the failed task
				# (and an object of it) until the game quits.
				ResourceLoader.load_threaded_get(it)
			_fail(it, "the threaded load failed")
			return 1.0


## Record a file that did not load and say so in the log, once per
## file and module (the loader is polled every frame).
func _fail(path: String, why: String) -> void:
	if path in failed:
		return
	failed.append(path)
	push_error("ModuleLoader: %s: %s" % [why, path])


func _held(path: String) -> Resource:
	return modules[path].held.get(path) if modules.has(path) else null


## The change itself, behind full black: the scene from memory, then
## every module let go, the one entered included, since its nodes now
## hold what they use and the one left frees with its nodes (item 4).
func _switch() -> void:
	var target := pending
	var scene := _held(pending) as PackedScene
	pending = ""
	phase = "out"
	since_switch = 0
	if scene != null:
		get_tree().change_scene_to_packed(scene)
	else:
		# The player stays where he was, and the black lifts; the
		# error names the scene, so the way over is not lost in silence.
		push_error("ModuleLoader: the scene could not be loaded, the "
			+ "way over is called off: " + target)
	for path in modules.keys():
		release(path)
	# The old camera goes with the old scene; the black is put again on
	# the new one in the next frame.
	_hide_fade()


func _expand(a: String) -> Array[String]:
	var out: Array[String] = []
	var dir := a.get_base_dir() + "/"
	var mask := a.get_file()
	if mask == "":
		mask = "*.glb"
	elif not "*" in mask:
		if ResourceLoader.exists(a):
			out.append(a)
		return out
	# list_directory also reads an exported pack, where the folder holds
	# only the imported names.
	for f in ResourceLoader.list_directory(dir):
		if f.match(mask):
			out.append(dir + f)
	out.sort()
	return out


# --- The black --------------------------------------------------------------

## A black quad on the camera, drawn over everything: it is seen in the
## headset, where a 2D layer is not; the layer covers the flat screen
## and the web page before a camera exists.
func _show_fade() -> void:
	if layer == null:
		layer = CanvasLayer.new()
		layer.layer = 128
		rect = ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(rect)
		add_child(layer)
	var cam := get_viewport().get_camera_3d()
	if cam != null and (quad == null or quad.get_parent() != cam):
		_hide_quad()
		quad = MeshInstance3D.new()
		quad.name = "ModuleFade"
		var q := QuadMesh.new()
		q.size = Vector2(4, 4)
		quad.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 127
		quad.material_override = m
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		quad.position = Vector3(0, 0, -FADE_DISTANCE)
		cam.add_child(quad)
	_paint()


func _paint() -> void:
	if rect != null:
		rect.color = Color(0, 0, 0, alpha)
	if quad != null and is_instance_valid(quad):
		(quad.material_override as StandardMaterial3D).albedo_color = \
			Color(0, 0, 0, alpha)


func _hide_quad() -> void:
	if quad != null and is_instance_valid(quad):
		quad.queue_free()
	quad = null


func _hide_fade() -> void:
	_hide_quad()
	if rect != null and phase == "":
		rect.color = Color(0, 0, 0, 0)
