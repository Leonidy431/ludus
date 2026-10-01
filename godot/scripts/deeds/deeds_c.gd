## Group c of the small acts at the hearts of places (PlaceDeeds; the
## contract is written at the top of place_deeds.gd): the community.
## Five acts, each a small deterministic state machine that teaches one
## discernment by the hands of the place's own craft:
##   separate-contract  (tana-port)     read, strike the creed line, seal
##   speak-of-maker     (kam-yurt)      sit, listen, speak; never join
##   hear-both-sides    (porch-court)   hear two, compare, then write
##   tell-custom-from-faith (wedding-yard)  sort four gifts of the feast
##   teach-a-letter     (crafts-school) smooth, show, guide, let go
## A wrong step answers in the craft's language (TABOO 0.39: a trader
## speaks of scales and wax, a nomad of felt and horses, a clerk of ink,
## a teacher of wax and stylus) and leaves the act open.  Nothing here
## changes FORM or counts a point, and nothing is random.  No line names
## a holy thing as a tool: in the yurt the player never enters the rite,
## and in the wedding yard custom is taken and faith is not mixed.
##
## Constitution: ФОРМА (the place and its craft) → ДЕЙСТВИЕ (the one
## act done in the right order) → ЦЕЛЬ (the lesson of the place learned
## by the hands: a road may be sold, a faith may not; speak without
## entering; judge after both; take the custom, keep the faith; teach
## without asking a price).
extends RefCounted

const ALREADY := "Это уже сделано."

