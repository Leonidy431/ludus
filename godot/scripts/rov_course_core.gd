## The ROV pilot course inside the pike-search contract (RovCourseCore).
## The operator, a diving instructor, gave his course outline for remote
## operated video work (docs/missions/rov-pilot-akula/); every learning
## objective and performance requirement of it is taught by doing inside
## the contract "The Shark of Issyk-Kul" (ContractCore).  The data is
## godot/data/rov-pilot-course.json.  This is training in a game, not a
## certification, and the data says so.
##
## Constitution: FORM (the vehicle, its instruments and the lake as they
## really are: 668 m, one thermocline at 50 m, brackish water) → ACTION
## (each skill of the outline done once at its stage of the contract:
## brief, check, measure, map, sample, protect, ascend, log) → GOAL
## (the pilot learns that a method and a measurement are the way to the
## truth, and that a find is guarded, not taken; Entelechy VIII.2, IX.3).
##
## Everything is static and deterministic: the same data and the same
## done list give the same progress, with no randomness.
class_name RovCourseCore
extends RefCounted

const DATA := "res://data/rov-pilot-course.json"
## A taught line is read in about seven seconds of speech (TABOO 0.020).
const MAX_LINE := 140
## Foreign product and agency names stay in the development documents;
## the game speaks in common words (TABOO 0.03 rule 7, TABOO 0.022
## rule 4).  Lower case, matched as substrings of lower-cased text.
const BRANDS := ["padi", "naui", "ssi ", "cmas", "blueos", "blue robotics",
	"bluerov", "ardusub", "qgroundcontrol", "raspberry", "hailo",
	"ping360", "tritech", "imagenex", "starfish", "humminbird", "lowrance",
	"garmin", "deeper", "oculus m", "chasing", "qysea", "fifish",
	"пади", "блюос"]
## The navigation cases the outline names (Dive One A.8).
const NAVIGATION := ["ship", "shore_boat", "cave", "river", "under_ice"]
## The method blocks that the outline counts as three.
const THREE := ["piloting", "detection", "conservation"]


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


## The objectives taught at one stage or step, in the order of the data.
static func objectives_for(stage: String, data: Dictionary = {}) -> Array:
	var d := data if not data.is_empty() else load_data()
	var out: Array = []
	for o in d.get("objectives", []):
		if String(o.get("stage", "")) == stage:
			out.append(o)
	return out


## Every string under a key ending in "_ru", with its path, so that the
## brand and length checks see nested method blocks too.
static func _ru_strings(v: Variant, path: String, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			var p := "%s.%s" % [path, k]
			if String(k).ends_with("_ru") and v[k] is String:
				out.append([p, v[k]])
			else:
				_ru_strings(v[k], p, out)
	elif v is Array:
		for i in v.size():
			_ru_strings(v[i], "%s[%d]" % [path, i], out)


static func _brand_in(text: String) -> String:
	var low := text.to_lower()
	for b in BRANDS:
		if low.contains(b):
			return b
	return ""


## The list of what is wrong with the course data against the contract
## and the dive physics; an empty list means the course keeps its rules.
static func check(data: Dictionary, contract: Dictionary) -> Array:
	var bad: Array = []
	var stages := {}
	for s in contract.get("stages", []):
		stages[String(s.id)] = true
	var steps := {}
	for s in data.get("steps", []):
		var id := String(s.get("id", ""))
		steps[id] = true
		if stages.has(id):
			bad.append("step %s shadows a contract stage" % id)
		if not stages.has(String(s.get("after", ""))):
			bad.append("step %s follows no contract stage" % id)
	var order: Array = data.get("order", [])
	for id in stages.keys() + steps.keys():
		if not order.has(id):
			bad.append("stage %s is missing from the order" % id)

	var seen := {}
	var last := -1
	for o in data.get("objectives", []):
		var id := String(o.get("id", ""))
		if id.is_empty() or seen.has(id):
			bad.append("objective id empty or repeated: %s" % id)
		seen[id] = true
		var st := String(o.get("stage", ""))
		if st.is_empty():
			bad.append("objective %s has no stage" % id)
		elif not stages.has(st) and not steps.has(st):
			bad.append("objective %s: stage %s is neither in the "
				% [id, st] + "contract nor declared in the course")
		else:
			# The objectives go in the order of play, so that the next
			# one to teach is always the next one met.
			var at := order.find(st)
			if at < last:
				bad.append("objective %s is out of order" % id)
			last = maxi(last, at)
		if String(o.get("source", "")).strip_edges().is_empty():
			bad.append("objective %s has no source in the outline" % id)
		if String(o.get("check", "")).strip_edges().is_empty():
			bad.append("objective %s has no check" % id)
		var teach := String(o.get("teach_ru", ""))
		if teach.is_empty() or teach.length() > MAX_LINE:
			bad.append("objective %s: teach_ru is %d chars"
				% [id, teach.length()])

	var m: Dictionary = data.get("methods", {})
	for k in THREE:
		var n: int = m.get(k, []).size()
		if n != 3:
			bad.append("methods.%s has %d, the outline asks for 3" % [k, n])
	var nav := {}
	for n in m.get("navigation", []):
		nav[String(n.id)] = true
	for k in NAVIGATION:
		if not nav.has(k):
			bad.append("navigation case %s is missing" % k)

	var asc: Dictionary = data.get("ascent", {})
	if not is_equal_approx(float(asc.get("m_per_min", -1.0)),
			DiveCore.MAX_ASCENT_M_PER_MIN):
		bad.append("ascent %s m/min differs from DiveCore %s"
			% [asc.get("m_per_min"), DiveCore.MAX_ASCENT_M_PER_MIN])
	var lake: Dictionary = data.get("lake", {})
	if not is_equal_approx(float(lake.get("thermocline_m", -1.0)),
			DiveCore.THERMOCLINE_M):
		bad.append("thermocline differs from DiveCore")

	var ru: Array = []
	_ru_strings(data, "course", ru)
	for pair in ru:
		var b := _brand_in(String(pair[1]))
		if not b.is_empty():
			bad.append("%s names a brand: %s" % [pair[0], b])
		# The game teaches; it does not certify (minimum age 18 and an
		# advanced diver card are the real course's entry, not ours).
		if not String(pair[0]).ends_with("not_certification_ru") \
				and String(pair[1]).to_lower().contains("сертифик"):
			bad.append("%s claims a certificate" % pair[0])
	return bad


## How far the course has gone: the done objectives (unknown ids are
## ignored), the total, and the id of the next objective to teach.
static func progress(done_ids: Array, data: Dictionary = {}) -> Dictionary:
	var d := data if not data.is_empty() else load_data()
	var done := 0
	var next := ""
	var objs: Array = d.get("objectives", [])
	for o in objs:
		if done_ids.has(o.id):
			done += 1
		elif next.is_empty():
			next = String(o.id)
	return {"done": done, "total": objs.size(), "next": next}
