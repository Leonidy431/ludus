## Craft tests of group c (community acts, scripts/deeds/deeds_c.gd).
## For each act: the right order closes it, every wrong step answers
## with words and leaves it open, a step taken too soon says so, no
## text carries a church word, and the same input gives the same output.
extends RefCounted

const ACTS := {
	"separate-contract": ["read", "strike", "seal"],
	"speak-of-maker": ["greet", "listen", "speak"],
	"hear-both-sides": ["hear_b", "hear_a", "compare", "write"],
	"tell-custom-from-faith": ["take", "take", "take", "leave"],
	"teach-a-letter": ["smooth", "show", "guide", "alone"],
}
## Buttons that are wrong at every point of the act.
const ALWAYS_WRONG := {
	"separate-contract": ["seal_all", "weigh"],
	"speak-of-maker": ["join", "pour"],
	"hear-both-sides": ["cut"],
	"teach-a-letter": ["whole", "price"],
}


func run(t: Object) -> void:
	var owned: Array = load("res://scripts/deeds/deeds_c.gd").ids()
	t._check(owned.size() == 5, "group c owns five acts")
	for id in ACTS:
		t._check(PlaceDeeds.has(id), id + ": the dispatcher routes it")
		_right_order(t, id)
		_texts(t, id)
	for id in ALWAYS_WRONG:
		_always_wrong(t, id)
	_contract_order(t)
	_hearing(t)
	_feast(t)
	_letter_and_yurt(t)


## The right buttons, in order, close the act on the last one only.
func _right_order(t: Object, id: String) -> void:
	var s := PlaceDeeds.start(id)
	var seq: Array = ACTS[id]
	for i in range(seq.size()):
		t._check(not s.done, "%s: open before step %d" % [id, i])
		s = PlaceDeeds.choose(id, s, seq[i])
		t._check(str(s.reply) != "", "%s: step %d answers" % [id, i])
	t._check(s.done, id + ": the right order closes the act")
	# The same steps give the same end (no chance).
	var s2 := PlaceDeeds.start(id)
	for c in seq:
		s2 = PlaceDeeds.choose(id, s2, c)
	t._check(s == s2, id + ": same steps, same end")
	t._check(PlaceDeeds.choose(id, s, seq[0]) == s,
		id + ": a closed act stays closed")


## Every text of every state on the path: buttons, lines and replies are
## filled and plain (no church word, TABOO 0.39 item 3).
func _texts(t: Object, id: String) -> void:
	var s := PlaceDeeds.start(id)
	var seq: Array = ACTS[id]
	for i in range(seq.size() + 1):
		var body := PlaceDeeds.lines(id, s)
		t._check(not body.is_empty(),
			"%s: the panel has lines at %d" % [id, i])
		for l in body:
			t._check(str(l) != "" and not LocationsCore.has_church_word(
				str(l)), "%s: a plain panel line at %d" % [id, i])
		if s.done:
			break
		for o in PlaceDeeds.options(id, s):
			t._check(str(o.text) != "" and not LocationsCore.has_church_word(
				str(o.text)), "%s: plain button %s" % [id, o.id])
			if o.disabled:
				t._check(str(o.reason) != "", id + ": closed says why")
				continue
			var r := PlaceDeeds.choose(id, s, str(o.id))
			t._check(str(r.reply) != "" and not LocationsCore.has_church_word(
				str(r.reply)), "%s: plain reply to %s at %d" % [id, o.id, i])
			if str(o.id) != seq[i]:
				t._check(not r.done, "%s: %s does not close at %d" % [
					id, o.id, i])
		s = PlaceDeeds.choose(id, s, seq[i])


func _always_wrong(t: Object, id: String) -> void:
	var s := PlaceDeeds.start(id)
	var seq: Array = ACTS[id]
	for i in range(seq.size()):
		for w in ALWAYS_WRONG[id]:
			var r := PlaceDeeds.choose(id, s, w)
			t._check(not r.done and str(r.reply) != "",
				"%s: %s teaches at stage %d" % [id, w, i])
			t._check(r.get("step", -1) == s.get("step", -1)
				and r.get("a") == s.get("a") and r.get("cmp") == s.get("cmp"),
				"%s: %s does not move the act" % [id, w])
		if i < seq.size() - 1:
			s = PlaceDeeds.choose(id, s, seq[i])