## Acts that go step by step.  "steps" are the right buttons in their
## right order (text, reply when taken in order); "early" is the reply
## when a later step is tried too soon; "extras" are buttons that are
## always wrong and say why; "order" is the order of the buttons on the
## panel (one wrong button leads and the right ones follow, so no two
## wrong ones stand side by side before the next right step); "scene"
## holds the panel lines, one list for each stage and a last one for
## the closed act.
const SEQ := {
	"separate-contract": {
		"steps": [
			{"id": "read", "text": "Прочесть договор строку за строкой",
				"ok": "Строка за строкой. На четвёртой — о вере: её "
					+ "вписали между ценой и сроком."},
			{"id": "strike", "text": "Вычеркнуть строку о вере",
				"ok": "Вычеркнуто. Цена и срок остались сами по себе."},
			{"id": "seal", "text": "Скрепить печатью торговые строки",
				"ok": "Печать легла на цену и срок. Путь продан, веры "
					+ "в нём нет."},
		],
		"early": {
			"strike": "Не видя строки, не вычеркнешь. Сперва прочти до "
				+ "конца, как проверяют мешок перед весами.",
			"seal": "Печать на сыром воске ложится на всё сразу. Что не "
				+ "отделено, то продано вместе с товаром.",
		},
		"extras": [
			{"id": "seal_all", "text": "Скрепить печатью весь договор",
				"reply": "Весы берут вес товара. Веру на чашу не кладут: "
					+ "что на неё легло, то уже продано."},
			{"id": "weigh", "text": "Взвесить пошлину на весах",
				"reply": "Весы честны, но взвешивают они груз. Договор "
					+ "читают глазами, а не весами."},
		],
		"order": ["seal_all", "read", "strike", "seal", "weigh"],
		"scene": [
			["Договор лежит на столе, воск у печати мягкий.",
				"В нём цена, срок и ещё что-то."],
			["Строка о вере найдена. Она вплетена в цену, как "
				+ "камень в мешок с зерном."],
			["Остались цена и срок. Печать тёплая."],
			["Договор скреплён. Путь можно продать, веру — нет."],
		],
	},
	"speak-of-maker": {
		"steps": [
			{"id": "greet",
				"text": "Поклониться хозяину и сесть у порога",
				"ok": "Хозяин кивнул. Гость у порога сидит в мире: в "
					+ "круг его не зовут и не гонят."},
			{"id": "listen", "text": "Выслушать кама до конца",
				"ok": "Кам говорил о небе, о коне и о предках. Ты "
					+ "слушал, не споря и не повторяя."},
			{"id": "speak",
				"text": "Сказать, что Творец неба один и ты чтишь Его",
				"ok": "Сказано тихо и один раз. Кам помолчал и "
					+ "подбросил в очаг сухую ветку."},
		],
		"early": {
			"listen": "Гость, не севший у порога, не слышит: стоит "
				+ "одной ногой в двери. Сперва сядь.",
			"speak": "Слово, сказанное поверх чужой речи, как конь, "
				+ "пущенный в чужую отару. Дождись, пока хозяин "
				+ "замолчит.",
		},
		"extras": [
			{"id": "join", "text": "Встать в круг и кружить за бубном",
				"reply": "Чужого коня не седлают. Ты гость у порога, а "
					+ "не всадник в чужом обряде. Сядь на войлок."},
			{"id": "pour", "text": "Брызнуть кумыс небу, как все",
				"reply": "Чаша хозяина льётся по его обычаю. Пей свою "
					+ "долю, а лить за него не берись."},
		],
		"order": ["join", "greet", "listen", "speak", "pour"],
		"scene": [
			["В юрте очаг и войлок. Хозяин-кам сидит напротив "
				+ "входа."],
			["Хозяин говорит. Ты сидишь у порога и слушаешь."],
			["Хозяин замолчал. Теперь твой черёд, и он один."],
			["О Творце неба сказано. В круг ты не входил: мир без "
				+ "смешения."],
		],
	},
	"teach-a-letter": {
		"steps": [
			{"id": "smooth", "text": "Разгладить воск на дощечке",
				"ok": "Воск гладкий, как стоячая вода. На нём виден "
					+ "каждый след."},
			{"id": "show", "text": "Вывести букву медленно, на глазах",
				"ok": "Одна буква, три движения. Ребёнок следит "
					+ "за стилом."},
			{"id": "guide", "text": "Провести его руку по борозде",
				"ok": "Рука ребёнка прошла путь вместе с твоей. "
					+ "Теперь она знает дорогу."},
			{"id": "alone", "text": "Отпустить руку: пусть выведет сам",
				"ok": "Буква кривая, но его. Воск разгладишь — "
					+ "будет следующая."},
		],
		"early": {
			"show": "На жёстком воске след не держится. Сперва "
				+ "разгладь, потом пиши.",
			"guide": "Нечего вести, пока он не видел всей буквы. "
				+ "Покажи один раз, медленно.",
			"alone": "Рука ещё не знает пути. Проведи её вместе "
				+ "с твоей, потом отпусти.",
		},
		"extras": [
			{"id": "whole", "text": "Вывести за него всю строку",
				"reply": "Это выведена твоя строка, а не его. Стило "
					+ "учит в той руке, которая его держит."},
			{"id": "price", "text": "Дать хлеб, когда он согласится с "
				+ "тобой в вере",
				"reply": "Хлеб даётся голодному, а не продаётся за "
					+ "слово. Воск учит букве, а не торгу."},
		],
		"order": ["whole", "smooth", "show", "guide", "alone", "price"],
		"scene": [
			["Под навесом ребёнок и воск на дощечке. Стило лежит "
				+ "рядом."],
			["Воск ровный. Ребёнок ждёт, что ему покажут."],
			["Он видел букву. Его рука ещё не знает борозды."],
			["Рука знает дорогу. Остаётся отпустить."],
			["Буква выведена его рукой. За хлеб ничего не просили."],
		],
	},
}

