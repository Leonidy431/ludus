## The obitel's objects in the hub: the K proxies chosen from the honest
## pool by scripts/obitel/obitel_objects.py (TABOO 0.07), placed by a
## fixed plan of slots, so the same data always gives the same yard.
##
## Each place of the obitel has its slots: cards (drawn SVG reliefs) hang
## on a wall or stand on two oak posts, small volumes lie on a table,
## bench or crate, large ones stand on the floor.  The walkable middle of
## the courtyard, the way to the pier and every interactable of hub.gd
## stay clear (checked by tests/test_obitel.gd against the real hub).
## A holy image is placed only in its one proper place, the red corner of
## the scriptorium under the lampada, as a flat board without a label
## (TABOO 0.2, 0.32 item 3, 0.38 item 3).
class_name ObitelLayout
extends RefCounted

const DATA := "res://data/obitel-objects.json"
const OAK := Color(0.42, 0.29, 0.17)
const BIRCH := Color(0.88, 0.86, 0.8)
# A name tag shows only when the player comes close, so the yard is not
# a wall of captions; a holy thing has none.
const TAG_RANGE_M := 3.2

# Slots per place and mount: position (the bottom for floor and table,
# the centre for wall, stand and the red corner), yaw in degrees (the
# way the card faces), and room: the largest footprint in metres the
# slot takes.  Written out by hand so the plan is readable and fixed.
const SLOTS := {
	"scriptorium": {
		# On the face of the shelves, left and right of the red corner,
		# and on the west wall south of the shelves.
		"wall": [[-6.62, 1.45, -2.15, 90], [-6.62, 1.45, -1.45, 90],
			[-6.62, 1.45, 1.45, 90], [-6.62, 1.45, 2.15, 90],
			[-6.97, 1.55, 3.9, 90], [-6.97, 1.55, 4.6, 90],
			[-6.97, 1.55, 5.3, 90], [-6.97, 1.55, 6.0, 90]],
		"table": [[-5.6, 0.8, -2.2, 90], [-5.6, 0.8, -1.4, 90],
			[-5.6, 0.8, -0.6, 90], [-5.6, 0.8, 0.6, 90],
			[-5.6, 0.8, 1.3, 90]],
		"floor": [[-6.3, 0.0, -3.8, 90, 1.0], [-5.3, 0.0, -3.9, 90, 1.0],
			[-6.3, 0.0, -4.9, 90, 1.0]],
		"red-corner": [[-6.62, 1.4, 0.0, 90]],
	},
	# The cell of the evening rule (scripts/rule_cell.gd) spans x -7.0 to
	# the partition at x -3.3, z -8.7 to -5.5; its lectern stands at
	# (-5.0, -7.3) with the stool at (-4.2, -7.0) and the watch is read
	# from (-5.0, -6.8).  The cell's things keep to its west half and the
	# bench along the north wall.
	"cell": {
		"wall": [[-6.2, 1.5, -8.47, 0], [-5.4, 1.5, -8.47, 0],
			[-6.97, 1.5, -7.2, 90], [-6.97, 1.5, -6.4, 90]],
		"table": [[-5.0, 0.42, -8.0, 0], [-4.6, 0.42, -8.0, 0],
			[-4.2, 0.42, -8.0, 0]],
		"floor": [[-6.05, 0.0, -6.3, 0, 1.8], [-6.4, 0.0, -7.95, 0, 1.0],
			[-6.4, 0.0, -5.7, 0, 1.0]],
	},
	"workshop": {
		# East of the cell's partition (x -3.3) and west of the gate
		# ladder (x -0.2).  Cards hang above the work bench, so a card and
		# a thing on the bench are not read as one.
		"wall": [[-2.8, 1.95, -8.47, 0], [-2.1, 1.95, -8.47, 0],
			[-1.4, 1.95, -8.47, 0], [-0.7, 1.95, -8.47, 0]],
		"table": [[-2.7, 0.8, -8.05, 0], [-2.1, 0.8, -8.05, 0],
			[-1.5, 0.8, -8.05, 0]],
		"floor": [[-2.6, 0.0, -6.5, 0, 1.2], [-1.3, 0.0, -6.5, 0, 1.2],
			[-0.8, 0.0, -7.6, 0, 0.8]],
	},
	"refectory": {
		"wall": [[3.4, 1.55, -8.47, 0], [4.2, 1.55, -8.47, 0],
			[5.0, 1.55, -8.47, 0], [5.8, 1.55, -8.47, 0],
			[6.6, 1.55, -8.47, 0], [7.4, 1.55, -8.47, 0]],
		"table": [[4.4, 0.79, -3.45, 0], [5.0, 0.79, -3.45, 0],
			[5.6, 0.79, -3.45, 0]],
		"floor": [[4.2, 0.0, -6.3, 0, 1.2], [5.6, 0.0, -6.3, 0, 1.2],
			[7.0, 0.0, -6.3, 0, 1.2], [7.8, 0.0, -4.6, 0, 1.0]],
	},
	"pier": {
		# Cards face the courtyard; the crate stands by the pier; the
		# gauge stands in the water off the pier's north side.
		"stand": [[8.6, 1.35, -2.8, -90], [8.6, 1.35, -3.6, -90],
			[8.6, 1.35, -4.4, -90], [8.6, 1.35, 2.8, -90]],
		"table": [[7.6, 0.45, -2.75, -90], [7.6, 0.45, -2.4, -90],
			[7.6, 0.45, -2.05, -90]],
		"floor": [[9.4, -0.55, -1.3, -90, 0.3], [7.6, 0.0, -4.0, -90, 1.0],
			[7.6, 0.0, 2.6, -90, 1.0], [7.6, 0.0, 3.8, -90, 1.0]],
	},
	"courtyard": {
		"stand": [[8.5, 1.35, 4.0, -90], [8.5, 1.35, 5.0, -90],
			[8.5, 1.35, 6.0, -90], [-3.9, 1.35, 6.2, 90]],
		"floor": [[6.4, 0.0, 7.0, 0, 4.2], [6.0, 0.0, 5.0, 0, 1.0],
			[7.2, 0.0, 5.0, 0, 1.0], [-2.6, 0.0, 6.4, 0, 1.0]],
	},
}

