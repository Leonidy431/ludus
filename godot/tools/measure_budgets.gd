## Runtime budgets of one headset scene (docs/APK_REQUIREMENTS.md).
##
## Rendered, under Xvfb (draw calls, primitives, memory):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##     --rendering-driver opengl3 -s res://tools/measure_budgets.gd \
##     -- --scene=dive [--check]
## Headless at the headset's 72 Hz pace (the scene's own script time):
##   godot --headless --max-fps 72 --path godot \
##     -s res://tools/measure_budgets.gd -- --scene=dive [--check]
## --view=<name> keeps one view, e.g. --scene=hub --view=evening-cell for
## the location standard of CLAUDE.md TABOO 0.013.
##
## One scene per process, so the memory of one scene does not stay in
## the baseline of the next.  The scene is placed at fixed views, and
## each view is sampled after it settles; the report is the maximum
## over all views, printed as one line "BUDGET_JSON {...}".  --check
## compares it with the "scene" section of scripts/godot/apk-budgets.json
## and exits with 1 on a breach.  Rendered numbers come from the host's
## GPU driver and a 1280x720 desktop camera, not from a Quest 3: they
## are an early warning, and the headset's own numbers are taken with
## the OVR Metrics Tool.
##
## The scene's own _process is called from here with the node's own
## processing switched off, so its cost is timed on its own.  Saves
## (user://hub.json, user://dive.json) are written only by player
## actions, which this script does not make.
extends SceneTree

const SETTLE := 20
const SAMPLE := 10
const EMPTY_FRAMES := 6

var scene_name := ""
var check := false
var budgets_path := ""
var only_view := ""
var node: Node
var views: Array = []
var step := -1
var frame := 0
var empty: Node3D
var empty_tex := 0
var base_static := 0
var proc_ms: Array = []
var proc_max_view := ""
var worst := {}
var failed := false


func _initialize() -> void:
	budgets_path = ProjectSettings.globalize_path("res://").path_join(
		"../scripts/godot/apk-budgets.json").simplify_path()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene_name = a.trim_prefix("--scene=")
		elif a == "--check":
			check = true
		elif a.begins_with("--budgets="):
			budgets_path = a.trim_prefix("--budgets=")
		elif a.begins_with("--view="):
			only_view = a.trim_prefix("--view=")
	if not scene_name in ["hub", "dive", "witness"]:
		printerr("measure_budgets: --scene=hub|dive|witness is required")
		failed = true
		return
	# The texture memory of an empty 3D scene at the same window size
	# and MSAA is the render targets alone; the scene is measured above
	# it.  Headless has no renderer, so it has nothing to subtract.
	if not _headless():
		empty = Node3D.new()
		var cam := Camera3D.new()
		cam.current = true
		cam.position = Vector3(0, 0, 3)
		empty.add_child(cam)
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		empty.add_child(box)
		root.add_child(empty)


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _process(delta: float) -> bool:
	if failed:
		quit(2)
		return true
	frame += 1
	if step == -1:
		return _measure_empty()
	if step >= views.size():
		_finish()
		return true
	var v: Dictionary = views[step]
	_apply(v)
	var t0 := Time.get_ticks_usec()
	node._process(delta)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	if frame > SETTLE:
		if proc_ms.is_empty() or ms > proc_ms.max():
			proc_max_view = v.name
		proc_ms.append(ms)
		_sample(v.name)
	if frame >= SETTLE + SAMPLE:
		step += 1
		frame = 0
	return false


## First frames: the empty scene; then the real scene is loaded.
func _measure_empty() -> bool:
	if empty != null:
		empty_tex = maxi(empty_tex, int(Performance.get_monitor(
			Performance.RENDER_TEXTURE_MEM_USED)))
		if frame < EMPTY_FRAMES:
			return false
		empty.free()
		empty = null
	base_static = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var ps := load("res://scenes/%s.tscn" % scene_name) as PackedScene
	node = ps.instantiate()
	root.add_child(node)
	current_scene = node
	node.set_process(false)
	views = _views()
	if only_view != "":
		views = views.filter(func(v): return v.name == only_view)
		if views.is_empty():
			printerr("measure_budgets: no view '%s' in %s" % [only_view,
				scene_name])
			failed = true
			return false
	step = 0
	frame = 0
	return false


