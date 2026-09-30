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
	t._check(cards.size() == 7, "seven cards")
	var titles := []
	for c in cards:
		titles.append(c.title)
		t._check(c.state in CockpitCore.STATE_COLOUR, "state %s" % c.state)
	t._check(titles == ["ГЛУБИНА", "ВОДА", "КУРС", "СОНАР", "ВСПЛЫТИЕ",
		"ЗАРЯД", "СУМКА"], "card order %s" % [titles])
	# The console counts no points: nothing like a score on any card.
	for c in cards:
		for word in ["очк", "балл", "score", "xp", "благодат"]:
			t._check(not (c.title + c.value + c.sub).to_lower().contains(
				word), "no '%s' on %s" % [word, c.title])
	t._check(cards[6].value == "2", "bag shows kept things")

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