# The furniture the layout brings for its small volumes: a plank bench in
# the cell, a work bench in the workshop, a birch crate on the shore.
# [centre x, top y, centre z, size x, size z, colour].
const FURNITURE := [
	[-4.6, 0.4, -8.0, 1.3, 0.45, "oak"],
	[-2.1, 0.78, -8.05, 1.8, 0.5, "oak"],
	[7.6, 0.43, -2.4, 0.5, 1.0, "birch"],
]


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


## The mount a slot table uses for an object: a holy thing never leaves
## the red corner, whatever the data says.
static func slot_mount(o: Dictionary) -> String:
	if o.flags.get("holy", false):
		return "red-corner" if o.mount == "red-corner" else ""
	return o.mount


## The footprint of an object on the floor, from the data's real size.
static func footprint(o: Dictionary) -> float:
	var s: Array = o.size_m
	if o.get("lay", false):
		return maxf(float(s[0]), float(s[1]))
	return maxf(float(s[0]), float(s[2]) if s.size() > 2 else 0.0)


## The plan: which slot each object takes, deterministically in the
## order of the data.  Objects without a free slot are returned in
## "unplaced", never dropped silently.
static func plan(data: Dictionary) -> Dictionary:
	var used := {}
	var placed := []
	var unplaced := []
	for o in data.get("objects", []):
		var m := slot_mount(o)
		var slots: Array = SLOTS.get(o.place, {}).get(m, [])
		# The first free slot; on the floor the smallest one the thing
		# fits, so a mat does not take the room a felt needs.
		var got := -1
		for i in slots.size():
			if used.has("%s/%s/%d" % [o.place, m, i]):
				continue
			var s: Array = slots[i]
			if m != "floor":
				got = i
				break
			if footprint(o) <= float(s[4]) and (got < 0
					or float(s[4]) < float(slots[got][4])):
				got = i
		if got >= 0:
			used["%s/%s/%d" % [o.place, m, got]] = true
		if got < 0:
			unplaced.append(o.id)
			continue
		var s: Array = slots[got]
		placed.append({"id": o.id, "place": o.place, "mount": m,
			"slot": got, "pos": Vector3(s[0], s[1], s[2]),
			"yaw": float(s[3]), "object": o})
	return {"placed": placed, "unplaced": unplaced}


