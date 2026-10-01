## The campaign of missions, ported from public/ludus/ludus-missions.js
## (normalizeState, buildMission, nextMission, catalog, canStart, start,
## view, choose, advance, fallStatus, liftFall).  The JS module is the
## reference: godot/tests/test_mission.gd replays
## godot/tests/fixtures/missions.json, written from it by
## scripts/godot/make_mission_fixture.js.
##
## The spine (data/campaign-spine.json) holds a prologue, five acts and
## a finale, 99 missions.  The prologue and Act I are the caravan road of
## the knight of fallen Cilicia to the Armenian brothers on Issyk-Kul
## (TABOO 0.03 point 2).  Each mission is four steps of the game's own
## ACTION layer: a find (a real object of the lake), a deed of the rule,
## a talk from the shared dialogue trees and a dive with the real
## physics of the lake.  Consequences are deterministic (TABOO 0.35 rule
## 15): +1..+5 to one of the seven attributes by the depth of the choice,
## capped by the act's ceiling, a path opened, or a person who greets
## the player differently next time.  No random number is drawn here.
##
## The fall replaces losing: a passion's lure closes the deep answers
## and the road to the next mission until sobriety and a talk with the
## mentor lift it (TrialCore holds the fall, shared with the thresholds).
## Prayer never pays: only deeds are mission steps (TABOO 0.35 rule 16).
class_name MissionCore
extends RefCounted

const ATTRS := ["wisdom", "faith", "dexterity", "constitution", "charisma",
	"cunning", "erudition"]
const GATE_IDS := ["foundational", "liturgical", "ascetic",
	"contemplative", "mystical", "apophatic"]
## Act N (N >= 2) opens only after the threshold of gate N-2 is crossed,
## so the story climbs with the soul.
const GATE_FOR_ACT := {2: "foundational", 3: "liturgical", 4: "ascetic",
	5: "contemplative", 6: "mystical"}
