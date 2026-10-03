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
## * on any device, packs in user://packs/ (<id>-<sha8>.pck, as named by
##   data/packs.json).
##
## A pack adds files under res:// and never replaces the game's own
## (replace_files = false).  This module itself opens no connection: the
## packs in user://packs are fetched over the network by PackFetch, in
## the background, from the project's own releases (TABOO 0.018).  Here
## they are only checked and mounted.  At start, before any pack of
## that folder is mounted, every file is held against the manifest
## inside the APK (data/packs.json): half downloads, old versions,
## files the manifest does not name and files whose size or SHA-256
## does not match are deleted and never mounted (TABOO 0.018 item 5);
## then the disk limit is kept.  Without a pack the game runs on the
## text of the lines, as now: a voice adds to the teaching, the line
## and its meaning are always there (TABOO 0.39 item 6).
##
## The store's expansion file is not in the manifest: the store or adb
## puts it there and the system checks it, so it is mounted as it is.
##
## Constitution: ФОРМА (what the headset carries beside the APK, named
## by the manifest) → ДЕЙСТВИЕ (at start, keep and mount only what
## matches, before any scene) → ЦЕЛЬ (the heroes' voices reach the
## player in his language, nothing foreign is mounted, and the game
## stays whole without them).
extends Node

## The shared checks of the manifest (static functions only, so no
## request is ever made from here).
const Fetch := preload("res://scripts/pack_fetch.gd")
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
## Folders already checked and mounted in this session: a second pass
## could delete a file under a pack that is mounted, so there is none.
var _prepared := {}


func _ready() -> void:
	mount_all()


## Mount the store's expansion file and the user packs; safe to call
## again: a pack already mounted and a folder already checked are
## skipped.
func mount_all() -> void:
	if OS.get_name() == "Android":
		var obb := pick_obb(_files(OBB_DIR))
		if obb != "":
			mount(OBB_DIR.path_join(obb))
	mount_dir(USER_PACKS)


## Check a folder of packs against a manifest (the shipped one when m
## is empty) and mount what matches, in name order (a fixed order, so
## two packs that add the same path always resolve the same way).
## What is deleted and why goes to `refused`.  Must run before any pack
## of the folder is mounted in this session: Godot cannot unmount, and
## a deleted file under a mounted pack would break its reads.
func mount_dir(dir: String, m := {}) -> void:
	var key := ProjectSettings.globalize_path(dir)
	if _prepared.has(key):
		return
	_prepared[key] = true
	if m.is_empty():
		m = Fetch.load_manifest()
	var r: Dictionary = Fetch.prepare(dir, m, Fetch.DISK_MAX_BYTES)
	for n in r.removed:
		refused[ProjectSettings.globalize_path(dir.path_join(n))] = \
			r.removed[n]
	for path in r.mount:
		mount(path)


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
