## The pilot's console (CockpitCore, docs/HLD_MANGUSTIK_COCKPIT M4) and
## the Mangustik model built from the operator's drawings (M2).
## Called from run_tests.gd; every check goes through its _check().
extends RefCounted


func _tel(over: Dictionary) -> Dictionary:
	var tel := {"depth": 12.0, "floor": 17.0, "temperature": 18.0,
		"pressure_bar": 2.19, "heading": 0.0, "sound_speed": 1480.0,
		"echo_delay": 0.007, "ascent_m_per_min": 0.0,
		"ascent_too_fast": false, "battery": 1.0}
	tel.merge(over, true)
	return tel


func run(t: Object) -> void:
	var bag := {"kept": [1, 2], "released": [3], "handed_over": []}
	var cards := CockpitCore.cards(_tel({}), bag)
	t._check(cards.size() == 8, "eight cards")
	var titles := []
	for c in cards:
		titles.append(c.title)
		t._check(c.state in CockpitCore.STATE_COLOUR, "state %s" % c.state)
	t._check(titles == ["ГЛУБИНА", "ВОДА", "КУРС", "СОНАР", "ВСПЛЫТИЕ",
		"ЗАРЯД", "ТРОС", "СУМКА"], "card order %s" % [titles])
	# The console counts no points: nothing like a score on any card.
	for c in cards:
		for word in ["очк", "балл", "score", "xp", "благодат"]:
			t._check(not (c.title + c.value + c.sub).to_lower().contains(
				word), "no '%s' on %s" % [word, c.title])
	t._check(cards[7].value == "2", "bag shows kept things")
	# Tether turns: calm, a warning a turn before the kink, red at it.
	for row in [[0.0, "info"], [1.5, "info"], [-2.0, "warn"],
			[3.0, "critical"], [-3.4, "critical"]]:
		t._check(CockpitCore.tether_state(row[0]) == row[1],
			"tether %.1f -> %s" % row)
	var wound := CockpitCore.cards(_tel({}), bag, 1.25)
	t._check(wound[6].value == "+1.2 об." or wound[6].value == "+1.3 об.",
		"tether card shows turns (%s)" % wound[6].value)
	t._check(CockpitCore.cards(_tel({}), bag, 0.05)[6].sub == "распутан",
		"tether card says unwound")

	# Battery: the yacht panel's fuel thresholds, 15 % and 25 %.
	for row in [[1.0, "safe"], [0.25, "safe"], [0.249, "warn"],
			[0.15, "warn"], [0.149, "critical"], [0.0, "critical"]]:
		t._check(CockpitCore.battery_state(row[0]) == row[1],
			"battery %.3f -> %s" % row)
	# Ascent: the diver's 10 m/min.
	for row in [[0.0, "safe"], [8.0, "safe"], [8.1, "warn"],
			[10.0, "warn"], [10.1, "critical"]]:
		t._check(CockpitCore.ascent_state(row[0]) == row[1],
			"ascent %.1f -> %s" % row)
	var fast := CockpitCore.cards(_tel({"ascent_m_per_min": 14.0,
		"ascent_too_fast": true}), bag)
	t._check(fast[4].state == "critical", "fast ascent is red")
	var down := CockpitCore.cards(_tel({"ascent_m_per_min": -20.0}), bag)
	t._check(down[4].value == "0.0" and down[4].state == "safe",
		"descending is not an ascent")
	var low := CockpitCore.cards(_tel({"depth": 16.6}), bag)
	t._check(low[0].state == "critical", "0.4 m over the floor is red")

	for row in [[0.0, "С"], [44.0, "СВ"], [90.0, "В"], [180.0, "Ю"],
			[270.0, "З"], [337.0, "СЗ"], [359.0, "С"], [-90.0, "З"]]:
		t._check(CockpitCore.compass_point(row[0]) == row[1],
			"compass %.0f -> %s" % row)

	# Near a holy thing the console goes out, and never in one frame.
	t._check(CockpitCore.fade_target(10.0) == 1.0, "far: full console")
	t._check(CockpitCore.fade_target(2.0) == 0.0, "near: console out")
	var mid := CockpitCore.fade_target(4.5)
	t._check(mid > 0.0 and mid < 1.0, "between: partly")
	var a := 1.0
	var seconds := 0.0
	while a > 0.0 and seconds < 10.0:
		a = CockpitCore.fade_step(a, 0.0, 1.0 / 72.0)
		seconds += 1.0 / 72.0
	t._check(seconds >= 1.5 and seconds <= 2.0,
		"fade takes %.2f s (TABOO 0.4: 1.5-2 s)" % seconds)

	# The manipulator: out, hold, back, in ARM_SECONDS; stowed outside.
	t._check(CockpitCore.arm_phase(-0.1) == 0.0, "arm stowed before")
	t._check(CockpitCore.arm_phase(0.0) == 0.0, "arm starts stowed")
	t._check(CockpitCore.arm_phase(0.6) == 1.0, "arm reached at mid")
	t._check(CockpitCore.arm_phase(0.3) > 0.0 and CockpitCore.arm_phase(
		0.3) < 1.0, "arm on its way out")
	t._check(CockpitCore.arm_phase(CockpitCore.ARM_SECONDS) == 0.0,
		"arm stowed after %.1f s" % CockpitCore.ARM_SECONDS)
	var prev := -1.0
	var monotone := true
	for i in 25:
		var p := CockpitCore.arm_phase(0.48 * i / 24.0)
		monotone = monotone and p >= prev
		prev = p
	t._check(monotone, "arm goes out without jerking back")

	# The sonar: the floor answers ahead on the slope, a thing in the
	# fan is seen, a thing behind or far above the beam is not.
	for depth in [12.0, 35.0, 60.0, 120.0]:
		var r := DiveCore.new_rov()
		r.x = DiveCore.x_for_depth(depth + 6.0) - 8.0
		r.z = 0.0
		r.depth = depth
		r.yaw = 0.0
		var scan := CockpitCore.sonar_scan(r, [])
		var hits := 0
		for f in scan.floor:
			if f > 0.0:
				hits += 1
		t._check(scan.floor.size() == CockpitCore.SONAR_BEAMS,
			"sonar beams at %d m" % depth)
		t._check(hits >= CockpitCore.SONAR_BEAMS / 2,
			"sonar finds the floor at %d m (%d beams)" % [depth, hits])
		var floor_mid: float = scan.floor[CockpitCore.SONAR_BEAMS / 2]
		t._check(floor_mid > 0.0 and floor_mid < CockpitCore.SONAR_RANGE,
			"floor ahead at %.1f m from %d m" % [floor_mid, depth])
		var ahead := {"x": r.x + 10.0, "z": 0.0,
			"depth": depth + 10.0 * tan(CockpitCore.SONAR_TILT), "size": 1.0}
		var behind := {"x": r.x - 10.0, "z": 0.0, "depth": depth}
		var above := {"x": r.x + 10.0, "z": 0.0, "depth": depth - 20.0}
		var seen := CockpitCore.sonar_scan(r, [ahead, behind, above])
		t._check(seen.echoes.size() == 1, "sonar sees only the thing "
			+ "ahead at %d m (%d echoes)" % [depth, seen.echoes.size()])
		if seen.echoes.size() == 1:
			t._check(absf(seen.echoes[0].range - 10.0) < 0.01
				and absf(seen.echoes[0].angle) < 0.01, "echo range/angle")
	# A thing to starboard shows at a positive angle.
	var rs := DiveCore.new_rov()
	rs.x = 300.0
	rs.depth = 20.0
	rs.yaw = 0.0
	var side := CockpitCore.sonar_scan(rs, [{"x": 310.0, "z": 5.0,
		"depth": 20.0 + 11.2 * tan(CockpitCore.SONAR_TILT)}])
	t._check(side.echoes.size() == 1 and side.echoes[0].angle > 0.0,
		"starboard is a positive angle")
	# The thermocline's echo: where the beam's centre crosses 50 m.
	for row in [[35.0, 25.98], [45.0, 8.66]]:
		var got := CockpitCore.thermocline_range(row[0])
		t._check(absf(got - row[1]) < 0.05,
			"thermocline from %.0f m at %.2f m" % [row[0], got])
	t._check(CockpitCore.thermocline_range(12.0) == -1.0,
		"thermocline out of range from 12 m")
	t._check(CockpitCore.thermocline_range(60.0) == -1.0,
		"no thermocline echo from below it")
	var s0 := CockpitCore.sonar_sweep(0.0)
	var s1 := CockpitCore.sonar_sweep(CockpitCore.SONAR_SWEEP)
	t._check(absf(s0 + CockpitCore.SONAR_FAN / 2.0) < 1e-6
		and absf(s1 - CockpitCore.SONAR_FAN / 2.0) < 1e-6,
		"sweep crosses the fan in %.0f s" % CockpitCore.SONAR_SWEEP)

	# The servo sounds while the arm moves and falls silent after.
	var synth := DiveSynth.new()
	synth.update({"depth": 10.0, "thrust": 0.0}, 0.1)
	synth.event_servo()
	var moving := synth.generate(int(0.2 * DiveSynth.MIX_RATE))
	var peak := 0.0
	for v in moving:
		peak = maxf(peak, absf(v))
	t._check(peak > 0.0, "servo is heard while the arm moves")
	t._check(synth.events.size() >= 1, "servo event is queued")

	# The model: the operator's ROV, within the Quest budget.
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://models/rov/mangustik.json"))
	t._check(meta.lod == "proxy", "model is marked proxy")
	t._check(int(meta.triangles) <= 20000, "triangles %d" % meta.triangles)
	t._check(absf(meta.size_m[0] - 0.838) < 0.05, "width %.3f m"
		% meta.size_m[0])
	t._check(meta.size_m[2] > 1.2 and meta.size_m[2] < 1.45,
		"length %.3f m" % meta.size_m[2])
	var scene := load("res://models/rov/mangustik.glb") as PackedScene
	t._check(scene != null, "mangustik.glb loads")
