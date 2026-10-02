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
	["under", 4.0, -0.55, 14.0], ["ceiling", 5.0, 0.0, 55.0],
	# The close-up swap in glasses (docs/HLD_SWAP_RENDERING_2026-10-02.md).
	["closeup-logbook", 6.0, 0.0, 0.0, "Logbook"],
	["closeup-souvenir", 7.0, 0.0, 0.0, "Souvenir"],
	["closeup-amphora", 100.0, 0.0, 0.0, "Amphora"],
	["closeup-drams", 450.0, 0.0, 0.0, "Drams"],
	["closeup-diary", 730.0, 0.0, 0.0, "Diary"]]
## The insights (docs/HLD_INSIGHTS_FLASHBACKS_2026-10-02.md): each opened
## at the start of its window, the veil faded in, the skip icon up.
## Shot alone with --insights; in the other views no insight may come by
## itself, so all count as shown.
const INSIGHT_VIEWS := [["insight-ink", 56.0, "ink_first_line"],
	["insight-jug", 12.0, "bazaar_jug"],
	["insight-ford", 190.0, "ford_of_cold"],
	["insight-purse", 450.0, "purse_at_the_gate"],
	["insight-skip", 730.0, "scribe_lifts_eyes"],
	["insight-finger", 830.0, "error_of_a_finger"]]
## Frames held per view: past the console's 1.75 s fade at 60 fps.
const HOLD := 130

## Each view is shot three times, as a head turns in the headset: left,
## ahead, right (--triple).
const YAWS := [["left", 35.0], ["ahead", 0.0], ["right", -35.0]]

var out := "user://pilot-shots"
var triple := false
var only_insights := false
var views: Array = VIEWS
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
		elif a == "--insights":
			only_insights = true
	if only_insights:
		views = []
		for v in INSIGHT_VIEWS:
			views.append([v[0], v[1], 0.0, 0.0, "", v[2]])
	DirAccess.make_dir_recursive_absolute(out)
	node = (load("res://scenes/pilot.tscn") as PackedScene).instantiate()
	node.replay = true
	node.stay = true
	root.add_child(node)
	current_scene = node


func _process(_dt: float) -> bool:
	if view >= views.size():
		return true
	if node.shown.is_empty():
		for x in node.insights.get("insights", []):
			node.shown.append(str(x.id))
	if views[view][1] < node.t:
		# The clock goes back for the room views: the console's last
		# words belong to the end, not to the start.
		node.screen.text = ""
		node.line.text = ""
	node.t = views[view][1]
	var v: Array = views[view]
	if frame == 0:
		node.skip_override = {}
		if not node.insight.is_empty():
			node.close_insight()
	if v.size() > 5 and frame == 5:
		for x in node.insights.insights:
			if x.id == v[5]:
				node.open_insight(x)
	if v.size() > 5 and frame > 5:
		# Held in the middle of the memory: the veil full, the clock
		# standing.  The skip view holds the stick half way through its
		# second, so the icon shows the pull filling.
		node.insight_s = 2.0
		# A slow first frame under Xvfb must not run the subtitle out.
		node.narr_left = 5.0
		if v[0] == "insight-skip":
			node.skip = {"stick_s": 0.5}
			node.skip_override = {"stick": 1.0}
	if frame == 0 and node.examining != "":
		# Each view starts with the world running, so the scene enters
		# its beat (the lake) before a close-up pauses it.
		node.close_examine()
	if v.size() > 4 and v[4] != "" and frame == 5:
		# Open the close-up of that thing, glasses on.
		node.glasses_on = true
		for e in node.data.examine:
			if e.id == v[4]:
				node.open_examine(e)
	node.rig.position.y = v[2] if v.size() > 2 else 0.0
	node.camera.rotation.x = deg_to_rad(v[3]) if v.size() > 3 else 0.0
	if triple:
		node.camera.rotation.y = deg_to_rad(YAWS[yaw][1])
	node.override = {"gaze": true, "away_deg": 2.0, "hand_m": 2.0}
	frame += 1
	if frame >= HOLD:
		var img := root.get_texture().get_image()
		var name := "pilot-%02d-%s" % [view + 1, views[view][0]]
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
