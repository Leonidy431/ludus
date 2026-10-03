## Branches of episode 1 (BranchCore, CLAUDE.md TABOO 0.025): the
## pilot's choices lead through DestinyCore to all seven finales, from
## the dawn on the water to the endless copy; the same deeds give the
## same finale; every finale has its light, music and third-person line
## with a bridge into episode 2; the lower path keeps its door open and
## repentance lifts it; the holy is never a branch.  Called from
## run_hub_tests.gd.
extends RefCounted


func run(t: Object) -> void:
	var d := BranchCore.load_data()
	var destiny := DestinyCore.load_data()
	t._check(not d.is_empty(), "pilot branches load")
	var bad := BranchCore.check(d, destiny)
	t._check(bad.is_empty(), "branches keep their rules: %s" % [bad])

	# Every one of the seven finales is reachable in episode 1.
	var reached := {}
	var all := BranchCore.paths(d)
	for picks in all:
		reached[BranchCore.finale_for(destiny,
			BranchCore.deeds_of(d, picks))] = true
	t._check(reached.size() == 7, "episode 1 reaches all seven finales: %s"
		% [reached.keys()])
	t._check(all.size() == BranchCore.paths(d).size(),
		"the paths are counted the same every time")

	# Light: turned away, left the silver, signed his name.
	var light := {"backup_clue": "found", "lure_ladder": "turn_at_prilog",
		"name_on_channel": "sign"}
	t._check(BranchCore.finale_for(destiny, BranchCore.deeds_of(d, light))
		== "dawn_on_water", "turned away and signed: the dawn on the water")
	var quiet := {"backup_clue": "missed", "lure_ladder": "turn_at_prilog",
		"name_on_channel": "keep_quiet"}
	t._check(BranchCore.finale_for(destiny, BranchCore.deeds_of(d, quiet))
		== "bread_shared", "turned away in silence: bread shared")
	var waited := {"backup_clue": "missed",
		"lure_ladder": "looked_and_waited"}
	t._check(BranchCore.finale_for(destiny, BranchCore.deeds_of(d, waited))
		== "prior_waits", "looked and did not decide: the Prior waits")

	# Purification: the betrayal, the eternal copy, and the open door.
	var sold := {"backup_clue": "missed", "lure_ladder": "take",
		"return_taken": "keep", "eternal_copy": "decline"}
	t._check(BranchCore.finale_for(destiny, BranchCore.deeds_of(d, sold))
		== "bought_place", "took the silver: the bought place")
	var copy := sold.duplicate()
	copy.eternal_copy = "accept"
	t._check(BranchCore.finale_for(destiny, BranchCore.deeds_of(d, copy))
		== "endless_copy", "took and accepted the copy: the endless copy")
	var back := {"backup_clue": "missed", "lure_ladder": "take",
		"return_taken": "return"}
	var back_deeds := BranchCore.deeds_of(d, back)
	var fin := DestinyCore.finale(destiny, back_deeds)
	t._check(fin.id == "warm_water" and fin.get("repentant", false),
		"returned what he took: the door is open, the repentant's warm water")
	t._check(not "copy_of_self" in BranchCore.deeds_of(d, {"lure_ladder":
		"take", "return_taken": "return", "eternal_copy": "accept"}),
		"the copy is not offered to one who has turned back")
	t._check(not "name_yourself" in BranchCore.deeds_of(d, {"lure_ladder":
		"take", "name_on_channel": "sign"}),
		"signing the refusal is not offered to one who took")

	# Determinism: the same deeds, the same finale, in any order.
	var a := BranchCore.deeds_of(d, light)
	var b := a.duplicate()
	b.reverse()
	t._check(BranchCore.finale_for(destiny, a)
		== BranchCore.finale_for(destiny, b), "the same deeds, the same end")

	# The rules catch what they must.
	var broken: Dictionary = d.duplicate(true)
	broken.finales[0].line_ru = "Я отвернулся от серебра."
	var probs := BranchCore.check(broken, destiny)
	t._check(probs.any(func(p): return "third person" in p),
		"a first-person line is caught")
	broken = d.duplicate(true)
	broken.finales[0].line_ru = "Он ".repeat(60)
	t._check(BranchCore.check(broken, destiny).any(
		func(p): return "over 140" in p), "a line over 140 chars is caught")
	broken = d.duplicate(true)
	broken.finales[0].erase("light")
	t._check(BranchCore.check(broken, destiny).any(
		func(p): return "light class" in p), "a finale without light is caught")
	broken = d.duplicate(true)
	broken.finales[1].erase("music")
	t._check(BranchCore.check(broken, destiny).any(
		func(p): return "music" in p), "a finale without music is caught")
	broken = d.duplicate(true)
	for p in broken.choice_points:
		if p.id == "eternal_copy":
			p.options[0].deeds = []
	t._check(BranchCore.check(broken, destiny).any(
		func(p): return "endless_copy: no path" in p),
		"an unreachable finale is caught")
	broken = d.duplicate(true)
	broken.finales[1].paths.append(broken.finales[0].paths[0])
	t._check(BranchCore.check(broken, destiny).any(
		func(p): return "declared under" in p),
		"the same deeds under two finales are caught")
	broken = d.duplicate(true)
	broken.choice_points[0].beat = "khachkar"
	t._check(BranchCore.check(broken, destiny).any(
		func(p): return "holy beat" in p), "a branch at the khachkar is caught")
	broken = d.duplicate(true)
	broken.choice_points[0].options[0].consequence_ru = \
		"в награду ему открывают кайрак"
	t._check(BranchCore.check(broken, destiny).any(
		func(p): return "the holy as a consequence" in p),
		"the holy as a reward is caught")
	t._check(BranchCore.third_person("Он вернул драмы в ил.")
		and not BranchCore.third_person("Мы вернули драмы."),
		"the third person is told from the first")
