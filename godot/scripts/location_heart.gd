## The heart of a location: the one practice or action at its centre
## (CLAUDE.md TABOO 0.013 item 1), as a birch-bark panel of the hub's
## kind.  The rules are the game's own tested cores; this file only
## words the panel and routes a choice to them, so a talk in a place is
## the hub's talk, a deed is MissionCore's deed, a threshold is
## TrialCore's, a thought on the road is PassionCore's, the evening watch
## is RuleCell's panel, the chronicle and the scribe are AtlasTraces'.
##
## A panel is a Dictionary {kind, choice, reply, ...}; the player's state
## st is {form, actions, trials, passions, chronicle, atlas_given, day}
## (LocationCore.read_state).  open, choose and tick return {panel, st,
## say, scene, save}: panel {} closes it, scene asks the place to change
## scene, save asks it to write st.  Nothing here reads a clock or draws
## a random number: the day comes in st.day and time in tick's dt.
##
## The shore of Svetloyar is listened to and records nothing (Kiberslav
## node 76).  The 23 new small actions of the places (docs/LOCATIONS_99_SELECTION,
## "Сердца", HLD phase L3) have no logic yet: their panel names the
## action and its teaching, and doing it counts nothing and pays nothing.
## Prayer never pays (TABOO 0.35 rule 16): a practice changes a counter
## that is only shown, never FORM.  The witness's line records nothing
## (TABOO 0.26 point 10).
class_name LocationHeart
extends RefCounted

const STILL_BREATH_SECONDS := 5.0
const AWAY := {"id": "away", "text": "Отойти", "disabled": false,
	"reason": ""}
## Practices done by standing still: moving starts the count again.
const STILL_PRACTICES := ["stillness", "vigil"]
## The shore of Svetloyar (Kiberslav node 76): the lake is listened to
## by one who stands still, for this long; then the shore is quiet.
## Nothing is counted, paid, saved or said as done: no marker, no
## reward, no record.
const LISTEN_SECONDS := 60.0


## What the hearts read, loaded once per place.
static func context() -> Dictionary:
	var lake := {}
	for o in _json("res://data/lake-objects-99.json").objects:
		lake[o.id] = o
	var passions: Dictionary = _json("res://data/passions.json")
	return {"trees": _json("res://data/dialogue-trees.json").trees,
		"trial_data": TrialCore.load_data(), "passion_data": passions,
		"manifest": _json("res://data/antagonist-manifest.json").manifest,
		"atlas": AtlasCore.load_data(), "lake": lake}


static func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## The panel kind of a heart spec.
static func kind_of(h: Dictionary) -> String:
	match h.get("core", ""):
		"MissionCore":
			return {"dialogue": "talk", "practice": "deed",
				"find": "find"}.get(h.get("step", ""), "new")
		"RuleCore":
			return "watch" if h.id == RuleCell.WATCH_ID else "rule"
		"TrialCore":
			return "trial"
		"PassionCore":
			return "passion"
		"DiveCore":
			return "dive"
		"AtlasTraces":
			return "atlas-" + str(h.id)
		"WitnessCore":
			return "witness"
		"listen":
			return "listen"
	return "new"


## The teaching of a place as a line for the panel: the data's lesson
## without the notes for the editors ("(узел 5)", "(ТАБУ …)"); a verse
## of Scripture in brackets stays.
static func teaching(loc: Dictionary) -> String:
	var re := RegEx.create_from_string(
		"\\s*\\((?:ТАБУ|узел|узлы|узлов)[^)]*\\)")
	return re.sub(str(loc.get("lesson", "")), "", true).strip_edges()


## A practice's source as the headset shows it: the rule's sources are
## kept in English for the JS reference; the panel names them in Russian,
## as the evening watch does ("Лествица, слова 15 и 26").
static func source_ru(src: String) -> String:
	var out := src
	for pair in [["Apophthegmata, Antony the Great 1",
				"Достопамятные сказания, Антоний Великий, 1"],
			["St John Chrysostom", "Иоанн Златоуст"],
			["Ladder, steps ", "Лествица, слова "],
			["Ladder, step ", "Лествица, слово "],
			[" and ", " и "], ["Mt ", "Мф "]]:
		out = out.replace(pair[0], pair[1])
	return out


static func _result(p: Dictionary, st: Dictionary, say := "",
		save := false, scene := "") -> Dictionary:
	return {"panel": p, "st": st, "say": say, "save": save, "scene": scene}


