## The knight's traces in the lake and the chronicle's choice (TABOO
## 0.03, rules 3-4; scripts/story/atlas_nodes.py CHRONICLE and TRACES,
## carried in godot/data/atlas-99.json).
##
## The chronicle is written once at the scriptorium table: the knight
## spared the enemy under the vault at Sis, or brought the vault down.
## The choice gives nothing (no attribute, no counter); its trace is in
## the dive: the passage on the slope is whole or lies as rubble, and
## every trace is placed by a seed that includes the choice.  The
## knight's things go to the scribe, never into the bag; the khachkar is
## holy (noInteract/noLoot): the arm does not touch it and the console
## goes out beside it.  Nothing here is random.
class_name AtlasTraces
extends RefCounted

## The passage of nodes 26-27 lies on the slope at this depth.
const PASSAGE_DEPTH := 44.0
const UNKNOWN_RU := "Тип не определён."


static func options(data: Dictionary) -> Array:
	return data.chronicle.options


static func option(data: Dictionary, id) -> Dictionary:
	for o in options(data):
		if o.id == id:
			return o
	return {}


## Write the chronicle.  Only the first choice counts: a chronicle is
## written once.  Returns the stored choice.
static func write_chronicle(data: Dictionary, current, id) -> String:
	if typeof(current) == TYPE_STRING and not option(data, current).is_empty():
		return current
	return id if not option(data, id).is_empty() else ""


## A point on the floor of the dive line near `depth`, moved along the
## shore by the seed (as DiveCore.place_objects does for lake objects).
static func _on_floor(seed_text: String, depth: float) -> Dictionary:
	var r := DiveCore.rng(seed_text)
	var z: float = (r.call() * 2.0 - 1.0) * DiveCore.CORRIDOR_M * 0.5
	var x := DiveCore.x_for_depth(depth)
	var d := DiveCore.floor_depth(x, z)
	var k := 0
	while k < 40 and absf(d - depth) > 1.0:
		x += 0.5 if d < depth else -0.5
		d = DiveCore.floor_depth(x, z)
		k += 1
	return {"x": x, "z": z, "depth": d, "yaw": r.call() * TAU}


## Everything of the Atlas on the lake floor for this chronicle choice
## ("" before it is written: the passage is not drawn yet).
static func place(data: Dictionary, choice: String) -> Array:
	var out := []
	for tr in data.traces:
		var at := _on_floor("atlas:%s:%s" % [tr.id, choice], tr.depth)
		var p: Dictionary = tr.duplicate(true)
		p.merge(at, true)
		p["kind"] = "trace"
		out.append(p)
	var o := option(data, choice)
	if not o.is_empty():
		var at := _on_floor("atlas:passage:" + choice, PASSAGE_DEPTH)
		at.merge({"id": "passage", "kind": "passage", "shape": choice,
			"ru": o.lake_ru, "holy": false, "loot": null, "size": 2.5,
			"colour": "#6f6a60", "scribe_ru": o.written_ru}, true)
		out.append(at)
	return out


## The arm meets a thing of the Atlas.  Returns {bag, text, reach}:
## reach is false for a holy thing (the arm does not move), and only the
## knight's things are handed to the scribe (bag.atlas).  No attribute
## changes here or anywhere.
static func take(bag: Dictionary, thing: Dictionary) -> Dictionary:
	var b := bag.duplicate(true)
	var atlas: Array = (b.get("atlas", []) as Array).duplicate()
	if thing.get("holy", false):
		return {"bag": b, "text": UNKNOWN_RU, "reach": false}
	if thing.get("loot") == "hand-over":
		if not thing.id in atlas:
			atlas.append(thing.id)
		b["atlas"] = atlas
		return {"bag": b, "reach": true,
			"text": "%s — писцу. Не в сумку: это чужая память." % thing.ru}
	return {"bag": b, "reach": true, "text": "%s. %s" % [thing.ru,
		thing.get("scribe_ru", "")]}


## Holy points for the console's fade.
static func holy_points(placed: Array) -> Array:
	var out := []
	for p in placed:
		if p.get("holy", false):
			out.append(Vector3(p.x, -p.depth, p.z))
	return out


## What the scribe says of the things handed over, in the order of the
## list (not of the finding), for the lectern.
static func scribe_page(data: Dictionary, handed: Array) -> String:
	var lines := []
	for tr in data.traces:
		if tr.id in handed and str(tr.scribe_ru) != "":
			lines.append("%s. %s" % [tr.ru, tr.scribe_ru])
	if lines.is_empty():
		return ""
	return "Писцу передано со дна\n\n" + "\n\n".join(lines)
