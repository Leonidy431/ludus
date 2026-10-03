## The twelve ready sets (TABOO 0.032): twelve per environment, every
## hour covered, the holy untouched, human fire in its class, a changing
## walk that never repeats, and a swap that waits for the hero to look
## away.
extends RefCounted


func run(t: Object) -> void:
	var env := SceneSets.load_env("evening_cell_sample")
	t._check(env.get("sets", []).size() == 12, "twelve sets in the sample")
	var hours := {}
	var holy_first: Dictionary = {}
	for s in env.get("sets", []):
		hours[s.period] = true
		t._check(s.hearth_kelvin >= 1900 and s.hearth_kelvin <= 2500,
			"set %d: human fire is 1900..2500 K (%d)" % [s.index,
				s.hearth_kelvin])
		t._check(s.instrument_kelvin == 6500, "set %d: instrument 6500 K"
			% s.index)
		t._check(absf(s.camera.roll) <= 8.0, "set %d: the horizon is level"
			% s.index)
		var icon: Dictionary = s.items.icon_board
		if holy_first.is_empty():
			holy_first = icon
		t._check(icon.pos == holy_first.pos and icon.yaw == holy_first.yaw
			and icon.scale == holy_first.scale,
			"set %d: the holy board has not moved" % s.index)
		for id in s.items:
			var r: Dictionary = s.items[id]
			t._check(absf(float(r.box[0][1]) - float(r.pos[1])) < 0.005,
				"set %d: %s rests on its support" % [s.index, id])
	t._check(hours.size() == 8, "every hour of the day has a set: %d"
		% hours.size())
	var last := -1
	var seen := {}
	for v in 48:
		var i := SceneSets.next_index("evening_cell_sample", v, 7, last)
		t._check(i != last, "visit %d does not repeat the last set" % v)
		if v < 12:
			seen[i] = true
		last = i
	t._check(seen.size() >= 11, "twelve visits meet almost every set: %d"
		% seen.size())
	t._check(SceneSets.next_index("a", 5, 1, -1)
		== SceneSets.next_index("a", 5, 1, -1), "a count and a hash only")
	var eye := Vector3.ZERO
	var fwd := Vector3(0, 0, -1)
	t._check(SceneSets.unseen(eye, fwd, Vector3(0, 0, 3)),
		"a point behind the head is unseen")
	t._check(not SceneSets.unseen(eye, fwd, Vector3(0, 0, -3)),
		"a point ahead is seen")
	var a := {"items": {"x": {"pos": [0, 0, 3]}, "y": {"pos": [0, 0, -3]}}}
	var b := {"items": {"x": {"pos": [1, 0, 3]}, "y": {"pos": [0, 0, -2]}}}
	t._check(SceneSets.swappable(a, b, eye, fwd, 0.0) == ["x"],
		"only the item out of sight changes")
	t._check(SceneSets.swappable(a, b, eye, fwd, 1.0).size() == 2,
		"in the dark everything may change")
	var src := FileAccess.get_file_as_string("res://scripts/scene_sets.gd")
	t._check(not src.contains("randf") and not src.contains("randi")
		and not src.contains("RandomNumberGenerator"),
		"no run-time randomness (TABOO 0.032 item 3)")
