## Claud, the ROV operator's AI companion (operator, 2026-10-03:
## «дай герою ИИ Клауд и озвучь голосом близким к кортана из Halo»;
## CLAUDE.md TABOO 0.026).  The plan, the voice and the chorus are in
## docs/HLD_COMPANION_CLAUD_2026-10-03.md; the lines of episode 1 live
## in godot/data/companion-claud.json.
##
## Claud speaks in the first person, in the headset and on the console;
## the narrator of pilot-narration.json speaks of the hero in the third.
## This file holds the logic apart from the scene and under test: which
## line answers a beat and an event, and check(), which fails the build
## when a line breaks the rules of the machine:
## - at the khachkar every line is empty: the machine is silent where
##   it cannot count (TABOO 0.4, 0.020 item 4);
## - no line is longer than 120 characters, and every line has en;
## - every number a line says is declared as a fact, and every physical
##   fact agrees with DiveCore (thermocline, sound speed, ascent limit,
##   temperature and pressure at depth), so the companion is an honest
##   instrument (CLAUDE.md TABOO 0.35 rule 19);
## - the machine never prays, never calls itself a god or a soul, and
##   never chooses for the hero (TABOO 0.026 item 2);
## - every hint beat climbs the ladder image -> direction -> direct
##   (TABOO 0.017).
## Nothing is random (Constitution): the same beat and event give the
## same line.
class_name CompanionCore
extends RefCounted

const DATA := "res://data/companion-claud.json"
const MAX_CHARS := 120
## Issyk-Kul is not ours to deepen: the lake is 668 m deep at most
## (CLAUDE.md TABOO 0.03 item 6); no depth a line names may exceed it.
const LAKE_MAX_M := 668.0
## How far a spoken rounding may stray from the model.
const TEMP_TOLERANCE := 0.6
const BAR_TOLERANCE := 0.05
const LANGS := ["ru", "en"]
## Words the machine never says (matched in lower case): prayer, a god or a soul of its own,
## salvation, and the imperative of a choice that is the hero's.
const FORBIDDEN := [
	"(^|[^а-яё])(мол[юи]|молитв|аминь|господ|благослов|душ[аиуе]" +
	"|спас[уеё]|спасени|грех|возьми|не бери|отдай|откажись|согласись" +
	"|решу за)",
	"\\b(pray|prayer|amen|bless|soul|god|salvation|sin|take it" +
	"|don't take|refuse it|accept it|give them|i'll decide)\\b",
]
## Facts whose value is a constant of the dive.
const CONSTANT_FACTS := {
	"thermocline_m": "THERMOCLINE_M", "c_above": "C_ABOVE",
	"c_below": "C_BELOW", "max_ascent": "MAX_ASCENT_M_PER_MIN",
	"t_surface": "T_SURFACE", "t_deep": "T_DEEP",
	"kink_turns": "KINK_TURNS", "safety_stop_s": "SAFETY_STOP_SEC",
}


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


## The entry for a beat and an event, or {} when there is none.
static func entry(data: Dictionary, beat_id: String,
		event: String) -> Dictionary:
	for x in data.get("lines", []):
		if str(x.get("beat", "")) == beat_id \
				and str(x.get("event", "")) == event:
			return x
	return {}


## What Claud says at this beat on this event, in `lang` (en when the
## language has no line).  Empty at the holy whatever the data hold:
## the console goes out and the companion with it.
static func line_for(beat_id: String, event: String, lang := "ru",
		data := {}) -> String:
	var d: Dictionary = data if not data.is_empty() else load_data()
	if beat_id in d.get("holy_beats", ["khachkar"]):
		return ""
	var x := entry(d, beat_id, event)
	if x.is_empty():
		return ""
	return str(x.get(lang, x.get("en", "")))


## A rung of the hint ladder: 1 image, 2 direction, 3 direct.
static func hint(beat_id: String, step: int, lang := "ru",
		data := {}) -> String:
	return line_for(beat_id, "hint:%d" % clampi(step, 1, 3), lang, data)


## Where the draft voice of a line lives once its pack is mounted.
static func voice_path(data: Dictionary, x: Dictionary,
		lang := "ru") -> String:
	return str(data.get("voice_dir",
		"res://companion/{lang}/{voice_file}.ogg")).format({
			"lang": lang, "voice_file": str(x.get("voice_file", ""))})


## Every number written in a line, with a decimal comma read as a point.
static func numbers(text: String) -> Array:
	var re := RegEx.new()
	re.compile("\\d+(?:[.,]\\d+)?")
	var out := []
	for m in re.search_all(text):
		out.append(float(m.get_string().replace(",", ".")))
	return out


