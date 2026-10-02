## Group e of the small acts at the hearts of places: storm, Kiberslav and
## finds (PlaceDeeds; the contract is written at the top of place_deeds.gd).
##
## Six acts.  Three are chains of steps where order or discernment matters:
## wait-out-storm (storm-bay), spot-the-haze (reactor-izba) and
## type-by-memory (zero-board).  Three are finds of the lake, each one
## "observe and leave": look without touching, note the belt and depth
## from the lake registry, tell the scribe, leave the thing where it lies.
## A find is never taken into a bag, holy or not (Constitution: a find is
## not loot), so the "take it" button exists only as the wrong step that
## teaches.
##
## A wrong step answers in the place's own craft language (TABOO 0.39) and
## leaves the step open; the right one moves on; the last closes the act
## with what it taught.  Only wait-out-storm asks to wait still: its last
## step counts seconds while the player stands still and starts again when
## the player moves.  Prayer is not a switch of currents, so the storm
## teaches waiting, not words.  Nothing is random, nothing changes FORM,
## and no counter or score is ever shown.
##
## Constitution: ФОРМА (the place and its craft) → ДЕЙСТВИЕ (one act in its
## right order) → ЦЕЛЬ (the lesson of the place learned by the hands).
extends RefCounted

const LAKE := "res://data/lake-objects-99.json"
## Seconds of standing still that close the storm act; short enough to
## stay comfortable in the headset, long enough to be a real wait.
const STORM_WAIT := 12.0

## Every step is {"q": panel line, "o": [option, ...]} and an option is
## [id, button text, is it right, reply].  A step with "wait" is a
## waiting step: its right option only keeps the player waiting.  The
## right options do not all stand first, so the order is not a habit.
const ACTS := {
	"wait-out-storm": [
		{"q": "Шторм у залива. Что видно на воде?", "o": [
			["go-now", "Выйти на лодке: у берега затишье", false,
				"Затишье у кромки обманчиво: рыбак смотрит на дальние валы."],
			["read", "Смотреть на дальние валы и на пену у мыса", true,
				"Валы идут рядами, пена рвётся к мысу: течение сильнее лодки."],
			["swim", "Войти по пояс и проверить течение ногой", false,
				"Разрывное течение берёт ногу первым и уносит быстрее шага."],
		]},
		{"q": "Лодка на берегу. Как её держать?", "o": [
			["leave", "Оставить на песке: никто не тронет", false,
				"Волна дойдёт и до песка. Лодка без швартова уходит первой."],
			["haul", "Вытащить выше валов, привязать к якорному камню",
				true, "Канат натянут, камень лёг тяжело: лодка стоит."],
			["oar-only", "Положить вёсла под борт и уйти", false,
				"Вёсла к лодке не привязать: найдёшь их потом у чужого берега."],
			["row", "Спустить лодку: вдруг хватит сил", false,
				"Вёсла не сильнее течения. Кто вышел в шторм, тот сам "
				+ "стал уловом."],
		]},
		{"q": "Всё закреплено. Течение рвёт у выхода из залива.",
			"wait": STORM_WAIT, "o": [
			["wait", "Стоять под навесом у фонаря и ждать", true,
				"Ты ждёшь. Течение не слушает слов, оно уходит, когда "
				+ "кончается шторм."],
		]},
	],
	"spot-the-haze": [
		{"q": "Ночь. Изба с тёмными окнами. Куда смотреть?", "o": [
			["smoke", "На трубу: где дым, там и жизнь", false,
				"Дым могли пустить для вида. Он скажет то, что хочет хозяин."],
			["air", "На воздух над крышей: он дрожит на свету фонаря", true,
				"Над крышей воздух дрожит, как над печью. Тепло не спрячешь."],
			["door", "На дверь: скрипит ли замок", false,
				"Замок молчит и у пустой избы, и у занятой."],
		]},
		{"q": "Марево есть. Как проверить, что это не игра света?", "o": [
			["sure", "Не проверять: и так ясно", false,
				"Одно наблюдение: это слух. Улика, когда её можно повторить."],
			["compare", "Сравнить с холодной избой рядом, в тот же час",
				true, "Соседний воздух стоит ровно. Разница не от света."],
			["lamp", "Подойти с лампой и посветить в окно", false,
				"Свет в окно скажет о тебе, а не об избе."],
		]},
		{"q": "Разница есть. Что записать в книгу находок?", "o": [
			["break", "Вскрыть дверь и посмотреть самому", false,
				"Вскрытая дверь предупредит тех, кто внутри. Улика нужна, "
				+ "а не шум."],
			["note", "Место, час, разницу с соседней; дверь не трогать",
				true, "Записано с часом и мерой. По теплу узнают узел, "
				+ "а не по слуху."],
			["tale", "Что изба заколдована: пусть другие боятся", false,
				"Страх не мера. Тепло объясняется печью и железом, "
				+ "а не сказкой."],
		]},
	],
	"type-by-memory": [
		{"q": "Нулевая плата. Что подключить к ней?", "o": [
			["net", "Обычную клавиатуру через сеть: так быстрее", false,
				"Сеть видит каждый байт ещё до платы. Тут нужен прямой "
				+ "провод."],
			["analog", "Аналоговую клавиатуру прямым проводом", true,
				"Провод короткий, сеть далеко: рука и плата вдвоём."],
		]},
		{"q": "Береста лежит рядом. Как вводить байты?", "o": [
			["paste", "Вставить всё куском из буфера", false,
				"Буфер не память: он оставляет след, а рука не оставляет."],
			["memory", "Байт за байтом по памяти, сверяя с напевом",
				true, "Байт к байту, как строка к строке в напеве."],
			["read", "Читать с бересты и вводить, глядя на строки", false,
				"Береста у стойки: чужой глаз её увидит. Напев помнят, "
				+ "а не читают."],
		]},
		{"q": "Байты введены. Плата ждёт, чтобы ты назвался.", "o": [
			["silent", "Промолчать и нажать ввод", false,
				"Свидетельство без имени не свидетельство. Голос нужен "
				+ "плате не меньше рук."],
			["name", "Сказать вслух своё имя, имя отца и город", true,
				"Назвался и стал виден. Цена названа; подвиг не в том, "
				+ "чтобы стереть себя."],
			["wipe", "Стереть следы и уйти незаметным", false,
				"Стереть следы значит стереть себя. Здесь нужно стать "
				+ "видимым, а не исчезнуть."],
		]},
	],
}

