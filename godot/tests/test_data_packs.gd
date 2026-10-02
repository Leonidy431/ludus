## Data packs beside the APK (DataPacks; docs/decisions/SIZE_STRATEGIES_
## 7_2026-10-02.md): an English voice pack is found, mounted and read; a
## missing or broken pack is refused without a crash; a pack never
## replaces the game's own files; the store's expansion file of the
## highest version is the one picked.  Called from run_hub_tests.gd.
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
	var pck := DIR.path_join("voice-en.pck")
	t._check(pk.pck_start(pck) == OK, "a test pack can be written")
	pk.add_file("res://audio/voice/en/pack.json",
		src.path_join("pack.json"))
	pk.add_file("res://audio/voice/en/__test_npc/n1.ogg",
		src.path_join("n1.ogg"))
	pk.add_file("res://data/church-words.json", src.path_join("cw.json"))
	t._check(pk.flush() == OK, "the test pack is flushed")

	dp.mount_dir(DIR)
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
	dp.mount_dir(DIR)
	t._check(dp.mounted.size() == before, "a pack is mounted once")

	# No network: the module reads files only.
	var code := FileAccess.get_file_as_string("res://scripts/data_packs.gd")
	for api in ["HTTPRequest", "HTTPClient", "WebSocket", "StreamPeer",
			"PacketPeer"]:
		t._check(not api in code, "DataPacks uses no network: " + api)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
