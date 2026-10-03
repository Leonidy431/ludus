## The Manuscript of rights in the headset build (HLD CHORUS24 F7,
## CLAUDE.md TABOO 0.1): every licence text the page names is in the
## build; every third-party picture that ships has an author, a source
## at a commit, a versioned SPDX id (never a bare "GPL") and its text;
## the engine, the OpenXR vendors plugin and the Khronos loader are
## listed; the board names all of it in Russian and English; the export
## presets carry licenses/ into the APK.  Called from run_hub_tests.gd.
extends RefCounted

const SPDX_TEXT := {
	"GPL-2.0-only": "GPL-2.0.txt", "GPL-2.0-or-later": "GPL-2.0.txt",
	"GPL-3.0-only": "GPL-3.0.txt", "GPL-3.0-or-later": "GPL-3.0.txt",
	"CC-BY-SA-3.0": "CC-BY-SA-3.0.txt", "Apache-2.0": "Apache-2.0.txt",
}


func run(t: Object) -> void:
	var d := RightsPanel.load_data()
	t._check(not d.is_empty(), "rights.json loads")

	# Every licence text named is in the build, and is a real text.
	var present := RightsPanel.texts_present(d)
	t._check(present.size() >= 7, "rights names the licence texts")
	for rel in present:
		t._check(present[rel], "licence text ships: %s" % rel)
		t._check(FileAccess.get_file_as_string("res://" + rel).length()
				> 200, "licence text is not empty: %s" % rel)
	var gpl3 := FileAccess.get_file_as_string("res://licenses/GPL-3.0.txt")
	t._check(gpl3.contains("Version 3, 29 June 2007"), "GPL 3 is the text")
	var gpl2 := FileAccess.get_file_as_string("res://licenses/GPL-2.0.txt")
	t._check(gpl2.contains("Version 2, June 1991"), "GPL 2 is the text")
	var bysa := FileAccess.get_file_as_string(
			"res://licenses/CC-BY-SA-3.0.txt")
	t._check(bysa.contains("Attribution-ShareAlike 3.0 Unported"),
			"CC BY-SA 3.0 is the text")
	var apache := FileAccess.get_file_as_string(
			"res://licenses/Apache-2.0.txt")
	t._check(apache.contains("Version 2.0, January 2004"),
			"Apache 2.0 is the text")
	# Godot's MIT file is what the engine binary itself says.
	t._check(FileAccess.get_file_as_string(
			"res://licenses/MIT-Godot-Engine.txt").strip_edges()
			== Engine.get_license_text().strip_edges(),
			"Godot MIT file equals Engine.get_license_text()")

	# The components of the APK.
	var names := []
	for c in d.get("components", []):
		names.append(str(c.name))
		t._check(c.get("in_apk", false), "component in APK: %s" % c.name)
		t._check(present.get(c.licence_file, false),
				"component has its text: %s" % c.name)
	t._check(names[0] == "Godot Engine", "the engine comes first")
	var joined := " ".join(names)
	t._check(joined.contains("godot_openxr_vendors")
			and joined.contains("Khronos OpenXR loader"),
			"vendors plugin and Khronos loader are listed")
	var spdx_of := {}
	for c in d.components:
		spdx_of[str(c.name).get_slice(" ", 0)] = c.spdx
	t._check(spdx_of.get("Khronos") == "Apache-2.0", "loader is Apache-2.0")

	# Every shipped third-party picture: author, source, SPDX, text.
	var raw: Array = d.get("raw_material", [])
	t._check(raw.size() >= 20, "rights lists the shipped pictures")
	for o in raw:
		var what := str(o.object)
		t._check(SPDX_TEXT.has(o.spdx), "%s: versioned SPDX id (%s)"
				% [what, o.spdx])
		t._check(str(o.licence_file).get_file()
				== SPDX_TEXT.get(o.spdx, "?"), "%s: right text" % what)
		t._check(str(o.author) != "" and str(o.repo).begins_with(
				"https://") and str(o.commit).length() == 10,
				"%s: author, source and commit" % what)
		t._check(float(o.shape_change) >= 0.35,
				"%s: shape change at least 35 %%" % what)
		var found := false
		for dir in DirAccess.get_directories_at("res://art/derived"):
			for f in DirAccess.get_files_at("res://art/derived/" + dir):
				if f.begins_with(what + "_v") and f.ends_with(".png"):
					found = true
		t._check(found, "%s: the picture is in the build" % what)

	# The board, in both languages, names everything above.
	for lang in RightsPanel.LANGS:
		var text := RightsPanel.text_for(lang, d)
		t._check(text.contains("Godot Engine") and text.contains("MIT"),
				"%s board names the engine" % lang)
		t._check(text.contains(RightsPanel.engine_copyright()),
				"%s board carries the engine copyright" % lang)
		t._check(text.contains("Apache-2.0"), "%s board: loader" % lang)
		for o in raw:
			t._check(text.contains(o.object) and text.contains(o.author)
					and text.contains(o.spdx), "%s board names %s"
					% [lang, o.object])
		for rel in present:
			t._check(text.contains(str(rel).get_file()),
					"%s board names %s" % [lang, rel])
		var parts := RightsPanel.engine_parts()
		t._check(parts.names.size() == Engine.get_copyright_info().size()
				- 1, "%s board counts the engine parts" % lang)
		t._check(text.contains(str(parts.names.size())),
				"%s board says how many engine parts" % lang)
	t._check(RightsPanel.text_for("ru", d).begins_with("Манускрипт прав"),
			"ru board title")
	t._check(RightsPanel.text_for("en", d).begins_with(
			"Manuscript of rights"), "en board title")
	t._check(RightsPanel.text_for("xx", d) == RightsPanel.text_for("en", d),
			"unknown language falls back to en")
	t._check(RightsPanel.text_for("ru", d) == RightsPanel.text_for("ru", d),
			"the board is deterministic")
	var board := RightsPanel.make("ru")
	t._check(board is Label3D and board.text == RightsPanel.text_for("ru"),
			"make() builds the Label3D with the board text")
	t._check(board.pixel_size * board.font_size >= 0.02,
			"letters are at least 2 cm tall")
	board.free()

	# The export presets carry licenses/ and data/ into the APK.
	var cfg := ConfigFile.new()
	t._check(cfg.load("res://export_presets.cfg") == OK, "presets load")
	for sec in ["preset.0", "preset.1"]:
		var inc := str(cfg.get_value(sec, "include_filter", ""))
		t._check(inc.contains("licenses/*") and inc.contains("data/*.json"),
				"%s ships licenses/ and data/rights.json" % sec)
