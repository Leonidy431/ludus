## The small acts at the hearts of 26 places (PlaceDeeds, phase L3 of
## docs/HLD_LOCATIONS_99_2026-09-30.md; docs/HLD_L3_PLACE_DEEDS_
## 2026-10-01.md).  Called from run_hub_tests.gd.  The contract every
## act keeps is checked here for all of them alike; each group's own
## test (tests/deeds/test_deeds_<g>.gd) checks the craft of its acts.
##
## For every act with logic: it starts open with no reply; every button
## has words and none says a church word (TABOO 0.39 item 3); a search
## of the buttons from the start reaches "done" within MAX_STEPS steps;
## the same steps give the same states (no chance); through the place's
## heart the act never changes FORM, records itself once on the step
## that closes it and once a day only, and leaves the actions, trials
## and passions as they were.  A hand-edited record is cut to its shape.
##
## The panel holds them (blind spot 15): over every state of the walk,
## laid out with the real panel's font and width (tests/deeds/
## panel_text.gd), a button fits one line and BUTTON_MAX letters, a
## panel line or reply fits LINE_WRAP_MAX lines and LINE_MAX letters,
## and the whole panel fits its bark.  A wrong step pressed again
## changes nothing (blind spot 22): the state it left stays as it is.
extends RefCounted

const DeedsGraph := preload("res://tests/deeds_graph.gd")
const PanelText := preload("res://tests/deeds/panel_text.gd")

const DAY := "2026-10-01"
const MAX_STEPS := 40
## How many of the 26 acts must have their logic.  A ratchet: it only
## goes up, and at 26 every heart of the 99 places has its own core.
const ACTS_WITH_LOGIC_MIN := 26
## The limits of the heart's panel, in letters, measured, not guessed:
##   godot --headless --path godot -s res://tools/measure_panel_text.gd
## The panel (location.gd) wraps at 1300 px of a 38 px font; the widest
## text of the acts takes 22.85 px a letter, so one line holds 56
## letters and a button after its "▸ 9. " (71 px) holds 53.  A panel
## line may wrap once.  The tool's --check fails when these are looser
## than the measurement (docs/BLINDSPOTS_CODE_BREAKTHROUGH_2026-10-01.md
## item 15).
const BUTTON_MAX := 53
const LINE_MAX := 112
const LINE_WRAP_MAX := 2

## How many wrong steps were pressed again (blind spot 22).
var _again := 0


func run(t: Object) -> void:
	var with_logic := 0
	for id in PlaceDeeds.GROUPS:
		if not PlaceDeeds.has(id):
			continue
		with_logic += 1
		_contract(t, id)
	t._check(with_logic >= ACTS_WITH_LOGIC_MIN,
		"acts with logic: %d of %d (at least %d)" % [with_logic,
			PlaceDeeds.GROUPS.size(), ACTS_WITH_LOGIC_MIN])
	print("  place deeds: %d of %d acts have their logic" % [with_logic,
		PlaceDeeds.GROUPS.size()])
	t._check(_again > 0, "wrong steps were pressed again")
	print("  place deeds: %d wrong steps pressed again" % _again)
	_record(t)
	_hearts(t)
	_web_walk(t)
	for g in ["a", "b", "c", "d", "e"]:
		var path := "res://tests/deeds/test_deeds_%s.gd" % g
		# Every group has its own craft test; a missing one is a failure,
		# not a quiet skip.
		t._check(ResourceLoader.exists(path), "group %s has its test" % g)
		if ResourceLoader.exists(path):
			load(path).new().run(t)


