## The 24 mentors in the headset (HLD_APK_GRAPHICS_SOUND_2026-10-01,
## track B).  Called from run_hub_tests.gd: run() checks the data, the
## dialogue core against the JS reference fixture and the persons in the
## places; in_hub() checks the real hub after one frame.
##   - all 24 trees are present and each mentor has a place (a heart
##     among the 99, or the hub), none twice;
##   - each tree loads, every branch leads to a node or ends the talk,
##     every line carries meaning and source, a saint only paraphrases;
##   - FORM gating and the walks match ludus-npc-dialogue-manager.js;
##   - a choice changes only the attributes its branch declares, by
##     +1..+5, the same way every time; nothing random in the code;
##   - a mentor is a person without a light, a glow or a church word,
##     his tag seen only within 3.2 m, clear of the other things.
extends RefCounted

const FIXTURE := "res://tests/fixtures/dialogue.json"
## A mentor in the hub keeps this much room from every other thing.
const CLEAR_M := 0.75
## Mentors stand at least this far apart, so each can be walked up to.
const APART_M := 1.2
## Sources of the dialogue lines with no Russian label yet: the panel
## shows the English original for them.  An open item for the chorus
## (docs/APK_PARITY.md); the gate keeps the number from growing, and it
## is lowered as labels are added to source-labels-ru.json.
const UNLABELLED_MAX := 84

var hub: Node


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func run(t: Object) -> void:
	var trees: Dictionary = _json(Mentors.TREES).trees
	var locs: Array = _json(Mentors.LOCATIONS).locations
	t._check(trees.size() == 24, "24 trees (%d)" % trees.size())
	_places(t, trees, locs)
	_trees(t, trees)
	_parity(t)
	_bonuses(t, trees)
	_no_randomness(t)
	_closed(t, trees)
	_labels(t, trees)
	_js_number(t)
	_persons(t, locs)
	hub = (load("res://scenes/hub.tscn") as PackedScene).instantiate()
	(t as SceneTree).root.add_child(hub)


## Each of the 24 stands somewhere, and only once: in the hub or at the
## heart of his places.  The four of the gates stay in the hub.
func _places(t: Object, trees: Dictionary, locs: Array) -> void:
	var pl := Mentors.places(trees, locs)
	t._check(pl.size() == 24, "a place for every mentor (%d)" % pl.size())
	var in_hub := 0
	for id in pl:
		var p: Dictionary = pl[id]
		var hub_at = p.hub
		t._check(hub_at != null or not p.places.is_empty(),
			id + " stands somewhere")
		t._check(hub_at == null or p.places.is_empty(),
			id + " stands in one kind of place, not in both")
		in_hub += int(hub_at != null)
		for lid in p.places:
			for loc in locs:
				if loc.id == lid:
					var h: Dictionary = loc.heart
					t._check(h.get("step", "") == "dialogue",
						"%s: %s is a talk" % [id, lid])
					t._check(not DialogueCore.node_of(trees[id],
						h.get("node")).is_empty(), "%s: %s opens node %s"
						% [id, lid, h.get("node")])
	for m in Mentors.GATE_MENTORS:
		t._check(Mentors.HUB_AT.has(m), m + " of the gates in the hub")
	for m in HubCore.MENTORS:
		t._check(m in Mentors.GATE_MENTORS, m + " is a gate mentor")
	t._check(in_hub == Mentors.HUB_AT.size(), "hub mentors %d" % in_hub)
	print("mentors: %d in the hub, %d in places" % [in_hub,
		pl.size() - in_hub])
	# The tags carry no church word (TABOO 0.39 p. 3, 0.013 p. 6).
	for m in Mentors.HUB_TAG:
		t._check(not LocationsCore.has_church_word(Mentors.HUB_TAG[m]),
			m + " tag has no church word: " + Mentors.HUB_TAG[m])
		t._check(Mentors.HUB_AT.has(m), m + " tag belongs to a hub mentor")
	for id in trees:
		t._check(Mentors.DRESS.has(id), id + " has a dress")


