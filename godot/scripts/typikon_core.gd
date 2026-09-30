## When the far monastery's bells ring over the path of the witness
## (docs/HLD_WITNESS_SOUND_2026-09-30.md, CLAUDE.md TABOO 0.35 rule 9).
##
## The bells are started by the clock and the Typikon only.  Every cue
## declares {order, service, dayRankCondition, meaning, trigger}; the
## trigger is always "clock": no walk, bow, button, find or gift reaches
## this file, and nothing here knows the player exists.
##
## The day and its rank come from LudusTypikon (scripts/audio/
## typikon.gd), the port of ludus-liturgical-clock.js that
## tests/ludus-audio-parity.test.js keeps equal to the web.  It is a
## computed, read-only calendar: Paschalion by the Julian computus, the
## liturgical day beginning at Vespers (18:00), Great Lent the 48 days
## before Pascha, Bright Week the six days after it.
class_name TypikonCore
extends RefCounted

## Trезвон as ludus-sacred-synth.js trezvon(tr, rng, t0, 3, 2, 0.19):
## three приёма of a затравка, two bars and the удар во вся.
const TREZVON_PRIEMY := 3
const TREZVON_BARS := 2
const TREZVON_BEAT := 0.19
const ZAZVON_FIGURE := [7, 6, 5, 6, 7, 6, 4, 6]
const ZATRAVKA := [7, 6, 7, 5]
## A благовест stroke every five seconds (LudusTypikon.STROKE_EVERY,
## a design choice: kolokol ch. 25 gives no tempo in seconds).
const LITURGY_CALL_MINUTES := 10

const GRIEF := ["great-friday", "great-saturday"]

## The bell cues of the path.  "minute" is when the cue starts (local
## minute of the day); "service_minute" is the moment whose liturgical
## day decides it: the Vespers being called opens the next day.
const CUES := [
	{"id": "liturgy-call", "order": "благовест", "service": "литургия",
		"minute": 530, "service_minute": 540, "trigger": "clock",
		"dayRankCondition": "воскресенье или великий праздник; не в "
			+ "Великую Пятницу, Великую Субботу и не в день Пасхи "
			+ "(пасхальная литургия ночью)",
		"meaning": "Мерные удары большого колокола зовут на литургию: "
			+ "обитель собирается, свидетель слышит зов издали."},
	{"id": "liturgy-trezvon", "order": "трезвон", "service": "литургия",
		"minute": 540, "service_minute": 540, "trigger": "clock",
		"dayRankCondition": "как у благовеста к литургии и если устав "
			+ "дня допускает трезвон; никогда в Великую Пятницу, "
			+ "Великую Субботу и в будни Великого поста",
		"meaning": "Трезвон после благовеста: радость праздника, "
			+ "служба начинается."},
	{"id": "bright-trezvon", "order": "трезвон",
		"service": "Светлая седмица", "minute": 720,
		"service_minute": 720, "trigger": "clock",
		"dayRankCondition": "только день Пасхи и Светлая седмица "
			+ "(kolokol гл. 25: звон от литургии до вечерни)",
		"meaning": "Пасхальный трезвон среди дня: радость, которую "
			+ "Светлая седмица отдаёт всем."},
	{"id": "vespers-call", "order": "благовест", "service": "вечерня",
		"minute": 1070, "service_minute": 1080, "trigger": "clock",
		"dayRankCondition": "всякий день; в будни Великого поста — "
			+ "двенадцать ударов (kolokol гл. 25)",
		"meaning": "Благовест к вечерне: день кончается, новый "
			+ "литургический день начинается с молитвы."},
	{"id": "vigil-trezvon", "order": "трезвон",
		"service": "всенощное бдение", "minute": 1080,
		"service_minute": 1080, "trigger": "clock",
		"dayRankCondition": "канун воскресенья или великого праздника, "
			+ "Светлая седмица; никогда в Великую Пятницу, Великую "
			+ "Субботу и в будни Великого поста",
		"meaning": "Трезвон к бдению: завтра праздник, радость "
			+ "начинается с вечера."},
]


static func _moment(civil: Dictionary, minute: int) -> Dictionary:
	return {"year": civil.year, "month": civil.month, "day": civil.day,
		"hour": minute / 60, "minute": minute % 60, "second": 0}