const GATE_TITLE_RU := {
	"foundational": "первый, основание",
	"liturgical": "второй, общий голос",
	"ascetic": "третий, прядь до вечера",
	"contemplative": "четвёртый, мутный кувшин",
	"mystical": "пятый, незажжённая свеча",
	"apophatic": "шестой, без лампы",
}
## Only deeds, never the practices of prayer.  The source is the one the
## rule of ludus-actions.js cites for the same practice.
const PRACTICE_RU := {
	"alms": {"label": "Подать милостыню",
		"after": "Ты отдал без счёта; у ворот стало на одного сытого больше.",
		"source": "Ladder, steps 16-17"},
	"forgive": {"label": "Простить обиду",
		"after": "Обида положена, как тюк у колодца; идти стало легче.",
		"source": "Ladder, steps 8-9"},
	"obedience": {"label": "Исполнить послушание наставника",
		"after": "Ты сделал, как сказали, не споря; дорога стала прямее.",
		"source": "Ladder, step 4"},
	"fast": {"label": "Сохранить сегодняшний пост",
		"after": "Ты ел в свой час и мало и никому об этом не сказал.",
		"source": "Ladder, step 14"},
	# A good deed in secret opens nothing visible: a secret that pays in
	# front of the player feeds vainglory (Mt 6:3-4).
	"secret_deed": {"label": "Сделать доброе тайно",
		"after": "Об этом никто не узнал. И не нужно.", "hidden": true,
		"source": "Ladder, step 22; Mt 6:3-4"},
}
## The passions' own lures in the language of profit (TABOO 0.39).
const LURES := {
	"gluttony": {
		"find": "Сначала поесть: привал рядом, находка подождёт сытого часа.",
		"dive": "Не лезть в холодную воду натощак: погружение подождёт до завтра.",
	},
	"avarice": {
		"find": "Спрятать в пояс: никто не видел, а зимы длинные.",
		"dive": "Нырнуть за блеском раньше других: кто первый, того и серебро.",
	},
	"vainglory": {
		"find": "Отнести находку на базар и рассказать, кто её нашёл.",
		"dive": "Уйти глубже всех, чтобы на пристани запомнили твоё имя.",
	},
	"sadness": {
		"find": "Сесть над находкой и горевать: здесь уже не будет как прежде.",
		"dive": "Не спускаться: всё хорошее давно утонуло.",
	},
	"anger": {
		"find": "Швырнуть находку в воду: это вещь тех, кто тебя обидел.",
		"dive": "Дёрнуть трос со злостью: пусть на лодке знают, что ты недоволен.",
	},
	"pride": {
		"find": "Объявить находку своим открытием: ты нашёл сам, без братии.",
		"dive": "Отстегнуть страховочный конец: ты и без него умеешь.",
	},
	"acedia": {
		"find": "Не наклоняться: день всё равно не кончится, пусть лежит.",
		"dive": "Остаться на берегу: вода та же, что вчера, смысла нет.",
	},
}
## One plan per act of the spine (ACT_PLAN in the JS): the people of the
## talks with their start and "warm" nodes, the real objects of the
## finds and dives, the deeds, and the act's teaching with its source.
const ACT_PLAN := {
	"prologue": {
		"passion": "gluttony",
		"npcs": [["sargis", "scales_greeting", "open_hand"],
			["anahit", "a_gate", "a_first_night"]],
		"finds": ["yakor.shallows.0", "gruzilo.shallows.0"],
		"dives": ["caustics.shallows.0", "spring.shallows.0"],
		"practices": ["obedience", "fast"],
		"intro": "Дорога к озеру: «{title}».",
		"practiceScene": "На привале у колодца наставник даёт тебе дело.",
		"findPlace": "На отмели у брода",
		"meaning": "The road begins by leaving: a stranger on the way learns to depend on God and on the hospitality of others.",
		"source": "Ladder, step 3",
	},
	"trade": {
		"passion": "avarice",
		"npcs": [["sargis", "scales_greeting", "open_hand"],
			["vardan", "v_ledger", "v_marks"], ["melik", "m_scales", "m_weights"],
			["anahit", "a_gate", "a_first_night"], ["khan", "k_start", "k_yasa"],
			["theodora", "greeting", "one_loaf"]],
		"finds": ["khum.shallows.0", "kotel.shallows.0", "bulla.shallows.0",
			"cherepki.shallows.1", "glazur.shallows.0", "zhernov.shallows.0",
			"kayrak.shallows.0"],
		"dives": ["svaya.shallows.2", "karman.shallows.1", "shafts.shallows.0",
			"boulder.shallows.1"],
		"practices": ["alms", "secret_deed", "forgive"],
		"intro": "Караванная дорога: «{title}».",
		"practiceScene": "У ворот каравансарая ждут те, кому нечем платить.",
		"findPlace": "На отмели у пристани фактории",
		"meaning": "A false balance is an abomination to the Lord; honest weights are the first teaching of the road of trade.",
		"source": "Proverbs 11:1",
	},
	"spiritual": {
		"passion": "vainglory",
		"npcs": [["theodora", "greeting", "one_loaf"],
			["kassiani", "k_greeting", "k_song"],
			["ikonopisets", "i_greeting", "i_layers"],
			["abba_moses", "greeting", "cell_teaches"],
			["elder_sergius", "greeting", "still_water"],
			["photius", "library", "margin_art"]],
		"finds": ["glazur.shallows.1", "bulla.shallows.0",
			"fundament.shallows.0", "kirpich.shallows.0"],
		"dives": ["shafts.shallows.1", "terrace.shelf.2", "snow.shelf.0"],
		"practices": ["secret_deed", "obedience", "forgive"],
		"intro": "Знаки в глине и камне: «{title}». На отмели и в скриптории лежат следы тех, кто молился у озера до нас.",
		"practiceScene": "В скриптории брат просит о помощи, пока никто не видит.",
		"findPlace": "На отмели под старой кладкой",
		"meaning": "Signs in clay and stone are honoured for what they point to; the image leads to its prototype and is never a charm.",
		"source": "St John of Damascus, Treatises on the Divine Images",
	},
	"hydrology": {
		"passion": "sadness",
		"npcs": [["rybak_issyk_kul", "greeting", "mending"],
			["elder_sergius", "greeting", "still_water"],
			["abba_john", "greeting", "watch_hand"],
			["tabib", "greeting", "bandage"]],
		"finds": ["svaya.shelf.2", "fundament.shallows.1", "ochag.shallows.0",
			"balka.shallows.0"],
		"dives": ["terrace.slope.2", "thermo.slope.0", "intwave.slope.0",
			"upwelling.slope.0", "slope-edge.slope.2", "silt.slope.0"],
		"practices": ["fast", "alms", "obedience"],
		"intro": "Вода поднимается: «{title}». Что было берегом, стало дном.",
		"practiceScene": "На пристани рыбаки чинят сети после пустого сезона.",
		"findPlace": "Там, где был прежний берег",
		"meaning": "The sea great and wide is full of works made in wisdom; the one who goes down to look sees the Maker in the made.",
		"source": "Psalm 103:24-25 (LXX; 104 in Hebrew numbering)",
	},
	"diplomacy": {
		"passion": "anger",
		"npcs": [["khan", "k_start", "k_yasa"],
			["strazhnik", "gate_watch", "night_watch"],
			["melik", "m_scales", "m_weights"], ["macrina", "greeting", "teaching"],
			["abba_moses", "greeting", "cell_teaches"]],
		"finds": ["bulla.shallows.0", "kosti.shallows.0", "kleshchi.shallows.0",
			"kotel.shallows.0"],
		"dives": ["seiche.shallows.0", "langmuir.shallows.0", "plume.shallows.1",
			"turbid.shallows.0"],
		"practices": ["forgive", "obedience", "alms"],
		"intro": "Ханы и послы: «{title}». У каждого свои весы, а обители нужно слово, которое держит мир.",
		"practiceScene": "Посол ушёл, хлопнув дверью; его люди ещё во дворе.",
		"findPlace": "У брода, где стоят шатры посольства",
		"meaning": "As far as it depends on you, live peaceably with all; the word that keeps peace is weighed before it is spoken.",
		"source": "Romans 12:18",
	},
	"craft": {
		"passion": "pride",
		"npcs": [["sister_catherine", "greeting", "wax_and_flame"],
			["ikonopisets", "i_greeting", "i_layers"],
			["tabib", "greeting", "bandage"],
			["abba_john", "greeting", "watch_hand"],
			["theodora", "greeting", "one_loaf"]],
		"finds": ["kleshchi.shallows.1", "shlak.shallows.0", "zhernov.shallows.1",
			"kirpich.shallows.0", "khum.shallows.1"],
		"dives": ["clay.shelf.0", "gravel.shallows.0", "sandstone.shallows.0",
			"bubbles.shelf.1"],
		"practices": ["obedience", "secret_deed", "fast"],
		"intro": "Мастерская обители: «{title}». Руки заняты, язык молчит, дело учит.",
		"practiceScene": "Мастер просит сделать работу так, как он велел.",
		"findPlace": "У старой кузни на отмели",
		"meaning": "The work of the hands keeps the heart from despondency; the elders plaited rope and prayed.",
		"source": "Apophthegmata Patrum, alphabetical collection, Antony the Great 1",
	},
	"narrative": {
		"passion": "acedia",
		"npcs": [["vardan", "v_ledger", "v_marks"],
			["photius", "library", "margin_art"],
			["rybak_issyk_kul", "greeting", "mending"],
			["elder_sergius", "greeting", "still_water"],
			["macrina", "greeting", "teaching"],
			["kassiani", "k_greeting", "k_song"]],
		"finds": ["svaya.shelf.2", "bulla.shallows.0", "ochag.shallows.0",
			"balka.shallows.0"],
		"dives": ["terrace.slope.2", "slope-edge.slope.0", "thermo.slope.2",
			"silt.slope.0"],
		"practices": ["forgive", "secret_deed", "alms"],
		"intro": "Камень под водой: «{title}». Книга находок почти дописана.",
		"practiceScene": "Перед тем как закрыть книгу, надо уладить старое.",
		"findPlace": "На старой береговой террасе",
		"meaning": "A thousand years are as yesterday; what the water keeps is kept for memory, not for gain.",
		"source": "Psalm 89:4 (LXX; 90:4 in Hebrew numbering)",
	},
}
## Short openings for the prologue and Act I, written from the titles of
## the spine.  Later acts use the act's own opening line.
const INTRO := {
	1: "Обитель у озера принимает караван на ночь. Саргис считает верблюдов, Анаит топит тонир; тебе велено помочь у ворот.",
	3: "Двое купцов спорят о весе тюка и зовут епископа рассудить. Пока он в пути, тебя просят приготовить вещи, свидетелей и книгу.",
	2: "Армянская фактория на берегу: склады, писцовая, весы. В книге прихода не сходится столбец.",
	4: "Хан обещает защиту дороги тем, кто держит честные весы. Обители предлагают стать свидетелем договора.",
	5: "Погонщик просит зерна в долг до осени, залога у него нет. Решать будут по слову, а не по серебру.",
	6: "Хлеб и воду надо развезти по трём стоянкам вдоль берега. Верблюдов мало, дорога длинная.",
	7: "Генуэзцы из Таны и армянские купцы договариваются о пути. Им нужен человек, которому верят обе стороны.",
	8: "На базаре ссора из-за подпиленной гири. Тебя зовут не судить, а помочь сверить меру.",
	9: "Караван везёт зерно в голодное селение за перевалом. Груз даровой, и потому его особенно хочется пересчитать.",
	10: "Мелик собирает пошлину; рыбаки просят отсрочки после пустого сезона. Тебя просят передать их слова.",
	11: "Обитель ведёт счёт своим амбарам: где хлеб лежит без дела, а где его не хватает.",
	12: "Шёлковый караван оставляет тюки на хранение, и купцы спрашивают, можно ли доверить тебе ключ.",
	13: "Купцы разных земель собираются у каравансарая решить спор о дороге. Речь у них торопливая, а слово должно быть взвешенным.",
	15: "Караванщики договариваются помогать друг другу в пути: колодцы, запасные верблюды, общий кров. Нужен тот, кто запишет устав.",
}
const KIND_RU := {"find": "находка", "practice": "дело",
	"dialogue": "разговор", "dive": "погружение"}
