## The people of the 12 stories in the headset (docs/HLD_STORY_12_
## CHARACTERS_2026-10-02.md; the census is docs/STORY_12_CHARACTERS_
## 2026-10-02.md).
##
## Each of the 12 stories (StoryRoute) has one talk step at the heart of
## a place; the matrix of the storylines names more people for it.
## data/story-cast-12.json, written by scripts/story/cast_12.py, says
## who of them stands in which place of his story, the tag over him and
## the node of his tree that speaks of the story's event.  The mentors
## of the courtyard stay there (Mentors.HUB_AT); the board of a story
## names them and where they stand.
##
## A person of a story stands beside the heart, never on it (TABOO 0.013
## item 1: the heart's prompt names only the heart): on the first spot
## of a fixed ring around the heart that keeps CLEAR_M from every thing,
## the bench, the way back and the walk from the door to the heart, and
## APART_M from the next person.  Nothing here is random; the same place
## gives the same spots.  He is drawn with the mentors' own figure
## (Mentors.figure), all the people of a place joined into one mesh by
## LocationBuild, and is talked to with the same trees as everywhere.
##
## Constitution: FORM (the people of a story, each with his craft and his
## place) -> ACTION (the player walks up to one where his story happens
## and talks with his own FORM) -> GOAL (the story's teaching is heard
## from many mouths, each in its own idiom, with its source).
class_name StoryCast
extends RefCounted

const DATA := "res://data/story-cast-12.json"
## How near a person answers a press, and the prompt over him.
const REACH_M := 1.1
## A thing keeps this much room from a person (TABOO 0.013 item 6).
const CLEAR_M := 0.75
## People stand this far apart, so each can be walked up to.
const APART_M := 1.2
## A person stands at least this far from the heart, so the heart's own
## prompt answers at the heart (its reach is LocationCore.REACH_M).
const FROM_HEART_M := 1.6
## And this far from the way back and the player's first step.
const FROM_DOOR_M := 1.2
## The walk from the door to the heart stays this wide on each side.
const WALK_HALF_M := 0.8
## The player talks with a person from this far in front of him.
const APPROACH_M := 1.0
## Seen from the door, a person nearer than this to the line of sight to
## another hides him.
const HIDE_M := 0.6
## The ring of spots around the heart: a step and a half away first, so
## from the door the heart's person stands alone in the middle and the
## people of the story beside him (the frames of 2026-10-02 at 1.7 m
## showed one row of four figures), the nearer ring only where a small
## room has no other room.  The angles are counted from the way to the
## door, both sides alike: beside the heart and a little behind it
## first, as people stand round a man at work (the frames of the porch
## and the bridge showed people at 55-75 degrees standing at the door
## like guards), the front sides last.
const RADII := [2.1, 2.5, 2.9, 3.3, 3.7, 1.7]
const ANGLES := [95, -95, 115, -115, 75, -75, 135, -135, 55, -55, 155,
	-155, 35, -35]

static var _data = null


static func load_data(path := DATA) -> Dictionary:
	if path == DATA and _data != null:
		return _data
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path)) \
		if FileAccess.file_exists(path) else null
	var d: Dictionary = raw if raw is Dictionary else {"stories": [],
		"places": {}}
	if path == DATA:
		_data = d
	return d


## The people who stand in one place: [{npc, tag, node, missions}].
static func at(place_id: String, data = null) -> Array:
	var d: Dictionary = data if data is Dictionary else load_data()
	return d.get("places", {}).get(place_id, [])


## The story of a mission in the cast data, or {}.
static func story(mission_id, data = null) -> Dictionary:
	var d: Dictionary = data if data is Dictionary else load_data()
	if mission_id == null:
		return {}
	for s in d.get("stories", []):
		if int(s.mission) == int(mission_id):
			return s
	return {}


## The board's lines for a story: who else the story calls for and
## where each stands (a place by its title, the courtyard's mentors by
## their courtyard tag).  Empty when the mission is not one of the 12.
static func people_lines(mission_id, data = null) -> Array:
	var s := story(mission_id, data)
	if s.is_empty():
		return []
	var by_place := {}
	var order := []
	for p in s.people:
		var key: String = p.place_ru
		if not by_place.has(key):
			by_place[key] = []
			order.append(key)
		var name: String = Mentors.HUB_TAG.get(p.npc, p.name_ru) \
			if p.place == "hub" else _tag_of(p.npc, p.place, data)
		by_place[key].append(name)
	var out := []
	for key in order:
		out.append("%s — %s." % ["; ".join(by_place[key]), key])
	if out.is_empty():
		return []
	return ["Люди сюжета:"] + out


static func _tag_of(npc: String, place: String, data = null) -> String:
	for p in at(place, data):
		if p.npc == npc:
			return p.tag
	return npc


# --- Where they stand ------------------------------------------------------

