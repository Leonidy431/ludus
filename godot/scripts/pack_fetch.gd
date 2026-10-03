## The "CD" of TABOO 0.018: packs fetched over the network in the
## background, before the player needs them, checked and then mounted
## by DataPacks (docs/HLD_PACKS_STREAM_2026-10-02.md).  Autoload
## "PackFetch".
##
## The APK is the hard disk: the game starts and plays without any of
## this.  A pack is asked for when the player walks towards what needs
## it (want), downloaded to user://packs/<id>-<sha8>.pck.part, its size
## and SHA-256 are compared with the manifest's, and only then is it
## renamed and mounted.  A pack that does not match is deleted, never
## mounted (TABOO 0.018 item 5).  The request is a plain GET of the
## file named in data/packs.json: no id, no save, no telemetry goes out
## (TABOO 0.35 item 21).
##
## The file name on disk carries the first eight hex digits of the
## pack's SHA-256.  A new version of a pack therefore lands beside the
## old one and never over a file that is mounted in this session; the
## old one is removed at the next start, before anything is mounted
## (prepare, called by DataPacks).  The disk limit is also enforced
## only there, for the same reason: Godot cannot unmount a pack, so a
## file must not vanish under a mounted pack.
##
## Constitution: ФОРМА (the manifest inside the APK, which names every
## pack by size and hash) → ДЕЙСТВИЕ (fetch in the background, keep
## only what matches) → ЦЕЛЬ (voices and new episodes arrive whole and
## true, and nothing foreign is ever mounted in the game).
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
	# DataPacks starts first and has already checked and mounted what
	# lies in user://packs; hashing the same files twice at start would
	# only slow the first frame down.
	var dp := get_node_or_null("/root/DataPacks")
	for p in manifest.get("packs", []):
		if not valid_entry(p):
			continue
		var path := local_path(p)
		var here: bool = ProjectSettings.globalize_path(path) \
			in dp.mounted if dp else verify(path, p)
		if here:
			status[p.id] = "ready"


static func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST):
		return {"packs": []}
	var d = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return d if d is Dictionary else {"packs": []}


## The manifest's entry for id, or {} when there is none or when it is
## not well formed (see valid_entry): a bad entry is never fetched.
static func entry(m: Dictionary, id: String) -> Dictionary:
	for p in m.get("packs", []):
		if p is Dictionary and str(p.get("id", "")) == id:
			return p if valid_entry(p) else {}
	return {}


## True when a name is one plain file name: no folder, no "..", nothing
## a path could climb out of user://packs with.
static func _plain_name(s: String) -> bool:
	return s != "" and s.is_valid_filename() and not ".." in s \
		and not "/" in s and not "\\" in s


## True when a manifest entry is safe to fetch and to store.  The id
## becomes a file name on disk, so it must be a plain name.  The file
## is a path under the releases' base: either a plain name or one
## release tag and a plain name ("packs-<id>-v<N>/<id>-v<N>.pck", as
## the delivery document lays the releases out); never "..", never a
## leading slash, never a scheme.  The hash must be 64 hex digits and
## the size positive, or the check after the download means nothing.
static func valid_entry(p: Variant) -> bool:
	if not p is Dictionary:
		return false
	var id := str(p.get("id", ""))
	var file := str(p.get("file", ""))
	var sha := str(p.get("sha256", ""))
	if not _plain_name(id) or file == "" or "\\" in file:
		return false
	var parts := file.split("/")
	if parts.size() > 2:
		return false
	for part in parts:
		if not _plain_name(part):
			return false
	return sha.length() == 64 and sha.is_valid_hex_number() \
		and int(p.get("bytes", 0)) > 0


## The file name of a pack on disk: its id and the first eight hex
## digits of its hash, so that each version has its own file.
static func local_name(p: Dictionary) -> String:
	return "%s-%s.pck" % [p.id, str(p.sha256).to_lower().left(8)]


