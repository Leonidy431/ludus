## Static batching of still geometry (docs/APK_REQUIREMENTS.md, Б-1).
##
## The Compatibility renderer draws every surface of every mesh instance
## with its own draw call and does not merge them.  The hub is built from
## hundreds of small boxes and layered SVG reliefs (one mesh per layer),
## so its frame was 438 calls where Quest 2 asks for fewer than 100.
## merge() bakes the still meshes under a node into a few meshes, one
## surface per material, without changing what is seen:
##   - only opaque, untextured StandardMaterial3D surfaces are merged;
##     surfaces whose materials differ only in albedo colour share one
##     surface, and the colour moves into the vertex colour (sRGB, as the
##     albedo colour is), so the pixel is the same;
##   - transparent surfaces stay as they were, since each is sorted back
##     to front on its own and a merge would fix their order;
##   - positions and normals are baked with the node's full transform
##     (the normal by the inverse transpose, as the renderer does for a
##     squashed card), and a mirrored node keeps the facing the renderer
##     gave it (see _bake);
##   - a group never gains a light: every member of a group is touched by
##     the same omni and spot lights (by their bounding boxes, as the
##     renderer pairs them), and the group's own box touches no other.
##     So each fragment sums the same lights as before, and no object
##     comes near the renderer's per-object light cap;
##   - a group stays inside one zone (the hub's cell behind its
##     partition), so an occluder can still hide the zone as a whole, and
##     near geometry is grouped only within max_extent metres, so frustum
##     culling keeps working at the scale of a room.
## Nodes that move or change are never merged: subtrees in "skip" are
## left alone, and a node in "scopes" or a node with its own script (an
## interactable such as the journal) is merged only within itself, so
## the node, its script and its transform stay as they are.
class_name StaticBatch
extends RefCounted

## Merged instances carry this meta, so a second pass leaves them alone.
const META := "static_batch"
## Material properties that do not change the pixel, or that the merge
## replaces (the albedo colour becomes the vertex colour).
const SIG_IGNORE := ["albedo_color", "resource_name", "resource_path",
	"resource_local_to_scene", "resource_scene_unique_id", "script"]

## The stored property names of StandardMaterial3D, read once.
static var _sig_names := PackedStringArray()


## Merge the still meshes under root.  opts:
##   skip:       nodes whose subtrees are not touched;
##   scopes:     nodes merged only within themselves (they may move);
##   zones:      AABBs in root space; a group never spans two of them;
##   max_extent: largest width of a near group on x and z, metres;
##   far:        beyond this distance from root's origin on x and z a
##               group has no width limit (the mountains).
## Returns counts: instances and surfaces before, merged meshes after.
static func merge(root: Node3D, opts := {}) -> Dictionary:
	var stats := {"instances": 0, "surfaces": 0, "groups": 0,
		"kept_single": 0}
	var skip: Array = opts.get("skip", [])
	var cap := int(ProjectSettings.get_setting(
		"rendering/limits/opengl/max_lights_per_object", 8))
	# Lights are found once in root's space, whichever scope a light
	# lives in: a scope's meshes are lit by the whole yard.
	var ctx := {"skip": skip, "scopes": opts.get("scopes", []),
		"lights": _lights(root, skip), "cap": cap,
		"zones": opts.get("zones", []),
		"max_extent": opts.get("max_extent", 6.0),
		"far": opts.get("far", 60.0), "sigs": {}}
	_merge_scope(root, Transform3D.IDENTITY, ctx, stats)
	return stats


## Merge the candidates of one scope in its own space; top_xf takes that
## space to root's, where lights and zones are.
static func _merge_scope(scope: Node3D, top_xf: Transform3D, ctx: Dictionary,
		stats: Dictionary) -> void:
	var sub: Array = []
	var cands: Array = []
	_collect(scope, Transform3D.IDENTITY, ctx, cands, sub)
	_merge_candidates(scope, top_xf, cands, ctx, stats)
	for s in sub:
		_merge_scope(s[0], top_xf * s[1], ctx, stats)