## Fixed views per scene: the places where the most is in sight.
func _views() -> Array:
	match scene_name:
		"hub":
			return [
				{"name": "start", "pos": Vector3(0, 0, 3), "yaw": 0.0},
				{"name": "start-yaw90", "pos": Vector3(0, 0, 3),
					"yaw": PI / 2.0},
				{"name": "start-yaw270", "pos": Vector3(0, 0, 3),
					"yaw": -PI / 2.0},
				{"name": "courtyard", "pos": Vector3(0, 0, 5.5), "yaw": 0.0},
				{"name": "pier", "pos": Vector3(5.5, 0, 0.6),
					"yaw": -PI / 2.0},
				{"name": "mentors", "pos": Vector3(-2.2, 0, 0),
					"yaw": PI / 2.0},
				# The location standard (TABOO 0.013): the view of
				# hub.gd --shots "evening-cell".
				{"name": "evening-cell", "pos": Vector3(-5.0, 0, -5.0),
					"yaw": 0.0},
			]
		"dive":
			var out := []
			for d in [3.0, 12.0, 35.0, 60.0, 120.0]:
				out.append({"name": "depth-%dm" % int(d), "depth": d})
			out.append({"name": "khachkar", "trace": "khachkar"})
			out.append({"name": "diary", "trace": "diary"})
			out.append({"name": "depth-60m-first-person", "depth": 60.0,
				"first": true})
			return out
		"witness":
			var out := [{"name": "start", "pos": Vector3(-1, 0, 0)}]
			for i in [0, 3, 6]:
				out.append({"name": "bay-%d" % i,
					"pos": Vector3(8.0 + 15.0 * i, 0, 0)})
			return out
	return []


## Hold the player at the view every frame, as a still headset would.
func _apply(v: Dictionary) -> void:
	match scene_name:
		"hub":
			node.pos = v.pos
			node.yaw = v.yaw
		"witness":
			node.pos = v.pos
			node.yaw = -PI / 2.0
		"dive":
			var rov: Dictionary = node.rov
			if v.has("trace"):
				var tr := {}
				for x in node.traces:
					if x.id == v.trace:
						tr = x
				if tr.is_empty():
					return
				var back: float = {"diary": 3.5, "khachkar": 2.6}[v.trace]
				rov.x = tr.x - back
				rov.z = tr.z - 1.2
				rov.depth = DiveCore.floor_depth(rov.x, rov.z) - 1.2
				node.pitch = -0.2
			else:
				rov.x = DiveCore.x_for_depth(v.depth + 6.0) - 8.0
				rov.z = 0.0
				rov.depth = v.depth
				node.pitch = -0.25
			rov.yaw = 0.0
			rov.lamp = true
			rov.vx = 0.0
			rov.vy = 0.0
			rov.vz = 0.0
			var first: bool = v.get("first", false)
			if node.third_person == first:
				node.third_person = not first
				node._place_view()


func _info(rid: RID, kind: int, what: int) -> int:
	return RenderingServer.viewport_get_render_info(rid, kind, what)


