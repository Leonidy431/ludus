## The operator's apparatus (ApparatusCore, ScreenFeed, TABOO 0.022): the
## inventory keeps its rules; every kind of video draws something; the
## magnetometer rises near iron and not near silver; the pilot shows the
## beat's instruments on the robot and at the surface and nothing at the
## khachkar.  Called from run_hub_tests.gd.
extends RefCounted


func _lit(img: Image) -> int:
	var n := 0
	for y in range(0, ScreenFeed.H, 2):
		for x in range(0, ScreenFeed.W, 2):
			if img.get_pixel(x, y) != ScreenFeed.BG:
				n += 1
	return n


func run(t: Object) -> void:
	var d := ApparatusCore.load_data()
	var pilot := PilotCore.load_data()
	t._check(not d.is_empty(), "apparatus loads")
	var bad := ApparatusCore.check(d, pilot)
	t._check(bad.is_empty(), "the apparatus keeps its rules: %s" % [bad])
	var robot := 0
	var surface := 0
	for i in d.items:
		if i.where == "robot":
			robot += 1
		else:
			surface += 1
	t._check(robot > 0 and surface > 0,
		"instruments on the robot (%d) and at the surface (%d)"
		% [robot, surface])
	t._check(ApparatusCore.for_beat(d, "khachkar", "robot").is_empty()
		and ApparatusCore.for_beat(d, "khachkar", "surface").is_empty(),
		"nothing on a screen at the khachkar")
	t._check(not ApparatusCore.screen_of(d, "walls", "robot").is_empty(),
		"the walls beat has a robot screen")

	var img := ScreenFeed.blank()
	ScreenFeed.sonar(img, [3.0, 5.0, 8.0, 99.0], 12.0, 0.4)
	t._check(_lit(img) > 20, "the sonar draws")
	img = ScreenFeed.blank()
	ScreenFeed.curve(img, [55000.0, 55100.0, 55300.0], 54950.0, 55450.0,
		55150.0)
	t._check(_lit(img) > 5, "the curve draws")
	img = ScreenFeed.blank()
	ScreenFeed.spectrogram(img, [[0.5, 0.2], [0.1, 0.9]])
	t._check(_lit(img) > 10, "the spectrogram draws")
	img = ScreenFeed.blank()
	ScreenFeed.range_bar(img, 4.0, 12.0)
	t._check(_lit(img) > 10, "the range bar draws")
	img = ScreenFeed.blank()
	ScreenFeed.camera_overlay(img, Vector2(0.5, 0.5))
	t._check(_lit(img) > 10, "the camera overlay draws")
	img = ScreenFeed.blank()
	ScreenFeed.map(img, [Vector2(0, 0), Vector2(1, 1)], 8.0)
	t._check(_lit(img) > 10, "the map draws")
	var a := ScreenFeed.blank()
	var b := ScreenFeed.blank()
	ScreenFeed.sonar(a, [4.0, 6.0], 12.0, 0.3)
	ScreenFeed.sonar(b, [4.0, 6.0], 12.0, 0.3)
	t._check(a.get_data() == b.get_data(), "the same telemetry, the same frame")

	var iron := [{"at": Vector3(0, 0, -2), "moment": 1600.0}]
	var near := ScreenFeed.field_nt(Vector3(0, 0, -1), iron)
	var far := ScreenFeed.field_nt(Vector3(0, 0, 8), iron)
	t._check(near - far > 100.0,
		"the magnetometer rises near iron (%.0f vs %.0f nT)" % [near, far])
	t._check(absf(ScreenFeed.field_nt(Vector3.ZERO, []) - 55000.0) < 0.01,
		"silver alone leaves the field as the Earth's")
	_scene(t)


func _scene(t: Object) -> void:
	var p: Node = (load("res://scenes/pilot.tscn") as PackedScene) \
		.instantiate()
	p.replay = true
	p.stay = true
	p.save_path = "user://pilot_test_apparatus.json"
	t.root.add_child(p)
	if p.data.is_empty():
		p._ready()
	# No insight may pause the clock in this walk.
	for x in p.insights.insights:
		p.shown.append(str(x.id))
	var guard := 0
	while p.t < 150.0 and guard < 4000:
		guard += 1
		p._process(0.1)
	t._check(p.beat_id == "walls", "the walk reaches the walls")
	t._check(p.panels.robot.quad.visible and not p.panels.robot.item.is_empty(),
		"at the walls the robot's screen shows %s"
		% [p.panels.robot.item.get("id", "")])
	while p.t < 650.0 and guard < 12000:
		guard += 1
		p._process(0.1)
	t._check(p.beat_id == "khachkar", "the walk reaches the khachkar")
	t._check(not p.panels.robot.quad.visible
		and not p.panels.surface.quad.visible,
		"at the khachkar both screens are dark")
	p.queue_free()
