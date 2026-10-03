## The cracked jug of the potters' yard (docs/HLD_SADNESS_VESSEL_2026-10-02.md):
## a beat of the road met at a thing of the place, beside its heart.
## Called from run_hub_tests.gd; every check goes through the runner's
## _check().
##
## What is checked, from the data the headset carries:
##   - the place: the beat stands on the cracked jug, out of the reach of
##     the heart and of the way back; the heart keeps its one practice;
##     the whole jug, the cracked one and the one daubed with clay are
##     real proxies under 5000 triangles, none of them holy;
##   - the art: the reworked kit ant_sadness_4bbd8e3f97 has its twelve
##     sprites in the build, and the figure at the beat is taken from it;
##   - the teacher: Theodora's node teaches the sign of sadness in her
##     own words (a discernment node, retold, with its source), and a
##     talk with her leads to it;
##   - the meeting: PassionCore's stages, the three breaths of stillness
##     counted by time, +1 Wisdom only for naming the thought the first
##     time, nothing for turning away, nothing for being led; the same
##     choices give the same end (no randomness, TABOO 0.35 rule 15);
##   - no church word on the beat's own words or on a choice.
## Constitution: FORM (Wisdom, or the talk with Theodora) -> ACTION (name
## the sign at the first stage, or turn away, and stand still) -> GOAL
## (sadness known by its sign: it praises yesterday and spoils today).
extends RefCounted

const PLACE := "pottery"
const KIT := "4bbd8e3f97"
const DAY := "2026-10-02"


func fresh() -> Dictionary:
	return {"form": HubCore.new_form(), "actions": RuleCore.normalize({}),
		"trials": TrialCore.empty_state(),
		"passions": PassionCore.normalize_record({}), "chronicle": null,
		"atlas_given": [], "day": DAY}


func _index(p: Dictionary, loc: Dictionary, st: Dictionary,
		ctx: Dictionary, id: String) -> int:
	var list := LocationHeart.choices(p, loc, st, ctx)
	for i in list.size():
		if list[i].id == id:
			return i
	return -1


## Walk the beat by choice ids; a choice with breaths is waited out
## standing still.  Returns {panel, st} after the last step.
func _walk(loc: Dictionary, st: Dictionary, ctx: Dictionary,
		ids: Array) -> Dictionary:
	var r := LocationHeart.open_beat(loc, st, ctx)
	for id in ids:
		var i := _index(r.panel, loc, r.st, ctx, id)
		if i < 0:
			return {"panel": r.panel, "st": r.st, "missing": id}
		r = LocationHeart.choose(r.panel, loc, r.st, ctx, i)
		var guard := 0
		while not r.panel.is_empty() and r.panel.get("still", -1.0) >= 0.0 \
				and guard < 100:
			r = LocationHeart.tick(r.panel, loc, r.st, ctx, 1.0, true)
			guard += 1
	return {"panel": r.panel, "st": r.st, "missing": ""}


