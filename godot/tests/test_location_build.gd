## The 99 locations as the headset builds them (CLAUDE.md TABOO 0.013,
## docs/HLD_LOCATIONS_99_2026-09-30.md phase L4).  Called from
## run_hub_tests.gd: run() checks the plans and the hearts' panels
## without a scene; in_scene() builds every place in the real
## location.tscn, one after another, and measures what was built:
## every thing is clear of the heart and of the way back by 0.75 m, in
## the place's bounds, at most 5000 triangles and one draw call; a holy
## thing only on its own slot, with both flags and no tag; no church
## word on a tag or a label; one heart, one way back, the light of the
## place's class.  What the places still wait for (things with no proxy
## yet) is counted and printed, never hidden.
extends RefCounted

const DAY := "2026-09-30"
## Kinds of heart whose panel may change FORM: a talk (the branch's own
## bonus) and a thought on the road named at its suggestion (PassionCore).
## A practice, a deed, a new action or the witness's line never does.
const FORM_MAY_CHANGE := ["talk", "passion"]

var data: Dictionary = {}
var scene: Node
var missing_total := 0


func fresh() -> Dictionary:
	return {"form": HubCore.new_form(), "actions": RuleCore.normalize({}),
		"trials": TrialCore.empty_state(),
		"passions": PassionCore.normalize_record({}), "chronicle": null,
		"atlas_given": [], "day": DAY}


func run(t: Object) -> void:
	data = LocationCore.load_data()
	var items := LocationCore.load_items()
	var ctx := LocationHeart.context()
	var locs: Array = data.get("locations", [])
	t._check(locs.size() == 99, "99 places to build (%d)" % locs.size())
	var waiting := {}
	for loc in locs:
		var a := LocationCore.plan(loc, data.things, items)
		var b := LocationCore.plan(loc, data.things, items)
		var id: String = loc.id
		t._check(var_to_str(a) == var_to_str(b), id + " plan deterministic")
		t._check(String(loc.constitution).contains("ФОРМА")
			and String(loc.constitution).contains("ДЕЙСТВИЕ")
			and String(loc.constitution).contains("ЦЕЛЬ"),
			id + " has its Constitution line")
		t._check(a.slots.size() + a.missing.size() == loc.slots.size(),
			id + " every wished thing is placed or listed as missing")
		for m in a.missing:
			var th: Dictionary = data.things[m.object]
			t._check(String(th.state).begins_with("pending"),
				"%s: %s is missing only because it has no model yet (%s)"
				% [id, m.object, th.state])
			waiting[m.object] = m.why
			missing_total += 1
		var holy_seen := 0
		for s in a.slots:
			if s.holy:
				holy_seen += 1
				t._check(loc.holy_place != null
					and s.object == loc.holy_place.thing
					and s.mount == "holy", id + ": holy only at its place")
				t._check(s.flags.noInteract and s.flags.noLoot and not s.tag,
					id + ": holy flags, no tag")
				t._check(s.model.from == "proxy",
					id + ": a holy thing is our own proxy, never raw")
		t._check(holy_seen <= 1, id + ": at most one holy thing")
		for text in LocationCore.labels(a):
			t._check(not LocationsCore.has_church_word(text),
				"%s: no church word on a label: %s" % [id, text])
		# The headset decides how a proxy is scaled from the data alone
		# (the proxies' .json are not packed); the rule must agree with
		# what each proxy's .json says it is.
		for s in a.slots:
			var meta := LocationCore.read_meta(s.model.meta)
			if s.model.from == "proxy" and not meta.is_empty():
				t._check((meta.get("method") == LocationCore.STRETCH_METHOD)
					== (LocationCore.method_of(s.thing, s.model)
						== LocationCore.STRETCH_METHOD),
					"%s: %s is scaled as its proxy was made (%s)" % [id,
						s.object, meta.get("method")])
		_panel(t, loc, ctx)
	var keys := waiting.keys()
	keys.sort()
	print("locations built: %d wished things wait for a model in %d kinds: %s"
		% [missing_total, keys.size(), ", ".join(keys)])
	_fit(t)
	_families(t)
	scene = (load(LocationCore.SCENE) as PackedScene).instantiate()
	scene.location_id = locs[0].id
	(t as SceneTree).root.add_child(scene)


