## Builds one location from its plan (LocationCore.plan): the shell and
## its light, the bench, the wished things on their slots, the heart and
## the way back.  The standard is the cell of the evening watch (CLAUDE.md
## TABOO 0.013, scripts/rule_cell.gd and scripts/obitel_layout.gd):
##   - one heart, one practice or action, its hint names only it;
##   - the light of the place's class (TABOO 0.38): the hearth's lamp, the
##     lampada only beside a holy thing, the instrument light of the ROV;
##   - the things on their slots around the heart, the passage free, a
##     name tag seen only within 3.2 m;
##   - a holy thing only on its own slot, flat, noInteract and noLoot,
##     without a tag, a glow or a halo (TABOO 0.2, 0.4 item 1).
## A drawn card from an SVG carries one surface per layer; its surfaces
## are joined here into one, coloured by vertex, so a card is one draw
## call and not up to 85 (HLD L2, TABOO 0.011).  The shell's boxes are
## joined the same way.
class_name LocationBuild
extends RefCounted

const OAK := Color(0.42, 0.29, 0.17)
const BIRCH := Color(0.88, 0.86, 0.8)
const WHITE := Color(0.9, 0.87, 0.8)
const BARK := Color(0.93, 0.88, 0.76)
const STONE := Color(0.55, 0.52, 0.47)
const ROCK := Color(0.36, 0.33, 0.3)
const SAND := Color(0.62, 0.57, 0.48)
const STEPPE := Color(0.46, 0.45, 0.33)
const SILT := Color(0.33, 0.31, 0.28)
const WATER := Color(0.16, 0.36, 0.52)
## Lignin and dark oak panels: the walls of a place of the Kiberslav
## branch (TABOO 0.38 item 2), the same material logic, no plastic.
const LIGNIN := Color(0.3, 0.23, 0.17)
## Kinds of place built of stone.
const STONE_KINDS := ["city-gate", "crypt", "archive-crypt",
	"treasury-crypt", "prison", "rabat", "gate", "customs",
	"hermit-cave", "sunken-chapel", "skete-ruin", "watchtower"]
## Clothes of the heart's person, picked by the id's hash (no randomness).
const CLOTH := [Color(0.25, 0.2, 0.15), Color(0.2, 0.17, 0.22),
	Color(0.12, 0.12, 0.16), Color(0.32, 0.26, 0.18),
	Color(0.18, 0.22, 0.2), Color(0.3, 0.18, 0.14)]


