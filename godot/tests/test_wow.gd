## The rising curve of wow (WowCore, docs/HLD_WOW_ESCALATION_2026-10-03.md):
## the curve follows the beats of episode 1 and keeps its rules; it never
## falls but at two marked dips; the khachkar has no effect at all; no
## flash is faster than 3 Hz, and under reduced motion none flashes; each
## level has its triad with a known pulse and its reduced form; the
## level rises at least every 180 s.  The checker itself is tested on
## broken curves.  Called from run_hub_tests.gd.
extends RefCounted


## Broken curves the checker must catch, by what is broken.
const MUTANTS := {
	"fall": "a fall without why",
	"holy": "wow at the khachkar",
	"flash": "a flash faster than 3 Hz",
	"no_reduced": "a missing reduced variant",
	"pulse": "an unknown pulse",
	"turn": "a forced turn of the view",
	"stall": "a curve that does not rise for more than 180 s",
	"particles": "particles over budget",
}


func _broken(d: Dictionary, what: String) -> Array:
	var x: Dictionary = d.duplicate(true)
	match what:
		"fall":
			_beat(x, "walls").level = 2
		"holy":
			_beat(x, "khachkar").level = 6
		"flash":
			x.levels["4"].visual.flash_hz = 3.5
		"no_reduced":
			x.levels["6"].erase("reduced")
		"pulse":
			x.levels["7"].haptic.kind = "bell_rope"
		"turn":
			x.levels["6"].visual.moves_camera = true
		"stall":
			for b in x.beats:
				if float(b.t) >= 210.0 and not b.get("holy", false):
					b.level = 4
					b.erase("why")
		"particles":
			x.levels["10"].visual.particles = 999
	return WowCore.check(x, PilotCore.load_data())


func _beat(d: Dictionary, id: String) -> Dictionary:
	for b in d.beats:
		if b.id == id:
			return b
	return {}


func run(t: Object) -> void:
	var d := WowCore.load_data()
	var pilot := PilotCore.load_data()
	t._check(not d.is_empty(), "wow curve loads")
	var bad := WowCore.check(d, pilot)
	t._check(bad.is_empty(), "the wow curve keeps its rules: %s" % [bad])
	t._check(d.levels.size() == 10, "ten levels, ten effects")

	# The curve rises from the drop to the title.
	t._check(WowCore.level_at(0.0) == 1, "the drop opens at level 1")
	t._check(WowCore.level_at(899.0) >= 9 and WowCore.level_at(905.0)
		== 10, "the title closes at level 10")
	t._check(WowCore.level_at(-1.0) == 0, "nothing before the episode")
	var peak := 0
	var dips := []
	for b in d.beats:
		if b.get("holy", false):
			continue
		if int(b.level) < peak:
			dips.append(b.id)
		peak = maxi(peak, int(b.level))
	t._check(dips.size() <= 2, "at most two calm dips: %s" % [dips])

	# The khachkar: the world quiets, no effect, no pulse.
	var k := _beat(d, "khachkar")
	t._check(k.get("holy", false) and int(k.level) == 0,
		"the khachkar is level 0")
	var at_k := float(k.t) + 5.0
	t._check(WowCore.level_at(at_k) == 0
		and WowCore.effect_at(at_k).is_empty()
		and WowCore.effect_at(at_k, true).is_empty(),
		"no wow at the khachkar, reduced or not")

	# Reduced motion: another form, no flash, no ambient pulse.
	for b in d.beats:
		if b.get("holy", false):
			continue
		var full := WowCore.effect_at(float(b.t) + 0.5)
		var red := WowCore.effect_at(float(b.t) + 0.5, true)
		t._check(full.level == red.level and red.reduced,
			"%s: same level under reduced motion" % b.id)
		t._check(float(red.visual.get("flash_hz", 0.0)) == 0.0,
			"%s: no flash under reduced motion" % b.id)
		t._check(not full.visual.get("moves_camera", true)
			and not red.visual.get("moves_camera", true),
			"%s: the effect never turns the player's view" % b.id)
		var hk := str(red.haptic.kind)
		t._check(hk.is_empty() or not Haptics.spec(hk, true).is_empty(),
			"%s: the reduced pulse is felt or absent on purpose" % b.id)

	# The flicker fix: 2.5 Hz, and a smooth dip with no dark frame.
	t._check(WowCore.flash_hz(0.2) <= 3.0 and WowCore.flash_hz(0.15) > 3.0,
		"flicker 0.2 s is under 3 Hz, the old 0.15 s was not")
	var darkest := 1.0
	for i in 61:
		darkest = minf(darkest, WowCore.flicker_energy(1.0, 0.9 * i / 60.0,
			0.9, true))
	t._check(darkest >= 0.39, "reduced flicker never goes dark (%.2f)"
		% darkest)
	t._check(WowCore.flicker_energy(1.0, 0.05, 0.9) == 0.0
		and WowCore.flicker_energy(1.0, 0.25, 0.9) == 1.0,
		"full flicker: off then on at 0.2 s")
	# The tether jerk: the effect is light, sound and hands, not a turn.
	var jerk := WowCore.effect_at(300.0)
	t._check(jerk.beat == "tether_jerk" and jerk.haptic.kind == "act_wrong",
		"the jerk is felt in both hands")

	# Same second, same effect (no randomness).
	t._check(WowCore.effect_at(455.0) == WowCore.effect_at(455.0),
		"deterministic")

	# The checker catches what it must.
	for what in MUTANTS:
		t._check(not _broken(d, what).is_empty(),
			"the checker catches: " + MUTANTS[what])