static func open(loc: Dictionary, st: Dictionary,
		ctx: Dictionary) -> Dictionary:
	var h: Dictionary = loc.heart
	var p := {"kind": kind_of(h), "choice": 0, "reply": ""}
	var s := st.duplicate(true)
	match p.kind:
		"talk":
			var tree: Dictionary = ctx.trees[h.npc]
			p["node"] = HubCore.node_of(tree, h.node)
			# As in the hub: a talk begun is a meeting.
			s.actions = HubCore.record_meeting(s.actions, h.npc)
			return _result(p, s, "", true)
		"rule":
			p["timer"] = -1.0
		"passion":
			p["enc"] = PassionCore.start(_passion(ctx, h.id))
			p["still"] = -1.0
		"listen":
			p["still"] = -1.0
			p["heard"] = false
	return _result(p, s)


static func _passion(ctx: Dictionary, id) -> Dictionary:
	for q in ctx.passion_data.passions:
		if q.id == id:
			return q
	return {}


static func _trace(ctx: Dictionary, id) -> Dictionary:
	for t in ctx.atlas.traces:
		if t.id == id:
			return t
	return {}


static func _task(id) -> Dictionary:
	for t in DiveCore.TASKS:
		if t.id == id:
			return t
	return {}


static func _mm_ss(sec: float) -> String:
	var n := ceili(maxf(0.0, sec))
	return "%d:%02d" % [n / 60, n % 60]


## What is still missing at a gate, in the words of the hub's ladder.
static func _missing_ru(c: Dictionary, gate: Dictionary) -> String:
	var need := []
	for m in c.missing:
		match m:
			"form":
				need.append("мудрость %d" % gate.wisdom)
			"dialogue":
				need.append("беседа с наставником")
			"rite":
				need.append("%d/%d %s" % [c.rite.have, c.rite.need, c.rite.ru])
			"gift":
				need.append("поклон «не мне» у лестницы врат")
			"ladder":
				need.append("сперва нижняя ступень")
	return ", ".join(need)