func _trees(t: Object, trees: Dictionary) -> void:
	for id in trees:
		var raw: Dictionary = trees[id]
		var tree := DialogueCore.normalise_tree(raw, id)
		t._check(not tree.is_empty(), id + " tree loads")
		t._check(tree.get("startNode") == raw.get("startNode"),
			id + " starts where the data says")
		var idiom: Dictionary = raw.get("idiom", {})
		for k in ["worldview", "craft", "images", "metaphors", "silence"]:
			t._check(idiom.has(k), "%s idiom has %s" % [id, k])
		for n in raw.nodes:
			var where: String = id + "/" + str(n.id)
			t._check(str(n.get("meaning", "")) != ""
				and str(n.get("source", "")) != "",
				where + " meaning and source")
			t._check(str(n.get("text_ru", "")) != "", where + " text_ru")
			if id in Mentors.SAINTS:
				t._check(n.get("voice") == "paraphrase",
					where + " a saint speaks in paraphrase")
				t._check(DialogueCore.voice_line(n).begins_with(
					"Пересказ"), where + " the panel says paraphrase")
			for b in n.branches:
				var nxt = b.get("nextNodeId")
				t._check(nxt == null or not DialogueCore.node_of(tree,
					nxt).is_empty(), "%s -> %s" % [where, nxt])


## The JS reference: normalisation, open branches per node and FORM,
## the walks, the refusal of a locked branch with its missing minimums.
func _parity(t: Object) -> void:
	var fx: Dictionary = _json(FIXTURE)
	var pack: Dictionary = _json(Mentors.TREES).trees.duplicate()
	pack["fixture_bad"] = fx.bad_tree
	var cases := 0
	for id in fx.trees:
		var want: Dictionary = fx.trees[id]
		var tree := DialogueCore.normalise_tree(pack.get(id), id)
		t._check(tree.get("startNode") == want.startNode,
			"%s start %s vs %s" % [id, tree.get("startNode"),
				want.startNode])
		t._check(tree.get("nodes", []).size() == want.nodes.size(),
			id + " node count")
		for i in mini(tree.get("nodes", []).size(), want.nodes.size()):
			var a: Dictionary = tree.nodes[i]
			var w: Dictionary = want.nodes[i]
			t._check(a.id == w.id, "%s node %d id" % [id, i])
			t._check(a.branches.size() == w.branches.size(),
				"%s/%s branch count" % [id, a.id])
			for j in mini(a.branches.size(), w.branches.size()):
				var ab: Dictionary = a.branches[j]
				var wb: Dictionary = w.branches[j]
				t._check(_same(ab.condition, wb.condition),
					"%s/%s/%d condition %s vs %s" % [id, a.id, j,
						ab.condition, wb.condition])
				t._check(_same(ab.attributeBonuses, wb.attributeBonuses),
					"%s/%s/%d bonuses %s vs %s" % [id, a.id, j,
						ab.attributeBonuses, wb.attributeBonuses])
				t._check(ab.nextNodeId == wb.nextNodeId,
					"%s/%s/%d next" % [id, a.id, j])
		for pname in want.profiles:
			var pr: Dictionary = want.profiles[pname]
			for nid in pr.open:
				var got := DialogueCore.available(DialogueCore.node_of(tree,
					nid), pr.start)
				t._check(_same(got, pr.open[nid]), "%s/%s open @%s %s vs %s"
					% [id, nid, pname, got, pr.open[nid]])
				cases += 1
			var form: Dictionary = pr.start.duplicate()
			var node := DialogueCore.node_of(tree, tree.startNode)
			for step in pr.walk:
				t._check(node.get("id") == step.node, "%s walk @%s at %s"
					% [id, pname, step.node])
				var avail := DialogueCore.available(node, form)
				t._check(_same(avail, step.open), "%s walk open @%s %s"
					% [id, pname, step.node])
				if step.refused != null:
					var r := DialogueCore.choose(form, node,
						int(step.refused.index))
					t._check(not r.ok and r.locked, "%s locked %s/%d"
						% [id, step.node, step.refused.index])
					t._check(_same(r.missing, step.refused.missing),
						"%s missing %s vs %s" % [id, r.missing,
							step.refused.missing])
				if step.chose == null:
					break
				var res := DialogueCore.choose(form, node, int(step.chose))
				t._check(res.ok, "%s choose %s/%d" % [id, step.node,
					step.chose])
				t._check(_same(res.bonuses, step.bonuses), "%s bonuses %s/%d"
					% [id, step.node, step.chose])
				t._check(res.next == step.next and res.complete
					== step.complete, "%s next %s/%d" % [id, step.node,
						step.chose])
				form = res.form
				t._check(_same(form, step.form), "%s form after %s"
					% [id, step.node])
				node = DialogueCore.node_of(tree, res.next)
				cases += 1
	print("dialogue parity: %d cases over %d trees" % [cases,
		fx.trees.size()])


