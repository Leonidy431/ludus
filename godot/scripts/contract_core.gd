## A contract in the manner of The Witcher (operator, 2026-10-02: the
## mission "catch the Mega pike, the Shark of Issyk-Kul"), held to the
## Constitution: no weapon, no kill, no randomness.  The loot is
## knowledge and evidence.  docs/HLD_CONTRACT_AKULA_2026-10-02.md and
## docs/story/MISSION_AKULA_ISSYK_KUL_2026-10-02.md tell the story; the
## data is godot/data/contract-akula.json.
##
## The stages: notice → clues → identify (the bestiary entry, legend set
## against measurement) → prepare (red light, tether sleeve, dusk) →
## encounter (follow slowly, hold in range) → sample (a swab of mucus) →
## lab (UV, microscope, the brass spoon) → choice (release with a tag,
## hand over, sell) → after.  A wrong approach only makes the fish leave
## for the night; there is no death and no game over.
class_name ContractCore
extends RefCounted

const DATA := "res://data/contract-akula.json"
## Words of a shooter or a slaughter: a contract with any of them in
## its data is not ours (Constitution, TABOO 0.35 rule 15).
const WEAPON_WORDS := ["гарпун", "торпед", "убить", "убил", "застрел",
	"взорв", "добить", "разделать", "трофейн"]


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


static func start() -> Dictionary:
	return {"stage": "notice", "clues": [], "facts": [], "prep": [],
		"bestiary": false, "hold_s": 0.0, "nights": 0, "sampled": false,
		"lab": [], "choice": "", "flags": [], "bonus": {}}


## The length a sonar reads from the echo's target strength, by the
## formula in the data (TS = a lg L + b, L in cm): the legend says
## three metres, the echo says how long the fish really is.
static func length_from_ts(data: Dictionary, ts_db: float) -> float:
	var s: Dictionary = data.sonar
	return pow(10.0, (ts_db - float(s.b)) / float(s.a)) / 100.0


static func ts_of(data: Dictionary, length_m: float) -> float:
	var s: Dictionary = data.sonar
	return float(s.a) * log(length_m * 100.0) / log(10.0) + float(s.b)


static func _clue(data: Dictionary, id: String) -> Dictionary:
	for c in data.clues:
		if c.id == id:
			return c
	return {}


## A clue found: its fact is learned once.  After `need` clues the
## contract moves to identification.
static func add_clue(data: Dictionary, st: Dictionary, id: String) \
		-> Dictionary:
	var s := st.duplicate(true)
	var c := _clue(data, id)
	if c.is_empty() or id in s.clues:
		return s
	s.clues.append(id)
	if not c.fact in s.facts:
		s.facts.append(c.fact)
	if s.stage in ["notice", "clues"]:
		s.stage = "clues"
		if s.clues.size() >= int(_stage(data, "clues").need):
			s.stage = "identify"
	return s


static func _stage(data: Dictionary, id: String) -> Dictionary:
	for g in data.stages:
		if g.id == id:
			return g
	return {}


## The bestiary opens only with every fact the stage needs: the legend
## alone (the old fisher's bucket) does not identify anything.
static func can_identify(data: Dictionary, st: Dictionary) -> bool:
	for f in _stage(data, "identify").need_facts:
		if not f in st.facts:
			return false
	return true


static func identify(data: Dictionary, st: Dictionary) -> Dictionary:
	var s := st.duplicate(true)
	if s.stage == "identify" and can_identify(data, s):
		s.bestiary = true
		s.stage = "prepare"
	return s


## Preparation: the wrong item (the white light) is taken off again, so
## a prepared ROV is exactly the items the stage needs.
static func prepare(data: Dictionary, st: Dictionary, item: String) \
		-> Dictionary:
	var s := st.duplicate(true)
	if s.stage != "prepare":
		return s
	for p in data.prep:
		if p.id == item:
			if p.get("wrong", false):
				s.prep.erase("red_filter")
				if not item in s.prep:
					s.prep.append(item)
			else:
				s.prep.erase("white_light")
				if not item in s.prep:
					s.prep.append(item)
	var ready := true
	for need in _stage(data, "prepare").need_prep:
		if not need in s.prep:
			ready = false
	if ready and not "white_light" in s.prep:
		s.stage = "encounter"
	return s


