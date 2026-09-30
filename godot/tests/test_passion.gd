## The meeting of a passion (PassionCore) against the JS reference
## fixture written by scripts/godot/make_passion_fixture.js from
## public/ludus/ludus-passion.js.  Every check goes through the runner's
## _check(); this file prints nothing itself.
extends RefCounted


## Deep equality as JSON sees it: numbers compare by value, so an int in
## the port equals the float that JSON parsing gives back.
func _same(a, b) -> bool:
	var num := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in num and typeof(b) in num:
		return absf(float(a) - float(b)) <= 1e-12 * maxf(1.0,
			absf(float(b)))
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		if a.size() != b.size():
			return false
		for k in b:
			if not a.has(k) or not _same(a[k], b[k]):
				return false
		return true
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if a.size() != b.size():
			return false
		for i in b.size():
			if not _same(a[i], b[i]):
				return false
		return true
	if typeof(a) != typeof(b):
		return false
	return a == b


func _load(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func run(t: Object) -> void:
	var fx: Dictionary = _load("res://tests/passion_fixture.json")
	var data: Dictionary = _load("res://data/passions.json")
	var manifest: Array = fx.manifest
	var by_id := {}
	for p in data.passions:
		by_id[p.id] = p
	t._check(_same(PassionCore.STAGES, fx.stages), "stages")
	t._check(data.order.size() == 8, "eight passions on the road")

	for c in fx.cases:
		var passion: Dictionary = by_id[c.passion]
		var tag := "%s form=%s actions=%s" % [c.passion, c.form, c.actions]
		t._check(PassionCore.can_name(passion, c.form, c.actions)
			== c.canName, "can_name " + tag)
		var st := PassionCore.start(passion)
		t._check(_same(st, c.start), "start " + tag)
		for stage in c.options:
			var s := st.duplicate()
			s.stage = stage
			var got := PassionCore.options(s, passion, c.form, c.actions)
			t._check(_same(got, c.options[stage]), "options %s @%s: %s"
				% [tag, stage, got])
		for w in c.walks:
			var s := PassionCore.start(passion)
			for id in w.ids:
				s = PassionCore.choose(s, id, passion, c.form, c.actions)
			var path := "%s %s" % [tag, w.ids]
			t._check(_same(s, w.state), "walk %s: %s" % [path, s])
			for id in w.refused:
				var same := PassionCore.choose(s, id, passion, c.form,
					c.actions)
				t._check(same == s and is_same(same, s),
					"refused %s at %s" % [id, path])
			if w.has("finish_empty"):
				var prior := {c.passion: {"meetings": 3, "overcome": 1,
					"captive": 1, "discerned": true},
					"other": {"meetings": 1}}
				for pair in [[{}, w.finish_empty], [prior,
						w.finish_prior]]:
					var res := PassionCore.finish(pair[0], s)
					var want: Dictionary = pair[1]
					t._check(_same(res.record, want.record),
						"finish record %s: %s" % [path, res.record])
					t._check(_same(res.attribute_bonuses,
						want.attributeBonuses), "finish bonus %s: %s"
						% [path, res.attribute_bonuses])

	for n in fx.normalize:
		var got := PassionCore.normalize_record(n.raw)
		t._check(_same(got, n.out), "normalize %s: %s" % [n.raw, got])

	for sp in fx.sprites:
		var entry: Dictionary = by_id[sp.passion] if sp.passion != null \
			else sp.entry
		var got = PassionCore.sprite_for(entry, sp.record, manifest)
		t._check(_same(got, sp.sprite), "sprite %s %s: %s" % [entry.id,
			sp.record, got])
	# Without the factory's manifest no sprite is chosen, as in the web
	# game before the factory script arrives.
	t._check(PassionCore.sprite_for(by_id["gluttony"], {}) == null,
		"no manifest, no sprite")
	t._check(PassionCore.sprite_for(null, {}, manifest) == null,
		"no passion, no sprite")
	# The same sprite is never shown twice in a row (TABOO 0.3 rule 53).
	for id in by_id:
		var prev := ""
		for n in 40:
			var s = PassionCore.sprite_for(by_id[id], {id: {"meetings": n}},
				manifest)
			t._check(s.src != prev, "%s meeting %d repeats" % [id, n])
			prev = s.src

	for nx in fx.next:
		var d: Dictionary = data.duplicate(true)
		var got = PassionCore.next_passion(d, nx.record, manifest)
		t._check(_same(got, nx.passion), "next %s: %s" % [nx.record,
			got.id if got != null else null])
		if got != null:
			# The entry of the data itself carries the sprite.
			var inside = null
			for p in d.passions:
				if p.id == got.id:
					inside = p
			t._check(is_same(inside, got), "next %s is the data entry"
				% got.id)