## The belt of a find in the words of the panel.
const BANDS := {"shallows": "мелководье", "thermocline": "термоклин",
	"deep": "глубина", "bottom": "дно"}

## What each find says of its own thing: look, wrong take, last word.
const FINDS := {
	"bulla.shallows.0": {
		"look": "Осмотрел буллу, не касаясь: на свинце оттиск, лежит плашмя.",
		"take": "Чужую веру хранят на месте и бережно: булла не трофей "
			+ "и не сувенир.",
		"end": "Булла осталась в песке. Чужое хранят, а не уносят.",
	},
	"fundament.shallows.1": {
		"look": "Осмотрел камни, не касаясь: ряды ровные, угол прямой. "
			+ "Скала так не ложится.",
		"take": "Камень из линии вынешь: фундамент станет россыпью и "
			+ "перестанет говорить.",
		"end": "Фундамент остался как лежал. Прямой угол выдаёт руку "
			+ "человека.",
	},
	"chebachok.shallows.0": {
		"look": "Смотрел издали, не двигаясь: стайка держится у харовой "
			+ "травы и не боится.",
		"take": "Стайка от руки разлетается. Сачок возьмёт рыбу, но "
			+ "потеряет луг.",
		"end": "Стайка осталась у травы. Живое смотрят, а не ловят.",
	},
}

static var _lake := {}


static func ids() -> Array:
	var out := ACTS.keys()
	for k in FINDS.keys():
		out.append("find:" + k)
	return out