const STEP_ORDER := ["find", "practice", "dialogue", "dive"]
const CLOSED_RU := {
	"deep": "глубокие ответы (сверка, запись, спуск по открытому пути)",
	"road": "дорога к следующей миссии",
}
## Physics of the lake (TABOO 0.35 rule 19).
const SOUND_M_S := 1480.0
const BAR_PER_M := 1.0 / 10.2
const SURFACE_BAR := 1.01325
## As in ludus-game.js: FORM never grows past 20.
const ATTR_MAX := 20


# --- Data -------------------------------------------------------------------

## The spine's ids come from JSON as floats; they are kept as ints here,
## with lookups the rules need often.
static func load_data() -> Dictionary:
	var read := func(name: String):
		return JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/" + name))
	var spine: Dictionary = read.call("campaign-spine.json")
	var acts := []
	for a in spine.acts:
		var ids := []
		for id in a.missions:
			ids.append(int(id))
		acts.append({"id": a.id, "title_ru": a.title_ru, "missions": ids})
	var titles := {}
	for m in spine.missions:
		titles[int(m.id)] = m.title
	var chorus := {}
	for m in spine.get("needsChorusRewrite", []):
		chorus[int(m.id)] = true
	var order := []
	for id in spine.order:
		order.append(int(id))
	var lake := {}
	for o in read.call("lake-objects-99.json").objects:
		lake[o.id] = o
	return {"acts": acts, "titles": titles, "chorus": chorus, "order": order,
		"trees": read.call("dialogue-trees.json").trees, "lake": lake,
		"passions": read.call("passions.json")}


