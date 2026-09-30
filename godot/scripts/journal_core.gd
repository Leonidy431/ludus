## The player's journal of the way, ported from the web game.
##
## Reference: public/ludus/ludus-journal.js (toMarkdown) with the rule of
## prayer of public/ludus/ludus-actions.js (PRACTICES, normalize,
## practiceTally).  godot/tests/test_journal.gd replays
## godot/tests/journal_fixture.json, written from the JS by
## scripts/godot/make_journal_fixture.js, so the page the headset
## exports is the page the web game exports, letter for letter.
##
## The journal is the player's own record: the seven attributes of
## FORM, the rule of prayer as counted, the open steps of the ladder and
## the passions met on the road.  What it leaves out, on purpose, as the
## web page does:
##   - the good deed in secret: its count is "known to God" (Mt 6:3-4);
##   - the preparation for confession: it is never kept anywhere, so it
##     cannot be written here (TABOO 0.26);
##   - any word that turns the record into a measure of a soul (TABOO
##     0.39): the closing line says so.
## The Order's journals are never destroyed (TABOO 0.25 point 5): an
## export never overwrites an earlier page (export_path).
## Pure: no file, no clock; the caller passes the saves and the date.
class_name JournalCore
extends RefCounted

const ATTRIBUTES := ["wisdom", "faith", "dexterity", "constitution",
	"charisma", "cunning", "erudition"]
const RU_ATTR := {"wisdom": "Мудрость", "faith": "Вера",
	"dexterity": "Ловкость", "constitution": "Стойкость",
	"charisma": "Обаяние", "cunning": "Хитрость", "erudition": "Книжность"}
## The twelve practices of the rule, in the order of ludus-actions.js.
## label is the web label (the exported page); ru is the book's word.
## kind: count adds one per act, daily once per day, timer in minutes.
const PRACTICES := [
	{"id": "prayer_rope", "label": "Prayer rope: one knot", "kind": "count",
		"legacy": "prayerCount", "ru": "Вервица: узлы"},
	{"id": "fast", "label": "Keep today's fast", "kind": "daily",
		"legacy": "fastDays", "ru": "Пост"},
	{"id": "stillness", "label": "Stillness", "kind": "timer",
		"legacy": "meditationHours", "ru": "Безмолвие"},
	{"id": "prostrations", "label": "Prostration", "kind": "count",
		"ru": "Поклоны"},
	{"id": "vigil", "label": "Night vigil", "kind": "timer",
		"ru": "Ночное бдение"},
	{"id": "handiwork", "label": "Handiwork", "kind": "timer",
		"ru": "Рукоделие"},
	{"id": "alms", "label": "Give alms", "kind": "daily",
		"ru": "Милостыня"},
	{"id": "forgive", "label": "Forgive an offence", "kind": "daily",
		"ru": "Простить обиду"},
	{"id": "thanksgiving", "label": "Glory to God for all things",
		"kind": "daily", "ru": "«Слава Богу за всё»"},
	{"id": "guard_thoughts", "label": "Evening watch over thoughts",
		"kind": "daily", "ru": "Вечерний дозор над помыслами"},
	{"id": "obedience", "label": "Fulfil the mentor's obedience",
		"kind": "daily", "ru": "Послушание наставника"},
	{"id": "secret_deed", "label": "A good deed in secret", "kind": "daily",
		"secret": true, "ru": "Доброе тайно"},
]
## The web labels of the six gates (ludus-actions.js GATES); the book
## uses HubCore.GATES[i].ru.
const GATE_LABELS := ["Foundational", "Liturgical", "Ascetic",
	"Contemplative", "Mystical", "Apophatic"]
const CLOSING := "One good deed is kept out of this page on purpose: it is known to God. This page counts steps on a road; it does not measure a soul."
const CLOSING_RU := "Одно доброе дело нарочно не записано: оно ведомо Богу. Журнал считает шаги дороги, а не меряет душу."


static func _num(v) -> float:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) \
			and float(v) > 0.0:
		return float(v)
	return 0.0


static func _is_true(v) -> bool:
	return typeof(v) == TYPE_BOOL and v


## Number(v) || 0 of JavaScript: any finite number, else 0.
static func _form_num(v) -> float:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)):
		return float(v)
	return 0.0


## A number as JavaScript writes it: 5, not 5.0.
static func _js(v: float) -> String:
	if v == floorf(v) and absf(v) < 1e15:
		return "%d" % int(v)
	return str(v)


static func _day(v) -> Variant:
	var re := RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$")
	if typeof(v) == TYPE_STRING and re.search(v) != null:
		return v
	return null


