## The journal of the way in the scriptorium: a birch-bark book on an oak
## lectern at the north end of the long table (JournalCore).
##
## It reads the player's own saves, user://hub.json and user://dive.json,
## and never writes to them.  Each press turns a page: FORM, the rule,
## the steps of the ladder, the road, the deeds of places, under the
## water, and last the page
## where the player may ask for the record to be written out.  Only a
## press on that last page writes a file, user://journal-<date>.md, the
## same Markdown page the web game exports; an earlier page of the same
## day is never overwritten, and nothing here deletes a journal (TABOO
## 0.25 point 5).  Reading counts nothing: no attribute, gate or reward.
##
## The preparation for confession is not here and is never recorded: it
## lives on the path of the witness and keeps nothing (TABOO 0.26).
## Placed by a small hook in hub.gd: things.append(JournalBook.place(self)).
class_name JournalBook
extends Node3D

# Beside the board of form in the south of the courtyard: the record of
# the way next to the form it records.  At the scriptorium's north end
# its reach covered the lectern of the evening cell, and by the north
# wall it stood in the workshop.
const AT := Vector3(-1.4, 0, 6.0)
const HUB_SAVE := "user://hub.json"
const DIVE_SAVE := "user://dive.json"
const OAK := Color(0.42, 0.29, 0.17)
const BARK := Color(0.93, 0.88, 0.76)
const INK := Color(0.2, 0.15, 0.1)
## The hearth's warm light over the page, about 2200 K (TABOO 0.38).
const HEARTH_K := Color(1.0, 0.62, 0.3)

## The titles of the places whose hearts hold an act (JournalCore.
## deed_titles), read once: the data of the 99 places does not change.
static var _deed_titles = null

var page := 0
var written := ""
var board: Label3D


## Build the lectern in the hub and return the thing the hub's reach
## finds; the hub calls use() when the player presses at it.
static func place(hub: Node3D) -> Dictionary:
	var book := JournalBook.new()
	book.name = "JournalBook"
	hub.add_child(book)
	book._build()
	return {"id": "journal", "kind": "node", "node": book,
		"pos": AT + Vector3(0.7, 0, 0),
		"ru": "Журнал пути: перевернуть бересту"}


func _box(size: Vector3, at: Vector3, colour: Color) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	m.material_override = mat
	m.position = at
	add_child(m)


func _build() -> void:
	_box(Vector3(0.12, 1.0, 0.12), AT + Vector3(0, 0.5, 0), OAK)
	_box(Vector3(0.5, 0.05, 0.7), AT + Vector3(0, 1.05, 0), OAK)
	# The open book on the lectern: two leaves of bark.
	_box(Vector3(0.34, 0.02, 0.5), AT + Vector3(0, 1.09, 0), BARK)
	var back := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 1.9)
	back.mesh = qm
	var bark := StandardMaterial3D.new()
	bark.albedo_color = BARK
	back.material_override = bark
	back.position = AT + Vector3(-0.42, 2.05, 0)
	back.rotation_degrees = Vector3(0, 90, 0)
	add_child(back)
	board = Label3D.new()
	board.font_size = 32
	board.pixel_size = 0.0021
	board.width = 860
	board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.modulate = INK
	board.outline_size = 0
	board.double_sided = false
	board.position = AT + Vector3(-0.4, 2.05, 0)
	board.rotation_degrees = Vector3(0, 90, 0)
	add_child(board)
	var lamp := OmniLight3D.new()
	lamp.light_color = HEARTH_K
	lamp.light_energy = 0.5
	lamp.omni_range = 3.0
	lamp.position = AT + Vector3(0.4, 2.4, 0.8)
	add_child(lamp)
	_show()


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## The record as the saves hold it now (read-only).
func state() -> Dictionary:
	var hub = _read(HUB_SAVE)
	if not hub is Dictionary:
		hub = {}
	var passions: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/passions.json"))
	var form = hub.get("form")
	if _deed_titles == null:
		_deed_titles = JournalCore.deed_titles(LocationCore.load_data())
	return {"form": form if form is Dictionary else HubCore.new_form(),
		"actions": hub.get("actions", {}),
		"deeds": hub.get("deeds", {}), "deed_titles": _deed_titles,
		"passions": PassionCore.normalize_record(hub.get("passions", {})),
		"passion_data": passions, "dive": _read(DIVE_SAVE),
		"date": Time.get_date_string_from_system()}


func _show() -> void:
	var pages := JournalCore.pages_ru(state())
	var total := pages.size() + 1
	var text := ""
	if page < pages.size():
		text = pages[page]
	elif written == "-":
		text = "Выписать не удалось: память шлема не открылась для записи. Журнал в сохранениях цел."
	elif written != "":
		text = "ВЫПИСАНО\n\nСтраница легла в файл:\n%s\n\nПрежние страницы не стираются: журнал хранится.\n\n%s" % [written, JournalCore.CLOSING_RU]
	else:
		text = "ВЫПИСАТЬ СТРАНИЦУ\n\nНажми здесь, и журнал ляжет в файл journal-<дата>.md рядом с сохранениями игры — та же страница, что в веб-версии. Прежние страницы не стираются; никуда не отправляется.\n\n%s" % JournalCore.CLOSING_RU
	board.text = "%s\n\n(лист %d из %d — нажми: дальше)" % [text, page + 1,
		total]


## A press at the lectern: turn the page, or on the last page write the
## record out once, as the player asked.
func use() -> void:
	var pages := JournalCore.pages_ru(state())
	if page == pages.size() and written == "":
		written = export_page()
		if written == "":
			written = "-"
	else:
		page = (page + 1) % (pages.size() + 1)
		written = ""
	_show()


## Write the Markdown page to a fresh user://journal-<date>.md.  Returns
## the path, or "" when the file could not be opened.
func export_page() -> String:
	var st := state()
	var path := JournalCore.export_path(st.date,
		func(p): return FileAccess.file_exists(p))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JournalCore.to_markdown(st))
	f.close()
	return path