## One frame of the encounter.  inp: dist_m, speed_m_s, light_nm.  Too
## fast, too close or white light: the fish leaves for the night ("fled",
## nights + 1), nothing breaks.  Held in range, slow, in red light for
## hold_s: the swab is taken ("sampled").
static func encounter_step(data: Dictionary, st: Dictionary, dt: float,
		inp: Dictionary) -> Dictionary:
	var s := st.duplicate(true)
	if s.stage != "encounter":
		return {"state": s, "event": ""}
	var e: Dictionary = data.encounter
	var d := float(inp.get("dist_m", 99.0))
	var v := float(inp.get("speed_m_s", 0.0))
	var nm := float(inp.get("light_nm", 0.0))
	if v > float(e.max_speed_m_s) or d < float(e.min_dist_m) \
			or (d <= float(e.max_dist_m) and nm < float(e.light_nm_min)):
		s.hold_s = 0.0
		s.nights = int(s.nights) + 1
		return {"state": s, "event": "fled"}
	if d <= float(e.max_dist_m):
		s.hold_s = float(s.hold_s) + dt
		if s.hold_s >= float(e.hold_s) - 1e-4:
			s.sampled = true
			s.stage = "lab"
			return {"state": s, "event": "sampled"}
	else:
		s.hold_s = 0.0
	return {"state": s, "event": ""}


## The lab gives every result, always the same: the swab and the jaw
## hold what they hold.
static func lab(data: Dictionary, st: Dictionary) -> Dictionary:
	var s := st.duplicate(true)
	if s.stage != "lab" or not s.sampled:
		return s
	s.lab = []
	for r in data.lab:
		s.lab.append(r.id)
	s.stage = "choice"
	return s


## The choice and its consequences: attribute bonuses fixed in the data,
## world flags, and for the sale a step down the ladder of avarice.
static func choose(data: Dictionary, st: Dictionary, id: String) \
		-> Dictionary:
	var s := st.duplicate(true)
	if s.stage != "choice":
		return s
	for c in data.choices:
		if c.id == id:
			s.choice = id
			s.bonus = c.bonus.duplicate()
			s.flags = c.flags.duplicate()
			if c.has("passion"):
				s.flags.append("passion:" + str(c.passion))
			s.stage = "after"
	return s


## The rules of the contract: every stage reachable, every fact the
## bestiary needs has a clue, no weapon or slaughter word, bonuses within
## +1..+5 on the seven attributes only, the treasure not holy and handed
## over, the narrator in the third person and short.
static func check(data: Dictionary) -> Array:
	var bad := []
	var attrs := ["wisdom", "faith", "dexterity", "constitution",
		"charisma", "cunning", "erudition"]
	var facts := {}
	for c in data.get("clues", []):
		facts[c.fact] = true
	for f in _stage(data, "identify").get("need_facts", []):
		if not facts.has(f):
			bad.append("no clue gives %s" % f)
	if _stage(data, "clues").get("need", 99) > data.get("clues", []).size():
		bad.append("more clues needed than exist")
	var text := JSON.stringify(data).to_lower()
	for w in WEAPON_WORDS:
		if w in text:
			bad.append("weapon word «%s»" % w)
	for c in data.get("choices", []):
		var total := 0
		for k in c.bonus:
			if not k in attrs:
				bad.append("%s: %s is not an attribute" % [c.id, k])
			total += int(c.bonus[k])
		if total < 1 or total > 5:
			bad.append("%s: bonus %d outside 1..5" % [c.id, total])
		if not c.has("cost_ru"):
			bad.append("%s: a choice without its cost" % c.id)
	var t: Dictionary = data.get("treasure", {})
	if t.get("holy", true) or t.get("rule", "") != "hand-over":
		bad.append("the treasure must be a find handed over, not holy")
	for k in data.get("narration", {}):
		# TABOO 0.020: each line closes its scene and opens the next.
		if not data.get("narration_bridge", {}).has(k):
			bad.append("narration %s bridges to nothing" % k)
		var line := str(data.narration[k])
		if line.length() > 140:
			bad.append("narration %s is %d long" % [k, line.length()])
		for w in LocationsCore.words(line):
			if w in ["я", "ты", "мне", "меня"]:
				bad.append("narration %s is not third person" % k)
	var cr: Dictionary = data.get("creature", {})
	var ts := ts_of(data, float(cr.get("length_m", 1.0)))
	var said := false
	for c in data.get("clues", []):
		if c.id == "sonar_echo" and "двадцать шесть" in str(c.line_ru):
			said = true
	if absf(ts + 26.0) > 0.6 or not said:
		bad.append("the sonar clue does not match the fish (%.1f dB)" % ts)
	return bad
