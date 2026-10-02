## How a place shows that standing still counts while an act asks to
## wait (docs/BLINDSPOTS_CODE_BREAKTHROUGH_2026-10-01.md, item 9).
##
## The storm at the bay (wait-out-storm, deeds_e.gd) closes after the
## player has stood still for its seconds.  Before this file the player
## could not tell whether the standing was counted, and a tremor of the
## thumb on the stick (any reading over 0.1) started the count again.
## Now:
##   - the place answers the waiting itself, with no number: the
##     lantern's flicker in the wind and the loudness of the surf and the
##     rain settle as the seconds pass, and come back when the player
##     moves (the storm is not over until the wait is);
##   - a dead zone on the stick and a short grace: a reading under
##     DEAD_ZONE is stillness, and a reading over it counts as moving
##     only after GRACE_SECONDS, so a tremor of the hand does not reset
##     the wait, while a real step still does.
## The act's own logic and its seconds stay in deeds_e.gd (PlaceDeeds);
## this file only reads the act's state and the length of its waiting
## step.  Nothing is counted, shown as a number or saved here.
##
## Light stays gentle: the gusts are below 2 Hz (no flashing, which
## must stay under 3 a second) and swing the lantern by at most
## FLICKER of its energy.
##
## Constitution: ФОРМА (the bay, its lantern and its surf) → ДЕЙСТВИЕ
## (standing still under the awning while the current runs) → ЦЕЛЬ
## (the storm ends by itself and is waited out, not commanded: prayer
## is not a switch of currents, node 48).
class_name StormCalm
extends RefCounted

## Stick magnitude under which the player stands still.  A thumb resting
## on a Quest controller reads up to about 0.15 by drift and tremor.
const DEAD_ZONE := 0.25
## A move over the dead zone shorter than this is forgiven as a tremor.
const GRACE_SECONDS := 0.5
## How much quieter the crafts of the place (surf, rain) are when the
## wait is complete, in dB.
const SURF_CALM_DB := -9.0
## Share of the lantern's energy that swings in the full storm.
const FLICKER := 0.3
## The wind's gusts: [Hz, weight, phase]; weights sum to 1.
const GUSTS := [[0.37, 0.6, 0.0], [0.91, 0.3, 1.3], [1.73, 0.1, 2.1]]
## How fast the storm comes back when the player moves: the whole way in
## this many seconds, so it rises and does not jump.
const RETURN_SECONDS := 1.5

## The steps of each act once read (the scene asks every frame).
static var _cache := {}


## A fresh watch of the stick.
static func new_watch() -> Dictionary:
	return {"moving": 0.0, "still": true}


## The watch after dt seconds with the stick at magnitude stick.
static func watch(w: Dictionary, stick: float, dt: float) -> Dictionary:
	var moving := 0.0
	if stick >= DEAD_ZONE:
		moving = float(w.get("moving", 0.0)) + maxf(dt, 0.0)
	return {"moving": moving, "still": moving < GRACE_SECONDS}


## Seconds of the waiting step the act stands at, or 0 when it is not
## at one (or has no such step).
static func wait_seconds(id: String, deed: Dictionary) -> float:
	var steps := _steps(id)
	var i := int(deed.get("step", 0))
	if deed.get("done", false) or i < 0 or i >= steps.size():
		return 0.0
	var step = steps[i]
	if step is Dictionary and step.has("wait"):
		return float(step.wait)
	return 0.0


## Whether the act has a waiting step at all (then its place is stormy
## until the wait is over).
static func has_wait(id: String) -> bool:
	for step in _steps(id):
		if step is Dictionary and step.has("wait"):
			return true
	return false


## The calm of the place for an act's state, 0 (full storm) .. 1 (the
## storm has passed), or -1 when the act asks no waiting.  Before the
## waiting step the storm is full; at it the calm grows with the seconds
## stood; once the act is done the storm has passed.
static func calm(id: String, deed: Dictionary) -> float:
	if not has_wait(id):
		return -1.0
	if deed.get("done", false):
		return 1.0
	var wait := wait_seconds(id, deed)
	if wait <= 0.0:
		return 0.0
	return clampf(float(deed.get("waited", 0.0)) / wait, 0.0, 1.0)


## The shown calm follows the act's: it settles as fast as the act
## counts, and the storm comes back over RETURN_SECONDS.
static func follow(shown: float, target: float, dt: float) -> float:
	if target >= shown:
		return target
	return maxf(target, shown - maxf(dt, 0.0) / RETURN_SECONDS)


## Loudness offset of the place's crafts (surf, rain), dB.
static func surf_db(c: float) -> float:
	return SURF_CALM_DB * clampf(c, 0.0, 1.0)


## The lantern's energy factor at time t: 1 when calm, swinging by up
## to FLICKER in the full storm, the same at the same t.
static func lamp_factor(c: float, t: float) -> float:
	var g := 0.0
	for gust in GUSTS:
		g += float(gust[1]) * sin(TAU * float(gust[0]) * t
			+ float(gust[2]))
	return 1.0 + FLICKER * (1.0 - clampf(c, 0.0, 1.0)) * g


## The steps of an act as its group file writes them (its ACTS table),
## or [] for an act whose group keeps no such table.
static func _steps(id: String) -> Array:
	if _cache.has(id):
		return _cache[id]
	var out := []
	var g: String = PlaceDeeds.GROUPS.get(id, "")
	if g != "":
		var script: Script = load(PlaceDeeds.DIR % g)
		var acts = script.get_script_constant_map().get("ACTS", {})
		if acts is Dictionary and acts.get(id) is Array:
			out = acts[id]
	_cache[id] = out
	return out