## The registry entry of a lake object, read once and kept.
static func _object(oid: String) -> Dictionary:
	if _lake.is_empty():
		var f := FileAccess.open(LAKE, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for o in d.get("objects", []):
					_lake[str(o.id)] = o
	return _lake.get(oid, {})


## The steps of an act: a table for the fixed acts, built from the lake
## registry for a find (belt and depth come from the data, not from here).
static func _steps(id: String) -> Array:
	if ACTS.has(id):
		return ACTS[id]
	if not id.begins_with("find:"):
		return []
	var oid := id.substr(5)
	var say: Dictionary = FINDS.get(oid, {})
	var obj := _object(oid)
	if say.is_empty() or obj.is_empty():
		return []
	var d: Array = obj.get("depth", [0, 0])
	var band: String = BANDS.get(str(obj.get("band", "")),
		str(obj.get("band", "")))
	var mark := "%s, %d–%d м" % [band, int(d[0]), int(d[1])]
	return [
		{"q": "Перед тобой: %s. Что делаешь?" % obj.get("ru", ""), "o": [
			["lift", "Поднять и рассмотреть в руке", false, say.take],
			["look", "Осмотреть, не касаясь", true, say.look],
			["move", "Сдвинуть, чтобы увидеть, что под ней", false,
				"Сдвинешь и потеряешь место: находка говорит "
				+ "положением, а не только видом."],
		]},
		{"q": "Где она лежит? Запиши пояс и глубину.", "o": [
			["deep", "Ниже термоклина, около 60 м", false,
				"Термоклин на 50 м, а ты в свете прожектора у берега: "
				+ "пояс другой."],
			["mark", mark, true,
				"Записано: " + mark + ". Место без меры не найдёшь вновь."],
			["mid", "Середина озера, 20–30 м", false,
				"Здесь не 20–30 м. Глубину берут с прибора, а не на глаз."],
		]},
		{"q": "Кому сказать о находке?", "o": [
			["silent", "Никому, вернуться за ней потом", false,
				"Скрытая находка пропала для всех. Её место знает "
				+ "только писец."],
			["scribe", "Писцу обители: что, где, на какой глубине", true,
				"Писец записал в книгу находок. Теперь это знает обитель."],
		]},
		{"q": "Записано. Как поступить с вещью?", "o": [
			["bag", "Взять в мешок: пригодится", false, say.take],
			["leave", "Оставить на месте", true, say.end],
		]},
	]


static func start(_id: String) -> Dictionary:
	return {"done": false, "reply": "", "step": 0, "waited": 0.0}


static func lines(id: String, s: Dictionary) -> Array:
	var steps := _steps(id)
	var i := int(s.get("step", 0))
	if s.get("done", false) or i >= steps.size():
		return []
	return [str(steps[i].q)]


static func options(id: String, s: Dictionary) -> Array:
	var steps := _steps(id)
	var i := int(s.get("step", 0))
	var out := []
	if s.get("done", false) or i >= steps.size():
		return out
	for o in steps[i].o:
		out.append({"id": o[0], "text": o[1], "disabled": false,
			"reason": ""})
	return out


static func choose(id: String, s: Dictionary, c: String) -> Dictionary:
	var steps := _steps(id)
	var i := int(s.get("step", 0))
	if s.get("done", false) or i >= steps.size():
		return s
	for o in steps[i].o:
		if o[0] != c:
			continue
		s["reply"] = str(o[3])
		if steps[i].has("wait"):
			# Waiting is only broken by moving: a wrong step starts the
			# wait again, the right one just goes on waiting.
			if not o[2]:
				s["waited"] = 0.0
			return s
		if o[2]:
			s["step"] = i + 1
			if i + 1 >= steps.size():
				s["done"] = true
		return s
	return s


## Only a waiting step counts time, and only while the player stands still.
static func tick(id: String, s: Dictionary, dt: float,
		still: bool) -> Dictionary:
	var steps := _steps(id)
	var i := int(s.get("step", 0))
	if s.get("done", false) or i >= steps.size() or not steps[i].has("wait"):
		return s
	if not still:
		s["waited"] = 0.0
		return s
	s["waited"] = float(s.get("waited", 0.0)) + maxf(dt, 0.0)
	if s.waited >= float(steps[i].wait):
		s["step"] = i + 1
		s["done"] = true
		for o in steps[i].o:
			if o[2]:
				s["reply"] = str(o[3])
	return s
