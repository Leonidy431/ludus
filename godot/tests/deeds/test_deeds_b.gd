## The craft of the water group (deeds_b.gd): for each act the right
## order closes it, each wrong or early step answers and leaves it open,
## and the same input gives the same output.  Called from
## test_place_deeds.gd.
##
## The water acts read the lake from its data (blind spot 14 of docs/
## BLINDSPOTS_CODE_BREAKTHROUGH_2026-10-01.md): _lake() works the numbers
## out here again, from lake-objects-99.json and DiveCore, and fails
## when a line or a reply of take-core or read-waterline says another
## number, or keeps a "{name}" the data did not fill.
extends RefCounted

const DeedsGraph := preload("res://tests/deeds_graph.gd")

## The right order of every act, by button id.
const RIGHT := {
	"share-water": ["measure", "open_upper", "shut", "open_lower", "shut"],
	"carry-archive-up": ["look", "chest", "case", "chronicle", "sack"],
	"test-ice": ["listen", "probe_edge", "tie_rope", "probe_ahead", "step"],
	"take-core": ["flat", "tube", "lift", "label", "basket"],
	"read-waterline": ["gauge", "marks", "compare", "stake", "cord"],
}
## Mistakes that are never right, by act.
const WRONG := {
	"share-water": ["open_wide"],
	"carry-archive-up": ["all"],
	"test-ice": ["camel", "shortcut"],
	"take-core": ["scoop", "ask", "spare"],
	"read-waterline": ["today"],
}


func run(t: Object) -> void:
	var ids: Array = load("res://scripts/deeds/deeds_b.gd").ids()
	t._check(ids.size() == 5, "group b owns five acts")
	for id in ids:
		_act(t, id)
	_share(t)
	_lake(t)


func _walk(id: String, seq: Array) -> Dictionary:
	var s := PlaceDeeds.start(id)
	for c in seq:
		s = PlaceDeeds.choose(id, s, c)
	return s


func _act(t: Object, id: String) -> void:
	var right: Array = RIGHT[id]
	t._check(PlaceDeeds.has(id), id + ": group b owns it")
	var done := _walk(id, right)
	t._check(done.done == true and str(done.reply) != "",
		id + ": the right order closes it with a lesson")
	t._check(_walk(id, right) == done, id + ": the same steps, the same end")
	t._check(not _walk(id, right.slice(0, right.size() - 1)).done,
		id + ": one step short is still open")
	# Every button of every state has plain words.
	var s := PlaceDeeds.start(id)
	for i in right.size():
		for o in PlaceDeeds.options(id, s):
			t._check(str(o.text) != "", id + ": a button has words")
		t._check(PlaceDeeds.lines(id, s).size() > 0, id + ": it has lines")
		s = PlaceDeeds.choose(id, s, right[i])
	# A mistake answers and changes nothing else.
	for w in WRONG[id]:
		var st := PlaceDeeds.start(id)
		var after := PlaceDeeds.choose(id, st, w)
		t._check(str(after.reply) != "" and not after.done,
			"%s: %s answers and leaves the act open" % [id, w])
		var back := after.duplicate()
		back.reply = ""
		t._check(back == st, "%s: %s moves nothing" % [id, w])
	# Every step taken too early answers and moves nothing.
	if id != "share-water":
		for i in range(1, right.size()):
			var st := PlaceDeeds.start(id)
			var after := PlaceDeeds.choose(id, st, right[i])
			t._check(str(after.reply) != "" and after.step == 0
				and not after.done,
				"%s: %s too early only teaches" % [id, right[i]])
		var one := PlaceDeeds.choose(id, PlaceDeeds.start(id), right[0])
		var again := PlaceDeeds.choose(id, one, right[0])
		t._check(again.step == 1 and str(again.reply) != "",
			id + ": a step done twice does not count twice")
	var first := PlaceDeeds.choose(id, PlaceDeeds.start(id), right[0])
	t._check(PlaceDeeds.tick(id, first, 5.0, true) == first,
		id + ": nothing waits")


