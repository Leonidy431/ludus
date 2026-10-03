## Branches of episode 1 (CLAUDE.md TABOO 0.025, operator 2026-10-03:
## «мы делаем разный сюжет положительный рай) или менее положительный
## (чистилище за грехи)»).  godot/data/pilot-branches.json maps the
## pilot's choices to the deeds of godot/data/destiny.json, and through
## DestinyCore to one of its seven finales; for each finale it gives the
## light, the music node of the entelechy suite, the narrator's line
## with its bridge into episode 2 and the last frame.
##
## «Рай» and «чистилище» are images of the heroes and their age; the
## mechanic is the path of repentance with the door open: no hell, no
## player death, no randomness, and the holy is never a reward, a key or
## a branch (TABOO 0.4).  The same deeds always give the same finale,
## because the finale is DestinyCore's, not ours.
class_name BranchCore
extends RefCounted

const DATA := "res://data/pilot-branches.json"
const PILOT := "res://data/pilot-1.json"
const ENTELECHY := "res://data/entelechy-99.json"
const POLES := ["light", "middle", "purification"]
## The holy is never a reward, a key or the consequence of a branch: a
## consequence, a line or a last frame naming it fails (TABOO 0.4,
## 0.35 item 16).  Word stems, matched at a word's start.
const HOLY := ["кайрак", "крест", "икон", "молитв", "колокол", "благовест",
	"лампад", "святын", "благодат", "причаст"]
## The narrator speaks of the hero in the third person (TABOO 0.020
## item 1): a line with these words is in the first or second person.
const NOT_THIRD := ["я", "мне", "меня", "мной", "мой", "моя", "моё", "мое",
	"мои", "моего", "мы", "нас", "нам", "наш", "наша", "ты", "тебя", "тебе",
	"твой", "твоя", "вы", "вас", "ваш"]
const LINE_MAX := 140