## The four gifts of the wedding feast, in the order they come.  "take"
## says whether the custom is to be taken (true) or the oath refused.
const FEAST := [
	{"scene": "Гости запели свадебный напев на своём языке.",
		"take": true, "yes": "Подпеть напев вместе со всеми",
		"no": "Попросить гостей замолчать",
		"ok": "Ты подпел. Напев ходит от двора ко двору, как вода "
			+ "от колодца к колодцу.",
		"bad": "Напев не вера, он как вода из общего колодца. "
			+ "Отгонять его — отгонять гостей."},
	{"scene": "Невесте дарят расшитую одежду по обычаю степи.",
		"take": true, "yes": "Принять расшитый платок на плечи",
		"no": "Вернуть дар: одежда чужая",
		"ok": "Платок лёг на плечи. Одежда греет всякого, "
			+ "кто её надел.",
		"bad": "Платок греет плечи, а не душу. Дар возвращают, "
			+ "когда он что-то требует взамен, а этот не требует."},
	{"scene": "Хозяева делят хлеб за общим столом.",
		"take": true, "yes": "Преломить хлеб со всеми",
		"no": "Отсесть: за этим столом чужие",
		"ok": "Хлеб преломлён. Стол накрыт для людей, а не для "
			+ "одной веры.",
		"bad": "Хлеб ломают с каждым, кто пришёл с миром. "
			+ "Отсесть — значит обидеть без причины."},
	{"scene": "Сват зовёт всех поклясться чужим духам над общей "
			+ "чашей.",
		"take": false, "yes": "Поклясться со всеми над чашей",
		"no": "Поблагодарить и не клясться",
		"ok": "Стол общий, клятва своя. Ты остался за столом и "
			+ "веру не смешал.",
		"bad": "Напев и платок берут на плечи, а клятву — на душу. "
			+ "Чужое на душу не берут. Попробуй иначе."},
]

## What the court's panel says at each stage of the hearing.
const HEAR_LINES := [
	"Двое спорят о меже и о долге. Книга и расписка лежат рядом.",
	"Истец сказал. Ответчик ждёт своей очереди.",
	"Ответчик сказал. Истец ждёт, что его не перебьют.",
	"Оба сказали всё. Книга и расписка ещё не сверены.",
	"Книга и расписка сверены. Перо над чистой строкой.",
	"Дело записано. Обе стороны выслушаны, ни одну не обошли.",
]


static func ids() -> Array:
	return ["separate-contract", "speak-of-maker", "hear-both-sides",
		"tell-custom-from-faith", "teach-a-letter"]


static func start(id: String) -> Dictionary:
	if id == "hear-both-sides":
		return {"done": false, "reply": "", "a": false, "b": false,
			"cmp": false}
	return {"done": false, "reply": "", "step": 0}


static func lines(id: String, s: Dictionary) -> Array:
	if id == "hear-both-sides":
		return [HEAR_LINES[_hear_stage(s)]]
	if id == "tell-custom-from-faith":
		if s.get("done", false):
			return ["Напев и платок приняты, клятва оставлена. Мир общин "
				+ "без смешения."]
		return [FEAST[int(s.step)].scene]
	var scene: Array = SEQ[id].scene[int(s.step)]
	return scene.duplicate()


static func options(id: String, s: Dictionary) -> Array:
	var out := []
	if id == "hear-both-sides":
		return [
			_btn("hear_a", "Выслушать истца до конца", s.a,
				"Он уже всё сказал."),
			_btn("hear_b", "Выслушать ответчика до конца", s.b,
				"Он уже всё сказал."),
			_btn("cut", "Прервать, когда дело стало ясно", false, ""),
			_btn("compare", "Сверить книгу с распиской", s.cmp,
				"Уже сверено."),
			_btn("write", "Записать решение в книгу", false, ""),
		]
	if id == "tell-custom-from-faith":
		var g: Dictionary = FEAST[int(s.step)]
		return [_btn("take", g.yes, false, ""),
			_btn("leave", g.no, false, "")]
	var def: Dictionary = SEQ[id]
	var done_ids := []
	for i in range(int(s.step)):
		done_ids.append(def.steps[i].id)
	for bid in def.order:
		out.append(_btn(bid, _text_of(def, bid), bid in done_ids,
			ALREADY))
	return out


