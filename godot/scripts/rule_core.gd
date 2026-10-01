## The rule of prayer, ported from public/ludus/ludus-actions.js
## (PRACTICES, normalize, doPractice, practiceTally, keptToday).  The JS
## module is the reference: godot/tests/test_rule.gd replays
## godot/tests/fixtures/rule.json, written from it by
## scripts/godot/make_rule_fixture.js.
##
## Twelve practices, each answering one passion on the Ladder.  kinds:
## "count" adds one per act; "daily" counts once per calendar day;
## "timer" counts only whole sessions actually completed.  The first
## three keep the legacy keys that the gates read (HubCore).  None of
## them ever adds XP or attributes (TABOO 0.35 rule 16): the counters
## are only shown.  A good deed in secret is not even shown as a number,
## because a secret counted in front of the player feeds vainglory
## (Mt 6:3-4).
##
## In the hub the evening watch over thoughts ("guard_thoughts") has its
## own cell.  It is the second way of sobriety beside the corner of
## stillness: TrialCore.sobriety_of counts it, so a watch kept after a
## fall, together with a new talk with the mentor who teaches that
## passion's sign, lifts the fall exactly as in the web.
class_name RuleCore
extends RefCounted

## Same order, ids, kinds, legacy keys and sources as the JS table.  The
## Russian label is the one the web mission panel uses where it has one
## (ludus-missions.js SOBRIETY, MissionCore.PRACTICE_RU); it is the
## practice's name, not a church term on a button (TABOO 0.39 point 3).
const PRACTICES := [
	{"id": "prayer_rope", "kind": "count", "legacy": "prayerCount",
		"ru": "Вервица: один узел", "source": "Ladder, step 28"},
	{"id": "fast", "kind": "daily", "legacy": "fastDays",
		"ru": "Сохранить сегодняшний пост", "source": "Ladder, step 14"},
	{"id": "stillness", "kind": "timer", "minutes": 1,
		"legacy": "meditationHours", "ru": "Безмолвие: одна минута",
		"source": "Ladder, steps 11 and 27"},
	{"id": "prostrations", "kind": "count", "ru": "Поклон",
		"source": "Ladder, step 25"},
	{"id": "vigil", "kind": "timer", "minutes": 10, "ru": "Ночное бдение",
		"source": "Ladder, steps 13 and 20"},
	{"id": "handiwork", "kind": "timer", "minutes": 5, "ru": "Рукоделие",
		"source": "Apophthegmata, Antony the Great 1"},
	{"id": "alms", "kind": "daily", "ru": "Подать милостыню",
		"source": "Ladder, steps 16-17"},
	{"id": "forgive", "kind": "daily", "ru": "Простить обиду",
		"source": "Ladder, steps 8-9"},
	{"id": "thanksgiving", "kind": "daily", "ru": "Благодарить за всё",
		"source": "Ladder, step 7; St John Chrysostom"},
	{"id": "guard_thoughts", "kind": "daily",
		"ru": "Вечерний дозор над помыслами",
		"source": "Ladder, steps 15 and 26"},
	{"id": "obedience", "kind": "daily",
		"ru": "Исполнить послушание наставника", "source": "Ladder, step 4"},
	{"id": "secret_deed", "kind": "daily", "secret": true,
		"ru": "Сделать доброе тайно", "source": "Ladder, step 22; Mt 6:3-4"},
]


static func practice(id) -> Dictionary:
	for p in PRACTICES:
		if p.id == id:
			return p
	return {}


static func _num(v) -> float:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) \
			and float(v) > 0.0:
		return float(v)
	return 0.0


static func _is_day(v) -> bool:
	return typeof(v) == TYPE_STRING \
		and RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$").search(v) \
		!= null


