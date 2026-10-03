## The ROV pilot course in the pike-search contract (RovCourseCore):
## every objective of the operator's outline has its stage, the stages
## exist, the lines are short, the ascent keeps the dive physics, no
## brand and no certificate reach the game strings, progress is
## deterministic.  Called from run_hub_tests.gd.
extends RefCounted


func run(t: Object) -> void:
	var d := RovCourseCore.load_data()
	var c := ContractCore.load_data()
	t._check(not d.is_empty(), "the ROV course loads")
	var bad := RovCourseCore.check(d, c)
	t._check(bad.is_empty(), "the ROV course keeps its rules: %s" % [bad])

	# Every skill the outline asks for is taught somewhere.
	var ids := {}
	for o in d.objectives:
		ids[o.id] = true
	for need in ["piloting_three", "thermocline_check", "legal_permit",
			"site_map", "predive_check", "care_of_equipment", "post_dive",
			"debrief", "log_dive", "navigation_features",
			"side_scan_reading", "robot_arm", "laser_scale", "robot_sonar",
			"robot_control", "detection_three", "conservation_three",
			"plastic_mesh", "ascent"]:
		t._check(ids.has(need), "the course teaches %s" % need)

	t._check(RovCourseCore.objectives_for("encounter", d).size() >= 4,
		"the encounter teaches sonar, piloting, control and lasers")
	t._check(RovCourseCore.objectives_for("nowhere", d).is_empty(),
		"an unknown stage teaches nothing")

	# The rules bite: a broken copy is caught.
	var b := d.duplicate(true)
	b.objectives[0].stage = "nowhere"
	b.objectives[1].teach_ru = "х".repeat(141)
	b.objectives[2].source = ""
	b.objectives[3].teach_ru = "Пульт BlueOS на лодке"
	b.ascent.m_per_min = 18.0
	b.methods.conservation.pop_back()
	b.not_certification_ru = "PADI"
	b.title_ru = "Сертификат пилота"
	var errs := RovCourseCore.check(b, c)
	var text := "\n".join(errs)
	for frag in ["nowhere", "141 chars", "no source", "brand: blueos",
			"ascent 18", "methods.conservation has 2", "brand: padi",
			"claims a certificate"]:
		t._check(text.contains(frag), "a broken course is caught: %s" % frag)

	# The ascent the outline gives for divers is not the vehicle's.
	t._check(float(d.ascent.outline_m_per_min)
			> DiveCore.MAX_ASCENT_M_PER_MIN,
		"the outline's diver ascent is faster than the tethered vehicle's")
	# A tethered ascent at 9 m/min passes; the diver's 18 m/min would be
	# too fast for the vehicle.  The history is [dt, depth] pairs.
	var rov := DiveCore.new_rov()
	rov.history = [[0.0, 30.0], [0.5, 29.925], [0.5, 29.85]]
	t._check(not DiveCore.ascent_rate(rov).too_fast,
		"9 m/min on the tether is not too fast")
	rov.history = [[0.0, 30.0], [0.5, 29.85], [0.5, 29.7]]
	t._check(DiveCore.ascent_rate(rov).too_fast,
		"the diver's 18 m/min is too fast for the tethered vehicle")

	# Progress walks the objectives in the order of play.
	var p := RovCourseCore.progress([], d)
	t._check(p.done == 0 and p.next == "legal_permit",
		"the course starts with the permit")
	p = RovCourseCore.progress(["legal_permit", "diver_safety", "bogus"],
		d)
	t._check(p.done == 2 and p.next == "conditions_brief"
			and p.total == d.objectives.size(),
		"progress counts known ids only: %s" % [p])
	var all: Array = []
	for o in d.objectives:
		all.append(o.id)
	p = RovCourseCore.progress(all, d)
	t._check(p.done == p.total and p.next == "",
		"all objectives done, nothing next")
	t._check(RovCourseCore.progress(all, d) == p, "progress is deterministic")