static func choose(id: String, s: Dictionary, c: String) -> Dictionary:
	if s.get("done", false):
		return s
	match id:
		"hear-both-sides":
			return _hear(s, c)
		"tell-custom-from-faith":
			return _feast(s, c)
		_:
			return _seq(id, s, c)


## None of the community acts asks to wait, so time passes without effect.
static func tick(_id: String, s: Dictionary, _dt: float,
		_still: bool) -> Dictionary:
	return s


static func _btn(id: String, text: String, off: bool,
		why: String) -> Dictionary:
	return {"id": id, "text": text, "disabled": off,
		"reason": why if off else ""}


static func _text_of(def: Dictionary, bid: String) -> String:
	for st in def.steps:
		if st.id == bid:
			return st.text
	for e in def.extras:
		if e.id == bid:
			return e.text
	return ""


## One step of a sequential act: the right button in its turn moves it
## on, a button of a later step answers "not yet", an extra always
## teaches why it is wrong.
static func _seq(id: String, s: Dictionary, c: String) -> Dictionary:
	var def: Dictionary = SEQ[id]
	var at: int = int(s.step)
	for i in range(def.steps.size()):
		var st: Dictionary = def.steps[i]
		if st.id != c:
			continue
		if i < at:
			s["reply"] = ALREADY
		elif i > at:
			s["reply"] = def.early[c]
		else:
			s["step"] = at + 1
			s["reply"] = st.ok
			s["done"] = at + 1 >= def.steps.size()
		return s
	for e in def.extras:
		if e.id == c:
			s["reply"] = e.reply
			return s
	return s


static func _hear_stage(s: Dictionary) -> int:
	if s.get("done", false):
		return 5
	if s.cmp:
		return 4
	if s.a and s.b:
		return 3
	if s.b:
		return 2
	if s.a:
		return 1
	return 0


## The hearing: either side first, both to the end, then the book is set
## against the receipt, and only then the pen.  Cutting a speaker short
## teaches and closes nothing.
static func _hear(s: Dictionary, c: String) -> Dictionary:
	var both: bool = s.a and s.b
	match c:
		"hear_a":
			if s.a:
				s["reply"] = "Он уже всё сказал."
			else:
				s["a"] = true
				s["reply"] = "Истец сказал всё: о меже и о долге. " \
					+ "Ты не перебил его."
		"hear_b":
			if s.b:
				s["reply"] = "Он уже всё сказал."
			else:
				s["b"] = true
				s["reply"] = "Ответчик сказал всё: о воде и о сроке. " \
					+ "Ты не перебил и его."
		"cut":
			s["reply"] = "Кто слышит одного, судит вполовину. Весы " \
				+ "с одной чашей не весы."
		"compare":
			if s.cmp:
				s["reply"] = "Уже сверено."
			elif not both:
				s["reply"] = "Сверять нечего, пока не сказали обе " \
					+ "стороны: расписка одна, а слов должно быть два."
			else:
				s["cmp"] = true
				s["reply"] = "Книга и расписка сошлись в долге и " \
					+ "разошлись в сроке. Теперь ясно, где у каждого " \
					+ "правда."
		"write":
			if not both:
				s["reply"] = "Чернила сохнут быстро, а слух должен " \
					+ "быть быстрее. Сперва выслушай обоих до конца."
			elif not s.cmp:
				s["reply"] = "Перо не торопится. Сверь книгу с " \
					+ "распиской, потом пиши."
			else:
				s["done"] = true
				s["reply"] = "Записано после обоих. Правда общины " \
					+ "решена внутри общины, без лицеприятия."
	return s


## The feast: one gift after another, taken or refused by its nature.
## A wrong answer teaches and the same gift stays on the table.
static func _feast(s: Dictionary, c: String) -> Dictionary:
	var g: Dictionary = FEAST[int(s.step)]
	if c != "take" and c != "leave":
		return s
	if (c == "take") != g.take:
		s["reply"] = g.bad
		return s
	s["reply"] = g.ok
	s["step"] = int(s.step) + 1
	s["done"] = int(s.step) >= FEAST.size()
	return s