## The panel's lines, before its choices.
static func lines(p: Dictionary, loc: Dictionary, st: Dictionary,
		ctx: Dictionary) -> Array:
	var h: Dictionary = loc.heart
	var out := []
	match p.kind:
		"talk":
			out = [LocationCore.person_of(h) + ":",
				str(p.node.get("text_ru", p.node.get("text", ""))), ""]
		"deed":
			var pr: Dictionary = MissionCore.PRACTICE_RU[h.id]
			out = [pr.label, "", teaching(loc),
				"Источник: " + source_ru(pr.source)]
			var tally := RuleCore.practice_tally(st.actions, h.id)
			if tally.get("shown", false):
				out.append("Сделано: " + tally.text_ru)
			out.append("")
		"rule":
			var pr := RuleCore.practice(h.id)
			out = [pr.ru, "", teaching(loc),
				"Источник: " + source_ru(pr.source)]
			var tally := RuleCore.practice_tally(st.actions, h.id)
			if tally.get("shown", false):
				out.append("Счёт: " + tally.text_ru)
			if p.timer >= 0.0:
				out.append("Идёт: осталось %s%s" % [_mm_ss(p.timer),
					" — стой, не двигаясь" if h.id in STILL_PRACTICES
						else ""])
			out.append("")
		"watch":
			var fs := TrialCore.fall_status(ctx.trial_data, st.trials,
				st.actions)
			var tree: Dictionary = ctx.trees.get(fs.get("teacher", ""), {})
			return RuleCell.watch_lines(st.actions, st.day, fs,
				tree.get("npcName_ru", fs.get("teacher", "")))
		"trial":
			var tv := TrialCore.trial_view(ctx.trial_data, st.trials, h.id,
				st.form, st.actions)
			var tr: Dictionary = tv.trial
			out = [tr.title_ru, "", tr.scene_ru, ""]
			var fs := TrialCore.fall_status(ctx.trial_data, st.trials,
				st.actions)
			if p.reply != "":
				out += [p.reply, ""]
			elif fs.fallen:
				out += ["Свет потускнел: %s. Сначала трезвение и беседа с наставником." % fs.passion_ru, ""]
			elif tv.passed:
				out += ["Этот порог пройден.", ""]
			elif not tv.open:
				var ladder := HubCore.evaluate_ladder(st.form, st.actions)
				var i := TrialCore.GATE_IDS.find(h.id)
				out += ["Порог ещё закрыт: " + _missing_ru(ladder[i],
					HubCore.GATES[i]) + ".", ""]
			elif tv.waiting:
				out += ["У порога ждут: сперва вернись к наставнику и поговори.",
					""]
		"passion":
			var q := _passion(ctx, h.id)
			out = ["На дороге: " + str(q.name_ru), "", str(q.lure_ru), ""]
			match p.enc.stage:
				"virtue":
					out += ["Помысел прошёл. %s — %s; %s." % [q.virtue_ru,
						q.source, q.ladder], ""]
				"captive":
					out += ["Он повёл тебя. Он вернётся; наставники научат его признаку.",
						""]
				_:
					if p.still >= 0.0:
						out += ["Помолчи… %d с" % ceili(p.still), ""]
		"dive":
			out = [_task(h.id).get("ru", ""), "", teaching(loc), "",
				"Задача решается в погружении: аппарат ждёт у пристани обители.",
				""]
		"find":
			var o: Dictionary = ctx.lake.get(h.object, {})
			out = ["Находка: " + str(o.get("ru", h.object)), "",
				teaching(loc), ""]
			if p.reply != "":
				out += [p.reply, ""]
		"atlas-trace":
			var tr := _trace(ctx, h.trace)
			out = [str(tr.ru), "", teaching(loc), ""]
			if p.reply != "":
				out += [p.reply, ""]
		"atlas-chronicle":
			out = ["Летопись обители", "", ctx.atlas.chronicle.scene_ru, ""]
			var o := AtlasTraces.option(ctx.atlas, st.chronicle)
			if not o.is_empty():
				out += [o.written_ru, ""]
		"atlas-scribe":
			var page := AtlasTraces.scribe_page(ctx.atlas, st.atlas_given)
			out = ["Книга находок у писца", "",
				page if page != ""
					else "Писцу пока ничего не передано со дна: книга ждёт.",
				"", teaching(loc), ""]
		"listen":
			out = ["Берег", "", teaching(loc), ""]
			if p.still >= 0.0:
				out += ["Стой, не двигаясь: слушай воду.", ""]
			elif p.heard:
				out += ["Тихо. Берег молчит, вода слышна.", ""]
		"witness":
			out = ["Черта", "",
				"Стой у черты. Подойти можно — до черты; склонить голову; уйти.",
				teaching(loc), ""]
		_:
			out = [str(h.get("ru", "")), "", teaching(loc), ""]
			if p.reply != "":
				out += [p.reply, ""]
	return out


