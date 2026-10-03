## The obitel's objects in the hub (TABOO 0.07, 0.32).  Called from
## run_hub_tests.gd.  The overlap check builds the real hub scene, so
## whatever another change adds to the hub's interactables is checked
## too.
extends RefCounted

const MAX_TRIS := 5000
# A slot keeps this much room, on the ground, from every interactable.
const CLEAR_M := 0.75


func run(t: Object) -> void:
	var data := ObitelLayout.load_data()
	var objs: Array = data.get("objects", [])
	t._check(objs.size() >= 24 and objs.size() <= 40,
		"K within 24..40 (%d)" % objs.size())
	t._check(int(data.get("pool_size", 0)) >= objs.size(),
		"the pool is not smaller than K")
	# Determinism: the same data gives the same plan.
	var a := ObitelLayout.plan(data)
	var b := ObitelLayout.plan(data)
	t._check(JSON.stringify(a.placed) == JSON.stringify(b.placed),
		"the plan is deterministic")
	t._check(a.unplaced.is_empty(), "every object has a slot %s"
		% [a.unplaced])
	t._check(a.placed.size() == objs.size(), "all placed")
	var seen := {}
	var per_thing := {}
	var places := {}
	for o in objs:
		# Files present and the Quest 3 budget read from the proxy json.
		t._check(ResourceLoader.exists(o.model), o.id + " .glb present")
		t._check(FileAccess.file_exists(o.meta), o.id + " .json present")
		var meta = JSON.parse_string(FileAccess.get_file_as_string(o.meta))
		t._check(meta is Dictionary and int(meta.get("tris", 1e9))
			<= MAX_TRIS, o.id + " <= 5000 triangles")
		t._check(meta is Dictionary and meta.get("lod") == "proxy",
			o.id + " is marked a proxy, not a final model")
		t._check(not seen.has(o.id), o.id + " once")
		seen[o.id] = true
		per_thing[o.thing] = per_thing.get(o.thing, 0) + 1
		places[o.place] = places.get(o.place, 0) + 1
		t._check(o.constitution.contains("ФОРМА")
			and o.constitution.contains("ДЕЙСТВИЕ")
			and o.constitution.contains("ЦЕЛЬ"), o.id + " constitution line")
		# Holy things: flat board, both flags, only in the red corner.
		if o.flags.get("holy", false):
			t._check(o.flags.noInteract and o.flags.noLoot,
				o.id + " holy flags")
			t._check(o.mount == "red-corner", o.id + " only in its place")
			t._check(meta is Dictionary and meta.get("method")
				== "flat-board", o.id + " is a flat board, not a statue")
		for w in ["святой", "благодать", "таинство", "мученик"]:
			t._check(not String(o.ru).to_lower().contains(w),
				o.id + " tag has no church term")
	for th in per_thing:
		t._check(per_thing[th] <= 2, th + ": at most two per thing")
	for p in ["scriptorium", "cell", "workshop", "refectory", "pier",
			"courtyard"]:
		t._check(places.get(p, 0) >= 4, p + ": at least four")
	# A holy thing that asks for another mount gets no slot.
	var stray := {"objects": [{"id": "x", "place": "pier",
		"mount": "stand", "size_m": [0.6, 0.6], "flags": {"holy": true}}]}
	t._check(ObitelLayout.plan(stray).placed.is_empty(),
		"a holy thing is never placed outside the red corner")
	placed = a.placed
	# The real hub enters the tree with the root, after _initialize;
	# run_hub_tests.gd waits one frame and calls in_hub().
	hub = (load("res://scenes/hub.tscn") as PackedScene).instantiate()
	(t as SceneTree).root.add_child(hub)


var placed: Array = []
var hub: Node


## The real hub: its interactables stay clear, the objects stand in the
## yard's bounds or at the shore, and every object is in the scene.
func in_hub(t: Object) -> void:
	t._check(hub.is_node_ready() and hub.things.size() >= 10,
		"the hub is built with its interactables (%d)" % hub.things.size())
	var root: Node = hub.get_node_or_null("Obitel")
	t._check(root != null, "hub builds the obitel")
	var count := 0
	if root:
		for c in root.get_children():
			if c.has_meta("obitel"):
				count += 1
	t._check(count == placed.size(), "every object is in the scene (%d)"
		% count)
	for p in placed:
		var at := Vector2(p.pos.x, p.pos.z)
		for th in hub.things:
			var d := at.distance_to(Vector2(th.pos.x, th.pos.z))
			t._check(d >= CLEAR_M, "%s clear of %s (%.2f m)"
				% [p.id, th.id, d])
		# Inside the yard, or at the shore of the lake east of it.
		var b: Rect2 = hub.BOUNDS.grow(0.6)
		t._check(b.has_point(at), p.id + " in the yard")
		# The way from the courtyard to the pier stays open.
		t._check(not (at.x > -1.0 and at.x < 9.0 and absf(at.y) < 1.2),
			p.id + " off the way to the pier")
	_landing(t)
	LocationBuild.forget_faces()
	hub.queue_free()


