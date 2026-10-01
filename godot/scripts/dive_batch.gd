## Fewer draw calls in the dive (docs/APK_REQUIREMENTS.md, blocker Б-1:
## the project's limit is 100 a frame; the dive drew 255 at 3 m).
##
## The Compatibility renderer draws every surface of every instance with
## its own call.  The dive's still parts are batched here without
## changing what is seen or what the player can do:
##   - the Mangustik's body: its model, the posoh hydrophone and each
##     rigid link of the arm are baked by StaticBatch, each within itself,
##     so the body, the arm's joints and every node a script moves or
##     hides keep their transforms;
##   - each lake object and each trace of the Atlas: the surfaces of one
##     thing that share a band material up to their colour become one
##     surface of that thing (merge_thing).  A thing stays its own node
##     with its own box for the band, so the arm still reaches it and the
##     band still runs on the outline of the whole thing.  Things are
##     never merged with one another, and a holy thing is not touched at
##     all (TABOO 0.2, 0.4 rule 1): it keeps its plain stone and its own
##     nodes;
##   - the D6 drawings of the shore: every still drawing of one size is
##     drawn from one texture array in one call (merge_drawings), each
##     quad turned to the eye about its own foot, as its Sprite3D was.
## Exactness: the colour of a surface goes to the shader as the very
## float its material's albedo uniform holds, and the drawings are sampled from the same texels, so a pixel differs
## only where a far imported mesh used its automatic LOD (the batch has
## none) or where a billboard's own box culled it at a frame's edge.
class_name DiveBatch
extends RefCounted

## Batches carry this meta, so a second pass leaves them alone.
const META := "dive_batch"
## The layers one texture array may hold: the least OpenGL ES 3.0
## guarantees (GL_MAX_ARRAY_TEXTURE_LAYERS).
const MAX_LAYERS := 256


## Bake the still parts of the body, each within itself.  A model with a
## visibility range (a far proxy) is left to StaticBatch's own rule: a
## mesh with a range is never merged.
static func merge_body(body: RovBody) -> Dictionary:
	var out := {}
	if body.model != null:
		out["model"] = StaticBatch.merge(body.model)
	if body.hydrophone != null:
		# The piezo disc behind the end cap came out striped when baked
		# (the close-up proof frame, about 200 px): it stays its own.
		var skip := body.hydrophone.find_children("piezo*", "", true,
			false)
		out["hydrophone"] = StaticBatch.merge(body.hydrophone,
			{"skip": skip})
	if body.arm_root != null:
		# Every joint the arm turns is merged only within itself.
		var joints: Array = [body.arm_upper, body.arm_fore]
		joints.append_array(body.fingers)
		out["arm"] = StaticBatch.merge(body.arm_root, {"scopes": joints})
	return out


# --- Lake objects and traces ------------------------------------------------

## The uniforms of RimLight's mesh shader that a batch reads per vertex.
const PER_VERTEX := {
	"uniform vec4 albedo : source_color = vec4(1.0);":
		"varying flat vec4 albedo;",
	"uniform float roughness : hint_range(0.0, 1.0) = 1.0;":
		"varying flat float roughness;",
	"uniform float metallic : hint_range(0.0, 1.0) = 0.0;":
		"varying flat float metallic;",
	"uniform float specular : hint_range(0.0, 1.0) = 0.5;":
		"varying flat float specular;",
}


## The band shader of a merged thing: RimLight's own mesh shader, with
## the albedo (CUSTOM0, the uniform's own value) and roughness, metallic and specular (CUSTOM1) read per
## vertex instead of from uniforms.  Everything else, the box of the
## thing included, stays as RimLight wrote it; "" if the code is not
## the one this was written for.
static func batch_code(rim_code: String) -> String:
	var start := "void vertex() {\n"
	if not start in rim_code:
		return ""
	var code := rim_code
	for decl in PER_VERTEX:
		if not decl in code:
			return ""
		code = code.replace(decl, PER_VERTEX[decl])
	return code.replace(start, start + "\talbedo = CUSTOM0;\n"
		+ "\troughness = CUSTOM1.x;\n\tmetallic = CUSTOM1.y;\n"
		+ "\tspecular = CUSTOM1.z;\n")


