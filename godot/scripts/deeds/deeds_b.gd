## Group b of the small acts at the hearts of places (PlaceDeeds; the
## contract is written at the top of place_deeds.gd): the water group.
## share-water (dam), carry-archive-up (flooded-lower), test-ice
## (ice-bay), take-core (silt-core), read-waterline (terrace-regression).
##
## Four acts are a strict order of steps, kept by one engine below: the
## buttons stay the same all the way, so the player must tell which step
## is next.  A step taken too early, or a step that is a mistake, answers
## in the craft language of the place (TABOO 0.39) and leaves the act
## open: it teaches and never punishes.  share-water alone is hand-made,
## because the sides of the dam may be served in either order.  Nothing
## here waits, so tick() returns the state as it was.  No chance, no
## FORM, no score: the act is done or it is not.
##
## Constitution: ФОРМА (the place, its measure and its things) →
## ДЕЙСТВИЕ (the right order, found by the hands) → ЦЕЛЬ (the lesson
## of the place: share by measure, carry what cannot be rewritten,
## probe before stepping, take the silt untouched, trust the old marks).
extends RefCounted

const SHARE := "share-water"
const SIDE_RU := {"upper": "верхний", "lower": "нижний"}
## The numbers of the lake two acts read (blind spot 14 of docs/
## BLINDSPOTS_CODE_BREAKTHROUGH_2026-10-01.md): they come from the data
## and the dive's own rules, not from the text, so the silt the player
## cores here is the silt plain the dive lays on its slope, at its depth
## and its water's warmth, and the old shore under the terrace is the
## drowned terrace of the lake's registry.
const LAKE := "res://data/lake-objects-99.json"
## The silt plain of the silt-core place (one of its slots).
const SILT := "silt.slope.0"
## The drowned shore terrace: an old shoreline under the water.
const OLD_SHORE := "terrace.shelf.2"

static var _facts := {}

