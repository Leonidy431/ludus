## The way from the courtyard into a big module, measured (CLAUDE.md
## TABOO 0.014 item 5; phase S1 of docs/HLD_12_STORIES_HEADSET_
## 2026-10-02.md):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##     --rendering-driver opengl3 -s res://tools/measure_transition.gd \
##     -- --mode=sync|threaded [--scene=dive|witness]
##
## One process per mode, so that neither finds the other's files in the
## cache.  The courtyard is built and settles first; then
##   sync     - the old way: change_scene_to_file in the frame of the
##              press, as hub.gd did before ModuleLoader;
##   threaded - ModuleLoader.prefetch as the player comes near, frames
##              run until it is ready, then ModuleLoader.go.
## Every frame the main thread's time is read as the wall time minus
## the time it waited in the run queue (second field of /proc/thread-
## self/schedstat, Linux), as tools/measure_budgets.gd does: on a shared
## host the wall clock also counts the time other processes held the
## core, which the headset would not have; the time the thread ran or
## was blocked (on a lock of the loader, say) is kept, since that is a
## stall.  The longest such frame is the stall the headset would show.
## The frame of the press is reported apart from the frame in
## which the new scene builds itself in _ready (the scenes are drawn by
## code, which no loader can move off the main thread).  The static
## memory is read every frame and the process peak at the end.  The
## last line printed is "TRANSITION_JSON {...}".  These are the host's
## numbers, not a Quest 3's; the headset's frame is the OVR Metrics
## Tool's.
extends SceneTree

const HUB := "res://scenes/hub.tscn"
const SCENES := {"dive": "res://scenes/dive.tscn",
	"witness": "res://scenes/witness.tscn"}
const SETTLE := 30
const AFTER := 30

var last := 0
var cpu_last := 0
var worst_ms := 0.0
var cpu_ms: Array = []
var peak := 0
var frames := 0


func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return fallback


## The main thread's own time so far, in ns: the wall clock less the
## run-queue wait (the wall clock alone where schedstat is missing).
func _cpu_ns() -> int:
	var wall := Time.get_ticks_usec() * 1000
	var f := FileAccess.open("/proc/thread-self/schedstat",
		FileAccess.READ)
	if f == null:
		return wall
	var parts := f.get_line().split(" ", false)
	return wall - (int(parts[1]) if parts.size() > 1 else 0)


## One frame: its wall time, its main-thread time, the memory now.
func _tick() -> void:
	await process_frame
	var now := Time.get_ticks_usec()
	var cpu := _cpu_ns()
	worst_ms = maxf(worst_ms, (now - last) / 1000.0)
	cpu_ms.append(snappedf((cpu - cpu_last) / 1e6, 0.01))
	last = now
	cpu_last = cpu
	peak = maxi(peak, OS.get_static_memory_usage())
	frames += 1


func _reset() -> void:
	last = Time.get_ticks_usec()
	cpu_last = _cpu_ns()
	worst_ms = 0.0
	cpu_ms = []
	peak = OS.get_static_memory_usage()
	frames = 0


func _initialize() -> void:
	var mode := _arg("mode", "threaded")
	var target: String = SCENES[_arg("scene", "dive")]
	change_scene_to_file(HUB)
	for i in SETTLE:
		await process_frame
	var base := OS.get_static_memory_usage()
	_reset()
	for i in 10:
		await _tick()
	var out := {"mode": mode, "scene": target,
		"hub_rest_main_worst_ms": cpu_ms.max(),
		"hub_static_bytes": base,
		"loadavg": FileAccess.open("/proc/loadavg",
			FileAccess.READ).get_line()}
	var loader: Node = root.get_node("ModuleLoader")
	if mode == "threaded":
		# The player comes near: the module loads while frames run.
		_reset()
		var t0 := Time.get_ticks_usec()
		loader.prefetch(target)
		while not loader.is_ready(target):
			await _tick()
		out.prefetch_wall_ms = snappedf(
			(Time.get_ticks_usec() - t0) / 1000.0, 0.1)
		out.prefetch_frames = frames
		out.prefetch_main_worst_ms = cpu_ms.max()
		out.prefetch_peak_over_hub_bytes = peak - base
	# The press: everything from here until the new scene has run for
	# AFTER frames is the transition.
	_reset()
	var t1 := Time.get_ticks_usec()
	var c1 := _cpu_ns()
	if mode == "sync":
		change_scene_to_file(target)
	else:
		loader.go(target)
	out.press_call_main_ms = snappedf((_cpu_ns() - c1) / 1e6, 0.01)
	var built := -1
	while current_scene == null or current_scene.scene_file_path != target:
		await _tick()
	built = frames - 1
	for i in AFTER:
		await _tick()
	# The frame of the press holds the call itself (the whole load, in
	# the old way: the first tick counts from before the call); the
	# frame of the build holds the new scene's _ready.
	var others := cpu_ms.duplicate()
	others.remove_at(built)
	out.press_frame_main_ms = cpu_ms[0]
	out.build_frame_main_ms = cpu_ms[built]
	out.frames_press_to_scene = built
	out.worst_frame_main_ms_besides_build = others.max()
	out.transition_wall_ms = snappedf(
		(Time.get_ticks_usec() - t1) / 1000.0, 0.1)
	out.transition_peak_over_hub_bytes = peak - base
	out.after_static_over_hub_bytes = OS.get_static_memory_usage() - base
	out.process_peak_static_bytes = OS.get_static_memory_peak_usage()
	print("TRANSITION_JSON ", JSON.stringify(out))
	quit(0)
