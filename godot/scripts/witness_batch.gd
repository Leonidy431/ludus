## Static batching of the path of the witness (docs/APK_REQUIREMENTS.md,
## blocker Б-1: the project's limit is 100 draw calls a frame).
##
## Every kit is built of small meshes, and each one costs a draw call.
## The parts that are not holy (the floor, the bench of those waiting,
## the candles and their flames, the figures of the brethren, the
## column, the bed, the witness line) never move, so the opaque parts of
## one kit that share every material setting but their colours are
## drawn as one mesh:
## - each part's albedo goes into its vertices, kept as sRGB and turned
##   linear by the material the same way the albedo uniform is;
## - each part's emission (a flame, the witness line, the window) is one
##   texel of a small palette the batch's emission texture reads through
##   the part's UV; a part that does not glow reads a black texel.
##
## Holy objects are never merged: each keeps its own node, its own
## material and its extras (noInteract, noLoot).  Transparent parts stay
## apart as well, since one mesh would fix the order in which they blend
## and the view would change with it.  A merged part stays in the kit,
## hidden, with its name and its extras, so nothing that reads the kit's
## data loses a flag; its meta "drawn_by" names the batch that draws it.
##
## The batch draws each part's authored geometry at full detail.  The
## imported kit meshes also carry automatic LODs, which a far thin
## candle uses; the batch has none, so such a candle's edge may differ by
## a pixel.  With LODs off in both, the frames match within two levels
## of 255 (docs/APK_REQUIREMENTS.md, witness draw calls).
class_name WitnessBatch
extends RefCounted

const PREFIX := "batch-"

## Settings of the geometry instance that must match to share a batch.
const INSTANCE_PROPS := ["cast_shadow", "layers", "gi_mode",
	"visibility_range_begin", "visibility_range_begin_margin",
	"visibility_range_end", "visibility_range_end_margin",
	"visibility_range_fade_mode", "transparency", "extra_cull_margin",
	"lod_bias", "sorting_offset", "sorting_use_aabb_center",
	"ignore_occlusion_culling"]

## Material settings a batch carries per part instead of per material.
const PER_PART := ["albedo_color", "emission", "emission_enabled",
	"emission_energy_multiplier"]


## Holy by the kit's own data: its glTF extras say so, or the kit's
## holyObjects list names it (Godot numbers repeated names: "candle2").
static func is_holy(node: Node, holy_names: Array) -> bool:
	var extras = node.get_meta("extras", {})
	if extras is Dictionary and extras.get("holy", false):
		return true
	var name := String(node.name)
	return name in holy_names \
		or name.rstrip("0123456789") in holy_names


## Merge the kit's static parts that are not holy; returns the batches.
## Groups keep the order of the kit's own nodes, so the result is the
## same on every run.
static func batch_kit(kit: Node3D, holy_names: Array) -> Array:
	var groups := {}
	var order := []
	for c in kit.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if is_holy(mi, holy_names) or not shown(mi, kit):
			continue
		var key := _key(mi)
		# A mirrored part would turn its faces inside out in the batch.
		if key == "" or relative(mi, kit).basis.determinant() <= 0.0:
			continue
		# Glowing parts share a batch only at one emission energy; a part
		# that does not glow joins any of them.
		var energy := _energy(mi)
		if energy >= 0.0:
			key += "|glow=%s" % var_to_str(energy)
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append(mi)
	# Parts that do not glow go with the first glowing batch of their
	# kind, so a kit with one energy draws its opaque parts in one call.
	for key in order.duplicate():
		if key.contains("|glow="):
			continue
		for other in order:
			if other.begins_with(key) and other != key:
				groups[other] = groups[key] + groups[other]
				groups.erase(key)
				order.erase(key)
				break
	var out := []
	for key in order:
		var parts: Array = groups[key]
		if parts.size() >= 2:
			out.append(_merge(kit, parts, "%s%d" % [PREFIX, out.size()]))
	return out


## Visible itself and through every parent up to the kit.  The kit may
## not be in the tree yet, so visible_in_tree cannot be asked.
static func shown(node: Node, kit: Node) -> bool:
	var n := node
	while n != null and n != kit:
		if n is Node3D and not (n as Node3D).visible:
			return false
		n = n.get_parent()
	return n == kit