## The combined box of every mesh under a node, in the node's own space.
static func local_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var xf: Transform3D = item[1]
		for c in n.get_children():
			if not c is Node3D:
				continue
			var cx: Transform3D = xf * (c as Node3D).transform
			if c is MeshInstance3D and (c as MeshInstance3D).mesh:
				var b: AABB = cx * (c as MeshInstance3D).mesh.get_aabb()
				box = b if first else box.merge(b)
				first = false
			stack.append([c, cx])
	return box


static func _box(parent: Node3D, size: Vector3, at: Vector3,
		colour: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.9
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)


## One object: the proxy scaled to the thing's size, laid down if it lies,
## turned to its slot and set on it by its own box.
static func _instance(p: Dictionary) -> Node3D:
	var o: Dictionary = p.object
	var scene := load(o.model) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	var sc: Array = o.scale
	model.scale = Vector3(sc[0], sc[1], sc[2])
	var shape := Node3D.new()
	shape.add_child(model)
	if o.get("lay", false):
		var s: Array = o.size_m
		# A thin sheet lies face up; a long round thing (log, scroll)
		# lies along its length.
		if float(s[2]) < 0.05:
			shape.rotation_degrees = Vector3(-90, 0, 0)
		else:
			shape.rotation_degrees = Vector3(0, 0, 90)
	var holder := Node3D.new()
	holder.name = "Obitel_" + o.id
	holder.add_child(shape)
	var box := local_aabb(holder)
	var centre := box.get_center()
	if p.mount in ["floor", "table"]:
		shape.position = -Vector3(centre.x, box.position.y, centre.z)
	else:
		shape.position = -centre
	holder.position = p.pos
	holder.rotation_degrees = Vector3(0, p.yaw, 0)
	holder.set_meta("obitel", o)
	return holder


## Called once from hub.gd _build_world(): builds the furniture, places
## the objects and returns the parent node (named "Obitel").
static func build_obitel_objects(hub: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Obitel"
	hub.add_child(root)
	for f in FURNITURE:
		var colour: Color = OAK if f[5] == "oak" else BIRCH
		var top := float(f[1])
		_box(root, Vector3(f[3], 0.06, f[4]),
			Vector3(f[0], top - 0.03, f[2]), colour)
		for dx in [-1, 1]:
			_box(root, Vector3(0.08, top - 0.06, float(f[4]) * 0.8),
				Vector3(float(f[0]) + dx * (float(f[3]) / 2.0 - 0.08),
					(top - 0.06) / 2.0, f[2]), colour.darkened(0.15))
	var pl := plan(load_data())
	for id in pl.unplaced:
		push_warning("obitel: no slot for " + str(id))
	for p in pl.placed:
		var node := _instance(p)
		if node == null:
			push_warning("obitel: no model for " + str(p.id))
			continue
		root.add_child(node)
		if p.mount == "stand":
			# Two oak posts and a rail behind the card.
			var back := Vector3(0, 0, -0.06).rotated(Vector3.UP,
				deg_to_rad(p.yaw))
			var side := Vector3(0.36, 0, 0).rotated(Vector3.UP,
				deg_to_rad(p.yaw))
			for sgn in [-1, 1]:
				_box(root, Vector3(0.07, 1.75, 0.07),
					Vector3(p.pos.x, 0.875, p.pos.z) + back + side * sgn, OAK)
		if not p.object.flags.get("holy", false):
			var tag := Label3D.new()
			tag.text = p.object.ru
			tag.font_size = 26
			tag.pixel_size = 0.0022
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.modulate = Color(0.95, 0.9, 0.8)
			tag.visibility_range_end = TAG_RANGE_M
			var above := 0.2 if p.mount in ["floor", "table"] else 0.45
			var h := local_aabb(node).size.y if p.mount in ["floor",
				"table"] else 0.0
			tag.position = p.pos + Vector3(0, h + above, 0)
			root.add_child(tag)
	return root
