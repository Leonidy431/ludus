extends SceneTree
# Temporary (not committed): draw calls and render CPU time of the hub
# at chosen views, with occlusion culling on or off.
#   -- --occ=on|off|scene [--fov=75]
const SETTLE := 20
var SAMPLE := 30
var only := []
const VIEWS := [
	["start", Vector3(0, 0, 3), 0.0],
	["start-yaw90", Vector3(0, 0, 3), PI / 2.0],
	["start-yaw270", Vector3(0, 0, 3), -PI / 2.0],
	["courtyard", Vector3(0, 0, 5.5), 0.0],
	["pier", Vector3(5.5, 0, 0.6), -PI / 2.0],
	["mentors", Vector3(-2.2, 0, 0), PI / 2.0],
	["evening-cell", Vector3(-5.0, 0, -5.0), 0.0],
	["cell-inside", Vector3(-6.3, 0, -5.9), -PI / 4.0],
	["cell-east", Vector3(-6.0, 0, -7.0), -PI / 2.0],
	["workshop-west", Vector3(-1.0, 0, -7.0), PI / 2.0],
]
var hub: Node3D
var occ := "scene"
var fov := 0.0
var step := 0
var frame := 0
var dc := []
var cpu := []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--occ="):
			occ = a.trim_prefix("--occ=")
		elif a.begins_with("--sample="):
			SAMPLE = int(a.trim_prefix("--sample="))
		elif a.begins_with("--views="):
			only = a.trim_prefix("--views=").split(",")
		elif a.begins_with("--fov="):
			fov = float(a.trim_prefix("--fov="))
	hub = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	RenderingServer.viewport_set_measure_render_time(
		root.get_viewport_rid(), true)


func _process(_d: float) -> bool:
	if frame == 0:
		if occ == "on":
			root.use_occlusion_culling = true
		elif occ == "off":
			root.use_occlusion_culling = false
		if fov > 0.0:
			hub.camera.fov = fov
	frame += 1
	if step >= VIEWS.size():
		print("TA_DONE occ=", occ, " viewport_occ=", root.use_occlusion_culling)
		return true
	var v: Array = VIEWS[step]
	if not only.is_empty() and not v[0] in only:
		step += 1
		frame = 1
		return false
	hub.pos = v[1]
	hub.yaw = v[2]
	if frame > SETTLE:
		dc.append(int(Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(
			root.get_viewport_rid()))
	if frame >= SETTLE + SAMPLE:
		cpu.sort()
		var mean := 0.0
		for c in cpu:
			mean += c
		mean /= cpu.size()
		print("TA_VIEW %s dc_max=%d dc_min=%d cpu_med_ms=%.3f cpu_p25=%.3f cpu_mean=%.3f n=%d" % [v[0],
			dc.max(), dc.min(), cpu[cpu.size() / 2], cpu[cpu.size() / 4], mean, cpu.size()])
		dc = []
		cpu = []
		step += 1
		frame = 1
	return false
