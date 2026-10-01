## The meeting of a passion on the road, ported from the web game.
##
## Reference: public/ludus/ludus-passion.js (STAGES, canName, start,
## options, choose, normalizeRecord, finish, spriteFor, nextPassion).
## godot/tests/test_passion.gd checks this port against
## godot/tests/passion_fixture.json, written from the JS by
## scripts/godot/make_passion_fixture.js.  Data: godot/data/passions.json,
## a byte-for-byte copy of public/ludus/data/passions.json, so both
## versions speak with one idiom and meaning (TABOO 0.39 point 6).
##
## A passion is met as a thought, and the Fathers describe how a thought
## takes hold in stages (St John Climacus, Ladder step 15; St Philotheus
## of Sinai in the Philokalia): prilog (the suggestion), converse (the
## mind talks with it), consent (the will agrees), captive (the thought
## leads the person).  The best answer cuts the thought at the
## suggestion, by naming its sign or by turning away into stillness;
## repentance is open at every stage.  Stillness ends every good path and
## pays nothing, because prayer and stillness are never XP (TABOO 0.35
## rule 16).  The only bonus is +1 Wisdom, once per passion, for naming
## it at the first stage.  No holy object is a weapon here (TABOO 0.2).
##
## States, records and sprites keep the JS keys (passionId, stage,
## named, turnedAtPrilog; meetings, overcome, captive, discerned), so a
## save written by one version reads the same in the other.
class_name PassionCore
extends RefCounted

const STAGES := ["prilog", "converse", "consent", "captive", "stillness",
	"virtue"]

## The part of the AntagonistFactory (ludus-antagonist-factory.js) that
## picks a passion's sprite.  The factory's manifest is not ported as data
## yet, so the caller hands it in; without one no sprite is chosen and the
## road keeps the art named in passions.json, exactly as the web game does
## until the factory script has loaded.
const CANVAS := 256
const THRESHOLD := 0.35
const MAX_FORGIVENESS := 0.5
const ART_BASE := "/ludus/art/derived/DEF-001/"


## Number(v) of JS, made finite: a bad value counts as zero.  A save or an
## old client may hand a number over as a string or a bool.
static func _num(v) -> float:
	var n := 0.0
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			n = float(v)
		TYPE_BOOL:
			n = 1.0 if v else 0.0
		TYPE_STRING, TYPE_STRING_NAME:
			var s := String(v).strip_edges()
			if s.is_empty():
				n = 0.0
			elif s.is_valid_float():
				n = s.to_float()
			elif s.to_lower().begins_with("0x") \
					and s.substr(2).is_valid_hex_number():
				n = float(s.substr(2).hex_to_int())
			else:
				n = NAN
		_:
			n = NAN
	return n if is_finite(n) else 0.0


## JS truthiness: whether a value counts as "yes" in a condition.
static func _truthy(v) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return float(v) != 0.0 and not is_nan(float(v))
		TYPE_STRING, TYPE_STRING_NAME:
			return not String(v).is_empty()
	return true


## obj[key] for a JS object: null when obj is not a dictionary or has no
## such key, as undefined is in the JS.
static func _at(obj, key: String):
	if typeof(obj) == TYPE_DICTIONARY and (obj as Dictionary).has(key):
		return obj[key]
	return null


## Naming the sign needs either the mentor who teaches it or enough
## Wisdom to see it unaided.
static func can_name(passion: Dictionary, form, actions) -> bool:
	var met = _at(_at(actions, "met"), str(passion.get("teacher")))
	return _truthy(met) \
		or _num(_at(form, "wisdom")) >= _num(passion.get("wisdomToName"))


static func start(passion: Dictionary) -> Dictionary:
	return {"passionId": passion.get("id"), "stage": "prilog",
		"named": false, "turnedAtPrilog": false}


