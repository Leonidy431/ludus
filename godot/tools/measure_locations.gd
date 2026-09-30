## Budgets of the 99 locations (CLAUDE.md TABOO 0.011; docs/HLD_LOCATIONS_
## 99_2026-09-30.md), rendered under Xvfb:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##     --rendering-driver opengl3 -s res://tools/measure_locations.gd \
##     -- --out=<file.json> [--only=a,b,c]
##
## One process builds every place in the real location.tscn, one after
## another, and holds the player at three views of each: at the door
## facing the heart, and from the middle of the place looking at each
## side wall.  Each view settles, then the main view's draw calls and
## primitives are read from the renderer (as tools/measure_budgets.gd
## reads them), with the scene's triangles counted from its meshes, the
## time the build took, and the bytes of the model files it loads.  The
## report is one JSON file with a row per place and the worst of each;
## the last line printed is "LOCATIONS_JSON {worst}".  The numbers come
## from the host's GPU driver and a 1280x720 desktop camera, not from a
## Quest 3: an early warning; the headset's own numbers are the OVR
## Metrics Tool's.
extends SceneTree

const SETTLE := 6
const SAMPLE := 3

var out_path := ""
var only: Array = []
var scene: Node
var ids: Array = []
var step := -1
var view := 0
var frame := 0
var rows: Array = []
var row := {}
var base_static := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(",", false))
	# Memory is read against the process before the scene exists, so
	# each place's row counts the scene with that place standing.
	base_static = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var data := LocationCore.load_data()
	for loc in data.locations:
		if only.is_empty() or loc.id in only:
			ids.append(loc.id)
	scene = (load(LocationCore.SCENE) as PackedScene).instantiate()
	scene.location_id = ids[0]
	root.add_child(scene)


func _views(p: Dictionary) -> Array:
	var mid := Vector3(0, 0, (p.heart.z + p.start.z) / 2.0)
	return [{"name": "door", "pos": p.start, "yaw": 0.0},
		{"name": "left", "pos": mid, "yaw": PI / 2.0},
		{"name": "right", "pos": mid, "yaw": -PI / 2.0}]


func _process(_dt: float) -> bool:
	frame += 1
	if step == -1:
		if frame < 3:
			return false
		_next()
		return false
	var views := _views(scene.p)
	var v: Dictionary = views[view]
	scene.pos = v.pos
	scene.yaw = v.yaw
	if frame > SETTLE:
		_sample(v.name)
	if frame >= SETTLE + SAMPLE:
		view += 1
		frame = 0
		if view >= views.size():
			rows.append(row)
			step += 1
			if step >= ids.size():
				_finish()
				return true
			_next()
	return false


## Build the next place and start its row.
func _next() -> void:
	if step == -1:
		step = 0
	var t0 := Time.get_ticks_usec()
	scene.open_place(ids[step])
	var build_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var files := {}
	for s in scene.p.slots:
		if s.model.path != "":
			files[s.model.path] = true
	var bytes := 0
	for f in files:
		var fa := FileAccess.open(f, FileAccess.READ)
		if fa:
			bytes += fa.get_length()
	row = {"id": ids[step], "type": scene.p.type,
		"light": scene.p.light["class"], "things": scene.p.slots.size(),
		"missing": scene.p.missing.size(), "model_files": files.size(),
		"model_bytes": bytes, "build_ms": snappedf(build_ms, 0.1),
		"triangles_scene": LocationBuild.triangles(scene.world),
		"draw_calls": 0, "draw_calls_view": "", "primitives": 0,
		"objects": 0, "static_memory_bytes": int(
			Performance.get_monitor(Performance.MEMORY_STATIC)) - base_static}
	view = 0
	frame = 0


func _sample(view_name: String) -> void:
	var vis := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var rid := root.get_viewport_rid()
	var dc := RenderingServer.viewport_get_render_info(rid, vis,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var pr := RenderingServer.viewport_get_render_info(rid, vis,
		RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var ob := RenderingServer.viewport_get_render_info(rid, vis,
		RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
	if dc > row.draw_calls:
		row.draw_calls = dc
		row.draw_calls_view = view_name
	row.primitives = maxi(row.primitives, pr)
	row.objects = maxi(row.objects, ob)


func _finish() -> void:
	var worst := {}
	for k in ["draw_calls", "primitives", "objects", "triangles_scene",
			"model_bytes", "build_ms", "static_memory_bytes"]:
		var best := {}
		for r in rows:
			if best.is_empty() or r[k] > best[k]:
				best = r
		worst[k] = {"value": best[k], "id": best.id}
	var total_missing := 0
	for r in rows:
		total_missing += int(r.missing)
	worst["places"] = rows.size()
	worst["missing_things"] = total_missing
	worst["renderer"] = RenderingServer.get_video_adapter_name()
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"worst": worst, "rows": rows},
				"  "))
	print("LOCATIONS_JSON ", JSON.stringify(worst))
	scene.free()
	quit(0)
