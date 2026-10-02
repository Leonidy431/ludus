## The lock at arm's length (lock_scene.gd, TABOO 0.024 Z4–Z5): a pinch
## point over a cell presses that cell; a press sounds and a swap sounds
## differently; the buoy's hearing lock, once calibrated, repairs the
## buoy's hearing and its diode turns green.  Called from
## run_hub_tests.gd.
extends RefCounted


func run(t: Object) -> void:
	var p: Node = (load("res://scenes/lock.tscn") as PackedScene) \
		.instantiate()
	p.lock_id = "buoy_hearing"
	t.root.add_child(p)
	if p.board == null:
		p._ready()
	var b: LockBoard = p.board
	var at := b.to_global(b.cell_pos(7))
	t._check(b.cell_at_point(at) == 7, "a pinch over cell 7 meets cell 7")
	t._check(b.cell_at_point(at + b.global_basis.z * 0.2) == -1,
		"a pinch 20 cm off the board meets nothing")
	var cam: Camera3D = p.camera
	var dir := (at - cam.global_position).normalized()
	t._check(b.cell_at(cam.global_position, dir) == 7,
		"a ray from the eye through cell 7 meets cell 7 on the tilted board")
	var m := LockCore.find_move(b.state)
	p._press(m[0], 1)
	t._check(p.sound.queue.size() > 0, "a pick sounds (a relay)")
	var before: int = p.sound.queue.size()
	p._press(m[1], 1)
	t._check(p.sound.queue.size() > before, "a swap sounds longer (a toggle)")
	for i in 200:
		if b.state.open:
			break
		var mv := LockCore.find_move(b.state)
		p._press(mv[0], 1)
		p._press(mv[1], 1)
	t._check(b.state.open, "the buoy's hearing lock is calibrated")
	t._check("hearing" in p.buoy_state.repaired,
		"the calibration repairs the buoy's hearing")
	var led: MeshInstance3D = p.buoy.get_node("Led_hearing")
	var col: Color = (led.material_override as StandardMaterial3D).albedo_color
	t._check(col.g > 0.8 and col.r < 0.6, "the hearing diode turns green")
	var other: MeshInstance3D = p.buoy.get_node("Led_power")
	var col2: Color = (other.material_override as StandardMaterial3D) \
		.albedo_color
	t._check(col2.g < 0.5, "the power diode, not yet repaired, stays red")
	t.root.remove_child(p)
	p.free()