## Merge the band surfaces of one thing that differ only in colour into
## one surface.  rim is the scene's RimLight (its materials and shaders).
## Returns the number of surfaces merged away.
static func merge_thing(node: Node3D, rim: RimLight,
		cache: Dictionary) -> int:
	var groups := {}
	var stack: Array = [[node, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		for c in (item[0] as Node).get_children():
			if not c is Node3D or not (c as Node3D).visible \
					or c.get_script() != null:
				continue
			var cx: Transform3D = item[1] * (c as Node3D).transform
			stack.append([c, cx])
			if c is MeshInstance3D and not c.has_meta(META):
				_take_surfaces(c as MeshInstance3D, cx, rim, groups)
	var before := 0
	for key in groups:
		before += (groups[key].surfaces as Array).size()
	# One surface draws as it did: nothing to gain.
	if before < 2 or groups.size() >= before:
		return 0
	# The box is the whole thing's, taken before any part leaves.
	var box := RimLight.box_in(Transform3D.IDENTITY,
		RimLight.thing_box(node))
	var gone := {}
	for key in groups:
		var g: Dictionary = groups[key]
		var mi := _bake_thing(g.surfaces, g.inst,
			_thing_material(g.material, cache))
		node.add_child(mi)
		RimLight._set_box(mi, box)
		for s in g.surfaces:
			gone[s.node] = true
	# Every surface of a picked instance went into a batch (an instance
	# joins whole or not at all), so the instance leaves the tree.
	for mi in gone:
		StaticBatch._retire(mi)
	return before - groups.size()


## The surfaces of one mesh instance that can join a batch, by group.
## A mesh joins only if every surface of it can, so no instance is left
## half drawn: an instance is either baked whole or kept as it is.
static func _take_surfaces(mi: MeshInstance3D, xf: Transform3D,
		rim: RimLight, groups: Dictionary) -> void:
	var mesh := mi.mesh
	if mesh == null or mi.skin != null or mi.material_overlay != null \
			or mi.transparency != 0.0 or mi.visibility_range_end != 0.0 \
			or mi.visibility_range_begin != 0.0:
		return
	if not (mesh is ArrayMesh or mesh is PrimitiveMesh):
		return
	if mesh is ArrayMesh and (mesh as ArrayMesh).get_blend_shape_count() > 0:
		return
	var inst := "cs%d l%d gi%d io%d m%.3f" % [mi.cast_shadow, mi.layers,
		mi.gi_mode, int(mi.ignore_occlusion_culling), mi.extra_cull_margin]
	var picked := []
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh) \
				.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return
		var mat := mi.get_active_material(s) as ShaderMaterial
		if mat == null or not mat in rim.materials.values() \
				or batch_code(mat.shader.code) == "":
			return
		picked.append({"surface": s, "material": mat})
	for p in picked:
		var mat: ShaderMaterial = p.material
		var key := "%d|%s" % [mat.shader.get_instance_id(), inst]
		# Transparent surfaces blend in the order they are drawn: they
		# are joined only within their own instance, in its order.
		if "ALPHA =" in mat.shader.code:
			key += "|%d" % mi.get_instance_id()
		if not groups.has(key):
			groups[key] = {"material": mat, "inst": mi, "surfaces": []}
		groups[key].surfaces.append({"node": mi, "xf": xf,
			"surface": p.surface, "material": mat, "done": false})


## One ShaderMaterial per band shader (render mode and alpha).
static func _thing_material(base: ShaderMaterial,
		cache: Dictionary) -> ShaderMaterial:
	var key := "%d" % base.shader.get_instance_id()
	if cache.has(key):
		return cache[key]
	var code := batch_code(base.shader.code)
	if code == "":
		return null
	var sh_key := "shader:%d" % base.shader.get_instance_id()
	if not cache.has(sh_key):
		var sh := Shader.new()
		sh.code = code
		cache[sh_key] = sh
	var sm := ShaderMaterial.new()
	sm.shader = cache[sh_key]
	cache[key] = sm
	return sm


## One mesh instance holding the surfaces, in the thing's space.  The
## winding and normals follow StaticBatch._bake (mirrored nodes keep the
## face the renderer gave them; normals by the inverse transpose).
static func _bake_thing(surfaces: Array, like: MeshInstance3D,
		mat: ShaderMaterial) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var albedo := PackedFloat32Array()
	var surface := PackedFloat32Array()
	var idx := PackedInt32Array()
	var cull_off := (mat.shader.code.find("cull_disabled") >= 0)
	for s in surfaces:
		var mi: MeshInstance3D = s.node
		var xf: Transform3D = s.xf
		var nb := xf.basis.inverse().transposed()
		var uniform := StaticBatch._is_uniform(nb)
		var nxf := Transform3D(nb.orthonormalized() if uniform else nb,
			Vector3.ZERO)
		var flip := xf.basis.determinant() < 0.0 and not cull_off
		var arr := mi.mesh.surface_get_arrays(s.surface)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] \
			if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		if nr.size() != v.size():
			nr = PackedVector3Array()
			nr.resize(v.size())
			nr.fill(Vector3(0, 0, 1))
		var base := verts.size()
		verts.append_array(xf * v)
		var tn: PackedVector3Array = nxf * nr
		if not uniform:
			for i in tn.size():
				tn[i] = tn[i].normalized()
		norms.append_array(tn)
		# The uniform's own value: the varying takes the same path to
		# ALBEDO.  Written linear (srgb_to_linear) it darkened every
		# merged surface in the proof frames (a reed leaf 142 -> 74 in
		# green): the curve was applied twice.
		var sm: ShaderMaterial = s.material
		var c: Color = sm.get_shader_parameter("albedo")
		var rms := [float(sm.get_shader_parameter("roughness")),
			float(sm.get_shader_parameter("metallic")),
			float(sm.get_shader_parameter("specular")), 0.0]
		var col := PackedFloat32Array()
		col.resize(v.size() * 4)
		var par := PackedFloat32Array()
		par.resize(v.size() * 4)
		for i in v.size():
			col[i * 4] = c.r
			col[i * 4 + 1] = c.g
			col[i * 4 + 2] = c.b
			col[i * 4 + 3] = c.a
			for k in 4:
				par[i * 4 + k] = rms[k]
		albedo.append_array(col)
		surface.append_array(par)
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
	arrays[Mesh.ARRAY_CUSTOM0] = albedo
	arrays[Mesh.ARRAY_CUSTOM1] = surface
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
	mesh.surface_set_material(0, mat)
	var out := MeshInstance3D.new()
	out.name = "DiveBatch"
	out.mesh = mesh
	out.cast_shadow = like.cast_shadow
	out.layers = like.layers
	out.gi_mode = like.gi_mode
	out.ignore_occlusion_culling = like.ignore_occlusion_culling
	out.extra_cull_margin = like.extra_cull_margin
	out.set_meta(META, true)
	return out


