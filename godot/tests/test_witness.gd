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
