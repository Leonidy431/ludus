## Craft tests of group e (scripts/deeds/deeds_e.gd): the right order
## closes each act, every wrong step answers and leaves it open, a wait
## counts only while still, and the same input always gives the same
## output.  A find is looked at and left, never taken.
extends RefCounted

const G := preload("res://scripts/deeds/deeds_e.gd")
const IDS := ["wait-out-storm", "spot-the-haze", "type-by-memory",
	"find:bulla.shallows.0", "find:fundament.shallows.1",
	"find:chebachok.shallows.0"]


func run(t: Object) -> void:
	t._check(G.ids().size() == 6, "group e owns six acts")
	for id in IDS:
		t._check(id in G.ids(), id + ": owned by group e")
		_craft(t, id)
	_storm_wait(t)
	_finds(t)


## The right button of the open step: the one that moves the step on.
## Empty for a waiting step, which only time moves.
func _right(id: String, s: Dictionary) -> String:
	for o in G.options(id, s):
		var n := G.choose(id, s.duplicate(true), str(o.id))
		if int(n.step) > int(s.step):
			return str(o.id)
	return ""


func _craft(t: Object, id: String) -> void:
	var s := G.start(id)
	t._check(not s.done and str(s.reply) == "", id + ": starts open")
	var guard := 0
	while not s.done and guard < 20:
		guard += 1
		t._check(not G.lines(id, s).is_empty(), id + ": a step has words")
		var right := _right(id, s)
		var waiting := right == ""
		var wrong := 0
		for o in G.options(id, s):
			t._check(str(o.text) != "" and not LocationsCore.has_church_word(
				str(o.text)), id + ": plain button " + str(o.text))
			var w := G.choose(id, s.duplicate(true), str(o.id))
			t._check(str(w.reply) != "" and not LocationsCore.has_church_word(
				str(w.reply)), id + ": a plain reply to " + str(o.id))
			t._check(G.choose(id, s.duplicate(true), str(o.id)) == w,
				id + ": deterministic " + str(o.id))
			if str(o.id) == right:
				continue
			t._check(not w.done and w.step == s.step,
				id + ": a wrong step stays open: " + str(o.id))
			wrong += 1
		t._check(wrong >= 1 or waiting,
			id + ": a step offers something to tell apart")
		if waiting:
			var a := G.tick(id, s.duplicate(true), 600.0, true)
			t._check(a.done and str(a.reply) != "",
				id + ": waiting still closes it")
			t._check(G.tick(id, s.duplicate(true), 600.0, true) == a,
				id + ": waiting is deterministic")
			s = a
		else:
			s = G.choose(id, s, right)
			t._check(str(s.reply) != "", id + ": the right step answers")
	t._check(s.done, id + ": the right order closes the act")
	t._check(guard >= 3 and guard <= 6, id + ": three to six steps")
	t._check(G.options(id, s).is_empty(), id + ": a closed act offers none")
	t._check(G.choose(id, s, "anything") == s, id + ": closed stays closed")
	t._check(G.choose(id, G.start(id), "no-such-button") == G.start(id),
		id + ": an unknown button changes nothing")
	if id != "wait-out-storm":
		t._check(G.tick(id, G.start(id), 600.0, true) == G.start(id),
			id + ": no waiting in this act")


## The storm counts seconds only while still; moving starts the
## wait again.  Words alone never close it.
func _storm_wait(t: Object) -> void:
	var id := "wait-out-storm"
	var s := G.start(id)
	s = G.choose(id, s, "read")
	s = G.choose(id, s, "haul")
	t._check(s.step == 2 and not s.done, "storm: two steps, then the wait")
	t._check(not G.choose(id, s, "wait").done, "storm: no word closes it")
	var a := G.tick(id, s, 8.0, true)
	t._check(not a.done and a.waited == 8.0, "storm: eight seconds not enough")
	var b := G.tick(id, a, 5.0, false)
	t._check(b.waited == 0.0 and not b.done, "storm: moving starts again")
	var c := G.choose(id, G.tick(id, s, 8.0, true), "wait")
	t._check(c.waited == 8.0 and not c.done,
		"storm: the waiting button keeps the wait")
	var d := G.tick(id, G.tick(id, s, 8.0, true), 8.0, true)
	t._check(d.done, "storm: standing still long enough closes it")
	t._check(G.tick(id, G.start(id), 600.0, true).step == 0,
		"storm: the early steps are not skipped by waiting")


## A find: the registry gives belt and depth, and the thing is left.
func _finds(t: Object) -> void:
	for oid in ["bulla.shallows.0", "fundament.shallows.1",
			"chebachok.shallows.0"]:
		var id: String = "find:" + oid
		var s := G.choose(id, G.start(id), "look")
		var depth: Dictionary = G.options(id, s)[1]
		t._check("мелководье" in str(depth.text) and " м" in str(depth.text),
			oid + ": the belt and depth come from the registry")
		var noted := G.choose(id, G.choose(id, s, "mark"), "scribe")
		var bag := G.choose(id, noted, "bag")
		t._check(not bag.done and str(bag.reply) != "",
			oid + ": taking it is never allowed")
		t._check(G.choose(id, noted, "leave").done,
			oid + ": leaving it closes the act")