## The contract: read first, strike the creed line, then seal; sealing
## on the raw wax or the whole sheet is the wrong craft.
func _contract_order(t: Object) -> void:
	var id := "separate-contract"
	var s := PlaceDeeds.start(id)
	var r := PlaceDeeds.choose(id, s, "strike")
	t._check(r.step == 0 and not r.done and "прочти" in r.reply,
		"contract: striking before reading is not yet")
	r = PlaceDeeds.choose(id, s, "seal")
	t._check(r.step == 0 and "печать" in r.reply.to_lower(),
		"contract: sealing the raw wax teaches")
	s = PlaceDeeds.choose(id, s, "read")
	r = PlaceDeeds.choose(id, s, "seal")
	t._check(r.step == 1 and not r.done,
		"contract: sealing before striking the creed line does not close")
	s = PlaceDeeds.choose(id, s, "strike")
	t._check(s.step == 2 and not s.done, "contract: struck, not yet sealed")
	r = PlaceDeeds.choose(id, s, "seal_all")
	t._check(not r.done and r.step == 2, "contract: the whole sheet is wrong")
	# A done step is shown closed on the panel.
	var closed := 0
	for o in PlaceDeeds.options(id, s):
		if o.disabled:
			closed += 1
	t._check(closed == 2, "contract: the two done steps are closed")


## Hear both, in either order; compare; only then write.
func _hearing(t: Object) -> void:
	var id := "hear-both-sides"
	for first in [["hear_a", "hear_b"], ["hear_b", "hear_a"]]:
		var s := PlaceDeeds.start(id)
		for c in first:
			s = PlaceDeeds.choose(id, s, c)
		s = PlaceDeeds.choose(id, s, "compare")
		s = PlaceDeeds.choose(id, s, "write")
		t._check(s.done, id + ": either side first closes it")
	var s0 := PlaceDeeds.start(id)
	var r := PlaceDeeds.choose(id, s0, "write")
	t._check(not r.done and "обоих" in r.reply,
		id + ": writing before hearing is refused")
	r = PlaceDeeds.choose(id, s0, "compare")
	t._check(not r.cmp and str(r.reply) != "",
		id + ": nothing to compare before both spoke")
	var s1 := PlaceDeeds.choose(id, s0, "hear_a")
	r = PlaceDeeds.choose(id, s1, "write")
	t._check(not r.done, id + ": one side is not enough")
	var s2 := PlaceDeeds.choose(id, s1, "hear_b")
	r = PlaceDeeds.choose(id, s2, "write")
	t._check(not r.done and "Сверь" in r.reply,
		id + ": both heard but not compared, the pen waits")
	r = PlaceDeeds.choose(id, s2, "hear_a")
	t._check(r.a and not r.done and str(r.reply) != "",
		id + ": hearing again changes nothing")


## Each gift is taken or refused by its nature; custom yes, oath no.
func _feast(t: Object) -> void:
	var id := "tell-custom-from-faith"
	var s := PlaceDeeds.start(id)
	for i in range(3):
		var r := PlaceDeeds.choose(id, s, "leave")
		t._check(r.step == i and not r.done and str(r.reply) != "",
			"%s: refusing a custom (%d) teaches" % [id, i])
		s = PlaceDeeds.choose(id, s, "take")
		t._check(s.step == i + 1, "%s: taking a custom (%d) moves on" % [
			id, i])
	var oath := PlaceDeeds.choose(id, s, "take")
	t._check(oath.step == 3 and not oath.done,
		id + ": taking the oath on the soul does not close it")
	t._check(PlaceDeeds.choose(id, s, "leave").done,
		id + ": refusing the oath closes it")
	t._check(PlaceDeeds.choose(id, s, "nonsense") == s,
		id + ": an unknown button changes nothing")


## The yurt: never into the rite.  The school: no price for a letter.
func _letter_and_yurt(t: Object) -> void:
	var y := "speak-of-maker"
	var s := PlaceDeeds.start(y)
	var r := PlaceDeeds.choose(y, s, "speak")
	t._check(r.step == 0 and not r.done, y + ": speech before sitting")
	s = PlaceDeeds.choose(y, s, "greet")
	r = PlaceDeeds.choose(y, s, "speak")
	t._check(r.step == 1 and not r.done,
		y + ": speaking before listening is not yet")
	for bad in ["join", "pour"]:
		t._check(PlaceDeeds.choose(y, s, bad).step == 1,
			y + ": the rite is not entered by " + bad)
	var l := "teach-a-letter"
	s = PlaceDeeds.start(l)
	for early in ["show", "guide", "alone"]:
		r = PlaceDeeds.choose(l, s, early)
		t._check(r.step == 0 and not r.done,
			l + ": " + early + " before the wax is smooth")
	s = PlaceDeeds.choose(l, s, "smooth")
	s = PlaceDeeds.choose(l, s, "show")
	r = PlaceDeeds.choose(l, s, "alone")
	t._check(not r.done and r.step == 2,
		l + ": letting go before guiding is too soon")
	r = PlaceDeeds.choose(l, s, "price")
	t._check("торгу" in r.reply and not r.done,
		l + ": asking a price teaches")