func _contract(t: Object, id: String) -> void:
	var s := PlaceDeeds.start(id)
	t._check(s.get("done") == false and str(s.get("reply", "x")) == "",
		id + ": starts open with no reply")
	t._check(PlaceDeeds.start(id) == s, id + ": the start is always the same")
	# Breadth-first over the buttons: some path closes the act.
	var seen := {var_to_str(s): true}
	var queue := [[s, 0]]
	var closed := false
	while not queue.is_empty() and not closed:
		var item: Array = queue.pop_front()
		var cur: Dictionary = item[0]
		var opts := PlaceDeeds.options(id, cur)
		t._check(not opts.is_empty(), id + ": an open act offers a step")
		for o in opts:
			t._check(str(o.get("text", "")) != ""
				and not LocationsCore.has_church_word(str(o.text)),
				"%s: a button with plain words: %s" % [id, o.get("text")])
			if o.get("disabled", false):
				t._check(str(o.get("reason", "")) != "",
					"%s: a closed button says why" % id)
				continue
			var nxt := PlaceDeeds.choose(id, cur, str(o.id))
			# A reply or a panel line is the narrator's voice, so it says
			# no church word either (TABOO 0.39 item 3).
			for tx in PlaceDeeds.lines(id, nxt) + [str(nxt.get("reply", ""))]:
				if LocationsCore.has_church_word(str(tx)):
					t._check(false, "%s: a plain line: %s" % [id, tx])
			t._check(PlaceDeeds.choose(id, cur, str(o.id)) == nxt,
				"%s: the same step gives the same state" % id)
			t._check(cur == item[0], id + ": choose leaves its input as it was")
			# A wrong step moves only the notes; pressed again from where
			# it left the act, it changes nothing (blind spot 22).
			if not nxt.get("done", false) and _notes_only(cur, nxt):
				_again += 1
				t._check(PlaceDeeds.choose(id, nxt, str(o.id)) == nxt,
					"%s: %s pressed again changes nothing" % [id, o.id])
			if nxt.get("done", false):
				closed = true
				t._check(PlaceDeeds.options(id, nxt).is_empty(),
					id + ": a closed act offers no button")
				break
			var key := var_to_str(nxt)
			if not seen.has(key) and int(item[1]) < MAX_STEPS:
				seen[key] = true
				queue.append([nxt, int(item[1]) + 1])
			# An act that asks to wait closes by waiting still.
			var waited := PlaceDeeds.tick(id, nxt, 600.0, true)
			if waited.get("done", false):
				closed = true
				break
	t._check(closed, id + ": some way through the buttons closes the act")


## The record: once a day, the known shape only.
func _record(t: Object) -> void:
	var r := PlaceDeeds.record({}, "test-ice", DAY)
	t._check(r == {"test-ice": {"count": 1, "lastDay": DAY}},
		"the first time is recorded")
	t._check(PlaceDeeds.record(r, "test-ice", DAY) == r,
		"the same day counts once")
	var r2 := PlaceDeeds.record(r, "test-ice", "2026-10-02")
	t._check(r2["test-ice"].count == 2, "the next day counts again")
	var bad := PlaceDeeds.normalize({"test-ice": {"count": "9",
		"lastDay": "yesterday"}, "unknown": {"count": 5}, "x": 3})
	t._check(bad == {"test-ice": {"count": 0, "lastDay": null}},
		"a hand-edited record keeps only its shape")
	t._check(PlaceDeeds.normalize(null) == {}, "no record is an empty one")


## Through the hearts of the real places: FORM untouched, the record
## changes once, on the closing step only.
func _hearts(t: Object) -> void:
	var data := LocationsCore.load_data()
	var ctx := LocationHeart.context()
	for loc in data.locations:
		var act := PlaceDeeds.act_of(loc.heart)
		if act == "" or not PlaceDeeds.has(act):
			continue
		var st := {"form": HubCore.new_form(),
			"actions": RuleCore.normalize({}),
			"trials": TrialCore.empty_state(),
			"passions": PassionCore.normalize_record({}), "chronicle": null,
			"atlas_given": [], "deeds": {}, "day": DAY}
		var r := LocationHeart.open(loc, st, ctx)
		t._check(r.panel.kind == "act", loc.id + ": the heart is its act")
		# Breadth-first over the panel's buttons and waiting, as a player
		# might try them in any order (a walk that always pressed the
		# first button that moved the act could swing between two wrong
		# ones for ever).  Each path carries how many saves it asked.
		var p: Dictionary = r.panel
		var s: Dictionary = r.st
		var saves := 0
		var seen := {var_to_str(p.deed): true}
		var queue := [[r.panel, r.st, 0, 0]]
		var steps := 0
		while not queue.is_empty() and steps < 4000:
			steps += 1
			var item: Array = queue.pop_front()
			var cur_p: Dictionary = item[0]
			var cur_s: Dictionary = item[1]
			var nexts := []
			var list := LocationHeart.choices(cur_p, loc, cur_s, ctx)
			for j in list.size():
				if list[j].disabled or list[j].id == "away":
					continue
				nexts.append(LocationHeart.choose(cur_p, loc, cur_s, ctx, j))
			nexts.append(LocationHeart.tick(cur_p, loc, cur_s, ctx, 600.0,
				true))
			var found := false
			for res in nexts:
				if res.panel.is_empty():
					continue
				var n_saves: int = item[2] + (1 if res.save else 0)
				if res.panel.deed.get("done", false):
					p = res.panel
					s = res.st
					saves = n_saves
					found = true
					break
				var key := var_to_str(res.panel.deed)
				if not seen.has(key) and int(item[3]) < MAX_STEPS:
					seen[key] = true
					queue.append([res.panel, res.st, n_saves, int(item[3]) + 1])
			if found:
				break
		t._check(p.deed.get("done", false), loc.id + ": the act closes")
		t._check(var_to_str(s.form) == var_to_str(st.form),
			loc.id + ": the act changes no FORM")
		t._check(var_to_str(s.actions) == var_to_str(st.actions)
			and var_to_str(s.trials) == var_to_str(st.trials)
			and var_to_str(s.passions) == var_to_str(st.passions),
			loc.id + ": the act touches only its own record")
		t._check(saves == 1 and s.deeds.get(act, {}).get("count") == 1,
			loc.id + ": recorded once, on the closing step")
		var lines := LocationHeart.lines(p, loc, s, ctx)
		t._check("Сегодня уже сделано." in lines,
			loc.id + ": the panel says it was done today")
		# The real heart's text of the closed act fits the bark, as the
		# walk's panels do in _panel_fits.
		var pt := _panel()
		t._check(PanelText.wrapped_all(pt, LocationHeart.text(p, loc, s,
			ctx)) <= PanelText.bark_lines(pt),
			loc.id + ": the closed panel fits its bark")