# --- State ------------------------------------------------------------------

## The state of the campaign.  trials, trial_wait and fall are TrialCore's
## (one state in the web game); the hub keeps them there.
static func empty_state() -> Dictionary:
	return {"done": {}, "current": null, "flags": {}, "lines": {},
		"trials": {}, "trial_wait": {}, "fall": null}


static func _num(v) -> float:
	var x := 0.0
	if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
		x = float(v)
	elif typeof(v) == TYPE_STRING and v.is_valid_float():
		x = float(v)
	return x if is_finite(x) and x > 0.0 else 0.0


## An id as JS would print it: 12 and 12.0 both give "12".
static func _id_str(v) -> String:
	if typeof(v) == TYPE_INT:
		return str(v)
	if typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v):
		return str(int(v))
	return str(v)


## A number as JS prints it in a template: no ".0" on whole numbers.
static func js_num(v) -> String:
	var x := float(v)
	if x == floorf(x) and absf(x) < 1e15:
		return str(int(x))
	return str(x)


## String(value || '') in JS: falsy values give "", numbers print as JS.
static func _js_text(v) -> String:
	if v == null or (v is bool and not v) or (v is String and v == ""):
		return ""
	if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
		return "" if float(v) == 0.0 else js_num(v)
	return str(v)


static func _re(pattern: String) -> RegEx:
	return RegEx.create_from_string(pattern)


## Keep only known shapes from storage, so a hand-edited record cannot
## smuggle in counters or a fall that cannot be lifted.
static func normalize_state(raw) -> Dictionary:
	var src: Dictionary = raw if raw is Dictionary else {}
	var st := empty_state()
	var id_re := _re("^\\d{1,3}$")
	var done = src.get("done")
	if done is Dictionary:
		for id in done:
			if id_re.search(_id_str(id)) and done[id] is bool and done[id]:
				st.done[_id_str(id)] = true
	var flags = src.get("flags")
	if flags is Dictionary:
		var flag_re := _re("^[a-z0-9_.:-]{1,60}$")
		for id in flags:
			if flag_re.search(str(id)) and flags[id] is bool and flags[id]:
				st.flags[str(id)] = true
	var lines = src.get("lines")
	if lines is Dictionary:
		var word := _re("^[a-z_]{1,40}$")
		for npc in lines:
			if word.search(str(npc)) and word.search(str(lines[npc])):
				st.lines[str(npc)] = str(lines[npc])
	var trials = src.get("trials")
	var wait = src.get("trial_wait")
	for g in GATE_IDS:
		if trials is Dictionary and trials.get(g) is bool and trials[g]:
			st.trials[g] = true
		if wait is Dictionary and wait.has(g) \
				and typeof(wait[g]) in [TYPE_INT, TYPE_FLOAT] \
				and is_finite(float(wait[g])):
			st.trial_wait[g] = floori(_num(wait[g]))
	var cur = src.get("current")
	if cur is Dictionary and id_re.search(_id_str(cur.get("id"))):
		var scene = null
		var sc = cur.get("scene")
		if sc is Dictionary:
			scene = {}
			for k in ["text", "speaker", "source", "meaning", "choice"]:
				scene[k] = _js_text(sc.get(k))
		st.current = {"id": int(_id_str(cur.id)),
			"step": maxi(0, floori(_num(cur.get("step")))), "scene": scene}
	var f = src.get("fall")
	if f is Dictionary and LURES.has(f.get("passion")):
		var teacher := str(f.get("teacher"))
		var since = f.get("since")
		if not since is Dictionary:
			since = {}
		st.fall = {"passion": f.passion,
			"teacher": teacher if _re("^[a-z_]{1,40}$").search(teacher)
				else "elder_sergius",
			"closed": ["deep", "road"],
			"since": {"sobriety": floori(_num(since.get("sobriety"))),
				"met": floori(_num(since.get("met")))}}
	return st