static func mat(colour: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	return m


static func box(parent: Node3D, size: Vector3, at: Vector3,
		colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat(colour)
	mi.position = at
	parent.add_child(mi)
	return mi


## Join every mesh under root into one mesh in root's space, each part
## keeping its material's colour as a vertex colour: one surface for the
## opaque layers and, where a drawing has see-through layers (an SVG
## layer with opacity), a second one for them, so a card is at most two
## draw calls.  Returns null when a part has a texture or a glow, so such
## a model is shown as it was made.
static func merged(root: Node3D, rough := 0.85) -> MeshInstance3D:
	# Two buckets: [vertices, normals, colours, indices].
	var solid := [PackedVector3Array(), PackedVector3Array(),
		PackedColorArray(), PackedInt32Array()]
	var clear := [PackedVector3Array(), PackedVector3Array(),
		PackedColorArray(), PackedInt32Array()]
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var xf: Transform3D = item[1]
		for c in n.get_children():
			if not c is Node3D:
				continue
			var cx: Transform3D = xf * (c as Node3D).transform
			stack.append([c, cx])
			if not c is MeshInstance3D or (c as MeshInstance3D).mesh == null:
				continue
			var mi := c as MeshInstance3D
			var nb := cx.basis.inverse().transposed()
			for s in mi.mesh.get_surface_count():
				var colour := Color.WHITE
				var see_through := false
				var m := mi.get_active_material(s)
				if m is BaseMaterial3D:
					var bm := m as BaseMaterial3D
					if bm.albedo_texture != null or bm.emission_enabled:
						return null
					colour = bm.albedo_color
					see_through = bm.transparency \
						!= BaseMaterial3D.TRANSPARENCY_DISABLED \
						or colour.a < 0.99
				elif m != null:
					return null
				var a := mi.mesh.surface_get_arrays(s)
				# Primitive meshes (boxes, capsules) are always triangles;
				# an imported mesh says what it holds.
				if a.is_empty() or mi.mesh is ArrayMesh \
						and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) \
						!= Mesh.PRIMITIVE_TRIANGLES:
					continue
				_append(clear if see_through else solid, a, cx, nb, colour)
	if solid[0].is_empty() and clear[0].is_empty():
		return null
	var am := ArrayMesh.new()
	var mats := []
	var buckets := [solid, clear]
	for bi in 2:
		var bucket: Array = buckets[bi]
		if bucket[0].is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = bucket[0]
		arrays[Mesh.ARRAY_NORMAL] = bucket[1]
		arrays[Mesh.ARRAY_COLOR] = bucket[2]
		arrays[Mesh.ARRAY_INDEX] = bucket[3]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mm := StandardMaterial3D.new()
		mm.vertex_color_use_as_albedo = true
		mm.vertex_color_is_srgb = true
		mm.roughness = rough
		mm.cull_mode = BaseMaterial3D.CULL_DISABLED
		if bi == 1:
			mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mats.append(mm)
	for i in mats.size():
		am.surface_set_material(i, mats[i])
	var out := MeshInstance3D.new()
	out.mesh = am
	return out


## One surface's arrays, moved into the joined mesh's space, appended
## to a bucket with the material's colour on every vertex.
static func _append(bucket: Array, a: Array, cx: Transform3D, nb: Basis,
		colour: Color) -> void:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nn = a[Mesh.ARRAY_NORMAL]
	var cc = a[Mesh.ARRAY_COLOR]
	var ii = a[Mesh.ARRAY_INDEX]
	var verts: PackedVector3Array = bucket[0]
	var norms: PackedVector3Array = bucket[1]
	var cols: PackedColorArray = bucket[2]
	var idx: PackedInt32Array = bucket[3]
	var base := verts.size()
	for k in v.size():
		verts.append(cx * v[k])
		if nn is PackedVector3Array and nn.size() == v.size():
			norms.append((nb * nn[k]).normalized())
		else:
			norms.append(Vector3.UP)
		if cc is PackedColorArray and cc.size() == v.size():
			cols.append(cc[k] * colour)
		else:
			cols.append(colour)
	if ii is PackedInt32Array and ii.size() > 0:
		for k in ii:
			idx.append(base + k)
	else:
		for k in v.size():
			idx.append(base + k)
	# Packed arrays are values: the grown ones go back into the bucket.
	bucket[0] = verts
	bucket[1] = norms
	bucket[2] = cols
	bucket[3] = idx


## Replace a group of meshes by their joined mesh, in place.
static func join(group: Node3D, rough := 0.85) -> Node3D:
	var one := merged(group, rough)
	if one == null:
		return group
	one.name = group.name
	one.transform = group.transform
	# The parts were never in the tree; they go now, or they would stay
	# in memory for as long as the game runs.
	group.free()
	return one


## Triangles of every mesh under a node, the node itself included (for
## the 5000 check).
static func triangles(root: Node) -> int:
	var list: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		list.append(root)
	# A drawing of the props store is one quad: two triangles.
	var n := 2 * root.find_children("*", "Sprite3D", true, false).size()
	for c in list:
		var mesh: Mesh = (c as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			var ii = a[Mesh.ARRAY_INDEX]
			if ii is PackedInt32Array and ii.size() > 0:
				n += ii.size() / 3
			else:
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				n += v.size() / 3
	return n


# --- The place ----------------------------------------------------------------

## The whole place under one node "World", so a place can be taken down
## and another built (the proof frames walk several).
static func build(p: Dictionary) -> Node3D:
	var world := Node3D.new()
	world.name = "World"
	world.set_meta("plan_id", p.id)
	_environment(world, p)
	_shell(world, p)
	_bench(world, p)
	var things := Node3D.new()
	things.name = "Things"
	world.add_child(things)
	var tags := Node3D.new()
	tags.name = "Tags"
	world.add_child(tags)
	for s in p.slots:
		var node := instance(s)
		if node == null:
			continue
		things.add_child(node)
		if s.stand:
			_posts(world, s)
		if s.plinth != null:
			var ph: float = s.plinth.h
			var base := Vector3(0.5, ph, 0.12) if s.plinth.stone \
				else Vector3(0.12, ph, 0.12)
			var pl := box(world, base, Vector3(s.pos.x, ph / 2.0, s.pos.z),
				ROCK if s.plinth.stone else OAK)
			pl.rotation_degrees = Vector3(0, s.yaw, 0)
			pl.name = "Plinth_" + s.object
		if s.tag:
			tags.add_child(_tag(s, node))
	_heart(world, p)
	_lights(world, p)
	return world


static func _environment(world: Node3D, p: Dictionary) -> void:
	var env := Environment.new()
	var sky: String = p.light.get("sky", "day")
	var indoor: bool = p.type in ["room", "cave"] or sky == "indoor"
	if p.type == "underwater":
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.02, 0.11, 0.16)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.12, 0.3, 0.36)
		env.ambient_light_energy = 0.55
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = 0.07
		env.fog_light_color = Color(0.04, 0.18, 0.24)
	elif indoor:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.05, 0.045, 0.04)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.55, 0.47, 0.4)
		# A room lit only by its lampada is dim, not black: the heart and
		# the walls stay readable in the headset.
		env.ambient_light_energy = 0.5 if p.light["class"] == "lampada" \
			else 0.42
	else:
		env.background_mode = Environment.BG_SKY
		var s := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		var c: Array = {
			"day": [Color(0.32, 0.52, 0.78), Color(0.78, 0.8, 0.82)],
			"dusk": [Color(0.2, 0.3, 0.5), Color(0.85, 0.62, 0.45)],
			"dawn": [Color(0.3, 0.38, 0.58), Color(0.95, 0.72, 0.55)],
			"night": [Color(0.02, 0.03, 0.07), Color(0.07, 0.08, 0.12)],
		}.get(sky, [Color(0.32, 0.52, 0.78), Color(0.78, 0.8, 0.82)])
		sm.sky_top_color = c[0]
		sm.sky_horizon_color = c[1]
		sm.ground_horizon_color = c[1].darkened(0.3)
		sm.ground_bottom_color = c[1].darkened(0.6)
		s.sky_material = sm
		env.sky = s
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.25 if sky == "night" else 0.5
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = 0.004
		env.fog_light_color = c[1]
		# The haze lies on the far ground, not over the whole sky.
		env.fog_sky_affect = 0.0
		var sun := DirectionalLight3D.new()
		sun.name = "Sun"
		var sun_c: Dictionary = {"day": [Color(1.0, 0.95, 0.88), 1.0, -45],
			"dusk": [Color(1.0, 0.8, 0.6), 0.6, -18],
			"dawn": [Color(1.0, 0.78, 0.6), 0.55, -10],
			"night": [Color(0.6, 0.68, 0.9), 0.12, -50]}
		var sc: Array = sun_c.get(sky, sun_c.day)
		sun.light_color = sc[0]
		sun.light_energy = sc[1]
		sun.rotation_degrees = Vector3(sc[2], -150, 0)
		world.add_child(sun)
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	world.add_child(we)


