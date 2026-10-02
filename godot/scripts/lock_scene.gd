## A lock at arm's length (TABOO 0.024, phases Z4–Z5): the board tilted
## toward the player like a lectern, the operator's buoy beside it, and
## three ways to play it:
##   * in the headset with controllers: a ray from the controller, the
##     trigger presses the cell the ray meets;
##   * in the headset with bare hands: a pinch (thumb and index tips
##     closer than 1.8 cm) over a cell presses it;
##   * on a screen: the mouse.
## Each press sounds (LockSound: relay, toggle, resonance) and is felt in
## the hand that made it (Haptics: lock_pick, lock_swap, lock_open).  When
## the lock repairs a system of the buoy, the buoy shows it at once.
extends Node3D

const PINCH_M := 0.018

var board: LockBoard
var camera: Node3D
var lock_id := "buoy_hearing"
var xr_active := false
var origin: XROrigin3D
var hands: Array[XRController3D] = []
var rays: Array[MeshInstance3D] = []
var trigger_was := [false, false]
var pinch_was := [false, false]
var sound: LockSound
var buoy: Node3D
var buoy_state := {}
var reduced := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lock="):
			lock_id = a.trim_prefix("--lock=")
	reduced = Haptics.prefers_reduced()
	_world()
	_rig()
	board = LockBoard.new()
	board.reduced = reduced
	add_child(board)
	# A lectern at arm's length: 0.5 m ahead, a little below the eyes,
	# its face turned up toward them by 35 degrees.
	board.position = Vector3(0, 1.15, -0.5)
	board.rotation.x = deg_to_rad(-35.0)
	board.setup(lock_id)
	board.pressed.connect(_on_pressed)
	board.opened.connect(_on_opened)
	sound = LockSound.new()
	add_child(sound)
	buoy_state = BuoyCore.start(BuoyCore.load_data())
	buoy = BuoyCore.build(buoy_state)
	buoy.position = Vector3(0.95, 0.0, -0.95)
	buoy.rotation.y = deg_to_rad(-30.0)
	add_child(buoy)


func _world() -> void:
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
	key.rotation = Vector3(-0.9, 0.5, 0.0)
	key.light_energy = 1.3
	key.light_color = Color(0.85, 0.92, 1.0)
	key.shadow_enabled = true
	add_child(key)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.06, 0.07, 0.08)
	fm.roughness = 0.9
	floor.material_override = fm
	add_child(floor)


func _rig() -> void:
	var xr := XRServer.find_interface("OpenXR")
	xr_active = xr != null and xr.is_initialized()
	origin = XROrigin3D.new()
	add_child(origin)
	if xr_active:
		get_viewport().use_xr = true
		var cam := XRCamera3D.new()
		origin.add_child(cam)
		camera = cam
		for side in ["left_hand", "right_hand"]:
			var c := XRController3D.new()
			c.tracker = side
			origin.add_child(c)
			hands.append(c)
			rays.append(_ray(c))
	else:
		var cam := Camera3D.new()
		cam.position = Vector3(0, 1.55, 0.05)
		cam.fov = 60
		origin.add_child(cam)
		cam.look_at(Vector3(0.3, 0.95, -0.7))
		camera = cam


## A thin beam from the controller, cyan of the instrument, 1.2 m long.
func _ray(c: XRController3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.002, 0.002, 1.2)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.4, 0.9, 1.0, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = Vector3(0, 0, -0.6)
	c.add_child(mi)
	return mi


func _process(_dt: float) -> void:
	if not xr_active:
		return
	for k in hands.size():
		var c := hands[k]
		# The ray: the trigger pressed this frame presses its cell.
		var pull := c.is_button_pressed("trigger_click") \
			or c.get_float("trigger") > 0.8
		if pull and not trigger_was[k]:
			var dir := -c.global_basis.z
			_press(board.cell_at(c.global_position, dir), k)
		trigger_was[k] = pull
		# The pinch of a bare hand over a cell.
		var p := pinch_point(k)
		var pinched := p != Vector3.INF
		if pinched and not pinch_was[k]:
			_press(board.cell_at_point(p), k)
		pinch_was[k] = pinched


## Where a bare hand pinches, in world space, or INF: the middle of the
## thumb and index tips when they are closer than PINCH_M.
func pinch_point(k: int) -> Vector3:
	var name := "/user/hand_tracker/left" if k == 0 \
		else "/user/hand_tracker/right"
	var tr := XRServer.get_tracker(name) as XRHandTracker
	if tr == null or not tr.has_tracking_data:
		return Vector3.INF
	var a := tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP)
	var b := tr.get_hand_joint_transform(
		XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)
	if a.origin.distance_to(b.origin) > PINCH_M:
		return Vector3.INF
	return origin.global_transform * ((a.origin + b.origin) * 0.5)


func _unhandled_input(ev: InputEvent) -> void:
	if xr_active:
		return
	if ev is InputEventMouseButton and ev.pressed \
			and ev.button_index == MOUSE_BUTTON_LEFT:
		var cam := camera as Camera3D
		_press(board.cell_at(cam.project_ray_origin(ev.position),
			cam.project_ray_normal(ev.position)), 1)


var last_hand := 1


func _press(cell: int, hand: int) -> void:
	last_hand = hand
	board.press(cell)


func _hand() -> XRController3D:
	return hands[last_hand] if last_hand < hands.size() else null


func _on_pressed(kind: String) -> void:
	sound.play(kind)
	Haptics.pulse(_hand(), "lock_" + kind if kind != "miss" else "lock_pick",
		reduced)


func _on_opened(id: String) -> void:
	sound.play("open")
	Haptics.pulse(_hand(), "lock_open", reduced)
	var l := LockCore.lock_of(board.data, id)
	if l.has("repairs"):
		buoy_state = BuoyCore.repair(buoy_state, str(l.repairs))
		BuoyCore.show(buoy, buoy_state)
