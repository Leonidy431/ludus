## Frames of the 12 stories for the eye check (TABOO 0.013 item 7; HLD
## docs/HLD_12_STORIES_HEADSET_2026-10-02.md, S4): for every story, the
## heart of each of its four places with the story's step open on the
## panel, as the player stands to act (1.3 m in front of the heart); and
## the board of the courtyard naming where to go.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##     --rendering-driver opengl3 -s res://tools/story_shots.gd -- \
##     --out=<dir> [--full=<dir>]
##
## Writes <out>/story-<mission>.png (the four steps, two by two, each at
## half size) and <out>/story-board.png; --full keeps every frame whole.
## The player's save is set for each frame and put back as it was after.
extends SceneTree

const SAVE := "user://hub.json"
const WAIT := 24
const NEAR_M := 1.3

var out := ""
var full := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--full="):
			full = arg.trim_prefix("--full=")
	if out == "":
		printerr("story_shots: --out=<dir> is needed")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	if full != "":
		DirAccess.make_dir_recursive_absolute(full)
	_run.call_deferred()


func _save_for(mission_id: int, step: int, mdata: Dictionary) -> void:
	var done := {}
	for act in mdata.acts:
		for id in act.missions:
			if id == mission_id:
				break
			if not mdata.chorus.has(id):
				done[str(id)] = true
		if mission_id in act.missions:
			break
	var trials := {}
	for g in TrialCore.GATE_IDS:
		trials[g] = true
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"form": HubCore.new_form(),
		"actions": {}, "trials": {"trials": trials, "trial_wait": {},
			"fall": null},
		"missions": {"done": done, "current": {"id": mission_id,
			"step": step, "scene": null}, "flags": {}, "lines": {}}}))
	f.close()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab() -> Image:
	return root.get_viewport().get_texture().get_image()


func _run() -> void:
	var kept := FileAccess.get_file_as_string(SAVE) \
		if FileAccess.file_exists(SAVE) else ""
	var story := StoryRoute.load_data()
	var mdata := MissionCore.load_data()
	for s in story.stories:
		var sheet: Image = null
		for i in s.route.size():
			var r: Dictionary = s.route[i]
			_save_for(int(s.mission), i, mdata)
			var scene: Node3D = (load(LocationCore.SCENE) as PackedScene) \
				.instantiate()
			scene.location_id = r.place
			root.add_child(scene)
			await _frames(4)
			scene.pos = scene.p.heart + Vector3(0, 0, NEAR_M)
			scene.yaw = 0.0
			scene.camera.rotation.x = -0.12
			scene._apply(LocationHeart.open(scene.loc, scene.st, scene.ctx))
			await _frames(WAIT)
			var img := _grab()
			if full != "":
				img.save_png("%s/story-%d-%d-%s.png" % [full, s.mission, i,
					r.place])
			if sheet == null:
				sheet = Image.create(img.get_width(), img.get_height(), false,
					img.get_format())
			var half := img.duplicate() as Image
			half.resize(img.get_width() / 2, img.get_height() / 2)
			sheet.blit_rect(half, Rect2i(Vector2i.ZERO, half.get_size()),
				Vector2i((i % 2) * half.get_width(),
					(i / 2) * half.get_height()))
			scene.queue_free()
			await _frames(2)
		sheet.save_png("%s/story-%d.png" % [out, s.mission])
		print("story %d: %s" % [s.mission, s.title])
	# The board: the first story set out on, its panel open in front.
	var first: Dictionary = story.stories[0]
	_save_for(int(first.mission), 0, mdata)
	var hub: Node3D = (load("res://scenes/hub.tscn") as PackedScene) \
		.instantiate()
	root.add_child(hub)
	await _frames(4)
	hub.pos = Vector3(1.0, 0, 1.2)
	hub.yaw = -PI / 2.0
	hub.camera.rotation.x = -0.12
	hub.mission = {"choice": 0, "start": -1}
	await _frames(WAIT)
	_grab().save_png("%s/story-board.png" % out)
	hub.mission = {}
	hub.pos = Vector3(1.6, 0, 1.2)
	await _frames(WAIT)
	_grab().save_png("%s/story-board-text.png" % out)
	hub.queue_free()
	await _frames(2)
	if kept != "":
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_string(kept)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()