## The walls and ground of the place, joined into one mesh; water and
## the far mountains apart (the water is smoother).
static func _shell(world: Node3D, p: Dictionary) -> void:
	var g := Node3D.new()
	g.name = "Shell"
	var w: float = p.w
	var d: float = p.d
	var h: float = p.h
	var t := 0.1
	var wall: Color = LIGNIN if p.kiberslav else WHITE
	# Gates, crypts, a prison, a cave and a caravan's stone shed are of
	# stone; the rest are whitewashed with oak (TABOO 0.38 item 2).
	var masonry: bool = p.kind in STONE_KINDS
	if masonry:
		wall = STONE
	match p.type:
		"room", "cave":
			var stone: bool = p.type == "cave"
			var floor_c: Color = ROCK if stone else (STONE.darkened(0.2)
				if masonry else OAK.lightened(0.08))
			var wall_c: Color = ROCK.lightened(0.05) if stone else wall
			box(g, Vector3(w + 2 * t, t, d + 2 * t), Vector3(0, -t / 2, 0),
				floor_c)
			box(g, Vector3(w + 2 * t, t, d + 2 * t), Vector3(0, h + t / 2, 0),
				ROCK if stone else OAK.darkened(0.25))
			box(g, Vector3(w + 2 * t, h, t), Vector3(0, h / 2, -d / 2 - t / 2),
				wall_c)
			for sx in [-1.0, 1.0]:
				box(g, Vector3(t, h, d), Vector3(sx * (w / 2 + t / 2), h / 2, 0),
					wall_c)
			_front(g, w, d, h, t, wall_c, 2.1)
			if not stone:
				# Oak eaves along the side walls under the ceiling.
				for sx in [-1.0, 1.0]:
					box(g, Vector3(0.18, 0.18, d), Vector3(sx * (w / 2 - 0.09),
						h - 0.09, 0), OAK)
		"yard":
			box(g, Vector3(w + 2 * t, t, d + 2 * t), Vector3(0, -t / 2, 0),
				STONE)
			box(g, Vector3(w + 2 * t, h, t), Vector3(0, h / 2, -d / 2 - t / 2),
				wall)
			for sx in [-1.0, 1.0]:
				box(g, Vector3(t, h, d), Vector3(sx * (w / 2 + t / 2), h / 2, 0),
					wall)
			_front(g, w, d, h, t, wall, h + 1.0)
			# Oak caps on the walls: one material logic (TABOO 0.38).
			box(g, Vector3(w + 0.4, 0.14, 0.3), Vector3(0, h + 0.07,
				-d / 2 - t / 2), OAK)
			for sx in [-1.0, 1.0]:
				box(g, Vector3(0.3, 0.14, d + 0.2), Vector3(sx * (w / 2 + t / 2),
					h + 0.07, 0), OAK)
			# The ground outside the walls.
			box(g, Vector3(120, t, 120), Vector3(0, -t / 2 - 0.02, 0),
				STEPPE)
		"shore":
			box(g, Vector3(w, t, d), Vector3(0, -t / 2 + 0.01, 0), SAND)
			box(g, Vector3(160, t, 80), Vector3(0, -t / 2 - 0.01,
				-d / 2 + 40), STEPPE)
		"open":
			box(g, Vector3(w, t, d), Vector3(0, -t / 2 + 0.01, 0),
				STEPPE.lightened(0.12))
			box(g, Vector3(160, t, 160), Vector3(0, -t / 2 - 0.01, 0), STEPPE)
		"underwater":
			box(g, Vector3(90, t, 90), Vector3(0, -t / 2, 0), SILT)
	world.add_child(join(g, 0.95))
	if p.type == "shore":
		var lake := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(400, 0.05, 400)
		lake.mesh = lm
		var water := mat(WATER, 0.35)
		# A low sun on smooth water makes a white band; the lake here is
		# a surface to stand by, so its glint is kept soft.
		water.metallic_specular = 0.15
		lake.material_override = water
		lake.position = Vector3(0, -0.3, -d / 2 - 200.0)
		lake.name = "Water"
		world.add_child(lake)
	if p.type in ["shore", "open"]:
		world.add_child(_mountains(p))


