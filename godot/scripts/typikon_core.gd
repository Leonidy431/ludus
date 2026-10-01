## When the far monastery's bells ring over the path of the witness
## (docs/HLD_BELL_RULES_TYPIKON_2026-09-30.md, CLAUDE.md TABOO 0.2
## item 5, TABOO 0.35 rules 9 and 10).
##
## The cues are not written here: they are the "cues" of the one bell
## table, godot/data/bell-rules.json (the same file as the web's
## public/ludus/data/bell-rules.json).  Every cue there names the rule
## it keeps, and every rule its source: the Typikon, Rozanov's
## explanation of it, or the bell book of the operator, with a quote.
## Clock times are the monastery's local custom, a design choice the
## table labels as such.
##
## The bells are started by the clock and the Typikon only.  Every cue
## declares {order, service, dayRankCondition, meaning}, and this file
## adds trigger "clock": no walk, bow, button, find or gift reaches
## this file, and nothing here knows the player exists.
##
## The day and its rank come from LudusTypikon (scripts/audio/
## typikon.gd), the port of ludus-liturgical-clock.js: Paschalion by
## the Julian computus, the liturgical day beginning at Vespers
## (18:00), Great Lent the 48 days before Pascha, Bright Week the six
## days after it.
class_name TypikonCore
extends RefCounted

## The figure of the трезвон, as ludus-sacred-synth.js trezvon(): a
## затравка on the small bells, then the upper figure of the зазвонные.
const ZAZVON_FIGURE := [7, 6, 5, 6, 7, 6, 4, 6]
const ZATRAVKA := [7, 6, 7, 5]

const GRIEF := ["great-friday", "great-saturday"]

static var _cues: Array = []


## The cues of the path: the table's cues, each started by the clock.
static func cues() -> Array:
	if _cues.is_empty():
		for c in LudusTypikon.rules().cues:
			var d: Dictionary = c.duplicate(true)
			d.trigger = "clock"
			_cues.append(d)
	return _cues


## A cue of the path by its id, or {}.
static func cue(id: String) -> Dictionary:
	for c in cues():
		if c.id == id:
			return c
	return {}


static func _moment(civil: Dictionary, minute: int) -> Dictionary:
	return {"year": civil.year, "month": civil.month, "day": civil.day,
		"hour": minute / 60, "minute": minute % 60, "second": 0}


static func day_key(civil: Dictionary) -> String:
	return "%04d-%02d-%02d" % [civil.year, civil.month, civil.day]


## Why a трезвон may not ring: "" when it may.  lit is the liturgical
## day of the service, civil the civil day of the moment (at noon).
## Both are asked, so the evening of Great Friday and of Great Saturday
## can never ring a трезвон in either reckoning of the day.  This guard
## is code, not data: it is the chorus's rule 9, and the table cannot
## switch it off.
static func trezvon_forbidden(lit: Dictionary, civil: Dictionary) -> String:
	if lit.period in GRIEF or civil.period in GRIEF:
		return "Великая Пятница или Суббота: трезвона нет"
	if lit.period == "great-lent" and lit.rank == "daily":
		return "будни Великого поста: трезвона нет"
	if not "трезвон" in LudusTypikon.allowed_orders(lit):
		return "устав дня не допускает трезвон"
	return ""


static func _any(names: Array, classes: Array) -> bool:
	for n in names:
		if n in classes:
			return true
	return false


## Does a cue ring on this civil date?  {ok, reason, lit}.
## "when" of the table: the liturgical day of the service must be in
## "lit", the civil day (at noon) in "civil", and neither in "not".
## Then the order must be one the sources name for the liturgical day,
## and a трезвон must pass the guard.
static func applies(c: Dictionary, civil: Dictionary) -> Dictionary:
	var lit := LudusTypikon.describe(_moment(civil, int(c.serviceMinute)))
	var day := LudusTypikon.describe(_moment(civil, 720))
	var out := {"ok": false, "reason": "", "lit": lit}
	var lc := LudusTypikon.day_classes(lit)
	var cc := LudusTypikon.day_classes(day)
	var when: Dictionary = c.when
	if when.has("lit") and not _any(when["lit"], lc):
		out.reason = "не тот день службы %s" % [lc]
		return out
	if when.has("civil") and not _any(when["civil"], cc):
		out.reason = "не тот день %s" % [cc]
		return out
	if when.has("not") and (_any(when["not"], lc)
			or _any(when["not"], cc)):
		out.reason = "исключён днём %s / %s" % [lc, cc]
		return out
	if not c.order in LudusTypikon.allowed_orders(lit):
		out.reason = "устав дня не называет %s" % c.order
		return out
	if c.order == "трезвон":
		var why := trezvon_forbidden(lit, day)
		if why != "":
			out.reason = why
			return out
	out.ok = true
	out.reason = "%s (%s)" % [c.rule, lit.period]
	return out


