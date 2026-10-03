## Claud, the companion (CompanionCore,
## docs/HLD_COMPANION_CLAUD_2026-10-03.md, CLAUDE.md TABOO 0.026):
## the lines of episode 1 keep the rules of the machine; at the khachkar
## it is silent whatever the data say; its numbers are the numbers of
## DiveCore; it never prays and never chooses for the hero; the hint
## ladder climbs image -> direction -> direct; the same beat gives the
## same line.  Called from run_hub_tests.gd.
extends RefCounted


func _break(d: Dictionary, beat: String, event: String, key: String,
		value: Variant) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	for x in c.lines:
		if x.beat == beat and x.event == event:
			if value == null:
				x.erase(key)
			else:
				x[key] = value
	return c


func _says(bad: Array, part: String) -> bool:
	for b in bad:
		if part in str(b):
			return true
	return false


func run(t: Object) -> void:
	var d := CompanionCore.load_data()
	var pilot := PilotCore.load_data()
	t._check(not d.is_empty(), "companion lines load")
	var bad := CompanionCore.check(d, pilot)
	t._check(bad.is_empty(), "Claud keeps the rules: %s" % [bad])
	var n: int = d.lines.size()
	t._check(n >= 30 and n <= 45, "30..45 lines in episode 1 (%d)" % n)
	t._check(d.draft_voice == true, "the voice is marked draft")

	# Silent at the holy, whatever the data hold.
	t._check(CompanionCore.line_for("khachkar", "enter", "ru", d) == "",
		"silent at the khachkar")
	var loud := _break(d, "khachkar", "enter", "ru", "Кайрак, тип камня.")
	t._check(CompanionCore.line_for("khachkar", "enter", "ru", loud) == "",
		"silent at the khachkar even if a line slips in")
	t._check(_says(CompanionCore.check(loud, pilot), "speaks at the holy"),
		"check catches a line at the holy")

	# The lines answer their beats, in both languages.
	t._check(CompanionCore.line_for("ascent", "enter", "ru", d)
		.begins_with("Всплываем"), "the ascent line in Russian")
	t._check(CompanionCore.line_for("ascent", "enter", "en", d)
		.begins_with("Ascending"), "the ascent line in English")
	t._check(CompanionCore.line_for("ascent", "enter", "de", d)
		.begins_with("Ascending"), "a language without lines falls to en")
	t._check(CompanionCore.line_for("walls", "no_such", "ru", d) == "",
		"no event, no line")
	t._check(CompanionCore.line_for("ascent", "enter", "ru", d)
		== CompanionCore.line_for("ascent", "enter", "ru", d),
		"the same beat gives the same line")
	t._check("тип не определён" in CompanionCore.line_for("diary",
		"line:holy", "ru", d).to_lower(),
		"before a holy line the machine answers 'type undefined'")

	# The hint ladder: three different rungs on each hint beat.
	for beat in d.hint_beats:
		var a := CompanionCore.hint(beat, 1, "ru", d)
		var b := CompanionCore.hint(beat, 2, "ru", d)
		var c := CompanionCore.hint(beat, 3, "ru", d)
		t._check(a != "" and b != "" and c != "" and a != b and b != c,
			"%s climbs image -> direction -> direct" % beat)
		t._check(CompanionCore.hint(beat, 9, "ru", d) == c,
			"%s: past the top rung it stays direct" % beat)

	# Every rule catches its breach.
	var long := _break(d, "walls", "enter", "ru", "Сонар. ".repeat(20))
	t._check(_says(CompanionCore.check(long, pilot), "chars"),
		"check catches a line over 120 chars")
	var lost := _break(d, "walls", "enter", "beat", "no_such_beat")
	t._check(_says(CompanionCore.check(lost, pilot), "unknown beat"),
		"check catches an unknown beat")
	var mute := _break(d, "walls", "enter", "en", null)
	t._check(_says(CompanionCore.check(mute, pilot), "missing en"),
		"check catches a missing en")
	var wrong := _break(d, "thermocline", "depth:50", "facts",
		[{"k": "thermocline_m", "v": 45}, {"k": "c_below", "v": 1435},
			{"k": "c_above", "v": 1480}])
	t._check(_says(CompanionCore.check(wrong, pilot), "thermocline_m"),
		"check catches a thermocline that is not DiveCore's")
	var fast := _break(d, "ascent", "enter", "facts",
		[{"k": "max_ascent", "v": 10}, {"k": "depth", "v": 52},
			{"k": "ascent_min", "from": 52, "v": 3}])
	t._check(_says(CompanionCore.check(fast, pilot), "faster than"),
		"check catches a climb faster than 10 m/min")
	var loose := _break(d, "walls", "enter", "ru",
		"Сонар рисует 7 прямых линий.")
	t._check(_says(CompanionCore.check(loose, pilot), "no fact"),
		"check catches a number with no fact")
	var warm := _break(d, "immersion", "enter", "facts",
		[{"k": "depth", "v": 38}, {"k": "temp_c", "at": 38, "v": 9},
			{"k": "pressure_bar", "at": 38, "v": 4.7}])
	t._check(_says(CompanionCore.check(warm, pilot), "degC"),
		"check catches a temperature that is not the lake's")
	var pray := _break(d, "walls", "enter", "ru", "Помолимся, господи.")
	t._check(_says(CompanionCore.check(pray, pilot), "must not"),
		"check catches the machine praying")
	var boss := _break(d, "lure", "enter", "en", "Take it. Nobody knows.")
	t._check(_says(CompanionCore.check(boss, pilot), "must not"),
		"check catches the machine choosing for the hero")
	var real := _break(d, "walls", "enter", "draft_voice", false)
	t._check(_says(CompanionCore.check(real, pilot), "draft"),
		"check catches a voice not marked draft")

	# The physics of the lines is DiveCore's.
	t._check(is_equal_approx(DiveCore.THERMOCLINE_M, 50.0)
		and is_equal_approx(DiveCore.MAX_ASCENT_M_PER_MIN, 10.0),
		"the companion speaks DiveCore's layer and limit")
	var x := CompanionCore.entry(d, "ascent", "enter")
	t._check(CompanionCore.voice_path(d, x, "ru")
		== "res://companion/ru/claud_ascent_enter.ogg",
		"the voice lives in the pack, not in the APK")
