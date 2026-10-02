## Locks as match-three (LockCore, TABOO 0.024): the data keeps its
## rules; the same lock gives the same board; no match at the start; a
## swap without a match spends nothing; every lock opens by a fixed play
## without a timer or a loss; the same moves give the same board.
## Called from run_hub_tests.gd.
extends RefCounted


func _play(d: Dictionary, id: String) -> Dictionary:
	var s := LockCore.start(d, id)
	for i in 400:
		if s.open:
			break
		var m := LockCore.find_move(s)
		if m.is_empty():
			break
		s = LockCore.swap(d, s, m[0], m[1])
	return s


func run(t: Object) -> void:
	var d := LockCore.load_data()
	t._check(not d.is_empty(), "locks load")
	var bad := LockCore.check(d)
	t._check(bad.is_empty(), "the locks keep their rules: %s" % [bad])
	t._check(LockCore.seed_of("rov_server") == LockCore.seed_of("rov_server")
		and LockCore.seed_of("rov_server") != LockCore.seed_of("buyer_safe"),
		"a lock's seed is its own and stable")
	var a := LockCore.start(d, "rov_server")
	var b := LockCore.start(d, "rov_server")
	t._check(a.board == b.board, "the same lock, the same board")
	t._check(LockCore.matches(a).is_empty(), "no match at the start")
	t._check(not LockCore.find_move(a).is_empty(), "a move exists")
	var same := LockCore.swap(d, a, 0, 2)
	t._check(same.moves == 0 and same.board == a.board,
		"a swap of cells that are not neighbours does nothing")
	for id in ["pult_gateway", "rov_server", "backup_drive",
			"expedition_safe", "buyer_safe"]:
		var p := _play(d, id)
		var q := _play(d, id)
		t._check(p.open, "%s opens by patient play (%d moves, %d turns)"
			% [id, p.moves, p.turns])
		t._check(p.board == q.board and p.moves == q.moves,
			"%s: the same moves, the same board" % id)