static func day_key(civil: Dictionary) -> String:
	return "%04d-%02d-%02d" % [civil.year, civil.month, civil.day]


## Why a трезвон may not ring: "" when it may.  lit is the liturgical
## day of the service, civil the civil day of the moment (at noon).
## Both are asked, so the evening of Great Friday and of Great Saturday
## can never ring a трезвон in either reckoning of the day.
static func trezvon_forbidden(lit: Dictionary, civil: Dictionary) -> String:
	if lit.period in GRIEF or civil.period in GRIEF:
		return "Великая Пятница или Суббота: трезвона нет"
	if lit.period == "great-lent" and lit.rank == "daily":
		return "будни Великого поста: трезвона нет"
	if not "трезвон" in LudusTypikon.allowed_orders(lit):
		return "устав дня не допускает трезвон"
	return ""


## Does a cue ring on this civil date?  {ok, reason, lit}.
static func applies(cue: Dictionary, civil: Dictionary) -> Dictionary:
	var lit := LudusTypikon.describe(_moment(civil, cue.service_minute))
	var day := LudusTypikon.describe(_moment(civil, 720))
	var out := {"ok": false, "reason": "", "lit": lit}
	var feast: bool = lit.rank == "great" \
		and not lit.period in GRIEF and lit.period != "pascha"
	match cue.id:
		"liturgy-call":
			out.ok = feast
			out.reason = "праздник" if feast else "не воскресенье"
		"liturgy-trezvon":
			var why := trezvon_forbidden(lit, day)
			out.ok = feast and why == ""
			out.reason = why if why != "" else "праздник"
		"bright-trezvon":
			var why := trezvon_forbidden(lit, day)
			var bright: bool = day.period in ["pascha", "bright-week"]
			out.ok = bright and why == ""
			out.reason = why if why != "" else "Светлая седмица"
		"vespers-call":
			out.ok = "благовест" in LudusTypikon.allowed_orders(lit)
			out.reason = "к вечерне"
		"vigil-trezvon":
			var why := trezvon_forbidden(lit, day)
			var high: bool = lit.rank in ["great", "pascha"] \
				or lit.period in ["pascha", "bright-week"]
			out.ok = high and why == ""
			out.reason = why if why != "" else "канун праздника"
	return out


## The strokes of a cue on a civil date: [[seconds, bell, velocity]].
## Seeded by the cue and the day, never by anything the player does.
static func strokes(cue: Dictionary, civil: Dictionary) -> Array:
	var key := day_key(civil)
	var out := []
	if cue.order == "благовест":
		var times := []
		var r: Callable
		if cue.id == "vespers-call":
			# The same strokes as the shore bell of the dive: the same
			# clock, the same seed (DiveSynth._update_bell_clock).
			times = LudusTypikon.bell_call(_moment(civil,
				cue.minute)).stroke_times
			r = DiveCore.rng("blagovest:" + key)
		else:
			for k in int(LITURGY_CALL_MINUTES * 60
					/ LudusTypikon.STROKE_EVERY):
				times.append(k * LudusTypikon.STROKE_EVERY)
			r = DiveCore.rng("blagovest-liturgy:" + key)
		for at in times:
			out.append([at, 0, 0.9 + r.call() * 0.08])
		return out
	# Трезвон: a faithful port of ludus-sacred-synth.js trezvon(), with
	# its random calls in the same order.
	var r := DiveCore.rng("trezvon:%s:%s" % [cue.id, key])
	var t := 0.0
	var beat := TREZVON_BEAT
	for p in TREZVON_PRIEMY:
		for i in ZATRAVKA.size():
			out.append([t + i * beat, ZATRAVKA[i], 0.75 + r.call() * 0.1])
		t += 4 * beat
		for bar in TREZVON_BARS:
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
	for cue in CUES:
		var a := applies(cue, civil)
		if not a.ok:
			continue
		var s := strokes(cue, civil)
		var end := 0.0
		for st in s:
			end = maxf(end, st[0] + BellSynth.ring_of(st[1]))
		var start: float = cue.minute * 60.0
		plan.append({"cue": cue, "start": start, "end": start + end,
			"strokes": s, "reason": a.reason, "lit": a.lit})
	return plan
