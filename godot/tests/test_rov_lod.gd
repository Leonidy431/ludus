## The Mangustik's far-view proxy and its switch by distance (RovLod,
## blocker Б-2 in docs/APK_REQUIREMENTS.md).  Called from run_tests.gd.
## The renderer's own choice is shown under Xvfb by
## tools/rov_lod_shots.gd; here the ranges that make it are checked.
extends RefCounted

const LIMIT := 5000


func _meta(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func run(t: Object) -> void:
	var full_meta := _meta("res://models/rov/mangustik.json")
	var lod_meta := _meta("res://models/rov/mangustik-lod1.json")
	t._check(lod_meta.lod == "proxy" and int(lod_meta.lod_level) == 1
		and lod_meta.lod_of == "mangustik", "lod1 meta names its model")
	t._check(int(lod_meta.triangles) <= LIMIT,
		"proxy %d triangles <= %d" % [lod_meta.triangles, LIMIT])
	t._check(lod_meta.noLoot == full_meta.noLoot
		and lod_meta.noInteract == full_meta.noInteract,
		"proxy keeps the model's flags")
	for i in 3:
		t._check(absf(float(lod_meta.size_m[i]) - float(full_meta.size_m[i]))
			< 0.01, "proxy size %d matches the model" % i)
	# The same parts in the same places and colours as the full model.
	t._check(lod_meta.parts.size() == full_meta.parts.size(),
		"proxy has every part")
	for i in mini(lod_meta.parts.size(), full_meta.parts.size()):
		var a: Dictionary = lod_meta.parts[i]
		var b: Dictionary = full_meta.parts[i]
		t._check(a.part == b.part and a.colour == b.colour
			and a.translate_mm == b.translate_mm, "part %s kept" % b.part)

	var rov := RovLod.build()
	t.root.add_child(rov)
	var full := rov.get_node_or_null("Full") as Node3D
	var proxy := rov.get_node_or_null("Proxy") as Node3D
	t._check(full != null and proxy != null, "both models are present")
	if full == null or proxy == null:
		rov.free()
		return
	t._check(RovLod.triangles(proxy) == int(lod_meta.triangles),
		"proxy mesh %d = meta" % RovLod.triangles(proxy))
	t._check(RovLod.triangles(full) == int(full_meta.triangles),
		"full mesh %d = meta" % RovLod.triangles(full))
	var pg := RovLod.geometry(proxy)
	t._check(pg.size() == 1, "proxy is one mesh (one draw call)")
	for g in pg:
		t._check(is_equal_approx(g.visibility_range_begin, RovLod.NEAR_M)
			and g.visibility_range_end == 0.0,
			"proxy draws from %.1f m outwards" % RovLod.NEAR_M)
		t._check(g.visibility_range_fade_mode
			== GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED,
			"no cross-fade: never both at once")
		var m := g.material_override as StandardMaterial3D
		t._check(m != null and m.vertex_color_use_as_albedo
			and is_equal_approx(m.metallic, 0.2)
			and is_equal_approx(m.roughness, 0.55),
			"proxy has the model's paint, colours from its vertices")
		var cols = (g as MeshInstance3D).mesh.surface_get_arrays(0)[
			Mesh.ARRAY_COLOR]
		t._check(cols != null and cols.size() > 0, "proxy has colours")
	# The full model hangs on the proxy: drawn only while the proxy is
	# hidden for being nearer than its begin.
	var parent := full.get_node_or_null(full.visibility_parent)
	t._check(parent != null and parent == pg[0],
		"full model's visibility parent is the proxy")
	var own := 0
	for g in RovLod.geometry(full):
		if g.visibility_range_begin != 0.0 or g.visibility_range_end != 0.0:
			own += 1
	t._check(own == 0, "full model's parts switch together (%d own)" % own)

	# Which one the views see.
	t._check(RovLod.shown_at(0.5) == "full", "full at 0.5 m")
	t._check(RovLod.shown_at(RovLod.NEAR_M - 0.01) == "full",
		"full just inside the switch")
	t._check(RovLod.shown_at(RovLod.NEAR_M + 0.01) == "proxy",
		"proxy just outside the switch")
	var centre: Vector3 = pg[0].get_aabb().get_center()
	# The dive's chase camera (dive.gd CHASE, in the body's frame).
	var chase: float = (Vector3(0.45, 0.85, 2.6) - centre).length()
	t._check(RovLod.shown_at(chase) == "proxy",
		"dive chase camera %.2f m: proxy" % chase)
	# The hub's pier view (hub.gd shots "pier": eye 1.6 m over (5.5,
	# 0, 0.6)); the vehicle at (8.4, 1, 0) turned -90 degrees.
	var on_pier := Transform3D(Basis.from_euler(Vector3(0, -PI / 2.0, 0)),
		Vector3(8.4, 1.0, 0)) * centre
	var pier: float = Vector3(5.5, 1.6, 0.6).distance_to(on_pier)
	t._check(RovLod.shown_at(pier) == "proxy",
		"hub pier view %.2f m: proxy" % pier)
	t._check(RovLod.shown_at(1.2) == "full",
		"at arm's length on the pier: the full model")

	# The batcher leaves the switch alone (StaticBatch skips a subtree
	# with a visibility parent).
	var yard := Node3D.new()
	t.root.add_child(yard)
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	yard.add_child(box)
	var rov2 := RovLod.build()
	yard.add_child(rov2)
	var before := RovLod.geometry(rov2.get_node("Full")).size()
	StaticBatch.merge(yard)
	var full2 := rov2.get_node_or_null("Full")
	t._check(full2 != null
		and RovLod.geometry(full2).size() == before
		and not full2.visibility_parent.is_empty(),
		"static batch keeps the full model and its switch")
	yard.free()

	# The ROV body in the dive uses the switch; first person hides both.
	var body := RovBody.new()
	t.root.add_child(body)
	# The runner calls this from _initialize, before the tree's first
	# frame, so the body is made ready by hand.
	if body.model == null:
		body._ready()
	t._check(body.model != null, "dive body has its model")
	if body.model == null:
		body.free()
		rov.free()
		return
	t._check(body.model.get_node_or_null("Full") != null
		and body.model.get_node_or_null("Proxy") != null,
		"dive body carries both models")
	body.show_frame(false)
	t._check(not body.model.visible, "first person hides both models")
	body.show_frame(true)
	t._check(body.model.visible, "third person shows the vehicle")
	body.free()
	rov.free()
