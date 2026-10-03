## The wrist computer on the glove (GloveComputer): its numbers come
## from the cores, it fits the cuff, it names no brand, and at the holy
## it is empty (docs/missions/rov-pilot-akula/DESIGN_ROV_PILOT_PIKE.md).
extends RefCounted


func run(t: Object) -> void:
	var before: int = t.checks
	var tx := GloveComputer.text(60.0, ["thermocline_check"])
	var r := roundi(VolumetricCore.resonant_radius_um(40.0, 0.0, 6.0))
	t._check(("%d мкм" % r) in tx, "the bubble size is Minnaert's (%d)" % r)
	t._check(r >= 75 and r <= 90, "about 82 um at 40 kHz (%d)" % r)
	var nm := GloveComputer.best_wavelength()
	t._check(nm >= 450 and nm <= 490, "the laser's best is blue-green")
	t._check(("ТЕРМОКЛИН %.0f м" % DiveCore.THERMOCLINE_M) in tx,
		"the thermocline is DiveCore's")
	t._check("ПРОЙДЕН" in tx and "[x] Сонар" in tx,
		"below the layer the thermocline task is done")
	t._check("ВПЕРЕДИ" in GloveComputer.text(20.0, []),
		"above the layer it is ahead")
	for line in tx.split("\n"):
		t._check(line.length() <= GloveComputer.WIDTH,
			"the line fits the cuff: %s" % line)
	for brand in ["PADI", "DiveCore", "voxel", "commit", "Кайрак",
			"кайрак", "OS v"]:
		t._check(not brand in tx, "no %s on the player's wrist" % brand)
	t._check(GloveComputer.text(60.0, [], true) == "",
		"at the kayrak the wrist is empty")
	print("glove computer: %d checks" % (t.checks - before))