## The choices at a stage.  Every option has a fixed next stage, so the
## same choices always lead to the same end (no randomness, TABOO 0.35
## rule 15).  The texts are the JS strings, unchanged.
static func options(state: Dictionary, passion: Dictionary, form,
		actions) -> Array:
	match state.get("stage"):
		"prilog":
			var list := [
				{"id": "look", "text": "Look closer",
					"text_ru": "Присмотреться", "next": "converse"},
				{"id": "turn", "text": "Turn away in silence",
					"text_ru": "Отвернуться в молчании",
					"next": "stillness"},
			]
			if can_name(passion, form, actions):
				list.insert(1, {"id": "name",
					"text": "Name it: %s" % str(passion.get("cue")),
					"text_ru": "Назвать: %s" % str(passion.get("cue_ru")),
					"next": "stillness"})
			return list
		"converse":
			return [
				{"id": "answer", "text": "Answer it, argue it out",
					"text_ru": "Ответить ему, переспорить",
					"next": "consent"},
				{"id": "stop", "text": "Stop talking with it; be still",
					"text_ru": "Не беседовать с ним; умолкнуть",
					"next": "stillness"},
			]
		"consent":
			return [
				{"id": "take", "text": "Take what it offers",
					"text_ru": "Взять предложенное", "next": "captive"},
				{"id": "remember", "text": "Remember the mentor's word",
					"text_ru": "Вспомнить слово наставника",
					"next": "stillness"},
			]
		"stillness":
			return [{"id": "still", "text": "Be still for three breaths",
				"text_ru": "Помолчать три вдоха", "next": "virtue",
				"breaths": 3}]
	return []


## One step down or away.  An option that is not offered changes
## nothing: the same state comes back.
static func choose(state: Dictionary, option_id: String,
		passion: Dictionary, form, actions) -> Dictionary:
	var opt := {}
	for o in options(state, passion, form, actions):
		if o.id == option_id:
			opt = o
			break
	if opt.is_empty():
		return state
	var n := state.duplicate()
	n.stage = opt.next
	n.named = _truthy(state.get("named")) or opt.id == "name"
	n.turnedAtPrilog = _truthy(state.get("turnedAtPrilog")) \
		or (state.get("stage") == "prilog" and opt.id == "turn")
	return n


## A record key is a short lower-case Latin word, as the JS /^[a-z]{1,20}$/
## demands; anything else in a save is dropped.
static func _valid_id(id: String) -> bool:
	if id.length() < 1 or id.length() > 20:
		return false
	for i in id.length():
		var c := id.unicode_at(i)
		if c < 97 or c > 122:
			return false
	return true


static func _count(v) -> int:
	return maxi(0, int(floor(_num(v))))


## The record of meetings with each passion.  Only the outcome is kept,
## never what the player "said" to it.  A JS array is an object too, so
## an array entry is kept with all counts at zero, as in the JS.
static func normalize_record(raw) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for key in raw:
		var id := str(key)
		var item = raw[key]
		if not _valid_id(id) \
				or typeof(item) not in [TYPE_DICTIONARY, TYPE_ARRAY]:
			continue
		out[id] = {
			"meetings": _count(_at(item, "meetings")),
			"overcome": _count(_at(item, "overcome")),
			"captive": _count(_at(item, "captive")),
			"discerned": typeof(_at(item, "discerned")) == TYPE_BOOL
				and _at(item, "discerned") == true,
		}
	return out


## Close an encounter.  Returns the new record and the FORM bonus, which
## is +1 Wisdom only the first time a passion is named at its
## suggestion: understanding, not a prize for fighting.
static func finish(record, state: Dictionary) -> Dictionary:
	var rec := normalize_record(record)
	var id := str(state.get("passionId"))
	var item: Dictionary = rec.get(id, {"meetings": 0, "overcome": 0,
		"captive": 0, "discerned": false})
	item.meetings += 1
	var bonus := {}
	if state.get("stage") == "virtue":
		item.overcome += 1
		if _truthy(state.get("named")) and not item.discerned:
			item.discerned = true
			bonus = {"wisdom": 1}
	elif state.get("stage") == "captive":
		item.captive += 1
	rec[id] = item
	return {"record": rec, "attribute_bonuses": bonus}


