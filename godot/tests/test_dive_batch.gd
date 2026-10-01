## The dive's batches (DiveBatch, Б-1 in docs/APK_REQUIREMENTS.md).
## Called from run_tests.gd: run() on small built things, in_dive() on
## the real dive scene once it is in the tree.
extends RefCounted

## Drawn instances under the dive root, its things and the body after
## the batches (headless: the drawings stay sprites there, since a
## dummy renderer gives no texels back).  A change that adds still
## geometry the batches cannot take shows here before the budget gate.
const BODY_INSTANCES_MAX := 20


static func _box(parent: Node3D, at: Vector3, colour: Color,
		rough := 0.95) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.4, 0.4, 0.4)
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


static func _drawn(n: Node) -> Array:
	return n.find_children("*", "GeometryInstance3D", true, false).filter(
		func(g): return not g is MeshInstance3D or g.mesh != null)


func run(t: Object) -> void:
	var rim := RimLight.new()
	# The shaders are RimLight's own with the uniforms read per vertex:
	# if RimLight's code changes shape, the batches stop, not the band.
	var base: ShaderMaterial = rim.material_for(StandardMaterial3D.new())
	var code := DiveBatch.batch_code(base.shader.code)
	t._check(code != "" and "albedo = CUSTOM0;" in code
		and "roughness = CUSTOM1.x;" in code
		and not "uniform vec4 albedo" in code
		and "instance uniform vec3 rim_c" in code
		and code.count("EMISSION = band_light * ") == 1,
		"the thing batch keeps RimLight's band and its box")
	var sprite := Sprite3D.new()
	sprite.texture = PlaceholderTexture2D.new()
	rim.drawing(sprite)
	var dcode := DiveBatch.drawing_code(
		(sprite.material_override as ShaderMaterial).shader.code)
	t._check(dcode != "" and "sampler2DArray drawing" in dcode
		and not "MODEL_MATRIX[3]" in dcode
		and dcode.count("layer_texel(layer, ") == 5,
		"the drawing batch samples the same texel of its layer")
	sprite.free()
	# A thing of three parts, two colours and two roughnesses: one
	# instance with one surface, each part's own colour and
	# roughness per vertex, the box of the whole thing for its band.
	var thing := Node3D.new()
	var reds := Color(0.8, 0.2, 0.1)
	_box(thing, Vector3(0, 0, 0), reds)
	_box(thing, Vector3(0.5, 0, 0), Color(0.1, 0.3, 0.9))
	_box(thing, Vector3(0, 0.5, 0), reds, 0.4)
	rim.dress(thing)
	var box := RimLight.box_in(Transform3D.IDENTITY,
		RimLight.thing_box(thing))
	var joined := DiveBatch.merge_thing(thing, rim, {})
	var left := _drawn(thing)
	t._check(joined == 2 and left.size() == 1, "three parts, one call: %d, %d"
		% [joined, left.size()])
	if left.size() == 1:
		var mi: MeshInstance3D = left[0]
		var arr := mi.mesh.surface_get_arrays(0)
		var alb: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
		var par: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM1]
		t._check(is_equal_approx(alb[0], reds.r)
			and is_equal_approx(alb[1], reds.g) and alb[3] == 1.0,
			"the colour is the albedo uniform's own value")
		var roughs := {}
		for i in range(0, par.size(), 4):
			roughs[snappedf(par[i], 0.001)] = true
		t._check(roughs.keys().size() == 2, "each part keeps its roughness")
		t._check(mi.get_instance_shader_parameter("rim_c") == box.c
			and mi.get_instance_shader_parameter("rim_x") == box.x,
			"the band runs on the outline of the whole thing")
		t._check(mi.has_meta(DiveBatch.META), "marked as a batch")
	# A second pass changes nothing.
	t._check(DiveBatch.merge_thing(thing, rim, {}) == 0, "idempotent")
	thing.free()
	# A holy thing is not dressed, so nothing of it can join a batch.
	var holy := Node3D.new()
	_box(holy, Vector3.ZERO, Color(0.5, 0.5, 0.5))
	_box(holy, Vector3(0.5, 0, 0), Color(0.6, 0.6, 0.6))
	rim.dress(holy, true)
	t._check(DiveBatch.merge_thing(holy, rim, {}) == 0
		and _drawn(holy).size() == 2, "a holy thing keeps its parts")
	holy.free()


## The real dive: every thing is its own node with its own batch, the
## holy things keep their parts, the arm keeps its joints, and the
## cockpit's viewports take turns.
func in_dive(t: Object, scene: Node) -> void:
	t._check(not scene.batch_off, "the dive is batched by default")
	var parents := {}
	for id in scene.thing_nodes:
		var node: Node3D = scene.thing_nodes[id]
		for g in _drawn(node):
			if g.has_meta(DiveBatch.META):
				t._check(not parents.has(g), "a batch of one thing only")
				parents[g] = id
				t._check(g.get_parent() == node,
					"%s: its batch is its own child" % id)
	for p in scene.placed + scene.traces:
		if RimLight.is_holy(p) and scene.thing_nodes.has(p.id):
			var parts: Array = _drawn(scene.thing_nodes[p.id])
			var own := not parts.is_empty()
			for g in parts:
				own = own and not g.has_meta(DiveBatch.META) \
					and not g.has_meta(StaticBatch.META)
			t._check(own, "%s is holy and is not batched" % p.id)
	var body: RovBody = scene.body
	t._check(body.arm_upper.is_inside_tree() and body.arm_fore.is_inside_tree()
		and body.fingers.size() == 2, "the arm keeps its joints")
	var n := _drawn(body).size()
	t._check(n <= BODY_INSTANCES_MAX, "the body draws %d instances (<= %d)"
		% [n, BODY_INSTANCES_MAX])
	# The arm still reaches: its joints turn with the phase.
	body.set_arm(1.0)
	var reached: float = body.arm_upper.rotation.x
	body.set_arm(0.0)
	t._check(not is_equal_approx(reached, body.arm_upper.rotation.x),
		"the arm still moves")
	var modes := []
	for v in [scene.eye_view, scene.screens_view, scene.console_view]:
		modes.append(v.render_target_update_mode)
	t._check(not SubViewport.UPDATE_ALWAYS in modes,
		"no cockpit viewport is drawn every frame: %s" % [modes])
	print("  dive batch: %s; body %d instances" % [scene.batch_stats, n])
