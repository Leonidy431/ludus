## Switch places fast, again and again, to shake out a crash of the
## audio mix thread that CI met twice inside measure_locations (a
## signal 11 on a non-main thread whose frames lie next to AudioServer's
## mix step and bus sends; 2026-10-02).  Each place is held a different
## number of frames (--hold, default 1 to 12) in a fixed order, so the
## stop of one place's sound lands at every point of the next one's
## start.
##
## Run under Xvfb (in a headless display the place sound stays silent):
##   xvfb-run -a godot --path godot --rendering-driver opengl3 \
##     -s res://tools/stress_place_switch.gd -- --switches=600
## It prints "STRESS done N switches" and exits 0, or crashes.
extends SceneTree

var scene: Node
var ids: Array = []
var switches := 600
var done := 0
var hold := 0
## Frames a place is held: hold_min + (switch * 37) % hold_span.
var hold_min := 1
var hold_span := 12


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--switches="):
			switches = int(a.trim_prefix("--switches="))
		elif a.begins_with("--hold="):
			# --hold=40,120: held 40 to 159 frames, long enough for the
			# loops to render and their players to start.
			var h := a.trim_prefix("--hold=").split(",")
			hold_min = int(h[0])
			hold_span = int(h[1])
	var data := LocationCore.load_data()
	for p in data.locations:
		ids.append(p.id)
	root.get_node("ModuleLoader").hold_ahead = true
	scene = (load(LocationCore.SCENE) as PackedScene).instantiate()
	scene.location_id = ids[0]
	root.add_child(scene)


func _process(_dt: float) -> bool:
	if hold > 0:
		hold -= 1
		return false
	if done >= switches:
		print("STRESS done %d switches" % done)
		scene.free()
		quit(0)
		return true
	done += 1
	# The hold cycles with a fixed step, so holds of every length meet
	# every place over the run (no randomness).
	hold = hold_min + (done * 37) % hold_span
	scene.open_place(ids[done % ids.size()])
	if done % 50 == 0:
		print("STRESS %d" % done)
	return false
