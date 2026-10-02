## The church-word stop-list gives the same verdict as the web on one
## shared corpus (tests/fixtures/church-words-corpus.json): «помощи» is
## not «мощи», «Богородицы» and «Евангелие» are caught, the twins pass
## (blind spot 16, docs/decisions/STOPLIST_SINGLE_SOURCE_2026-10-02.md).
## Called from run_hub_tests.gd.
extends RefCounted

## The corpus sits beside the JS tests, outside the exported tree, so
## the headset build does not carry it.
const CORPUS := "../tests/fixtures/church-words-corpus.json"


func run(t: Object) -> void:
	var list := LocationsCore.church_list()
	t._check(list.get("stems", []).size() >= 40
		and "молитв" in list.stems and "богородиц" in list.stems,
		"the stop-list is read from data/church-words.json")
	var path := ProjectSettings.globalize_path("res://").path_join(CORPUS)
	var corpus = JSON.parse_string(FileAccess.get_file_as_string(path))
	t._check(corpus is Dictionary, "the shared corpus is read: " + path)
	if not corpus is Dictionary:
		return
	t._check(corpus.must_flag.size() >= 30
		and corpus.must_pass.size() >= 10, "the corpus is not empty")
	for row in corpus.must_flag:
		var got := LocationsCore.church_word(str(row[0]))
		t._check(got == str(row[1]), "caught %s: %s (got %s)"
			% [row[1], row[0], got])
	for row in corpus.must_pass:
		var got := LocationsCore.church_word(str(row[0]))
		t._check(got == "", "passes %s (got %s)" % [row[0], got])
