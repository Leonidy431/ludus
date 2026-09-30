## The posoh hydrophone (PosohCore, docs/HLD_POSOH_HYDROPHONE_2026-09-30)
## and its model built from the operator's drawing.  Called from
## run_tests.gd; every check goes through its _check() and _near().
extends RefCounted


func run(t: Object) -> void:
	# REAL numbers, recomputed from the posoh sources' component values.
	t._near(PosohCore.nyquist_hz(), 20000.0, "Nyquist of 40 kHz sampling")
	t._check(absf(PosohCore.aa_corner_hz() - 48228.8) < 1.0,
		"anti-alias corner %.1f Hz (HYDROPHONE_V1.md: ~48 kHz)"
		% PosohCore.aa_corner_hz())
	t._check(PosohCore.aa_corner_hz() > PosohCore.nyquist_hz(),
		"the RC corner sits above Nyquist, as the author notes")
	t._check(absf(PosohCore.coupling_corner_hz() - 3.183) < 0.01,
		"AC coupling corner %.3f Hz" % PosohCore.coupling_corner_hz())
	var band := PosohCore.band()
	t._check(band.whistle_hz == [4000.0, 20000.0], "whistle band 4-20 kHz")
	t._check(not band.clicks_heard,
		"model 1 cannot record clicks up to 150 kHz")
	t._check(PosohCore.REPORT_S == 0.5, "firmware reports every 500 ms")
	t._check(PosohCore.ADC_BITS == 12, "12-bit ESP32 ADC")
	# The water: wavelength follows DiveCore's thermocline step.
	t._near(PosohCore.wavelength_m(20000.0, 10.0), 0.074, "lambda above")
	t._near(PosohCore.wavelength_m(20000.0, 60.0), 0.07175, "lambda below")
	t._check(PosohCore.wavelength_m(20000.0, 49.9)
		> PosohCore.wavelength_m(20000.0, 50.1),
		"the wave shortens as it crosses the layer")
	t._check(absf(PosohCore.ka(20000.0, 10.0) - 0.849) < 0.001,
		"ka at 20 kHz %.3f" % PosohCore.ka(20000.0, 10.0))
	for d in [1.0, 49.0, 51.0, 160.0]:
		t._check(PosohCore.omnidirectional(d), "omni at %.0f m" % d)
	t._check(absf(PosohCore.layer_reflection_db() + 36.3) < 0.1,
		"thermocline reflects %.1f dB" % PosohCore.layer_reflection_db())
	# Mount geometry from the Mangustik's assembly.
	t._check(PosohCore.SENSOR.z < PosohCore.MOUNT.z,
		"the piezo looks forward (-Z) from its mount")
	t._check(absf(PosohCore.nearest_thruster_m() - 0.3151) < 0.001,
		"nearest thruster %.4f m" % PosohCore.nearest_thruster_m())
	# Self-noise: none when stopped, louder with thrust, never random.
	t._check(PosohCore.self_noise_db(0.0) == -INF, "stopped: no self-noise")
	t._check(PosohCore.self_noise_db(0.01) == -INF, "dead zone is silence")
	var prev := -INF
	for k in 11:
		var th := 0.1 * k
		var n := PosohCore.self_noise_db(th)
		if k > 0:
			t._check(n > prev, "louder at %.1f" % th)
		prev = n
		t._check(n == PosohCore.self_noise_db(th), "same input, same noise")
	t._check(absf(PosohCore.self_noise_db(1.0) - 141.5) < 0.2,
		"full thrust at the piezo %.2f dB (ASSUMED levels)"
		% PosohCore.self_noise_db(1.0))
	# Hearing range: stopping the thrusters is what lets it hear.
	var still := PosohCore.hearing_range_m(PosohCore.REFERENCE_SL_DB, 0.0)
	var full := PosohCore.hearing_range_m(PosohCore.REFERENCE_SL_DB, 1.0)
	t._check(absf(still - 177.8) < 0.5, "still: heard to %.1f m" % still)
	t._check(full < 0.5, "full thrust: heard to %.2f m" % full)
	t._check(still > 100.0 * full, "silence hears a hundredfold farther")
	var r_prev := INF
	for k in 11:
		var r := PosohCore.hearing_range_m(PosohCore.REFERENCE_SL_DB,
			0.1 * k)
		t._check(r <= r_prev, "range shrinks with thrust at %.1f" % (0.1 * k))
		r_prev = r
	t._check(PosohCore.hearing_range_m(200.0, 0.0) == PosohCore.RANGE_MAX_M,
		"range capped")
	# The card: cyan when listening, amber when the ROV drowns the lake;
	# no points, no reward words.
	var quiet := PosohCore.card(12.0, 0.0)
	var loud := PosohCore.card(12.0, 0.8)
	t._check(quiet.title == "ГИДРОФОН" and quiet.state == "info",
		"quiet card %s" % [quiet])
	t._check(quiet.value == "слышно озеро", "quiet value")
	t._check(quiet.sub == "такой же ROV до 178 м", "quiet sub %s" % quiet.sub)
	t._check(loud.state == "warn" and loud.value.begins_with("винты +"),
		"loud card %s" % [loud])
	for c in [quiet, loud]:
		t._check(c.state in CockpitCore.STATE_COLOUR, "known state")
		for word in ["очк", "балл", "score", "xp", "благодат", "молитв",
				"свят"]:
			t._check(not (c.title + c.value + c.sub).to_lower().contains(
				word), "no '%s' on the hydrophone card" % word)
	var deep := PosohCore.reading(80.0, 0.0)
	t._check(deep.sound_speed == 1435.0 and not deep.masked,
		"below the layer: 1435 m/s, listening")
	# The model built from hydrophone_v1.scad agrees with the core.
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://models/posoh/hydrophone.json"))
	t._check(meta.lod == "proxy", "model is marked proxy")
	t._check(meta.noLoot == true, "hydrophone is not loot")
	t._check(int(meta.triangles) <= 5000, "Quest budget %d" % meta.triangles)
	t._check(meta.depth_rating_m == null, "no invented depth rating")
	t._near(float(meta.drawing_mm.tube_od) / 1000.0, PosohCore.TUBE_OD_M,
		"tube OD matches the drawing")
	t._near(float(meta.drawing_mm.tube_total_length) / 1000.0,
		PosohCore.TUBE_LEN_M, "tube length matches the drawing")
	t._near(float(meta.drawing_mm.piezo_diameter) / 1000.0,
		PosohCore.PIEZO_D_M, "piezo matches the drawing")
	t._check(absf(float(meta.size_m[2]) - PosohCore.TUBE_LEN_M) < 1e-4,
		"model length %s m" % meta.size_m[2])
	var scene := load("res://models/posoh/hydrophone.glb") as PackedScene
	t._check(scene != null, "hydrophone.glb loads")
	if scene:
		var node := scene.instantiate()
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		t._check(meshes.size() == 9, "9 drawn parts (%d)" % meshes.size())
		node.free()
	# Mounted on the body, hidden with the frame in first person.
	# During _initialize the tree does not run _ready yet, so the body is
	# built by calling it directly; it only creates child nodes.
	var body := RovBody.new()
	body._ready()
	t._check(body.hydrophone != null
		and body.hydrophone.position == PosohCore.MOUNT, "mounted")
	body.show_frame(false)
	t._check(not body.hydrophone.visible, "hidden in first person")
	body.show_frame(true)
	t._check(body.hydrophone.visible, "seen in third person")
	body.free()
