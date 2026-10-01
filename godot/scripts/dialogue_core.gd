## The rules of a talk with a mentor, ported from the web game's
## dialogue manager (public/ludus/ludus-npc-dialogue-manager.js) and
## checked against it by a fixture (tests/fixtures/dialogue.json, made by
## scripts/godot/make_dialogue_fixture.js).
##
## The JS module is the reference: a tree is normalised the same way
## (only the seven attributes survive in a condition or a bonus, a bonus
## is rounded and clamped to +1..+5, a missing start falls back to the
## first node), a branch is open when the FORM meets every minimum of its
## condition, and a choice adds exactly the branch's declared bonuses.
## Nothing here reads a clock or draws a random number (Constitution:
## no randomness; a bonus is the direct consequence of a choice).
##
## What the headset shows besides the JS: the Russian text, the voice of
## the line and its source.  A saint speaks only as a paraphrase with its
## source (TABOO 0.35 rule 18, 0.37), so the panel names both.
##
## Constitution: FORM (the seven attributes) -> ACTION (the branches the
## FORM opens, and the one the player takes) -> GOAL (the teaching of the
## line, with its meaning and source carried in the data).
class_name DialogueCore
extends RefCounted

## Exactly seven attributes (Constitution); anything else is dropped.
const ATTRIBUTES := ["wisdom", "faith", "dexterity", "constitution",
	"charisma", "cunning", "erudition"]
## One choice grants +1 to +5 per attribute (CLAUDE.md, attributes).
const MAX_BONUS_PER_CHOICE := 5
const RU_ATTR := {"wisdom": "Мудрость", "faith": "Вера",
	"dexterity": "Ловкость", "constitution": "Стойкость",
	"charisma": "Обаяние", "cunning": "Хитрость", "erudition": "Книжность"}
## Node fields the headset keeps beside the JS shape, for the panel and
## for the chorus (meaning and source are never shown as a label of a
## reward; the source is shown as the line's ground).
const KEPT := ["text_ru", "voice", "meaning", "source"]


## Keep only the seven attributes with finite numbers; a bonus is
## rounded, capped at +5 and dropped unless positive (as the JS).
static func sanitise(map, clamp_bonus: bool) -> Dictionary:
	var clean := {}
	if not map is Dictionary:
		return clean
	for a in ATTRIBUTES:
		if not map.has(a):
			continue
		var value := js_number(map[a])
		if is_nan(value) or is_inf(value):
			continue
		if clamp_bonus:
			# Math.round in JS rounds .5 up, also for negatives.
			var bonus := mini(MAX_BONUS_PER_CHOICE, int(floor(value + 0.5)))
			if bonus > 0:
				clean[a] = bonus
		else:
			clean[a] = value
	return clean


## Number(v) of the JS, for the values JSON can carry: a number is
## itself, null and false are 0, true is 1, a string is its number
## (blank is 0, anything else not a number is NaN), an array of none is
## 0 and of one is that one's Number(String(x)), anything else is NaN.
## So a condition {wisdom: "5"} gates at 5 and {wisdom: null} at 0, as in
## the web game.  (Hex, binary and octal strings are left out: the
## trees are written by hand in decimal.)
static func js_number(v) -> float:
	if v == null:
		return 0.0
	if v is bool:
		return 1.0 if v else 0.0
	if v is float or v is int:
		return float(v)
	if v is String or v is StringName:
		var t := str(v).strip_edges()
		if t == "":
			return 0.0
		if t in ["Infinity", "+Infinity"]:
			return INF
		if t == "-Infinity":
			return -INF
		return t.to_float() if t.is_valid_float() else NAN
	if v is Array:
		if v.is_empty():
			return 0.0
		if v.size() == 1:
			return js_number("" if v[0] == null else str(v[0]))
	return NAN


## The tree in the shape the rules rely on, or {} when it is unusable.
static func normalise_tree(raw, npc_id: String) -> Dictionary:
	if not raw is Dictionary or not raw.get("nodes") is Array \
			or raw.nodes.is_empty():
		return {}
	var nodes := []
	for node in raw.nodes:
		if not node is Dictionary or not node.get("id") is String:
			continue
		var branches := []
		var raw_branches = node.get("branches", [])
		if raw_branches is Array:
			for b in raw_branches:
				# .filter(Boolean) of the JS: a falsy entry is dropped, a
				# truthy one that is not an object is a branch with no
				# fields (no text, no condition, no bonus, the end).
				if not _truthy(b):
					continue
				if not b is Dictionary:
					b = {}
				var nxt = b.get("nextNodeId")
				branches.append({
					"text": _text(b.get("text")),
					"text_ru": _text(b.get("text_ru", b.get("text"))),
					"condition": sanitise(b.get("condition"), false),
					"nextNodeId": nxt if nxt is String and nxt != "" else null,
					"attributeBonuses": sanitise(b.get("attributeBonuses"),
						true),
					"narrativeEffect": _text(b.get("narrativeEffect"))
						if _truthy(b.get("narrativeEffect")) else "",
				})
		var n := {"id": node.id, "text": _text(node.get("text")),
			"branches": branches}
		for k in KEPT:
			if node.has(k):
				n[k] = node[k]
		nodes.append(n)
	if nodes.is_empty():
		return {}
	var start = raw.get("startNode")
	var has_start := false
	for n in nodes:
		if n.id == start:
			has_start = true
	var tree := {
		"npcId": raw.npcId if raw.get("npcId") is String else npc_id,
		"npcName": raw.npcName if raw.get("npcName") is String else "",
		"npcName_ru": raw.get("npcName_ru", raw.get("npcName", npc_id)),
		"theology": raw.theology if raw.get("theology") is String else "",
		"startNode": start if has_start else nodes[0].id,
		"nodes": nodes,
	}
	if raw.get("idiom") is Dictionary:
		tree["idiom"] = raw.idiom
	return tree