func _share(t: Object) -> void:
	var id := "share-water"
	# Either side may come first.
	var lower_first := _walk(id, ["measure", "open_lower", "shut",
		"open_upper", "shut"])
	t._check(lower_first.done, "share-water: the lower side may go first")
	# Unmeasured water is not let go.
	var s := PlaceDeeds.choose(id, PlaceDeeds.start(id), "open_upper")
	t._check(s.open == "" and str(s.reply) != "",
		"share-water: no water is let go before it is measured")
	# One side twice in a row is not the turn of the other.
	s = _walk(id, ["measure", "open_upper", "shut", "open_upper"])
	t._check(s.open == "" and str(s.reply) != "" and not s.done,
		"share-water: the same side twice only teaches")
	# Opening while open, shutting while shut.
	s = _walk(id, ["measure", "open_upper", "open_lower"])
	t._check(s.open == "upper" and str(s.reply) != "",
		"share-water: one sluice, one side at a time")
	s = PlaceDeeds.choose(id, PlaceDeeds.start(id), "shut")
	t._check(str(s.reply) != "" and not s.done,
		"share-water: shutting a shut sluice only answers")
	# Both sides served closes the act, one side does not.
	s = _walk(id, ["measure", "open_upper", "shut"])
	t._check(not s.done and s.served == ["upper"],
		"share-water: one side served is not enough")


## The lake's numbers in the water acts are the data's (blind spot 14).
func _lake(t: Object) -> void:
	var lake := {}
	var f := FileAccess.open("res://data/lake-objects-99.json",
		FileAccess.READ)
	for o in JSON.parse_string(f.get_as_text()).objects:
		lake[str(o.id)] = o
	var have: bool = lake.has("silt.slope.0") \
		and lake.has("terrace.shelf.2")
	t._check(have, "the silt plain and the drowned shore are in the "
		+ "lake's registry")
	if not have:
		return
	# The silt plain the place shows is the one whose depth is read.
	var slots := []
	for loc in LocationsCore.load_data().locations:
		if loc.id == "silt-core":
			for sl in loc.slots:
				slots.append(str(sl.object))
	t._check("silt.slope.0" in slots, "take-core: the silt plain stands "
		+ "in the silt-core place")
	var placed: Dictionary = DiveCore.place_objects(
		[lake["silt.slope.0"]])[0]
	var depth := int(round(float(placed.depth)))
	var temp := ("%.1f" % DiveCore.temperature(depth)).replace(".", ",")
	var thermo := int(DiveCore.THERMOCLINE_M)
	var band: Array = lake["terrace.shelf.2"].depth
	var lo := int(band[0])
	var hi := int(band[1])
	t._check(depth >= int(lake["silt.slope.0"].depth[0])
		and depth <= int(lake["silt.slope.0"].depth[1]),
		"take-core: the silt lies within its band (%d m)" % depth)
	var core := " ".join(PlaceDeeds.lines("take-core",
		PlaceDeeds.start("take-core")))
	t._check(("глубина %d м" % depth) in core and ("%s °C" % temp) in core
		and ("на %d м" % thermo) in core,
		"take-core: the panel reads %d m, %s °C, the layer at %d m: %s"
		% [depth, temp, thermo, core])
	var labelled := _walk("take-core", ["flat", "tube", "lift", "label"])
	t._check(("%d м, %s °C" % [depth, temp]) in str(labelled.reply),
		"take-core: the label says the data's depth and warmth: "
		+ str(labelled.reply))
	var tube := _walk("take-core", ["flat", "tube"])
	var side := "выше" if depth < thermo else "ниже"
	t._check(("на %d м, %s" % [depth, side]) in str(tube.reply),
		"take-core: the tube stands %s the layer: %s" % [side, tube.reply])
	var shore := " ".join(PlaceDeeds.lines("read-waterline",
		PlaceDeeds.start("read-waterline")))
	t._check(("%d–%d м" % [lo, hi]) in shore,
		"read-waterline: the old shore lies at %d–%d m: %s"
		% [lo, hi, shore])
	var marks := _walk("read-waterline", ["gauge", "marks"])
	t._check(("%d–%d м" % [lo, hi]) in str(marks.reply),
		"read-waterline: the marks name the old shore: "
		+ str(marks.reply))
	# Every number either act says, in any state, is one of the data's.
	var allowed := [str(depth), temp, str(thermo), str(lo), str(hi)]
	var num := RegEx.create_from_string("\\d+(,\\d+)?")
	for id in ["take-core", "read-waterline"]:
		var seen := 0
		for n in DeedsGraph.walk(id).nodes:
			for tx in n.lines + [n.reply]:
				t._check(not "{" in str(tx), id + ": a filled text: " + tx)
				for m in num.search_all(str(tx)):
					seen += 1
					t._check(m.get_string() in allowed,
						"%s: %s is the data's number: %s"
						% [id, m.get_string(), tx])
		t._check(seen > 0, id + ": it reads numbers from the data")
