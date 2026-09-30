## The things of the 99 locations that come from the 99 cloned repos
## (CLAUDE.md TABOO 0.013 p. 3, 0.012, 0.1; track B): every file a
## location names is in the build and loads as a texture, every thing is
## on that location's wishlist and is not holy, a room or a cave shows
## no variant that needs sand or grass, and only the variants a location
## shows are in the APK (TABOO 0.011).  Called from run_tests.gd.
extends RefCounted

const ITEMS := "res://data/location-items.json"
const LOCATIONS := "res://data/locations-99.json"
const INDOOR := ["room", "cave"]


func _json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


func run(t: Object) -> void:
	var items := _json(ITEMS)
	var data := _json(LOCATIONS)
	t._check(not items.is_empty(), "location-items.json reads")
	var by_id := {}
	for loc in data.get("locations", []):
		by_id[loc.id] = loc
	var things: Dictionary = data.get("things", {})
	var kits: Dictionary = items.get("kits", {})
	t._check(kits.size() > 0, "at least one kit passed by eye")
	var shown := {}
	for loc_id in items.get("locations", {}):
		t._check(by_id.has(loc_id), "%s is one of the 99" % loc_id)
		if not by_id.has(loc_id):
			continue
		var loc: Dictionary = by_id[loc_id]
		var indoor: bool = loc.shell.type in INDOOR
		for row in items.locations[loc_id]:
			var what := "%s/%s" % [loc_id, row.item]
			t._check(row.item in loc.wishlist, what + " is wished there")
			t._check(things.has(row.item) and things[row.item].holy == null,
				what + " is not holy")
			t._check(kits.has(row.kit), what + " names a listed kit")
			t._check(row.item in kits.get(row.kit, {}).get("serves", []),
				what + " is served by its kit")
			t._check(row.files.size() > 0
				and row.files.size() == row.settings.size(),
				what + " names its variants")
			for i in row.files.size():
				var path: String = "%s/%s" % [row.kit_dir, row.files[i]]
				shown[path] = true
				t._check(ResourceLoader.exists(path), path + " is imported")
				t._check(load(path) is Texture2D, path + " is a texture")
				t._check(not indoor or row.settings[i] == "any",
					what + ": no sand or grass indoors")
	t._check(shown.size() > 0, "some variants are shown")
	# Only what a location shows is copied into the build: every file of
	# a kit folder is named by some location.
	for kit in kits.values():
		var dir := DirAccess.open(kit.dir)
		t._check(dir != null, "%s exists" % kit.dir)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".png"):
				t._check(shown.has("%s/%s" % [kit.dir, f]),
					"%s/%s is shown by a location" % [kit.dir, f])
