## The Water Atlas at the lectern (TABOO 0.03).  Called from
## run_hub_tests.gd.
extends RefCounted


func run(t: Object) -> void:
	var data := AtlasCore.load_data()
	t._check(data.nodes.size() == 99, "99 nodes (%d)" % data.nodes.size())
	var seen := {}
	for node in data.nodes:
		seen[int(node.n)] = true
		var c: String = node.constitution
		t._check(c.contains("ФОРМА") and c.contains("ДЕЙСТВИЕ")
			and c.contains("ЦЕЛЬ"), "#%d has its Constitution line" % node.n)
		t._check(node.status in ["принят", "адаптирован", "заменён"],
			"#%d status" % node.n)
	t._check(seen.size() == 99, "numbers 1..99 once each")
	t._check(AtlasCore.page_text(data, 0).contains("Каталанский атлас"),
		"the frame opens with the Catalan Atlas")
	t._check(AtlasCore.page_text(data, 99).contains("99."),
		"the last page is node 99")
	t._check(AtlasCore.next_page(data, 99) == 0, "after 99, the frame")
	# The gate on reincarnation, souls and "simulation" was lifted by
	# the operator on 2026-10-02 (CLAUDE.md, amendment to TABOO 0.03).
	_traces(t, data)
	_web_parity(t, data)


## The knight's traces and the chronicle (AtlasTraces, TABOO 0.03).
func _traces(t: Object, data: Dictionary) -> void:
	t._check(AtlasTraces.options(data).size() == 2, "two chronicle options")
	# The chronicle is written once.
	t._check(AtlasTraces.write_chronicle(data, null, "spare") == "spare",
		"first choice is written")
	t._check(AtlasTraces.write_chronicle(data, "spare", "vault") == "spare",
		"a written chronicle does not change")
	t._check(AtlasTraces.write_chronicle(data, null, "nonsense") == "",
		"an unknown choice writes nothing")
	var before := AtlasTraces.place(data, "")
	t._check(before.size() == data.traces.size(),
		"no passage before the chronicle is written")
	var spare := AtlasTraces.place(data, "spare")
	var vault := AtlasTraces.place(data, "vault")
	t._check(spare.size() == data.traces.size() + 1, "the passage is drawn")
	t._check(JSON.stringify(spare) == JSON.stringify(
		AtlasTraces.place(data, "spare")), "placing is deterministic")
	var moved := false
	for i in data.traces.size():
		if Vector2(spare[i].x, spare[i].z) != Vector2(vault[i].x, vault[i].z):
			moved = true
	t._check(moved, "the chronicle's choice moves the traces")
	t._check(spare[-1].shape == "spare" and vault[-1].shape == "vault",
		"the passage is whole or fallen by the choice")
	var holy := 0
	for p in spare:
		# Every trace lies on the floor of the dive line near its depth.
		var floor_d := DiveCore.floor_depth(p.x, p.z)
		t._check(absf(floor_d - p.depth) < 0.01, "%s on the floor" % p.id)
		var want: float = p.get("depth", 0.0) if p.kind == "passage" \
			else _trace(data, p.id).depth
		t._check(absf(p.depth - want) < 3.0,
			"%s near %.0f m (%.1f)" % [p.id, want, p.depth])
		if p.holy:
			holy += 1
			t._check(p.loot == null, "%s is never loot" % p.id)
	t._check(holy == 1, "one holy thing: the khachkar")
	t._check(AtlasTraces.holy_points(spare).size() == 1,
		"the console fades at the khachkar")
	# The arm and the bag.
	var bag := {"kept": [], "released": [], "handed_over": []}
	var khachkar := _find(spare, "khachkar")
	var r := AtlasTraces.take(bag, khachkar)
	t._check(not r.reach, "the arm does not touch the khachkar")
	t._check(r.text == AtlasTraces.UNKNOWN_RU, "the protocol: type unknown")
	t._check(not r.bag.has("atlas") or r.bag.atlas.is_empty(),
		"nothing of the khachkar goes anywhere")
	var diary := _find(spare, "diary")
	r = AtlasTraces.take(bag, diary)
	t._check(r.reach and r.bag.atlas == ["diary"], "the diary to the scribe")
	t._check(r.bag.kept.is_empty() and r.bag.handed_over.is_empty(),
		"not into the bag, not into the settlement finds")
	t._check(bag.get("atlas", []).is_empty(), "take does not change its input")
	var again := AtlasTraces.take(r.bag, diary)
	t._check(again.bag.atlas.size() == 1, "handed over once")
	var passage := AtlasTraces.take(bag, _find(spare, "passage"))
	t._check(passage.reach and not passage.bag.has("atlas"),
		"the passage is looked at, not taken")
	t._check(not r.has("form") and not r.has("attribute"),
		"taking changes no attribute")
	# The scribe's page.
	t._check(AtlasTraces.scribe_page(data, []) == "", "no page before")
	var page := AtlasTraces.scribe_page(data, ["shield", "diary", "khachkar"])
	t._check(page.find("Дневник") < page.find("Щит") and page.find("Дневник")
		> 0, "the scribe's page lists the things in the list's order")
	t._check(not page.contains("Кайрак"), "the khachkar is not on it")
	t._check(AtlasCore.page_count(data, page) == 101, "one more page")
	t._check(AtlasCore.page_text(data, 100, page) == page,
		"the scribe's page follows node 99")
	t._check(AtlasCore.next_page(data, 100, page) == 0, "then the frame")


