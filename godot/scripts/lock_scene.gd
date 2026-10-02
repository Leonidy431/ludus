## A lock on its own: the board in front of the eyes, lit like a survey
## terminal at night, for play on a screen and for proof frames.  In the
## pilot the same LockBoard hangs in the room or by the pult (phase Z5).
extends Node3D

var board: LockBoard
var camera: Camera3D
var lock_id := "rov_server"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lock="):
			lock_id = a.trim_prefix("--lock=")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.015, 0.025, 0.035)
	e.ambient_light_color = Color(0.25, 0.3, 0.35)
	e.ambient_light_energy = 0.6
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.4, 0.0)
	key.light_energy = 1.2
	key.light_color = Color(0.85, 0.92, 1.0)
	add_child(key)
	board = LockBoard.new()
	add_child(board)
	board.setup(lock_id)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.02, 0.62)
	camera.fov = 50
	add_child(camera)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed \
			and ev.button_index == MOUSE_BUTTON_LEFT:
		var o := camera.project_ray_origin(ev.position)
		var d := camera.project_ray_normal(ev.position)
		board.press(board.cell_at(o, d))
