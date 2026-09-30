## The two practices of the rule that the hub gives a place
## (docs/HLD_EVENING_WATCH_ROPE_2026-09-30.md): the cell of the evening
## watch over thoughts and the prayer rope on its lectern, kept in the
## pace of the breath.  hub.gd draws the panels and reads the controls;
## the rules are RuleCore, RopeCore and TrialCore, and this file only
## builds the cell and words the panels, so hub.gd stays small.
##
## Words: the watch speaks the idiom of a watchman on the wall (TABOO
## 0.39); no church term is a label.  The rope's count is shown and
## nothing else: no score, no streak, no bonus (TABOO 0.35 rule 16).
class_name RuleCell
extends RefCounted

## Deep enough in the cell that the mentors of the scriptorium are out
## of reach from here.
const WATCH_AT := Vector3(-5.0, 0, -6.8)
const ROPE_AT := Vector3(-3.0, 1.13, 3.2)
const ROPE_KNOTS := 33
## A clay oil lamp for reading at night: the hearth class of light, a
## human work light (about 1900 K), not the lampada of a holy thing
## (TABOO 0.38 point 1).
const LAMP_K := Color(1.0, 0.56, 0.22)
const WATCH_ID := "guard_thoughts"


## The cell in the north-west corner: a whitewashed partition, a low
## oak lectern with the book of the day's rule, a stool and the lamp.
## Returns the thing the hub can reach.
static func build(hub: Node3D, oak: Color) -> Dictionary:
	var white := Color(0.9, 0.87, 0.8)
	hub._box(Vector3(0.2, 2.4, 3.2), Vector3(-3.3, 1.2, -7.1), white)
	hub._box(Vector3(0.3, 0.2, 3.3), Vector3(-3.3, 2.45, -7.1), oak)
	hub._box(Vector3(0.12, 1.0, 0.12), Vector3(-5.0, 0.5, -7.3), oak)
	var desk: MeshInstance3D = hub._box(Vector3(0.6, 0.05, 0.45),
		Vector3(-5.0, 1.05, -7.3), oak)
	desk.rotation_degrees = Vector3(-20, 0, 0)
	hub._box(Vector3(0.44, 0.02, 0.3), Vector3(-5.0, 1.09, -7.28),
		Color(0.93, 0.88, 0.76))
	hub._box(Vector3(0.4, 0.45, 0.4), Vector3(-4.2, 0.22, -7.0), oak)
	var lamp: MeshInstance3D = hub._box(Vector3(0.12, 0.06, 0.08),
		Vector3(-4.62, 1.1, -7.35), Color(0.6, 0.36, 0.22))
	lamp.material_override.emission_enabled = true
	lamp.material_override.emission = LAMP_K
	lamp.material_override.emission_energy_multiplier = 0.6
	var light := OmniLight3D.new()
	light.light_color = LAMP_K
	light.light_energy = 0.9
	light.omni_range = 3.0
	light.position = Vector3(-4.62, 1.25, -7.3)
	hub.add_child(light)
	return {"id": "watch", "kind": "watch", "pos": WATCH_AT,
		"ru": "Келья: вечерний дозор над помыслами"}


## The rope lying on the lectern of the courtyard: thirty-three knots of
## dark wool in a ring and a tassel.  Our own drawing (TABOO 0.35 rule
## 6: nothing of the rule is taken from raw material).  The hub turns
## the ring by one knot when a knot is tied, so the hand sees it pass.
static func build_rope(hub: Node3D) -> Node3D:
	var ring := Node3D.new()
	ring.position = ROPE_AT
	hub.add_child(ring)
	var wool := StandardMaterial3D.new()
	wool.albedo_color = Color(0.12, 0.1, 0.09)
	wool.roughness = 1.0
	var knot := SphereMesh.new()
	knot.radius = 0.011
	knot.height = 0.02
	knot.radial_segments = 8
	knot.rings = 4
	for i in ROPE_KNOTS:
		var a := TAU * i / ROPE_KNOTS
		var k := MeshInstance3D.new()
		k.mesh = knot
		k.material_override = wool
		k.position = Vector3(cos(a) * 0.1, 0, sin(a) * 0.1)
		ring.add_child(k)
	var tassel := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.004
	tm.bottom_radius = 0.018
	tm.height = 0.06
	tassel.mesh = tm
	tassel.material_override = wool
	tassel.position = Vector3(0, 0, 0.14)
	tassel.rotation_degrees = Vector3(90, 0, 0)
	ring.add_child(tassel)
	return ring


