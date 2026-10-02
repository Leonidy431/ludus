## Proof frames of a lock board (TABOO 0.024, phase Z4): the board as it
## starts, a tile picked with two moves made, and the matrix calibrated,
## for the robot's server and for the expedition's safe.
##
##     xvfb-run godot --path godot --rendering-driver opengl3 \
##         -s res://tools/lock_shots.gd -- --out=../docs/audit/2026-10-02/locks
extends SceneTree

const LOCKS := ["buoy_hearing", "rov_server", "expedition_safe"]
var out := "user://lock-shots"
var node: Node
var li := 0
var step := 0
var frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	_load()


func _load() -> void:
	if node:
		node.queue_free()
	node = (load("res://scenes/lock.tscn") as PackedScene).instantiate()
	node.lock_id = LOCKS[li]
	root.add_child(node)
	current_scene = node


func _play(n: int) -> void:
	var b: LockBoard = node.board
	for i in n:
		var m := LockCore.find_move(b.state)
		if m.is_empty() or b.state.open:
			return
		b.press(m[0])
		b.press(m[1])


func _process(_dt: float) -> bool:
	if li >= LOCKS.size():
		return true
	frame += 1
	if frame == 5:
		if step == 1:
			_play(2)
			var m := LockCore.find_move(node.board.state)
			if not m.is_empty():
				node.board.press(m[0])
		elif step == 2:
			node.board.picked = -1
			_play(40)
	if frame >= 40:
		var names := ["start", "picked", "open"]
		var path := out.path_join("lock-%s-%s.png" % [LOCKS[li], names[step]])
		root.get_texture().get_image().save_png(path)
		print("shot ", path)
		frame = 0
		step += 1
		if step >= 3:
			step = 0
			li += 1
			if li < LOCKS.size():
				_load()
	return false
