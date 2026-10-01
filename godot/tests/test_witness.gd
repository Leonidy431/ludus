## The path of the witness (docs/HLD_APK_PRIORITY A3): the data of the
## seven scene kits keep every promise of TABOO 0.26 point 10, and no
## walk can cross a witness line.  Called from run_hub_tests.gd.
extends RefCounted


func run(t: Object) -> void:
	var witness_z := {}
	for id in WitnessCore.ORDER:
		var scene := load("res://models/scene/sacrament-%s.glb" % id) \
			as PackedScene
		t._check(scene != null, "kit %s loads" % id)
		if scene == null:
			continue
		var kit := scene.instantiate() as Node3D
		for c in kit.find_children("*", "Node3D", true, false):
			if String(c.name).to_lower().contains("witness"):
				witness_z[id] = (c as Node3D).position.z
		kit.free()
	# Six kits carry a witness line; the ordination memory has none
	# (docs/SACRAMENTS_VR_SCENES.md, D-9).
	t._check(witness_z.size() == 6 and not "ordination" in witness_z,
		"witness lines: %s" % [witness_z.keys()])
	var bays := WitnessCore.bays(witness_z)
	t._check(bays.size() == 7, "seven kits on the path")
	for b in bays:
		var m: Dictionary = b.meta
		t._check(m.microphone == false and m.speechRecognition == false,
			"%s: no microphone" % b.id)
		t._check(m.logPresence == false, "%s: presence not logged" % b.id)
		t._check(m.reward == null and m.attributes == null
			and m.gate == null, "%s: no reward, attribute or gate" % b.id)
		t._check(m.audio.digitalZero == false, "%s: no digital zero" % b.id)
		for word in ["таинств", "благодат", "святой", "спасени"]:
			t._check(not String(m.title).to_lower().contains(word),
				"%s: title '%s' has no '%s'" % [b.id, m.title, word])
		# The kit stands so that its line lies on the path's edge.
		t._check(absf(absf(b.z) - b.witness_z - WitnessCore.PATH_HALF)
			< 1e-6, "%s: line on the path's edge" % b.id)
	# Walk hard towards every kit, from everywhere on the path: the
	# distance to the line never goes below zero.
	var worst := INF
	for b in bays:
		for dx in [-6.0, -3.0, 0.0, 3.0, 6.0]:
			var p := Vector3(b.x + dx, 0, 0)
			for i in 400:
				p = WitnessCore.clamp_walk(p + Vector3(0.01, 0,
					b.side * 0.05), bays.size())
			worst = minf(worst, WitnessCore.to_line(p, b))
	t._check(worst >= 0.0, "no walk crosses a witness line (%.3f)" % worst)
	var far := WitnessCore.clamp_walk(Vector3(9999, 0, 0), bays.size())
	t._check(far.x == WitnessCore.path_end(bays.size()), "path has an end")
	# The room's own tone: about -48 dBFS, never digital zero, and the
	# same from the same seed.
	var st := {"seed": 7, "lp": 0.0}
	var block := WitnessCore.room_tone(22050, st)
	var level := WitnessCore.rms_dbfs(block)
	t._check(absf(level - WitnessCore.ROOM_TONE_DBFS) < 2.0,
		"room tone %.1f dBFS" % level)
	var again := WitnessCore.room_tone(22050, {"seed": 7, "lp": 0.0})
	t._check(block == again, "room tone is deterministic")
	var next := WitnessCore.room_tone(256, st)
	t._check(absf(next[0] - block[block.size() - 1]) < 0.01,
		"blocks join without a click")
	_batched_kits(t)
	_batched_path(t)


## Every kit batched on its own: the merged parts are not holy and are
## drawn where they stood, in their own colours and glows; holy objects
## keep their nodes, materials and flags (docs/APK_REQUIREMENTS.md, Б-1).
func _batched_kits(t: Object) -> void:
	var shown_before := 0
	var shown_after := 0
	for id in WitnessCore.ORDER:
		var holy: Array = WitnessCore.load_meta(id).get("holyObjects", [])
		var kit := (load("res://models/scene/sacrament-%s.glb" % id)
			as PackedScene).instantiate() as Node3D
		var keep := {}
		for c in kit.find_children("*", "MeshInstance3D", true, false):
			shown_before += int(c.visible)
			if WitnessBatch.is_holy(c, holy):
				keep[c] = c.get_active_material(0)
		var batches := WitnessBatch.batch_kit(kit, holy)
		t._check(not batches.is_empty(), "%s: something is batched" % id)
		for h in keep:
			var ex: Dictionary = h.get_meta("extras", {})
			t._check(h.visible and h.get_active_material(0) == keep[h]
				and not h.has_meta("drawn_by") and ex.get("noInteract")
				and ex.get("noLoot"), "%s: holy %s keeps its node, material "
				% [id, h.name] + "and flags")
		for b in batches:
			_check_batch(t, id, kit, b as MeshInstance3D, holy)
		for c in kit.find_children("*", "MeshInstance3D", true, false):
			shown_after += int(c.visible)
		# Batching twice gives the same batches: the result depends on the
		# kit alone.
		var again := (load("res://models/scene/sacrament-%s.glb" % id)
			as PackedScene).instantiate() as Node3D
		var second := WitnessBatch.batch_kit(again, holy)
		var same := second.size() == batches.size()
		for i in mini(second.size(), batches.size()):
			same = same and second[i].get_meta("extras").parts \
				== batches[i].get_meta("extras").parts
		t._check(same, "%s: batching is deterministic" % id)
		again.free()
		kit.free()
	t._check(shown_after < shown_before, "kits draw %d meshes, not %d"
		% [shown_after, shown_before])


