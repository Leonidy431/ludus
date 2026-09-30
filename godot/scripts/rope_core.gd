## The prayer rope as a metronome of the breath
## (docs/HLD_EVENING_WATCH_ROPE_2026-09-30.md, R-phases;
## docs/HLD_IMPLEMENTATION_F1_F5_2026-09-29.md "чётки как метроном
## дыхания").
##
## One knot passes the fingers with one breath: the prayer is said on
## the inhale and the exhale, and the knot is tied as the breath goes
## out.  The rope therefore accepts at most one knot per breath cycle,
## and only on the outgoing half; a press on the inhale or a second
## press in the same breath ties nothing and says why.  There is no
## failure, no streak and no score: the knot is the same one knot of
## HubCore.pray_knot (prayKnot in ludus-actions.js), counted and shown,
## never turned into points (TABOO 0.35 rule 16; TABOO 0.2 point 4:
## prayer is not a spell, the metronome only keeps the pace).
class_name RopeCore
extends RefCounted

## Jesus Prayer breathing, seconds: inhale, hold after inhale, exhale,
## hold after exhale.  Copied from hesychasm-meditation-module
## src/hesychasm/breathing_patterns.py (create_basic_pattern ...
## create_ignatius_pattern), read-only, as TABOO 0.35 rule 20 asks.
## tests/rope-breath.test.js compares this table with the module (when
## it is checked out beside ludus) and with ludus-sacred-synth.js BREATH;
## godot/tests/test_rope.gd compares it with DiveSynth.BREATH.
const BREATH := {
	"basic": {"inhale": 4.0, "hold_in": 0.0, "exhale": 6.0, "hold_out": 0.0},
	"athonite": {"inhale": 5.0, "hold_in": 1.0, "exhale": 8.0,
		"hold_out": 1.0},
	"optina": {"inhale": 4.5, "hold_in": 0.0, "exhale": 5.5,
		"hold_out": 0.0},
	"sinaite": {"inhale": 6.0, "hold_in": 2.0, "exhale": 8.0,
		"hold_out": 0.0},
	"ignatius": {"inhale": 5.0, "hold_in": 0.5, "exhale": 6.0,
		"hold_out": 0.5},
}
## The order in which the stick walks the patterns; the first is the
## beginner's, as in the module.
const ORDER := ["basic", "athonite", "optina", "sinaite", "ignatius"]
## Names by the place or the teacher of the tradition, as the module
## names its methods; no church title on the label (TABOO 0.39 point 3).
const RU := {"basic": "начальное", "athonite": "афонское",
	"optina": "оптинское", "sinaite": "синайское", "ignatius": "игнатиево"}
const PHASES := ["inhale", "hold_in", "exhale", "hold_out"]
const PHASE_RU := {"inhale": "вдох", "hold_in": "задержка",
	"exhale": "выдох", "hold_out": "тишина"}


static func cycle(name: String) -> float:
	var p: Dictionary = BREATH[name]
	return p.inhale + p.hold_in + p.exhale + p.hold_out


## Where the breath is at t seconds since the rope was taken: the phase,
## the whole cycles gone by, and the seconds left in the phase.  Phases
## of zero length are skipped.
static func phase_at(name: String, t: float) -> Dictionary:
	var p: Dictionary = BREATH[name]
	var c := cycle(name)
	var tt := maxf(0.0, t)
	var n := floori(tt / c)
	var q := tt - n * c
	for ph in PHASES:
		if q < p[ph]:
			return {"phase": ph, "cycle": n, "left": p[ph] - q}
		q -= p[ph]
	# Rounding at the very end of a cycle belongs to its last phase.
	return {"phase": "hold_out" if p.hold_out > 0.0 else "exhale",
		"cycle": n, "left": 0.0}


static func new_state(name := "basic") -> Dictionary:
	return {"pattern": name if BREATH.has(name) else "basic",
		"clock": 0.0, "last_cycle": -1}


## The next pattern in ORDER (dir +1 or -1); the clock starts again, so
## the new breath begins with an inhale.
static func turn(state: Dictionary, dir: int) -> Dictionary:
	var i := ORDER.find(state.pattern)
	var st := new_state(ORDER[posmod(i + dir, ORDER.size())])
	return st


## Try to tie a knot now.  Returns {state, actions, tied, why}; why is
## "" when tied, "inhale" when the breath is still coming in, "same"
## when this breath already has its knot.
static func tie(state: Dictionary, actions: Dictionary) -> Dictionary:
	var st := state.duplicate()
	var ph := phase_at(st.pattern, st.clock)
	if ph.phase in ["inhale", "hold_in"]:
		return {"state": st, "actions": actions, "tied": false,
			"why": "inhale"}
	if ph.cycle <= int(st.last_cycle):
		return {"state": st, "actions": actions, "tied": false, "why": "same"}
	st.last_cycle = ph.cycle
	return {"state": st, "actions": HubCore.pray_knot(actions),
		"tied": true, "why": ""}


## Moments between t0 and t1 when the hand is touched: "exhale" as the
## breath turns outward (the moment of the knot), "inhale" as a new
## breath begins.  Deterministic: they come from the table alone.
static func cues_between(name: String, t0: float, t1: float) -> Array:
	var out := []
	if t1 <= t0:
		return out
	var p: Dictionary = BREATH[name]
	var c := cycle(name)
	var ex_at: float = p.inhale + p.hold_in
	var n := floori(maxf(0.0, t0) / c)
	while n * c <= t1:
		for ev in [["inhale", n * c], ["exhale", n * c + ex_at]]:
			if ev[1] > t0 and ev[1] <= t1:
				out.append({"kind": ev[0], "at": ev[1]})
		n += 1
	return out


## Knots in a minute at this pace: shown to the player as the pace of
## the rope, never as a target.
static func knots_per_minute(name: String) -> float:
	return 60.0 / cycle(name)
