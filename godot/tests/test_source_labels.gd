## The Russian labels of the sources (SourceLabels, source-labels-ru.json)
## in the headset's panel of missions.  The hub script is made without a
## scene (its _ready never runs), given one mission on the road, and its
## panel text is read: the source line must be the Russian label, the
## English original must not be shown.  Called from run_hub_tests.gd.
extends RefCounted


func run(t: Object) -> void:
	var table: Dictionary = SourceLabels.labels()
	t._check(table.size() > 100, "labels read: %d" % table.size())
	# The rule itself: a label when there is one, the original otherwise.
	t._check(SourceLabels.ru("Deuteronomy 22:1-3") == "Втор. 22:1–3",
		"find source label")
	t._check(SourceLabels.ru("Ladder, step 3") == "Лествица, слово 3",
		"ladder label")
	t._check(SourceLabels.ru("No such book 1:1") == "No such book 1:1",
		"fallback keeps the original")
	t._check(SourceLabels.ru("Ladder, step 3", {}) == "Ladder, step 3",
		"empty table falls back")
	t._check(SourceLabels.ru("Ladder, step 3", {"Ladder, step 3":
		{"ru": ""}}) == "Ladder, step 3", "empty label falls back")
	# Every source the port writes itself has a label.
	var own := ["Deuteronomy 22:1-3",
		"Psalm 103:24-25 (LXX; 104 in Hebrew numbering)"]
	for p in MissionCore.PRACTICE_RU.values():
		own.append(p.source)
	for plan in MissionCore.ACT_PLAN.values():
		own.append(plan.source)
	for s in own:
		t._check(table.has(s), "label for " + s)

	# The panel: the hub without its scene, one mission on the road.
	var hub = load("res://scripts/hub.gd").new()
	var data: Dictionary = hub.mission_data
	var id := MissionCore.next_mission(data, hub._mstate())
	# The board, before setting out: the act's source.
	hub.mission = {"choice": 0, "start": id}
	var board: String = hub._mission_panel_text()
	var plan: Dictionary = MissionCore.build_mission(data, id)
	t._check(board.find(SourceLabels.PREFIX + SourceLabels.ru(plan.source))
		>= 0, "board shows the Russian label")
	t._check(board.find(plan.source) < 0, "board hides " + plan.source)
	# On the road: the first step (a find) and its source.
	var st := MissionCore.start(data, hub._mstate(), id)
	hub.mission_state = {"done": st.done, "current": st.current,
		"flags": st.flags, "lines": st.lines}
	hub.mission = {"choice": 0, "start": -1}
	var text: String = hub._mission_panel_text()
	t._check(text.find("Источник: Втор. 22:1–3") >= 0,
		"step panel shows Втор. 22:1–3:\n" + text)
	t._check(text.find("Deuteronomy") < 0, "step panel hides English")
	hub.free()
	# No raw source is joined to the prefix by hand in the hub any more.
	var src := FileAccess.get_file_as_string("res://scripts/hub.gd")
	t._check(src.find("\"Источник: \" +") < 0,
		"hub formats every source through SourceLabels")