static func _json(path: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


static func load_data() -> Dictionary:
	return _json(DATA)


## The finale id a set of deeds leads to: DestinyCore's, so the branch
## and the destiny never disagree.
static func finale_for(destiny: Dictionary, deeds: Array) -> String:
	return str(DestinyCore.finale(destiny, deeds).get("id", ""))


static func finale_entry(data: Dictionary, id: String) -> Dictionary:
	for f in data.get("finales", []):
		if f.id == id:
			return f
	return {}


static func _point(data: Dictionary, id: String) -> Dictionary:
	for p in data.get("choice_points", []):
		if p.id == id:
			return p
	return {}


## Is a point offered after the picks made so far?  Every condition of
## "offered_if" must hold; a point not yet picked holds no option.
static func offered(point: Dictionary, picks: Dictionary) -> bool:
	var cond: Dictionary = point.get("offered_if", {})
	for k in cond:
		if not str(picks.get(k, "")) in cond[k]:
			return false
	return true


## The deeds of a set of picks {point id: option id}, in the order of
## the points; a point not offered adds nothing.
static func deeds_of(data: Dictionary, picks: Dictionary) -> Array:
	var out := []
	for p in data.get("choice_points", []):
		var pick := str(picks.get(p.id, ""))
		if pick == "" or not offered(p, picks):
			continue
		for o in p.options:
			if o.id == pick:
				for d in o.deeds:
					if not d in out:
						out.append(d)
	return out


## The echo the pilot gives at choice_echo for these picks (the stage
## the lure ladder reached): virtue, captive or unresolved.
static func echo_of(data: Dictionary, picks: Dictionary) -> String:
	var p := _point(data, "lure_ladder")
	for o in p.get("options", []):
		if o.id == str(picks.get("lure_ladder", "")):
			return str(o.get("echo", "unresolved"))
	return "unresolved"


## Every path of the episode: each point in order takes each of its
## options when offered, or none when not.  Deterministic order.
static func paths(data: Dictionary) -> Array:
	var all := [{}]
	for p in data.get("choice_points", []):
		var next := []
		for picks in all:
			if not offered(p, picks):
				next.append(picks)
				continue
			for o in p.options:
				var q: Dictionary = picks.duplicate()
				q[p.id] = o.id
				next.append(q)
		all = next
	return all


static func _words(text: String) -> PackedStringArray:
	var clean := text.to_lower()
	for ch in [".", ",", ":", ";", "!", "?", "«", "»", "—", "(", ")", "\""]:
		clean = clean.replace(ch, " ")
	return clean.split(" ", false)


static func _holy_in(text: String) -> String:
	for w in _words(text):
		for stem in HOLY:
			if w.begins_with(stem):
				return stem
	return ""


static func third_person(text: String) -> bool:
	for w in _words(text):
		if w in NOT_THIRD:
			return false
	return true


## The openings of episode 2 the pilot already knows: the "episode2"
## values of its choice echo.
static func openings(pilot: Dictionary) -> Array:
	var out := []
	for k in pilot.get("choice_echo", {}):
		out.append(str(pilot.choice_echo[k].episode2))
	return out


static func _line_problems(id: String, key: String, text: String) -> Array:
	var bad := []
	if text == "":
		bad.append("%s: no %s" % [id, key])
	if text.length() > LINE_MAX:
		bad.append("%s: %s is %d chars, over %d" % [id, key, text.length(),
			LINE_MAX])
	if not third_person(text):
		bad.append("%s: %s is not in the third person" % [id, key])
	var h := _holy_in(text)
	if h != "":
		bad.append("%s: %s names the holy («%s»)" % [id, key, h])
	return bad


## Everything that is wrong with the branches, or [] when nothing is.
static func check(data: Dictionary, destiny: Dictionary,
		pilot: Dictionary = {}, entelechy: Dictionary = {}) -> Array:
	var bad := []
	if pilot.is_empty():
		pilot = _json(PILOT)
	if entelechy.is_empty():
		entelechy = _json(ENTELECHY)
	var known := {}
	for x in destiny.get("deeds", []):
		known[x.id] = true
	var beats := {}
	for b in pilot.get("beats", []):
		beats[b.id] = b
	var opens := openings(pilot)

	# The choice points: real beats, never the holy, deeds of destiny,
	# conditions only on earlier points.
	var seen_points := []
	for p in data.get("choice_points", []):
		if not beats.has(p.beat):
			bad.append("%s: no beat %s in the pilot" % [p.id, p.beat])
		elif beats[p.beat].get("holy", false):
			bad.append("%s: a branch at the holy beat %s" % [p.id, p.beat])
		for k in p.get("offered_if", {}):
			if not k in seen_points:
				bad.append("%s: depends on %s, not an earlier point"
					% [p.id, k])
		if p.options.size() < 2:
			bad.append("%s: a choice of fewer than two options" % p.id)
		for o in p.options:
			for d in o.deeds:
				if not known.has(d):
					bad.append("%s.%s: deed %s is not in destiny"
						% [p.id, o.id, d])
			var h := _holy_in(str(o.get("consequence_ru", "")))
			if h != "":
				bad.append("%s.%s: the holy as a consequence («%s»)"
					% [p.id, o.id, h])
			if p.id == "lure_ladder" \
					and not str(o.get("echo", "")) in pilot.get(
						"choice_echo", {}):
				bad.append("%s.%s: no echo of the pilot" % [p.id, o.id])
		seen_points.append(p.id)

	# The craft: the chosen techniques the finales may name.
	var craft := {}
	for c in data.get("craft", {}).get("chosen", []):
		craft[c.technique] = true
	if data.get("craft", {}).get("chosen", []).size() != 99:
		bad.append("the craft is not 99 techniques")
	if int(data.get("craft", {}).get("pool", 0)) < 99:
		bad.append("the craft's pool is smaller than its choice")

	var nodes := {}
	for n in entelechy.get("nodes", []):
		nodes[n.id] = n.get("signs", []).size()

	# The finales: exactly destiny's seven, each fully dressed.
	var ids := []
	for f in data.get("finales", []):
		ids.append(f.id)
		var df: Dictionary = {}
		for x in destiny.get("finales", []):
			if x.id == f.id:
				df = x
		if df.is_empty():
			bad.append("%s: not a finale of destiny" % f.id)
			continue
		var band := int(df.band)
		var pole := str(f.get("pole", ""))
		var bands := []
		if pole in POLES:
			for x in data.poles[pole].bands:
				bands.append(int(x))
		if not band in bands:
			bad.append("%s: pole %s does not hold band %d" % [f.id, pole,
				band])
		var light: Dictionary = f.get("light", {})
		var lights := [light]
		if light.has("mix"):
			lights.append(light.mix)
		for l in lights:
			var cls := str(l.get("class", ""))
			if not data.lights.has(cls):
				bad.append("%s: no light class %s" % [f.id, cls])
				continue
			var r: Array = data.lights[cls]
			var k := int(l.get("kelvin", 0))
			if k < int(r[0]) or k > int(r[1]):
				bad.append("%s: %d K is not %s light" % [f.id, k, cls])
		var m: Dictionary = f.get("music", {})
		if not nodes.has(str(m.get("node", ""))):
			bad.append("%s: no music node" % f.id)
		elif int(m.get("sign", 0)) < 1 \
				or int(m.sign) > int(nodes[m.node]):
			bad.append("%s: no sign %s in node %s" % [f.id, m.get("sign"),
				m.node])
		bad.append_array(_line_problems(f.id, "line_ru",
			str(f.get("line_ru", ""))))
		if f.has("repent_line_ru"):
			bad.append_array(_line_problems(f.id, "repent_line_ru",
				str(f.repent_line_ru)))
			if not str(f.get("repent_bridge_to", "")) in opens:
				bad.append("%s: the repentant bridge leads nowhere" % f.id)
		if not str(f.get("bridge_to", "")) in opens:
			bad.append("%s: bridge_to %s is no opening of episode 2"
				% [f.id, f.get("bridge_to")])
		var frame := str(f.get("last_frame_ru", ""))
		if frame == "":
			bad.append("%s: no last frame" % f.id)
		elif _holy_in(frame) != "":
			bad.append("%s: the holy in the last frame" % f.id)
		if str(f.get("all_faiths_ru", "")) == "":
			bad.append("%s: no all_faiths line" % f.id)
		if pole == "purification" and str(f.get("door_ru", "")) == "":
			bad.append("%s: the lower path without its open door" % f.id)
		if light.get("class", "") == "lampada":
			bad.append("%s: the lamp of the holy as a reward" % f.id)
		var techs: Array = f.get("techniques", [])
		if techs.size() < 2:
			bad.append("%s: fewer than two techniques" % f.id)
		for t in techs:
			if not craft.has(t):
				bad.append("%s: technique %s is not in the top 99"
					% [f.id, t])
		# The declared paths really end here.
		for path in f.get("paths", []):
			var got := finale_for(destiny, path)
			if got != f.id:
				bad.append("%s: path %s ends in %s" % [f.id, path, got])
	var want := []
	for x in destiny.get("finales", []):
		want.append(x.id)
	var a := ids.duplicate()
	a.sort()
	want.sort()
	if a != want:
		bad.append("the finales are not destiny's seven: %s" % [ids])

	# No deed set is declared under two finales.
	var declared := {}
	for f in data.get("finales", []):
		for path in f.get("paths", []):
			var key: Array = path.duplicate()
			key.sort()
			var s := ",".join(key)
			if declared.has(s) and declared[s] != f.id:
				bad.append("deeds %s declared under %s and %s"
					% [s, declared[s], f.id])
			declared[s] = f.id

	# Every finale is reached by some path of the episode; one set of
	# deeds gives one finale; each bridge is honest for a path that
	# reaches it (the pilot's own echo opens episode 2 the same way).
	var reached := {}
	var by_deeds := {}
	var echo_ok := {}
	for picks in paths(data):
		var deeds := deeds_of(data, picks)
		var fid := finale_for(destiny, deeds)
		reached[fid] = true
		var key: Array = deeds.duplicate()
		key.sort()
		var s := ",".join(key)
		if by_deeds.has(s) and by_deeds[s] != fid:
			bad.append("deeds %s give %s and %s" % [s, by_deeds[s], fid])
		by_deeds[s] = fid
		var fe := finale_entry(data, fid)
		var ep2: String = pilot.choice_echo[echo_of(data, picks)].episode2
		if ep2 == str(fe.get("bridge_to", "")) \
				or ep2 == str(fe.get("repent_bridge_to", "")):
			echo_ok[fid] = true
	for id in want:
		if not reached.has(id):
			bad.append("%s: no path of episode 1 reaches it" % id)
		elif not echo_ok.has(id):
			bad.append("%s: its bridge matches no path's echo" % id)
	return bad