# --- The D6 drawings --------------------------------------------------------

## The band shader of the drawings with the texture taken from an array:
## RimLight's own drawing shader, its foot (MODEL_MATRIX[3]) and its
## layer read per vertex (CUSTOM0) instead of from the sprite's node.
static func drawing_code(rim_code: String) -> String:
	var decl := "uniform sampler2D drawing : source_color, " \
		+ "filter_linear_mipmap, repeat_disable;"
	var start := "void vertex() {\n"
	if not decl in rim_code or not start in rim_code \
			or not "MODEL_MATRIX[3]" in rim_code:
		return ""
	var code := rim_code.replace("texture(drawing, ", "layer_texel(layer, ")
	code = code.replace("MODEL_MATRIX[3]", "vec4(CUSTOM0.xyz, 1.0)")
	code = code.replace(start, start + "\tlayer = CUSTOM0.w;\n")
	return code.replace(decl, decl.replace("sampler2D ", "sampler2DArray ")
		+ "\nvarying flat float layer;\n"
		+ "vec4 layer_texel(float l, vec2 uv) {\n"
		+ "\treturn texture(drawing, vec3(uv, l));\n}")


## Draw still drawings (Sprite3D with RimLight's drawing material, all
## under one parent) from texture arrays, one call per array.  A drawing
## whose texels cannot be read (a renderer with no read back, a headless
## run) stays the sprite it was.  Returns the sprites drawn by batches.
static func merge_drawings(sprites: Array, rim: RimLight) -> int:
	var by_size := {}
	for sp in sprites:
		var s := sp as Sprite3D
		if s == null or s.texture == null \
				or not rim.drawing_materials.has(s.texture) \
				or s.material_override != rim.drawing_materials[s.texture]:
			continue
		var key := "%s|%s|%s" % [s.texture.get_size(), s.pixel_size,
			s.get_parent().get_instance_id()]
		if not by_size.has(key):
			by_size[key] = []
		by_size[key].append(s)
	var shader: Shader
	var done := 0
	for key in by_size:
		var list: Array = by_size[key]
		if list.size() < 2:
			continue
		var layers := {}
		var images := []
		for s in list:
			if layers.has(s.texture):
				continue
			if images.size() >= MAX_LAYERS:
				break
			var img: Image = s.texture.get_image()
			if img == null or img.is_empty():
				# The renderer gave no texels back (a dummy renderer, or
				# a readback the driver refuses): the drawings stay
				# sprites, a call each.  Said aloud, since on the
				# headset that would bring the calls back unseen.
				push_warning(("DiveBatch.merge_drawings: no texels for "
					+ "%s; %d drawings stay sprites") % [
					s.texture.resource_path, list.size()])
				images.clear()
				break
			if not images.is_empty() and (img.get_format()
					!= images[0].get_format() or img.get_size()
					!= images[0].get_size() or img.has_mipmaps()
					!= images[0].has_mipmaps()):
				images.clear()
				break
			layers[s.texture] = images.size()
			images.append(img)
		if images.is_empty():
			continue
		if shader == null:
			var code := drawing_code(
				(list[0].material_override as ShaderMaterial).shader.code)
			if code == "":
				return done
			shader = Shader.new()
			shader.code = code
		var array := Texture2DArray.new()
		if array.create_from_images(images) != OK:
			continue
		var sm := ShaderMaterial.new()
		sm.shader = shader
		var first := list[0].material_override as ShaderMaterial
		sm.set_shader_parameter("band_uv",
			first.get_shader_parameter("band_uv"))
		sm.set_shader_parameter("drawing", array)
		var take := list.filter(func(s): return layers.has(s.texture))
		var mi := _bake_drawings(take, layers, sm)
		(take[0] as Node).get_parent().add_child(mi)
		for s in take:
			s.get_parent().remove_child(s)
			s.free()
		# The sprites' own textures leave video memory with their last
		# holder, the drawing material: the array holds the same texels.
		for tex in layers:
			rim.drawing_materials.erase(tex)
		done += take.size()
	return done


