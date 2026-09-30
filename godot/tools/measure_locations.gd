## Budgets of the 99 locations (CLAUDE.md TABOO 0.011; docs/HLD_LOCATIONS_
## 99_2026-09-30.md), rendered under Xvfb:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##     --rendering-driver opengl3 -s res://tools/measure_locations.gd \
##     -- [--out=<file.json>] [--only=a,b,c] [--check] [--budgets=<file>]
##
## First an empty 3D scene at the same window size is drawn, so the
## texture memory of a place is counted above the render targets alone
## (as tools/measure_budgets.gd does).  Then one process builds every
## place in the real location.tscn, one after another, and holds the
## player at four views of each: at the door facing the heart, from the
## middle of the place looking at each side wall, and at the heart with
## its birch-bark panel open (the panel and its words are drawn over the
## place, so they count).  Each view settles, then the renderer is read:
## the whole frame's draw calls (3D and canvas, as measure_budgets.gd's
## draw_calls_frame), the main view's 3D and canvas calls apart, its
## primitives (twice, for two eyes), the objects, the CPU heap over the
## start and the texture memory over the empty scene.  The scene's
## triangles are counted from its meshes, with the time the build took
## and the bytes of the model files it loads.
##
## The report is one JSON file with a row per place and the worst of
## each; the last line printed is "LOCATIONS_JSON {worst}".  With
## --check the worst place is held to the "scene" section of
## scripts/godot/apk-budgets.json, the same limits as hub, dive and
## witness (the locations have no exception): a breach prints the row
## and exits 1, missing budgets exit 2 (TABOO 0.011 item 4: a breach
## stops the line).  The numbers come from the host's GPU driver and a
## 1280x720 desktop camera, not from a Quest 3: an early warning; the
## headset's own numbers are the OVR Metrics Tool's.
extends SceneTree

const SETTLE := 6
const SAMPLE := 3
const EMPTY_FRAMES := 8
## The metrics held to the budgets, each with the scene budget's key.
const CHECKED := ["draw_calls_frame", "primitives_two_eyes_est",
	"static_memory_delta_bytes", "texture_memory_over_empty_bytes"]

var out_path := ""
var budgets_path := ""
var check := false
var only: Array = []
var scene: Node
var empty: Node3D
var empty_tex := 0
var ids: Array = []
var step := -2
var view := 0
var frame := 0
var rows: Array = []
var row := {}
var base_static := 0


func _initialize() -> void:
	budgets_path = ProjectSettings.globalize_path("res://").path_join(
		"../scripts/godot/apk-budgets.json").simplify_path()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(",", false))
		elif a == "--check":
			check = true
		elif a.begins_with("--budgets="):
			budgets_path = a.trim_prefix("--budgets=")
	# Memory is read against the process before the scene exists, so
	# each place's row counts the scene with that place standing.
	base_static = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var data := LocationCore.load_data()
	for loc in data.locations:
		if only.is_empty() or loc.id in only:
			ids.append(loc.id)
	empty = Node3D.new()
	var cam := Camera3D.new()
	cam.current = true
	cam.position = Vector3(0, 0, 3)
	empty.add_child(cam)
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	empty.add_child(box)
	root.add_child(empty)


func _views(p: Dictionary) -> Array:
	var mid := Vector3(0, 0, (p.heart.z + p.start.z) / 2.0)
	return [{"name": "door", "pos": p.start, "yaw": 0.0},
		{"name": "left", "pos": mid, "yaw": PI / 2.0},
		{"name": "right", "pos": mid, "yaw": -PI / 2.0},
		{"name": "panel", "pos": p.heart + Vector3(0, 0, 1.3), "yaw": 0.0,
			"panel": true}]