# --- The campaign -----------------------------------------------------------

static func act_of(data: Dictionary, mission_id: int) -> int:
	for i in data.acts.size():
		if mission_id in data.acts[i].missions:
			return i
	return -1


static func title_of(data: Dictionary, mission_id: int) -> String:
	return data.titles.get(mission_id, str(mission_id))


static func _done(st: Dictionary, id: int) -> bool:
	return st.done.get(str(id), false)


## The deterministic shape of one mission: which person, which object,
## which deed and which dive.  Neighbours in an act differ because each
## pool is walked by the mission's place in the act.
static func build_mission(data: Dictionary, mission_id: int) -> Dictionary:
	var ai := act_of(data, mission_id)
	if ai < 0:
		return {}
	var act: Dictionary = data.acts[ai]
	var plan: Dictionary = ACT_PLAN[act.id]
	var pos: int = act.missions.find(mission_id)
	var title := title_of(data, mission_id)
	var pick := func(pool: Array):
		return pool[pos % pool.size()]
	var who: Array = pick.call(plan.npcs)
	return {
		"id": mission_id,
		"title": title,
		"actIndex": ai,
		"actId": act.id,
		"actTitle": act.title_ru,
		"chorus": data.chorus.has(mission_id),
		"intro": INTRO.get(mission_id,
			plan.intro.replace("{title}", title)),
		"meaning": plan.meaning,
		"source": plan.source,
		"passion": plan.passion,
		# The FORM threshold of the deep answers grows with the act; a
		# guest (1 in every attribute) can reach the first ones.
		"depthNeed": 1 + ai * 2,
		# Growth inside a mission stops two above the gate of the act, so
		# walking many missions cannot replace understanding.
		"ceiling": 4 + ai * 2,
		"steps": [
			{"kind": "find", "object": pick.call(plan.finds),
				"place": plan.findPlace},
			{"kind": "practice", "practice": pick.call(plan.practices),
				"scene": plan.practiceScene},
			{"kind": "dialogue", "npc": who[0], "node": who[1],
				"warm": who[2]},
			{"kind": "dive", "object": pick.call(plan.dives)},
		],
	}


static func act_complete(data: Dictionary, st: Dictionary, ai: int) -> bool:
	for id in data.acts[ai].missions:
		if not data.chorus.has(id) and not _done(st, id):
			return false
	return true


static func gate_title(gate_id: String) -> String:
	return GATE_TITLE_RU.get(gate_id, gate_id)


## Why an act is closed, or "" when it is open.
static func act_lock(data: Dictionary, st: Dictionary, ai: int) -> String:
	if ai == 0:
		return ""
	if not act_complete(data, st, ai - 1):
		return "Сначала пройди: " + data.acts[ai - 1].title_ru
	var gate: String = GATE_FOR_ACT.get(ai, "")
	if gate != "" and not st.trials.get(gate, false):
		return "Нужен порог: " + gate_title(gate)
	return ""


## The next mission to walk: the first unfinished, runnable mission of
## the first act that is not complete (-1 when none).
static func next_mission(data: Dictionary, st: Dictionary) -> int:
	for i in data.acts.size():
		if act_complete(data, st, i):
			continue
		if act_lock(data, st, i) != "":
			return -1
		for id in data.acts[i].missions:
			if not data.chorus.has(id) and not _done(st, id):
				return id
		return -1
	return -1


## Every act with its lock and the status of each mission: done,
## current, next, locked (ahead) or chorus (on rewrite, never runs).
static func catalog(data: Dictionary, st: Dictionary) -> Array:
	var nxt := next_mission(data, st)
	var out := []
	for i in data.acts.size():
		var act: Dictionary = data.acts[i]
		var ms := []
		for id in act.missions:
			var status := "locked"
			if data.chorus.has(id):
				status = "chorus"
			elif _done(st, id):
				status = "done"
			elif st.current != null and st.current.id == id:
				status = "current"
			elif id == nxt:
				status = "next"
			ms.append({"id": id, "title": title_of(data, id),
				"status": status})
		out.append({"id": act.id, "title": act.title_ru,
			"lock": act_lock(data, st, i),
			"complete": act_complete(data, st, i), "missions": ms})
	return out


static func can_start(data: Dictionary, st: Dictionary,
		mission_id: int) -> Dictionary:
	if data.chorus.has(mission_id):
		return {"ok": false, "reason": "на переписке у хора"}
	if st.current != null:
		return {"ok": false, "reason": "Сначала закончи начатую миссию."}
	if st.fall != null:
		return {"ok": false,
			"reason": "Дорога закрыта, пока свет не вернётся."}
	if next_mission(data, st) != mission_id:
		return {"ok": false, "reason": "Эта миссия ещё впереди."}
	return {"ok": true, "reason": ""}


