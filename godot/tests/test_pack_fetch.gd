## Packs over the network (PackFetch, TABOO 0.018): a pack is accepted
## only when its size and SHA-256 match the manifest, a broken one is
## deleted and never mounted, and the request carries nothing about the
## player.  The network itself is not touched here: the download is
## stood in for by a file written where it would land.
extends RefCounted


func run(t: Object) -> void:
	var pf: Node = t.root.get_node("PackFetch")
	t._check(pf != null, "PackFetch is an autoload")
	var body := "pack bytes 1375".to_utf8_buffer()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(body)
	var sha := ctx.finish().hex_encode()
	var m := {"base": "https://example.invalid/", "packs": [
		{"id": "__test", "file": "x.pck", "bytes": body.size(),
			"sha256": sha}]}
	DirAccess.make_dir_recursive_absolute(pf.DIR)
	var part: String = pf._path("__test") + ".part"
	var f := FileAccess.open(part, FileAccess.WRITE)
	f.store_buffer(body)
	f.close()
	t._check(pf.verify(part, m.packs[0]), "a matching file verifies")
	t._check(pf.accept("__test", m) == "ready", "a matching pack is ready")
	t._check(FileAccess.file_exists(pf._path("__test")),
		"and lies in place")
	# A broken download: one byte changed.
	f = FileAccess.open(part, FileAccess.WRITE)
	f.store_buffer("pack bytes 1376".to_utf8_buffer())
	f.close()
	t._check(not pf.verify(part, m.packs[0]), "a changed byte fails")
	t._check(pf.accept("__test", m) == "failed: checksum",
		"a broken pack is refused")
	t._check(not FileAccess.file_exists(part), "and deleted")
	t._check(not pf.verify(pf._path("__missing"), m.packs[0]),
		"a missing file does not verify")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		pf._path("__test")))
	# Unknown ids change nothing; the shipped manifest is well formed.
	pf.want("__nothing")
	t._check(not pf.status.has("__nothing"), "an unknown pack is not asked")
	var shipped: Dictionary = pf.load_manifest()
	t._check(shipped.has("packs") and str(shipped.get("base", ""))
		.begins_with("https://github.com/Leonidy431/ludus/releases/"),
		"packs come from the project's own releases")
	for p in shipped.packs:
		t._check(str(p.get("sha256", "")).length() == 64,
			"pack %s has a SHA-256" % p.id)
	# Disk: over the limit, the oldest pack goes first, the kept one
	# stays.
	for n in ["__old", "__new"]:
		var w := FileAccess.open(pf._path(n), FileAccess.WRITE)
		w.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]))
		w.close()
	var gone: Array = pf.evict(12, "__new")
	t._check(gone == ["__old"], "LRU deletes the oldest pack: %s" % [gone])
	t._check(FileAccess.file_exists(pf._path("__new")),
		"the kept pack stays")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		pf._path("__new")))
	# Privacy: the request sends no id, no save, no telemetry.
	var code := ""
	for ln in FileAccess.get_file_as_string(
			"res://scripts/pack_fetch.gd").split("\n"):
		# Comments may name what is not sent; only code counts.
		if not ln.strip_edges().begins_with("#"):
			code += ln + "\n"
	for w in ["get_unique_id", "user://hub", "user://pilot",
			"set_custom_header", "custom_headers", "telemetry",
			"get_model_name"]:
		t._check(not w in code, "PackFetch sends nothing like " + w)
