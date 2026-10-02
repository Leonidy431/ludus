## The board of a lock in the headset (CLAUDE.md TABOO 0.024, phase Z4 of
## docs/HLD_LOCK_MATCH3_2026-10-02.md): «калибровка акустической
## матрицы».  LockCore holds the rules; this node only draws the state
## and turns a pointer into a swap.
##
## The look is engineering minimalism (operator, 2026-10-02): a graphite
## plate with a thin cyan frame and scan lines like a survey terminal;
## the tiles are the lock's own parts drawn as small solids (a chip with
## its pins, a sealed connector, a hydrophone, an optical lens, a quartz
## resonator; the same five for a safe, as the operator asked), cyan,
## ultramarine and graphite with terracotta and phosphor green accents.
## No tile is a fruit or a sweet, and nothing glitters as a reward.
##
## The pointer is a ray (mouse or controller) met with the board's plane
## by arithmetic: the engine is built without physics, so no raycast.
class_name LockBoard
extends Node3D

signal opened(lock_id: String)
## Every press the board accepted: "pick", "swap" (a run made) or
## "miss" (no run: the tiles stay), for the sound and the hands.
signal pressed(kind: String)

const CELL := 0.07
const TILE := 0.054

var data := {}
var lock := {}
var state := {}
var picked := -1
var flash := {}
var reduced := false
var cells: Array = []
var head: Label3D
var goal_line: Label3D
var ring: MeshInstance3D


func setup(lock_id: String) -> void:
	data = LockCore.load_data()
	lock = LockCore.lock_of(data, lock_id)
	state = LockCore.start(data, lock_id)
	_build_plate()
	_draw()


func _mat(c: Color, emit := 0.0, metal := 0.0, rough := 0.5) \
		-> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _size() -> Vector2:
	return Vector2(float(state.w) * CELL, float(state.h) * CELL)