## Quads as Sprite3D lays them (SpriteBase3D::draw_texture_rect, centred,
## axis Z): from the top left corner, UV (0, 0) at the top left, the
## normal +Z; the foot and the layer of each in CUSTOM0.
static func _bake_drawings(list: Array, layers: Dictionary,
		mat: ShaderMaterial) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var feet := PackedFloat32Array()
	var idx := PackedInt32Array()
	var box := AABB()
	for i in list.size():
		var s: Sprite3D = list[i]
		var half: Vector2 = s.texture.get_size() * s.pixel_size * 0.5
		var at := s.position
		var base := verts.size()
		for c in [[-1.0, 1.0, 0.0, 0.0], [1.0, 1.0, 1.0, 0.0],
				[1.0, -1.0, 1.0, 1.0], [-1.0, -1.0, 0.0, 1.0]]:
			verts.append(Vector3(c[0] * half.x, c[1] * half.y, 0.0))
			norms.append(Vector3(0, 0, 1))
			tans.append_array([1.0, 0.0, 0.0, 1.0])
			uvs.append(Vector2(c[2], c[3]))
			feet.append_array([at.x, at.y, at.z, float(layers[s.texture])])
		idx.append_array([base, base + 1, base + 2, base, base + 2,
			base + 3])
		var r := maxf(half.x, half.y)
		var b := AABB(at - Vector3.ONE * r, Vector3.ONE * 2.0 * r)
		box = b if i == 0 else box.merge(b)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TANGENT] = tans
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_CUSTOM0] = feet
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mesh.surface_set_material(0, mat)
	var out := MeshInstance3D.new()
	out.name = "DiveDrawings"
	out.mesh = mesh
	# The vertices are offsets from each foot: the box is the feet's.
	out.custom_aabb = box
	out.set_meta(META, true)
	return out
