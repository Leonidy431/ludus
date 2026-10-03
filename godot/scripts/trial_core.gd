## The thresholds of the gates and the fall they can lead to, ported
## from public/ludus/ludus-missions.js (trialView, chooseTrial,
## fallStatus, liftFall).  The JS module is the reference:
## godot/tests/test_trial.gd replays godot/tests/trial_fixture.json,
## written from it by scripts/godot/make_trial_fixture.js.
##
## A threshold is a choice by understanding, not a quiz: each option
## leads somewhere ("through", "return" to the mentor, or a "fall"
## into a passion).  The fall closes the deep paths until it is lifted
## by sobriety (stillness or guarding the thoughts, counted as more
## than when it began) together with a new talk with the mentor who
## teaches that passion's sign.  Nothing is scored or tallied: the fall
## is dropped whole when it is lifted.
##
## While a fall lasts every threshold is locked (trial_view returns
## locked with reason "fall"), so a second fall can never overwrite the
## first one and its snapshot (HLD_TRIALS_LADDER_2026-10-03, F9).  The
## ladder of HubCore also asks that the threshold of gate N be passed
## before gate N+1 opens (chorus decision in the same HLD).
class_name TrialCore
extends RefCounted

const GATE_IDS := ["foundational", "liturgical", "ascetic",
	"contemplative", "mystical", "apophatic"]


static func load_data() -> Dictionary:
	return {
		"trials": JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/gate-trials.json")),
		"passions": JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/passions.json")),
	}


static func empty_state() -> Dictionary:
	return {"trials": {}, "trial_wait": {}, "fall": null}


static func _num(v) -> float:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) \
			and float(v) > 0.0:
		return float(v)
	return 0.0


static func _met(actions: Dictionary, who: String) -> float:
	return _num(actions.get("met", {}).get(who, 0))


static func passion_of(data: Dictionary, id) -> Dictionary:
	for p in data.passions.passions:
		if p.id == id:
			return p
	return {}


static func trial_for(data: Dictionary, gate_id: String) -> Dictionary:
	for t in data.trials.trials:
		if t.gateId == gate_id:
			return t
	return {}


## Sobriety: guarding the thoughts, plus every whole minute of stillness.
static func sobriety_of(actions: Dictionary) -> int:
	var guard := 0.0
	var pr: Dictionary = actions.get("practices", {})
	if pr.has("guard_thoughts"):
		guard = _num(pr.guard_thoughts.get("count", 0))
	return int(guard) + floori(_num(actions.get("meditationHours", 0.0))
		* 60.0 + 1e-6)


static func _fall_into(data: Dictionary, st: Dictionary, passion_id,
		actions: Dictionary) -> void:
	# The first fall stands until it is lifted: its snapshot is what
	# sobriety and the mentor's talk are measured against, so a second
	# fall must not quietly reset it.
	if st.get("fall") != null:
		return
	var p := passion_of(data, passion_id)
	var teacher: String = p.get("teacher", "elder_sergius")
	st.fall = {"passion": passion_id, "teacher": teacher,
		"closed": ["deep", "road"], "since": {
			"sobriety": sobriety_of(actions),
			"met": int(_met(actions, teacher))}}


## The threshold of a gate: open only when the gate itself is open (the
## ladder of HubCore, which also asks that the previous threshold be
## passed), waiting after a "return" until a new talk with the mentor,
## done once passed, and locked for as long as a fall lasts.
static func trial_view(data: Dictionary, st: Dictionary, gate_id: String,
		form: Dictionary, actions: Dictionary) -> Dictionary:
	var trial := trial_for(data, gate_id)
	if trial.is_empty():
		return {}
	var open := false
	for c in HubCore.evaluate_ladder(form, actions, st.get("trials", {})):
		if c.id == gate_id:
			open = c.open
	# A fall closes every threshold, not only the deep paths: a choice
	# made in the dark would be made by the passion, not by the player.
	var locked: bool = st.get("fall") != null
	var waiting: bool = st.trial_wait.has(gate_id) \
		and _met(actions, trial.mentor) <= st.trial_wait[gate_id]
	var passed: bool = st.trials.get(gate_id, false)
	var options := []
	for o in trial.options:
		options.append({"id": o.id, "text": o.text_ru,
			"disabled": not open or waiting or passed or locked})
	return {"trial": trial, "open": open, "passed": passed,
		"waiting": waiting, "locked": locked,
		"reason": "fall" if locked else "", "options": options}


## Take an option.  Returns {state, outcome, reply, source, passion};
## a disabled or unknown option changes nothing (outcome null).
static func choose_trial(data: Dictionary, state: Dictionary,
		gate_id: String, option_id: String, form: Dictionary,
		actions: Dictionary) -> Dictionary:
	var st := state.duplicate(true)
	var tv := trial_view(data, st, gate_id, form, actions)
	if tv.is_empty():
		return {"state": st, "outcome": null, "reply": ""}
	var opt := {}
	for o in tv.trial.options:
		if o.id == option_id:
			opt = o
	var shown := {}
	for o in tv.options:
		if o.id == option_id:
			shown = o
	if opt.is_empty() or shown.is_empty() or shown.disabled:
		return {"state": st, "outcome": null, "reply": ""}
	match opt.outcome:
		"through":
			st.trials[gate_id] = true
			st.trial_wait.erase(gate_id)
		"return":
			st.trial_wait[gate_id] = int(_met(actions, tv.trial.mentor))
		"fall":
			_fall_into(data, st, opt.passion, actions)
	return {"state": st, "outcome": opt.outcome, "reply": opt.reply_ru,
		"source": opt.get("source", ""), "passion": opt.get("passion")}


static func fall_status(data: Dictionary, st: Dictionary,
		actions: Dictionary) -> Dictionary:
	if st.fall == null:
		return {"fallen": false}
	var f: Dictionary = st.fall
	var p := passion_of(data, f.passion)
	var sober := sobriety_of(actions) > int(f.since.sobriety)
	var taught := int(_met(actions, f.teacher)) > int(f.since.met)
	return {"fallen": true, "passion": f.passion,
		"passion_ru": p.get("name_ru", f.passion), "cue": p.get("cue_ru", ""),
		"virtue_ru": p.get("virtue_ru", ""), "teacher": f.teacher,
		"sober": sober, "taught": taught, "can_lift": sober and taught}


## The fall is dropped whole when it can be lifted.
static func lift_fall(data: Dictionary, state: Dictionary,
		actions: Dictionary) -> Dictionary:
	var st := state.duplicate(true)
	if fall_status(data, st, actions).get("can_lift", false):
		st.fall = null
	return st
