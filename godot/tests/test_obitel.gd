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
	hub.queue_free()
