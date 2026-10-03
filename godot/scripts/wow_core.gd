## The rising curve of wow in episode 1 (operator, 2026-10-03: «должны
## по нарастающей постоянно вау эффекты»).  The plan, the chorus and the
## hooks for the scene are in docs/HLD_WOW_ESCALATION_2026-10-03.md; the
## curve and the ten effects live in godot/data/pilot-wow.json.
##
## Each beat of the pilot has a level 1..10 and each level one effect: a
## triad of light, synth and a pulse from the shared Haptics table, with
## its reduced-motion form and a note on where in the view it sits.  The
## level never falls, except at two marked "calm before" dips and at the
## khachkar, where the world quiets and there is no effect at all
## (TABOO 0.4 item 2, TABOO 0.015 item 5).  Nothing here is random
## (Constitution): the same second gives the same effect.
##
## Constitution: ФОРМА (light, water, sound and the hands of the player)
## → ДЕЙСТВИЕ (every beat answers a little stronger than the last, and
## the world falls silent at the khachkar) → ЦЕЛЬ (the player feels the
## way down and towards the light; the silence at the holy is louder
## than any effect).
class_name WowCore
extends RefCounted

const DATA := "res://data/pilot-wow.json"
const PILOT := "res://data/pilot-1.json"

static var _cache := {}


static func load_data() -> Dictionary:
	if _cache.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_cache = d if d is Dictionary else {}
	return _cache


## The beat of the curve that holds at second t (the last one begun).
static func beat_at(t: float, data: Dictionary = {}) -> Dictionary:
	var d := data if not data.is_empty() else load_data()
	var cur := {}
	for b in d.get("beats", []):
		if float(b.t) <= t:
			cur = b
	return cur


## The wow level at second t: 0 before the episode and at the holy.
static func level_at(t: float, data: Dictionary = {}) -> int:
	var b := beat_at(t, data)
	if b.is_empty() or b.get("holy", false):
		return 0
	return int(b.level)


## The effect to play at second t, with the reduced-motion form laid
## over the full one when `reduced`; {} at the holy and before the start.
static func effect_at(t: float, reduced := false,
		data: Dictionary = {}) -> Dictionary:
	var d := data if not data.is_empty() else load_data()
	var b := beat_at(t, d)
	if b.is_empty() or b.get("holy", false):
		return {}
	var e: Dictionary = d.levels.get(str(int(b.level)), {})
	if e.is_empty():
		return {}
	var out := e.duplicate(true)
	out.erase("reduced")
	out["level"] = int(b.level)
	out["beat"] = str(b.id)
	out["reduced"] = reduced
	if reduced:
		var r: Dictionary = e.reduced
		out["visual"] = r.visual.duplicate(true)
		out["haptic"] = r.haptic.duplicate(true)
		if r.has("sound"):
			out["sound"] = r.sound.duplicate(true)
	return out


## Light of the lamp during a flicker: on and off at half-period
## flicker_half_s (2.5 Hz, under the 3 Hz line for photosensitivity),
## and under reduced motion one smooth dip to 40 % with no dark frame.
## k_s is the seconds since the flicker began, len_s its length.
static func flicker_energy(base: float, k_s: float, len_s: float,
		reduced := false, data: Dictionary = {}) -> float:
	if k_s < 0.0 or k_s >= len_s:
		return base
	if reduced:
		return base * (1.0 - 0.6 * sin(PI * k_s / len_s))
	var d := data if not data.is_empty() else load_data()
	var half := float(d.get("rules", {}).get("flicker_half_s", 0.2))
	return base if int(k_s / half) % 2 == 1 else 0.0


## Flashes per second of a square flicker of the given half-period.
static func flash_hz(half_s: float) -> float:
	return 0.0 if half_s <= 0.0 else 1.0 / (2.0 * half_s)


static func _visual_problems(name: String, v: Dictionary,
		rules: Dictionary) -> Array:
	var bad := []
	if float(v.get("flash_hz", 0.0)) > float(rules.max_flash_hz):
		bad.append("%s: flashes %.2f Hz > %.1f Hz" % [name,
			float(v.flash_hz), float(rules.max_flash_hz)])
	if int(v.get("particles", 0)) > int(rules.max_particles):
		bad.append("%s: %d particles > %d" % [name, int(v.particles),
			int(rules.max_particles)])
	if float(v.get("gpu_ms", 0.0)) > float(rules.max_gpu_ms):
		bad.append("%s: %.2f ms GPU > %.1f ms" % [name, float(v.gpu_ms),
			float(rules.max_gpu_ms)])
	if v.get("moves_camera", true):
		bad.append("%s: turns or moves the player's view" % name)
	return bad


