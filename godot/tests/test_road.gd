## The road beyond the wicket (HLD_TETHER_TRIALS_PASSIONS T3): every
## sprite the antagonist manifest can pick is in the build, every
## passion can be met, and a meeting ends with no reward but the one
## +1 Wisdom for discerning at the first stage.  Called from
## run_hub_tests.gd.
extends RefCounted


func run(t: Object) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/passions.json"))
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/antagonist-manifest.json")).manifest
	var files := 0
	for o in manifest:
		for v in o.variants:
			files += 1
			t._check(ResourceLoader.exists("res://art/derived/DEF-001/"
				+ v.file), "sprite %s in the build" % v.file)
	# Twelve variants per shipped object (TABOO 0.3 rule 37); the count
	# follows the manifest, so a new runner pass does not break the test.
	t._check(files == 12 * manifest.size() and files >= 132,
		"%d sprites = 12 x %d objects" % [files, manifest.size()])
	for p in data.passions:
		var s = PassionCore.sprite_for(p, {}, manifest)
		t._check(s != null, "%s has a figure" % p.id)
	# Walk every passion the best way: turn away in silence, then be
	# still; the end is virtue and no attribute changes.
	var record := {}
	for p in data.passions:
		var st := PassionCore.start(p)
		st = PassionCore.choose(st, "turn", p, {"wisdom": 1}, {})
		st = PassionCore.choose(st, "still", p, {"wisdom": 1}, {})
		t._check(st.stage == "virtue", "%s: stillness ends in virtue" % p.id)
		var res := PassionCore.finish(record, st)
		record = res.record
		t._check(res.attribute_bonuses.is_empty(),
			"%s: turning away pays nothing" % p.id)
	t._check(PassionCore.next_passion(data, record, manifest) == null,
		"all overcome: the road is quiet")
	# Naming the sign at the first stage: +1 Wisdom once, never twice.
	var p0: Dictionary = data.passions[0]
	var named := PassionCore.start(p0)
	var opts := PassionCore.options(named, p0, {"wisdom": 20}, {})
	var name_id := ""
	for o in opts:
		if str(o.id).begins_with("name"):
			name_id = o.id
	t._check(name_id != "", "the sign can be named with enough Wisdom")
	named = PassionCore.choose(named, name_id, p0, {"wisdom": 20}, {})
	named = PassionCore.choose(named, "still", p0, {"wisdom": 20}, {})
	var first := PassionCore.finish({}, named)
	t._check(first.attribute_bonuses == {"wisdom": 1}, "+1 Wisdom once")
	var again := PassionCore.finish(first.record, named)
	t._check(again.attribute_bonuses.is_empty(), "never twice")