## Anything read from the save file comes back only in known shapes, as
## normalize() in JS: unknown practices, keys and gifts are dropped, so
## a tampered record cannot smuggle in new counters.  (The JS also
## carries the passions record; the hub keeps that one apart, in
## PassionCore.normalize_record.)
static func normalize(raw) -> Dictionary:
	var src: Dictionary = raw if raw is Dictionary else {}
	var met := {}
	var src_met = src.get("met", {})
	if src_met is Dictionary:
		var re := RegEx.create_from_string("^[a-z_]{1,40}$")
		for id in src_met:
			if typeof(id) == TYPE_STRING and re.search(id) != null:
				met[id] = floori(_num(src_met[id]))
	var gifts := {}
	var src_gifts = src.get("gifts", {})
	if src_gifts is Dictionary:
		for g in HubCore.GATES:
			if src_gifts.get(g.id) is bool and src_gifts.get(g.id) == true:
				gifts[g.id] = true
	var practices := {}
	var src_pr = src.get("practices", {})
	if src_pr is Dictionary:
		for p in PRACTICES:
			var item = src_pr.get(p.id)
			if not p.has("legacy") and item is Dictionary:
				var day = item.get("lastDay")
				practices[p.id] = {"count": floori(_num(item.get("count"))),
					"lastDay": day if _is_day(day) else null}
	var lfd = src.get("lastFastDay")
	return {"practices": practices,
		"prayerCount": float(floori(_num(src.get("prayerCount")))),
		"fastDays": float(floori(_num(src.get("fastDays")))),
		"meditationHours": _num(src.get("meditationHours")),
		"lastFastDay": lfd if _is_day(lfd) else null,
		"met": met, "gifts": gifts}


## Stillness counts only whole minutes, rounded to four places as the JS
## does with toFixed(4).
static func add_stillness(actions: Dictionary, minutes) -> Dictionary:
	var n := normalize(actions)
	var whole := floori(_num(minutes))
	n.meditationHours = snappedf(n.meditationHours + whole / 60.0, 0.0001)
	return n


## One act of a practice.  opts.day ("YYYY-MM-DD") is required for daily
## practices and opts.minutes (whole minutes completed) for timers; the
## caller gives both, so no clock is hidden in here.
static func do_practice(actions: Dictionary, id: String,
		opts := {}) -> Dictionary:
	var pr := practice(id)
	if pr.is_empty():
		return normalize(actions)
	match pr.get("legacy", ""):
		"prayerCount":
			var n := normalize(actions)
			n.prayerCount += 1.0
			return n
		"fastDays":
			return HubCore.keep_fast(normalize(actions), opts.get("day"))
		"meditationHours":
			return add_stillness(actions, opts.get("minutes"))
	var n := normalize(actions)
	var item: Dictionary = n.practices.get(id, {"count": 0, "lastDay": null})
	match pr.kind:
		"count":
			item.count += 1
		"daily":
			var day = opts.get("day")
			if not _is_day(day) or item.lastDay == day:
				return n
			item.count += 1
			item.lastDay = day
		"timer":
			# Only a completed session of the practice's length counts.
			if floori(_num(opts.get("minutes"))) < int(pr.minutes):
				return n
			item.count += int(pr.minutes)
	n.practices[id] = item
	return n


## What the rule may show: a number, or nothing for the secret deed.
## text is the JS wording; text_ru is what the headset shows.
static func practice_tally(actions: Dictionary, id: String) -> Dictionary:
	var pr := practice(id)
	if pr.is_empty():
		return {}
	var a := normalize(actions)
	if pr.get("secret", false):
		return {"shown": false, "text": "known to God",
			"text_ru": "знает Бог"}
	var value := 0
	match pr.get("legacy", ""):
		"meditationHours":
			value = floori(a.meditationHours * 60.0 + 1e-6)
		"":
			value = int(a.practices.get(id, {"count": 0}).count)
		_:
			value = int(a[pr.legacy])
	var unit := ""
	var unit_ru := ""
	if pr.kind == "timer":
		unit = " min"
		unit_ru = " мин"
	elif pr.kind == "daily":
		unit = " day" if value == 1 else " days"
		unit_ru = " " + _days_ru(value)
	return {"shown": true, "value": value, "text": "%d%s" % [value, unit],
		"text_ru": "%d%s" % [value, unit_ru]}


static func _days_ru(n: int) -> String:
	if n % 10 == 1 and n % 100 != 11:
		return "день"
	if n % 10 in [2, 3, 4] and not n % 100 in [12, 13, 14]:
		return "дня"
	return "дней"


static func kept_today(actions: Dictionary, id: String, day) -> bool:
	var pr := practice(id)
	if pr.is_empty() or pr.kind != "daily":
		return false
	var a := normalize(actions)
	if pr.get("legacy", "") == "fastDays":
		return a.lastFastDay == day
	return a.practices.get(id, {}).get("lastDay") == day
