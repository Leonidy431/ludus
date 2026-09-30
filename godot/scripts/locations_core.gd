## The 99 locations of our plots (docs/HLD_LOCATIONS_99_2026-09-30.md,
## CLAUDE.md TABOO 0.013): the specification the next phases build,
## read from data/locations-99.json, which
## scripts/locations/locations_99.py writes from an honest pool
## (TABOO 0.07).
##
## Nothing here builds a scene yet.  This file answers the questions of
## the standard of the evening-watch cell for every location: does its
## heart name a real practice or action of the game's own cores (the
## logic that is already tested), and what ground does each placed
## thing take, recomputed from its position, turn and size, so the
## headset's test does not trust the generator's arithmetic.
class_name LocationsCore
extends RefCounted

const DATA := "res://data/locations-99.json"
## A thing keeps this much room from the heart (TABOO 0.013 item 6).
const CLEAR_M := 0.75
## A drawn card hangs at this width and is this thin on its wall.
const CARD_M := 0.6
const WALL_T := 0.1
## Church words never label a place, a thing or a hint (TABOO 0.39
## item 3); the same list as the generator's CHURCH_WORDS.
const CHURCH_WORDS := ["свят", "благодат", "таинств", "мученик", "мучени",
	"спасени", "литурги", "причаст", "причащ", "исповед", "крещен",
	"молитв", "чудо", "мощи", "икон", "храм", "церк", "алтар", "крест",
	"лампад", "прп.", "свт.", "вмц."]
const LIGHT_K := {"lampada": [1800, 1800], "hearth": [1900, 2500],
	"instrument": [6500, 6500]}


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


static func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## What the hearts are checked against: the data the cores read.
static func context() -> Dictionary:
	var lake := {}
	for o in _json("res://data/lake-objects-99.json").objects:
		lake[o.id] = true
	var passions := {}
	for p in _json("res://data/passions.json").passions:
		passions[p.id] = true
	return {"trees": _json("res://data/dialogue-trees.json").trees,
		"lake": lake, "passions": passions,
		"atlas": _json("res://data/atlas-99.json")}


static func _has_words(line: String) -> bool:
	return line.contains("ФОРМА") and line.contains("ДЕЙСТВИЕ") \
		and line.contains("ЦЕЛЬ")


## Whether a location's heart is a real practice or action of the game.
static func heart_ok(h: Dictionary, ctx: Dictionary) -> bool:
	match h.get("core", ""):
		"RuleCore":
			return not RuleCore.practice(h.id).is_empty()
		"MissionCore":
			match h.get("step", ""):
				"practice":
					return MissionCore.PRACTICE_RU.has(h.id)
				"find":
					return ctx.lake.has(h.object)
				"dialogue":
					var tree: Dictionary = ctx.trees.get(h.npc, {})
					return not tree.is_empty() \
						and not HubCore.node_of(tree, h.node).is_empty()
		"DiveCore":
			for t in DiveCore.TASKS:
				if t.id == h.id:
					return true
		"AtlasTraces":
			match h.id:
				"trace":
					for t in ctx.atlas.traces:
						if t.id == h.trace:
							return true
				"chronicle":
					return AtlasTraces.options(ctx.atlas).size() == 2
				"scribe":
					return true
		"TrialCore":
			return h.id in TrialCore.GATE_IDS
		"PassionCore":
			return ctx.passions.has(h.id)
		"WitnessCore":
			return h.id in WitnessCore.ORDER
		"TypikonCore":
			return h.id == "hear" and not TypikonCore.cues().is_empty()
		"new":
			return _has_words(String(h.get("constitution", "")))
	return false


## The ground a placed thing takes, as Rect2(x, z, width, depth): a card
## is thin on its wall, a volume takes its size, and a yaw of +-90
## turns it.
static func rect_of(slot: Dictionary, thing: Dictionary) -> Rect2:
	var fw := CARD_M
	var fd := WALL_T
	if not thing.state in ["card", "board"]:
		fw = float(thing.size_m[0])
		fd = float(thing.size_m[2])
	if absf(float(slot.yaw)) == 90.0:
		var t := fw
		fw = fd
		fd = t
	var x := float(slot.pos[0])
	var z := float(slot.pos[2])
	return Rect2(x - fw / 2.0, z - fd / 2.0, fw, fd)


## Which layer a placed thing is in: on a wall or a post, on the bench
## top, or on the ground (the floor or the seabed).
static func layer_of(slot: Dictionary) -> String:
	if slot.mount in ["wall", "stand"]:
		return "wall"
	var y := float(slot.pos[1])
	if slot.mount == "holy":
		return "wall" if y > 1.0 else ("top" if y > 0.3 else "ground")
	return "top" if slot.mount == "table" else "ground"


## The distance from a point to a rectangle on the ground.
static func gap(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()


static func has_church_word(text: String) -> bool:
	var low := text.to_lower()
	for w in CHURCH_WORDS:
		if low.contains(w):
			return true
	return false


## The model file of a thing that already ships in the APK.
static func model_path(thing: Dictionary) -> String:
	var src: String = thing.source
	var id := src.get_slice(":", 1)
	match src.get_slice(":", 0):
		"obj":
			return "res://models/obitel/%s.glb" % id
		"lake":
			return "res://models/lake/lake-%s.glb" % id.replace(".", "-")
		"atlas":
			return "res://models/atlas/atlas-%s.glb" % id
	return ""