## The spots of a place's people from its plan (LocationCore.plan):
## [{npc, tag, node, missions, pos, yaw, placed}].  A person with no spot
## is kept with placed false and no pos, so a test names him; he is never
## put where a thing or the walk is.
static func spots(p: Dictionary, people: Array) -> Array:
	var out := []
	if p.get("type", "") == "underwater":
		return out
	var taken := []
	var rects := []
	for s in p.get("slots", []):
		rects.append(LocationCore.slot_rect(s))
	if p.get("bench") != null:
		rects.append(_rect(p.bench.rect))
	for person in people:
		# The side of the heart matters more than the step: every ring
		# of one bearing is tried before the next bearing.
		var at = null
		for a in ANGLES:
			for r in RADII:
				var dir := Vector3(0, 0, 1).rotated(Vector3.UP,
					deg_to_rad(float(a)))
				var c: Vector3 = p.heart + dir * float(r)
				c = Vector3(snappedf(c.x, 0.01), 0.0, snappedf(c.z, 0.01))
				if fits(c, p, rects, taken):
					at = c
					break
			if at != null:
				break
		var row: Dictionary = person.duplicate(true)
		row["placed"] = at != null
		if at != null:
			row["pos"] = at
			row["yaw"] = facing(at, p)
			taken.append(at)
		out.append(row)
	return out


## The turn of a person about the vertical, in degrees: he faces the
## middle of the walk from the door to the heart, where the player comes
## from (the figure's face is its local +Z, as the mentors').
static func facing(at: Vector3, p: Dictionary) -> float:
	var look: Vector3 = (p.heart + p.start) / 2.0
	var d := look - at
	return rad_to_deg(atan2(d.x, d.z))


## Whether a person may stand at c: inside the place, clear of the
## heart, the way back, the walk to the heart, every thing and the
## bench, the holy thing's quiet ring, and the other people.
static func fits(c: Vector3, p: Dictionary, rects: Array,
		taken: Array) -> bool:
	var m := 0.45
	if absf(c.x) > p.w / 2.0 - m or absf(c.z) > p.d / 2.0 - m:
		return false
	var pt := Vector2(c.x, c.z)
	var heart := Vector2(p.heart.x, p.heart.z)
	if pt.distance_to(heart) < FROM_HEART_M:
		return false
	for q in [p.exit, p.start]:
		if pt.distance_to(Vector2(q.x, q.z)) < FROM_DOOR_M:
			return false
	# The walk from the first step to the heart stays free.
	var a := Vector2(p.start.x, p.start.z)
	if Geometry2D.get_closest_point_to_segment(pt, a, heart) \
			.distance_to(pt) < WALK_HALF_M:
		return false
	if p.get("passage") != null and _rect(p.passage).grow(0.4) \
			.has_point(pt):
		return false
	for r in rects:
		if LocationsCore.gap(pt, r) < CLEAR_M:
			return false
	if p.get("holy_at") != null:
		var h: Vector3 = p.holy_at
		if pt.distance_to(Vector2(h.x, h.z)) \
				< LocationCore.HOLY_FAR_M + REACH_M:
			return false
	# Walked up to from the front, a metre away (StoryCast.APPROACH_M),
	# he is the one who answers: the heart and the others are farther.
	var f := approach(c, p)
	if f.distance_to(heart) < APPROACH_M + 0.3:
		return false
	var door := Vector2(p.start.x, p.start.z)
	for o in taken:
		var q := Vector2(o.x, o.z)
		if pt.distance_to(q) < APART_M:
			return false
		if f.distance_to(q) < APPROACH_M + 0.3 \
				or approach(o, p).distance_to(pt) < APPROACH_M + 0.3:
			return false
		# Seen from the door, nobody stands behind another (the frames
		# of 2026-10-02 hid the spice merchant behind the bishop).
		if _behind(pt, q, door) or _behind(q, pt, door):
			return false
	return true


## Whether a stands hidden behind b, seen from the door.
static func _behind(a: Vector2, b: Vector2, door: Vector2) -> bool:
	if a.distance_to(door) <= b.distance_to(door):
		return false
	return Geometry2D.get_closest_point_to_segment(b, door, a) \
		.distance_to(b) < HIDE_M


## The point a metre in front of a person, where the player stands to
## talk with him (and where the proof frame of him is taken).
static func approach(at: Vector3, p: Dictionary) -> Vector2:
	var face := Vector3(0, 0, 1).rotated(Vector3.UP,
		deg_to_rad(facing(at, p)))
	var f := at + face * APPROACH_M
	return Vector2(f.x, f.z)


static func _rect(r: Array) -> Rect2:
	return Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]),
		float(r[3]) - float(r[1]))


## The prompt over a person in a place.
static func prompt(person: Dictionary) -> String:
	return "Поговорить: " + str(person.tag)
