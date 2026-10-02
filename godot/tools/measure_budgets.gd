## Runtime budgets of one headset scene (docs/APK_REQUIREMENTS.md).
##
## Rendered, under Xvfb (draw calls, primitives, memory):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##     --rendering-driver opengl3 -s res://tools/measure_budgets.gd \
##     -- --scene=dive [--check]
## Headless at the headset's 72 Hz pace (the scene's own script time,
## the synth's time per second of sound, the bells' PCM in RAM):
##   godot --headless --max-fps 72 --path godot \
##     -s res://tools/measure_budgets.gd -- --scene=dive [--check]
## --view=<name> keeps one view, e.g. --scene=hub --view=evening-cell for
## the location standard of CLAUDE.md TABOO 0.013.  --budgets=<path>
## reads the limits from another file.  Arguments after "--" also reach
## the scene, so --now=2026-10-04T08:00 sets the witness's clock.
##
## One scene per process, so the memory of one scene does not stay in
## the baseline of the next.  The scene is placed at fixed views, and
## each view is sampled after it settles; the report is the maximum
## over all views, printed as one line "BUDGET_JSON {...}".  --check
## compares it with the "scene" and "audio" sections of
## scripts/godot/apk-budgets.json and exits with 1 on a breach and 2 on
## a budgets file it cannot use.  Rendered numbers come from the host's
## GPU driver and a 1280x720 desktop camera, not from a Quest 3: they
## are an early warning, and the headset's own numbers are taken with
## the OVR Metrics Tool.
##
## Draw calls are counted over the whole frame: the main view (under
## multiview one call covers both eyes) and every SubViewport, 3D and
## canvas, since each of them is drawn every frame on the headset too.
##
## Script time is the wall time of the scene's own _process minus the
## time this thread waited on the run queue during the call (the second
## field of /proc/thread-self/schedstat, Linux).  A shared host
## preempts the thread under load, and the wall clock then counts time
## the script did not run; the difference is close to the thread's CPU
## time.  Where schedstat cannot be read, the wall time is used and the
## report says so.  The host's CPU and load average are recorded with
## every run, since both move the numbers.
##
## The scene's own _process is called from here with the node's own
## processing switched off, so its cost is timed on its own.  Saves
## (user://hub.json, user://dive.json) are written only by player
## actions, which this script does not make.
extends SceneTree

const SETTLE := 20
## Frames a view may wait for a module fetched ahead (about 20 s).
const AHEAD_WAIT_MAX := 1200
const SAMPLE := 10
const EMPTY_FRAMES := 6
## Calls of a synth's generate() for its time per second of sound.
const SYNTH_CALLS := 8
## Days the witness's bell plan is scanned for its PCM in RAM.
const PCM_DAYS := 366
## The witness's bells may take this long to render on the host.
const PCM_WAIT_MS := 120000

var scene_name := ""
var check := false
var budgets_path := ""
var only_view := ""
var node: Node
var views: Array = []
var step := -1
var frame := 0
var ahead_waits := 0
var empty: Node3D
var empty_tex := 0
var base_static := 0
var proc_ms: Array = []
var wall_ms: Array = []
var by_view := {}
var proc_max_view := ""
var worst := {}
var dc_breakdown: Array = []
# A scene whose SubViewports take turns (dive.gd drawn_views) says which
# of them it set to draw.  The render info read in a frame is that of
# the frame drawn before it, so the set from the previous call is the
# one the numbers hold; a viewport not in it keeps its last render's
# numbers, which are not in this frame.  null: every SubViewport counts.
var drawn_set = null
var drawn_frame = null
var failed := false
var sched_ok := false
var sched_cost_ns := 0
var load_start := ""


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
	load_start = _loadavg()
	_calibrate_sched()
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


