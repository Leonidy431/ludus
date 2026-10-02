## Destiny: the loot of the game is not things but the person (operator,
## 2026-10-02: «Возьми за лут в игре ветки развития персонажа и семь
## разных веток финала от выборов зависящие. Ближе к раю или ближе к
## аду»).  docs/HLD_DESTINY_BRANCHES_FINALES_2026-10-02.md;
## godot/data/destiny.json.
##
## Two things grow from the player's deeds, both deterministic:
##   * seven branches of growth, one for each of the seven attributes of
##     the Constitution (no new attribute), each with nodes the attribute
##     opens: an ability of knowledge, craft or trust, never a magic and
##     never a reward for prayer or the holy;
##   * the direction of the path, a score of weighted deeds, read as one
##     of seven finales from "closer to hell" (-3) to "closer to paradise"
##     (+3).
## The game shows a direction and judges no one (Mt 7:1).  Repentance
## counts until the last hour: a path with repentance never ends below
## the floor band (the worker of the eleventh hour, the Paschal homily of
## St John Chrysostom).
class_name DestinyCore
extends RefCounted

const DATA := "res://data/destiny.json"
const ATTRS := ["wisdom", "faith", "dexterity", "constitution", "charisma",
	"cunning", "erudition"]
## Images the finales must not use: hell is shown as a loop without love,
## never as fire, pit or torment on screen (TABOO 0.4, 0.015 item 3).
const NO_IMAGES := ["огонь", "пламя", "пытк", "кров", "демон", "черт",
	"мучени", "котёл", "котел"]


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


static func _deed(data: Dictionary, id: String) -> Dictionary:
	for x in data.deeds:
		if x.id == id:
			return x
	return {}


## The score of a path: the sum of its deeds' weights, each deed once,
## within the range.  Unknown deeds count nothing.
static func score(data: Dictionary, deeds: Array) -> int:
	var seen := {}
	var s := 0
	for id in deeds:
		if seen.has(id):
			continue
		seen[id] = true
		s += int(_deed(data, str(id)).get("weight", 0))
	var r: Array = data.score_range
	return clampi(s, int(r[0]), int(r[1]))


static func repented(data: Dictionary, deeds: Array) -> bool:
	for id in deeds:
		if _deed(data, str(id)).get("repent", false):
			return true
	return false


## The band -3..+3 of a path: the score in thirds of its half-range,
## lifted to the floor band when the player has repented.
static func band(data: Dictionary, deeds: Array) -> int:
	var s := score(data, deeds)
	var b := 0
	if s <= -7:
		b = -3
	elif s <= -4:
		b = -2
	elif s <= -1:
		b = -1
	elif s == 0:
		b = 0
	elif s <= 3:
		b = 1
	elif s <= 6:
		b = 2
	else:
		b = 3
	if repented(data, deeds):
		b = maxi(b, int(data.repent_floor_band))
	return b


static func finale(data: Dictionary, deeds: Array) -> Dictionary:
	var b := band(data, deeds)
	for f in data.finales:
		if int(f.band) == b:
			return f
	return {}


## The nodes of the seven branches a form has opened: a node opens when
## its attribute reaches the node's need.  Deterministic, nothing bought.
static func open_nodes(data: Dictionary, form: Dictionary) -> Array:
	var out := []
	for br in data.branches:
		var v := int(form.get(br.attr, 0))
		for n in br.nodes:
			if v >= int(n.need):
				out.append(n.id)
	return out


static func check(data: Dictionary) -> Array:
	var bad := []
	var attrs := []
	for br in data.get("branches", []):
		attrs.append(br.attr)
		if br.nodes.size() < 3:
			bad.append("%s: a branch of fewer than 3 nodes" % br.attr)
		var last := 0
		for n in br.nodes:
			if int(n.need) <= last:
				bad.append("%s: needs must rise" % n.id)
			last = int(n.need)
			var g := str(n.gives_ru).to_lower()
			for w in ["благодать", "молитв", "святын"]:
				if w in g and br.attr != "faith":
					bad.append("%s: the holy as a gift of growth" % n.id)
		if br.attr == "cunning":
			for n in br.nodes:
				if not n.has("cost_ru"):
					bad.append("%s: a cunning node without its cost" % n.id)
	attrs.sort()
	var want := ATTRS.duplicate()
	want.sort()
	if attrs != want:
		bad.append("branches are not exactly the seven attributes")
	var bands := []
	for f in data.get("finales", []):
		bands.append(int(f.band))
		for k in ["title_ru", "scene_ru", "line_ru", "teaches_ru", "source",
				"door_ru"]:
			if str(f.get(k, "")) == "":
				bad.append("%s: no %s" % [f.id, k])
		if str(f.line_ru).length() > 140:
			bad.append("%s: line too long" % f.id)
		var text := (str(f.scene_ru) + " " + str(f.line_ru)).to_lower()
		for w in NO_IMAGES:
			if w in text:
				bad.append("%s: «%s» on screen" % [f.id, w])
	bands.sort()
	if bands != [-3, -2, -1, 0, 1, 2, 3]:
		bad.append("seven finales must cover -3..+3: %s" % [bands])
	for x in data.get("deeds", []):
		if absi(int(x.weight)) > 3:
			bad.append("%s: weight beyond 3" % x.id)
	return bad