## The heart's panel on a fresh state: it opens, says something, offers
## a way out, and a choice goes to the right core.  Deterministic.
func _panel(t: Object, loc: Dictionary, ctx: Dictionary) -> void:
	var id: String = loc.id
	var st := fresh()
	var r := LocationHeart.open(loc, st, ctx)
	var r2 := LocationHeart.open(loc, st, ctx)
	t._check(var_to_str(r) == var_to_str(r2), id + " panel deterministic")
	var p: Dictionary = r.panel
	t._check(not p.is_empty(), id + " heart opens a panel")
	var lines := LocationHeart.lines(p, loc, r.st, ctx)
	t._check(lines.size() > 1 and str(lines[0]) != "",
		id + " panel has words")
	if p.kind in ["deed", "rule"]:
		var joined := "\n".join(lines)
		t._check(not joined.contains("Ladder")
			and not joined.contains("Apophthegmata"),
			id + " names its source in Russian")
	var list := LocationHeart.choices(p, loc, r.st, ctx)
	t._check(not list.is_empty() and list[list.size() - 1].id == "away",
		id + " panel offers a way out")
	for c in list:
		t._check(not LocationsCore.has_church_word(str(c.text))
			or p.kind in ["talk", "trial"],
			"%s: no church word on a button: %s" % [id, c.text])
	# The first open choice.
	var i := 0
	while i < list.size() and list[i].disabled:
		i += 1
	var res := LocationHeart.choose(p, loc, r.st, ctx, i)
	if not p.kind in FORM_MAY_CHANGE:
		t._check(var_to_str(res.st.form) == var_to_str(st.form),
			"%s: %s changes no FORM" % [id, p.kind])
	if p.kind in ["witness", "new", "find", "atlas-scribe"]:
		t._check(var_to_str(res.st) == var_to_str(st) and not res.save,
			"%s: %s records nothing" % [id, p.kind])
	if p.kind == "trial":
		t._check(list.size() == 1, id + ": a closed threshold only lets go")
	if p.kind == "rule" and RuleCore.practice(loc.heart.id).kind == "timer":
		_timer(t, loc, ctx, p)


## A practice of whole minutes counts only when the minutes are whole,
## and for stillness and the vigil only while the body is still.
func _timer(t: Object, loc: Dictionary, ctx: Dictionary,
		p: Dictionary) -> void:
	var id: String = loc.id
	var pr := RuleCore.practice(loc.heart.id)
	var st := fresh()
	var r := LocationHeart.choose(p, loc, st, ctx, 0)
	t._check(r.panel.timer > 0.0, id + " timer starts")
	var sec := float(pr.minutes) * 60.0
	var half := LocationHeart.tick(r.panel, loc, r.st, ctx, sec - 1.0, true)
	t._check(var_to_str(half.st) == var_to_str(st),
		id + " nothing counts before the minutes are whole")
	if loc.heart.id in LocationHeart.STILL_PRACTICES:
		var moved := LocationHeart.tick(half.panel, loc, half.st, ctx, 0.5,
			false)
		t._check(is_equal_approx(moved.panel.timer, sec),
			id + " a movement starts the count again")
	var done := LocationHeart.tick(half.panel, loc, half.st, ctx, 2.0, true)
	var before := RuleCore.practice_tally(st.actions, loc.heart.id)
	var after := RuleCore.practice_tally(done.st.actions, loc.heart.id)
	t._check(after.value > before.value and done.save,
		"%s: whole minutes counted (%s -> %s)" % [id, before.text_ru,
			after.text_ru])
	t._check(var_to_str(done.st.form) == var_to_str(st.form),
		id + " a practice pays no FORM")