## Truthiness of the JS for JSON values.
static func _truthy(v) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is float or v is int:
		return v != 0 and not is_nan(float(v))
	if v is String:
		return v != ""
	return true


static func _text(v) -> String:
	return "" if v == null else str(v)


static func node_of(tree: Dictionary, node_id) -> Dictionary:
	for n in tree.get("nodes", []):
		if n.id == node_id:
			return n
	return {}


## condition {wisdom: 8, faith: 6} means wisdom >= 8 and faith >= 6.
## A key that is not one of the seven attributes is ignored, as the JS
## drops it when it normalises the tree.
static func check_condition(condition, form: Dictionary) -> bool:
	condition = sanitise(condition, false)
	for a in condition:
		if _num(form.get(a, 0)) < float(condition[a]):
			return false
	return true


## The unmet minimums, so the panel can say which part of the FORM must
## still grow: [{attribute, required, current}].
static func missing(condition, form: Dictionary) -> Array:
	var out := []
	condition = sanitise(condition, false)
	for a in condition:
		var cur := _num(form.get(a, 0))
		if cur < float(condition[a]):
			out.append({"attribute": a, "required": float(condition[a]),
				"current": cur})
	return out


## Number(x) || 0 of the JS: NaN is zero (an infinity stays, as in JS).
static func _num(v) -> float:
	var f := js_number(v)
	return 0.0 if is_nan(f) else f


## Indices (in node.branches) of the branches the FORM opens.
static func available(node: Dictionary, form: Dictionary) -> Array:
	var out := []
	var bs: Array = node.get("branches", [])
	for i in bs.size():
		if check_condition(bs[i].get("condition", {}), form):
			out.append(i)
	return out


## The branches the FORM opens, in order.
static func open_branches(node: Dictionary, form: Dictionary) -> Array:
	var out := []
	for i in available(node, form):
		out.append(node.branches[i])
	return out


## Take branch i of node: refused when locked (a stale index cannot skip
## a gate); else the form gains exactly the declared bonuses.  Returns
## {ok, locked, missing, form, bonuses, next, complete, narrative}.
static func choose(form: Dictionary, node: Dictionary, i: int) -> Dictionary:
	var bs: Array = node.get("branches", [])
	if i < 0 or i >= bs.size():
		return {"ok": false, "locked": false, "missing": [], "form": form}
	var b: Dictionary = bs[i]
	if not check_condition(b.get("condition", {}), form):
		return {"ok": false, "locked": true,
			"missing": missing(b.get("condition", {}), form), "form": form}
	var res := apply(form, b)
	res["ok"] = true
	res["locked"] = false
	res["missing"] = []
	return res


## A branch's bonuses on the form: only the seven attributes, only
## +1..+5 (the branch is sanitised again here, so a raw branch from the
## data cannot pass more than the JS would).
static func apply(form: Dictionary, branch: Dictionary) -> Dictionary:
	var f := form.duplicate()
	var bonuses := sanitise(branch.get("attributeBonuses", {}), true)
	for a in bonuses:
		# (form[a] || 0) + bonus, as the game does: a fractional value is
		# kept, a whole one stays an integer.
		var v := _num(f.get(a, 0)) + float(bonuses[a])
		f[a] = int(v) if v == floor(v) and absf(v) < 1e15 else v
	var nxt = branch.get("nextNodeId")
	if not (nxt is String and nxt != ""):
		nxt = null
	return {"form": f, "bonuses": bonuses, "next": nxt,
		"complete": nxt == null,
		"narrative": _text(branch.get("narrativeEffect", ""))}


## The line under a mentor's words: whose voice and on what ground.  A
## saint's line is a paraphrase of his teaching, never his quotation.
static func voice_line(node: Dictionary) -> String:
	var src := str(node.get("source", ""))
	if src == "":
		return ""
	var label := SourceLabels.ru(src)
	if node.get("voice", "") == "paraphrase":
		return "Пересказ учения. Источник: " + label
	return "Источник: " + label


## What the closed branches of a node ask of the FORM, as one line:
## "Ещё закрыто, нужно: Мудрость 6, Вера 5" (empty when nothing the
## teaching asks for is closed).  The wording does not depend on the
## gender or the number of the attributes named.
##
## A branch gated by Cunning is left out.  In the data such branches are
## the favour-seeking requests (Kassia's "a verse to sway a man", and the
## same at Isaias, Symeon and elder Sergius), whose cost is that the
## deeper talk stays closed; Cunning is the attribute that is "rare, not
## approved" (CLAUDE.md, attributes) and opens no gate (TABOO 0.35 rule
## 14).  Naming it as something still to grow would show the way of
## prelest as a goal (Constitution: the closed part is what is still to
## grow towards the teaching).
static func closed_line(node: Dictionary, form: Dictionary) -> String:
	var parts := []
	for b in node.get("branches", []):
		if sanitise(b.get("condition", {}), false).has("cunning"):
			continue
		for m in missing(b.get("condition", {}), form):
			var s := "%s %d" % [RU_ATTR.get(m.attribute, m.attribute),
				int(m.required)]
			if not s in parts:
				parts.append(s)
	if parts.is_empty():
		return ""
	return "Ещё закрыто, нужно: " + ", ".join(parts)