## Walk the tree under node; still mesh instances go to cands with their
## transform in the scope's space, nodes merged on their own go to sub
## with theirs.
static func _collect(node: Node, xf: Transform3D, ctx: Dictionary,
		cands: Array, sub: Array) -> void:
	var skip: Array = ctx.skip
	var scopes: Array = ctx.scopes
	for c in node.get_children():
		if c in skip or not c is Node3D:
			continue
		var n := c as Node3D
		if not n.visible or n.top_level:
			continue
		# A subtree with a visibility parent (a level of detail, such
		# as RovLod's full model) appears and hides at run time; baked
		# into a group, it would lose the switch.
		if not n.visibility_parent.is_empty():
			continue
		var cx: Transform3D = xf * n.transform
		if n in scopes or n.get_script() != null:
			sub.append([n, cx])
			continue
		if n is MeshInstance3D and not n.has_meta(META):
			var info := _describe(n as MeshInstance3D, ctx.sigs)
			if not info.is_empty():
				info["node"] = n
				info["xf"] = cx
				info["aabb"] = cx * (n as MeshInstance3D).mesh.get_aabb()
				cands.append(info)
		_collect(n, cx, ctx, cands, sub)


## What a mesh instance brings to a merge, or {} if it cannot be merged
## without changing the picture.
static func _describe(mi: MeshInstance3D, sigs: Dictionary) -> Dictionary:
	var mesh := mi.mesh
	if mesh == null or mi.material_overlay != null or mi.skin != null:
		return {}
	if not (mesh is ArrayMesh or mesh is PrimitiveMesh):
		return {}
	if mesh is ArrayMesh and (mesh as ArrayMesh).get_blend_shape_count() > 0:
		return {}
	if mi.transparency != 0.0 or mi.visibility_range_begin != 0.0 \
			or mi.visibility_range_end != 0.0:
		return {}
	var surfaces := []
	var sig := ""
	for s in mesh.get_surface_count():
		# A PrimitiveMesh is always triangles; an ArrayMesh says so.
		if mesh is ArrayMesh and (mesh as ArrayMesh) \
				.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return {}
		var mat: Material = mi.material_override
		if mat == null:
			mat = mi.get_surface_override_material(s)
		if mat == null:
			mat = mesh.surface_get_material(s)
		# A material shared by many surfaces is read once.
		var mid := mat.get_instance_id() if mat else 0
		if not sigs.has(mid):
			sigs[mid] = _material_sig(mat)
		var ms: String = sigs[mid]
		if ms == "":
			return {}
		if sig != "" and ms != sig:
			return {}
		sig = ms
		surfaces.append({"surface": s, "material": mat})
	if surfaces.is_empty():
		return {}
	var inst := "cs%d l%d gi%d io%d m%.3f" % [mi.cast_shadow, mi.layers,
		mi.gi_mode, int(mi.ignore_occlusion_culling), mi.extra_cull_margin]
	return {"sig": sig + "|" + inst, "surfaces": surfaces}


## The signature of a material that can take its albedo from vertex
## colour, or "" if it cannot be merged: every stored property except
## the albedo colour, so two surfaces share a group only when nothing
## else differs.
static func _material_sig(mat: Material) -> String:
	if mat == null or mat.get_class() != "StandardMaterial3D":
		return ""
	var m := mat as StandardMaterial3D
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			or m.albedo_color.a < 1.0 or m.vertex_color_use_as_albedo \
			or m.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED \
			or m.next_pass != null:
		return ""
	for t in BaseMaterial3D.TEXTURE_MAX:
		if m.get_texture(t) != null:
			return ""
	# Every StandardMaterial3D has the same stored properties: their
	# names are read once, and the values are written out in one call.
	if _sig_names.is_empty():
		for p in m.get_property_list():
			if p.usage & PROPERTY_USAGE_STORAGE and not p.name in SIG_IGNORE:
				_sig_names.append(p.name)
	var values := []
	for n in _sig_names:
		values.append(m.get(n))
	return var_to_str(values)