## How a proxy is turned and scaled (LocationCore.fit).
func _fit(t: Object) -> void:
	var shield := LocationCore.fit({"state": "volume",
		"size_m": [0.9, 0.9, 0.1]}, Vector3(1.26, 0.162, 1.241), "kit")
	t._check(shield.rot == Vector3(-90, 0, 0) and shield.scale.x
		== shield.scale.y, "a lying shield stands up, scaled evenly")
	var log_fit := LocationCore.fit({"state": "volume",
		"size_m": [0.4, 0.4, 4.0]}, Vector3(2, 4, 2),
		LocationCore.STRETCH_METHOD)
	var got: Vector3 = log_fit.scale * Vector3(2, 2, 4)
	t._check(log_fit.rot == Vector3(-90, 0, 0)
		and got.is_equal_approx(Vector3(0.4, 0.4, 4.0)),
		"a stand-in capsule lies along the log (%s)" % got)
	var card := LocationCore.fit({"state": "card", "size_m": [0.4, 0.4,
		0.03]}, Vector3(0.392, 0.392, 0.028), "")
	t._check(is_equal_approx(card.scale.x * 0.392, LocationCore.CARD_M),
		"a card hangs at the card's width")
	var items := LocationCore.load_items("res://no-such-file.json")
	t._check(items.is_empty(), "no props store file: no items, no error")
	var holy_item := LocationCore.model_of("worship-cross",
		data.things["worship-cross"], {"worship-cross": {"model":
			"res://models/rov/mangustik.glb", "meta": ""}})
	t._check(holy_item.from == "",
		"a holy thing is never taken from the props store")


## The hub's road of places lists every place under its families.
func _families(t: Object) -> void:
	var seen := {}
	var fams := LocationCore.families(data)
	for f in fams:
		t._check(LocationCore.FAMILY_RU.has(f.id), f.id + " has its name")
		for pl in f.places:
			seen[pl.id] = true
	t._check(seen.size() == 99, "every place is on the road of places (%d)"
		% seen.size())
	t._check(fams.size() == 13, "thirteen families (%d)" % fams.size())
	# The board in the hub: a press opens a family, the next goes to the
	# marked place, the first line of a family goes back, the mark wraps.
	var home := {"family": -1, "cursor": 0}
	var r := PlacesLectern.press(fams, home)
	t._check(r.state.family == 0 and r.go == "", "a press opens a family")
	r = PlacesLectern.press(fams, r.state)
	t._check(r.go == fams[0].places[0].id,
		"a press in a family goes to the marked place (%s)" % r.go)
	t._check(PlacesLectern.press(fams, {"family": 3, "cursor": 0}).state
		== {"family": -1, "cursor": 3}, "the first line goes back")
	t._check(PlacesLectern.move(fams, home, -1).cursor == fams.size() - 1,
		"the mark wraps")
	for i in fams.size():
		var page := PlacesLectern.text(fams, {"family": i, "cursor": 0})
		t._check(not LocationsCore.has_church_word(page),
			"the board of %s has no church word" % fams[i].id)


## Build every place in the real scene and measure it.
func in_scene(t: Object) -> void:
	t._check(scene.is_node_ready(), "location.tscn is built")
	var fails_before: int = t.failures
	var worst_tris := 0
	for loc in data.locations:
		scene.open_place(loc.id)
		_built(t, loc)
		var tris := LocationBuild.triangles(scene.world)
		worst_tris = maxi(worst_tris, tris)
	# The panel opened in the scene: a press at the heart opens it and a
	# press on "away" closes it; the prompt at the start names a place.
	scene.open_place("deacon-cell")
	scene.pos = scene.p.heart + Vector3(0, 0, 1.0)
	t._check(scene._nearest().get("id") == "heart", "the heart answers")
	scene._interact()
	t._check(not scene.heart_panel.is_empty(), "a press opens the panel")
	var n := LocationHeart.choices(scene.heart_panel, scene.loc, scene.st,
		scene.ctx).size()
	scene.proof = true  # Nothing is written by this test.
	scene._select(n - 1)
	t._check(scene.heart_panel.is_empty(), "away closes the panel")
	scene.pos = scene.p.exit
	t._check(scene._nearest().get("id") == "exit", "the way back answers")
	print("locations built: worst place %d triangles in the whole scene; %d failures in the scene checks"
		% [worst_tris, t.failures - fails_before])
	scene.free()


