## Proof frames of the pilot "Taboo" (TABOO 0.013 item 7, TABOO 0.015):
## one frame per world it shows, saved as docs/audit/<date>/pilot-*.png.
##
##     xvfb-run godot --path godot --rendering-driver opengl3 \
##         -s res://tools/pilot_shots.gd -- --out=../docs/audit/2026-10-02
##
## The clock is held at each view's second; the scene's own _process
## enters the beat, as in tools/measure_budgets.gd.
extends SceneTree

const VIEWS := [["room", 2.0], ["water", 20.0], ["immersion", 40.0],
	["walls", 150.0], ["lure", 450.0], ["khachkar", 655.0],
	["diary", 730.0], ["mark", 875.0], ["title", 902.0],
	# Pandora V1: crouched under the table, head up at the ceiling.
	["under", 4.0, -0.55, 14.0], ["ceiling", 5.0, 0.0, 55.0]]
## Frames held per view: past the console's 1.75 s fade at 60 fps.
const HOLD := 130

## Each view is shot three times, as a head turns in the headset: left,
## ahead, right (--triple).
const YAWS := [["left", 35.0], ["ahead", 0.0], ["right", -35.0]]

var out := "user://pilot-shots"
var triple := false
var yaw := 0
var node: Node
var view := 0
var frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a == "--triple":
			triple = true
	DirAccess.make_dir_recursive_absolute(out)
	node = (load("res://scenes/pilot.tscn") as PackedScene).instantiate()
	node.replay = true
	node.stay = true
	root.add_child(node)
	current_scene = node


func _process(_dt: float) -> bool:
	if view >= VIEWS.size():
		return true
	if VIEWS[view][1] < node.t:
		# The clock goes back for the room views: the console's last
		# words belong to the end, not to the start.
		node.screen.text = ""
		node.line.text = ""
	node.t = VIEWS[view][1]
	var v: Array = VIEWS[view]
	node.rig.position.y = v[2] if v.size() > 2 else 0.0
	node.camera.rotation.x = deg_to_rad(v[3]) if v.size() > 3 else 0.0
	if triple:
		node.camera.rotation.y = deg_to_rad(YAWS[yaw][1])
	node.override = {"gaze": true, "away_deg": 2.0, "hand_m": 2.0}
	frame += 1
	if frame >= HOLD:
		var img := root.get_texture().get_image()
		var name := "pilot-%02d-%s" % [view + 1, VIEWS[view][0]]
		if triple:
			name += "-" + YAWS[yaw][0]
		var path: String = out.path_join(name + ".png")
		img.save_png(path)
		print("shot ", path)
		frame = 0
		if triple and yaw < YAWS.size() - 1:
			yaw += 1
		else:
			yaw = 0
			view += 1
	return false