## The part's transform relative to the kit, walked through its parents.
static func relative(node: Node3D, kit: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != kit:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## The emission energy of a glowing part, or -1 for a part that does
## not glow.
static func _energy(mi: MeshInstance3D) -> float:
	var mat := mi.get_active_material(0) as BaseMaterial3D
	return mat.emission_energy_multiplier if mat.emission_enabled else -1.0


## What a part must share with another to be drawn with it: every stored
## setting of its material but its colours (PER_PART), and the settings
## of the instance.  "" when the part cannot be merged: several surfaces,
## a texture, a sub-resource, transparency, colours already in vertices,
## no normals, not triangles, or a glow brighter than a texel holds.
static func _key(mi: MeshInstance3D) -> String:
	if mi.mesh == null or mi.mesh.get_surface_count() != 1:
		return ""
	if mi.skin != null or mi.material_overlay != null:
		return ""
	if mi.mesh is ArrayMesh:
		var am := mi.mesh as ArrayMesh
		if am.get_blend_shape_count() > 0 \
				or am.surface_get_primitive_type(0) \
				!= Mesh.PRIMITIVE_TRIANGLES \
				or not am.surface_get_format(0) & Mesh.ARRAY_FORMAT_NORMAL:
			return ""
	# A box or other primitive of the engine is always triangles with
	# normals; any other kind of mesh is left as it is.
	elif not mi.mesh is PrimitiveMesh:
		return ""
	var mat := mi.get_active_material(0) as BaseMaterial3D
	if mat == null or mat.vertex_color_use_as_albedo \
			or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return ""
	if mat.emission_enabled and (mat.emission.r > 1.0
			or mat.emission.g > 1.0 or mat.emission.b > 1.0):
		return ""
	var key := mat.get_class() + ";"
	for p in mat.get_property_list():
		if not p.usage & PROPERTY_USAGE_STORAGE:
			continue
		var pname: String = p.name
		if pname in PER_PART or pname.begins_with("resource_") \
				or pname == "script":
			continue
		var v = mat.get(pname)
		if v is Object:
			return ""
		key += "%s=%s;" % [pname, var_to_str(v)]
	for pname in INSTANCE_PROPS:
		key += "%s=%s;" % [pname, var_to_str(mi.get(pname))]
	return key


static func _merge(kit: Node3D, parts: Array, name: String) \
		-> MeshInstance3D:
	# The palette of glows: one texel per distinct emission colour, black
	# for the parts that do not glow.
	var palette: Array = []
	var energy := -1.0
	for part in parts:
		var e := _energy(part)
		var glow := _glow(part)
		if not glow in palette:
			palette.append(glow)
		if e >= 0.0:
			energy = e
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var index := PackedInt32Array()
	var names := []
	var first := parts[0] as MeshInstance3D
	for part in parts:
		var mi := part as MeshInstance3D
		var arrays := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nr: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var xf := relative(mi, kit)
		# Normals go through the inverse transpose, so a scaled part
		# keeps the shading it had.
		var nb := xf.basis.inverse().transposed()
		var colour := (mi.get_active_material(0) as BaseMaterial3D) \
			.albedo_color
		# The centre of the part's texel, so the nearest filter reads it
		# whole.
		var uv := Vector2((palette.find(_glow(mi)) + 0.5) / palette.size(),
			0.5)
		var base := verts.size()
		for i in v.size():
			verts.append(xf * v[i])
			normals.append((nb * nr[i]).normalized())
			colours.append(colour)
			uvs.append(uv)
		var ix = arrays[Mesh.ARRAY_INDEX]
		if ix == null or (ix as PackedInt32Array).is_empty():
			for i in v.size():
				index.append(base + i)
		else:
			for i in ix:
				index.append(base + i)
		mi.visible = false
		mi.set_meta("drawn_by", name)
		names.append(String(mi.name))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colours
	arr[Mesh.ARRAY_INDEX] = index
	var mat := (first.get_active_material(0) as BaseMaterial3D) \
		.duplicate() as BaseMaterial3D
	mat.albedo_color = Color(1, 1, 1, mat.albedo_color.a)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	if energy >= 0.0:
		arr[Mesh.ARRAY_TEX_UV] = uvs
		var img := Image.create_empty(palette.size(), 1, false,
			Image.FORMAT_RGBA8)
		for i in palette.size():
			img.set_pixel(i, 0, palette[i])
		mat.emission_enabled = true
		mat.emission = Color(0, 0, 0)
		mat.emission_energy_multiplier = energy
		mat.emission_texture = ImageTexture.create_from_image(img)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# The parts had no texture, so the UV transform only moves the
		# palette's texels; it is reset so each UV reads its own texel.
		mat.uv1_scale = Vector3.ONE
		mat.uv1_offset = Vector3.ZERO
		mat.uv1_triplanar = false
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, mat)
	var batch := MeshInstance3D.new()
	batch.name = name
	batch.mesh = mesh
	for pname in INSTANCE_PROPS:
		batch.set(pname, first.get(pname))
	# The batch is scenery drawn in one call: nothing in it can be taken
	# or touched, whatever each part's own extras said.
	batch.set_meta("extras", {"batch": true, "parts": names,
		"noInteract": true, "noLoot": true})
	kit.add_child(batch)
	return batch


## The part's glow as a palette colour: its emission, or black.
static func _glow(mi: MeshInstance3D) -> Color:
	var mat := mi.get_active_material(0) as BaseMaterial3D
	if not mat.emission_enabled:
		return Color(0, 0, 0, 1)
	return Color(mat.emission.r, mat.emission.g, mat.emission.b, 1)