func _built(t: Object, loc: Dictionary) -> void:
	var id: String = loc.id
	var p: Dictionary = scene.p
	var world: Node3D = scene.world
	t._check(p.id == id, id + " is the place built")
	var hearts := 0
	var exits := 0
	for th in scene.things:
		hearts += int(th.id == "heart")
		exits += int(th.id == "exit")
	t._check(hearts == 1 and exits == 1, id + ": one heart, one way back")
	var things: Node = world.get_node("Things")
	t._check(things.get_child_count() == p.slots.size(),
		"%s: every placed thing is in the scene (%d of %d)" % [id,
			things.get_child_count(), p.slots.size()])
	var heart := Vector2(p.heart.x, p.heart.z)
	var exit := Vector2(p.exit.x, p.exit.z)
	var bounds := Rect2(-p.w / 2.0 - 0.05, -p.d / 2.0 - 0.05, p.w + 0.1,
		p.d + 0.1)
	var tagged := {}
	for tag in world.get_node("Tags").get_children():
		var l := tag as Label3D
		t._check(is_equal_approx(l.visibility_range_end,
			LocationCore.TAG_RANGE_M), "%s: tag %s seen within 3.2 m"
			% [id, l.text])
		t._check(not LocationsCore.has_church_word(l.text),
			"%s: tag has no church word: %s" % [id, l.text])
		tagged[l.get_meta("tag_of")] = true
	for c in things.get_children():
		var holder := c as Node3D
		var meta: Dictionary = holder.get_meta("location_thing")
		var box: AABB = holder.transform * ObitelLayout.local_aabb(holder)
		var r := Rect2(box.position.x, box.position.z, box.size.x,
			box.size.z)
		var key: String = meta.object
		t._check(bounds.encloses(r), "%s: %s inside the place (%s)" % [id,
			key, r])
		if meta.mount != "heart":
			var gh := LocationsCore.gap(heart, r)
			t._check(gh >= LocationCore.CLEAR_M - 0.01,
				"%s: %s clear of the heart (%.2f m)" % [id, key, gh])
		var ge := LocationsCore.gap(exit, r)
		t._check(ge >= LocationCore.CLEAR_M - 0.01,
			"%s: %s clear of the way back (%.2f m)" % [id, key, ge])
		var tris := LocationBuild.triangles(holder)
		t._check(tris > 0 and tris <= LocationCore.MAX_TRIS,
			"%s: %s has %d triangles (<= 5000)" % [id, key, tris])
		var meshes := holder.find_children("*", "MeshInstance3D", true,
			false)
		t._check(meshes.size() == 1
			and (meshes[0] as MeshInstance3D).mesh.get_surface_count() <= 2,
			"%s: %s is one mesh of <= 2 surfaces (%d meshes)" % [id, key,
				meshes.size()])
		if meta.holy:
			t._check(meta.noInteract and meta.noLoot and not tagged.has(key),
				"%s: holy %s flat, both flags, no tag" % [id, key])
			t._check(box.size.z <= 0.2 or box.size.x <= 0.2,
				"%s: holy %s is flat (%s)" % [id, key, box.size])
	var person := world.get_node_or_null("PersonName") as Label3D
	if person:
		t._check(not LocationsCore.has_church_word(person.text),
			"%s: the person's name has no church title: %s" % [id,
				person.text])
	var cls: String = p.light["class"]
	var light_name: String = {"hearth": "HearthLight",
		"instrument": "InstrumentLight", "lampada": "LampadaLight"}[cls]
	t._check(world.get_node_or_null(light_name) != null,
		"%s: the light of its class (%s)" % [id, cls])
	var lampada := world.get_node_or_null("Lampada") != null
	t._check(lampada == (p.lampada and p.holy_key != ""
		and not p.missing.any(func(m): return m.object == p.holy_key)),
		"%s: a lampada only beside its holy thing" % id)