## "" when a fact agrees with the physics of the dive, else why not.
static func fact_problem(f: Dictionary) -> String:
	var k := str(f.get("k", ""))
	var v := float(f.get("v", NAN))
	if CONSTANT_FACTS.has(k):
		var want := float((DiveCore as Script)
			.get_script_constant_map()[CONSTANT_FACTS[k]])
		return "" if is_equal_approx(v, want) \
			else "%s says %s, DiveCore %s" % [k, v, want]
	match k:
		"plain":
			return ""
		"depth":
			return "" if v >= 0.0 and v <= minf(LAKE_MAX_M,
				float(DiveCore.ROV.max_depth)) \
				else "depth %s out of the lake" % v
		"temp_c":
			var t := DiveCore.temperature(float(f.get("at", 0.0)))
			return "" if absf(v - t) <= TEMP_TOLERANCE \
				else "%s degC at %s m, DiveCore %.2f" % [v, f.at, t]
		"pressure_bar":
			var p := DiveCore.SURFACE_BAR \
				+ float(f.get("at", 0.0)) / DiveCore.METRES_PER_BAR
			return "" if absf(v - p) <= BAR_TOLERANCE \
				else "%s bar at %s m, DiveCore %.2f" % [v, f.at, p]
		"ascent_min":
			# At no more than 10 m/min the climb from `from` metres takes
			# at least from / 10 minutes; a shorter promise breaks it.
			var need := float(f.get("from", 0.0)) \
				/ DiveCore.MAX_ASCENT_M_PER_MIN
			return "" if v >= need \
				else "%s min from %s m is faster than the limit" \
					% [v, f.from]
	return "unknown fact %s" % k


## Every way the lines break the rules; empty when none.
static func check(data := {}, pilot := {}) -> Array:
	var d: Dictionary = data if not data.is_empty() else load_data()
	var p: Dictionary = pilot if not pilot.is_empty() \
		else PilotCore.load_data()
	var bad := []
	var beats := {}
	for b in p.get("beats", []):
		beats[str(b.id)] = b
	if d.get("draft_voice", false) != true:
		bad.append("the voice is not marked draft")
	var holy: Array = d.get("holy_beats", [])
	for id in beats:
		if beats[id].get("holy", false) and not id in holy:
			bad.append("holy beat %s missing from holy_beats" % id)
	var forbid := []
	for src in FORBIDDEN:
		var re := RegEx.new()
		re.compile(src)
		forbid.append(re)
	var keys := {}
	var files := {}
	var steps := {}
	var file_re := RegEx.new()
	file_re.compile("^claud_[a-z0-9_]+$")
	var lines: Array = d.get("lines", [])
	if lines.is_empty():
		bad.append("no lines")
	for x in lines:
		var beat := str(x.get("beat", ""))
		var ev := str(x.get("event", ""))
		var tag := beat + "/" + ev
		if not beats.has(beat):
			bad.append("%s: unknown beat" % tag)
		if keys.has(tag):
			bad.append("%s: twice" % tag)
		keys[tag] = true
		var vf := str(x.get("voice_file", ""))
		if file_re.search(vf) == null or files.has(vf):
			bad.append("%s: voice_file %s" % [tag, vf])
		files[vf] = true
		if x.get("draft_voice", false) != true:
			bad.append("%s: not marked draft voice" % tag)
		var facts: Array = x.get("facts", [])
		var said := []
		for f in facts:
			said.append(float(f.get("v", NAN)))
			var why := fact_problem(f)
			if why != "":
				bad.append("%s: %s" % [tag, why])
		for lang in LANGS:
			if not x.has(lang):
				bad.append("%s: missing %s" % [tag, lang])
				continue
			var text := str(x[lang])
			if beat in holy:
				if text != "":
					bad.append("%s: speaks at the holy" % tag)
				continue
			if text == "":
				bad.append("%s: empty %s" % [tag, lang])
			if text.length() > int(d.get("max_chars", MAX_CHARS)) \
					or text.length() > MAX_CHARS:
				bad.append("%s: %s is %d chars" % [tag, lang,
					text.length()])
			for re in forbid:
				if re.search(text.to_lower()) != null:
					bad.append("%s: the machine says what it must not"
						% tag)
			for n in numbers(text):
				var ok := false
				for s in said:
					if is_equal_approx(n, s):
						ok = true
				if not ok:
					bad.append("%s: %s says %s with no fact" % [tag,
						lang, n])
			if not numbers(text).is_empty() \
					and not x.has("say_" + lang):
				bad.append("%s: digits with no say_%s for the voice"
					% [tag, lang])
		if ev.begins_with("hint:"):
			var s: Dictionary = steps.get(beat, {})
			s[int(ev.substr(5))] = true
			steps[beat] = s
	for beat in d.get("hint_beats", []):
		var s: Dictionary = steps.get(beat, {})
		for i in [1, 2, 3]:
			if not s.has(i):
				bad.append("%s: hint ladder lacks step %d" % [beat, i])
	for id in holy:
		if not keys.has(str(id) + "/enter"):
			bad.append("%s: no silent line at the holy" % id)
	return bad
