## The rules of the monastery hub, ported from the web game.
##
## Gates: public/ludus/ludus-actions.js (GATES, evaluate, evaluateLadder,
## prayKnot, addStillness, recordMeeting, acceptGift).  The JS module is
## the reference; godot/tests/run_hub_tests.gd checks this port against
## godot/tests/hub_fixture.json, written from the JS by
## scripts/godot/make_hub_fixture.js.
##
## Dialogues: the same public/ludus/data/dialogue-trees.json as the web
## game (TABOO 0.39 point 6: one idiom and meaning for both versions).  A
## branch's condition is a set of attribute minimums; its bonuses are
## added deterministically (Constitution: no random rolls).
class_name HubCore
extends RefCounted

const ATTRIBUTES := ["wisdom", "faith", "dexterity", "constitution",
	"charisma", "cunning", "erudition"]
const GATES := [
	{"id": "foundational", "ru": "Основание", "wisdom": 4,
		"mentors": ["theodora"], "gift": false,
		"rite": {"key": "prayerCount", "min": 10.0, "per_minute": false,
			"ru": "узлов на вервице"}},
	{"id": "liturgical", "ru": "Служба", "wisdom": 6,
		"mentors": ["theodora", "elder_sergius"], "gift": false,
		"rite": {"key": "prayerCount", "min": 33.0, "per_minute": false,
			"ru": "узлов на вервице"}},
	{"id": "ascetic", "ru": "Подвиг", "wisdom": 8,
		"mentors": ["abba_john"], "gift": false,
		"rite": {"key": "fastDays", "min": 1.0, "per_minute": false,
			"ru": "день поста"}},
	{"id": "contemplative", "ru": "Созерцание", "wisdom": 10,
		"mentors": ["elder_sergius"], "gift": true,
		"rite": {"key": "meditationHours", "min": 10.0 / 60.0,
			"per_minute": true, "ru": "минут безмолвия"}},
	{"id": "mystical", "ru": "Свет", "wisdom": 12,
		"mentors": ["sister_catherine"], "gift": true,
		"rite": {"key": "meditationHours", "min": 30.0 / 60.0,
			"per_minute": true, "ru": "минут безмолвия"}},
	{"id": "apophatic", "ru": "Молчание", "wisdom": 14,
		"mentors": ["elder_sergius", "theodora", "abba_john",
			"sister_catherine"], "gift": true,
		"rite": {"key": "meditationHours", "min": 1.0, "per_minute": true,
			"ru": "минут безмолвия"}},
]
## The four mentors of the gates stand in the scriptorium.
const MENTORS := ["elder_sergius", "theodora", "abba_john",
	"sister_catherine"]


static func new_form() -> Dictionary:
	var form := {}
	for a in ATTRIBUTES:
		form[a] = 1  # The guest's seed minimum, as in ludus-game.js.
	return form


static func new_actions() -> Dictionary:
	return {"prayerCount": 0.0, "fastDays": 0.0, "meditationHours": 0.0,
		"met": {}, "gifts": {}, "lastFastDay": null}


## Today's fast, kept once per calendar day (keepFast in
## ludus-actions.js).  The day is the player's local date "YYYY-MM-DD";
## anything else changes nothing, and a second fast on the same day
## counts nothing more.
static func keep_fast(actions: Dictionary, iso_day) -> Dictionary:
	var n := actions.duplicate(true)
	var re := RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$")
	if typeof(iso_day) != TYPE_STRING or re.search(iso_day) == null:
		return n
	if n.get("lastFastDay") != iso_day:
		n.fastDays = _num(n.fastDays) + 1.0
		n.lastFastDay = iso_day
	return n


static func _num(v) -> float:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) \
			and float(v) > 0.0:
		return float(v)
	return 0.0


## One knot of the prayer rope.  It is counted and shown, never turned
## into points or attributes (TABOO 0.35 rule 16).
static func pray_knot(actions: Dictionary) -> Dictionary:
	var n := actions.duplicate(true)
	n.prayerCount = _num(n.prayerCount) + 1.0
	return n