static func _yes(v: bool) -> String:
	return "да" if v else "ещё нет"


## The watch: the charter of the practice, today's state, the tally
## (shown, never paid), and, after a fall, what lifts it.
static func watch_lines(actions: Dictionary, day: String, fs: Dictionary,
		teacher_ru: String) -> Array:
	var pr := RuleCore.practice(WATCH_ID)
	var kept := RuleCore.kept_today(actions, WATCH_ID, day)
	var tally := RuleCore.practice_tally(actions, WATCH_ID)
	var lines := [pr.ru, "",
		"Обойди прожитый день, как сторож обходит стену в сумерки: кто "
		+ "стучал в ворота, кого ты впустил, кого прогнал. Не суди, "
		+ "замечай: сторож не воюет, он не спит.",
		"Против блудного помысла; хранит целомудрие. Источник: Лествица, "
		+ "слова 15 и 26.", "",
		"Сегодня: %s. Дозоров: %s." % ["держан" if kept else "не держан",
			tally.text_ru]]
	if fs.get("fallen", false):
		lines += ["", "Свет потускнел: %s. Признак: %s" % [fs.passion_ru,
			fs.cue],
			"Трезвение: %s · беседа с наставником (%s): %s." % [
				_yes(fs.sober), teacher_ru, _yes(fs.taught)]]
	lines.append("")
	return lines


static func watch_choices(actions: Dictionary, day: String) -> Array:
	var kept := RuleCore.kept_today(actions, WATCH_ID, day)
	return [{"id": "keep", "text": "Держать дозор", "disabled": kept,
		"reason": "сегодня дозор уже держан"},
		{"id": "away", "text": "Отойти", "disabled": false, "reason": ""}]


static func rope_lines(rope: Dictionary, actions: Dictionary) -> Array:
	var p: Dictionary = RopeCore.BREATH[rope.pattern]
	var ph := RopeCore.phase_at(rope.pattern, rope.clock)
	var parts := ["вдох %s с" % _s(p.inhale)]
	if p.hold_in > 0.0:
		parts.append("задержка %s" % _s(p.hold_in))
	parts.append("выдох %s" % _s(p.exhale))
	if p.hold_out > 0.0:
		parts.append("тишина %s" % _s(p.hold_out))
	return ["Вервица", "",
		"Узел — на выдохе: одно дыхание, одна молитва, один узел.",
		"Дыхание %s: %s." % [RopeCore.RU[rope.pattern], ", ".join(parts)],
		"", "Сейчас: %s · %d с" % [RopeCore.PHASE_RU[ph.phase].to_upper(),
			ceili(ph.left)],
		"Узлов: %d" % int(actions.get("prayerCount", 0)), ""]


static func _s(v: float) -> String:
	return ("%d" % int(v)) if is_equal_approx(v, roundf(v)) \
		else ("%.1f" % v).replace(".", ",")


static func rope_choices(rope: Dictionary) -> Array:
	var nxt: String = RopeCore.ORDER[posmod(RopeCore.ORDER.find(
		rope.pattern) + 1, RopeCore.ORDER.size())]
	return [{"id": "knot", "text": "Завязать узел", "disabled": false,
		"reason": ""},
		{"id": "turn", "text": "Сменить дыхание: " + RopeCore.RU[nxt],
			"disabled": false, "reason": ""},
		{"id": "away", "text": "Отложить вервицу", "disabled": false,
			"reason": ""}]


static func choice_lines(choices: Array, current: int) -> Array:
	var out := []
	for j in choices.size():
		var c: Dictionary = choices[j]
		var line := "%s%d. %s" % ["▸ " if j == current else "  ", j + 1,
			c.text]
		if c.disabled and c.reason != "":
			line += "  (%s)" % c.reason
		out.append(line)
	return out
