## Static batching of still geometry (StaticBatch, Б-1 in
## docs/APK_REQUIREMENTS.md).  Called from run_hub_tests.gd: run() on
## small built scenes, in_hub() on the real hub one frame later.
extends RefCounted

## The hub's drawn surfaces after the merge; 600 before it (438 draw
## calls in the courtyard view).  A change that adds still geometry
## the batcher cannot merge shows here before the budget gate.
const HUB_SURFACES_MAX := 100

var hub: Node


static func _box(parent: Node3D, at: Vector3, colour: Color,
		cull := BaseMaterial3D.CULL_BACK, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.5, 0.5)
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(colour, alpha)
	m.roughness = 0.9
	m.cull_mode = cull
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


static func _meshes(n: Node) -> Array:
	return n.find_children("*", "MeshInstance3D", true, false).filter(
		func(m): return m.mesh != null)


## The sign of the first triangle's winding against its vertex normal.
static func _facing(mi: MeshInstance3D) -> float:
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var i: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var g := (v[i[1]] - v[i[0]]).cross(v[i[2]] - v[i[0]])
	return signf(g.dot(nr[i[0]]))


func run(t: Object) -> void:
	# Two opaque colours become one surface; the colours move into the
	# vertex colour at the 8-bit level the renderer stores; nothing is
	# lost or added.
	var root := Node3D.new()
	var red := Color(0.8, 0.2, 0.1)
	var oak := Color(0.42, 0.29, 0.17)
	_box(root, Vector3(0, 0, 0), red)
	_box(root, Vector3(1, 0, 0), oak)
	var glass := _box(root, Vector3(2, 0, 0), red, BaseMaterial3D.CULL_BACK,
		0.5)
	var st := StaticBatch.merge(root)
	var ms := _meshes(root)
	t._check(ms.size() == 2 and st.groups == 1 and st.surfaces == 2,
		"two opaque boxes merge, the glass stays (%d meshes)" % ms.size())
	t._check(is_instance_valid(glass) and glass.get_parent() == root,
		"a transparent surface is not merged")
	var merged: MeshInstance3D = ms[0] if ms[0] != glass else ms[1]
	var arr := merged.mesh.surface_get_arrays(0)
	t._check((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() == 2 * 36,
		"triangles kept: %d indices" % arr[Mesh.ARRAY_INDEX].size())
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var want := [red, oak]
	for k in 2:
		var c: Color = cols[k * (cols.size() / 2)]
		var w: Color = want[k]
		t._check(roundi(c.r * 255.0) == roundi(w.r * 255.0)
			and roundi(c.g * 255.0) == roundi(w.g * 255.0)
			and roundi(c.b * 255.0) == roundi(w.b * 255.0),
			"vertex colour %s is the albedo %s" % [c, w])
	var mat: StandardMaterial3D = merged.mesh.surface_get_material(0)
	t._check(mat.vertex_color_use_as_albedo and mat.vertex_color_is_srgb
		and mat.albedo_color == Color(1, 1, 1, 1),
		"the merged material takes the vertex colour as sRGB albedo")
	root.free()
	# A light is never added to a surface: a box in a lamp's range and a
	# box outside it stay apart.
	root = Node3D.new()
	_box(root, Vector3(0, 0, 0), oak)
	_box(root, Vector3(4, 0, 0), oak)
	var lamp := OmniLight3D.new()
	lamp.omni_range = 1.5
	lamp.position = Vector3(0, 1, 0)
	root.add_child(lamp)
	StaticBatch.merge(root)
	t._check(_meshes(root).size() == 2,
		"a lit box and an unlit one are not merged")
	root.free()
	# A scope (the rope turns) is merged only within itself.
	root = Node3D.new()
	var ring := Node3D.new()
	root.add_child(ring)
	_box(ring, Vector3(0, 0, 0), oak)
	_box(ring, Vector3(0.2, 0, 0), red)
	_box(root, Vector3(0.4, 0, 0), oak)
	StaticBatch.merge(root, {"scopes": [ring]})
	t._check(_meshes(ring).size() == 1 and ring.get_child_count() == 1,
		"the scope's boxes merge under the scope")
	t._check(_meshes(root).size() == 2, "the scope keeps apart from the rest")
	root.free()
	# A mirrored node: a culled material keeps its front, a double-sided
	# one keeps the winding the renderer draws it with (shaded as back).
	var facing := {}
	for key in ["plain", "mirror-culled", "mirror-double"]:
		root = Node3D.new()
		var cull := BaseMaterial3D.CULL_DISABLED if key == "mirror-double" \
			else BaseMaterial3D.CULL_BACK
		var a := _box(root, Vector3(0, 0, 0), oak, cull)
		_box(root, Vector3(1, 0, 0), oak, cull)
		if key != "plain":
			a.scale = Vector3(1, -1, 1)
		StaticBatch.merge(root)
		facing[key] = _facing(_meshes(root)[0])
		root.free()
	t._check(facing["mirror-culled"] == facing["plain"],
		"a mirrored culled box keeps its front")
	t._check(facing["mirror-double"] == -facing["plain"],
		"a mirrored double-sided box keeps the renderer's winding")
	# The real hub, checked one frame later by in_hub().
	hub = (load("res://scenes/hub.tscn") as PackedScene).instantiate()
	(t as SceneTree).root.add_child(hub)


func in_hub(t: Object) -> void:
	var surfaces := 0
	for m in _meshes(hub):
		if m.visible:
			surfaces += (m as MeshInstance3D).mesh.get_surface_count()
	t._check(surfaces <= HUB_SURFACES_MAX,
		"the hub draws %d mesh surfaces (<= %d)" % [surfaces,
			HUB_SURFACES_MAX])
	var ring: Node3D = hub.rope_ring
	t._check(_meshes(ring).size() == 1 and ring.get_parent() == hub,
		"the rope is one mesh that still turns with its ring")
	# The holy image is baked only within itself, under its own holder.
	var holy := 0
	for h in hub.get_node("Obitel").get_children():
		if h.has_meta("obitel") and h.get_meta("obitel").flags.get("holy",
				false):
			holy += 1
			t._check(_meshes(h).size() >= 1,
				"the holy image %s keeps its own mesh" % h.name)
	t._check(holy >= 1, "the red corner has its image (%d)" % holy)
	var book := hub.get_node_or_null("JournalBook")
	t._check(book != null and book.board != null,
		"the journal keeps its node and board")
	t._check(hub.get_viewport().use_occlusion_culling,
		"the hub's viewport culls by its occluders")
	t._check(hub.find_children("*", "OccluderInstance3D", true,
		false).size() == hub.OCCLUDERS.size(), "every occluder is built")
	hub.queue_free()
