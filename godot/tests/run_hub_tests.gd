## Headless tests of the hub: godot --headless --path godot --script
## res://tests/run_hub_tests.gd.  Gates against the JS reference fixture
## (ludus-actions.js) and the shared dialogue trees.
extends SceneTree

var failures := 0
var checks := 0


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _load(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _form(w: int) -> Dictionary:
	var f := HubCore.new_form()
	f.wisdom = w
	return f


func _initialize() -> void:
	var fx: Dictionary = _load("res://tests/hub_fixture.json")
	var actions := HubCore.new_actions()
	for step in fx.steps:
		match step.op:
			"knots":
				for i in int(step.a):
					actions = HubCore.pray_knot(actions)
			"meet":
				actions = HubCore.record_meeting(actions, step.a)
			"still":
				actions = HubCore.add_stillness(actions, float(step.a))
			"gift":
				actions = HubCore.accept_gift(actions, _form(int(step.b)),
					step.a)
			"check":
				var ladder := HubCore.evaluate_ladder(_form(int(step.a)),
					actions)
				for i in ladder.size():
					var got: Dictionary = ladder[i]
					var want: Dictionary = step.ladder[i]
					_check(got.open == want.open, "%s open @W%s"
						% [want.id, step.a])
					_check(got.missing == want.missing, "%s missing %s vs %s"
						% [want.id, got.missing, want.missing])
					_check(got.ready_for_gift == want.readyForGift,
						"%s gift" % want.id)
	# The shared dialogue trees: every mentor has a tree, every branch
	# leads to a real node or ends the talk, and a walk is deterministic.
	var trees: Dictionary = _load("res://data/dialogue-trees.json").trees
	for m in HubCore.MENTORS:
		_check(trees.has(m), "tree for " + m)
	for id in trees:
		var tree: Dictionary = trees[id]
		_check(not HubCore.node_of(tree, tree.startNode).is_empty(),
			id + " start")
		for n in tree.nodes:
			_check(n.has("meaning") and n.has("source"), id + "/" + n.id
				+ " meaning+source")
			for b in n.branches:
				var nxt = b.nextNodeId
				_check(nxt == null or not HubCore.node_of(tree,
					nxt).is_empty(), id + "/" + n.id + " -> " + str(nxt))
	var walk := func(start_form: Dictionary) -> Array:
		var f := start_form.duplicate()
		var tree: Dictionary = trees["elder_sergius"]
		var node := HubCore.node_of(tree, tree.startNode)
		var path := []
		for i in 12:
			var open := HubCore.open_branches(node, f)
			if open.is_empty():
				break
			var res := HubCore.choose(f, open[0])
			f = res.form
			path.append(node.id)
			if res.next == null:
				break
			node = HubCore.node_of(tree, res.next)
		return [path, f]
	_check(walk.call(HubCore.new_form()) == walk.call(HubCore.new_form()),
		"dialogue walk deterministic")
	var high := HubCore.new_form()
	high.wisdom = 9
	_check(walk.call(high)[0] != [] , "walk moves")
	print("hub: %d checks, %d failures" % [checks, failures])
	# The path of the witness (docs/HLD_APK_PRIORITY A3).
	var before := checks
	var fails := failures
	load("res://tests/test_witness.gd").new().run(self)
	print("witness: %d checks, %d failures" % [checks - before,
		failures - fails])
	# The thresholds of the gates (HLD_TETHER_TRIALS_PASSIONS T2).
	before = checks
	fails = failures
	load("res://tests/test_trial.gd").new().run(self)
	print("trial: %d checks, %d failures" % [checks - before,
		failures - fails])
	quit(1 if failures else 0)
