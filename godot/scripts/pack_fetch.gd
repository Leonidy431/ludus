## The "CD" of TABOO 0.018: packs fetched over the network in the
## background, before the player needs them, checked and then mounted
## by DataPacks (docs/HLD_PACKS_STREAM_2026-10-02.md).  Autoload
## "PackFetch".
##
## The APK is the hard disk: the game starts and plays without any of
## this.  A pack is asked for when the player walks towards what needs
## it (want), downloaded to user://packs/<id>.pck.part, its SHA-256 is
## compared with the manifest's, and only then is it renamed and
## mounted.  A pack that does not match is deleted, never mounted.
## The request is a plain GET of the file named in data/packs.json:
## no id, no save, no telemetry goes out (TABOO 0.35 item 21).
extends Node

const MANIFEST := "res://data/packs.json"
const DIR := "user://packs"
## The disk the packs may take on the headset.  Over it, the packs not
## used the longest are deleted first (LRU by file time); a pack the
## player needs again is fetched again.  Not by the clock: a pack
## deleted every two minutes would be fetched over and over, and gone
## when there is no network (operator's question of 2026-10-02).
const DISK_MAX_BYTES := 512 * 1024 * 1024

## id -> "queued" | "loading" | "ready" | "failed: <why>"
var status := {}
var manifest := {}
var _http: HTTPRequest
var _current := ""
var _queue: Array[String] = []


func _ready() -> void:
	manifest = load_manifest()
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.request_completed.connect(_on_done)
	add_child(_http)
	# What already lies in user://packs and checks out is ready.
	for p in manifest.get("packs", []):
		if verify(_path(p.id), p):
			status[p.id] = "ready"


static func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST):
		return {"packs": []}
	var d = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return d if d is Dictionary else {"packs": []}


static func entry(m: Dictionary, id: String) -> Dictionary:
	for p in m.get("packs", []):
		if p.id == id:
			return p
	return {}


static func _path(id: String) -> String:
	return DIR.path_join(id + ".pck")


## True when the file at path has the manifest's size and SHA-256.
static func verify(path: String, p: Dictionary) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() != int(p.get("bytes", -1)):
		return false
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		ctx.update(f.get_buffer(1 << 20))
	return ctx.finish().hex_encode() == str(p.get("sha256", ""))


## Ask for a pack: it is fetched in the background if it is not here.
## Unknown ids and packs already ready or queued change nothing.
func want(id: String) -> void:
	var p := entry(manifest, id)
	if p.is_empty() or status.get(id, "") in ["ready", "queued",
			"loading"]:
		return
	status[id] = "queued"
	_queue.append(id)
	_next()


func is_ready(id: String) -> bool:
	return status.get(id, "") == "ready"


func _next() -> void:
	if _current != "" or _queue.is_empty():
		return
	_current = _queue.pop_front()
	var p := entry(manifest, _current)
	DirAccess.make_dir_recursive_absolute(DIR)
	_http.download_file = _path(_current) + ".part"
	status[_current] = "loading"
	var url := str(manifest.get("base", "")) + str(p.file)
	if _http.request(url) != OK:
		_finish("failed: request")


func _on_done(result: int, code: int, _h: PackedStringArray,
		_b: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		# No network or no file: the game goes on without the pack.
		_finish("failed: http %d/%d" % [result, code])
		return
	_finish(accept(_current, manifest))


## Check a downloaded .part and put it in place; "ready" or why not.
static func accept(id: String, m: Dictionary) -> String:
	var p := entry(m, id)
	var part := _path(id) + ".part"
	if not verify(part, p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(part))
		return "failed: checksum"
	DirAccess.rename_absolute(ProjectSettings.globalize_path(part),
		ProjectSettings.globalize_path(_path(id)))
	return "ready"


## Delete the least recently used packs until the rest fit `limit`;
## `keep` is never deleted (the pack being mounted).  Returns the ids
## deleted.
static func evict(limit: int, keep := "") -> Array:
	var files := []
	var total := 0
	var d := DirAccess.open(DIR)
	if d == null:
		return []
	for n in d.get_files():
		if not n.ends_with(".pck"):
			continue
		var path := DIR.path_join(n)
		var size := FileAccess.open(path, FileAccess.READ).get_length()
		total += size
		files.append([FileAccess.get_modified_time(path), n, size])
	files.sort()
	var gone := []
	for f in files:
		if total <= limit:
			break
		var id: String = f[1].get_basename()
		if id == keep:
			continue
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
			DIR.path_join(f[1])))
		total -= int(f[2])
		gone.append(id)
	return gone


func _finish(st: String) -> void:
	status[_current] = st
	if st == "ready":
		for id in evict(DISK_MAX_BYTES, _current):
			status.erase(id)
		var dp := get_node_or_null("/root/DataPacks")
		if dp:
			dp.mount(_path(_current))
	_current = ""
	_next()