static func start(data: Dictionary, state: Dictionary,
		mission_id: int) -> Dictionary:
	var st := normalize_state(state)
	if can_start(data, st, mission_id).ok:
		st.current = {"id": mission_id, "step": 0, "scene": null}
	return st


# --- Steps ------------------------------------------------------------------

## Bonuses: only the seven attributes, whole numbers 1..5.
static func clean_bonuses(raw) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	for k in ATTRS:
		var v := floori(_num(raw.get(k)))
		if v > 0:
			out[k] = mini(5, v)
	return out


static func cap_bonuses(bonuses: Dictionary, form: Dictionary,
		ceiling: int) -> Dictionary:
	var out := {}
	for k in bonuses:
		var room := float(ceiling) - _num(form.get(k))
		if room > 0.0:
			out[k] = mini(int(bonuses[k]), floori(room))
	return out


static func meets_condition(cond, form: Dictionary) -> bool:
	if not cond is Dictionary:
		return true
	for k in cond:
		if not k in ATTRS or _num(form.get(k)) < _num(cond[k]):
			return false
	return true


## The sign of a passion is shown under its lure once the player has
## sat with the teacher who teaches it, or understands enough to name it.
static func _lure_choice(data: Dictionary, mission: Dictionary, kind: String,
		form: Dictionary, actions: Dictionary) -> Dictionary:
	var p := TrialCore.passion_of(data, mission.passion)
	var met: Dictionary = actions.get("met", {})
	var taught := not p.is_empty() and (_num(met.get(p.teacher)) > 0.0
		or _num(form.get("wisdom")) >= _num(p.get("wisdomToName")))
	return {"id": "lure", "text": LURES[mission.passion][kind],
		"lure": true, "disabled": false, "reason": "",
		"cue": "Признак: " + p.cue_ru if taught else ""}


static func tree_node(data: Dictionary, npc: String, node_id) -> Dictionary:
	var tree: Dictionary = data.trees.get(npc, {})
	if tree.is_empty():
		return {}
	for n in tree.nodes:
		if n.id == node_id:
			return n
	for n in tree.nodes:
		if n.id == tree.startNode:
			return n
	return {}


static func pressure_bar(depth: float) -> String:
	return "%.2f" % (SURFACE_BAR + depth * BAR_PER_M)


static func echo_ms(depth: float) -> float:
	return roundf((2.0 * depth / SOUND_M_S) * 1000.0 * 10.0) / 10.0


static func _choice(id: String, text: String, extra := {}) -> Dictionary:
	var c := {"id": id, "text": text, "disabled": false, "reason": "",
		"cue": ""}
	c.merge(extra, true)
	return c


static func step_view(data: Dictionary, st: Dictionary, mission: Dictionary,
		index: int, form: Dictionary, actions: Dictionary) -> Dictionary:
	var step: Dictionary = mission.steps[index]
	var deep_closed: bool = st.fall != null
	var closed_note := "Путь закрыт, пока свет не вернётся."
	var need: int = mission.depthNeed
	match step.kind:
		"find":
			var obj: Dictionary = data.lake.get(step.object, {})
			var handover: bool = not obj.is_empty() \
				and obj.get("flags", {}).get("loot") == "hand-over"
			return {"kind": "find", "title": "Находка",
				"text": "%s: %s." % [step.place,
					obj.ru if not obj.is_empty() else step.object],
				"meaning": "What is found belongs to its owner and to memory; it is returned, never kept as loot.",
				"source": "Deuteronomy 22:1-3",
				"choices": [
					_choice("handover", "Передать находку в книгу обители."
						if handover
						else "Оставить на месте и записать, где лежит."),
					_choice("note", "Отметить место и идти дальше."),
					_choice("deep", "Сверить находку с летописью фактории.",
						{"deep": true, "disabled": deep_closed
							or _num(form.get("erudition")) < need,
						"reason": closed_note if deep_closed
							else "Нужна Erudition %d." % need}),
					_lure_choice(data, mission, "find", form, actions),
				]}
		"practice":
			var pr: Dictionary = PRACTICE_RU[step.practice]
			return {"kind": "practice", "title": "Дело", "text": step.scene,
				"meaning": "A deed of the rule answers a passion; it is done, not paid for.",
				"source": pr.source,
				"choices": [_choice("keep", pr.label + "."),
					_choice("later", "Отложить: дорога торопит.")]}
		"dialogue":
			var tree: Dictionary = data.trees.get(step.npc, {})
			var node_id: String = st.lines.get(step.npc, step.node)
			var node := tree_node(data, step.npc, node_id)
			var choices := []
			var any_open := false
			var branches: Array = node.get("branches", [])
			for i in branches.size():
				var b: Dictionary = branches[i]
				var cond = b.get("condition")
				var reason := ""
				if cond is Dictionary:
					var need_s := []
					for k in cond:
						need_s.append("%s %s" % [k, js_num(cond[k])])
					reason = "Нужно: " + ", ".join(need_s)
				var dis := not meets_condition(cond, form)
				any_open = any_open or not dis
				var text = b.get("text_ru")
				choices.append(_choice("b%d" % i, str(text if text != null
					and text != "" else b.get("text")),
					{"disabled": dis, "reason": reason}))
			if not any_open:
				choices.append(_choice("bow", "Молча поклониться и выйти."))
			var name: String = tree.get("npcName_ru", step.npc)
			return {"kind": "dialogue", "title": "Разговор: " + name,
				"speaker": name, "npc": step.npc,
				"node": node.get("id", node_id),
				"text": node.get("text_ru", ""),
				"voice": node.get("voice", ""),
				"meaning": node.get("meaning", ""),
				"source": node.get("source", ""), "choices": choices}
	var obj: Dictionary = data.lake.get(step.object, {})
	var depth: float = float(obj.depth[1]) if not obj.is_empty() else 5.0
	var path_flag := "m%d.kept" % mission.id
	return {"kind": "dive", "title": "Погружение",
		"text": "ROV уходит на %s м: давление %s бар, эхо от дна вернётся через %s мс. Внизу: %s." % [
			js_num(depth), pressure_bar(depth), js_num(echo_ms(depth)),
			obj.ru if not obj.is_empty() else step.object],
		"meaning": "The creatures of the deep are works made in wisdom; the one who descends slowly sees them.",
		"source": "Psalm 103:24-25 (LXX; 104 in Hebrew numbering)",
		"choices": [
			_choice("rope", "Спускаться по тросу медленно и слушать эхо."),
			_choice("record", "Задержаться у дна и записать, что видишь.",
				{"deep": true, "disabled": deep_closed
					or _num(form.get("wisdom")) < need,
				"reason": closed_note if deep_closed
					else "Нужна Wisdom %d." % need}),
			_choice("path", "Спуститься туда, куда открыл путь сделанный долг.",
				{"deep": true, "disabled": deep_closed
					or not st.flags.get(path_flag, false),
				"reason": closed_note if deep_closed
					else "Путь открывает сделанное в этой миссии дело."}),
			_lure_choice(data, mission, "dive", form, actions),
		]}