## The web dive places the same things on the same floor
## (public/ludus/dive/dive-atlas.js, fixture written by
## scripts/godot/make_atlas_fixture.js): the traces for every chronicle
## choice and the own drawings of the shore, as dive.gd builds them.
func _web_parity(t: Object, data: Dictionary) -> void:
	var f := FileAccess.open("res://tests/fixtures/atlas-traces.json",
		FileAccess.READ)
	t._check(f != null, "web atlas fixture present")
	if f == null:
		return
	var web: Dictionary = JSON.parse_string(f.get_as_text())
	for choice in ["", "spare", "vault"]:
		var ours := AtlasTraces.place(data, choice)
		var theirs: Array = web.traces[choice]
		t._check(ours.size() == theirs.size(),
			"web '%s': %d things" % [choice, theirs.size()])
		for i in mini(ours.size(), theirs.size()):
			var a: Dictionary = ours[i]
			var b: Dictionary = theirs[i]
			t._check(a.id == b.id and a.shape == b.shape
				and absf(a.x - b.x) < 1e-6 and absf(a.z - b.z) < 1e-6
				and absf(a.depth - b.depth) < 1e-6
				and absf(a.yaw - b.yaw) < 1e-6,
				"web '%s' %s on the same spot" % [choice, a.id])
	# The own drawings: the very placement _build_own_drawings runs.
	var dive := preload("res://scripts/dive.gd")
	var k := 0
	var same := 0
	for kit in dive.OWN_DRAWINGS:
		var spots: Array = dive.own_drawing_spots(kit)
		t._check(dive._kit_files("res://art/derived/%s" % kit.dir,
			kit.kit).size() == 12, "%s: 12 variants" % kit.kit)
		t._check(spots.size() == int(kit.n), "%s: %d drawings" % [kit.kit,
			int(kit.n)])
		for spot in spots:
			if k < web.drawings.size():
				var w: Dictionary = web.drawings[k]
				if w.kit == kit.kit and absf(w.x - spot.x) < 1e-6 \
						and absf(w.z - spot.z) < 1e-6 \
						and absf(w.centreDepth - spot.y) < 1e-6 \
						and w.file == str(spot.file).get_file():
					same += 1
			k += 1
	t._check(k == web.drawings.size() and same == k,
		"web own drawings on the same spots (%d of %d)" % [same, k])
	_fish_parity(t, web)