static func add_stillness(actions: Dictionary, minutes: float) -> Dictionary:
	var n := actions.duplicate(true)
	n.meditationHours = _num(n.meditationHours) + maxf(0.0, minutes) / 60.0
	return n


static func record_meeting(actions: Dictionary, npc_id: String) -> Dictionary:
	var n := actions.duplicate(true)
	n.met[npc_id] = int(n.met.get(npc_id, 0)) + 1
	return n


static func rite_progress(gate: Dictionary, actions: Dictionary) -> Dictionary:
	var have := _num(actions.get(gate.rite.key, 0.0))
	var scale := 60.0 if gate.rite.per_minute else 1.0
	return {"have": floori(have * scale + 1e-6),
		"need": roundi(gate.rite.min * scale), "ru": gate.rite.ru,
		"done": have + 1e-9 >= gate.rite.min}


## The three-part check (and the gift for gates 4-6), as evaluate() in
## ludus-actions.js.  Returns {id, open, missing: [kinds], ready_for_gift}.
static func evaluate(gate: Dictionary, form: Dictionary,
		actions: Dictionary) -> Dictionary:
	var missing := []
	var wisdom := _num(form.get("wisdom", 0))
	if wisdom < gate.wisdom:
		missing.append("form")
	var unmet := []
	for m in gate.mentors:
		if not actions.met.get(m, 0):
			unmet.append(m)
	if not unmet.is_empty():
		missing.append("dialogue")
	var rite := rite_progress(gate, actions)
	if not rite.done:
		missing.append("rite")
	var ready: bool = gate.gift and missing.is_empty()
	if gate.gift and not actions.gifts.get(gate.id, false):
		missing.append("gift")
	return {"id": gate.id, "open": missing.is_empty(), "missing": missing,
		"unmet": unmet, "rite": rite, "ready_for_gift": ready}


## Gates are a ladder: a higher gate never opens before a lower one.
##
## When the trial state's "trials" dictionary is given (gate id -> true
## once its threshold is passed), gate N+1 also waits for the threshold
## of gate N: a "return" there keeps the next gate closed until the
## threshold is passed (chorus decision, HLD_TRIALS_LADDER_2026-10-03).
## Without it (null) the ladder is the three-part check alone, as
## evaluateLadder(form, actions) in ludus-actions.js.
static func evaluate_ladder(form: Dictionary, actions: Dictionary,
		trials = null) -> Array:
	var blocked := false
	var trial_due := false
	var out := []
	for gate in GATES:
		var check := evaluate(gate, form, actions)
		if blocked and check.open:
			check.open = false
			check.missing.append("ladder")
		elif trial_due and check.open:
			check.open = false
			check.missing.append("trial")
		if not check.open:
			blocked = true
		trial_due = _threshold_due(gate.id, trials)
		out.append(check)
	return out


## True when the trial state is given and the threshold of this gate is
## not yet passed.  A threshold is never counted as points: it is only
## crossed or not (TABOO 0.35 rule 16).
static func _threshold_due(gate_id: String, trials) -> bool:
	if not (trials is Dictionary):
		return false
	return not bool(trials.get(gate_id, false))


## The bow for gates 4-6, accepted only when every other condition holds.
static func accept_gift(actions: Dictionary, form: Dictionary,
		gate_id: String) -> Dictionary:
	var n := actions.duplicate(true)
	for gate in GATES:
		if gate.id == gate_id and gate.gift:
			if evaluate(gate, form, n).ready_for_gift:
				n.gifts[gate_id] = true
	return n


# --- Dialogues ----------------------------------------------------------

static func node_of(tree: Dictionary, node_id) -> Dictionary:
	for n in tree.nodes:
		if n.id == node_id:
			return n
	return {}


## Branches the FORM allows: every attribute in the condition is met
## (DialogueCore, checked against the web game's dialogue manager).
static func open_branches(node: Dictionary, form: Dictionary) -> Array:
	return DialogueCore.open_branches(node, form)


## Take a branch: its declared bonuses are added (only the seven
## attributes, +1..+5 each, as the JS clamps them), and the next node id
## (or null at the end of the talk) is returned.
static func choose(form: Dictionary, branch: Dictionary) -> Dictionary:
	return DialogueCore.apply(form, branch)