## A thing rests on its support within this many millimetres (TABOO
## 0.016 item 3); more is floating, less is sinking.
const LAND_MM := 5.0


## Absolute gravity in the hub (CLAUDE.md TABOO 0.016 item 3): a thing
## on the floor or a table rests its lowest point on the surface straight
## under its middle within LAND_MM; a card on a stand touches its own
## posts, which stand hidden behind it on the ground and reach above its
## middle.  Cards on a wall and the board of the red corner are flagged
## by their mount and only counted.  A holy board is thin along the axis
## it faces.  The hub bakes its still geometry into a few meshes
## (StaticBatch), the things and posts among them, so the things are
## measured on a second, unbaked build of the same plan, and the surfaces
## are the real hub's, less each thing's own baked copy.
func _landing(t: Object) -> void:
	var fresh := Node3D.new()
	(t as SceneTree).root.add_child(fresh)
	var root := ObitelLayout.build_obitel_objects(fresh)
	var under := LocationBuild.meshes_of(hub)
	var own_boxes := []
	var posts := {}
	for c in root.get_children():
		if c.has_meta("obitel"):
			own_boxes.append((c as Node3D).global_transform
				* ObitelLayout.local_aabb(c).grow(0.001))
		if c.has_meta("card_of"):
			var id: String = c.get_meta("card_of")
			if not posts.has(id):
				posts[id] = []
			posts[id].append(c)
	var landed := 0
	var hung := 0
	var walls := 0
	for c in root.get_children():
		if not c.has_meta("obitel"):
			continue
		var holder := c as Node3D
		var o: Dictionary = holder.get_meta("obitel")
		var mount: String = ObitelLayout.slot_mount(o)
		var own := ObitelLayout.local_aabb(holder)
		if o.flags.get("holy", false):
			t._check(own.size.z <= 0.2, "%s: holy board is thin along its "
				% o.id + "facing (%s)" % own.size)
		if mount == "stand":
			hung += int(_on_posts(t, o.id, holder, own, posts.get(o.id, []),
				under, own_boxes))
			continue
		if not mount in ["floor", "table"]:
			walls += 1
			continue
		var box: AABB = holder.global_transform * own
		var mid := box.get_center()
		var top := LocationBuild.surface_below(under, Vector3(mid.x,
			box.position.y + 0.05, mid.z), own_boxes)
		var gap := (box.position.y - top) * 1000.0
		t._check(absf(gap) <= LAND_MM, "%s (%s) rests on its support "
			% [o.id, mount] + "(%.1f mm)" % gap)
		landed += int(absf(gap) <= LAND_MM)
	fresh.free()
	print(("obitel: landing (TABOO 0.016 item 3): %d things rest on "
		+ "their support within %.1f mm, %d cards hang on their posts, "
		+ "%d hang on a wall or in the red corner") % [landed, LAND_MM,
			hung, walls])


func _on_posts(t: Object, id: String, holder: Node3D, own: AABB,
		parts: Array, under: Array, ignore: Array) -> bool:
	t._check(parts.size() >= 2, id + " on a stand has its posts")
	if parts.size() < 2:
		return false
	var pw := AABB()
	for i in parts.size():
		var mi := parts[i] as MeshInstance3D
		var b: AABB = mi.global_transform * mi.mesh.get_aabb()
		pw = b if i == 0 else pw.merge(b)
	var pb: AABB = holder.global_transform.affine_inverse() * pw
	var touch := absf(own.position.z - pb.end.z) * 1000.0
	var hidden := pb.position.x >= own.position.x - 0.005 \
		and pb.end.x <= own.end.x + 0.005
	var mid := pw.get_center()
	# The posts' own baked copy is passed over as well.
	var top := LocationBuild.surface_below(under, Vector3(mid.x,
		pw.position.y + 0.05, mid.z), ignore + [pw.grow(0.001)])
	var gap := (pw.position.y - top) * 1000.0
	t._check(touch <= LAND_MM, "%s touches its posts (%.1f mm)"
		% [id, touch])
	t._check(hidden, id + "'s posts stand hidden behind it")
	t._check(pb.end.y >= own.get_center().y,
		id + "'s posts reach above its middle")
	t._check(absf(gap) <= LAND_MM, "%s's posts stand on the ground "
		% id + "(%.1f mm)" % gap)
	return touch <= LAND_MM and hidden and absf(gap) <= LAND_MM