## For a sequence act: "intro" is the panel text; each button holds
## either "at" (the step where it is right, "ok" the answer when it is,
## "early" the answer when it comes too soon) or "wrong" (a mistake).
## "first" marks the one tempting mistake that stands at the top.
const ACTS := {
	"carry-archive-up": {
		"intro": ["Вода поднимается по нижнему двору.",
			"Фонари в руках, лестница наверх узка.",
			"Что вынесем первым?"],
		"buttons": [
			{"id": "sack", "text": "Подхватить мешок с зерном", "at": 4,
				"ok": "Зерно поднято последним. Люди сыты, а записи целы.",
				"early": "Зерно купят и в долине, а книгу не купишь."
					+ " Сначала то, что не написать заново."},
			{"id": "chronicle", "text": "Взять летопись уровней воды",
				"at": 3,
				"ok": "Единственный счёт воды наверху. Эти строки не"
					+ " восстановить.",
				"early": "Не торопись с тем, что можно списать."
					+ " Порядок выноса решает исход."},
			{"id": "look", "text": "Окинуть взглядом нижний ярус",
				"at": 0,
				"ok": "Вода у третьей ступени. Время есть, если не"
					+ " метаться.",
				"early": "Смотрят прежде, чем нести."},
			{"id": "all", "first": true, "text": "Позвать всех и хватать что попало",
				"wrong": "Все схватили кто что: дорогое осталось"
					+ " внизу. Порядок дороже спешки."},
			{"id": "case", "text": "Вынести запечатанный футляр с грамотами",
				"at": 2,
				"ok": "Грамоты под стеной сухие. Печать цела.",
				"early": "Грамоты потом. Сперва то, у чего нет"
					+ " второго списка."},
			{"id": "chest", "text": "Поднять ларь с книгами", "at": 1,
				"ok": "Книги наверху. Эти листы не писать заново.",
				"early": "Сперва осмотрись: сколько у тебя ступеней?"},
		],
	},
	"test-ice": {
		"intro": ["Залив мелкий, лёд тонок у берега.",
			"Напрямик короче вдвое.",
			"Караван ждёт на берегу."],
		"buttons": [
			{"id": "step", "text": "Ступить на лёд", "at": 4,
				"ok": "Лёд держит там, где посох ответил. Быстрый"
					+ " путь не всегда путь: путь тот, что промерен.",
				"early": "Нога не посох: что под ней, не знаешь."
					+ " Проверь прежде шага."},
			{"id": "camel", "text": "Пустить верблюда вперёд",
				"wrong": "Верблюд тяжёл, лёд тонок: так теряют"
					+ " и зверя, и груз."},
			{"id": "probe_ahead", "text": "Простучать лёд впереди посохом",
				"at": 3,
				"ok": "Глухой, крепкий звук. Дальше можно.",
				"early": "Лёд впереди не слышен, пока не постучал."
					+ " Сначала страховка."},
			{"id": "tie_rope", "text": "Обвязаться верёвкой с берега",
				"at": 2,
				"ok": "Верёвка с берега держит. Конец у каравана.",
				"early": "Верёвку вяжут, когда знаешь, как лёд"
					+ " отвечает у кромки."},
			{"id": "shortcut", "first": true, "text": "Идти напрямик, пока светло",
				"wrong": "Светло, да не твёрдо. Быстрый путь не всегда"
					+ " путь."},
			{"id": "probe_edge", "text": "Простучать лёд у кромки", "at": 1,
				"ok": "У берега лёд звонкий. Это ещё не весь залив.",
				"early": "Сперва посмотри, какой он, потом стучи."},
			{"id": "listen", "text": "Посмотреть на цвет и трещины",
				"at": 0,
				"ok": "Белый лёд хрупок, тёмный крепче. Здесь пятна.",
				"early": "Глаз не зря стоит первым."},
		],
	},
	"take-core": {
		"intro": ["Ил лежит слоями, как страницы: внизу старше.",
			"Прибор: глубина {depth} м, вода {temp} °C,"
				+ " слой скачка на {thermo} м."],
		"buttons": [
			{"id": "basket", "text": "Уложить керн в корзину для проб",
				"at": 4,
				"ok": "Один керн, подписанный рукой, в корзине. Память"
					+ " воды это ил: слои, а не колдовство.",
				"early": "Корзина после подписи: безымянный керн"
					+ " в ней никто не узнает."},
			{"id": "scoop", "first": true, "text": "Загрести ил ковшом",
				"wrong": "Ковш перемешал слои: страницы склеены."
					+ " Керн берут трубкой, отвесно."},
			{"id": "label", "text": "Подписать: место, глубина, день",
				"at": 3,
				"ok": "Подпись выведена: {depth} м, {temp} °C. Без неё"
					+ " керн просто грязь.",
				"early": "Подписывать нечего: керна ещё нет в руках."},
			{"id": "ask", "text": "Спросить у воды, что она помнит",
				"wrong": "Вода молчит, слои помнят. Читают ил,"
					+ " а не воду."},
			{"id": "lift", "text": "Вынуть трубку, не встряхивая", "at": 2,
				"ok": "Столбик ила вышел целым: слои на местах.",
				"early": "Нечего вынимать: трубка ещё не в иле."},
			{"id": "tube", "text": "Опустить трубку отвесно", "at": 1,
				"ok": "Трубка вошла ровно: дно на {depth} м,"
					+ " {side} слоя скачка.",
				"early": "Сперва выбери место, где ил не тронут."},
			{"id": "flat", "text": "Выбрать ровное место нетронутого ила",
				"at": 0,
				"ok": "Ровно, без следов. Здесь слои лежат как лежали.",
				"early": "Место выбирают раньше трубки."},
			{"id": "spare", "text": "Взять ещё пару кернов про запас",
				"wrong": "Один керн, подписанный рукой, дороже"
					+ " десяти безымянных."},
		],
	},
	"read-waterline": {
		"intro": ["Вода ушла и оставила террасу.",
			"На склоне старые метки: докуда она приходила.",
			"Под водой лежит прежний берег, на {lo}–{hi} м."],
		"buttons": [
			{"id": "cord", "text": "Натянуть шнур между кольями", "at": 4,
				"ok": "Шнур лёг выше всех меток. Надёжная земля"
					+ " отмечена: наблюдение, а не догадка.",
				"early": "Шнур между чем? Колья ещё не вбиты."},
			{"id": "today", "first": true, "text": "Вбить колья по сегодняшней кромке",
				"wrong": "Сегодня вода ушла, метки помнят, докуда"
					+ " приходила. Не строят там, куда вернётся вода."},
			{"id": "stake", "text": "Вбить колья выше самой высокой метки",
				"at": 3,
				"ok": "Колья стоят выше старой воды.",
				"early": "Выше чего вбивать? Сперва сверь метки"
					+ " с рейкой."},
			{"id": "compare", "text": "Сверить старые метки с рейкой",
				"at": 2,
				"ok": "Самая высокая метка на две ладони выше нынешней"
					+ " воды.",
				"early": "Сверять не с чем: метки или рейку ещё не"
					+ " читал."},
			{"id": "marks", "text": "Найти старые метки на склоне", "at": 1,
				"ok": "Три полосы ила на камне. Вода то уходила"
					+ " на {lo}–{hi} м ниже, то приходила.",
				"early": "Сперва прочти, где вода стоит сейчас."},
			{"id": "gauge", "text": "Прочесть рейку у кромки воды", "at": 0,
				"ok": "Рейка показала нынешнюю воду.",
				"early": "С рейки начинают."},
		],
	},
}


