## Headless test runner: godot --headless --path godot --script
## res://tests/run_tests.gd.  Exits 0 when every check passes.
extends SceneTree

const TOL := 1e-6
var failures := 0
var checks := 0


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _near(a: float, b: float, what: String) -> void:
	_check(absf(a - b) <= TOL * maxf(1.0, absf(b)), "%s: %s != %s"
		% [what, a, b])


func _load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _initialize() -> void:
	var fx: Dictionary = _load_json("res://tests/fixture.json")
	var objects: Array = _load_json("res://data/lake-objects-99.json").objects
	var fish: Array = _load_json("res://data/issyk-kul-fish.json").fish
	# The generator: the same seed gives the same numbers as in JS.
	for sample in fx.rng:
		var r := DiveCore.rng(sample.seed)
		for v in sample.values:
			_near(r.call(), v, "rng " + sample.seed)
	for f in fx.floor:
		_near(DiveCore.base_depth(f.x), f.base, "base_depth %s" % f.x)
		_near(DiveCore.floor_depth(f.x, 12.5), f.floor, "floor %s" % f.x)
	for f in fx.xForDepth:
		_near(DiveCore.x_for_depth(f.d), f.x, "x_for_depth %s" % f.d)
	for f in fx.temperature:
		_near(DiveCore.temperature(f.d), f.t, "temperature %s" % f.d)
	var placed := DiveCore.place_objects(objects)
	_check(placed.size() == fx.placed.size(), "placed count")
	for i in mini(placed.size(), fx.placed.size()):
		var a: Dictionary = placed[i]
		var b: Dictionary = fx.placed[i]
		_check(a.id == b.id and a.where == b.where, "placed id " + b.id)
		_near(a.x, b.x, b.id + " x")
		_near(a.z, b.z, b.id + " z")
		_near(a.depth, b.depth, b.id + " depth")
		_near(a.yaw, b.yaw, b.id + " yaw")
		# The rule itself, not only parity: inside its own depth range.
		_check(a.depth >= a.depth_range[0] - 0.01
			and a.depth <= a.depth_range[1] + 0.01, b.id + " in range")
	var schools := DiveCore.fish_schools(fish)
	for i in schools.size():
		var s: Dictionary = schools[i]
		var e: Dictionary = fx.schools[i]
		_check(s.id == e.id and s.count == int(e.count), "school " + e.id)
		_near(s.centre.x, e.centre.x, e.id + " centre x")
		_near(s.centre.depth, e.centre.depth, e.id + " centre depth")
		_near(s.phase, e.phase, e.id + " phase")
	for sample in fx.fishAt:
		var s: Dictionary = schools.filter(func(q): return q.id == sample.id)[0]
		var ts := [0.0, 3.0, 17.5]
		for k in 3:
			var p := DiveCore.fish_at(s, 2, ts[k])
			_near(p.x, sample.at[k].x, sample.id + " fish x")
			_near(p.depth, sample.at[k].depth, sample.id + " fish depth")
	var rov := DiveCore.new_rov()
	for inp in fx.rov.inputs:
		rov = DiveCore.step_rov(rov, inp, 0.1)
	for key in ["x", "z", "depth", "yaw", "battery"]:
		_near(rov[key], fx.rov.final[key], "rov " + key)
	var t := DiveCore.telemetry(rov)
	_near(t.temperature, fx.rov.telemetry.temperature, "telemetry temp")
	_near(t.ascent_m_per_min, fx.rov.telemetry.ascentMPerMin, "ascent")
	_near(t.echo_delay, fx.rov.telemetry.echoDelay, "echo")
	# Loot rules: the endemic is released, the bulla is never taken.
	var chebak: Dictionary = schools.filter(func(q): return q.id == "chebak")[0]
	var res := DiveCore.loot_action(chebak, {})
	_check(res.rule == "release" and not "chebak" in res.bag.kept,
		"endemic released")
	for p in placed:
		if p.item == "bulla":
			var bres := DiveCore.loot_action(p, {})
			_check(bres.rule == null and bres.bag.kept.is_empty(),
				"bulla not taken")
	# The game scenario gives the same tasks, fall state and messages.
	var r := DiveCore.new_rov()
	r.x = 400.0
	r.depth = 70.0
	var g := DiveCore.new_game()
	var said := 0
	var plan := [[{"vertical": 1.0}, 50], [{}, 200], [{"vertical": -1.0}, 30],
		[{"vertical": 1.0}, 80], [{"vertical": -1.0}, 400]]
	for step in plan:
		for i in step[1]:
			var inp: Dictionary = step[0].duplicate()
			inp["drift"] = DiveCore.current(r.x, i * 0.1)
			r = DiveCore.step_rov(r, inp, 0.1)
			var out := DiveCore.step_game(g, r, 0.1, 0)
			g = out.game
			said += out.say.size()
	_check(g.done == fx.game.done, "game done %s vs %s" % [g.done,
		fx.game.done])
	_check(g.fallen == fx.game.fallen, "game fallen")
	_check(said == int(fx.game.said), "game messages %d vs %s" % [said,
		fx.game.said])
	_near(r.depth, fx.game.depth, "game depth")
	_near(r.z, fx.game.z, "game drift z")
	# The tether: the same turns, task and warnings as the JS core.
	var tr := DiveCore.new_rov()
	tr.depth = 4.0
	var tg := DiveCore.new_game()
	var tsaid := 0
	for leg in [[{"turn": 1.0}, 84, false], [{"turn": -1.0}, 84, false],
			[{}, 1, true], [{"turn": 1.0}, 220, false]]:
		for i in leg[1]:
			tr = DiveCore.step_rov(tr, leg[0], 0.1)
			var tout := DiveCore.step_game(tg, tr, 0.1, 0, leg[2])
			tg = tout.game
			tsaid += tout.say.size()
	var tfx: Dictionary = fx.tether
	_check(tg.done == tfx.done, "tether done %s vs %s" % [tg.done, tfx.done])
	_near(tg.turns, tfx.turns, "tether turns")
	_check(tg.wound == tfx.wound, "tether wound")
	_check(tsaid == int(tfx.said), "tether messages %d vs %s" % [tsaid,
		tfx.said])
	_near(tr.yaw, tfx.yaw, "tether yaw")
	print("dive_core: %d checks, %d failures" % [checks, failures])
	# Biomes, bubbles and the thermocline heard (HLD_DIVE_BIOMES_BUBBLES).
	var b0 := checks
	var f0 := failures
	var biomes: RefCounted = load("res://tests/test_biomes.gd").new()
	biomes.run(self)
	print("biomes: %d checks, %d failures" % [checks - b0, failures - f0])
	# Sound of the dive (scripts/audio, HLD_FOLLOWUPS D5).
	var before := checks
	var fails := failures
	load("res://tests/test_audio.gd").new().run(self)
	print("audio: %d checks, %d failures" % [checks - before,
		failures - fails])
	# The pilot's console and the Mangustik model (HLD_MANGUSTIK_COCKPIT).
	before = checks
	fails = failures
	load("res://tests/test_cockpit.gd").new().run(self)
	print("cockpit: %d checks, %d failures" % [checks - before,
		failures - fails])
	# The posoh hydrophone on the Mangustik (HLD_POSOH_HYDROPHONE).
	before = checks
	fails = failures
	load("res://tests/test_posoh.gd").new().run(self)
	print("posoh: %d checks, %d failures" % [checks - before,
		failures - fails])
	# Things of the 99 locations from the 99 repos (HLD_LOCATION_ITEMS).
	before = checks
	fails = failures
	load("res://tests/test_location_items.gd").new().run(self)
	print("location items: %d checks, %d failures" % [checks - before,
		failures - fails])
	# The real dive scene: the holy things carry no band (it enters the
	# tree with the root, after _initialize, so wait a frame).
	before = checks
	fails = failures
	var dive: Node = (load("res://scenes/dive.tscn") as PackedScene) \
		.instantiate()
	root.add_child(dive)
	await process_frame
	biomes.in_dive(dive)
	# Б-1: the dive's batches (DiveBatch).
	var dive_batch = load("res://tests/test_dive_batch.gd").new()
	dive_batch.run(self)
	dive_batch.in_dive(self, dive)
	print("dive scene: %d checks, %d failures" % [checks - before,
		failures - fails])
	quit(1 if failures else 0)
