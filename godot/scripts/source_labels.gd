## The Russian form of a source, for the panels of the headset.
##
## The campaign's data (campaign-spine.json, the dialogue trees, the
## passions and the thresholds) cites its sources in English, because it
## mirrors the webtypicon2 game source and must not change.  The player
## reads the Russian form: data/source-labels-ru.json maps each source
## string to its rendering by Synodal and church conventions
## ("Deuteronomy 22:1-3" -> "Втор. 22:1–3").  The same table and the
## same rule serve the web panels (public/ludus/ludus-source-labels.js).
##
## A source missing from the table is shown as it is: the player never
## sees an error, and nothing is printed, because a quiet original is
## better than a broken panel.
##
## Constitution: FORM (the source a teaching stands on) -> ACTION (the
## panel names it in the reader's own tongue) -> GOAL (the player can
## open the book and read the teaching for himself).
class_name SourceLabels
extends RefCounted

const PATH := "res://data/source-labels-ru.json"
const PREFIX := "Источник: "

static var _labels = null


## The table's labels, read once.  An unreadable table is an empty one,
## so every source falls back to its original string.
static func labels() -> Dictionary:
	if _labels == null:
		_labels = {}
		if FileAccess.file_exists(PATH):
			var doc = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if doc is Dictionary and doc.get("labels") is Dictionary:
				_labels = doc.labels
	return _labels


## The Russian label of a source, or the source itself when the table
## has no label for it.  table is for tests; the panels pass nothing.
static func ru(src: String, table = null) -> String:
	var t: Dictionary = table if table is Dictionary else labels()
	var entry = t.get(src)
	if entry is Dictionary and entry.get("ru") is String \
			and entry.ru != "":
		return entry.ru
	return src


## The panel's line for a source: "Источник: <label>".
static func line(src: String) -> String:
	return PREFIX + ru(src)
