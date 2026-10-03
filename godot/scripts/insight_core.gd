## Insights: flashbacks to another epoch that come by themselves when
## the player's place, the order of his deeds, the clock, the depth, the
## step of his thought or his stillness calls them (operator, 2026-10-02:
## «эффект прихода инсайтов флешбеков если место последовательность
## время или иной фактор их вызывает»).  The plan and the chorus are in
## docs/HLD_INSIGHTS_FLASHBACKS_2026-10-02.md; the twelve of episode 1
## live in godot/data/pilot-insights.json.
##
## The logic is here, apart from the scene and under test: which insight
## is due, and whether the hands or the eyes have asked to skip it.
## Nothing is random (Constitution): the same body on the same path gets
## the same insights in the same order.  The holy never calls one: no
## trigger may name it, and none comes in the beat of the khachkar.
class_name InsightCore
extends RefCounted

const DATA := "res://data/pilot-insights.json"
const FACTORS := ["time", "place", "sequence", "depth", "find", "stage",
	"still"]
const STAGES := ["prilog", "converse", "consent", "captive", "stillness",
	"virtue"]


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


## True when every name of `need` is in `events` in that order (other
## events may come between them).
static func in_order(events: Array, need: Array) -> bool:
	var i := 0
	for e in events:
		if i < need.size() and e == need[i]:
			i += 1
	return i == need.size()


## Whether the trigger of one insight holds for this frame.  ctx: t,
## world, beat, head (Vector3), forward (Vector3), depth, events (Array of
## "beat:x", "look:x", "clue:x", "stage:x"), stage, still_s, look_s (the
## seconds each place has been held in view, by insight id, kept by the
## caller; a number stands for all).
static func holds(x: Dictionary, ctx: Dictionary) -> bool:
	var g: Dictionary = x.trigger
	match str(x.factor):
		"time":
			return float(ctx.t) >= float(g.at)
		"place":
			var ls = ctx.get("look_s", 0.0)
			if ls is Dictionary:
				ls = ls.get(x.id, 0.0)
			return str(ctx.world) == str(g.world) \
				and float(ls) >= float(g.hold_s)
		"sequence", "find":
			return in_order(ctx.events, g.after)
		"depth":
			return float(ctx.depth) >= float(g.depth_m)
		"stage":
			return str(ctx.stage) == str(g.stage)
		"still":
			return str(ctx.beat) == str(g.beat) \
				and float(ctx.still_s) >= float(g.still_s)
	return false


## Whether the head is on a place of a "place" trigger this frame: near
## enough and inside its cone.  The caller adds dt to look_s while true.
static func on_place(x: Dictionary, head: Vector3, forward: Vector3) -> bool:
	if str(x.factor) != "place":
		return false
	var g: Dictionary = x.trigger
	var p := Vector3(g.pos[0], g.pos[1], g.pos[2])
	var to := p - head
	if to.length() > float(g.range_m) or to.length() < 0.001:
		return false
	return rad_to_deg(forward.angle_to(to)) <= float(g.cone_deg)


## The insight to play now, or {} when none.  The first one in the
## file's order whose window is open and whose trigger holds; none in
## the cold open, in a beat with no insights, while another plays or the
## glasses are on (busy), or within cooldown_s of the last.
static func due(data: Dictionary, ctx: Dictionary) -> Dictionary:
	if bool(ctx.get("busy", false)):
		return {}
	if float(ctx.t) < float(data.cold_open_s):
		return {}
	if str(ctx.beat) in data.no_insight_beats:
		return {}
	if float(ctx.get("since_last", INF)) < float(data.cooldown_s):
		return {}
	for x in data.insights:
		if x.id in ctx.get("shown", []):
			continue
		var w: Array = x.window
		if float(ctx.t) < float(w[0]) or float(ctx.t) > float(w[1]):
			continue
		if holds(x, ctx):
			return x
	return {}


## The skip, by the hands or by the eyes.  inp: stick (the larger
## thumbstick deflection of the two hands, 0..1), grips (both grips
## held), icon (the head or a controller's ray on the skip icon).  The
## hands must pull and hold, the eyes must rest: a brush of the stick or
## a glance does not throw the memory away.  Returns the new state, skip
## (bool) and progress (0..1, the fullest of the three, for the ring).
static func skip_step(sk: Dictionary, cfg: Dictionary, dt: float,
		inp: Dictionary) -> Dictionary:
	var s := {
		"stick_s": float(sk.get("stick_s", 0.0)),
		"grip_s": float(sk.get("grip_s", 0.0)),
		"icon_s": float(sk.get("icon_s", 0.0)),
	}
	var pulled := float(inp.get("stick", 0.0)) >= float(cfg.stick_min)
	s.stick_s = s.stick_s + dt if pulled else 0.0
	s.grip_s = s.grip_s + dt if bool(inp.get("grips", false)) else 0.0
	s.icon_s = s.icon_s + dt if bool(inp.get("icon", false)) else 0.0
	var p := maxf(s.stick_s / float(cfg.stick_hold_s),
		maxf(s.grip_s / float(cfg.grip_hold_s),
		s.icon_s / float(cfg.icon_hold_s)))
	# A hair of tolerance: ten frames of 0.1 s add up to 0.99999.
	return {"state": s, "skip": p >= 1.0 - 1e-4,
		"progress": clampf(p, 0.0, 1.0)}


