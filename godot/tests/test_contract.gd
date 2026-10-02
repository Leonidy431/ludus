## The contract "The Shark of Issyk-Kul" (ContractCore): its data keeps
## the rules; the echo tells the length; a legend alone identifies
## nothing; white light or haste only sends the fish away for the night;
## a slow approach in red light takes the swab; the lab and the choice
## give the same results every time.  Called from run_hub_tests.gd.
extends RefCounted


func _ready_for_encounter(d: Dictionary) -> Dictionary:
	var s := ContractCore.start()
	for id in ["tether_nick", "scale_in_mesh", "sonar_echo", "dusk_log"]:
		s = ContractCore.add_clue(d, s, id)
	s = ContractCore.identify(d, s)
	for p in ["red_filter", "tether_sleeve", "dusk"]:
		s = ContractCore.prepare(d, s, p)
	return s


func run(t: Object) -> void:
	var d := ContractCore.load_data()
	t._check(not d.is_empty(), "contract loads")
	var bad := ContractCore.check(d)
	t._check(bad.is_empty(), "the contract keeps its rules: %s" % [bad])

	var l := ContractCore.length_from_ts(d, -26.0)
	t._check(absf(l - 1.18) < 0.02, "the echo of -26 dB is a fish of %.2f m" % l)
	t._check(ContractCore.length_from_ts(d, -26.0) < 3.0,
		"the echo is shorter than the legend's three metres")

	var s := ContractCore.start()
	s = ContractCore.add_clue(d, s, "fisher_story")
	s = ContractCore.add_clue(d, s, "net_hole")
	s = ContractCore.add_clue(d, s, "tether_nick")
	s = ContractCore.add_clue(d, s, "scale_in_mesh")
	t._check(s.stage == "identify", "four clues lead to identification")
	t._check(not ContractCore.can_identify(d, s),
		"the legend without the echo and the log identifies nothing")
	s = ContractCore.identify(d, s)
	t._check(not s.bestiary, "no bestiary entry without the measurement")

	s = ContractCore.start()
	for id in ["tether_nick", "scale_in_mesh", "sonar_echo", "dusk_log"]:
		s = ContractCore.add_clue(d, s, id)
	s = ContractCore.identify(d, s)
	t._check(s.bestiary and s.stage == "prepare", "the bestiary opens")
	for p in ["red_filter", "tether_sleeve", "white_light", "dusk"]:
		s = ContractCore.prepare(d, s, p)
	t._check(s.stage == "prepare",
		"white light takes the red filter off: not ready")
	s = ContractCore.prepare(d, s, "red_filter")
	t._check(s.stage == "encounter", "red filter, sleeve and dusk: ready")

	var r := ContractCore.encounter_step(d, s, 0.1,
		{"dist_m": 0.6, "speed_m_s": 0.8, "light_nm": 680.0})
	t._check(r.event == "fled" and r.state.nights == 1,
		"haste sends the fish away for the night, nothing breaks")
	r = ContractCore.encounter_step(d, r.state, 0.1,
		{"dist_m": 0.6, "speed_m_s": 0.1, "light_nm": 520.0})
	t._check(r.event == "fled", "white light near the fish sends it away")
	var st: Dictionary = r.state
	for i in 29:
		r = ContractCore.encounter_step(d, st, 0.1,
			{"dist_m": 0.6, "speed_m_s": 0.1, "light_nm": 680.0})
		st = r.state
	t._check(not st.sampled, "2.9 s in range is not yet a swab")
	r = ContractCore.encounter_step(d, st, 0.1,
		{"dist_m": 0.6, "speed_m_s": 0.1, "light_nm": 680.0})
	t._check(r.event == "sampled" and r.state.stage == "lab",
		"3 s slow and still in red light: the swab is taken")
	var lab := ContractCore.lab(d, r.state)
	t._check(lab.lab == ["uv_oil", "fibres", "brass_spoon"],
		"the lab gives the same three results")
	for id in ["release_tagged", "hand_over", "sell"]:
		var a := ContractCore.choose(d, lab, id)
		var b := ContractCore.choose(d, lab, id)
		t._check(a.bonus == b.bonus and a.flags == b.flags,
			"%s gives the same consequence every time" % id)
	var sold := ContractCore.choose(d, lab, "sell")
	t._check("passion:avarice" in sold.flags,
		"the sale is a step of avarice, not a reward")
	var e2 := ContractCore.choose(d, ContractCore.start(), "sell")
	t._check(e2.choice == "", "no choice before the lab")
	var r2 := _ready_for_encounter(d)
	t._check(r2.stage == "encounter", "the helper reaches the encounter")
