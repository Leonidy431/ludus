extends SceneTree
# Temporary census of the hub's drawables (not committed).
var hub: Node3D
var f := 0


func _initialize() -> void:
	hub = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)


func _process(_d: float) -> bool:
	f += 1
	if f < 3:
		return false
	var by_parent := {}
	var total_surf := 0
	var n_mi := 0
	var labels := 0
	var label_outline := 0
	var obitel_models := {}
	var mats := {}
	for c in hub.find_children("*", "", true, false):
		if c is MeshInstance3D and c.mesh:
			n_mi += 1
			var s: int = c.mesh.get_surface_count()
			total_surf += s
			var key := str(c.get_parent().name)
			if c.get_parent() == hub:
				key = "hub:" + c.mesh.get_class()
			var p: Node = c
			while p != hub:
				if str(p.name).begins_with("Obitel_"):
					key = "obitel-model"
					obitel_models[str(p.name)] = obitel_models.get(
						str(p.name), 0) + s
					break
				p = p.get_parent()
			by_parent[key] = by_parent.get(key, 0) + s
		elif c is Label3D:
			labels += 1
			if c.outline_size > 0:
				label_outline += 1
		elif c is Sprite3D:
			by_parent["sprite3d"] = by_parent.get("sprite3d", 0) + 1
		elif c is GeometryInstance3D:
			by_parent["other:" + c.get_class()] = by_parent.get(
				"other:" + c.get_class(), 0) + 1
	print("MI ", n_mi, " surfaces ", total_surf, " labels ", labels,
		" with outline ", label_outline)
	var keys := by_parent.keys()
	keys.sort_custom(func(a, b): return by_parent[a] > by_parent[b])
	for k in keys:
		print("  ", k, ": ", by_parent[k])
	var ok := obitel_models.keys()
	ok.sort_custom(func(a, b): return obitel_models[a] > obitel_models[b])
	for k in ok:
		print("  OB ", k, ": ", obitel_models[k])
	var lights := hub.find_children("*", "Light3D", true, false)
	print("lights ", lights.size())
	for c in hub.find_children("*", "MeshInstance3D", true, false):
		if c.mesh is ArrayMesh and c.has_meta("static_batch"):
			print("  G ", c.get_parent().name, "/", c.name, " ",
				c.mesh.get_aabb(), " v=", c.mesh.surface_get_array_len(0))
		elif c.mesh is PrimitiveMesh:
			print("  S ", c.get_parent().name, " ", c.mesh.get_class(), " ",
				c.global_position, " ", c.mesh.get_aabb().size)
	return true
