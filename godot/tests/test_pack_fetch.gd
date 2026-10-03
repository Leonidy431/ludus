## Packs over the network (PackFetch, TABOO 0.018): a pack is accepted
## only when its size and SHA-256 match the manifest, a broken one is
## deleted and never mounted, a manifest entry that could climb out of
## the packs folder is refused, each version has its own file, half
## downloads and old versions go at the next start, and the request
## carries nothing about the player.  The network itself is not
## touched here: the download is stood in for by a file written where
## it would land.  Called from run_hub_tests.gd.
extends RefCounted

const DIR := "user://packs_fetch_test"


func run(t: Object) -> void:
	var pf: Node = t.root.get_node("PackFetch")
	t._check(pf != null, "PackFetch is an autoload")
	DirAccess.make_dir_recursive_absolute(DIR)
	var body := "pack bytes 1375".to_utf8_buffer()
	var sha := _sha(body)
	var p := {"id": "__test", "file": "packs-__test-v1/__test-v1.pck",
		"bytes": body.size(), "sha256": sha}
	var m := {"base": "https://example.invalid/", "packs": [p]}
	t._check(pf.valid_entry(p), "a well formed entry is valid")
	t._check(pf.local_name(p) == "__test-%s.pck" % sha.left(8),
		"the file name carries the hash")
	var final: String = pf.local_path(p, DIR)
	var part := final + ".part"
	_put(part, body)
	t._check(pf.verify(part, p), "a matching file verifies")
	t._check(pf.accept("__test", m, DIR) == "ready",
		"a matching pack is ready")
	t._check(FileAccess.file_exists(final) and not FileAccess.file_exists(
		part), "and lies in place")
	_put(part, body)
	t._check(pf.accept("__test", m, DIR) == "ready"
		and not FileAccess.file_exists(part),
		"the same version fetched twice is kept once")
	# A broken download: one byte changed.
	_put(part, "pack bytes 1376".to_utf8_buffer())
	t._check(not pf.verify(part, p), "a changed byte fails")
	t._check(pf.accept("__test", m, DIR) == "failed: checksum",
		"a broken pack is refused")
	t._check(not FileAccess.file_exists(part), "and deleted")
	t._check(not pf.verify(DIR.path_join("__missing.pck"), p),
		"a missing file does not verify")

	# A new version of the same id lands in its own file, beside the
	# mounted one, never over it.
	var body2 := "pack bytes 2026".to_utf8_buffer()
	var p2 := {"id": "__test", "file": "packs-__test-v2/__test-v2.pck",
		"bytes": body2.size(), "sha256": _sha(body2)}
	var m2 := {"packs": [p2]}
	var final2: String = pf.local_path(p2, DIR)
	t._check(final2 != final, "a new version has a new file name")
	_put(final2 + ".part", body2)
	t._check(pf.accept("__test", m2, DIR) == "ready"
		and pf.verify(final, p), "the old version is left untouched")
	# At the next start the old version and half downloads go first.
	_put(DIR.path_join("__half.pck.part"), body)
	var r: Dictionary = pf.prepare(DIR, m2, 1 << 20)
	t._check(r.mount == [final2], "only the new version is mounted: %s"
		% [r.mount])
	t._check(not FileAccess.file_exists(final)
		and r.removed.get(final.get_file(), "") == "not in the manifest",
		"the old version is deleted at start")
	t._check(not FileAccess.file_exists(DIR.path_join("__half.pck.part")),
		"a half download is deleted at start")

	# Entries that could climb out of the packs folder are refused.
	var bad_ids := ["../x", "a/b", "..", "", "a\\b", "x:y"]
	for id in bad_ids:
		var e := p.duplicate()
		e.id = id
		t._check(not pf.valid_entry(e), "id %s is refused" % id)
		t._check(pf.accept(id, {"packs": [e]}, DIR) == "failed: manifest",
			"accept refuses id %s" % id)
	for file in ["../x.pck", "a/../x.pck", "/x.pck", "a/b/c.pck",
			"https://evil/x.pck", "a\\x.pck", ""]:
		var e := p.duplicate()
		e.file = file
		t._check(not pf.valid_entry(e), "file %s is refused" % file)
	var e_sha := p.duplicate()
	e_sha.sha256 = "abc"
	t._check(not pf.valid_entry(e_sha), "a short hash is refused")
	var e_bytes := p.duplicate()
	e_bytes.bytes = 0
	t._check(not pf.valid_entry(e_bytes), "a zero size is refused")
	pf.want("../x")
	t._check(not pf.status.has("../x"), "a bad id is never asked")

	# Unknown ids change nothing; the shipped manifest is well formed.
	pf.want("__nothing")
	t._check(not pf.status.has("__nothing"), "an unknown pack is not asked")
	var shipped: Dictionary = pf.load_manifest()
	t._check(shipped.has("packs") and str(shipped.get("base", ""))
		.begins_with("https://github.com/Leonidy431/ludus/releases/"),
		"packs come from the project's own releases")
	for sp in shipped.packs:
		t._check(pf.valid_entry(sp), "pack %s is well formed" % sp.id)

	# Disk: over the limit, the oldest pack goes first; ties in file
	# time are broken by name, so the order is fixed.
	for n in ["__a_old.pck", "__b_new.pck"]:
		_put(DIR.path_join(n), PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(final2))
	var gone: Array = pf.evict(12, DIR)
	t._check(gone == ["__a_old.pck"], "LRU deletes the oldest pack: %s"
		% [gone])
	t._check(FileAccess.file_exists(DIR.path_join("__b_new.pck")),
		"the rest stays")
	# Eviction happens only at start, before mounting: the code that
	# finishes a download never calls it.
	var src := FileAccess.get_file_as_string("res://scripts/pack_fetch.gd")
	var finish := src.substr(src.find("func _finish("))
	t._check(not "evict(" in finish, "no eviction after a download")
	for n in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
			DIR.path_join(n)))

	# Privacy: the request sends no id, no save, no telemetry.
	var code := ""
	for ln in src.split("\n"):
		# Comments may name what is not sent; only code counts.
		if not ln.strip_edges().begins_with("#"):
			code += ln + "\n"
	for w in ["get_unique_id", "user://hub", "user://pilot",
			"set_custom_header", "custom_headers", "telemetry",
			"get_model_name"]:
		t._check(not w in code, "PackFetch sends nothing like " + w)


func _sha(b: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(b)
	return ctx.finish().hex_encode()


func _put(path: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()