static func local_path(p: Dictionary, dir := DIR) -> String:
	return dir.path_join(local_name(p))


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
	return ctx.finish().hex_encode() == str(p.get("sha256", "")).to_lower()


## Ask for a pack: it is fetched in the background if it is not here.
## Unknown or malformed ids and packs already ready or queued change
## nothing.
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
	_http.download_file = local_path(p) + ".part"
	status[_current] = "loading"
	var url := str(manifest.get("base", "")) + str(p.file)
	if _http.request(url) != OK:
		_remove(local_path(p) + ".part")
		_finish("failed: request")


func _on_done(result: int, code: int, _h: PackedStringArray,
		_b: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		# No network or no file: the game goes on without the pack, and
		# the half-written file is not left to fill the disk unseen.
		_remove(local_path(entry(manifest, _current)) + ".part")
		_finish("failed: http %d/%d" % [result, code])
		return
	_finish(accept(_current, manifest))


## Check a downloaded .part and put it in place; "ready" or why not.
static func accept(id: String, m: Dictionary, dir := DIR) -> String:
	var p := entry(m, id)
	if p.is_empty():
		return "failed: manifest"
	var final := local_path(p, dir)
	var part := final + ".part"
	if not verify(part, p):
		_remove(part)
		return "failed: checksum"
	# The same version may already lie in place (fetched twice); it is
	# the same bytes, so the new copy is simply dropped.
	if verify(final, p):
		_remove(part)
		return "ready"
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(part),
		ProjectSettings.globalize_path(final))
	if err != OK:
		_remove(part)
		return "failed: rename %d" % err
	return "ready"


## Make a folder of packs fit to mount, at start and before anything in
## it is mounted: half downloads, files the manifest does not name (old
## versions among them) and files whose size or hash does not match are
## deleted; then the least recently used packs are deleted until the
## rest fit `limit`.  Returns {"mount": [paths, in name order],
## "removed": {file name: why}}.
static func prepare(dir: String, m: Dictionary,
		limit := DISK_MAX_BYTES) -> Dictionary:
	var removed := {}
	var keep := []
	if not DirAccess.dir_exists_absolute(dir):
		return {"mount": keep, "removed": removed}
	var known := {}
	for p in m.get("packs", []):
		if valid_entry(p):
			known[local_name(p)] = p
	var names := Array(DirAccess.get_files_at(dir))
	names.sort()
	for n in names:
		var path := dir.path_join(n)
		var why := ""
		if n.ends_with(".part"):
			why = "half download"
		elif not known.has(n):
			why = "not in the manifest"
		elif not verify(path, known[n]):
			why = "checksum"
		if why != "":
			_remove(path)
			removed[n] = why
		else:
			keep.append(n)
	for n in evict(limit, dir):
		removed[n] = "disk limit"
		keep.erase(n)
	var out := []
	for n in keep:
		out.append(dir.path_join(n))
	return {"mount": out, "removed": removed}


## Delete the least recently used packs of dir until the rest fit
## `limit`.  Called only from prepare, before any pack is mounted, so
## it never deletes a mounted file.  Ties in file time are broken by
## name, so the order is the same on every run.  Returns the file
## names deleted.
static func evict(limit: int, dir := DIR) -> Array:
	var files := []
	var total := 0
	if not DirAccess.dir_exists_absolute(dir):
		return []
	for n in DirAccess.get_files_at(dir):
		var path := dir.path_join(n)
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var size := f.get_length()
		f.close()
		total += size
		files.append([FileAccess.get_modified_time(path), n, size])
	files.sort()
	var gone := []
	for f in files:
		if total <= limit:
			break
		_remove(dir.path_join(f[1]))
		total -= int(f[2])
		gone.append(f[1])
	return gone


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish(st: String) -> void:
	status[_current] = st
	if st == "ready":
		var dp := get_node_or_null("/root/DataPacks")
		if dp:
			dp.mount(local_path(entry(manifest, _current)))
	_current = ""
	_next()