func _check_batch(t: Object, id: String, kit: Node3D, b: MeshInstance3D,
		holy: Array) -> void:
	var ex: Dictionary = b.get_meta("extras")
	t._check(ex.noInteract and ex.noLoot, "%s: %s is not touched or taken"
		% [id, b.name])
	var arr := b.mesh.surface_get_arrays(0)
	var bv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bc: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var mat := b.mesh.surface_get_material(0) as BaseMaterial3D
	var img: Image = null
	if mat.emission_texture != null:
		img = mat.emission_texture.get_image()
	var bu = arr[Mesh.ARRAY_TEX_UV]
	var base := 0
	var worst := 0.0
	var colours_ok := true
	var glows_ok := true
	for pname in ex.parts:
		var part: MeshInstance3D = null
		for c in kit.find_children(pname, "MeshInstance3D", true, false):
			if c.get_meta("drawn_by", "") == b.name:
				part = c
		t._check(part != null and not part.visible
			and not WitnessBatch.is_holy(part, holy),
			"%s: %s draws %s, hidden and not holy" % [id, b.name, pname])
		if part == null:
			return
		var xf := Transform3D.IDENTITY
		var n: Node = part
		while n != kit:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var pv: PackedVector3Array = part.mesh.surface_get_arrays(0)[
			Mesh.ARRAY_VERTEX]
		var pm := part.get_active_material(0) as BaseMaterial3D
		for i in pv.size():
			worst = maxf(worst, (xf * pv[i]).distance_to(bv[base + i]))
			colours_ok = colours_ok and _near(bc[base + i], pm.albedo_color)
			var glow := Color(0, 0, 0)
			if img != null:
				var x := int((bu[base + i] as Vector2).x * img.get_width())
				glow = img.get_pixel(x, 0) * mat.emission_energy_multiplier
			var want := Color(0, 0, 0)
			if pm.emission_enabled:
				want = pm.emission * pm.emission_energy_multiplier
			glows_ok = glows_ok and _near(glow, want)
		base += pv.size()
	t._check(base == bv.size(), "%s: %s holds only its parts" % [id, b.name])
	t._check(worst < 1e-4, "%s: %s parts stand where they stood (%.6f m)"
		% [id, b.name, worst])
	t._check(colours_ok, "%s: %s keeps each part's colour" % [id, b.name])
	t._check(glows_ok, "%s: %s keeps each part's glow" % [id, b.name])


## Two colours equal to within one step of an 8-bit channel.
func _near(a: Color, b: Color) -> bool:
	var step := 1.01 / 255.0
	return absf(a.r - b.r) <= step and absf(a.g - b.g) <= step \
		and absf(a.b - b.b) <= step


## The whole path as it is built: no batch is lit by more lights than
## the renderer gives one object, and everything the path can ever show
## at once (every kit, plaque and the sheet) stays within the frame's
## draw calls, whatever the headset's field of view.
func _batched_path(t: Object) -> void:
	# The tests run before the tree does, so the path is built by the
	# scene's own builders, outside the tree, and every place is taken in
	# the scene's frame.
	var scene := (load("res://scenes/witness.tscn") as PackedScene) \
		.instantiate()
	scene._build_world()
	scene._build_bays()
	var limit := int(ProjectSettings.get_setting(
		"rendering/limits/opengl/max_lights_per_object", 8))
	var lights := scene.find_children("*", "OmniLight3D", true, false)
	var batches := scene.find_children("batch-*", "MeshInstance3D", true,
		false)
	t._check(batches.size() == WitnessCore.ORDER.size(),
		"every kit has its batch (%d)" % batches.size())
	for b in batches:
		var mi := b as MeshInstance3D
		var box: AABB = WitnessBatch.relative(mi, scene) * mi.get_aabb()
		var lit := 0
		for l in lights:
			var o := l as OmniLight3D
			var p := WitnessBatch.relative(o, scene).origin
			var near := p.clamp(box.position, box.end)
			lit += int(near.distance_to(p) < o.omni_range)
		t._check(lit <= limit, "%s/%s is lit by %d lights (at most %d)"
			% [b.get_parent().name, b.name, lit, limit])
	var draws := 0
	for g in scene.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		# The sheet shows itself when the walker comes near.
		if not WitnessBatch.shown(gi, scene) \
				and not gi.get_parent() is ConfessionSheet:
			continue
		if gi is Label3D:
			# The outline is a second surface, drawn in its own call.
			draws += 2 if (gi as Label3D).outline_size > 0 else 1
		elif gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			draws += (gi as MeshInstance3D).mesh.get_surface_count()
	var budget := _frame_budget()
	t._check(budget > 0 and draws <= budget,
		"the whole path at once: %d draw calls, budget %d" % [draws, budget])
	print("witness: the whole path at once draws %d calls" % draws)
	scene.free()


## scene.draw_calls_frame.limit of scripts/godot/apk-budgets.json.
func _frame_budget() -> int:
	var path := ProjectSettings.globalize_path("res://").path_join(
		"../scripts/godot/apk-budgets.json").simplify_path()
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return 0
	return int(data.get("scene", {}).get("draw_calls_frame", {}).get(
		"limit", 0))