## The front wall with an opening at the entrance (the way back).
static func _front(g: Node3D, w: float, d: float, h: float, t: float,
		colour: Color, door_h: float) -> void:
	var half := 0.7
	var side := w / 2 - half
	if side > 0.05:
		for sx in [-1.0, 1.0]:
			box(g, Vector3(side, h, t), Vector3(sx * (half + side / 2), h / 2,
				d / 2 + t / 2), colour)
	if door_h < h:
		box(g, Vector3(2 * half, h - door_h, t), Vector3(0,
			(h + door_h) / 2, d / 2 + t / 2), colour)


## The far ridges beyond the water or the steppe, as the hub draws the
## Terskey range: far, simple, one mesh.
static func _mountains(p: Dictionary) -> Node3D:
	var g := Node3D.new()
	g.name = "Mountains"
	for i in 9:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 60.0 + (i * 37) % 40
		cm.height = 70.0 + (i * 53) % 50
		cm.radial_segments = 6
		cm.rings = 1
		cone.mesh = cm
		cone.material_override = mat(Color(0.42, 0.44, 0.5))
		var a := -PI / 2.0 - 0.9 + i * 0.22
		cone.position = Vector3(cos(a) * 330.0, cm.height / 2.0 - 10.0,
			sin(a) * 330.0)
		g.add_child(cone)
	return join(g, 1.0)


## The oak bench along the left wall, or a birch crate outdoors, for the
## small things (the data's bench rectangle and top height).
static func _bench(world: Node3D, p: Dictionary) -> void:
	if p.bench == null:
		return
	var r: Array = p.bench.rect
	var top: float = p.bench.top
	var cx := (float(r[0]) + float(r[2])) / 2.0
	var cz := (float(r[1]) + float(r[3])) / 2.0
	var sx := float(r[2]) - float(r[0])
	var sz := float(r[3]) - float(r[1])
	var g := Node3D.new()
	g.name = "Bench"
	var colour: Color = OAK.lightened(0.18) if p.bench.crate else OAK
	if p.bench.crate:
		box(g, Vector3(sx, top, sz), Vector3(cx, top / 2.0, cz), colour)
	else:
		box(g, Vector3(sx, 0.06, sz), Vector3(cx, top - 0.03, cz), colour)
		for dz in [-1.0, 1.0]:
			box(g, Vector3(sx * 0.8, top - 0.06, 0.08), Vector3(cx, (top - 0.06)
				/ 2.0, cz + dz * (sz / 2.0 - 0.1)), colour.darkened(0.15))
	world.add_child(join(g, 0.9))