## The choices: {id, text, disabled, reason}; the last one steps away,
## except at the end of a meeting with a thought, which is walked on.
static func choices(p: Dictionary, loc: Dictionary, st: Dictionary,
		ctx: Dictionary) -> Array:
	var h: Dictionary = loc.heart
	match p.kind:
		"talk":
			var out := []
			var open := HubCore.open_branches(p.node, st.form)
			for i in open.size():
				out.append({"id": "b%d" % i, "text": str(open[i].get("text_ru",
					open[i].get("text", ""))), "disabled": false, "reason": ""})
			return out + [AWAY]
		"deed":
			var kept := RuleCore.kept_today(st.actions, h.id, st.day)
			return [{"id": "do", "text": MissionCore.PRACTICE_RU[h.id].label,
				"disabled": kept, "reason": "сегодня уже сделано"}, AWAY]
		"rule":
			var pr := RuleCore.practice(h.id)
			match pr.kind:
				"timer":
					if p.timer >= 0.0:
						return [{"id": "stop", "text": "Прервать: не считать",
							"disabled": false, "reason": ""}, AWAY]
					return [{"id": "start", "text": "Начать: %d мин"
						% int(pr.minutes), "disabled": false, "reason": ""},
						AWAY]
				"daily":
					return [{"id": "do", "text": pr.ru,
						"disabled": RuleCore.kept_today(st.actions, h.id,
							st.day), "reason": "сегодня уже"}, AWAY]
			return [{"id": "do", "text": pr.ru, "disabled": false,
				"reason": ""}, AWAY]
		"watch":
			return RuleCell.watch_choices(st.actions, st.day)
		"trial":
			if p.reply != "":
				return [AWAY]
			var tv := TrialCore.trial_view(ctx.trial_data, st.trials, h.id,
				st.form, st.actions)
			var fs := TrialCore.fall_status(ctx.trial_data, st.trials,
				st.actions)
			if fs.fallen or tv.passed or not tv.open or tv.waiting:
				return [AWAY]
			var out := []
			for o in tv.options:
				out.append({"id": o.id, "text": o.text,
					"disabled": o.disabled, "reason": ""})
			return out + [AWAY]
		"passion":
			if p.enc.stage in ["virtue", "captive"]:
				return [{"id": "finish", "text": "Идти дальше",
					"disabled": false, "reason": ""}]
			if p.still >= 0.0:
				return []
			var out := []
			for o in PassionCore.options(p.enc, _passion(ctx, h.id), st.form,
					st.actions):
				out.append({"id": o.id, "text": o.text_ru, "disabled": false,
					"reason": "", "breaths": o.get("breaths", 0)})
			return out + [AWAY]
		"dive":
			var fs := TrialCore.fall_status(ctx.trial_data, st.trials,
				st.actions)
			return [{"id": "dive", "text": "Спустить аппарат в озеро",
				"disabled": fs.fallen, "reason":
				"путь в глубину закрыт: сперва трезвение и беседа"}, AWAY]
		"find":
			if p.reply != "":
				return [AWAY]
			return [{"id": "look", "text": "Рассмотреть и оставить на месте",
				"disabled": false, "reason": ""}, AWAY]
		"atlas-trace":
			return [{"id": "hand", "text": "Отдать писцу",
				"disabled": h.trace in st.atlas_given,
				"reason": "уже у писца"}, AWAY]
		"atlas-chronicle":
			if not AtlasTraces.option(ctx.atlas, st.chronicle).is_empty():
				return [AWAY]
			var out := []
			for o in AtlasTraces.options(ctx.atlas):
				out.append({"id": o.id, "text": o.text_ru, "disabled": false,
					"reason": ""})
			return out + [AWAY]
		"atlas-scribe":
			return [AWAY]
		"witness":
			return [{"id": "bow", "text": "Склонить голову", "disabled": false,
				"reason": ""}, AWAY]
		"listen":
			if p.still >= 0.0:
				return [AWAY]
			return [{"id": "listen", "text": "Стоять и слушать",
				"disabled": false, "reason": ""}, AWAY]
	if p.reply != "":
		return [AWAY]
	return [{"id": "do", "text": str(h.get("ru", "")), "disabled": false,
		"reason": ""}, AWAY]


## A choice by its place in the list.
static func choose(p: Dictionary, loc: Dictionary, st: Dictionary,
		ctx: Dictionary, i: int) -> Dictionary:
	var list := choices(p, loc, st, ctx)
	if i < 0 or i >= list.size():
		return _result(p, st)
	var c: Dictionary = list[i]
	if c.disabled:
		return _result(p, st, c.reason)
	if c.id == "away":
		return _result({}, st)
	var h: Dictionary = loc.heart
	var q := p.duplicate(true)
	var s := st.duplicate(true)
	match p.kind:
		"talk":
			var open := HubCore.open_branches(p.node, s.form)
			var res := HubCore.choose(s.form, open[int(c.id.substr(1))])
			s.form = res.form
			if res.next == null:
				return _result({}, s, "Беседа окончена.", true)
			q.node = HubCore.node_of(ctx.trees[h.npc], res.next)
			q.choice = 0
			return _result(q, s, "", true)
		"deed":
			s.actions = MissionCore.do_practice(s.actions, h.id, s.day)
			return _result(q, s, MissionCore.PRACTICE_RU[h.id].after, true)
		"rule":
			match c.id:
				"start":
					q.timer = float(RuleCore.practice(h.id).minutes) * 60.0
					return _result(q, s, "Начато.")
				"stop":
					q.timer = -1.0
					return _result(q, s, "Прервано: не засчитано.")
			s.actions = RuleCore.do_practice(s.actions, h.id, {"day": s.day})
			return _result(q, s, "Сделано: " + RuleCore.practice(h.id).ru
				+ ".", true)
		"watch":
			if c.id == "keep":
				s.actions = RuleCore.do_practice(s.actions, RuleCell.WATCH_ID,
					{"day": s.day})
				return _result(q, s, "Дозор держан. Сторож не спал.", true)
		"trial":
			var res := TrialCore.choose_trial(ctx.trial_data, s.trials, h.id,
				c.id, s.form, s.actions)
			if res.outcome == null:
				return _result({}, st)
			s.trials = res.state
			q.reply = res.reply
			q.choice = 0
			return _result(q, s, "", true)
		"passion":
			var passion := _passion(ctx, h.id)
			if c.id == "finish":
				var res := PassionCore.finish(s.passions, p.enc)
				s.passions = res.record
				for a in res.attribute_bonuses:
					if a in HubCore.ATTRIBUTES:
						s.form[a] = int(s.form[a]) \
							+ int(res.attribute_bonuses[a])
				return _result({}, s, "", true)
			if c.get("breaths", 0) > 0:
				q.still = float(c.breaths) * STILL_BREATH_SECONDS
				q["pending"] = c.id
				return _result(q, s)
			q.enc = PassionCore.choose(p.enc, c.id, passion, s.form,
				s.actions)
			q.choice = 0
			return _result(q, s)
		"dive":
			return _result({}, s, "", true, "res://scenes/dive.tscn")
		"find":
			q.reply = "Вещь остаётся на месте: писцу несут слово о ней, а не её саму."
			q.choice = 0
			return _result(q, s)
		"atlas-trace":
			var tr := _trace(ctx, h.trace)
			var res := AtlasTraces.take({"atlas": s.atlas_given}, {"id": tr.id,
				"ru": tr.ru, "loot": tr.loot, "holy": tr.holy})
			s.atlas_given = res.bag.atlas
			q.reply = res.text
			q.choice = 0
			return _result(q, s, res.text, true)
		"atlas-chronicle":
			s.chronicle = AtlasTraces.write_chronicle(ctx.atlas, s.chronicle,
				c.id)
			q.choice = 0
			return _result(q, s, "", true)
		"witness":
			# Nothing is written about standing at the line.
			return _result({}, st)
		"listen":
			# The time of standing lives only in the open panel.
			q.still = LISTEN_SECONDS
			q.choice = 0
			return _result(q, st)
	q.reply = "Сделано."
	q.choice = 0
	return _result(q, s)


