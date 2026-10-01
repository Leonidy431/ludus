## Group d of the small acts at the hearts of places (PlaceDeeds; the
## contract is written at the top of place_deeds.gd): road and memory.
##
## Five acts: lay-a-stone (santash-pass), seal-the-chronicle
## (archive-crypt), find-pole-star (star-shore), tell-only-true
## (map-workshop), compare-forms (sis-armourer).  Each is a short row of
## steps where discernment matters, not speed: the wrong button answers
## in the place's own craft language and teaches, the right one moves on.
## No act asks to wait, so tick() leaves the state as it was.  Nothing
## here is random, nothing changes FORM and nothing is counted: the act
## is done or it is not.
##
## Constitution: ФОРМА (the place's craft and its things) → ДЕЙСТВИЕ (the
## steps done in the right order) → ЦЕЛЬ (the lesson of the place learned
## by the hands: a memory without a count, a record kept and not hidden,
## a route and not a fate, a witness without embellishment, a form and
## not a quarrel).
extends RefCounted

## Every step: "ask" is the line shown, "opts" are the buttons in a fixed
## order as [text, right, reply].  A right button's reply is empty, so
## the panel just shows the next ask; a wrong one teaches.  The right
## button is not always first, so that order of the list teaches nothing.
## "done" is the closing line naming what was learned.
const ACTS := {
	"lay-a-stone": {
		"steps": [
			{"ask": "Курган велик, камней на нём не счесть. Какой взять?",
			"opts": [
				["Самый тяжёлый, чтобы все увидели", false,
					"Камень не по силам: спина скажет раньше кургана. "
					+ "Бери по руке."],
				["Набрать полную пазуху", false,
					"Курган не склад. Один камень, одна память."],
				["Тот, что поднимешь одной рукой", true, ""]]},
			{"ask": "Камень в руке. Куда его положить?",
			"opts": [
				["Сбоку, где ещё есть место", true, ""],
				["Сверху, повыше всех", false,
					"Кто лезет наверх, тот глядит на себя, а не на "
					+ "тех, кого помнит."],
				["Подвинуть чужой, чтобы лёг ровнее", false,
					"Чужой камень стоит на своём месте. Не трогай."]]},
			{"ask": "Камень лёг. Что дальше?",
			"opts": [
				["Пересчитать камни на кургане", false,
					"Кто считает, тот торгуется с памятью. Курган "
					+ "счёта не ведёт."],
				["Отойти к костру и не считать", true, ""],
				["Сложить рядом второй, про запас", false,
					"Второй уже не про память, а про счёт. Хватит "
					+ "одного."]]},
		],
		"done": "Камень лёг один и без счёта. Память не копят, её "
			+ "кладут.",
	},
	"seal-the-chronicle": {
		"steps": [
			{"ask": "Лист летописи перед тобой. Что делать первым?",
			"opts": [
				["Скрепить воском сразу", false,
					"Воск ляжет на ошибку и закроет её. Сперва "
					+ "проверь строки."],
				["Вычеркнуть неудобное место", false,
					"Вычеркнуть не значит сберечь. Память хранят "
					+ "целиком, и неудобное тоже."],
				["Сверить каждую строку с тем, что было", true, ""]]},
			{"ask": "Строки верны, но чернила ещё сырые.",
			"opts": [
				["Запечатать тёплым воском", false,
					"Сырой лист под воском поплывёт. Подожди."],
				["Дать листу высохнуть", true, ""],
				["Сложить лист вдвое", false,
					"Свежие чернила отпечатаются на обороте."]]},
			{"ask": "Лист сух. Как его укрыть?",
			"opts": [
				["Залить воском весь лист", false,
					"Воск на самом листе склеит строки. Он держит "
					+ "шов, а не письмо."],
				["Спрятать без печати, подальше", false,
					"Что спрятано без печати, то легко подменить. "
					+ "Хранят открыто и под печатью."],
				["Обернуть кожей, воск положить на шов", true, ""]]},
		],
		"done": "Летопись цела: воск на шве, кожа вокруг, строки не "
			+ "тронуты. Её сберегли, а не спрятали.",
	},
	"find-pole-star": {
		"steps": [
			{"ask": "Небо ночное, открытое. С чего начать?",
			"opts": [
				["Искать самую яркую звезду", false,
					"Самая яркая не Полярная. Ищи по Ковшу: его край "
					+ "указывает на неё."],
				["Спросить, что звёзды сулят", false,
					"Звёзды не сулят, они показывают. Путь берут, "
					+ "судьбу не берут."],
				["Найти Ковш и вести взгляд по его краю", true, ""]]},
			{"ask": "Звезда найдена. В руках астролябия.",
			"opts": [
				["Навести визир и снять высоту", true, ""],
				["Прикинуть высоту по пальцам", false,
					"Для пальцев рано: прибор в руках затем, чтобы "
					+ "мерить, а не гадать."],
				["Загадать на звезду", false,
					"Здесь не гадают. Здесь считают высоту и берут "
					+ "пеленг."]]},
			{"ask": "Высота снята. Что с пеленгом?",
			"opts": [
				["Идти на звезду, пока не дойдёшь", false,
					"К звезде не дойти. Её берут ориентиром, а шаг "
					+ "сверяют с картой."],
				["Сверить с компасом и записать", true, ""],
				["Записать как знак к добру или худу", false,
					"Высота есть число, а не знак. Она называет "
					+ "место, а не долю."]]},
		],
		"done": "Пеленг взят и записан. Звезда указала путь, а судьбы "
			+ "не знает: это навигация.",
	},
	"tell-only-true": {
		"steps": [
			{"ask": "Картограф ждёт. Что ему рассказать?",
			"opts": [
				["Всё, что слышал в порту", false,
					"Слух не свидетельство. Расскажи, что видел сам."],
				["То, что красивее ляжет на карту", false,
					"Карта не песня. Красота берега не наносит."],
				["Только то, что видел сам", true, ""]]},
			{"ask": "Сколько дней пути до обители? Ты шёл пять с "
				+ "половиной.",
			"opts": [
				["Прибавить пару дней на всякий случай", false,
					"Лишнее на карте лишняя дорога для моряка. "
					+ "Скажи как шёл."],
				["Назвать пять с половиной, как шёл", true, ""],
				["Округлить до шести, звучит надёжнее", false,
					"Круглое число вводит в заблуждение. Скажи как "
					+ "шёл."]]},
			{"ask": "За озером горы, про которые ты только слышал.",
			"opts": [
				["Нарисовать со слов, с драконами", false,
					"Со слов рисуют легенду. Пусть край будет "
					+ "пустым, а не выдуманным."],
				["Промолчать об этом совсем", false,
					"Молчание путает не меньше лжи. Скажи, что не "
					+ "видел, и картограф оставит край пустым."],
				["Сказать: этого я не видел", true, ""]]},
		],
		"done": "Картограф вывел то, что ты видел, и оставил край "
			+ "пустым. На карте обитель, а не легенда.",
	},
	"compare-forms": {
		"steps": [
			{"ask": "Шлем мастера лежит на наковальне, рядом чертёж "
				+ "аппарата. С чего начать?",
			"opts": [
				["Сравнить цвет: что темнее", false,
					"Цвет это окалина. Железо судят по форме."],
				["Снять обвод шлема и приложить к обводу корпуса",
					true, ""],
				["Решить на глаз, что красивее", false,
					"Красота не мера. Мерь обвод."]]},
			{"ask": "Обводы сходятся не везде. Где они сходятся?",
			"opts": [
				["Там, где ручка и крепёж", false,
					"Ручка держит руку, а не поток. Смотри на лоб."],
				["Нигде: века разные, задачи разные", false,
					"Века разные, а вода и удар те же. Приложи "
					+ "ещё раз."],
				["Там, где поток встречает преграду: лоб и нос",
					true, ""]]},
			{"ask": "Что скажешь о двух мастерах?",
			"opts": [
				["Один списал у другого", false,
					"Не списывали: сошлись, как две дороги у одного "
					+ "брода. Сравнивай, не обвиняй."],
				["Старое лучше нового", false,
					"Не лучше и не хуже. Мастер ковал для головы, "
					+ "инженер для течения, а задача одна."],
				["Задача одна, и железо служит человеку", true, ""]]},
		],
		"done": "Обводы сошлись там, где поток бьёт в преграду. Железо "
			+ "служит человеку: так решал и мастер, и инженер.",
	},
}