func _process(_dt: float) -> bool:
	frame += 1
	if step == -2:
		# The empty scene first: its texture memory is the baseline.
		empty_tex = maxi(empty_tex, int(Performance.get_monitor(
			Performance.RENDER_TEXTURE_MEM_USED)))
		if frame < EMPTY_FRAMES:
			return false
		empty.free()
		scene = (load(LocationCore.SCENE) as PackedScene).instantiate()
		scene.location_id = ids[0]
		root.add_child(scene)
		step = -1
		frame = 0
		return false
	if step == -1:
		if frame < 3:
			return false
		_next()
		return false
	var views := _views(scene.p)
	var v: Dictionary = views[view]
	scene.pos = v.pos
	scene.yaw = v.yaw
	if v.get("panel", false) and scene.heart_panel.is_empty():
		# Opened as the scene opens it, but not through _apply: nothing
		# is saved by a measure.
		scene.heart_panel = LocationHeart.open(scene.loc, scene.st,
			scene.ctx).panel
	elif not v.get("panel", false):
		scene.heart_panel = {}
	if frame > SETTLE:
		_sample(v.name)
	if frame >= SETTLE + SAMPLE:
		view += 1
		frame = 0
		if view >= views.size():
			scene.heart_panel = {}
			rows.append(row)
			step += 1
			if step >= ids.size():
				quit(_finish())
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
		"draw_calls_frame": 0, "draw_calls_view": "",
		"draw_calls_3d": 0, "draw_calls_canvas": 0, "primitives": 0,
		"primitives_two_eyes_est": 0, "objects": 0,
		"static_memory_delta_bytes": 0,
		"texture_memory_over_empty_bytes": 0}
	view = 0
	frame = 0


func _sample(view_name: String) -> void:
	var vis := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var can := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS
	var dc := RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
	var pr := RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME
	var rid := root.get_viewport_rid()
	var frame_dc := int(Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if frame_dc > row.draw_calls_frame:
		row.draw_calls_frame = frame_dc
		row.draw_calls_view = view_name
	row.draw_calls_3d = maxi(row.draw_calls_3d,
		RenderingServer.viewport_get_render_info(rid, vis, dc))
	row.draw_calls_canvas = maxi(row.draw_calls_canvas,
		RenderingServer.viewport_get_render_info(rid, can, dc))
	var prim := RenderingServer.viewport_get_render_info(rid, vis, pr)
	row.primitives = maxi(row.primitives, prim)
	row.primitives_two_eyes_est = maxi(row.primitives_two_eyes_est,
		2 * prim)
	row.objects = maxi(row.objects, RenderingServer.viewport_get_render_info(
		rid, vis, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME))
	row.static_memory_delta_bytes = maxi(row.static_memory_delta_bytes,
		int(Performance.get_monitor(Performance.MEMORY_STATIC))
		- base_static)
	row.texture_memory_over_empty_bytes = maxi(
		row.texture_memory_over_empty_bytes, int(Performance.get_monitor(
			Performance.RENDER_TEXTURE_MEM_USED)) - empty_tex)


func _finish() -> int:
	var worst := {}
	for k in ["draw_calls_frame", "draw_calls_3d", "draw_calls_canvas",
			"primitives", "primitives_two_eyes_est", "objects",
			"triangles_scene", "model_bytes", "build_ms",
			"static_memory_delta_bytes", "texture_memory_over_empty_bytes"]:
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
	worst["empty_texture_bytes"] = empty_tex
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"worst": worst, "rows": rows},
				"  "))
	print("LOCATIONS_JSON ", JSON.stringify(worst))
	scene.free()
	return _check(worst) if check else 0


## Hold every place to the scene budgets; the table is printed either
## way.  0 within, 1 on a breach, 2 when the budgets cannot be read.
func _check(worst: Dictionary) -> int:
	if not FileAccess.file_exists(budgets_path):
		print("ПРОВЕРКА невозможна: нет файла " + budgets_path)
		return 2
	var data = JSON.parse_string(FileAccess.get_file_as_string(budgets_path))
	var b: Dictionary = data.get("scene", {}) if data is Dictionary else {}
	var rc := 0
	for k in CHECKED:
		if not b.has(k):
			print("ПРОВЕРКА невозможна: нет scene.%s в %s" % [k,
				budgets_path])
			return 2
		# The locations have no exception: each is held to the base.
		var limit := float(b[k].limit)
		var got := float(worst[k].value)
		var ok := got <= limit
		print("%s %s: %d (место %s) из %d" % ["ок" if ok else "ПРЕВЫШЕНИЕ",
			k, int(got), worst[k].id, int(limit)])
		if not ok:
			rc = 1
			for r in rows:
				if float(r[k]) > limit:
					print("  %s: %d" % [r.id, int(r[k])])
	print("ПРОВЕРКА мест: " + ("все бюджеты соблюдены" if rc == 0
		else "бюджет превышен"))
	return rc