## Numbers compare by value (JSON has no int/float), arrays and maps
## element by element.
func _same(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	return a == b


## The data declares only +1..+5 on the seven attributes, so nothing is
## clamped away; a choice adds exactly that and touches nothing else, and
## the same choice gives the same form.
func _bonuses(t: Object, trees: Dictionary) -> void:
	var start := HubCore.new_form()
	for id in trees:
		for n in trees[id].nodes:
			for b in n.branches:
				var raw: Dictionary = b.get("attributeBonuses", {})
				for a in raw:
					t._check(a in DialogueCore.ATTRIBUTES and int(raw[a]) >= 1
						and int(raw[a]) <= 5, "%s/%s bonus %s=%s in +1..+5"
						% [id, n.id, a, raw[a]])
				var r1 := HubCore.choose(start, b)
				var r2 := HubCore.choose(start, b)
				t._check(_same(r1.form, r2.form), "%s/%s same choice, same form"
					% [id, n.id])
				for a in DialogueCore.ATTRIBUTES:
					var d := int(r1.form[a]) - int(start[a])
					t._check(d == int(raw.get(a, 0)), "%s/%s %s changes by %d"
						% [id, n.id, a, d])
				t._check(r1.form.size() == start.size(),
					"%s/%s no new attribute" % [id, n.id])
	# A non-attribute bonus and an out-of-range one never reach FORM.
	var bad := HubCore.choose(start, {"attributeBonuses": {"ethos": 3,
		"wisdom": 9, "faith": -2}})
	t._check(bad.form.size() == 7 and int(bad.form.wisdom) == 6
		and int(bad.form.faith) == 1, "bonus clamped to +5, ethos dropped")


## The closed line names only the growth the teaching asks for: never
## Cunning (its branches are the favour-seeking requests, whose cost is
## that the deeper talk stays closed), and its wording does not depend
## on the gender or the number of the attributes named.
func _closed(t: Object, trees: Dictionary) -> void:
	var start := HubCore.new_form()
	var kas: Dictionary = trees.kassiani
	var line := DialogueCore.closed_line(HubCore.node_of(kas,
		kas.startNode), start)
	t._check(line.begins_with("Ещё закрыто, нужно: "),
		"kassiani start: closed line wording: " + line)
	t._check(not line.contains("Хитрость"),
		"kassiani start: no Cunning to grow: " + line)
	var named := 0
	for id in trees:
		for n in trees[id].nodes:
			var l := DialogueCore.closed_line(n, start)
			t._check(not l.contains("Хитрость") and not l.contains("нужна "),
				"%s/%s closed line: %s" % [id, n.id, l])
			named += int(l != "")
	t._check(named > 0, "closed lines shown on a new FORM (%d)" % named)
	# A branch gated by Cunning is left out even when it alone is closed.
	var only_cunning := {"branches": [{"condition": {"cunning": 3}}]}
	t._check(DialogueCore.closed_line(only_cunning, start) == "",
		"a Cunning gate alone gives no closed line")


## The Russian labels of the dialogue sources: the unlabelled ones do
## not grow in number.
func _labels(t: Object, trees: Dictionary) -> void:
	var seen := {}
	var missing := 0
	for id in trees:
		for n in trees[id].nodes:
			var src := str(n.get("source", ""))
			if src == "" or seen.has(src):
				continue
			seen[src] = true
			missing += int(SourceLabels.ru(src) == src)
	print("dialogue sources: %d, without a Russian label %d" % [seen.size(),
		missing])
	t._check(missing <= UNLABELLED_MAX, "unlabelled sources %d <= %d"
		% [missing, UNLABELLED_MAX])


## Number() of the JS for the values JSON can carry.
func _js_number(t: Object) -> void:
	var cases := [[5, 5.0], [2.5, 2.5], [null, 0.0], [true, 1.0],
		[false, 0.0], ["5", 5.0], [" 2 ", 2.0], ["", 0.0], ["2.5", 2.5],
		[[], 0.0], [[3], 3.0], [["7"], 7.0], [[null], 0.0]]
	for c in cases:
		t._check(is_equal_approx(DialogueCore.js_number(c[0]), c[1]),
			"Number(%s) = %s" % [c[0], c[1]])
	for v in ["x", [1, 2], {}]:
		t._check(is_nan(DialogueCore.js_number(v)), "Number(%s) is NaN" % [v])
	# A fractional FORM value is kept when a bonus is added, as in the
	# game; a whole one stays whole.
	var f: Dictionary = DialogueCore.apply({"wisdom": 6.5, "faith": 2},
		{"attributeBonuses": {"wisdom": 1, "faith": 2}}).form
	t._check(is_equal_approx(f.wisdom, 7.5) and f.faith is int
		and f.faith == 4, "apply keeps 6.5 + 1 = 7.5, 2 + 2 = 4: %s" % f)


func _no_randomness(t: Object) -> void:
	for path in ["res://scripts/dialogue_core.gd", "res://scripts/mentors.gd"]:
		var src := FileAccess.get_file_as_string(path)
		for w in ["randi", "randf", "RandomNumberGenerator", "Time.",
				"OS.get_ticks"]:
			t._check(not src.contains(w), "%s has no %s" % [path, w])


## A mentor in a place stands at its heart as a person (one joined
## mesh, no light under it) with his tag seen only near.
func _persons(t: Object, locs: Array) -> void:
	var data := LocationCore.load_data()
	var items := LocationCore.load_items()
	var kits := LocationCore.load_kits()
	var seen := {}
	for loc in locs:
		var npc := str(loc.heart.get("npc", ""))
		if npc == "" or seen.has(npc):
			continue
		seen[npc] = true
		var p := LocationCore.plan(loc, data.things, items, kits)
		var world := LocationBuild.build(p)
		var person := world.get_node_or_null("Person")
		t._check(person is MeshInstance3D, "%s: %s stands at the heart"
			% [loc.id, npc])
		if person:
			t._check(person.find_children("*", "Light3D", true,
				false).is_empty(), loc.id + ": the person has no light")
			var m = (person as MeshInstance3D).mesh
			for s in m.get_surface_count() if m else 0:
				var mat = (person as MeshInstance3D).get_active_material(s)
				t._check(not (mat is BaseMaterial3D and mat.emission_enabled),
					loc.id + ": the person does not glow")
			var at: Vector3 = p.heart
			var bb := (person as MeshInstance3D).get_aabb()
			t._check(bb.size.y > 1.6 and bb.size.y < 1.95,
				"%s: a person's height (%.2f)" % [loc.id, bb.size.y])
			t._check(absf(bb.get_center().x - at.x) < 0.3,
				loc.id + ": at the heart")
		var tag := world.get_node_or_null("PersonName") as Label3D
		t._check(tag != null and is_equal_approx(tag.visibility_range_end,
			Mentors.TAG_RANGE_M), loc.id + ": tag seen only within 3.2 m")
		world.free()
	print("mentors in places: %d built" % seen.size())


## The real hub: every hub mentor is an interactable with his tag, the
## mentors stand apart and clear of the other things, and none glows.
func in_hub(t: Object) -> void:
	var mentors := {}
	for th in hub.things:
		if th.kind == "mentor":
			mentors[th.id] = th
	t._check(mentors.size() == Mentors.HUB_AT.size(),
		"hub mentors present (%d)" % mentors.size())
	for id in Mentors.HUB_AT:
		t._check(mentors.has(id), id + " talks in the hub")
	for id in mentors:
		var at := Vector2(mentors[id].pos.x, mentors[id].pos.z)
		t._check(hub.BOUNDS.has_point(at), id + " in the yard")
		for th in hub.things:
			if th.id == id:
				continue
			var d := at.distance_to(Vector2(th.pos.x, th.pos.z))
			var need := APART_M if th.kind == "mentor" else CLEAR_M
			t._check(d >= need, "%s clear of %s (%.2f m)" % [id, th.id, d])
		# The way from the courtyard to the pier stays open.
		t._check(not (at.x > -1.0 and at.x < 9.0 and absf(at.y) < 1.2),
			id + " off the way to the pier")
	# Each hub mentor is the one the player reaches from the yard side:
	# a gate mentor from a step east of him (his approach from the yard
	# is free), a guest from a step towards the yard's centre; the point
	# is not inside another mentor.
	var keep: Vector3 = hub.pos
	for id in Mentors.HUB_AT:
		var p: Vector3 = Mentors.HUB_AT[id]
		var step := Vector3(0.8, 0, 0)
		if not id in Mentors.GATE_MENTORS:
			step = (Mentors.YARD_CENTRE - p).normalized() * 0.8
		hub.pos = p + step
		for o in Mentors.HUB_AT:
			if o != id:
				t._check(Vector2(hub.pos.x - Mentors.HUB_AT[o].x,
					hub.pos.z - Mentors.HUB_AT[o].z).length() >= 0.5,
					"%s: the approach is not inside %s" % [id, o])
		var near: Dictionary = hub._nearest()
		t._check(near.get("id", "") == id, "%s reached from the yard (%s)"
			% [id, near.get("id", "")])
		# A gate mentor has no guest between him and the yard: nothing
		# else stands within 2.2 m east of him on his line.
		if id in Mentors.GATE_MENTORS:
			for o in Mentors.HUB_AT:
				var q: Vector3 = Mentors.HUB_AT[o]
				t._check(o == id or not (q.x > p.x and q.x < p.x + 2.2
					and absf(q.z - p.z) < 0.7), "%s: %s stands in front"
					% [id, o])
	hub.pos = keep
	var tags := 0
	for c in hub.find_children("MentorName*", "Label3D", true, false):
		tags += 1
		t._check(is_equal_approx(c.visibility_range_end,
			Mentors.TAG_RANGE_M), c.text + ": seen only within 3.2 m")
		t._check(not LocationsCore.has_church_word(c.text),
			c.text + ": no church word")
	t._check(tags == Mentors.HUB_AT.size(), "a tag per hub mentor (%d)"
		% tags)
	for c in hub.find_children("Mentor_*", "Node3D", true, false):
		t._check(c.find_children("*", "Light3D", true, false).is_empty(),
			c.name + " carries no light")
	# A talk in the hub: the panel names the voice and the source.
	hub.talk = {"npc": "gregory_palamas", "node": HubCore.node_of(
		hub.trees.gregory_palamas, hub.trees.gregory_palamas.startNode),
		"choice": 0}
	hub._refresh_prompt()
	var text: String = hub.panel.text
	t._check(text.begins_with("Григорий Палама:"), "talk names the mentor")
	t._check(text.contains("Пересказ учения. Источник:"),
		"a saint's line is marked a paraphrase with its source")
	hub.talk = {}
	hub.queue_free()