## Two oak posts and a rail behind a card that stands outdoors.
static func _posts(world: Node3D, s: Dictionary) -> void:
	var g := Node3D.new()
	g.name = "Posts_" + s.object
	var back := Vector3(0, 0, -0.06).rotated(Vector3.UP, deg_to_rad(s.yaw))
	var side := Vector3(0.36, 0, 0).rotated(Vector3.UP, deg_to_rad(s.yaw))
	var bottom: float = s.pos.y - 0.34
	for sgn in [-1, 1]:
		box(g, Vector3(0.07, bottom + 0.4, 0.07), Vector3(s.pos.x, (bottom
			+ 0.4) / 2.0, s.pos.z) + back + side * sgn, OAK)
	world.add_child(join(g, 0.9))


## One thing: its model turned and scaled to the thing's size (fit),
## joined into one mesh, set on its slot by its own box: on the ground or
## the bench by its bottom, on a wall by its centre.
static func instance(s: Dictionary) -> Node3D:
	if s.model.from == "kit":
		return kit(s)
	var model: Node3D = null
	var method := ""
	if s.model.from == "own":
		model = own(s.model.own)
		method = LocationCore.STRETCH_METHOD
	else:
		var scene := load(s.model.path) as PackedScene
		if scene == null:
			return null
		model = scene.instantiate() as Node3D
		method = LocationCore.method_of(s.thing, s.model)
	var probe := Node3D.new()
	probe.add_child(model)
	var raw := ObitelLayout.local_aabb(probe)
	probe.remove_child(model)
	probe.free()
	var f := LocationCore.fit(s.thing, raw.size, method)
	var rot := Node3D.new()
	rot.rotation_degrees = f.rot
	rot.add_child(model)
	var scaler := Node3D.new()
	scaler.scale = f.scale
	scaler.add_child(rot)
	# merged() works in its root's space, so the scale is put under a
	# plain parent to be joined into the vertices.
	var outer := Node3D.new()
	outer.add_child(scaler)
	var one := merged(outer)
	var shape: Node3D = scaler
	outer.remove_child(scaler)
	outer.free()
	if one != null:
		scaler.free()
		shape = one
	var holder := Node3D.new()
	holder.name = "Thing_" + s.object
	holder.add_child(shape)
	var bb := ObitelLayout.local_aabb(holder)
	var centre := bb.get_center()
	if s.layer == "wall":
		shape.position = -centre
	else:
		shape.position = -Vector3(centre.x, bb.position.y, centre.z)
	holder.position = s.pos
	holder.rotation_degrees = Vector3(0, s.yaw, 0)
	holder.set_meta("location_thing", {"object": s.object, "ru": s.ru,
		"mount": s.mount, "holy": s.holy, "noInteract": s.flags.noInteract,
		"noLoot": s.flags.noLoot, "from": s.model.from})
	return holder


## A drawing of the props store (LocationCore._place_kits), as the D6
## drawings stand in the dive (dive.gd _build_own_drawings): a Sprite3D
## of the drawn part of its canvas, in metres, lit by the place's own
## light, cut by its alpha.  On the ground or the bench it turns about
## its upright and stands on its lowest pixel; on a wall it hangs flat,
## facing the room, a hand's breadth off the wall.
static func kit(s: Dictionary) -> Node3D:
	var tex := load(s.model.path) as Texture2D
	if tex == null:
		return null
	var m: Dictionary = s.model
	var sp := Sprite3D.new()
	sp.name = "Drawing"
	sp.texture = tex
	sp.region_enabled = true
	sp.region_rect = m.region
	sp.pixel_size = m.px
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.shaded = true
	sp.double_sided = true
	# The kits are pixel drawings with no mipmaps: nearest keeps their
	# edges, linear would smear them over a metre.
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var holder := Node3D.new()
	holder.name = ("Thing_" if not s.get("second", false) else "Beside_") \
		+ s.object
	holder.add_child(sp)
	if m.billboard:
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.position = Vector3(0, m.h / 2.0, 0)
	else:
		sp.position = Vector3(0, 0, 0.03)
	holder.position = s.pos
	holder.rotation_degrees = Vector3(0, s.yaw, 0)
	holder.set_meta("location_thing", {"object": s.object, "ru": s.ru,
		"mount": s.mount, "holy": false, "noInteract": false,
		"noLoot": false, "from": "kit", "kit": m.kit,
		"licence": m.licence, "second": s.get("second", false)})
	return holder


