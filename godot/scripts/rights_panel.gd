## The Manuscript of rights in the world: one board that names every
## third-party part of the headset build, its author, its licence (SPDX
## id) and where its text lies in the APK (HLD CHORUS24 F7; CLAUDE.md
## TABOO 0.1: the licence register is always kept).
##
## The facts come from godot/data/rights.json, which
## scripts/build_rights_manifest.py writes from what actually ships, and
## from the engine itself: Engine.get_license_text() for Godot's MIT
## text and Engine.get_copyright_info() for the engine's own
## third-party parts, so the board cannot drift from the binary.  The
## licence texts (GPL 2 and 3, CC BY-SA 3.0, Apache 2.0, MIT) ship in
## res://licenses/, because the copy the player holds must carry them.
##
## Constitution: ФОРМА (what the game is made of, and whose hands made
## it) → ДЕЙСТВИЕ (the player can walk up and read every name and every
## licence, as a colophon at the end of a manuscript) → ЦЕЛЬ (knowledge
## as a shared good, IX.3; the author of borrowed work is named, VIII.7).
class_name RightsPanel
extends RefCounted

const DATA := "res://data/rights.json"
const LANGS := ["ru", "en"]
## Board look: the ink of the places lectern; a finer scale (22 px at
## 1 mm a pixel is a 2 cm letter, read at arm's length) so the long
## list fits one board about 1.2 m wide and 1.7 m tall; the same ink
## keeps it one of the tags of the cell (TABOO 0.013 p. 4).
const INK := Color(0.2, 0.15, 0.1)
const FONT_SIZE := 22
const PIXEL := 0.001
const WIDTH := 1200

const WORDS := {
	"ru": {
		"title": "Манускрипт прав",
		"engine": "Движок: %s %s — %s.",
		"engine_parts": "Частей движка со своими лицензиями: %d "
				+ "(%s): %s.",
		"components": "Модули в сборке:",
		"raw": "Картинки из открытых игр, переработанные раннером "
				+ "(автор, источник, лицензия, изменение):",
		"change": "форма %d %%, цвет %d %%",
		"texts": "Тексты лицензий лежат в самой сборке, в папке "
				+ "licenses/: %s.",
		"own": "Своё: %s — %s.",
	},
	"en": {
		"title": "Manuscript of rights",
		"engine": "Engine: %s %s — %s.",
		"engine_parts": "Engine parts under their own licences: %d "
				+ "(%s): %s.",
		"components": "Modules in the build:",
		"raw": "Pictures from open games, reworked by the runner "
				+ "(author, source, licence, change):",
		"change": "shape %d %%, colour %d %%",
		"texts": "The licence texts are in the build itself, in "
				+ "licenses/: %s.",
		"own": "Our own: %s — %s.",
	},
}

static var _cache := {}


static func load_data() -> Dictionary:
	if _cache.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_cache = d if d is Dictionary else {}
	return _cache


## The engine's own third-party parts, by name, without the engine
## itself, sorted; and the licence ids they use.
static func engine_parts() -> Dictionary:
	var names := []
	var ids := {}
	for part in Engine.get_copyright_info():
		if str(part.name) == "Godot Engine":
			continue
		names.append(str(part.name))
		for p in part.parts:
			ids[str(p.license)] = true
	names.sort()
	var lic := ids.keys()
	lic.sort()
	return {"names": names, "licences": lic}


## The first line of Godot's own MIT text, as the binary carries it.
static func engine_copyright() -> String:
	return Engine.get_license_text().split("\n")[0].strip_edges()


## The whole board in `lang` (en for a language without words here).
static func text_for(lang := "ru", data: Dictionary = {}) -> String:
	var d := data if not data.is_empty() else load_data()
	var w: Dictionary = WORDS.get(lang, WORDS.en)
	var out := PackedStringArray([w.title, ""])
	var comps: Array = d.get("components", [])
	if not comps.is_empty():
		var e: Dictionary = comps[0]
		out.append(w.engine % [e.name, e.version, e.spdx])
		out.append(engine_copyright())
	var parts := engine_parts()
	out.append(w.engine_parts % [parts.names.size(),
			", ".join(parts.licences), ", ".join(parts.names)])
	out.append("")
	out.append(w.components)
	for i in range(1, comps.size()):
		var c: Dictionary = comps[i]
		out.append("• %s — %s (%s)" % [c.name, c.spdx,
				str(c.licence_file).get_file()])
	out.append("")
	out.append(w.raw)
	for o in d.get("raw_material", []):
		var change: String = w.change % [
				roundi(float(o.shape_change) * 100.0),
				roundi(float(o.colour_change) * 100.0)]
		out.append("• %s — %s; %s @ %s, %s; %s; %s" % [o.object,
				o.author, o.repo, o.commit, o.path, o.spdx, change])
	var ru := lang == "ru"
	out.append(str(d.get("copyleft_note_ru" if ru else "copyleft_note",
			d.get("copyleft_note", ""))))
	out.append("")
	var files := PackedStringArray()
	for rel in d.get("licence_texts", []):
		files.append(str(rel).get_file())
	out.append(w.texts % ", ".join(files))
	var own: Dictionary = d.get("own", {})
	if not own.is_empty():
		out.append(w.own % [own.get("name_ru" if ru else "name", own.name),
				own.get("licence_ru" if ru else "licence", own.licence)])
	return "\n".join(out)


## Every licence text the board names, and whether it is in the build.
static func texts_present(data: Dictionary = {}) -> Dictionary:
	var d := data if not data.is_empty() else load_data()
	var out := {}
	for rel in d.get("licence_texts", []):
		out[str(rel)] = FileAccess.file_exists("res://" + str(rel))
	return out


## The board itself: a Label3D the caller places in the world.
static func make(lang := "ru") -> Label3D:
	var board := Label3D.new()
	board.name = "RightsPanel"
	board.text = text_for(lang)
	board.font_size = FONT_SIZE
	board.pixel_size = PIXEL
	board.width = WIDTH
	board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	board.modulate = INK
	board.outline_size = 0
	board.double_sided = false
	return board