## The fish of our own drawing (DEF-056): every fish of a school with a
## 12/12 kit shows the same cell, at the same size and on the same spot
## in the web and in the headset (FishDrawings, fish_drawings.gd), at
## several times and from three eyes; only 12/12 kits swim; over time
## every cell of a kit is shown, neighbours never repeat, and a view
## from below or above appears only to a steep eye.
func _fish_parity(t: Object, web: Dictionary) -> void:
	var index := FishDrawings.load_index()
	t._check(not index.is_empty(), "fish drawings index present")
	var fish: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/issyk-kul-fish.json"))
	var by_id := {}
	for s in DiveCore.fish_schools(fish.fish):
		var kit := FishDrawings.kit_of(index, str(s.id))
		if kit.is_empty():
			continue
		by_id[s.id] = s
		t._check(kit.files.size() == 12 and kit.fish_px.size() == 12
			and kit.views.size() == 12 and kit.rest.size() == 12
			and kit.age.size() == 12 and kit.foot.size() == 12,
			"%s: 12 variants" % s.id)
		t._check(ResourceLoader.exists(FishDrawings.ART + kit.atlas),
			"%s: atlas in the headset" % s.id)
		_fish_rule(t, index, kit, s)
	var theirs: Array = web.get("fish", [])
	var same := 0
	for w in theirs:
		if not by_id.has(w.id):
			continue
		var s: Dictionary = by_id[w.id]
		var kit := FishDrawings.kit_of(index, str(s.id))
		var eye: Dictionary = w.eye if w.eye is Dictionary else {}
		var p := FishDrawings.spot(index, kit, s, int(w.i), float(w.t), eye)
		if int(p.v) == int(w.v) and p.file == w.file \
				and absf(p.size - float(w.size)) < 1e-6 \
				and bool(p.top) == bool(w.top) \
				and absf(p.x - float(w.x)) < 1e-6 \
				and absf(p.z - float(w.z)) < 1e-6 \
				and absf(p.depth - float(w.depth)) < 1e-6:
			same += 1
	t._check(theirs.size() > 0 and same == theirs.size(),
		"web own fish: same cell, size and spot (%d of %d)" % [same,
			theirs.size()])


## The rule itself, over three cycles of the queues and three eyes.
func _fish_rule(t: Object, index: Dictionary, kit: Dictionary,
		s: Dictionary) -> void:
	var seen := {}
	var repeats := 0
	var wrong_view := 0
	var eyes := [{},
		{"x": s.centre.x, "z": s.centre.z, "depth": s.centre.depth + 30.0},
		{"x": s.centre.x, "z": s.centre.z,
			"depth": maxf(0.3, s.centre.depth - 30.0)}]
	var tt := 0.5
	while tt < FishDrawings.PERIOD_S * 36.0:
		for eye in eyes:
			var spots := FishDrawings.school_spots(index, kit, s, tt, eye)
			for i in spots.size():
				var p: Dictionary = spots[i]
				seen[p.v] = true
				if i > 0 and int(spots[i - 1].v) == int(p.v):
					repeats += 1
				var v := FishDrawings.view(eye, p)
				if p.top and v == "side":
					wrong_view += 1
		tt += 3.0
	t._check(seen.size() == 12,
		"%s: all 12 cells shown over time (%d)" % [s.id, seen.size()])
	t._check(repeats == 0, "%s: neighbours never repeat" % s.id)
	t._check(wrong_view == 0,
		"%s: views from below or above only to a steep eye" % s.id)


func _find(placed: Array, id: String) -> Dictionary:
	for p in placed:
		if p.id == id:
			return p
	return {}


func _trace(data: Dictionary, id: String) -> Dictionary:
	for tr in data.traces:
		if tr.id == id:
			return tr
	return {}