func run(t: Object) -> void:
	var data := LocationCore.load_data()
	var loc := LocationCore.by_id(data, PLACE)
	t._check(not loc.is_empty(), "the potters' yard is one of the 99")
	var b: Dictionary = loc.get("beat", {})
	t._check(b.get("id") == "sadness" and b.get("thing") == "cracked-jug"
		and b.get("kit") == KIT and b.get("npc") == "theodora"
		and b.get("node") == "cracked_jug",
		"the yard's beat: sadness at the cracked jug, taught by Theodora")
	var beats := 0
	for l in data.locations:
		beats += int(l.has("beat"))
	t._check(beats == 1, "one beat among the 99 places (%d)" % beats)
	t._check(LocationHeart.kind_of(loc.heart) == "rule"
		and loc.heart.id == "handiwork",
		"the heart of the yard keeps its one practice: handiwork")

	# The place as the headset plans it.
	var p := LocationCore.plan(loc, data.things, LocationCore.load_items(),
		LocationCore.load_kits())
	t._check(p.beat != null, "the plan carries the beat")
	var at: Vector3 = p.beat.at
	var heart_gap := Vector2(at.x - p.heart.x, at.z - p.heart.z).length()
	t._check(heart_gap >= LocationCore.REACH_M + LocationCore.BEAT_REACH_M,
		"the jug stands out of the heart's reach (%.2f m)" % heart_gap)
	var exit_gap := Vector2(at.x - p.exit.x, at.z - p.exit.z).length()
	t._check(exit_gap >= LocationCore.EXIT_REACH_M
		+ LocationCore.BEAT_REACH_M,
		"the jug stands out of the way back's reach (%.2f m)" % exit_gap)
	var found := {}
	for s in p.slots:
		if s.object in ["water-jug", "cracked-jug", "patched-jug"]:
			found[s.object] = s
	t._check(found.size() == 3,
		"the whole, the cracked and the mended jug stand in the yard (%s)"
		% [found.keys()])
	for key in ["cracked-jug", "patched-jug"]:
		if not found.has(key):
			continue
		var s: Dictionary = found[key]
		t._check(not s.holy and not s.flags.noLoot and s.tag,
			key + ": an ordinary thing with a tag, never holy")
		t._check(s.model.from == "proxy" and ResourceLoader.exists(
			s.model.path), key + ": its proxy is in the build")
		var meta := LocationCore.read_meta(s.model.meta)
		t._check(int(meta.get("tris", 99999)) <= LocationCore.MAX_TRIS,
			"%s: %s triangles (<= 5000)" % [key, meta.get("tris")])
	t._check(Vector2(at.x - found["cracked-jug"].pos.x,
		at.z - found["cracked-jug"].pos.z).length() < 0.01,
		"the beat answers at the cracked jug itself")
	t._check(p.holy_key == "", "no holy thing at the potters' yard")
	for text in [p.beat.ru, str(b.scene_ru), str(b.lesson)]:
		t._check(not LocationsCore.has_church_word(text),
			"no church word in the beat: " + text)

	# The art: the reworked kit, twelve sprites in the build.
	var ctx := LocationHeart.context()
	var kit := {}
	for o in ctx.manifest:
		if str(o.id) == KIT:
			kit = o
	t._check(kit.get("passion") == "sadness"
		and kit.get("variants", []).size() == 12,
		"the cracked-jug kit has twelve variants of sadness")
	for v in kit.get("variants", []):
		t._check(ResourceLoader.exists("res://art/derived/DEF-001/"
			+ str(v.file)), "sprite %s in the build" % v.file)

	# The teacher: Theodora's node, reachable from her talk.
	var tree: Dictionary = ctx.trees.theodora
	var node := HubCore.node_of(tree, "cracked_jug")
	t._check(str(node.get("meaning", "")).begins_with(
		"Discernment cue for the passion of sadness"),
		"Theodora's cracked jug teaches the sign of sadness")
	t._check(node.get("voice") == "paraphrase"
		and str(node.get("source", "")).contains("Praktikos 10"),
		"the desert teacher is retold, with Evagrius as the source")
	t._check(str(node.get("text_ru", "")).contains("кувшин"),
		"she speaks of it in her own idiom: the jug by the trough")
	var leads := false
	for n in tree.nodes:
		for br in n.get("branches", []):
			leads = leads or br.get("nextNodeId") == "cracked_jug"
	t._check(leads, "a talk with Theodora leads to the cracked jug")

	# The meeting.
	var st := fresh()
	var r := LocationHeart.open_beat(loc, st, ctx)
	t._check(r.panel.kind == "passion" and r.panel.beat
		and r.panel.enc.passionId == "sadness"
		and r.panel.enc.stage == "prilog", "a press at the jug meets sadness")
	var text := LocationHeart.text(r.panel, loc, r.st, ctx)
	t._check(text.contains(str(b.ru)) and text.contains("Вспомни дом"),
		"the panel names the jug, then the thought it brings")
	var ids := []
	for c in LocationHeart.choices(r.panel, loc, r.st, ctx):
		ids.append(c.id)
		t._check(not LocationsCore.has_church_word(str(c.text)),
			"no church word on a choice: " + str(c.text))
	t._check(ids == ["look", "turn", "away"],
		"without the teacher or Wisdom 6 the sign cannot be named: %s" % [ids])
	var art := LocationHeart.passion_art(loc, r.st, ctx, r.panel)
	t._check(art.contains("ant_sadness_" + KIT) and ResourceLoader.exists(
		art), "the figure over the jug is the cracked jug: " + art)
	t._check(LocationHeart.passion_art(loc, r.st, ctx) == "",
		"the yard's heart shows no figure of a thought")

	# Turning away in silence: virtue, nothing paid.
	var a := _walk(loc, fresh(), ctx, ["turn", "still"])
	t._check(a.missing == "" and a.panel.enc.stage == "virtue",
		"turning away and three breaths of stillness end in virtue")
	var a_text := LocationHeart.text(a.panel, loc, a.st, ctx)
	t._check(a_text.contains("подмазывают глиной"),
		"after it the yard's lesson is said")
	var a_end := LocationHeart.choose(a.panel, loc, a.st, ctx, 0)
	t._check(a_end.panel.is_empty() and a_end.save,
		"walking on closes the panel and asks to save")
	t._check(a_end.st.form == HubCore.new_form(),
		"turning away pays nothing: FORM unchanged")
	t._check(a_end.st.passions.sadness.overcome == 1
		and not a_end.st.passions.sadness.discerned,
		"the meeting is recorded as overcome, not discerned")

	# The breaths are waited out by time, not passed by a press.
	var w := LocationHeart.open_beat(loc, fresh(), ctx)
	w = LocationHeart.choose(w.panel, loc, w.st, ctx,
		_index(w.panel, loc, w.st, ctx, "turn"))
	w = LocationHeart.choose(w.panel, loc, w.st, ctx,
		_index(w.panel, loc, w.st, ctx, "still"))
	t._check(is_equal_approx(float(w.panel.still),
		3.0 * LocationHeart.STILL_BREATH_SECONDS),
		"three breaths of stillness are waited for")

	# Naming it after the talk with Theodora: +1 Wisdom, once.
	var named := fresh()
	named.actions = HubCore.record_meeting(named.actions, "theodora")
	var n1 := _walk(loc, named, ctx, ["name", "still"])
	t._check(n1.missing == "" and n1.panel.enc.named
		and n1.panel.enc.stage == "virtue",
		"after the talk with Theodora the sign is named at the suggestion")
	var n1_end := LocationHeart.choose(n1.panel, loc, n1.st, ctx, 0)
	t._check(int(n1_end.st.form.wisdom) == int(named.form.wisdom) + 1,
		"naming the sign the first time gives +1 Wisdom")
	t._check(n1_end.st.passions.sadness.discerned,
		"the thought is recorded as discerned")
	var n2 := _walk(loc, n1_end.st, ctx, ["name", "still"])
	var n2_end := LocationHeart.choose(n2.panel, loc, n2.st, ctx, 0)
	t._check(int(n2_end.st.form.wisdom) == int(n1_end.st.form.wisdom),
		"naming it again pays nothing more")
	var n3 := _walk(loc, named, ctx, ["name", "still"])
	var n3_end := LocationHeart.choose(n3.panel, loc, n3.st, ctx, 0)
	t._check(n3_end.st == n1_end.st,
		"the same choices give the same end (no randomness)")

	# Led by it: the jug comes back, and the panel says who knows its sign.
	var c := _walk(loc, fresh(), ctx, ["look", "answer", "take"])
	t._check(c.missing == "" and c.panel.enc.stage == "captive",
		"talking with the thought and taking its offer: it leads")
	t._check(LocationHeart.text(c.panel, loc, c.st, ctx).contains(
		LocationHeart.beat_mentor_line(b)),
		"the panel sends the player to Theodora for the sign")
	var c_end := LocationHeart.choose(c.panel, loc, c.st, ctx, 0)
	t._check(c_end.st.form == HubCore.new_form()
		and c_end.st.passions.sadness.captive == 1,
		"being led changes no FORM and is recorded")
	# A place without a beat opens nothing at a press of the kind.
	var other := LocationCore.by_id(data, "deacon-cell")
	t._check(LocationHeart.open_beat(other, fresh(), ctx).panel.is_empty(),
		"a place without a beat has none to open")