## The lake numbers by name, for "{name}" in the texts of ACTS:
## depth (m, whole) and temp (°C at that depth, one decimal, with a
## comma) of the silt plain where DiveCore.place_objects lays it; side
## ("выше" or "ниже") of the thermocline; thermo (m); lo and hi (m) of
## the drowned shore's band.  A name the data lacks stays in braces, and
## the group test fails on it.
static func facts() -> Dictionary:
	if not _facts.is_empty():
		return _facts
	var lake := {}
	var f := FileAccess.open(LAKE, FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for o in d.get("objects", []):
				lake[str(o.id)] = o
	var out := {"thermo": int(DiveCore.THERMOCLINE_M)}
	if lake.has(SILT):
		var placed: Dictionary = DiveCore.place_objects([lake[SILT]])[0]
		var depth := int(round(float(placed.depth)))
		out["depth"] = depth
		out["temp"] = ("%.1f" % DiveCore.temperature(depth)).replace(
			".", ",")
		out["side"] = "выше" if depth < DiveCore.THERMOCLINE_M else "ниже"
	if lake.has(OLD_SHORE):
		out["lo"] = int(lake[OLD_SHORE].depth[0])
		out["hi"] = int(lake[OLD_SHORE].depth[1])
	_facts = out
	return out


## A text of ACTS with the lake's numbers put in.
static func say(text: String) -> String:
	return text.format(facts())


static func ids() -> Array:
	return [SHARE, "carry-archive-up", "test-ice", "take-core",
		"read-waterline"]


static func start(id: String) -> Dictionary:
	if id == SHARE:
		return {"done": false, "reply": "", "measured": false,
			"open": "", "served": []}
	return {"done": false, "reply": "", "step": 0}


static func _steps(id: String) -> int:
	var n := 0
	for b in ACTS[id].buttons:
		if b.has("at"):
			n += 1
	return n


static func lines(id: String, s: Dictionary) -> Array:
	if id == SHARE:
		return _share_lines(s)
	# The steps already done are not listed again: their buttons stay
	# on the panel, closed, with "Это уже сделано." beside them.  A log
	# of the same words above them made the panel taller than its bark
	# (tools/measure_panel_text.gd: 25 lines on a bark of 19).
	var out: Array = []
	for line in ACTS[id].intro:
		out.append(say(line))
	return out


static func options(id: String, s: Dictionary) -> Array:
	if id == SHARE:
		return _share_options(s)
	var out: Array = []
	var step: int = s.get("step", 0)
	# The tempting mistake first, then the steps in the order of the
	# work, then the other mistakes.  The shared heart test presses the
	# first open button that changes the panel, so one mistake at most
	# may stand ahead of the next step; the steps are told apart by
	# what each says, not by where it stands.
	var steps: Array = []
	var lure: Array = []
	var rest: Array = []
	for b in ACTS[id].buttons:
		if b.has("at"):
			steps.append(b)
		elif b.get("first", false):
			lure.append(b)
		else:
			rest.append(b)
	steps.sort_custom(func(a, b): return a.at < b.at)
	for b in lure + steps + rest:
		var o := {"id": b.id, "text": b.text, "disabled": false,
			"reason": ""}
		if b.has("at") and b.at < step:
			o.disabled = true
			o.reason = "Это уже сделано."
		out.append(o)
	return out


static func choose(id: String, s: Dictionary, c: String) -> Dictionary:
	if id == SHARE:
		return _share_choose(s, c)
	for b in ACTS[id].buttons:
		if b.id != c:
			continue
		if b.has("wrong"):
			s.reply = say(b.wrong)
		elif b.at == s.step:
			s.step += 1
			s.reply = say(b.ok)
			if s.step >= _steps(id):
				s.done = true
		elif b.at < s.step:
			s.reply = "Это уже сделано."
		else:
			s.reply = say(b.early)
		return s
	return s


## No act of this group asks to wait still.
static func tick(_id: String, s: Dictionary, _dt: float,
		_still: bool) -> Dictionary:
	return s


# -- share-water ---------------------------------------------------------
# The sluice serves two channels in turn.  Either may come first; the
# water is measured before it is let go, and the sluice shut between.

static func _share_lines(s: Dictionary) -> Array:
	var out: Array = ["Одна заслонка, два русла: верхнее и нижнее.",
		"Воды в обоих мало, а ждут оба."]
	# The measuring is not listed: its button stays, closed, with "Это
	# уже сделано." beside it (the panel must fit its bark).
	for side in s.served:
		out.append("Сделано: %s арык напоен." % SIDE_RU[side])
	if s.open != "":
		out.append("Заслонка поднята в %s арык." % SIDE_RU[s.open])
	return out


static func _share_options(s: Dictionary) -> Array:
	var out: Array = []
	var shut_off: bool = s.open == ""
	out.append({"id": "measure", "text": "Смерить воду в обоих руслах",
		"disabled": s.measured, "reason": "Это уже сделано."})
	out.append({"id": "open_upper", "text": "Открыть заслонку верхнему",
		"disabled": not shut_off or "upper" in s.served,
		"reason": "Верхнему уже дано." if "upper" in s.served
			else "Заслонка уже поднята."})
	out.append({"id": "open_lower", "text": "Открыть заслонку нижнему",
		"disabled": not shut_off or "lower" in s.served,
		"reason": "Нижнему уже дано." if "lower" in s.served
			else "Заслонка уже поднята."})
	out.append({"id": "open_wide", "text": "Поднять заслонку до отказа",
		"disabled": false, "reason": ""})
	out.append({"id": "shut", "text": "Закрыть заслонку",
		"disabled": shut_off, "reason": "Заслонка и так закрыта."})
	return out


static func _share_choose(s: Dictionary, c: String) -> Dictionary:
	match c:
		"measure":
			s.measured = true
			s.reply = "Мерка одна на оба русла: по рейке, не на глаз."
		"open_upper", "open_lower":
			var side := c.trim_prefix("open_")
			if not s.measured:
				s.reply = "На глаз делят так, что кого-то обделяют."\
					+ " Сначала смерь воду."
			elif s.open != "":
				s.reply = "Заслонка уже поднята: закрой её сперва."
			elif side in s.served:
				s.reply = "Этому руслу дано. Теперь очередь другого."
			else:
				s.open = side
				s.reply = "Вода пошла в %s арык. Ждёт мерки." % SIDE_RU[side]
		"open_wide":
			s.reply = "Поднял до отказа: верхний полон, нижний сух."\
				+ " Так суд не течёт, как вода."
		"shut":
			if s.open == "":
				s.reply = "Закрывать нечего: заслонка опущена."
			else:
				s.served.append(s.open)
				s.served.sort()
				s.open = ""
				if s.served.size() >= 2:
					s.done = true
					s.reply = "Обоим дано поровну, по мерке. Воду делят"\
						+ " по очереди: суд течёт, как вода."
				else:
					s.reply = "Мера дана. Очередь другого русла."
	return s