## The box of a thing in its holder's space, drawings included: a
## billboard is counted as the square it sweeps as it turns.
static func local_box(root: Node3D) -> AABB:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	var box := ObitelLayout.local_aabb(root)
	var first := meshes.is_empty()
	for c in root.find_children("*", "Sprite3D", true, false):
		var sp := c as Sprite3D
		var xf := Transform3D.IDENTITY
		var n: Node = sp
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var w := sp.region_rect.size.x * sp.pixel_size
		var h := sp.region_rect.size.y * sp.pixel_size
		var b := AABB(Vector3(-w / 2.0, -h / 2.0, 0), Vector3(w, h, 0))
		if sp.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
			b = AABB(Vector3(-w / 2.0, -h / 2.0, -w / 2.0), Vector3(w, h, w))
		b = xf * b
		box = b if first else box.merge(b)
		first = false
	return box


## Our own drawings that the builder makes (LocationCore.OWN).
static func own(key: String) -> Node3D:
	var g := Node3D.new()
	match key:
		"lectern":
			# The low oak lectern of the evening cell (rule_cell.gd).
			box(g, Vector3(0.12, 0.9, 0.12), Vector3(0, 0.45, 0), OAK)
			var desk := box(g, Vector3(0.6, 0.05, 0.45), Vector3(0, 0.93, 0),
				OAK)
			desk.rotation_degrees = Vector3(-20, 0, 0)
			var page := box(g, Vector3(0.44, 0.02, 0.3), Vector3(0, 0.97,
				0.02), BARK)
			page.rotation_degrees = Vector3(-20, 0, 0)
			box(g, Vector3(0.4, 0.04, 0.3), Vector3(0, 0.02, 0),
				OAK.darkened(0.2))
	return g


static func _tag(s: Dictionary, node: Node3D) -> Label3D:
	var tag := Label3D.new()
	tag.text = s.ru
	tag.font_size = 26
	tag.pixel_size = 0.0022
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.95, 0.9, 0.8)
	tag.visibility_range_end = LocationCore.TAG_RANGE_M
	var bb := local_box(node)
	var top: float = s.pos.y + bb.end.y if s.layer != "wall" else s.pos.y
	var above: float = 0.2 if s.layer != "wall" else 0.45
	tag.position = Vector3(s.pos.x, top + above, s.pos.z)
	tag.set_meta("tag_of", s.object)
	return tag


# --- The heart ------------------------------------------------------------------

## What stands at the heart, by the core it belongs to: the person of a
## talk, the lectern of a practice or an action, the threshold of a gate,
## a waystone where a thought comes, the ROV over a dive's task, a line
## of oak for the witness.  The heart's own thing (a find, a trace) is
## already on its slot "heart".
static func _heart(world: Node3D, p: Dictionary) -> void:
	var h: Dictionary = p.heart_spec
	var g := Node3D.new()
	g.name = "HeartProp"
	var at: Vector3 = p.heart
	var has_own := false
	for s in p.slots:
		if s.mount == "heart":
			has_own = true
	var person := false
	var wet: bool = p.type == "underwater"
	match "wet" if wet else h.core:
		"wet":
			# Under water the operator acts through the ROV: no lectern
			# on the seabed; a find or a trace is its own thing.
			pass
		"MissionCore":
			if h.step == "dialogue":
				person = true
			elif h.step == "find" and not has_own:
				_find_plinth(g, at, str(h.object))
			elif not has_own:
				_lectern(g, at)
		"TrialCore":
			# The threshold: a stone sill between two low stone jambs, open
			# above (a frame with a crossbar read as a gallows).
			box(g, Vector3(1.0, 0.12, 0.36), at + Vector3(0, 0.06, 0), STONE)
			for sx in [-0.45, 0.45]:
				box(g, Vector3(0.24, 0.9, 0.36), at + Vector3(sx, 0.45, 0),
					STONE.darkened(0.1))
		"PassionCore":
			# A grey waystone where the thought comes to meet the player.
			var stone := box(g, Vector3(0.5, 0.45, 0.4), at + Vector3(0, 0.22,
				0), ROCK)
			stone.rotation_degrees = Vector3(0, 17, 4)
		"DiveCore":
			pass
		"WitnessCore":
			# The witness line: a low kerb of oak, not a glowing marker.
			box(g, Vector3(2.0, 0.08, 0.12), at + Vector3(0, 0.04, 0.35), OAK)
		"AtlasTraces":
			if not has_own:
				_lectern(g, at)
		"RuleCore":
			_lectern(g, at)
		_:
			# A new small action of the place: at a work table under a
			# roof, at a flat stone on open ground and on the shore.
			if p.type in ["open", "shore"]:
				var slab := box(g, Vector3(0.9, 0.4, 0.6), at + Vector3(0, 0.2,
					0), ROCK.lightened(0.1))
				slab.rotation_degrees = Vector3(0, 8, 0)
			else:
				_workbench(g, at)
	if g.get_child_count() > 0:
		world.add_child(join(g, 0.9))
	else:
		g.free()
	if person:
		_person(world, p)
	if wet and not has_own:
		_rov(world, p)


