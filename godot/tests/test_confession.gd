## The preparation sheet in the headset (ConfessionSheet), the static
## guarantees of TABOO 0.26 as tests/ludus-confession.test.js keeps them
## for the web module: no file, no user://, no console, no network, no
## save, no counter, and in the headset no field to write in at all
## (point 9).  The whole source is scanned, comments included, so the
## file may not even name what it must never use.  Called from
## run_hub_tests.gd.
extends RefCounted

const PATH := "res://scripts/confession_sheet.gd"
const FORBIDDEN := ["FileAccess", "ConfigFile", "user://", "DirAccess",
	"ResourceSaver", "store_", "save", "print", "push_warning",
	"push_error", "HTTPRequest", "HTTPClient", "StreamPeer", "PacketPeer",
	"WebSocket", "JavaScriptBridge", "OS.shell_open", "OS.execute",
	"OS.set_", "LineEdit", "TextEdit", "virtual_keyboard", "clipboard",
	"Time.", "emit_signal", "+= 1", "record", "Engine.get_singleton",
	"ProjectSettings.set", "get_tree().root.set_meta", "set_meta"]


func run(t: Object) -> void:
	var src := FileAccess.get_file_as_string(PATH)
	t._check(src.length() > 1000, "the confession sheet is there")
	for word in FORBIDDEN:
		t._check(not src.contains(word), "confession sheet uses no %s"
			% word)
	t._check(src.contains("Это не таинство"), "says it is not the sacrament")
	t._check(src.contains("\"Сжечь листок\""), "offers to burn the sheet")
	t._check(src.contains("на бумаге") and src.contains("тишине сердца"),
		"advises paper or the silence of the heart")
	# The sheet itself: eight questions, the words above, nothing else
	# to press but the burning.
	var text := ConfessionSheet.text()
	t._check(ConfessionSheet.QUESTIONS.size() == 8, "eight questions")
	for q in ConfessionSheet.QUESTIONS:
		t._check(text.contains(q), "question on the sheet: " + q)
	t._check(text.contains("Это не таинство") and text.contains(
		"«Сжечь листок»"), "sheet text")
	# No trace in the game: the rule of prayer has no practice for it,
	# and no counter anywhere in the hub's rules names it.
	for pr in JournalCore.PRACTICES:
		t._check(not str(pr.id).contains("confess"), "no practice "
			+ str(pr.id))
	var re := RegEx.create_from_string("(?i)confess|исповед")
	for path in ["res://scripts/journal_core.gd",
			"res://scripts/hub_core.gd", "res://scripts/mission_core.gd"]:
		var code := FileAccess.get_file_as_string(path)
		# Comments may declare the rule; code may not name it.
		var lines := []
		for line in code.split("\n"):
			if not line.strip_edges().begins_with("#"):
				lines.append(line)
		t._check(re.search("\n".join(lines)) == null,
			"%s keeps nothing of it" % path)
	# The Eucharist only in the story: no practice, no action for it.
	var eu := RegEx.create_from_string(
		"(?i)euchar|communion|причащ|евхарист")
	for pr in JournalCore.PRACTICES:
		t._check(eu.search(str(pr.id) + str(pr.label)) == null,
			"no Eucharist practice " + str(pr.id))
	# The sheet in the scene: it shows near the stand, burns on a press
	# and comes back clean only after walking away; its state is two
	# booleans in memory.
	var parent = Node3D.new()
	parent.set_script(load("res://tests/confession_walker.gd"))
	var bay := {"x": 53.0, "side": 1.0}
	var sheet := ConfessionSheet.place(parent, bay)
	parent.pos = sheet.at + Vector3(0, 0, -1.0)
	sheet._process(0.1)
	t._check(sheet.board.visible, "sheet shown at the stand")
	t._check(sheet.at.z < WitnessCore.PATH_HALF, "sheet on the path side")
	sheet.burned = true
	sheet._process(0.1)
	t._check(not sheet.board.visible, "burned sheet is gone")
	parent.pos = sheet.at + Vector3(-6.0, 0, 0)
	sheet._process(0.1)
	parent.pos = sheet.at + Vector3(0, 0, -1.0)
	sheet._process(0.1)
	t._check(sheet.board.visible and not sheet.burned,
		"a clean sheet after walking away")
	parent.free()
