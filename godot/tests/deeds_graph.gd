## The graph of the 26 acts of the place hearts, walked out of their own
## logic (scripts/deeds/*.gd), for the web build (blind spot 13 of
## docs/BLINDSPOTS_CODE_BREAKTHROUGH_2026-10-01.md;
## docs/HLD_DEEDS_WEB_PARITY_2026-10-02.md).
##
## The web build does not copy the acts by hand: it plays this graph,
## so "the same acts with the same words" is measured, not hoped.  The
## acts stay written once, in GDScript; public/ludus/data/place-deeds.json
## is their walk.  Every state reachable by the buttons, and by waiting
## still where an act asks to wait, becomes a node:
##   {lines, reply, done, options: [{id, text, disabled, reason}],
##    next: {button id: node index}, wait: {seconds, next}};
## in the file the texts are indices into one "strings" table.
## Node 0 of each act is its start.  A wait edge holds the least whole
## second of standing still that moves the act on; the headset counts
## the same seconds while the player stands still, the web page offers
## a "wait" button that counts them at once.  Nothing here is random:
## the same code always gives the same file (Constitution: no chance in
## outcomes).
##
## Write it:  godot --headless --path godot -s res://tests/export_deeds_graph.gd
## The test (tests/test_place_deeds.gd) fails when the file and the code
## part, so a change of an act without a new walk cannot pass CI.
##
## Constitution: ФОРМА (one act, written once, in the place's own craft)
## → ДЕЙСТВИЕ (the same steps and words in the headset and on the page)
## → ЦЕЛЬ (the lesson of the place is the same wherever it is learned).
extends RefCounted

## The file the web build reads, next to the game's other web data.
const OUT := "../public/ludus/data/place-deeds.json"
## A bound on the states of one act: a walk past it is a loop in an act.
const MAX_NODES := 4000
## The longest wait looked for, in seconds, and its step.
const MAX_WAIT := 600.0
const WAIT_STEP := 1.0


## The path of the web file on the host.
static func out_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join(
		OUT).simplify_path()


## The whole graph: {"version", "acts": {id: {"nodes": [...]}}}.
static func build() -> Dictionary:
	var acts := {}
	var ids: Array = PlaceDeeds.GROUPS.keys()
	ids.sort()
	var places := _places()
	for id in ids:
		acts[id] = walk(id)
		acts[id]["place"] = places.get(id, {})
	return {"version": 1,
		"source": "godot/scripts/deeds (tests/deeds_graph.gd)",
		"acts": acts}


## The nodes of one act, breadth-first from its start.
static func walk(id: String) -> Dictionary:
	var start := PlaceDeeds.start(id)
	var index := {var_to_str(start): 0}
	var states: Array = [start]
	var nodes: Array = []
	var i := 0
	var overflow := false
	while i < states.size():
		var s: Dictionary = states[i]
		var node := {"lines": PlaceDeeds.lines(id, s),
			"reply": str(s.get("reply", "")),
			"done": bool(s.get("done", false)),
			"options": [], "next": {}}
		for o in PlaceDeeds.options(id, s):
			node.options.append({"id": str(o.get("id", "")),
				"text": str(o.get("text", "")),
				"disabled": bool(o.get("disabled", false)),
				"reason": str(o.get("reason", ""))})
			if o.get("disabled", false):
				continue
			var nxt := PlaceDeeds.choose(id, s, str(o.id))
			node.next[str(o.id)] = _index_of(nxt, index, states)
		var w := _wait(id, s)
		if not w.is_empty():
			node["wait"] = {"seconds": w.seconds,
				"next": _index_of(w.state, index, states)}
		nodes.append(node)
		i += 1
		if states.size() > MAX_NODES:
			overflow = true
			break
	return {"nodes": nodes, "overflow": overflow}


## The place of each act as the heart's panel shows it above the steps:
## the place's name, the heart's own words and the place's teaching
## (LocationHeart.teaching, without the notes for the editors).
static func _places() -> Dictionary:
	var out := {}
	for loc in LocationsCore.load_data().get("locations", []):
		var act := PlaceDeeds.act_of(loc.get("heart", {}))
		if act == "" or out.has(act):
			continue
		out[act] = {"id": str(loc.id), "title": str(loc.get("title_ru", "")),
			"heart": str(loc.heart.get("ru", "")),
			"teaching": LocationHeart.teaching(loc)}
	return out


static func _index_of(s: Dictionary, index: Dictionary,
		states: Array) -> int:
	var key := var_to_str(s)
	if not index.has(key):
		index[key] = states.size()
		states.append(s)
	return index[key]


## The least whole second of standing still that moves the act from s,
## and the state it moves to; {} when waiting changes nothing but the
## running count of seconds itself.
static func _wait(id: String, s: Dictionary) -> Dictionary:
	if s.get("done", false):
		return {}
	var far := PlaceDeeds.tick(id, s, MAX_WAIT, true)
	if _moved(s, far) == false:
		return {}
	var t := WAIT_STEP
	while t <= MAX_WAIT:
		var nxt := PlaceDeeds.tick(id, s, t, true)
		if _moved(s, nxt):
			return {"seconds": t, "state": nxt}
		t += WAIT_STEP
	return {}


## True when a wait moved more than its own running count of seconds.
static func _moved(a: Dictionary, b: Dictionary) -> bool:
	var x := a.duplicate(true)
	var y := b.duplicate(true)
	x.erase("waited")
	y.erase("waited")
	return x != y


## The graph as the file holds it: every text once in "strings", nodes
## point at it by index (the 4 600 texts of the walk are 550 different
## ones); keys sorted, one act per line, so a change of one act shows as
## one line in a diff.
static func to_text(g: Dictionary) -> String:
	var table := {}
	var strings := []
	var ids: Array = g.acts.keys()
	ids.sort()
	var rows := []
	for id in ids:
		var nodes := []
		for n in g.acts[id].nodes:
			var lines := []
			for l in n.lines:
				lines.append(_ref(str(l), table, strings))
			var opts := []
			for o in n.options:
				opts.append({"id": o.id, "disabled": o.disabled,
					"text": _ref(o.text, table, strings),
					"reason": _ref(o.reason, table, strings)})
			var m := {"lines": lines, "reply": _ref(n.reply, table, strings),
				"done": n.done, "options": opts, "next": n.next}
			if n.has("wait"):
				m["wait"] = n.wait
			nodes.append(m)
		rows.append("%s: %s" % [JSON.stringify(id),
			JSON.stringify({"place": g.acts[id].place, "nodes": nodes},
				"", true)])
	return ("{\"version\": %d,\n\"source\": %s,\n\"strings\": %s,\n"
		+ "\"acts\": {\n%s\n}}\n") % [g.version, JSON.stringify(g.source),
		JSON.stringify(strings), ",\n".join(rows)]


static func _ref(text: String, table: Dictionary, strings: Array) -> int:
	if not table.has(text):
		table[text] = strings.size()
		strings.append(text)
	return table[text]
