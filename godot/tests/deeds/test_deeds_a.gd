## Craft tests of group a (scripts/deeds/deeds_a.gd): the right order
## closes each act, every wrong step answers and leaves it open, and the
## same input always gives the same output.
extends RefCounted

const G := preload("res://scripts/deeds/deeds_a.gd")
const IDS := ["forge-nail", "caulk-seam", "proof-the-block",
	"rope-right-angle", "prune-vine"]


func run(t: Object) -> void:
	t._check(G.ids().size() == 5, "group a owns five acts")
	for id in IDS:
		t._check(id in G.ids(), id + ": owned by group a")
		_craft(t, id)


## The right button of the open step, found by trying each one.
func _right(id: String, s: Dictionary) -> String:
	for o in G.options(id, s):
		var n := G.choose(id, s.duplicate(true), str(o.id))
		if int(n.step) > int(s.step):
			return str(o.id)
	return ""


func _craft(t: Object, id: String) -> void:
	var s := G.start(id)
	var guard := 0
	while not s.done and guard < 20:
		guard += 1
		t._check(not G.lines(id, s).is_empty(), id + ": a step has its words")
		var right := _right(id, s)
		t._check(right != "", id + ": every open step has a right button")
		var wrong := 0
		for o in G.options(id, s):
			t._check(str(o.text) != "" and not LocationsCore.has_church_word(
				str(o.text)), id + ": plain button " + str(o.text))
			if str(o.id) == right:
				continue
			wrong += 1
			var w := G.choose(id, s.duplicate(true), str(o.id))
			t._check(str(w.reply) != "" and not w.done and w.step == s.step,
				id + ": a wrong step teaches and stays open: " + str(o.id))
			t._check(not LocationsCore.has_church_word(str(w.reply)),
				id + ": a plain reply to " + str(o.id))
			t._check(G.choose(id, s.duplicate(true), str(o.id)) == w,
				id + ": a wrong step is deterministic")
		t._check(wrong >= 1, id + ": a step offers something to tell apart")
		var before := s.duplicate(true)
		s = G.choose(id, s, right)
		t._check(str(s.reply) != "", id + ": the right step answers")
		t._check(G.choose(id, before, right) == s,
			id + ": the right step is deterministic")
	t._check(s.done, id + ": the right order closes the act")
	t._check(guard >= 3 and guard <= 6, id + ": three to six steps")
	t._check(G.options(id, s).is_empty(), id + ": a closed act offers none")
	t._check(G.choose(id, s, "anything") == s, id + ": closed stays closed")
	t._check(G.tick(id, G.start(id), 600.0, true) == G.start(id),
		id + ": no waiting in this act")
	t._check(G.choose(id, G.start(id), "no-such-button") == G.start(id),
		id + ": an unknown button changes nothing")