## One line of a /proc file ("" where it cannot be read).  get_line(),
## because the size of a /proc file reads as 0.
func _proc_line(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_line()


func _loadavg() -> String:
	var parts := _proc_line("/proc/loadavg").split(" ", false)
	return " ".join(parts.slice(0, 3)) if parts.size() >= 3 else "unknown"


## Nanoseconds this thread has waited on the run queue, or -1.
func _run_delay_ns() -> int:
	var parts := _proc_line("/proc/thread-self/schedstat").split(" ", false)
	if parts.size() < 2:
		return -1
	return int(parts[1])


## The cost of the two reads around a timed call, so it is not counted
## as the scene's time: the median of empty pairs.
func _calibrate_sched() -> void:
	sched_ok = _run_delay_ns() >= 0
	if not sched_ok:
		return
	var costs := []
	for i in 32:
		var t0 := Time.get_ticks_usec()
		var d0 := _run_delay_ns()
		var d1 := _run_delay_ns()
		costs.append((Time.get_ticks_usec() - t0) * 1000 - (d1 - d0))
	costs.sort()
	sched_cost_ns = maxi(0, int(costs[costs.size() / 2]))


## [wall ms, ms net of run-queue wait] of one call.
func _timed(f: Callable) -> Array:
	var t0 := Time.get_ticks_usec()
	var d0 := _run_delay_ns() if sched_ok else 0
	f.call()
	var d1 := _run_delay_ns() if sched_ok else 0
	var wall_ns := (Time.get_ticks_usec() - t0) * 1000
	if not sched_ok:
		return [wall_ns / 1e6, wall_ns / 1e6]
	return [wall_ns / 1e6, maxf(0.0, wall_ns - (d1 - d0) - sched_cost_ns)
		/ 1e6]


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
	drawn_frame = drawn_set
	var ms := _timed(func(): node._process(delta))
	var dv = node.get("drawn_views")
	drawn_set = (dv as Array).duplicate() if dv is Array else null
	# A module fetched ahead at this view (TABOO 0.014) counts once it is
	# in memory: the view settles only after the load is done, so the
	# peak of hub plus module is what is measured, not a half load.
	var ml := root.get_node_or_null("ModuleLoader")
	if ml != null and str(ml.ahead_path) != "" \
			and not ml.is_ready(ml.ahead_path) and frame <= SETTLE + 1:
		frame = mini(frame, SETTLE)
		ahead_waits += 1
		if ahead_waits < AHEAD_WAIT_MAX:
			return false
	if frame > SETTLE:
		if proc_ms.is_empty() or ms[1] > proc_ms.max():
			proc_max_view = v.name
		proc_ms.append(ms[1])
		wall_ms.append(ms[0])
		var pv: Dictionary = by_view.get(v.name, {"sum": 0.0, "n": 0,
			"max": 0.0})
		pv.sum += ms[1]
		pv.n += 1
		pv.max = maxf(pv.max, ms[1])
		by_view[v.name] = pv
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
				# The worst reachable views of the yard (a 5 x 5 grid
				# over BOUNDS, eight headings each): from the south-east
				# corner by the pier towards the north-east, and from the
				# south wall towards the north.
				{"name": "yard-se-ne", "pos": Vector3(8.0, 0, 7.0),
					"yaw": PI / 4.0},
				{"name": "yard-south", "pos": Vector3(-2.0, 0, 7.0),
					"yaw": 0.0},
				# At the ROV slipway, where the dive module is fetched
				# ahead (TABOO 0.014): the hub and the dive in memory
				# at once, the peak of the way to the water.
				{"name": "slipway", "pos": Vector3(7.0, 0, 0.0),
					"yaw": -PI / 2.0},
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
			# The far end looking back: the whole path is in sight, and
			# before batching it drew more than the entrance (131 vs 129).
			out.append({"name": "end-back", "pos": Vector3(104, 0, 0),
				"yaw": PI / 2.0})
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
			node.yaw = v.get("yaw", -PI / 2.0)
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
	var parts := [
		{"viewport": "main", "kind": "3d", "draw_calls": main_dc},
		{"viewport": "main", "kind": "canvas",
			"draw_calls": _info(main, can, dc)},
	]
	# Under multiview one draw call covers both eyes, but every vertex
	# is shaded once per eye; a SubViewport is mono and drawn once.
	var sub_prim := 0
	var sub_px := 0
	for sv in node.find_children("*", "SubViewport", true, false):
		var s := sv as SubViewport
		# Its memory is held whether it draws this frame or not.
		sub_px += s.size.x * s.size.y
		if drawn_frame != null and not (drawn_frame as Array).has(s):
			continue
		var rid: RID = s.get_viewport_rid()
		sub_prim += _info(rid, vis, pr) + _info(rid, can, pr)
		var label := "%s %dx%d" % [s.name, s.size.x, s.size.y]
		parts.append({"viewport": label, "kind": "3d",
			"draw_calls": _info(rid, vis, dc)})
		parts.append({"viewport": label, "kind": "canvas",
			"draw_calls": _info(rid, can, dc)})
	var frame_dc := int(Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var row := {
		"draw_calls_frame": frame_dc,
		"draw_calls_main_view": main_dc,
		"primitives_main_view": main_prim,
		"primitives_one_view_est": main_prim + sub_prim,
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
	if frame_dc > worst.get("draw_calls_frame", {"value": -1}).value:
		dc_breakdown = parts.filter(func(p): return p.draw_calls > 0)
	for k in row:
		if row[k] > worst.get(k, {"value": -1}).value:
			worst[k] = {"value": row[k], "view": view}


static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2]


static func _pct(a: Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[mini(s.size() - 1, int(q * s.size()))]


static func _mean(a: Array) -> float:
	var sum := 0.0
	for v in a:
		sum += v
	return sum / maxf(1.0, a.size())


## CPU per second of sound of the scene's synth, called SYNTH_CALLS
## times in a row after the views (the synth's state no longer matters).
## The synth's class is reached through the scene's own object, never
## named here: a class named in this script is loaded with the script,
## before the baseline, and its memory would drop out of the scene's.
func _synth_probe() -> Dictionary:
	var target: Object
	match scene_name:
		"dive":
			target = node.audio.synth
		"witness":
			target = node.audio
		"hub":
			# The courtyard's bell clock (PlaceAudio); the place's loops
			# are rendered once, off the frame, and cost no synth time.
			if node.place_sound == null or node.place_sound.bell_clock \
					== null:
				return {}
			target = node.place_sound.bell_clock
		_:
			return {}
	var cls = target.get_script()
	var frames := int(cls.MIX_RATE)
	var net := []
	var wall := []
	for i in SYNTH_CALLS:
		var ms := _timed(func(): target.generate(frames))
		wall.append(ms[0])
		net.append(ms[1])
	# The synth's cost depends on what sounds: the state it was timed in.
	var state := {"view": views.back().name if views.size() else ""}
	if scene_name == "witness":
		state["kit"] = node.audio.kit
		state["bells_ringing"] = node.audio.bells.ringing.size()
		state["clock"] = Time.get_datetime_string_from_datetime_dict(
			node.audio.now(), false)
	return {"synth": cls.get_global_name(), "calls": SYNTH_CALLS,
		"state": state,
		"ms_per_second_median": snappedf(_median(net), 0.01),
		"ms_per_second_max": snappedf(net.max(), 0.01),
		"wall_ms_per_second_median": snappedf(_median(wall), 0.01),
		"wall_ms_per_second_max": snappedf(wall.max(), 0.01)}


## Bytes of one rendered bell clip (float32): the clip is as long as
## its longest mode rings (BellSynth._job), whatever the strength.
static func _clip_bytes(bell, index: int) -> int:
	var frames := 0
	for m in bell.modes(bell.spec(index), 1.0):
		frames = maxi(frames, int(ceil(m[2] * bell.MIX_RATE)))
	return 4 * frames


static func _day_keys(typikon, bell,
		civil: Dictionary) -> Dictionary:
	var keys := {}
	for p in typikon.day_plan(civil):
		for s in p.strokes:
			keys[bell.key_of(s[1], s[2])] = int(s[1])
	return keys


static func _keys_bytes(keys: Dictionary, per_bell: Dictionary) -> int:
	var total := 0
	for k in keys:
		total += per_bell[keys[k]]
	return total


## The witness's bells in RAM: the clips of the scene's own day,
## rendered; then the day plans of PCM_DAYS days from that day, counted
## from the clip lengths without rendering.  Clips are kept once made,
## so a stay across a day boundary holds two days' clips: that union is
## the worst case of one stay.
func _pcm_probe() -> Dictionary:
	if scene_name != "witness":
		return {}
	var b = node.audio.bells
	var bell = b.get_script()
	# The Typikon's day plan is loaded now, after the measurement, for
	# the same reason the synth's class is not named in this script.
	var typikon = load("res://scripts/typikon_core.gd")
	var until := Time.get_ticks_msec() + PCM_WAIT_MS
	while Time.get_ticks_msec() < until:
		b.warm_async()
		if b.task == -1 and b.jobs.is_empty():
			break
		OS.delay_msec(5)
	var rendered := 0
	for k in b.clips:
		rendered += b.clips[k].size() * 4
	var per_bell := {}
	for i in bell.ENSEMBLE.size():
		per_bell[i] = _clip_bytes(bell, i)
	var now: Dictionary = node.audio.now()
	var t0 := int(Time.get_unix_time_from_datetime_dict({
		"year": now.year, "month": now.month, "day": now.day,
		"hour": 12, "minute": 0, "second": 0}))
	var day_max := 0
	var day_max_date := ""
	var two_max := 0
	var two_max_dates := ""
	var prev := {}
	var prev_date := ""
	var today := 0
	for i in PCM_DAYS:
		var civil := Time.get_datetime_dict_from_unix_time(t0 + i * 86400)
		var date: String = typikon.day_key(civil)
		var keys := _day_keys(typikon, bell, civil)
		var bytes := _keys_bytes(keys, per_bell)
		if i == 0:
			today = bytes
		if bytes > day_max:
			day_max = bytes
			day_max_date = date
		if i > 0:
			var both := prev.duplicate()
			both.merge(keys)
			var two := _keys_bytes(both, per_bell)
			if two > two_max:
				two_max = two
				two_max_dates = prev_date + ".." + date
		prev = keys
		prev_date = date
	return {"date": typikon.day_key(now),
		"rendered_bytes": rendered, "rendered_clips": b.clips.size(),
		"jobs_left": b.jobs.size(), "counted_bytes_same_day": today,
		"days_scanned": PCM_DAYS, "day_max_bytes": day_max,
		"day_max_date": day_max_date, "two_days_max_bytes": two_max,
		"two_days_max_dates": two_max_dates}


func _finish() -> void:
	var per_px := 8
	var budgets := _load_budgets()
	var scene_b: Dictionary = budgets.get("scene", {})
	if scene_b.has("subviewport_bytes"):
		per_px = int(scene_b.subviewport_bytes.get("bytes_per_px", 8))
	# Every AudioStreamGenerator is a synth the CPU feeds each frame.
	var gens := 0
	# Every player is a voice the mixer runs (track A of HLD_APK_
	# GRAPHICS_SOUND_2026-10-01); the hub's rope breath is counted only
	# once taken in hand, so one is added for it.
	var players := 0
	for c in node.find_children("*", "", true, false):
		var player := (c is AudioStreamPlayer or c is AudioStreamPlayer2D
			or c is AudioStreamPlayer3D)
		if player:
			players += 1
		if player and c.stream is AudioStreamGenerator:
			gens += 1
	if scene_name == "hub" and node.rope_breath == null:
		players += 1
	var views_out := {}
	for k in by_view:
		views_out[k] = {"mean": snappedf(by_view[k].sum / by_view[k].n,
			0.001), "max": snappedf(by_view[k].max, 0.001)}
	var out := {
		"scene": scene_name,
		"audio_generators": gens,
		"audio_players": players,
		"mode": "headless" if _headless() else "rendered",
		"adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"window": str(root.get_visible_rect().size),
		"msaa_3d": root.msaa_3d,
		"host": {"cpu": OS.get_processor_name(),
			"cores": OS.get_processor_count(), "loadavg_start": load_start,
			"loadavg_end": _loadavg()},
		"views": views.size(),
		"only_view": only_view,
		"script_time": ("wall minus run-queue wait "
			+ "(/proc/thread-self/schedstat)") if sched_ok else "wall",
		"schedstat_read_cost_us": sched_cost_ns / 1000.0,
		"script_ms_mean_host": snappedf(_mean(proc_ms), 0.001),
		"script_ms_median_host": snappedf(_median(proc_ms), 0.001),
		"script_ms_p95_host": snappedf(_pct(proc_ms, 0.95), 0.001),
		"script_ms_max_host": snappedf(proc_ms.max() if proc_ms.size()
			else 0.0, 0.001),
		"script_ms_max_view": proc_max_view,
		"script_wall_ms_mean_host": snappedf(_mean(wall_ms), 0.001),
		"script_wall_ms_max_host": snappedf(wall_ms.max() if wall_ms.size()
			else 0.0, 0.001),
		"script_ms_by_view": views_out,
		"worst": worst,
		"draw_calls_breakdown": dc_breakdown,
	}
	var bs = node.get("batch_stats")
	if bs is Dictionary and not (bs as Dictionary).is_empty():
		out["batch_stats"] = bs
	if worst.has("subviewport_px"):
		out["subviewport_bytes_est"] = worst.subviewport_px.value * per_px
	if _headless():
		out["synth"] = _synth_probe()
		out["pcm"] = _pcm_probe()
	print("BUDGET_JSON " + JSON.stringify(out))
	var code := 0
	if check:
		code = _check(out, budgets)
	node.queue_free()
	quit(code)


func _load_budgets() -> Dictionary:
	if not FileAccess.file_exists(budgets_path):
		printerr("measure_budgets: no budgets file " + budgets_path)
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(budgets_path))
	return data if data is Dictionary else {}


## The limit of one metric for this run: the scene's exception, if one
## is recorded and the whole scene was walked, else the base limit.  A
## single view (--view) is always held to the base limit, since an
## exception covers the known views of a scene, not a new place in it.
## "" in the second slot, or the reason the exception is unusable.
func _limit(entry: Dictionary, policy: Dictionary) -> Array:
	var base := float(entry.limit)
	var exc: Dictionary = entry.get("exceptions", {}).get(scene_name, {})
	if exc.is_empty() or only_view != "":
		return [base, "", {}]
	for field in policy.get("required", ["limit"]):
		if not exc.has(field) or str(exc[field]) == "":
			return [base, "у исключения %s нет поля %s" % [scene_name,
				field], exc]
	var lim := float(exc.limit)
	var factor := float(policy.get("max_factor", 1))
	if lim > factor * base:
		return [base, "исключение %s: %s больше %s (не выше x%s базы)" % [
			scene_name, str(lim), str(factor * base), str(factor)], exc]
	return [lim, "", exc]


## Compare with the limits; rendered metrics only when rendered, the
## script's time, the synth and the bells only at the headless 72 Hz
## pace (a slow software renderer stretches the frame and the time
## measured in it).  Time is not judged on an overloaded host: above
## scene.script_host_max_load_per_core the rows say "не проверено" and
## the run ends with 2 unless something else is breached.
func _check(out: Dictionary, budgets: Dictionary) -> int:
	var b: Dictionary = budgets.get("scene", {})
	var policy: Dictionary = budgets.get("exception_policy", {})
	if b.is_empty():
		print("ПРОВЕРКА невозможна: нет раздела scene в " + budgets_path)
		return 2
	var rows := []
	if out.mode == "rendered":
		for k in ["draw_calls_frame", "primitives_two_eyes_est",
				"static_memory_delta_bytes",
				"texture_memory_over_empty_bytes", "subviewport_bytes"]:
			if not b.has(k):
				print("ПРОВЕРКА невозможна: нет scene.%s в %s" % [k,
					budgets_path])
				return 2
		for k in ["draw_calls_frame", "primitives_two_eyes_est",
				"static_memory_delta_bytes",
				"texture_memory_over_empty_bytes"]:
			rows.append([k, float(out.worst[k].value), b[k],
				out.worst[k].view, false])
		rows.append(["subviewport_bytes",
			float(out.get("subviewport_bytes_est", 0)), b.subviewport_bytes,
			"-", false])
		# The dive's draw calls are counted with its drawings batched
		# (DiveBatch.merge_drawings, from texels read back from the
		# renderer).  If none were, the frame measured is not the frame
		# the exception describes: the run fails rather than pass on
		# another scene.
		if scene_name == "dive" and not node.get("batch_off") \
				and int(out.get("batch_stats", {}).get(
					"drawings_batched", 0)) <= 0:
			print(("БЮДЖЕТ dive | drawings_batched: 0 — НАРУШЕНО: рисунки "
				+ "берега не собраны в массив текстур (рендер не вернул "
				+ "текселы), вызовы отрисовки не те, что в исключении"))
			print("ИТОГ dive: нарушено бюджетов — 1 (docs/APK_REQUIREMENTS.md).")
			return 1
	else:
		var a: Dictionary = budgets.get("audio", {})
		for k in ["script_ms_mean_host", "script_ms_max_host",
				"script_host_max_load_per_core"]:
			if not b.has(k):
				print("ПРОВЕРКА невозможна: нет scene.%s в %s" % [k,
					budgets_path])
				return 2
		rows.append(["script_ms_mean_host", float(out.script_ms_mean_host),
			b.script_ms_mean_host, "все", true])
		rows.append(["script_ms_max_host", float(out.script_ms_max_host),
			b.script_ms_max_host, out.script_ms_max_view, true])
		if not out.synth.is_empty() and a.has("synth_ms_per_second_host"):
			rows.append(["synth_ms_per_second_host (%s, медиана)" %
				out.synth.synth, float(out.synth.ms_per_second_median),
				a.synth_ms_per_second_host, "-", true])
		if not out.pcm.is_empty() and a.has("pcm_clips_bytes"):
			rows.append(["pcm_clips_bytes (два дня подряд, худшие)",
				float(out.pcm.two_days_max_bytes), a.pcm_clips_bytes,
				out.pcm.two_days_max_dates, false])
	if b.has("audio_generators"):
		rows.append(["audio_generators", float(out.audio_generators),
			b.audio_generators, "-", false])
	if b.has("audio_players"):
		rows.append(["audio_players", float(out.audio_players),
			b.audio_players, "-", false])
	# The host is judged by its load when the run began: the one-minute
	# average per core, our own process included.
	var busy := ""
	if out.mode != "rendered":
		var parts: PackedStringArray = str(out.host.loadavg_start).split(" ")
		var cores := maxf(1.0, float(out.host.cores))
		var per_core := float(parts[0]) / cores if parts[0].is_valid_float() \
			else INF
		var most := float(b.script_host_max_load_per_core.limit)
		if per_core > most:
			busy = "нагрузка хоста %s на %d ядрах (%.2f на ядро) выше %s" % [
				parts[0], int(cores), per_core, str(most)]
	var bad := 0
	var unchecked := 0
	var active := []
	for r in rows:
		var lim := _limit(r[2], policy)
		if lim[1] != "":
			print("ПРОВЕРКА невозможна: %s (%s)" % [lim[1], budgets_path])
			return 2
		if r[4] and busy != "":
			unchecked += 1
			print(("БЮДЖЕТ %s | %s: %s при пределе %s (вид %s) — не "
				+ "проверено: %s") % [scene_name, r[0], str(r[1]),
				str(lim[0]), r[3], busy])
			continue
		var ok: bool = r[1] <= lim[0]
		if not ok:
			bad += 1
		var note := ""
		if not lim[2].is_empty():
			note = " — ИСКЛЮЧЕНИЕ %s до %s, база %s (%s, %s)" % [
				scene_name, str(lim[0]), str(float(r[2].limit)),
				lim[2].blocker, lim[2].approval]
			if r[1] > float(r[2].limit):
				active.append("%s %s" % [r[0], lim[2].blocker])
		print("БЮДЖЕТ %s | %s: %s при пределе %s (вид %s) — %s%s" % [
			scene_name, r[0], str(r[1]), str(lim[0]), r[3],
			"ок" if ok else "НАРУШЕНО", note])
	if bad > 0:
		print("ИТОГ %s: нарушено бюджетов — %d (docs/APK_REQUIREMENTS.md)."
			% [scene_name, bad])
		return 1
	if unchecked > 0:
		print(("ИТОГ %s: время не проверено (%d строк): %s; повторить на "
			+ "свободном хосте.") % [scene_name, unchecked, busy])
		return 2
	if not active.is_empty():
		print(("ИТОГ %s: бюджеты соблюдены; действуют исключения: %d (%s) "
			+ "— выше базы, ждут решения (docs/APK_REQUIREMENTS.md).") % [
			scene_name, active.size(), ", ".join(active)])
		return 0
	print("ИТОГ %s: бюджеты сцены соблюдены." % scene_name)
	return 0