## Time passing with the panel open: a practice of whole minutes, and
## the three breaths of stillness before a thought.  still is whether the
## player's body is still (no walking); for stillness and the vigil a
## movement starts the count again, as the hub's corner does.
static func tick(p: Dictionary, loc: Dictionary, st: Dictionary,
		ctx: Dictionary, dt: float, still: bool) -> Dictionary:
	var h: Dictionary = loc.heart
	if p.get("kind") == "rule" and p.timer >= 0.0:
		var q := p.duplicate(true)
		var pr := RuleCore.practice(h.id)
		if h.id in STILL_PRACTICES and not still:
			q.timer = float(pr.minutes) * 60.0
			return _result(q, st)
		q.timer -= dt
		if q.timer > 0.0:
			return _result(q, st)
		q.timer = -1.0
		var s := st.duplicate(true)
		s.actions = RuleCore.do_practice(s.actions, h.id,
			{"minutes": int(pr.minutes), "day": s.day})
		return _result(q, s, "Сделано: %s, %d мин." % [pr.ru,
			int(pr.minutes)], true)
	if p.get("kind") == "listen" and p.still >= 0.0:
		var q := p.duplicate(true)
		q.still = LISTEN_SECONDS if not still else q.still - dt
		if q.still <= 0.0:
			q.still = -1.0
			q.heard = true
			q.choice = 0
		# The state is handed back as it came: nothing is recorded.
		return _result(q, st)
	if p.get("kind") == "passion" and p.still >= 0.0:
		var q := p.duplicate(true)
		q.still -= dt
		if q.still > 0.0:
			return _result(q, st)
		q.still = -1.0
		q.enc = PassionCore.choose(p.enc, str(p.get("pending", "still")),
			_passion(ctx, h.id), st.form, st.actions)
		q.choice = 0
		return _result(q, st)
	return _result(p, st)


## The figure of the thought met at the heart, from the antagonist
## factory (the same variant the web game shows), or "" without art.
static func passion_art(loc: Dictionary, st: Dictionary,
		ctx: Dictionary) -> String:
	var q := _passion(ctx, loc.heart.id)
	var sprite = PassionCore.sprite_for(q, st.passions, ctx.manifest)
	if sprite == null:
		return ""
	return "res://art/derived/DEF-001/" + str(sprite.src).get_file()


## The panel's text: its lines and its choices, the current one marked.
static func text(p: Dictionary, loc: Dictionary, st: Dictionary,
		ctx: Dictionary) -> String:
	return "\n".join(lines(p, loc, st, ctx) + RuleCell.choice_lines(
		choices(p, loc, st, ctx), p.choice))