## Everything that breaks the curve's rules, as readable lines; [] when
## it keeps them.  `pilot` is pilot-1.json (loaded when not given).
static func check(data: Dictionary = {}, pilot: Dictionary = {}) -> Array:
	var d := data if not data.is_empty() else load_data()
	var p := pilot
	if p.is_empty():
		var pp = JSON.parse_string(FileAccess.get_file_as_string(PILOT))
		p = pp if pp is Dictionary else {}
	var bad := []
	var rules: Dictionary = d.get("rules", {})
	var kinds := Haptics.PULSES
	# The curve follows the episode beat by beat.
	var pb: Array = p.get("beats", [])
	var wb: Array = d.get("beats", [])
	if pb.size() != wb.size():
		bad.append("curve has %d beats, the episode %d" % [wb.size(),
			pb.size()])
	for i in mini(pb.size(), wb.size()):
		if str(pb[i].id) != str(wb[i].id) \
				or float(pb[i].t) != float(wb[i].t):
			bad.append("beat %d: %s@%s, episode has %s@%s" % [i,
				wb[i].id, wb[i].t, pb[i].id, pb[i].t])
		if pb[i].get("holy", false) != wb[i].get("holy", false):
			bad.append("%s: holy flag differs from the episode"
				% wb[i].id)
	# Monotone, two dips at most, each with its why; holy is level 0.
	var peak := 0
	var dips := 0
	var last_rise := 0.0
	var holy_s := 0.0
	for i in wb.size():
		var b: Dictionary = wb[i]
		var lv := int(b.get("level", 0))
		var end := float(p.get("length_s", 900.0)) if i + 1 >= wb.size() \
			else float(wb[i + 1].t)
		if b.get("holy", false):
			if lv != 0:
				bad.append("%s: the holy has wow level %d" % [b.id, lv])
			if b.has("effect"):
				bad.append("%s: an effect at the holy" % b.id)
			holy_s += end - float(b.t)
			continue
		if lv < 1 or lv > 10:
			bad.append("%s: level %d outside 1..10" % [b.id, lv])
		if lv < peak:
			dips += 1
			if str(b.get("why", "")).strip_edges().is_empty():
				bad.append("%s: falls %d → %d without why" % [b.id, peak,
					lv])
		elif lv > peak:
			# The holy seconds do not count: the world is meant to rest.
			var gap := float(b.t) - last_rise - holy_s
			if peak > 0 and gap > float(rules.max_rise_gap_s):
				bad.append("%s: %.0f s without a rise > %d s" % [b.id, gap,
					int(rules.max_rise_gap_s)])
			peak = lv
			last_rise = float(b.t)
			holy_s = 0.0
		if not d.levels.has(str(lv)):
			bad.append("%s: no effect for level %d" % [b.id, lv])
	# A curve that stops below the top must not rest there too long.
	var tail := float(p.get("length_s", 900.0)) - last_rise - holy_s
	if peak < 10 and tail > float(rules.max_rise_gap_s):
		bad.append("the curve stalls at %d for %.0f s before the end"
			% [peak, tail])
	if dips > int(rules.max_dips):
		bad.append("%d dips > %d" % [dips, int(rules.max_dips)])
	# Every level: the triad, in budget, with its reduced form.
	for k in d.levels:
		var e: Dictionary = d.levels[k]
		for part in ["visual", "sound", "haptic", "ergonomics"]:
			if not e.has(part):
				bad.append("level %s: no %s" % [k, part])
		bad.append_array(_visual_problems("level " + k,
			e.get("visual", {}), rules))
		var hk := str(e.get("haptic", {}).get("kind", ""))
		if not kinds.has(hk):
			bad.append("level %s: unknown haptic kind '%s'" % [k, hk])
		var er: Dictionary = e.get("ergonomics", {})
		if float(er.get("distance_m", 0.0)) < float(rules.min_distance_m):
			bad.append("level %s: closer than %.1f m" % [k,
				float(rules.min_distance_m)])
		if str(er.get("comfort_ru", "")).is_empty():
			bad.append("level %s: no comfort note" % k)
		if not e.has("reduced") or not e.reduced.has("visual") \
				or not e.reduced.has("haptic"):
			bad.append("level %s: no reduced-motion variant" % k)
			continue
		var rv: Dictionary = e.reduced.visual
		bad.append_array(_visual_problems("level %s reduced" % k, rv,
			rules))
		if float(rv.get("flash_hz", 0.0)) > 0.0:
			bad.append("level %s reduced: still flashes" % k)
		if int(rv.get("particles", 0)) \
				> int(e.get("visual", {}).get("particles", 0)):
			bad.append("level %s reduced: more particles than full" % k)
		var rk := str(e.reduced.haptic.get("kind", ""))
		if not rk.is_empty() and not kinds.has(rk):
			bad.append("level %s reduced: unknown haptic kind '%s'"
				% [k, rk])
		if rk in Haptics.AMBIENT:
			bad.append("level %s reduced: ambient pulse '%s' kept" % [k,
				rk])
	var fh := flash_hz(float(rules.get("flicker_half_s", 0.0)))
	if fh > float(rules.get("max_flash_hz", 3.0)):
		bad.append("flicker %.2f Hz > %.1f Hz" % [fh,
			float(rules.max_flash_hz)])
	return bad