static func _lectern(g: Node3D, at: Vector3) -> void:
	box(g, Vector3(0.12, 1.0, 0.12), at + Vector3(0, 0.5, 0), OAK)
	var desk := box(g, Vector3(0.6, 0.05, 0.45), at + Vector3(0, 1.05, 0),
		OAK)
	desk.rotation_degrees = Vector3(-20, 0, 0)
	var page := box(g, Vector3(0.44, 0.02, 0.3), at + Vector3(0, 1.09, 0.02),
		BARK)
	page.rotation_degrees = Vector3(-20, 0, 0)


## A low oak work table with a sheet of birch bark on it: where a new
## small action of the place is done (HLD phase L3).
static func _workbench(g: Node3D, at: Vector3) -> void:
	box(g, Vector3(1.0, 0.06, 0.5), at + Vector3(0, 0.77, 0), OAK)
	for sx in [-0.42, 0.42]:
		box(g, Vector3(0.07, 0.74, 0.42), at + Vector3(sx, 0.37, 0),
			OAK.darkened(0.15))
	box(g, Vector3(0.4, 0.01, 0.28), at + Vector3(0, 0.805, 0.02), BARK)


## A find that has no slot of its own (the heart names a lake object):
## the object on a low plinth, from the lake's own model if it ships.
static func _find_plinth(g: Node3D, at: Vector3, object_id: String) -> void:
	box(g, Vector3(0.6, 0.7, 0.5), at + Vector3(0, 0.35, 0), STONE)
	var path := "res://models/lake/lake-%s.glb" % object_id.replace(".", "-")
	if not ResourceLoader.exists(path):
		return
	var m := (load(path) as PackedScene).instantiate() as Node3D
	var holder := Node3D.new()
	holder.add_child(m)
	var bb := ObitelLayout.local_aabb(holder)
	var s := 0.45 / maxf(0.01, maxf(bb.size.x, bb.size.z))
	holder.scale = Vector3(s, s, s)
	m.position = -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	holder.position = at + Vector3(0, 0.7, 0)
	g.add_child(holder)


## The person of a talk: a body and a head, facing the entrance, with
## the name the hint gives (never a church title, TABOO 0.39 item 3).
## People, not statues; no halo (TABOO 0.2).
static func _person(world: Node3D, p: Dictionary) -> void:
	var npc := str(p.heart_spec.get("npc", ""))
	var g := Node3D.new()
	g.name = "Person"
	var at: Vector3 = p.heart
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.24
	cap.height = 1.5
	cap.radial_segments = 12
	cap.rings = 4
	body.mesh = cap
	body.material_override = mat(CLOTH[absi(npc.hash()) % CLOTH.size()])
	body.position = at + Vector3(0, 0.75, 0)
	g.add_child(body)
	var head := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.26
	sp.radial_segments = 12
	sp.rings = 6
	head.mesh = sp
	head.material_override = mat(Color(0.78, 0.62, 0.5))
	head.position = at + Vector3(0, 1.62, 0)
	g.add_child(head)
	world.add_child(join(g, 0.9))
	var name_label := Label3D.new()
	name_label.name = "PersonName"
	name_label.text = p.person
	name_label.font_size = 30
	name_label.pixel_size = 0.0026
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position = at + Vector3(0, 2.0, 0)
	name_label.modulate = Color(0.95, 0.9, 0.8)
	world.add_child(name_label)


## The ROV over the heart of a dive's task, lamp on: the instrument
## world (6500 K), the operator's own Mangustik.
static func _rov(world: Node3D, p: Dictionary) -> void:
	var scene := load("res://models/rov/mangustik.glb") as PackedScene
	if scene == null:
		return
	var rov := scene.instantiate() as Node3D
	rov.name = "Rov"
	rov.position = p.heart + Vector3(0, 1.2, 0)
	rov.rotation_degrees = Vector3(0, 90, 0)
	world.add_child(rov)