static func ids() -> Array:
	return ACTS.keys()


static func start(_id: String) -> Dictionary:
	return {"done": false, "reply": "", "step": 0, "tried": []}


## The body lines: what the wrong steps of this question taught (all of
## them, so pressing one again loses nothing), then the ask of the step;
## a closed act shows only what was learned.
static func lines(id: String, s: Dictionary) -> Array:
	var act: Dictionary = ACTS[id]
	if s.get("done", false):
		return [act.done]
	var step: Dictionary = act.steps[int(s.get("step", 0))]
	var out := []
	for i in s.get("tried", []):
		out.append(step.opts[int(i)][2])
	out.append(step.ask)
	return out


## The buttons of the current step; a closed act has none.  The id is the
## button's place in the step, which is stable because the lists are
## constants.
static func options(id: String, s: Dictionary) -> Array:
	if s.get("done", false):
		return []
	var step: Dictionary = ACTS[id].steps[int(s.get("step", 0))]
	var out := []
	for i in step.opts.size():
		out.append({"id": "o%d" % i, "text": step.opts[i][0],
			"disabled": false, "reason": ""})
	return out


static func choose(id: String, s: Dictionary, c: String) -> Dictionary:
	if s.get("done", false) or not c.begins_with("o"):
		return s
	var act: Dictionary = ACTS[id]
	var n := int(s.get("step", 0))
	var opts: Array = act.steps[n].opts
	if not c.substr(1).is_valid_int():
		return s
	var i := c.substr(1).to_int()
	if i < 0 or i >= opts.size():
		return s
	if not opts[i][1]:
		# A wrong step teaches and leaves the act open at the same step.
		# Pressing the same wrong button again changes nothing: it was
		# answered already and its line stays on the panel.
		var tried: Array = s.get("tried", [])
		if i in tried:
			return s
		tried.append(i)
		tried.sort()
		s["tried"] = tried
		s["reply"] = opts[i][2]
		return s
	if n + 1 >= act.steps.size():
		s["done"] = true
		s["reply"] = act.done
	else:
		s["step"] = n + 1
		s["reply"] = ""
		s["tried"] = []
	return s


## None of these acts asks to wait still.
static func tick(_id: String, s: Dictionary, _dt: float,
		_still: bool) -> Dictionary:
	return s