## The strokes of a cue on a civil date: [[seconds, bell, velocity]].
## Seeded by the cue and the day, never by anything the player does.
static func strokes(c: Dictionary, civil: Dictionary) -> Array:
	var key := day_key(civil)
	var pat: Dictionary = c.pattern
	var out := []
	match String(pat.kind):
		"vespers-call":
			# The same strokes as the shore bell of the dive: the same
			# clock, the same seed (DiveSynth._update_bell_clock).
			var times: Array = LudusTypikon.bell_call(_moment(civil,
				int(c.minute))).stroke_times
			var r := DiveCore.rng("blagovest:" + key)
			for at in times:
				out.append([at, int(pat.bell), 0.9 + r.call() * 0.08])
		"blagovest", "counted":
			var n := int(pat.count) if pat.kind == "counted" \
				else int(float(pat.minutes) * 60.0 / float(pat.every))
			var r := DiveCore.rng("blagovest:%s:%s" % [c.id, key])
			for k in n:
				out.append([k * float(pat.every), int(pat.bell),
					0.9 + r.call() * 0.08])
		"dvoi":
			# Звон в двои, as ludus-sacred-synth.js zvonVDvoi(): the
			# постовой and the next bell in size, in turn.
			var n := int(float(pat.minutes) * 60.0 / float(pat.every))
			for k in n:
				out.append([k * float(pat.every), 1 + k % 2, 0.7])
		"trezvon":
			out = _trezvon(c, key, int(pat.priemy), int(pat.bars),
				float(pat.beat))
	return out


## Трезвон: a faithful port of ludus-sacred-synth.js trezvon(), with
## its random calls in the same order.
static func _trezvon(c: Dictionary, key: String, priemy: int, bars: int,
		beat: float) -> Array:
	var out := []
	var r := DiveCore.rng("trezvon:%s:%s" % [c.id, key])
	var t := 0.0
	for p in priemy:
		for i in ZATRAVKA.size():
			out.append([t + i * beat, ZATRAVKA[i], 0.75 + r.call() * 0.1])
		t += 4 * beat
		for bar in bars:
			for s in 8:
				var at := t + s * beat
				if s == 0:
					out.append([at, 0, 0.85])
				if s % 2 == 0:
					out.append([at, 1 if s % 4 == 0 else 2,
						0.7 + r.call() * 0.1])
				if s == 4:
					out.append([at, 3, 0.65])
				out.append([at, ZAZVON_FIGURE[s], 0.6 + r.call() * 0.15])
			t += 8 * beat
		# Удар во вся: all bells at once, the end of a приём.
		for b in BellSynth.ENSEMBLE.size():
			out.append([t + b * 0.004, b, 0.95 * (0.8 if b == 0 else 0.7)])
		t += 8 * beat
	return out


## The cues that ring on a civil date, each with its strokes and its
## span in seconds of the day: [{cue, start, end, strokes, reason}].
static func day_plan(civil: Dictionary) -> Array:
	var plan := []
	for c in cues():
		var a := applies(c, civil)
		if not a.ok:
			continue
		var s := strokes(c, civil)
		var end := 0.0
		for st in s:
			end = maxf(end, st[0] + BellSynth.ring_of(st[1]))
		var start: float = float(c.minute) * 60.0
		plan.append({"cue": c, "start": start, "end": start + end,
			"strokes": s, "reason": a.reason, "lit": a.lit})
	return plan