# --- Light ------------------------------------------------------------------------

## The light of the place's class (TABOO 0.38 item 1): a hearth lamp
## over the heart (a hanging clay lamp indoors, a lantern on a post
## outdoors), the ROV's white lamp for the instrument class, and the
## lampada beside the holy image only where the data puts one.
static func _lights(world: Node3D, p: Dictionary) -> void:
	var cls: String = p.light["class"]
	var at: Vector3 = p.heart
	var indoor: bool = p.type in ["room", "cave"]
	var reach := maxf(p.w, p.d) * 0.9
	var wet: bool = p.type == "underwater"
	if cls in ["hearth", "instrument"] and not wet:
		# Indoors the lamp hangs a little in front of the heart, so the
		# person or the page there is lit from the side the player comes
		# from; outdoors it stands on a post beside the heart, inside the
		# heart's clear ring (no thing is nearer than 0.75 m), never as a
		# pole with an arm, which reads as a gallows.
		var work: bool = cls == "instrument"
		var y: float = minf(p.h - 0.35, 2.3) if indoor else 1.5
		# Outdoors the post stands a little behind the heart's side, out
		# of the way of the player who faces the heart.
		var lamp_at := at + (Vector3(0, y, 0.6) if indoor
			else Vector3(0.6, y, -0.35))
		var g := Node3D.new()
		g.name = "Lamp"
		if indoor:
			box(g, Vector3(0.02, p.h - y, 0.02), lamp_at + Vector3(0,
				(p.h - y) / 2.0, 0), Color(0.2, 0.18, 0.16))
		else:
			box(g, Vector3(0.07, y - 0.04, 0.07), Vector3(lamp_at.x,
				(y - 0.04) / 2.0, lamp_at.z), OAK)
		world.add_child(join(g, 0.9))
		# A clay lamp for the hearth class, a brass work lamp with a white
		# glass for the instrument class (TABOO 0.38 item 1).
		var body := box(world, Vector3(0.14, 0.08, 0.12), lamp_at,
			Color(0.62, 0.5, 0.3) if work else Color(0.6, 0.36, 0.22))
		body.name = "LampBody"
		body.material_override.emission_enabled = true
		body.material_override.emission = p.colour
		body.material_override.emission_energy_multiplier = 0.8
		var light := OmniLight3D.new()
		light.name = "InstrumentLight" if work else "HearthLight"
		light.light_color = p.colour
		light.light_energy = 1.3 if indoor else (0.6 if p.light.sky == "day"
			else 1.4)
		light.omni_range = reach
		light.position = lamp_at + Vector3(0, -0.1, 0.15)
		world.add_child(light)
	elif wet:
		# Under water the only light is the ROV's lamp (6500 K), from the
		# side the operator comes from, on the heart.
		var spot := SpotLight3D.new()
		spot.name = "InstrumentLight"
		spot.light_color = LocationCore.INSTRUMENT_K
		spot.light_energy = 14.0
		spot.spot_range = 14.0
		spot.spot_angle = 45.0
		spot.position = at + Vector3(0, 2.6, 3.4)
		spot.look_at_from_position(spot.position, at + Vector3(0, 0.3, 0))
		world.add_child(spot)
	if p.lampada:
		var holy := {}
		for s in p.slots:
			if s.holy:
				holy = s
		if not holy.is_empty():
			var cup := MeshInstance3D.new()
			cup.name = "Lampada"
			var cm := CylinderMesh.new()
			cm.top_radius = 0.06
			cm.bottom_radius = 0.035
			cm.height = 0.1
			cm.radial_segments = 10
			cm.rings = 1
			cup.mesh = cm
			var glass := mat(Color(0.7, 0.1, 0.08), 0.2)
			glass.emission_enabled = true
			glass.emission = LocationCore.LAMPADA_K
			glass.emission_energy_multiplier = 0.8
			cup.material_override = glass
			var front := Vector3(0, 0, 0.14).rotated(Vector3.UP,
				deg_to_rad(holy.yaw))
			cup.position = holy.pos + Vector3(0, -0.45, 0) + front
			world.add_child(cup)
			var lamp := OmniLight3D.new()
			lamp.name = "LampadaLight"
			lamp.light_color = LocationCore.LAMPADA_K
			lamp.light_energy = 0.9
			lamp.omni_range = 4.0
			lamp.position = cup.position + front
			world.add_child(lamp)