func _sample(view: String) -> void:
	var vis := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var can := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS
	var dc := RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
	var pr := RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME
	var main := root.get_viewport_rid()
	var main_dc := _info(main, vis, dc)
	var main_prim := _info(main, vis, pr)
	# Under multiview one draw call covers both eyes, but every vertex
	# is shaded once per eye; a SubViewport is mono and drawn once.
	var sub_prim := 0
	var sub_px := 0
	for sv in node.find_children("*", "SubViewport", true, false):
		var rid: RID = (sv as SubViewport).get_viewport_rid()
		sub_prim += _info(rid, vis, pr) + _info(rid, can, pr)
		sub_px += (sv as SubViewport).size.x * (sv as SubViewport).size.y
	var row := {
		"draw_calls_main_view": main_dc,
		"draw_calls_all_viewports": int(Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives_main_view": main_prim,
		"primitives_two_eyes_est": 2 * main_prim + sub_prim,
		"objects_all_viewports": int(Performance.get_monitor(
			Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"static_memory_delta_bytes": int(Performance.get_monitor(
			Performance.MEMORY_STATIC)) - base_static,
		"texture_memory_over_empty_bytes": int(Performance.get_monitor(
			Performance.RENDER_TEXTURE_MEM_USED)) - empty_tex,
		"video_memory_bytes": int(Performance.get_monitor(
			Performance.RENDER_VIDEO_MEM_USED)),
		"subviewport_px": sub_px,
	}
	for k in row:
		if row[k] > worst.get(k, {"value": -1}).value:
			worst[k] = {"value": row[k], "view": view}


func _finish() -> void:
	var per_px := 8
	var budgets := _load_budgets()
	var scene_b: Dictionary = budgets.get("scene", {})
	if scene_b.has("subviewport_bytes"):
		per_px = int(scene_b.subviewport_bytes.get("bytes_per_px", 8))
	var sum := 0.0
	var mx := 0.0
	for v in proc_ms:
		sum += v
		mx = maxf(mx, v)
	# Every AudioStreamGenerator is a synth the CPU feeds each frame.
	var gens := 0
	for c in node.find_children("*", "", true, false):
		var player := (c is AudioStreamPlayer or c is AudioStreamPlayer2D
			or c is AudioStreamPlayer3D)
		if player and c.stream is AudioStreamGenerator:
			gens += 1
	var out := {
		"scene": scene_name,
		"audio_generators": gens,
		"mode": "headless" if _headless() else "rendered",
		"adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"window": str(root.get_visible_rect().size),
		"msaa_3d": root.msaa_3d,
		"views": views.size(),
		"script_ms_mean_host": snappedf(sum / maxf(1.0, proc_ms.size()),
			0.001),
		"script_ms_max_host": snappedf(mx, 0.001),
		"script_ms_max_view": proc_max_view,
		"worst": worst,
	}
	if worst.has("subviewport_px"):
		out["subviewport_bytes_est"] = worst.subviewport_px.value * per_px
	print("BUDGET_JSON " + JSON.stringify(out))
	var code := 0
	if check:
		code = _check(out, scene_b)
	node.queue_free()
	quit(code)


func _load_budgets() -> Dictionary:
	if not FileAccess.file_exists(budgets_path):
		printerr("measure_budgets: no budgets file " + budgets_path)
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(budgets_path))
	return data if data is Dictionary else {}


## Compare with the limits; rendered metrics only when rendered, the
## script's time only at the headless 72 Hz pace (a slow software
## renderer stretches the frame and the time measured in it).
func _check(out: Dictionary, b: Dictionary) -> int:
	if b.is_empty():
		print("ПРОВЕРКА невозможна: нет раздела scene в " + budgets_path)
		return 2
	var rows := []
	if out.mode == "rendered":
		for k in ["draw_calls_main_view", "primitives_two_eyes_est",
				"static_memory_delta_bytes",
				"texture_memory_over_empty_bytes"]:
			rows.append([k, float(out.worst[k].value), float(b[k].limit),
				out.worst[k].view])
		rows.append(["subviewport_bytes",
			float(out.get("subviewport_bytes_est", 0)),
			float(b.subviewport_bytes.limit), "-"])
	else:
		rows.append(["script_ms_mean_host", float(out.script_ms_mean_host),
			float(b.script_ms_mean_host.limit), "все"])
		rows.append(["script_ms_max_host", float(out.script_ms_max_host),
			float(b.script_ms_max_host.limit), out.script_ms_max_view])
	if b.has("audio_generators"):
		rows.append(["audio_generators", float(out.audio_generators),
			float(b.audio_generators.limit), "-"])
	var bad := 0
	for r in rows:
		var ok: bool = r[1] <= r[2]
		if not ok:
			bad += 1
		print("БЮДЖЕТ %s | %s: %s при пределе %s (вид %s) — %s" % [
			scene_name, r[0], str(r[1]), str(r[2]), r[3],
			"ок" if ok else "НАРУШЕНО"])
	if bad > 0:
		print("ИТОГ %s: нарушено бюджетов — %d (docs/APK_REQUIREMENTS.md)."
			% [scene_name, bad])
		return 1
	print("ИТОГ %s: бюджеты сцены соблюдены." % scene_name)
	return 0
