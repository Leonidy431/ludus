## Data packs beside the APK (DataPacks; docs/decisions/SIZE_STRATEGIES_
## 7_2026-10-02.md): an English voice pack is found, mounted and read; a
## missing or broken pack is refused without a crash; a pack never
## replaces the game's own files; the store's expansion file of the
## highest version is the one picked.  A pack in the packs folder is
## mounted only when the manifest names it and its size and SHA-256
## match; a broken copy, an old version, a stray file and a half
## download are deleted, never mounted (TABOO 0.018 item 5).  Called
## from run_hub_tests.gd.
##
## The test pack stays mounted for the rest of the run (Godot has no
## unmount); its paths live under res://audio/voice/en/__test_npc only.
extends RefCounted

const DIR := "user://packs_test"


func run(t: Object) -> void:
	var dp: Node = t.root.get_node("DataPacks")
	t._check(dp != null, "DataPacks is an autoload")
	if dp == null:
		return

	# The store's expansion file: main.<version>.<package>.obb, highest.
	t._check(dp.pick_obb(["main.7.org.ludus.dive.obb",
		"main.181.org.ludus.dive.obb", "patch.200.org.ludus.dive.obb",
		"main.x.org.ludus.dive.obb", "main.300.other.app.obb"])
		== "main.181.org.ludus.dive.obb", "the highest main OBB is picked")
	t._check(dp.pick_obb([]) == "", "no OBB, no pick")

	# A missing pack and a file that is not a pack are refused calmly.
	t._check(not dp.mount(DIR.path_join("absent.pck")),
		"a missing pack is refused")
	DirAccess.make_dir_recursive_absolute(DIR)
	var junk := FileAccess.open(DIR.path_join("junk.bin"),
		FileAccess.WRITE)
	junk.store_string("not a pack")
	junk.close()
	t._check(not dp.mount(DIR.path_join("junk.bin")),
		"a file that is not a pack is refused")

	t._check(not dp.has_voice("en") or dp.mounted.size() > 0,
		"no English voice before a pack, unless one is installed")

	# Build an English voice pack the way the export will: pack.json, a
	# line, and a file that tries to replace the game's own data.
	var src := DIR.path_join("src")
	DirAccess.make_dir_recursive_absolute(src)
	_write(src.path_join("pack.json"),
		JSON.stringify({"pack": "voice", "lang": "en"}))
	_write(src.path_join("n1.ogg"), "OggS test bytes")
	_write(src.path_join("cw.json"), "{\"replaced\": true}")
	var original := FileAccess.get_file_as_string(
		"res://data/church-words.json")
	var pk := PCKPacker.new()
	var built := src.path_join("voice-en.pck")
	t._check(pk.pck_start(built) == OK, "a test pack can be written")
	pk.add_file("res://audio/voice/en/pack.json",
		src.path_join("pack.json"))
	pk.add_file("res://audio/voice/en/__test_npc/n1.ogg",
		src.path_join("n1.ogg"))
	pk.add_file("res://data/church-words.json", src.path_join("cw.json"))
	t._check(pk.flush() == OK, "the test pack is flushed")

	# The manifest names it by size and hash; a second entry stands for
	# a download that was spoiled on the way.
	var bytes := FileAccess.get_file_as_bytes(built)
	var good := {"id": "voice-en", "file": "packs-voice-en-v1/x.pck",
		"bytes": bytes.size(), "sha256": _sha(bytes)}
	var bad := {"id": "voice-xx", "file": "x.pck",
		"bytes": bytes.size(), "sha256": _sha(bytes)}
	var m := {"packs": [good, bad, {"id": "../x", "file": "x.pck",
		"bytes": 1, "sha256": _sha(bytes)}]}
	var pck := DIR.path_join("voice-en-%s.pck" % _sha(bytes).left(8))
	_put(pck, bytes)
	var spoiled := bytes.duplicate()
	spoiled[spoiled.size() - 1] = spoiled[spoiled.size() - 1] ^ 0xff
	var broken := DIR.path_join("voice-xx-%s.pck"
		% str(bad.sha256).left(8))
	_put(broken, spoiled)
	var old := DIR.path_join("voice-en-00000000.pck")
	_put(old, bytes)
	var stray := DIR.path_join("stray.pck")
	_put(stray, bytes)
	var part := DIR.path_join("voice-en-%s.pck.part"
		% _sha(bytes).left(8))
	_put(part, bytes.slice(0, 10))

	dp.mount_dir(DIR, m)
	t._check(not ProjectSettings.globalize_path(broken) in dp.mounted,
		"a spoiled .pck is not mounted")
	t._check(not FileAccess.file_exists(broken), "and is deleted")
	t._check(dp.refused.get(ProjectSettings.globalize_path(broken), "")
		== "checksum", "the reason is the checksum")
	t._check(not FileAccess.file_exists(old)
		and not ProjectSettings.globalize_path(old) in dp.mounted,
		"an old version is deleted before mounting")
	t._check(not FileAccess.file_exists(stray),
		"a pack the manifest does not name is deleted")
	t._check(not FileAccess.file_exists(part),
		"a half download is deleted at start")
	t._check(not FileAccess.file_exists(DIR.path_join("junk.bin")),
		"a stray file of the folder is deleted")
	t._check(ProjectSettings.globalize_path(pck) in dp.mounted,
		"the English voice pack is mounted")
	t._check(dp.has_voice("en"), "the English voice is there")
	t._check(not dp.has_voice("ru"), "no Russian voice without its pack")
	t._check(dp.voice_path("en", "__test_npc", "n1")
		== "res://audio/voice/en/__test_npc/n1.ogg",
		"a recorded line is found by NPC and node")
	t._check(dp.voice_path("en", "__test_npc", "n2") == "",
		"a line not recorded gives the text alone")
	t._check(FileAccess.get_file_as_string("res://data/church-words.json")
		== original, "a pack never replaces the game's own files")
	var before: int = dp.mounted.size()
	dp.mount_dir(DIR, m)
	t._check(dp.mounted.size() == before, "a pack is mounted once")

	# No network: the module reads files only.
	var code := FileAccess.get_file_as_string("res://scripts/data_packs.gd")
	for api in ["HTTPRequest", "HTTPClient", "WebSocket", "StreamPeer",
			"PacketPeer"]:
		t._check(not api in code, "DataPacks uses no network: " + api)


func _sha(b: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(b)
	return ctx.finish().hex_encode()


func _put(path: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