## The plate, its frame, the scan lines, the header and the goal line.
func _build_plate() -> void:
	var s := _size()
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(s.x + 0.06, s.y + 0.12, 0.012)
	plate.mesh = pm
	plate.material_override = _mat(Color(0.05, 0.06, 0.07), 0.0, 0.3,
		0.8)
	plate.position = Vector3(0, 0.025, -0.008)
	add_child(plate)
	var cyan := _mat(Color(0.35, 0.9, 1.0), 1.4)
	for e in [[Vector3(s.x + 0.04, 0.0015, 0.002), Vector3(0, s.y / 2 + 0.02, 0)],
			[Vector3(s.x + 0.04, 0.0015, 0.002), Vector3(0, -s.y / 2 - 0.02, 0)],
			[Vector3(0.0015, s.y + 0.04, 0.002), Vector3(s.x / 2 + 0.02, 0, 0)],
			[Vector3(0.0015, s.y + 0.04, 0.002), Vector3(-s.x / 2 - 0.02, 0, 0)]]:
		var f := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = e[0]
		f.mesh = fm
		f.material_override = cyan
		f.position = e[1]
		add_child(f)
	# Scan lines: a faint ruled glass over the plate, as on a sounder.
	var img := Image.create(4, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var a := 0.10 if y % 4 == 0 else 0.0
		for x in 4:
			img.set_pixel(x, y, Color(0.3, 0.9, 1.0, a))
	var glass := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(s.x + 0.04, s.y + 0.04)
	glass.mesh = gq
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_texture = ImageTexture.create_from_image(img)
	gm.uv1_scale = Vector3(1, 6, 1)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glass.material_override = gm
	glass.position = Vector3(0, 0, 0.03)
	add_child(glass)
	head = _text(22, Vector3(0, s.y / 2 + 0.065, 0.01))
	head.text = "КАЛИБРОВКА АКУСТИЧЕСКОЙ МАТРИЦЫ\n" + str(lock.name_ru)
	goal_line = _text(18, Vector3(0, -s.y / 2 - 0.05, 0.01))
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = TILE * 0.52
	tm.outer_radius = TILE * 0.6
	ring.mesh = tm
	ring.rotation.x = PI / 2.0
	ring.material_override = _mat(Color(0.55, 1.0, 0.45), 2.0)
	ring.visible = false
	add_child(ring)


func _text(size: int, at: Vector3) -> Label3D:
	var l := Label3D.new()
	l.font_size = size
	l.pixel_size = 0.0006
	l.modulate = Color(0.45, 0.92, 1.0)
	l.outline_size = 4
	l.width = 900
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = at
	add_child(l)
	return l


func cell_pos(i: int) -> Vector3:
	var w: int = state.w
	var h: int = state.h
	var x := i % w
	var y := i / w
	return Vector3((float(x) - float(w - 1) / 2.0) * CELL,
		(float(h - 1) / 2.0 - float(y)) * CELL, 0.012)


## One tile of the lock's parts, built from primitives.
func _tile(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"chip":
			var b := _part(BoxMesh.new(), _mat(Color(0.10, 0.42, 0.20), 0.0,
				0.1, 0.4))
			(b.mesh as BoxMesh).size = Vector3(TILE * 0.9, TILE * 0.62, 0.008)
			n.add_child(b)
			for k in 4:
				for sgn in [-1.0, 1.0]:
					var p := _part(BoxMesh.new(), _mat(Color(0.8, 0.78, 0.7),
						0.0, 1.0, 0.3))
					(p.mesh as BoxMesh).size = Vector3(0.004, 0.006, 0.003)
					p.position = Vector3(-0.015 + 0.01 * k,
						sgn * TILE * 0.34, 0.0)
					n.add_child(p)
			var led := _part(SphereMesh.new(), _mat(Color(0.45, 1.0, 0.4), 2.5))
			(led.mesh as SphereMesh).radius = 0.003
			(led.mesh as SphereMesh).height = 0.006
			led.position = Vector3(TILE * 0.3, 0, 0.006)
			n.add_child(led)
		"connector":
			var c := _part(CylinderMesh.new(), _mat(Color(0.62, 0.30, 0.16),
				0.0, 0.6, 0.4))
			(c.mesh as CylinderMesh).top_radius = TILE * 0.28
			(c.mesh as CylinderMesh).bottom_radius = TILE * 0.28
			(c.mesh as CylinderMesh).height = TILE * 0.8
			c.rotation.z = PI / 2.0
			n.add_child(c)
			var r := _part(TorusMesh.new(), _mat(Color(0.2, 0.22, 0.24), 0.0,
				0.9, 0.3))
			(r.mesh as TorusMesh).inner_radius = TILE * 0.28
			(r.mesh as TorusMesh).outer_radius = TILE * 0.36
			r.rotation.z = PI / 2.0
			n.add_child(r)
		"hydrophone":
			var hy := _part(CylinderMesh.new(), _mat(Color(0.12, 0.20, 0.55),
				0.0, 0.3, 0.35))
			(hy.mesh as CylinderMesh).top_radius = TILE * 0.22
			(hy.mesh as CylinderMesh).bottom_radius = TILE * 0.22
			(hy.mesh as CylinderMesh).height = TILE * 0.6
			n.add_child(hy)
			var dome := _part(SphereMesh.new(), _mat(Color(0.15, 0.25, 0.62),
				0.0, 0.3, 0.3))
			(dome.mesh as SphereMesh).radius = TILE * 0.22
			(dome.mesh as SphereMesh).height = TILE * 0.44
			dome.position = Vector3(0, TILE * 0.3, 0)
			n.add_child(dome)
		"lens":
			var lens := _part(CylinderMesh.new(), _mat(Color(0.30, 0.85, 0.95),
				0.6, 0.0, 0.05))
			(lens.mesh as CylinderMesh).top_radius = TILE * 0.38
			(lens.mesh as CylinderMesh).bottom_radius = TILE * 0.38
			(lens.mesh as CylinderMesh).height = 0.006
			lens.rotation.x = PI / 2.0
			n.add_child(lens)
			var rim := _part(TorusMesh.new(), _mat(Color(0.25, 0.27, 0.3), 0.0,
				0.9, 0.3))
			(rim.mesh as TorusMesh).inner_radius = TILE * 0.36
			(rim.mesh as TorusMesh).outer_radius = TILE * 0.44
			rim.rotation.x = PI / 2.0
			n.add_child(rim)
		_:
			var q := _part(CylinderMesh.new(), _mat(Color(0.86, 0.88, 0.84),
				0.15, 0.0, 0.15))
			(q.mesh as CylinderMesh).radial_segments = 6
			(q.mesh as CylinderMesh).top_radius = TILE * 0.2
			(q.mesh as CylinderMesh).bottom_radius = TILE * 0.3
			(q.mesh as CylinderMesh).height = TILE * 0.8
			n.add_child(q)
	return n


func _part(mesh: Mesh, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	return mi


## Draw the board as the state stands: one node per cell, the pick ring,
## the goal line with what is gathered and what is still needed.
func _draw() -> void:
	for c in cells:
		c.queue_free()
	cells.clear()
	for i in state.board.size():
		var kind: String = lock.tiles[int(state.board[i])]
		var t := _tile(kind)
		t.position = cell_pos(i)
		if flash.has(i) and not reduced:
			t.scale = Vector3.ONE * 1.12
		add_child(t)
		cells.append(t)
	ring.visible = picked >= 0
	if picked >= 0:
		ring.position = cell_pos(picked) + Vector3(0, 0, 0.004)
	var parts: Array = []
	for k in lock.goal:
		var i: int = lock.tiles.find(k)
		parts.append("%s %d/%d" % [lock.tiles_ru[i], mini(int(state.cleared[k]),
			int(lock.goal[k])), int(lock.goal[k])])
	if state.open:
		goal_line.text = "МАТРИЦА ОТКАЛИБРОВАНА · " + str(lock.opens_ru)
		goal_line.modulate = Color(0.55, 1.0, 0.45)
	else:
		goal_line.text = "  ·  ".join(parts) + "    ходов: %d" % int(state.moves)


## A pointer ray (origin, direction, in world space) to a cell, or -1.
func cell_at(origin: Vector3, dir: Vector3) -> int:
	var xf := global_transform
	var o := xf.affine_inverse() * origin
	var d := xf.basis.inverse() * dir
	if absf(d.z) < 1e-6:
		return -1
	var k := (0.012 - o.z) / d.z
	if k < 0.0:
		return -1
	var p := o + d * k
	var w: int = state.w
	var h: int = state.h
	var x := int(floor(p.x / CELL + float(w) / 2.0))
	var y := int(floor(float(h) / 2.0 - p.y / CELL))
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return y * w + x


## A press on a cell: the first press picks, the second on a neighbour
## swaps; a press elsewhere picks anew.
func press(i: int) -> void:
	if i < 0 or state.open:
		return
	if picked < 0:
		picked = i
	else:
		var s := LockCore.swap(data, state, picked, i)
		if s.moves == state.moves:
			picked = i
			pressed.emit("pick")
			_draw()
			return
		flash = {}
		state = s
		picked = -1
		pressed.emit("swap")
		if state.open:
			opened.emit(str(lock.id))
		_draw()
		return
	pressed.emit("pick")
	_draw()


## A pinch in the world (the meeting point of thumb and index tips) to a
## cell: the point must be within 4 cm of the board's face.
func cell_at_point(p: Vector3) -> int:
	var q := global_transform.affine_inverse() * p
	if absf(q.z - 0.012) > 0.04:
		return -1
	var w: int = state.w
	var h: int = state.h
	var x := int(floor(q.x / CELL + float(w) / 2.0))
	var y := int(floor(float(h) / 2.0 - q.y / CELL))
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return y * w + x
