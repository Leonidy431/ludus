## Proof frames of the fish of our own drawing (DEF-056) in the dive:
## for each species with a 12/12 kit the ROV is held a few body lengths
## behind one fish of its school, at the school's real depth, and the
## frame is saved, first from the ROV's eye, then from behind its body.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##     --rendering-driver opengl3 -s res://tools/fish_shots.gd \
##     -- --out=/tmp/fish
## The frames are for the eye check (TABOO 0.013 item 7); nothing here
## measures budgets, measure_budgets.gd does.
extends SceneTree

const SETTLE := 24

var out := "/tmp/fish-shots"
var node: Node
var plan: Array = []
var step := 0
var frame := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	node = (load("res://scenes/dive.tscn") as PackedScene).instantiate()
	root.add_child(node)


func _process(_delta: float) -> bool:
	if plan.is_empty():
		for s in node.schools:
			if not FishDrawings.kit_of(node.fish_index, str(s.id)).is_empty():
				plan.append({"school": s, "first": true})
				plan.append({"school": s, "first": false})
		if plan.is_empty():
			printerr("fish_shots: no kit of DEF-056 in the dive")
			return true
	if step >= plan.size():
		return true
	var p: Dictionary = plan[step]
	var s: Dictionary = p.school
	if node.third_person == p.first:
		node.third_person = not p.first
		node._place_view()
	# Hold the fish still and the ROV behind it.
	node.t = 40.0
	var f := DiveCore.fish_at(s, 0, node.t)
	var back := maxf(1.8, float(s.length) * 6.0)
	# A fish on the bottom is met from the deep side, facing the shore:
	# up the slope the ROV keeps its clearance above a shallower floor
	# and would look over the fish.
	var side := -1.0 if s.bottom else 1.0
	node.rov.x = f.x - side * (back + (0.0 if p.first else 1.0))
	node.rov.z = f.z
	node.rov.depth = f.depth
	node.rov.yaw = PI if s.bottom else 0.0
	node.rov.vx = 0.0
	node.rov.vz = 0.0
	node.rov.vy = 0.0
	node.rov.lamp = true
	node.pitch = 0.0
	frame += 1
	if frame == SETTLE:
		var name := "%s/dive-fish-%s%s.png" % [out, s.id,
			"" if p.first else "-3p"]
		root.get_viewport().get_texture().get_image().save_png(name)
		print("fish shot %s at %.1f m: %s" % [s.id, f.depth, name])
		frame = 0
		step += 1
	return false