## normalize() of ludus-actions.js: anything read from a save comes back
## only in known shapes, so a tampered file cannot add counters.
static func normalize(raw) -> Dictionary:
	var src: Dictionary = raw if raw is Dictionary else {}
	var met := {}
	var re_id := RegEx.create_from_string("^[a-z_]{1,40}$")
	var src_met = src.get("met", {})
	if src_met is Dictionary:
		for id in src_met:
			if re_id.search(str(id)) != null:
				met[str(id)] = floori(_num(src_met[id]))
	var gifts := {}
	var src_gifts = src.get("gifts", {})
	for gate in HubCore.GATES:
		if src_gifts is Dictionary and _is_true(src_gifts.get(gate.id)):
			gifts[gate.id] = true
	var practices := {}
	var src_pr = src.get("practices", {})
	for pr in PRACTICES:
		var item = src_pr.get(pr.id) if src_pr is Dictionary else null
		if not pr.has("legacy") and item is Dictionary:
			practices[pr.id] = {"count": floori(_num(item.get("count"))),
				"lastDay": _day(item.get("lastDay"))}
	return {"practices": practices,
		"prayerCount": float(floori(_num(src.get("prayerCount")))),
		"fastDays": float(floori(_num(src.get("fastDays")))),
		"meditationHours": _num(src.get("meditationHours")),
		"lastFastDay": _day(src.get("lastFastDay")),
		"met": met, "gifts": gifts}


## practiceTally() of ludus-actions.js: a number, or nothing at all for
## the secret deed.  unit_ru gives the book's Russian units.
static func practice_tally(actions: Dictionary, id: String,
		ru := false) -> Dictionary:
	var pr := {}
	for p in PRACTICES:
		if p.id == id:
			pr = p
	if pr.is_empty():
		return {}
	var a := normalize(actions)
	if pr.get("secret", false):
		return {"shown": false,
			"text": "ведомо Богу" if ru else "known to God"}
	var value := 0
	if pr.get("legacy") == "meditationHours":
		value = floori(a.meditationHours * 60.0 + 1e-6)
	elif pr.has("legacy"):
		value = int(a[pr.legacy])
	else:
		value = int(a.practices.get(id, {"count": 0}).count)
	var unit := ""
	if pr.kind == "timer":
		unit = " мин" if ru else " min"
	elif pr.kind == "daily":
		if ru:
			unit = " " + _days_ru(value)
		else:
			unit = " day" if value == 1 else " days"
	return {"shown": true, "value": value, "text": "%d%s" % [value, unit]}


static func _days_ru(n: int) -> String:
	var d := n % 100
	if d >= 11 and d <= 14:
		return "дней"
	match n % 10:
		1:
			return "день"
		2, 3, 4:
			return "дня"
	return "дней"


## The passions met on the road, in Evagrius' order of passions.json.
static func _met(passion_data: Dictionary, record) -> Array:
	var out := []
	if not record is Dictionary:
		return out
	for id in passion_data.get("order", []):
		if record.get(id) is Dictionary:
			var p := {"id": id, "name": id, "name_ru": id}
			for x in passion_data.passions:
				if x.id == id:
					p = x
			out.append({"p": p, "r": record[id]})
	return out


## Under the water (the headset only: the web game has no dive yet).
## dive is the content of user://dive.json: {bag, done}.
static func dive_summary(dive) -> Dictionary:
	if not dive is Dictionary:
		return {}
	var bag = dive.get("bag", {})
	var done = dive.get("done", [])
	if not bag is Dictionary:
		bag = {}
	if not done is Array:
		done = []
	var tasks := []
	for task in DiveCore.TASKS:
		if task.id in done:
			tasks.append(task)
	var count := func(key: String) -> int:
		var v = bag.get(key, [])
		return (v as Array).size() if v is Array else 0
	return {"tasks": tasks, "total": DiveCore.TASKS.size(),
		"handed_over": count.call("handed_over"),
		"released": count.call("released"), "atlas": count.call("atlas")}


