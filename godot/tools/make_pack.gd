## Build a pack (TABOO 0.018) from a folder of sources: every file under
## --src goes into a Godot .pck at res://<its path under src>, and the
## pack's size and SHA-256 are printed for the manifest line of
## data/packs.json.  The files are packed as they are (JPEG atlases,
## JSON, Ogg): the game reads them with Image.load_jpg_from_buffer and
## friends, so no import step is needed.
##
##     godot --headless --path godot -s res://tools/make_pack.gd -- \
##         --src=packs/closeups-ep1 --out=../build/packs/closeups-ep1.pck
extends SceneTree


func _initialize() -> void:
	var src := ""
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--src="):
			src = a.trim_prefix("--src=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var root := ProjectSettings.globalize_path("res://").path_join(src) \
		.simplify_path()
	out = ProjectSettings.globalize_path("res://").path_join(out) \
		.simplify_path()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var files := _walk(root, "")
	files.sort()
	var pk := PCKPacker.new()
	if pk.pck_start(out) != OK:
		printerr("make_pack: cannot write ", out)
		quit(1)
		return
	for rel in files:
		pk.add_file("res://" + rel, root.path_join(rel))
	pk.flush()
	var f := FileAccess.open(out, FileAccess.READ)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		ctx.update(f.get_buffer(1 << 20))
	print("PACK %s files=%d bytes=%d sha256=%s" % [out.get_file(),
		files.size(), f.get_length(), ctx.finish().hex_encode()])
	quit(0)


func _walk(root: String, rel: String) -> Array:
	var out := []
	var d := DirAccess.open(root.path_join(rel))
	for n in d.get_files():
		if n != ".gdignore":
			out.append(rel.path_join(n) if rel != "" else n)
	for n in d.get_directories():
		out.append_array(_walk(root, rel.path_join(n) if rel != "" else n))
	return out