## Omni and spot lights under root as boxes in root space, the same boxes
## the renderer pairs with instances (LightStorage::light_get_aabb in
## drivers/gles3: a cube of the range; for a spot the box of its cone),
## moved by the light's transform.  A fragment outside a light's box gets
## nothing from it, so a group whose box meets the same lights as each of
## its members is lit as they were.  Energy is not looked at: a lantern
## at zero is still paired and may be lit later.
static func _lights(root: Node3D, skip: Array) -> Array:
	var out := []
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		for c in (item[0] as Node).get_children():
			if c in skip or not c is Node3D:
				continue
			var cx: Transform3D = item[1] * (c as Node3D).transform
			var local := AABB()
			if c is OmniLight3D:
				var r := (c as OmniLight3D).omni_range
				local = AABB(-Vector3.ONE * r, Vector3.ONE * 2.0 * r)
			elif c is SpotLight3D:
				var s := c as SpotLight3D
				var angle := deg_to_rad(s.spot_angle)
				var size := sin(angle) * s.spot_range
				local = AABB(Vector3(-size, -size, -s.spot_range),
					Vector3(size * 2.0, size * 2.0, s.spot_range))
				if angle > PI * 0.5:
					local = AABB(-Vector3.ONE * s.spot_range,
						Vector3.ONE * 2.0 * s.spot_range)
			if local.has_volume():
				out.append(cx * local)
			stack.append([c, cx])
	return out


static func _light_set(box: AABB, lights: Array) -> Array:
	var s := []
	for i in lights.size():
		if (lights[i] as AABB).intersects(box):
			s.append(i)
	return s


static func _zone(box: AABB, zones: Array) -> int:
	var c := box.get_center()
	for i in zones.size():
		if (zones[i] as AABB).grow(0.001).has_point(c):
			return i
	return -1


## Group the candidates and bake each group of two or more surfaces into
## one mesh instance under scope.  Boxes are compared in root's space
## (top_xf), where the lights and zones are.
static func _merge_candidates(scope: Node3D, top_xf: Transform3D,
		cands: Array, ctx: Dictionary, stats: Dictionary) -> void:
	var lights: Array = ctx.lights
	var zones: Array = ctx.zones
	var max_extent: float = ctx.max_extent
	var groups: Array = []  # {key, box, members}
	for c in cands:
		var box: AABB = top_xf * (c.aabb as AABB)
		var ls := _light_set(box, lights)
		if ls.size() > int(ctx.cap):
			continue
		var centre := box.get_center()
		var is_far := Vector2(centre.x, centre.z).length() > float(ctx.far)
		var key := "%s|%s|%d|%s" % [c.sig, str(ls), _zone(box, zones),
			str(is_far)]
		var home := {}
		for g in groups:
			if g.key != key:
				continue
			var joined: AABB = (g.box as AABB).merge(box)
			# A group grows to max_extent, or to the length of its
			# longest member (an eave joins its wall), never beyond.
			var gb: AABB = g.box
			var wide := maxf(max_extent, maxf(gb.size.x, box.size.x))
			var deep := maxf(max_extent, maxf(gb.size.z, box.size.z))
			if not is_far and (joined.size.x > wide + 0.001
					or joined.size.z > deep + 0.001):
				continue
			if _light_set(joined, lights) != ls:
				continue
			home = g
			break
		if home.is_empty():
			home = {"key": key, "box": box, "members": []}
			groups.append(home)
		home.box = (home.box as AABB).merge(box)
		home.members.append(c)
	var n := 0
	for g in groups:
		var count := 0
		for m in g.members:
			count += m.surfaces.size()
		if count < 2:
			stats.kept_single += 1
			continue
		var baked := _bake(g.members, "StaticBatch%d" % n)
		scope.add_child(baked)
		n += 1
		stats.groups += 1
		stats.instances += g.members.size()
		stats.surfaces += count
		for m in g.members:
			_retire(m.node)