## Where the skip icon hangs: low and to the right of where the head
## looked when the insight began, fixed in the world there, so a turn of
## the head can rest on it (an icon nailed to the eyes could never be
## looked at).
static func icon_at(cfg: Dictionary, head: Vector3, forward: Vector3) \
		-> Vector3:
	var f := Vector3(forward.x, 0.0, forward.z)
	if f.length() < 0.001:
		f = Vector3(0, 0, -1)
	f = f.normalized()
	var right := f.cross(Vector3.UP).normalized()
	var d := f.rotated(Vector3.UP, -deg_to_rad(float(cfg.icon_right_deg)))
	d = d.rotated(right, -deg_to_rad(float(cfg.icon_down_deg)))
	return head + d.normalized() * float(cfg.icon_dist_m)


## The rules of the twelve: exactly twelve, each with a known factor,
## a trigger of its shape and a window; never the holy as a trigger and
## never a window over a beat without insights; a third-person line of
## at most 140 characters bridged to a beat that exists; an image from
## the prerenders already in the APK or none.  Every factor of the
## operator's words appears: place, sequence, time and the others.
static func check(data: Dictionary, pilot: Dictionary) -> Array:
	var bad := []
	var ins: Array = data.get("insights", [])
	if ins.size() != 12:
		bad.append("%d insights, not 12" % ins.size())
	var beats := {}
	for b in pilot.get("beats", []):
		beats[b.id] = b
	var ids := {}
	var factors := {}
	var holy: Array = data.get("holy_ids", [])
	for x in ins:
		var id := str(x.get("id", ""))
		if ids.has(id):
			bad.append("insight %s twice" % id)
		ids[id] = true
		var f := str(x.get("factor", ""))
		factors[f] = true
		if not f in FACTORS:
			bad.append("%s: factor %s" % [id, f])
		var g: Dictionary = x.get("trigger", {})
		var need := {"time": ["at"], "place": ["world", "pos", "range_m",
			"cone_deg", "hold_s"], "sequence": ["after"], "find": ["after"],
			"depth": ["depth_m"], "stage": ["stage"],
			"still": ["beat", "still_s"]}
		for k in need.get(f, []):
			if not g.has(k):
				bad.append("%s: trigger without %s" % [id, k])
		if f == "stage" and not str(g.get("stage", "")) in STAGES:
			bad.append("%s: no such stage" % id)
		for e in g.get("after", []):
			var name := str(e).get_slice(":", 1)
			if name in holy:
				bad.append("%s: the holy calls it" % id)
			if str(e).begins_with("beat:") and not beats.has(name):
				bad.append("%s: no beat %s" % [id, name])
		if str(g.get("beat", "")) in data.get("no_insight_beats", []):
			bad.append("%s: it waits in a beat without insights" % id)
		var w: Array = x.get("window", [])
		if w.size() != 2 or float(w[0]) > float(w[1]):
			bad.append("%s: window" % id)
		else:
			if float(w[0]) < float(data.cold_open_s):
				bad.append("%s: in the cold open" % id)
			for b in pilot.get("beats", []):
				if not str(b.id) in data.get("no_insight_beats", []):
					continue
				var a := float(b.t)
				var z := float(pilot.length_s)
				for b2 in pilot.beats:
					if float(b2.t) > a:
						z = minf(z, float(b2.t))
				if float(w[0]) < z and float(w[1]) > a:
					bad.append("%s: window over %s" % [id, b.id])
		var line := str(x.get("line_ru", ""))
		if line == "" or line.length() > 140:
			bad.append("%s: line of %d" % [id, line.length()])
		for word in LocationsCore.words(line):
			if word in ["я", "ты", "мне", "меня", "тебя", "тебе", "мой",
					"моя", "моё"]:
				bad.append("%s: not third person" % id)
		if not beats.has(str(x.get("bridge_to", ""))):
			bad.append("%s: bridges to nothing" % id)
		# TABOO 0.021 item 1 and TABOO 0.023 item 5: an insight explains a
		# law of the world and says how every faith and none reads it.
		if str(x.get("explains", "")) == "":
			bad.append("%s: explains no law of the world" % id)
		if str(x.get("all_faiths", "")) == "":
			bad.append("%s: no reading for every faith" % id)
		var img := str(x.get("image", ""))
		if img != "" and not img.begins_with("res://art/prerender/"):
			bad.append("%s: an image outside the prerenders" % id)
	for f in ["time", "place", "sequence"]:
		if not factors.has(f):
			bad.append("no insight by %s" % f)
	return bad
