## The small acts at the hearts of 26 places (docs/HLD_L3_PLACE_DEEDS_
## 2026-10-01.md; CLAUDE.md TABOO 0.013 item 1: the heart of a place is
## one practice or one act whose logic stands apart and under test, as
## RuleCore does for the evening watch).
##
## Twenty-three places had a heart marked "new" and three a find of the
## lake: their panels named the act and counted nothing.  Each act now
## lives in one of five group files, deeds_a.gd … deeds_e.gd, written
## and tested apart (tests/deeds/test_deeds_<g>.gd).  This file only
## routes an act to its group, keeps the record and checks the contract.
##
## The contract of a group file (static functions, no state of its own):
##   ids() -> Array            the act ids it owns;
##   start(id) -> Dictionary   the act's first state; must hold
##                             "done": false and "reply": "";
##   lines(id, s) -> Array     body lines of the panel (the heart adds the
##                             title, the place's teaching and "Отойти");
##   options(id, s) -> Array   {id, text, disabled, reason} buttons;
##   choose(id, s, c) -> Dict  the next state for button id c; "reply"
##                             says what happened, "done" closes the act;
##   tick(id, s, dt, still) -> Dictionary
##                             the state after dt seconds (an act that
##                             asks to wait still); others return s.
## The same state and choice always give the same next state: no
## randomness anywhere (Constitution: no chance in outcomes).  An act
## never changes FORM and never gives a point: it is done or not, and
## the record keeps only how many times and the last day, as the rule's
## practices do (RuleCore).  A wrong step answers with a reply that
## teaches and lets the player try again; it never punishes.
##
## Constitution: ФОРМА (the place, its craft and its things) → ДЕЙСТВИЕ
## (one act done in the right order, by the place's own measure) → ЦЕЛЬ
## (the lesson of the place learned by the hands, not by a counter).
class_name PlaceDeeds
extends RefCounted

## The group file of every act.  A find of the lake is "find:<object>".
const GROUPS := {
	"forge-nail": "a", "caulk-seam": "a", "proof-the-block": "a",
	"rope-right-angle": "a", "prune-vine": "a",
	"share-water": "b", "carry-archive-up": "b", "test-ice": "b",
	"take-core": "b", "read-waterline": "b",
	"separate-contract": "c", "speak-of-maker": "c",
	"hear-both-sides": "c", "tell-custom-from-faith": "c",
	"teach-a-letter": "c",
	"lay-a-stone": "d", "seal-the-chronicle": "d", "find-pole-star": "d",
	"tell-only-true": "d", "compare-forms": "d",
	"wait-out-storm": "e", "spot-the-haze": "e", "type-by-memory": "e",
	"find:bulla.shallows.0": "e", "find:fundament.shallows.1": "e",
	"find:chebachok.shallows.0": "e",
}
const DIR := "res://scripts/deeds/deeds_%s.gd"

static var _scripts := {}


## The act id of a heart spec, or "" when the heart is not one of these.
static func act_of(h: Dictionary) -> String:
	if h.get("core", "") == "new":
		return str(h.get("id", ""))
	if h.get("core", "") == "MissionCore" and h.get("step", "") == "find":
		return "find:" + str(h.get("object", ""))
	return ""


static func _group(id: String) -> Script:
	var g: String = GROUPS.get(id, "")
	if g == "":
		return null
	if not _scripts.has(g):
		_scripts[g] = load(DIR % g)
	return _scripts[g]


## True when the act's group owns it and has its logic.
static func has(id: String) -> bool:
	var s := _group(id)
	return s != null and id in s.call("ids")


static func start(id: String) -> Dictionary:
	return _group(id).call("start", id)


static func lines(id: String, s: Dictionary) -> Array:
	return _group(id).call("lines", id, s)


static func options(id: String, s: Dictionary) -> Array:
	return _group(id).call("options", id, s)


static func choose(id: String, s: Dictionary, c: String) -> Dictionary:
	return _group(id).call("choose", id, s.duplicate(true), c)


static func tick(id: String, s: Dictionary, dt: float,
		still: bool) -> Dictionary:
	return _group(id).call("tick", id, s.duplicate(true), dt, still)


## The record of the acts as a save holds it, in the known shape only:
## {id: {"count": int >= 0, "lastDay": "YYYY-MM-DD" or null}} for known
## ids; anything else in a hand-edited save is dropped.
static func normalize(raw) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	var day_re := RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$")
	for id in raw:
		if not GROUPS.has(id) or not raw[id] is Dictionary:
			continue
		var c = raw[id].get("count", 0)
		var d = raw[id].get("lastDay")
		out[id] = {"count": maxi(0, int(c)) if typeof(c) in [TYPE_INT,
				TYPE_FLOAT] else 0,
			"lastDay": d if typeof(d) == TYPE_STRING
				and day_re.search(d) != null else null}
	return out


## True when the act was done on this day already.
static func done_today(rec: Dictionary, id: String, day: String) -> bool:
	return rec.get(id, {}).get("lastDay") == day


## The record after the act is done on day: once a day counts.
static func record(rec: Dictionary, id: String, day: String) -> Dictionary:
	var out := normalize(rec)
	if done_today(out, id, day):
		return out
	var n: int = out.get(id, {}).get("count", 0)
	out[id] = {"count": n + 1, "lastDay": day}
	return out
