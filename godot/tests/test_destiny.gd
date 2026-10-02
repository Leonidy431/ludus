## Destiny (DestinyCore): seven branches on the seven attributes, seven
## finales from closer to hell to closer to paradise, chosen by deeds and
## the same every time; repentance lifts any path above the darkest
## finales; nothing on screen is fire or torment.  Called from
## run_hub_tests.gd.
extends RefCounted


func run(t: Object) -> void:
	var d := DestinyCore.load_data()
	t._check(not d.is_empty(), "destiny loads")
	var bad := DestinyCore.check(d)
	t._check(bad.is_empty(), "destiny keeps its rules: %s" % [bad])

	var worst := ["stage:captive", "drams_taken", "contract:sell",
		"sell_diary", "copy_of_self"]
	var best := ["stage:virtue", "drams_left", "clue:backup",
		"contract:release_tagged", "lock:expedition_safe", "share_battery",
		"return_diary", "forgive_traitor", "name_yourself"]
	t._check(DestinyCore.finale(d, worst).id == "endless_copy",
		"the worst path ends in the endless copy")
	t._check(DestinyCore.finale(d, best).id == "dawn_on_water",
		"sacrifice and forgiveness end in the dawn on the water")
	t._check(DestinyCore.finale(d, []).id == "prior_waits",
		"no deed: the Prior waits")
	t._check(DestinyCore.finale(d, ["stage:virtue", "drams_left"]).id
		== "witness", "a small good path: the witness")
	t._check(DestinyCore.finale(d, ["drams_taken"]).id == "warm_water",
		"a small fall: warm water")
	t._check(DestinyCore.finale(d, ["stage:captive", "contract:sell",
		"drams_taken"]).id == "bought_place", "avarice: the bought place")
	t._check(DestinyCore.finale(d, ["share_battery", "contract:hand_over",
		"stage:virtue"]).id == "bread_shared", "mercy: bread shared")

	var turned := worst + ["repent"]
	t._check(DestinyCore.band(d, turned) >= -1,
		"repentance lifts even the worst path (band %d)"
		% DestinyCore.band(d, turned))
	t._check(DestinyCore.finale(d, worst).id
		== DestinyCore.finale(d, worst).id, "the same deeds, the same end")
	t._check(DestinyCore.score(d, ["drams_left", "drams_left"])
		== DestinyCore.score(d, ["drams_left"]), "a deed counts once")

	var form := {"wisdom": 6, "faith": 3, "cunning": 0, "erudition": 12}
	var nodes := DestinyCore.open_nodes(d, form)
	t._check("w1" in nodes and "w2" in nodes and not "w3" in nodes,
		"wisdom 6 opens two nodes of its branch")
	t._check("e4" in nodes and not "u1" in nodes,
		"erudition 12 opens its last node; cunning 0 opens none")
	var seen := {}
	for f in d.finales:
		seen[f.id] = true
	t._check(seen.size() == 7, "seven distinct finales")