## The web page plays the walk of these acts (tests/deeds_graph.gd →
## public/ludus/data/place-deeds.json).  A changed act without a new walk
## fails here, so the page and the headset never part silently; write it
## with: godot --headless --path godot -s res://tests/export_deeds_graph.gd
func _web_walk(t: Object) -> void:
	var g: Dictionary = DeedsGraph.build()
	for id in g.acts:
		t._check(not g.acts[id].overflow, id + ": the walk ends")
	_panel_fits(t, g)
	var path := DeedsGraph.out_path()
	t._check(FileAccess.file_exists(path), "the web walk exists: " + path)
	var have := FileAccess.get_file_as_string(path)
	t._check(have == DeedsGraph.to_text(g),
		"the web walk matches the acts (re-run tests/export_deeds_graph.gd)")


## True when b differs from a only in the notes of a state ("reply",
## "tried"): the step was a wrong one (place_deeds.gd).
static func _notes_only(a: Dictionary, b: Dictionary) -> bool:
	var x := a.duplicate(true)
	var y := b.duplicate(true)
	for k in ActCue.NOTES:
		x.erase(k)
		y.erase(k)
	return x == y


static var _pt := {}


## The real heart's panel, built once (tests/deeds/panel_text.gd).
static func _panel() -> Dictionary:
	if _pt.is_empty():
		_pt = PanelText.panel()
	return _pt


## Every state of every act on the real panel (blind spot 15): buttons
## on one line within BUTTON_MAX letters, lines and replies within
## LINE_WRAP_MAX lines and LINE_MAX letters, the whole panel within its
## bark.  One failure names the act and the text.
func _panel_fits(t: Object, g: Dictionary) -> void:
	var p := _panel()
	var bark := PanelText.bark_lines(p)
	var bad := {"button": 0, "line": 0, "panel": 0}
	var states := 0
	for id in g.acts:
		for n in g.acts[id].nodes:
			states += 1
			for o in n.options:
				var tx := str(o.text)
				if tx.length() > BUTTON_MAX or PanelText.wrapped(p,
						PanelText.PREFIX + tx) > 1:
					bad.button += 1
					t._check(false, "%s: a button of %d letters fits one "
						% [id, tx.length()] + "line within %d: %s"
						% [BUTTON_MAX, tx])
			for tx in n.lines + [n.reply]:
				if str(tx).length() > LINE_MAX or PanelText.wrapped(p,
						str(tx)) > LINE_WRAP_MAX:
					bad.line += 1
					t._check(false, "%s: a line fits %d lines within %d "
						% [id, LINE_WRAP_MAX, LINE_MAX] + "letters: %s" % tx)
			var h := PanelText.wrapped_all(p, PanelText.compose(
				g.acts[id].place, n))
			if h > bark:
				bad.panel += 1
				t._check(false, "%s: a panel of %d lines fits the bark's %d"
					% [id, h, bark])
	t._check(states > 0, "the panel is checked over the walk's states")
	print("  panel text: %d states; over the limit: %d buttons, %d lines, "
		% [states, bad.button, bad.line] + "%d panels (bark %d lines)"
		% [bad.panel, bark])
