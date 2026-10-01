## The journal of the way (JournalCore): the exported page is the web
## page letter for letter (journal_fixture.json, written from
## ludus-journal.js by scripts/godot/make_journal_fixture.js); the secret
## deed is never counted; nothing about confession; an export never
## overwrites an earlier page (TABOO 0.25 point 5).  Called from
## run_hub_tests.gd.
extends RefCounted


func run(t: Object) -> void:
	var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/journal_fixture.json"))
	var passions: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/passions.json"))
	t._check(fx.records.size() >= 5, "journal fixture has its pages")
	for r in fx.records:
		var md := JournalCore.to_markdown({"form": r.form,
			"actions": r.actions, "passions": r.passions,
			"passion_data": passions, "date": r.date})
		t._check(md == r.md, "journal %s: page as in the web" % r.name)
		if md != r.md:
			var a := md.split("\n")
			var b: PackedStringArray = str(r.md).split("\n")
			for i in mini(a.size(), b.size()):
				if a[i] != b[i]:
					printerr("  line %d: got [%s] want [%s]" % [i, a[i],
						b[i]])
					break
	var busy: Dictionary = fx.records[3]
	var state := {"form": busy.form, "actions": busy.actions,
		"passions": busy.passions, "passion_data": passions,
		"date": busy.date}
	var md := JournalCore.to_markdown(state)
	# The secret deed is named but never counted, on the page and in
	# the book (Mt 6:3-4).
	for line in md.split("\n"):
		if line.contains("A good deed in secret"):
			t._check(line.ends_with("known to God"), "secret not counted")
			t._check(RegEx.create_from_string("\\d").search(line) == null,
				"no number on the secret line")
	var pages := JournalCore.pages_ru(state)
	t._check(pages.size() == 5, "five pages in the book")
	t._check(pages[1].contains("Доброе тайно — ведомо Богу"),
		"secret in the book: known to God")
	t._check(pages[1].contains("Простить обиду — 2 дня")
		and pages[1].contains("Милостыня — 1 день"), "Russian days")
	# No confession and no church word as a label (TABOO 0.26, 0.39).
	var re := RegEx.create_from_string(
		"(?i)confess|исповед|таинств|благодат|святост|мученик|grace|saint")
	t._check(re.search(md) == null, "no church words on the page")
	t._check(re.search("\n".join(pages)) == null,
		"no church words in the book")
	# Under the water: the headset's own section, only with a dive save.
	var dive := {"bag": {"kept": ["a"], "released": ["b", "c"],
		"handed_over": ["x", "y"], "atlas": ["diary"]},
		"done": ["hover", "tether", "unknown"]}
	state["dive"] = dive
	var with_dive := JournalCore.to_markdown(state)
	t._check(with_dive.contains("- Tasks of the dive: 2 of 8")
		and with_dive.contains("handed to the scribe: 2")
		and with_dive.contains("Let go back into the water: 2"),
		"dive section")
	t._check(md.contains("Under the water") == false,
		"no dive section without a dive save")
	t._check(JournalCore.pages_ru(state)[4].contains("из 8"),
		"dive page in the book")
	t._check(JournalCore.dive_summary("junk").is_empty()
		and JournalCore.dive_summary({"bag": 5, "done": "x"}).tasks == [],
		"a broken dive save is read as nothing")
	# Deterministic: the same saves give the same page.
	t._check(JournalCore.to_markdown(state) == with_dive, "deterministic")
	# An export never overwrites an earlier page.
	var taken := ["user://journal-2026-09-30.md",
		"user://journal-2026-09-30-2.md"]
	t._check(JournalCore.export_path("2026-09-30",
		func(p): return p in taken) == "user://journal-2026-09-30-3.md",
		"export takes a free name")
	t._check(JournalCore.export_path("2026-10-01",
		func(p): return p in taken) == "user://journal-2026-10-01.md",
		"export of a new day")
	# The book never deletes: no remove call in the journal scripts.
	for path in ["res://scripts/journal_core.gd",
			"res://scripts/journal_book.gd"]:
		var src := FileAccess.get_file_as_string(path)
		t._check(src != "" and not src.contains("remove")
			and not src.contains("FileAccess.WRITE_READ"),
			"%s never deletes" % path)
	# The book writes only when asked, and only under user://journal-.
	var book := FileAccess.get_file_as_string("res://scripts/journal_book.gd")
	t._check(book.count("FileAccess.WRITE") == 1
		and book.contains("JournalCore.export_path"),
		"the book writes once, to a fresh journal file")
