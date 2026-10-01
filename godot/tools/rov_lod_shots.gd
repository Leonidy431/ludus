## Frames and triangle counts of the Mangustik's level of detail
## (godot/scripts/rov_lod.gd, blocker Б-2), rendered under Xvfb:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##     --rendering-driver opengl3 -s res://tools/rov_lod_shots.gd \
##     -- --out=/abs/dir
## For each camera distance the frame is saved and the renderer's own
## primitive count is printed ("LOD_JSON {...}"): it shows which model
## the visibility ranges really chose, not which one the script meant.
## The "pair-*" frames put the full model and the proxy side by side at
## the same distance, each forced on, so the eye can compare them.
extends SceneTree

## Camera distance to the vehicle's centre, metres.
const DISTANCES := [1.4, 1.8, 2.3, 2.8, 4.0, 8.0, 14.0]
const SETTLE := 6

var out_dir := ""
var cam: Camera3D
var rov: Node3D
var pair: Node3D
var centre := Vector3.ZERO
var shots: Array = []
var step := -1
var frame := 0
var rows: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("user://rov_lod")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.2, 0.26)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.66)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.1
	world.add_child(sun)
	rov = RovLod.build()
	world.add_child(rov)
	var proxy := rov.get_node("Proxy") as Node3D
	centre = RovLod.geometry(proxy)[0].get_aabb().get_center()
	# The pair: both models on, side by side, no ranges.
	pair = Node3D.new()
	pair.visible = false
	world.add_child(pair)
	var a := (load(RovLod.FULL) as PackedScene).instantiate() as Node3D
	a.position = Vector3(-0.6, 0, 0)
	pair.add_child(a)
	var b := (load(RovLod.PROXY) as PackedScene).instantiate() as Node3D
	b.position = Vector3(0.6, 0, 0)
	for g in RovLod.geometry(b):
		g.material_override = RovLod.proxy_paint()
	pair.add_child(b)
	cam = Camera3D.new()
	cam.fov = 60.0
	world.add_child(cam)
	cam.current = true
	for d in DISTANCES:
		shots.append({"name": "lod-%.1fm" % d, "d": d, "pair": false})
	for d in [1.4, 2.4, 6.0]:
		shots.append({"name": "pair-%.1fm" % d, "d": d, "pair": true})


## Looking at the vehicle from the side and a little above, quarter on.
func _place(d: float, at: Vector3) -> void:
	var dir := Vector3(0.75, 0.35, 0.55).normalized()
	cam.position = at + dir * d
	cam.look_at(at, Vector3.UP)


func _process(_delta: float) -> bool:
	if step < 0 or frame >= SETTLE:
		if step >= 0:
			_record()
		step += 1
		frame = 0
		if step >= shots.size():
			_finish()
			return true
		var s: Dictionary = shots[step]
		rov.visible = not s.pair
		pair.visible = s.pair
		_place(s.d, centre if not s.pair else Vector3(0, centre.y, 0))
	frame += 1
	return false


func _record() -> void:
	var s: Dictionary = shots[step]
	var vp := root.get_viewport_rid()
	var prim := RenderingServer.viewport_get_render_info(vp,
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var dc := RenderingServer.viewport_get_render_info(vp,
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var img := root.get_texture().get_image()
	var path := out_dir.path_join(s.name + ".png")
	img.save_png(path)
	var dist := cam.global_position.distance_to(centre)
	rows.append({"shot": s.name, "distance_m": snappedf(dist, 0.01),
		"primitives": prim, "draw_calls": dc,
		"expected": "pair" if s.pair else RovLod.shown_at(dist)})


func _finish() -> void:
	print("LOD_JSON " + JSON.stringify({"near_m": RovLod.NEAR_M,
		"full_triangles": RovLod.triangles(rov.get_node("Full")),
		"proxy_triangles": RovLod.triangles(rov.get_node("Proxy")),
		"shots": rows}))
