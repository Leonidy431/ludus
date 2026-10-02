## Data packs beside the APK: the English voices first (operator,
## 2026-10-02: «для английской речи сделай пока»).
##
## Heavy data that is not code (recorded voices, later the choir and the
## full models) goes into Godot resource packs (.pck), one per kind or
## language, not into the APK (docs/decisions/SIZE_STRATEGIES_7_2026-10-
## 02.md, ways 2, 3 and 6).  At start, before any scene, this autoload
## mounts what it finds:
##
## * on the headset, the store's expansion file in /Android/obb/<package>/
##   (main.<version>.<package>.obb, the highest version), which is the
##   same .pck renamed; by hand it is put there with adb push;
## * on any device, packs in user://packs/ (voice-en.pck and the like).
##
## A pack adds files under res:// and never replaces the game's own
## (replace_files = false).  Nothing is fetched from a network: a pack
## is there or it is not (TABOO 0.26, 0.02 item 2).  Without the English
## pack the game runs on the text of the lines, as now: a voice adds to
## the teaching, the line and its meaning are always there (TABOO 0.39
## item 6).
##
## Constitution: ФОРМА (what the headset carries beside the APK) →
## ДЕЙСТВИЕ (mount what is there, at start, without the network) → ЦЕЛЬ
## (the heroes' voices reach the player in his language, and the game
## stays whole without them).
extends Node

const PACKAGE := "org.ludus.dive"
const OBB_DIR := "/sdcard/Android/obb/" + PACKAGE
const USER_PACKS := "user://packs"
## Where a voice pack puts its files: res://audio/voice/<lang>/
## <npc>/<node>.ogg, with pack.json naming the pack and its language.
const VOICE_ROOT := "res://audio/voice"

## Absolute paths of the packs mounted, in the order they were mounted.
var mounted: Array[String] = []
## Why a pack found was not mounted: path → reason (for the journal of
## a tester, never shown as an error to a player).
var refused: Dictionary = {}


func _ready() -> void:
	mount_all()


## Mount the store's expansion file and the user packs; safe to call
## again, a pack already mounted is skipped.
func mount_all() -> void:
	if OS.get_name() == "Android":
		var obb := pick_obb(_files(OBB_DIR))
		if obb != "":
			mount(OBB_DIR.path_join(obb))
	mount_dir(USER_PACKS)


## Mount every .pck of a folder, in name order (a fixed order, so two
## packs that add the same path always resolve the same way).
func mount_dir(dir: String) -> void:
	var names := _files(dir)
	names.sort()
	for n in names:
		if n.ends_with(".pck"):
			mount(dir.path_join(n))


func mount(path: String) -> bool:
	var abs_path := ProjectSettings.globalize_path(path)
	if abs_path in mounted:
		return true
	if not FileAccess.file_exists(abs_path):
		refused[abs_path] = "not found"
		return false
	if not ProjectSettings.load_resource_pack(abs_path, false):
		refused[abs_path] = "not a Godot pack"
		return false
	mounted.append(abs_path)
	return true


## The store's expansion file of the highest version among names, or ""
## when there is none: main.<version>.org.ludus.dive.obb.
static func pick_obb(names: Array) -> String:
	var best := ""
	var best_v := -1
	for n in names:
		var parts := String(n).split(".")
		if parts.size() < 3 or parts[0] != "main" \
				or not String(n).ends_with("." + PACKAGE + ".obb") \
				or not parts[1].is_valid_int():
			continue
		var v := int(parts[1])
		if v > best_v:
			best_v = v
			best = n
	return best


## True when a voice pack of this language is mounted.
func has_voice(lang: String) -> bool:
	return FileAccess.file_exists(VOICE_ROOT.path_join(lang)
		.path_join("pack.json"))


## The recorded line of an NPC's node in a language, or "" when the pack
## or the line is not there (the panel then shows the text alone).
func voice_path(lang: String, npc: String, node: String) -> String:
	var p := VOICE_ROOT.path_join(lang).path_join(npc).path_join(
		node + ".ogg")
	return p if ResourceLoader.exists(p) or FileAccess.file_exists(p) \
		else ""


static func _files(dir: String) -> Array:
	if not DirAccess.dir_exists_absolute(dir):
		return []
	return Array(DirAccess.get_files_at(dir))