## What the player sees now: the current step, or the scene a choice
## produced (with a press to walk on).  Empty when no mission runs.
static func view(data: Dictionary, state: Dictionary, form: Dictionary,
		actions: Dictionary) -> Dictionary:
	var st := normalize_state(state)
	if st.current == null:
		return {}
	var mission := build_mission(data, st.current.id)
	var index: int = mini(st.current.step, mission.steps.size() - 1)
	return {"mission": mission, "index": index,
		"total": mission.steps.size(),
		"kind_ru": KIND_RU[mission.steps[index].kind],
		"step": step_view(data, st, mission, index, form, actions),
		"scene": st.current.scene,
		"last": index == mission.steps.size() - 1}


## Take one choice of the current step.  Returns the new state and the
## effects the game must apply (bonuses, a meeting, a practice, a fall).
static func choose(data: Dictionary, state: Dictionary, choice_id: String,
		form: Dictionary, actions: Dictionary) -> Dictionary:
	var st := normalize_state(state)
	var effects := {"bonuses": {}, "meet": null, "practice": null,
		"fall": null, "opens": null, "line": null}
	var v := view(data, st, form, actions)
	if v.is_empty() or v.scene != null:
		return {"state": st, "effects": effects}
	var choice := {}
	for c in v.step.choices:
		if c.id == choice_id:
			choice = c
	if choice.is_empty() or choice.disabled:
		return {"state": st, "effects": effects}
	var mission: Dictionary = v.mission
	var step: Dictionary = mission.steps[v.index]
	var scene := {"text": "", "speaker": "", "source": "", "meaning": "",
		"choice": choice.text}
	if choice.get("lure", false):
		TrialCore._fall_into(data, st, mission.passion, actions)
		effects.fall = mission.passion
		var p := TrialCore.passion_of(data, mission.passion)
		scene.text = "Помысел (%s) взял своё. Свет вокруг потускнел, и два пути закрылись: %s и %s. Их открывает трезвение и разговор с наставником." % [
			p.get("name_ru", mission.passion), CLOSED_RU.deep, CLOSED_RU.road]
		scene.source = p.get("ladder", "")
	elif step.kind == "find":
		var obj: Dictionary = data.lake.get(step.object, {})
		var name: String = obj.ru.split(":")[0] if not obj.is_empty() \
			else step.object
		if choice_id == "handover":
			# An honest find pays in trust, not in points: the person of
			# this mission starts from their "warm" node.
			var talk: Dictionary = mission.steps[2]
			st.lines[talk.npc] = talk.warm
			effects.line = {"npc": talk.npc, "node": talk.warm}
			scene.text = "%s записан в книгу находок с местом и глубиной. Весть о честной находке ушла вперёд тебя." % name
		elif choice_id == "note":
			scene.text = "Ты отметил место камнем и пошёл дальше. %s остался лежать, как лежал." % name
		else:
			effects.bonuses = {"erudition": 2}
			scene.text = "В летописи фактории нашлась строка о таком же: %s. Находка встала на своё место в истории берега." % name
		scene.source = v.step.source
	elif step.kind == "practice":
		var pr: Dictionary = PRACTICE_RU[step.practice]
		if choice_id == "keep":
			effects.practice = step.practice
			if not pr.get("hidden", false):
				var flag := "m%d.kept" % mission.id
				st.flags[flag] = true
				effects.opens = flag
			scene.text = pr.after
		else:
			scene.text = "Дело осталось несделанным. Дорога за это не наказывает, но и нового пути не открывает."
		scene.source = v.step.source
	elif step.kind == "dialogue":
		effects.meet = step.npc
		var node := tree_node(data, step.npc, v.step.node)
		var branch := {}
		if choice_id != "bow":
			branch = node.branches[int(choice_id.substr(1))]
		effects.bonuses = clean_bonuses(branch.get("attributeBonuses"))
		var nxt = branch.get("nextNodeId")
		var reply := {}
		if nxt != null and nxt != "":
			reply = tree_node(data, step.npc, nxt)
		scene.speaker = v.step.speaker
		if not reply.is_empty() and reply.id == nxt:
			scene.text = reply.text_ru
			scene.source = reply.source
			scene.meaning = reply.meaning
		else:
			scene.text = "%s молча кивает." % v.step.speaker
			scene.source = v.step.source
			scene.meaning = v.step.meaning
	else:
		var obj: Dictionary = data.lake.get(step.object, {})
		var depth := js_num(obj.depth[1] if not obj.is_empty() else 5)
		var what: String = obj.ru if not obj.is_empty() else step.object
		if choice_id == "rope":
			scene.text = "Медленно, по тросу, до %s м. %s. Всплытие — не быстрее 10 м/мин." % [depth, what]
		elif choice_id == "record":
			effects.bonuses = {"wisdom": 1}
			scene.text = "%s: записано с глубиной %s м и давлением %s бар. Запись пойдёт в книгу обители. Всплытие — не быстрее 10 м/мин." % [
				what, depth, pressure_bar(float(depth))]
		else:
			effects.bonuses = {"constitution": 2}
			scene.text = "Сделанное дело открыло спуск дальше: у %s видно то, чего не видно с тропы. Всплытие — не быстрее 10 м/мин." % what
		scene.source = v.step.source
	effects.bonuses = cap_bonuses(effects.bonuses, form, mission.ceiling)
	st.current.scene = scene
	return {"state": st, "effects": effects}


