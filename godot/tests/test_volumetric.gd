## VolumetricCore against the Python numbers of the operator's repo
## (fixture from scripts/godot/make_volumetric_fixture.py), the physics
## of bubbles and laser, the data file's lines and the holy silence.
## Called from run_hub_tests.gd.
extends RefCounted

const FIXTURE := "res://tests/fixtures/volumetric_fixture.json"


func run(t: Object) -> void:
	var fx = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	t._check(fx is Dictionary, "volumetric fixture loads")
	if not fx is Dictionary:
		return
	for pair in fx.temperature:
		t._check(VolumetricCore.rgb_for("temperature", pair[0])
			== _ints(pair[1]), "temperature %s -> %s" % [pair[0], pair[1]])
	for pair in fx.oxygen:
		t._check(VolumetricCore.rgb_for("dissolved_oxygen", pair[0])
			== _ints(pair[1]), "oxygen %s -> %s" % [pair[0], pair[1]])
	var c := VolumetricCore.color_for("temperature", 0.0)
	t._check(c.is_equal_approx(Color(30 / 255.0, 60 / 255.0, 220 / 255.0)),
		"cold is blue")

	var col: Dictionary = fx.column
	var readings := []
	for l in col.layers:
		readings.append({"h": l[0], "temperature": l[1]})
	var frame := VolumetricCore.water_column_frame(readings, "temperature")
	t._check(frame.size() == int(col.count),
		"column voxel count %d == %d" % [frame.size(), col.count])
	t._check(_flat(frame[0]) == _ints(col.first), "first voxel as Python")
	t._check(_flat(frame[-1]) == _ints(col.last), "last voxel as Python")
	var sums := [0, 0, 0]
	var zs := {}
	for v in frame:
		sums[0] += v.x
		sums[1] += v.y
		sums[2] += v.z
		zs[v.z] = v.rgb
	t._check(sums == _ints(col.sum_xyz), "column coordinate sums as Python")
	for k in col.rgb_per_z:
		t._check(zs.get(int(k), []) == _ints(col.rgb_per_z[k]),
			"layer z=%s colour as Python" % k)

	var cl: Dictionary = fx.cloud
	var cv := VolumetricCore.point_cloud_frame(cl.points)
	t._check(cv.size() == cl.voxels.size(), "cloud size")
	for i in cv.size():
		t._check(_flat(cv[i]) == _ints(cl.voxels[i]),
			"cloud voxel %d as Python" % i)

	for pair in fx.tension:
		t._check(is_equal_approx(VolumetricCore.surface_tension(pair[0]),
			pair[1]), "tension at %s PSU" % pair[0])
	t._check(is_equal_approx(VolumetricCore.surface_tension(0.0), 0.0728)
		and is_equal_approx(VolumetricCore.surface_tension(35.0), 0.0679),
		"tension ends 0.0728 and 0.0679")
	for m in fx.minnaert:
		var r := VolumetricCore.resonant_radius_um(m[0], m[1], m[2])
		t._check(absf(r - m[3]) < 1e-6 * m[3],
			"Minnaert %s kHz %s m %s PSU = %.3f um" % [m[0], m[1], m[2], r])
	var r40 := VolumetricCore.resonant_radius_um(40.0, 0.0, 6.0)
	t._check(r40 > 75.0 and r40 < 90.0, "40 kHz bubble ~80 um (%.1f)" % r40)
	t._check(VolumetricCore.resonant_radius_um(40.0, 50.0, 6.0) > r40,
		"deeper water, larger resonant bubble at a fixed frequency")

	var blue := VolumetricCore.laser_transmission(470.0, 10.0, 2.0)
	var red := VolumetricCore.laser_transmission(630.0, 10.0, 2.0)
	t._check(blue > red * 2.0, "blue beam outlives red at 10 m")
	t._check(VolumetricCore.laser_transmission(470.0, 0.0, 5.0) == 1.0,
		"no distance, no loss")
	t._check(VolumetricCore.laser_transmission(470.0, 10.0, 8.0) < blue,
		"turbid water dims the beam")
	var best := 400.0
	var best_t := 0.0
	for nm in range(400, 701, 10):
		var tr := VolumetricCore.laser_transmission(nm, 20.0, 1.0)
		if tr > best_t:
			best_t = tr
			best = nm
	t._check(VolumetricCore.is_optimal_wavelength(best),
		"best wavelength %d nm is inside 450-490" % int(best))

	var lake := VolumetricCore.lake_column(100.0)
	t._check(lake.size() == 12 and lake[0].h == 0.0 and lake[-1].h == 1.0,
		"lake column is bottom to top")
	t._check(absf(lake[0].temperature - DiveCore.temperature(100.0)) < 1e-9
		and lake[0].temperature < lake[-1].temperature,
		"lake: cold below, warm above, DiveCore's profile")
	t._check(VolumetricCore.lake_column(100.0) == lake,
		"lake column is deterministic")
	var lf := VolumetricCore.water_column_frame(lake, "temperature")
	t._check(lf.size() == 12 * 625, "12 sparse layers of 625 voxels")

	var d := VolumetricCore.load_data()
	var pilot := PilotCore.load_data()
	var ids := {}
	for b in pilot.beats:
		ids[b.id] = true
	t._check(bool(d.holy_silent), "data: holy_silent")
	t._check(d.modes.size() == 3 and d.grid.sparse_step == 4,
		"data: three modes, sparse step 4")
	for n in d.narrator:
		t._check(n.line_ru.length() <= 140 and ids.has(n.bridge_to)
			and n.has("why"), "narrator %s: <=140 and bridge %s exists"
			% [n.mode, n.bridge_to])
		t._check(not n.line_ru.contains(" я ") and not n.line_ru.contains(" ты "),
			"narrator %s in the third person" % n.mode)
	for n in d.claude:
		t._check(n.line_ru.length() <= 120, "Claude line %s <=120" % n.mode)
	for m in d.modes:
		t._check(VolumetricCore.narrator_line(d, m.id, "thermocline") != ""
			and VolumetricCore.narrator_line(d, m.id, "khachkar") == ""
			and VolumetricCore.claude_line(d, m.id, "khachkar") == "",
			"mode %s: lines away from the holy, silence at the khachkar"
			% m.id)


func _ints(a: Array) -> Array:
	var out := []
	for x in a:
		out.append(int(x))
	return out


func _flat(v: Dictionary) -> Array:
	return [v.x, v.y, v.z] + v.rgb