## One mesh instance holding every surface of the members, in the space
## of their common root.
static func _bake(members: Array, label: String) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var first: StandardMaterial3D
	var inst: MeshInstance3D
	for m in members:
		var mi: MeshInstance3D = m.node
		if inst == null:
			inst = mi
		var xf: Transform3D = m.xf
		# Normals go by the inverse transpose; when it is a rotation
		# times one scale the lengths are fixed once, else per vertex.
		var nb := xf.basis.inverse().transposed()
		var uniform := _is_uniform(nb)
		var nxf := Transform3D(nb.orthonormalized() if uniform else nb,
			Vector3.ZERO)
		var mirrored := xf.basis.determinant() < 0.0
		for s in m.surfaces:
			var mat: StandardMaterial3D = s.material
			if first == null:
				first = mat
			# A mirrored instance: the Compatibility renderer only swaps
			# the cull face and leaves the winding as it is, so a culled
			# material shows its true front and a double-sided one is
			# shaded as its back (gl_FrontFacing is false).  Baked, the
			# winding is reversed for a culled material and kept for a
			# double-sided one, which gives the same picture.
			var flip := mirrored \
				and mat.cull_mode != BaseMaterial3D.CULL_DISABLED
			var arr := mi.mesh.surface_get_arrays(s.surface)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] \
				if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var base := verts.size()
			verts.append_array(xf * v)
			if nr.size() != v.size():
				# No normals (the ROV's glb has none): the renderer reads
				# the unset attribute as zero; scene.glsl decodes it to
				# the axis -Z and turns +Z about that axis, which gives
				# local +Z at every vertex (axis_angle_to_tbn).  The bake
				# gives the same normal, so the shading stays as it is.
				nr = PackedVector3Array()
				nr.resize(v.size())
				nr.fill(Vector3(0, 0, 1))
			var tn: PackedVector3Array = nxf * nr
			if not uniform:
				for i in tn.size():
					tn[i] = tn[i].normalized()
			norms.append_array(tn)
			var col := PackedColorArray()
			col.resize(v.size())
			col.fill(_quantised(mat.albedo_color))
			cols.append_array(col)
			var ind = arr[Mesh.ARRAY_INDEX]
			var tri := PackedInt32Array()
			if ind == null or (ind as PackedInt32Array).is_empty():
				tri.resize(v.size())
				for i in v.size():
					tri[i] = i
			else:
				tri = ind
			if flip:
				for i in range(0, tri.size() - 2, 3):
					var a := tri[i + 1]
					tri[i + 1] = tri[i + 2]
					tri[i + 2] = a
			for i in tri.size():
				tri[i] += base
			idx.append_array(tri)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := first.duplicate() as StandardMaterial3D
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.vertex_color_use_as_albedo = true
	# The albedo colour is sRGB and made linear by the renderer; the
	# vertex colour takes the same path.
	mat.vertex_color_is_srgb = true
	mesh.surface_set_material(0, mat)
	var out := MeshInstance3D.new()
	out.name = label
	out.mesh = mesh
	out.cast_shadow = inst.cast_shadow
	out.layers = inst.layers
	out.gi_mode = inst.gi_mode
	out.ignore_occlusion_culling = inst.ignore_occlusion_culling
	out.extra_cull_margin = inst.extra_cull_margin
	out.set_meta(META, true)
	return out


## Vertex colours are stored in 8 bits by truncation; a quarter step
## over the nearest level lands on that level, not the one below.
static func _quantised(c: Color) -> Color:
	return Color((roundf(c.r * 255.0) + 0.25) / 255.0,
		(roundf(c.g * 255.0) + 0.25) / 255.0,
		(roundf(c.b * 255.0) + 0.25) / 255.0, 1.0)


static func _is_uniform(b: Basis) -> bool:
	var x := b.x.length()
	var y := b.y.length()
	var z := b.z.length()
	return absf(x - y) < 1e-4 * x and absf(x - z) < 1e-4 * x \
		and absf(b.x.dot(b.y)) < 1e-4 * x * y \
		and absf(b.x.dot(b.z)) < 1e-4 * x * z \
		and absf(b.y.dot(b.z)) < 1e-4 * y * z


## The merged node leaves the tree; if it had children (a glTF node
## over another), it stays as an empty transform so they keep theirs.
static func _retire(mi: MeshInstance3D) -> void:
	if mi.get_child_count() > 0:
		mi.mesh = null
		mi.material_override = null
		return
	mi.get_parent().remove_child(mi)
	mi.free()
