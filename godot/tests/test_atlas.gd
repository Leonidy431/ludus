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
	# The rejected frame never reaches the page the player reads as a
	# claim: every mention of it is a denial written by the chorus.
	for p in AtlasCore.page_count(data):
		var text := AtlasCore.page_text(data, p).to_lower()
		for w in ["мир — симуляция внутри", "железный аватар души"]:
			t._check(not text.contains(w), "page %d has no '%s'" % [p, w])
	_traces(t, data)


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
	t._check(not page.contains("Хачкар"), "the khachkar is not on it")
	t._check(AtlasCore.page_count(data, page) == 101, "one more page")
	t._check(AtlasCore.page_text(data, 100, page) == page,
		"the scribe's page follows node 99")
	t._check(AtlasCore.next_page(data, 100, page) == 0, "then the frame")


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