## All variants of a passion, in the order of the manifest.
static func variants_of(passion: String, manifest: Array) -> Array:
	var out := []
	for o in manifest:
		if o.passion != passion:
			continue
		for v in o.variants:
			var e: Dictionary = v.duplicate()
			e.objectId = o.id
			e.passion = o.passion
			out.append(e)
	return out


## One round of the queue: a Fisher-Yates shuffle seeded by the passion,
## the seed and the round number (FNV-1a and mulberry32 of DiveCore, the
## same as the factory's hashString and seeded).
static func _round(size: int, key: String, number: int) -> Array:
	var next := DiveCore.rng("%s#%d" % [key, number])
	var order := []
	for i in size:
		order.append(i)
	for i in range(size - 1, 0, -1):
		var j := int(floor(float(next.call()) * float(i + 1)))
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	return order


## The index of the n-th variant.  When a round would start with the
## variant that ended the previous one, its first two places are
## swapped, so the same sprite never comes twice in a row (TABOO 0.3
## rule 53).
static func queue_index(size: int, key: String, n: int) -> int:
	if size <= 0:
		return -1
	var target := n / size
	var last := -1
	var order := []
	for r in target + 1:
		order = _round(size, key, r)
		if size > 1 and order[0] == last:
			var tmp = order[0]
			order[0] = order[1]
			order[1] = tmp
		last = order[size - 1]
	return order[n % size]


## Rules 55 and 58: the radius of a disc with the silhouette's area,
## made smaller the further the form moved from its source, because a
## stranger form is harder to read and the player is forgiven.
static func interaction_radius(shape: float, area: float) -> float:
	var base := sqrt(maxf(0.0, area) / PI) / CANVAS
	var over := minf(1.0, maxf(0.0, (shape - THRESHOLD)
		/ (1.0 - THRESHOLD)))
	return base * (1.0 - MAX_FORGIVENESS * over)


static func _describe(v: Dictionary) -> Dictionary:
	var hull := []
	for p in v.hull:
		hull.append([float(p[0]) / CANVAS, float(p[1]) / CANVAS])
	var bbox := []
	for c in v.bbox:
		bbox.append(float(c) / CANVAS)
	return {
		"passion": v.passion,
		"objectId": v.objectId,
		"slot": v.slot,
		"src": ART_BASE + str(v.file),
		"shapeChange": v.shape,
		"hitbox": {"hull": hull, "bbox": bbox},
		"radius": interaction_radius(float(v.shape), float(v.area)),
		"analyticsId": "ludus.variant.%s.%s.%s" % [v.passion, v.objectId,
			v.slot],
	}


## The sprite for the player's next meeting with a passion.  The number
## of past meetings picks the place in the factory's queue, so drawing
## the road again shows the same sprite and each new meeting the next
## one.  Null without a passion, a manifest or art for that passion.
static func sprite_for(passion, record, manifest: Array = []) -> Variant:
	if typeof(passion) != TYPE_DICTIONARY or manifest.is_empty():
		return null
	var raw = passion.get("raw")
	var name := str(raw) if _truthy(raw) else str(passion.get("id"))
	var list := variants_of(name, manifest)
	if list.is_empty():
		return null
	var rec := normalize_record(record)
	var id := str(passion.get("id"))
	var met: int = rec[id].meetings if rec.has(id) else 0
	var key := "%s|%s" % [name, id if _truthy(passion.get("id")) else ""]
	return _describe(list[queue_index(list.size(), key, maxi(0, met))])


## The next passion on the road: the first in Evagrius' order that has
## not yet been overcome; one that took the player captive comes back
## until it is overcome.  As in the JS, the entry in `data` itself gets
## the factory sprite in `art` (and the full description in `sprite`), so
## the road and the meeting show one variant.
static func next_passion(data: Dictionary, record,
		manifest: Array = []) -> Variant:
	var rec := normalize_record(record)
	var found = null
	for id in data.order:
		var p = null
		for q in data.passions:
			if q.id == id:
				p = q
				break
		if p == null:
			continue
		if rec.has(p.id) and rec[p.id].overcome > 0:
			continue
		found = p
		break
	var sprite = sprite_for(found, record, manifest)
	if sprite != null:
		found.art = sprite.src
		found.sprite = sprite
	return found
