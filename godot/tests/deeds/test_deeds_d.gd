## The craft of group d of the place acts (road and memory): for each act
## the right order closes it, every wrong step answers with a line and
## leaves it open, and the same step gives the same state.  The contract
## shared by all acts is in tests/test_place_deeds.gd.
extends RefCounted

const D := "res://scripts/deeds/deeds_d.gd"
## The right way through every act, by a distinctive part of each button.
const PATHS := {
	"lay-a-stone": ["одной рукой", "Сбоку", "не считать"],
	"seal-the-chronicle": ["Сверить каждую", "высохнуть", "кожей"],
	"find-pole-star": ["Ковш", "визир", "компасом"],
	"tell-only-true": ["видел сам", "пять с половиной", "не видел"],
	"compare-forms": ["Снять обвод", "встречает преграду",
		"железо служит"],
}


func _press(g: Script, id: String, s: Dictionary, part: String) -> Dictionary:
	for o in g.call("options", id, s):
		if str(o.text).contains(part):
			return g.call("choose", id, s.duplicate(true), str(o.id))
	return {}


func run(t: Object) -> void:
	var g: Script = load(D)
	var mine: Array = g.call("ids")
	t._check(mine.size() == PATHS.size(), "group d owns its five acts")
	for id in PATHS:
		t._check(id in mine and PlaceDeeds.has(id), id + ": has logic")
		var s: Dictionary = g.call("start", id)
		var path: Array = PATHS[id]
		for k in path.size():
			t._check(not s.done, "%s: open before step %d" % [id, k])
			var count := 0
			# Every wrong button answers, stays open, stays at this step.
			for o in g.call("options", id, s):
				count += 1
				if str(o.text).contains(path[k]):
					continue
				var nxt: Dictionary = g.call("choose", id, s.duplicate(true),
					str(o.id))
				t._check(str(nxt.get("reply", "")) != ""
					and not nxt.done and nxt.step == s.step,
					"%s: wrong step %d answers and stays: %s" % [id, k,
						o.text])
				t._check(not LocationsCore.has_church_word(nxt.reply),
					"%s: the reply has plain words" % id)
				t._check(g.call("choose", id, s.duplicate(true),
					str(o.id)) == nxt, id + ": no chance in a wrong step")
			t._check(count >= 2, id + ": a step offers a choice")
			var before := s.duplicate(true)
			s = _press(g, id, s, path[k])
			t._check(not s.is_empty() and s != before,
				"%s: the right step %d moves on" % [id, k])
		t._check(s.done and str(s.reply) != "",
			id + ": the right order closes it and names the lesson")
		t._check(g.call("options", id, s).is_empty(),
			id + ": a closed act offers nothing")
		t._check(g.call("lines", id, s).size() == 1,
			id + ": a closed act shows what was learned")
		t._check(g.call("tick", id, s, 600.0, true) == s,
			id + ": waiting changes nothing")
		# A right button of a later step does not work at the first.
		var first: Dictionary = g.call("start", id)
		var skip := _press(g, id, first, PATHS[id][1])
		t._check(skip.is_empty() or (not skip.done and skip.step == 0),
			id + ": the second step's button does not work at the first")
		t._check(g.call("choose", id, first, "o99") == first
			and g.call("choose", id, first, "x") == first,
			id + ": an unknown button changes nothing")
