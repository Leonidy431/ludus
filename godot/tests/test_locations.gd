## The 99 locations keep the standard of the evening-watch cell (CLAUDE.md
## TABOO 0.013) in the headset's own terms: every heart resolves in the
## game's cores, every placed thing's ground is recomputed here and kept
## off the heart and the passage, holy things only in their slot with
## both flags, no church word on a label, the light class right, the
## budget kept (TABOO 0.011).  Called from run_hub_tests.gd.
extends RefCounted


func run(t: Object) -> void:
	var data := LocationsCore.load_data()
	var locs: Array = data.get("locations", [])
	var things: Dictionary = data.get("things", {})
	t._check(locs.size() == 99, "K is 99 (%d)" % locs.size())
	t._check(int(data.get("pool_size", 0)) >= locs.size(),
		"the pool is not smaller than K")
	var ctx := LocationsCore.context()
	var ids := {}
	var kinds := {}
	for loc in locs:
		t._check(not ids.has(loc.id), loc.id + " once")
		ids[loc.id] = true
		kinds[loc.kind] = kinds.get(loc.kind, 0) + 1
		_location(t, loc, things, ctx)
	for k in kinds:
		t._check(kinds[k] <= 2, "%s: at most two places of a kind" % k)
	# The checks can fail: a made-up practice, a missing talk, a thing
	# on the heart and a church word on a label are all caught.
	t._check(not LocationsCore.heart_ok({"core": "RuleCore",
		"id": "communion"}, ctx), "a made-up practice is refused")
	t._check(not LocationsCore.heart_ok({"core": "MissionCore",
		"step": "dialogue", "npc": "anahit", "node": "nope"}, ctx),
		"a missing talk is refused")
	t._check(not LocationsCore.heart_ok({"core": "new", "id": "x",
		"constitution": "no line"}, ctx),
		"a new action without its Constitution line is refused")
	var on_heart := LocationsCore.rect_of({"pos": [0.0, 0.0, 0.3],
		"yaw": 0, "mount": "floor"}, {"state": "volume",
		"size_m": [0.5, 0.5, 0.5]})
	t._check(LocationsCore.gap(Vector2.ZERO, on_heart)
		< LocationsCore.CLEAR_M, "a thing at the heart is caught")
	# The operator lifted the stop-list on 2026-10-02: the finder still
	# sees the word, the gate lets the label through.
	t._check(LocationsCore.find_church_word("Святой ключ") != "",
		"the stop-list still finds a church word on a label")
	t._check(not LocationsCore.has_church_word("Святой ключ"),
		"and the lifted gate lets it through")


func _location(t: Object, loc: Dictionary, things: Dictionary,
		ctx: Dictionary) -> void:
	var id: String = loc.id
	var h: Dictionary = loc.heart
	t._check(LocationsCore.heart_ok(h, ctx), id + " heart resolves: "
		+ str(h.core) + " " + str(h.get("id", "")))
	t._check(not LocationsCore.has_church_word(loc.title_ru),
		id + " title has no church word")
	t._check(not LocationsCore.has_church_word(h.ru),
		id + " heart hint has no church word")
	t._check(String(loc.constitution).contains("ФОРМА")
		and String(loc.constitution).contains("ДЕЙСТВИЕ")
		and String(loc.constitution).contains("ЦЕЛЬ"),
		id + " constitution line")
	var light: Dictionary = loc.light
	var span: Array = LocationsCore.LIGHT_K.get(light["class"], [0, 0])
	t._check(int(light.kelvin) >= int(span[0])
		and int(light.kelvin) <= int(span[1]), id + " light class and K")
	var holy = loc.holy_place
	if light["class"] == "lampada":
		t._check(holy != null, id + " lampada only at a holy thing")
	if holy != null:
		t._check(holy.noInteract and holy.noLoot and not holy.tag,
			id + " holy flags, no tag")
	t._check(loc.unplaced.is_empty(), id + " every thing has a slot")
	t._check(loc.slots.size() == loc.wishlist.size(),
		id + " one slot per wished thing")
	var shell: Dictionary = loc.shell
	var w := float(shell.size_m[0])
	var d := float(shell.size_m[1])
	var bounds := Rect2(-w / 2.0 - 0.001, -d / 2.0 - 0.001, w + 0.002,
		d + 0.002)
	var heart := Vector2(float(shell.heart_at[0]), float(shell.heart_at[2]))
	var p: Array = shell.passage
	var passage := Rect2(float(p[0]), float(p[1]), float(p[2]) - float(p[0]),
		float(p[3]) - float(p[1]))
	var layers := {"wall": [], "top": [], "ground": []}
	var count := {}
	for s in loc.slots:
		var th: Dictionary = things[s.object]
		count[s.object] = count.get(s.object, 0) + 1
		var r := LocationsCore.rect_of(s, th)
		t._check(bounds.encloses(r), "%s: %s inside the place" % [id,
			s.object])
		var holy_thing := th.holy != null
		t._check((s.mount == "holy") == holy_thing,
			"%s: %s holy only in its slot" % [id, s.object])
		if not holy_thing:
			t._check(not LocationsCore.has_church_word(th.ru),
				"%s: tag %s has no church word" % [id, th.ru])
		if loc.shell.type == "underwater":
			t._check(th.state == "volume" or holy_thing,
				"%s: %s is a volume under water" % [id, s.object])
		if s.mount == "heart":
			continue
		t._check(LocationsCore.gap(heart, r) >= LocationsCore.CLEAR_M
			- 0.001, "%s: %s clear of the heart (%.2f m)" % [id, s.object,
				LocationsCore.gap(heart, r)])
		var layer := LocationsCore.layer_of(s)
		if layer == "ground":
			t._check(not _cross(r, passage),
				"%s: %s off the passage" % [id, s.object])
		for q in layers[layer]:
			t._check(not _cross(r, q), "%s: %s does not overlap" % [id,
				s.object])
		layers[layer].append(r)
	for k in count:
		t._check(count[k] <= 2, "%s: at most two states of %s" % [id, k])
	var b: Dictionary = loc.budget
	t._check(b.ok and int(b.draw_calls_merged) <= 100,
		id + " within the draw-call budget once cards are merged")
	for k in loc.wishlist:
		var th: Dictionary = things[k]
		if th.tris != null:
			t._check(int(th.tris) <= 5000, "%s: %s <= 5000 triangles"
				% [id, k])
		if th.in_apk:
			var path := LocationsCore.model_path(th)
			t._check(ResourceLoader.exists(path), "%s: %s ships (%s)"
				% [id, k, path])


## Two rectangles share ground (touching edges do not count).
func _cross(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x - 0.000001 \
		and b.position.x < a.end.x - 0.000001 \
		and a.position.y < b.end.y - 0.000001 \
		and b.position.y < a.end.y - 0.000001