## Walk on after a scene.  The last step completes the mission.
static func advance(data: Dictionary, state: Dictionary) -> Dictionary:
	var st := normalize_state(state)
	if st.current == null or st.current.scene == null:
		return {"state": st, "completed": null}
	var mission := build_mission(data, st.current.id)
	if st.current.step + 1 >= mission.steps.size():
		st.done[str(mission.id)] = true
		st.current = null
		return {"state": st, "completed": mission.id}
	st.current.step += 1
	st.current.scene = null
	return {"state": st, "completed": null}


# --- The fall and the rule --------------------------------------------------

static func fall_status(data: Dictionary, state: Dictionary,
		actions: Dictionary) -> Dictionary:
	return TrialCore.fall_status(data, normalize_state(state), actions)


static func lift_fall(data: Dictionary, state: Dictionary,
		actions: Dictionary) -> Dictionary:
	return TrialCore.lift_fall(data, normalize_state(state), actions)


## One deed of the rule, as doPractice in ludus-actions.js for the five
## deeds a mission can ask: the fast is the legacy counter of gate 3,
## the others are daily practices counted once per calendar day.
static func do_practice(actions: Dictionary, id: String,
		iso_day: String) -> Dictionary:
	if id == "fast":
		return HubCore.keep_fast(actions, iso_day)
	var n := actions.duplicate(true)
	if not PRACTICE_RU.has(id) \
			or not _re("^\\d{4}-\\d{2}-\\d{2}$").search(iso_day):
		return n
	if not n.get("practices") is Dictionary:
		n.practices = {}
	var item: Dictionary = n.practices.get(id, {"count": 0, "lastDay": null})
	if item.get("lastDay") == iso_day:
		return n
	n.practices[id] = {"count": int(item.get("count", 0)) + 1,
		"lastDay": iso_day}
	return n


## Apply the effects of a choice the way ludus-game.js does: the meeting,
## then the deed, then the bonuses (FORM never past 20).
static func apply_effects(form: Dictionary, actions: Dictionary,
		effects: Dictionary, iso_day: String) -> Dictionary:
	var a := actions
	var f := form.duplicate()
	if effects.meet != null:
		a = HubCore.record_meeting(a, effects.meet)
	if effects.practice != null:
		a = do_practice(a, effects.practice, iso_day)
	for k in effects.bonuses:
		f[k] = mini(ATTR_MAX, int(f.get(k, 0)) + int(effects.bonuses[k]))
	return {"form": f, "actions": a}