## toMarkdown() of ludus-journal.js.  state: {form, actions, passions,
## passion_data, date: "YYYY-MM-DD", dive (optional, headset only)}.
static func to_markdown(state: Dictionary) -> String:
	var form: Dictionary = state.get("form", {})
	var actions := normalize(state.get("actions", {}))
	var lines := ["# The way: a page from my journal", "",
		"Written on %s." % state.get("date", ""), "", "## Form", ""]
	for a in ATTRIBUTES:
		lines.append("- %s: %s" % [a.capitalize(),
			_js(_form_num(form.get(a)))])
	lines += ["", "## Rule of prayer", ""]
	for pr in PRACTICES:
		lines.append("- %s — %s" % [pr.label,
			practice_tally(actions, pr.id).text])
	lines += ["", "## Steps of the ladder", ""]
	var ladder := HubCore.evaluate_ladder(form, actions)
	var any_open := false
	for i in ladder.size():
		if ladder[i].open:
			lines.append("- " + GATE_LABELS[i])
			any_open = true
	if not any_open:
		lines.append("- None yet: the first step is still ahead.")
	lines += ["", "## On the road", ""]
	var met := _met(state.get("passion_data", {}), state.get("passions"))
	if met.is_empty():
		lines.append("- No thought met on the road yet.")
	for m in met:
		var r: Dictionary = m.r
		var how := "met, and it will come back"
		if _num(r.get("overcome")) > 0.0:
			how = "passed; answered by %s" % m.p.get("virtue",
				"its virtue")
		var sign := ", named at its first sign" \
			if _is_true(r.get("discerned")) else ""
		var n := _js(_num(r.get("meetings")))
		lines.append("- %s: %s%s (%s meeting%s)." % [m.p.get("name", m.p.id),
			how, sign, n, "" if n == "1" else "s"])
	var dv := dive_summary(state.get("dive"))
	if not dv.is_empty():
		lines += ["", "## Under the water", "",
			"- Tasks of the dive: %d of %d" % [dv.tasks.size(), dv.total],
			"- Finds handed to the scribe: %d" % dv.handed_over,
			"- Things of the knight handed to the scribe: %d" % dv.atlas,
			"- Let go back into the water: %d" % dv.released]
	lines += ["", "---", "", CLOSING, ""]
	return "\n".join(lines)


## The birch-bark book in the scriptorium: the same record in Russian,
## one page per part.  The last page is where the player may ask for the
## Markdown page to be written out (JournalBook).
static func pages_ru(state: Dictionary) -> Array:
	var form: Dictionary = state.get("form", {})
	var actions := normalize(state.get("actions", {}))
	var pages := []
	var p := ["ЖУРНАЛ ПУТИ", "Писано %s." % state.get("date", ""), "",
		"Форма:"]
	for a in ATTRIBUTES:
		p.append("  %s — %s" % [RU_ATTR[a], _js(_form_num(form.get(a)))])
	pages.append("\n".join(p))
	p = ["ПРАВИЛО", ""]
	for pr in PRACTICES:
		p.append("%s — %s" % [pr.ru, practice_tally(actions, pr.id,
			true).text])
	pages.append("\n".join(p))
	p = ["СТУПЕНИ ЛЕСТНИЦЫ", ""]
	var ladder := HubCore.evaluate_ladder(form, actions)
	for i in ladder.size():
		if ladder[i].open:
			p.append("%d. %s" % [i + 1, HubCore.GATES[i].ru])
	if p.size() == 2:
		p.append("Пока ни одной: первая ступень впереди.")
	pages.append("\n".join(p))
	p = ["НА ДОРОГЕ", ""]
	var met := _met(state.get("passion_data", {}), state.get("passions"))
	if met.is_empty():
		p.append("Помыслов на дороге ещё не встречал.")
	for m in met:
		var r: Dictionary = m.r
		var how := "встречен; он вернётся"
		if _num(r.get("overcome")) > 0.0:
			how = "прошёл; ответ — %s" % str(m.p.get("virtue_ru",
				"его добродетель")).to_lower()
		if _is_true(r.get("discerned")):
			how += ", узнан по первому признаку"
		p.append("%s: %s (встреч: %s)." % [m.p.get("name_ru", m.p.id), how,
			_js(_num(r.get("meetings")))])
	pages.append("\n".join(p))
	var dv := dive_summary(state.get("dive"))
	p = ["ПОД ВОДОЙ", ""]
	if dv.is_empty():
		p.append("Погружений ещё не было.")
	else:
		p.append("Задачи погружения: %d из %d." % [dv.tasks.size(),
			dv.total])
		for task in dv.tasks:
			p.append("  • " + str(task.ru).get_slice(":", 0))
		p += ["Находки писцу: %d." % dv.handed_over,
			"Вещи рыцаря писцу: %d." % dv.atlas,
			"Отпущено в воду: %d." % dv.released]
	pages.append("\n".join(p))
	return pages


## Where an exported page goes: user://journal-<date>.md, or -2, -3 ...
## when that name is taken, so an earlier page is never overwritten.
## exists: Callable(path) -> bool.
static func export_path(date: String, exists: Callable) -> String:
	var base := "user://journal-%s" % date
	var path := base + ".md"
	var n := 2
	while exists.call(path):
		path = "%s-%d.md" % [base, n]
		n += 1
	return path
