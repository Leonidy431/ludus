extends SceneTree
# Temporary: the transforms and materials of models (not committed).


func _dump(path: String) -> void:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	print("== ", path.get_file())
	var stack: Array = [[n, Transform3D.IDENTITY, 0]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var xf: Transform3D = it[1]
		for c in node.get_children():
			var cx: Transform3D = xf * (c as Node3D).transform
			var line := "  ".repeat(it[2] + 1) + str(c.name) + " det=%.3f" % \
				cx.basis.determinant()
			if c is MeshInstance3D:
				var m: Mesh = c.mesh
				var mat = m.surface_get_material(0)
				var arr := m.surface_get_arrays(0)
				line += " col=%s nrm=%s alb=%s cull=%d" % [
					str(arr[Mesh.ARRAY_COLOR] != null),
					str(arr[Mesh.ARRAY_NORMAL] != null),
					str(mat.albedo_color) if mat else "-",
					mat.cull_mode if mat else -1]
			print(line)
			stack.append([c, cx, it[2] + 1])
	n.free()


func _initialize() -> void:
	_dump("res://models/rov/mangustik.glb")
	_dump("res://models/obitel/obj-termometr-vody.glb")
	quit(0)
