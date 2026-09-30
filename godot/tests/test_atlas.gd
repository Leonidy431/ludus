## The Water Atlas at the lectern (TABOO 0.03).  Called from
## run_hub_tests.gd.
extends RefCounted


func run(t: Object) -> void:
	var data := AtlasCore.load_data()
	t._check(data.nodes.size() == 99, "99 nodes (%d)" % data.nodes.size())
	var seen := {}
	for node in data.nodes:
		seen[int(node.n)] = true
		var c: String = node.constitution
		t._check(c.contains("ФОРМА") and c.contains("ДЕЙСТВИЕ")
			and c.contains("ЦЕЛЬ"), "#%d has its Constitution line" % node.n)
		t._check(node.status in ["принят", "адаптирован", "заменён"],
			"#%d status" % node.n)
	t._check(seen.size() == 99, "numbers 1..99 once each")
	t._check(AtlasCore.page_text(data, 0).contains("Каталанский атлас"),
		"the frame opens with the Catalan Atlas")
	t._check(AtlasCore.page_text(data, 99).contains("99."),
		"the last page is node 99")
	t._check(AtlasCore.next_page(data, 99) == 0, "after 99, the frame")
	# The rejected frame never reaches the page the player reads as a
	# claim: every mention of it is a denial written by the chorus.
	for p in AtlasCore.page_count(data):
		var text := AtlasCore.page_text(data, p).to_lower()
		for w in ["мир — симуляция внутри", "железный аватар души"]:
			t._check(not text.contains(w), "page %d has no '%s'" % [p, w])
