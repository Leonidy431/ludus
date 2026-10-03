## Which save the game reads and writes: the player's own, or the tester's.
##
## Every reader and writer of the courtyard's and the dive's saves asks
## here (hub.gd, dive.gd, location_core.gd, story_route.gd,
## journal_book.gd), so no scene hardcodes a path.  Normal play uses
## user://hub.json and user://dive.json.  The test slot (StoryCheck, the
## tester's entry on the mission board) uses user://test-hub.json and
## user://test-dive.json, and is active only in a debug build while the
## marker user://test-slot exists.  A release export never reads the
## marker, so the test slot cannot exist there, whatever lies on disk.
##
## Constitution: FORM (the tester in the headset) -> ACTION (open any of
## the 12 stories in a separate test save) -> GOAL (the operator checks
## the teaching of every story without walking the campaign; a release
## build has no such door).
class_name SaveSlot
extends RefCounted

const HUB := "user://hub.json"
const DIVE := "user://dive.json"
const TEST_HUB := "user://test-hub.json"
const TEST_DIVE := "user://test-dive.json"
const MARKER := "user://test-slot"


## Whether this is a debug build.  debug overrides it for the tests
## (null asks the engine), so the hidden branch of a release build is
## tested in a debug run too.
static func debug_build(debug = null) -> bool:
	return OS.is_debug_build() if debug == null else bool(debug)


## Whether the test slot is active: a debug build and the marker.
static func testing(debug = null, marker := MARKER) -> bool:
	return debug_build(debug) and FileAccess.file_exists(marker)


static func hub(debug = null, marker := MARKER) -> String:
	return TEST_HUB if testing(debug, marker) else HUB


static func dive(debug = null, marker := MARKER) -> String:
	return TEST_DIVE if testing(debug, marker) else DIVE


## The test slot's files and marker, as StoryCheck writes them.
static func test_paths() -> Dictionary:
	return {"hub": TEST_HUB, "dive": TEST_DIVE, "marker": MARKER}


## Write a save whole or not at all.  The JSON goes to <path>.part, is
## closed, then renamed over the save: a rename within one folder is
## atomic on Android and Linux, so a crash, a dead battery or a second
## writer mid-write leaves the old save, never half of a new one (a load
## run of the tests, 2026-10-03, tore user://test-hub.json and read
## "Parse JSON failed").  Returns whether the save was replaced.
##
## The save it replaces is kept as <path>.bak, but only when it still
## reads as a whole JSON object: a save already spoiled on disk (a hand
## edit over adb, a bad sector) never overwrites the last good copy.
static func write_json(path: String, data) -> bool:
	var part := path + ".part"
	var f := FileAccess.open(part, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSlot: cannot write %s" % part)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if _parse(path) is Dictionary:
		DirAccess.copy_absolute(path, path + ".bak")
	var ok := DirAccess.rename_absolute(part, path) == OK
	if not ok:
		push_warning("SaveSlot: cannot replace %s" % path)
	return ok


## Read a save: the file itself, or, if it is spoiled, its last good
## copy <path>.bak.  {} only when neither reads, so a spoiled save no
## longer turns into a fresh start that the next write would make
## permanent (chorus audit 2026-10-03, voice 14).
static func read_json(path: String) -> Dictionary:
	var d = _parse(path)
	if d is Dictionary:
		return d
	var bak = _parse(path + ".bak")
	if bak is Dictionary:
		if FileAccess.file_exists(path):
			push_warning("SaveSlot: %s is spoiled, read its .bak" % path)
		return bak
	return {}


static func _parse(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
