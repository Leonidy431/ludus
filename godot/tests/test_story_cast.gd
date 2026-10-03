## The people of the 12 stories in the headset (StoryCast,
## data/story-cast-12.json; docs/HLD_STORY_12_CHARACTERS_2026-10-02.md,
## phase C4).  Called from run_hub_tests.gd.
##   - the data covers the 12 stories, every person has a tree, his node
##     and a place of his story; a mentor of the courtyard stays there;
##   - in every place each person stands, on a spot clear of the heart,
##     the way back, the walk from the door, every thing and the bench,
##     apart from the others, inside the place, the same every time;
##   - the built place joins its people into one mesh with no light and
##     no glow, and gives each a tag seen only within 3.2 m, with no
##     church word;
##   - a press near a person opens his talk on his node and records the
##     meeting; at the heart the heart answers, not a person;
##   - a talk walks to its end through the branches FORM opens, changing
##     only the attributes a branch declares, the same way every time;
##   - the board names every person of a story and where he stands.
extends RefCounted

## The 24 trees of the chorus and the 10 people of the stories.
const TREES_N := 34

var data := LocationCore.load_data()
var ctx := LocationHeart.context()
var cast := StoryCast.load_data()
var story := StoryRoute.load_data()


func run(t: Object) -> void:
	var before: int = t.checks
	var fails: int = t.failures
	_data(t)
	var figures := 0
	for lid in cast.places:
		figures += _place(t, str(lid))
	_board(t)
	print("story cast: %d figures in %d places; %d checks, %d failures"
		% [figures, cast.places.size(), t.checks - before,
			t.failures - fails])


func _data(t: Object) -> void:
	t._check(ctx.trees.size() == TREES_N, "%d trees (%d)" % [TREES_N,
		ctx.trees.size()])
	t._check(cast.stories.size() == 12, "people of 12 stories (%d)"
		% cast.stories.size())
	for s in story.stories:
		t._check(not StoryCast.story(s.mission, cast).is_empty(),
			"story %d has its people" % int(s.mission))
	for s in cast.stories:
		for p in s.people:
			var where := "M%d %s" % [int(s.mission), p.npc]
			var tree: Dictionary = ctx.trees.get(p.npc, {})
			t._check(not tree.is_empty(), where + " has a tree")
			t._check(not HubCore.node_of(tree, p.node).is_empty()
				and HubCore.node_of(tree, p.node).id == p.node,
				"%s opens %s" % [where, p.node])
			t._check(p.npc != s.talk.npc, where + " is not the talk step")
			if p.place == "hub":
				t._check(Mentors.HUB_AT.has(p.npc),
					where + " stands in the courtyard")
				continue
			t._check(not Mentors.HUB_AT.has(p.npc),
				where + " is not a mentor of the courtyard")
			var loc := LocationCore.by_id(data, p.place)
			t._check(not loc.is_empty(), where + " place " + p.place)
			if loc.is_empty():
				continue
			t._check(loc.shell.type != "underwater", where + " on dry land")
			t._check(str(loc.heart.get("npc", "")) != p.npc,
				where + " is not at the heart of his place")
			t._check(("M%d" % int(s.mission)) in loc.plots
				or p.get("on_route", false), where + ": a place of his story")
	# Every person of the stories stands somewhere (Mentors.places).
	var pl := Mentors.places()
	for lid in cast.places:
		for c in cast.places[lid]:
			t._check(lid in pl[c.npc].cast, "%s listed at %s" % [c.npc, lid])
			t._check(Mentors.DRESS.has(c.npc), c.npc + " has a dress")
			# The people of the stories are not saints of the calendar:
			# no saint is given a figure among them or a line in his name.
			t._check(not c.npc in Mentors.SAINTS,
				c.npc + " is not a saint of the calendar")


## One place: the spots, the built people, the talks.  Returns how many
## stand there.
func _place(t: Object, lid: String) -> int:
	var loc := LocationCore.by_id(data, lid)
	var items := LocationCore.load_items()
	var kits := LocationCore.load_kits()
	var p := LocationCore.plan(loc, data.things, items, kits)
	var q := LocationCore.plan(loc, data.things, items, kits)
	t._check(str(p.cast) == str(q.cast), lid + ": the same spots every time")
	t._check(p.cast.size() == StoryCast.at(lid).size(),
		lid + ": every person of the place is planned")
	var heart := Vector2(p.heart.x, p.heart.z)
	var rects := []
	for s in p.slots:
		rects.append(LocationCore.slot_rect(s))
	var placed := 0
	for c in p.cast:
		var who := "%s %s" % [lid, c.npc]
		t._check(c.placed, who + " has a spot")
		if not c.placed:
			continue
		placed += 1
		var at := Vector2(c.pos.x, c.pos.z)
		t._check(absf(c.pos.x) <= p.w / 2.0 - 0.4
			and absf(c.pos.z) <= p.d / 2.0 - 0.4, who + " inside the place")
		t._check(at.distance_to(heart) >= StoryCast.FROM_HEART_M,
			"%s off the heart (%.2f m)" % [who, at.distance_to(heart)])
		t._check(at.distance_to(Vector2(p.exit.x, p.exit.z))
			>= StoryCast.FROM_DOOR_M, who + " off the way back")
		for r in rects:
			t._check(LocationsCore.gap(at, r) >= LocationsCore.CLEAR_M,
				"%s 0.75 m from every thing (%.2f)" % [who,
					LocationsCore.gap(at, r)])
		for o in p.cast:
			if o.npc != c.npc and o.placed:
				t._check(at.distance_to(Vector2(o.pos.x, o.pos.z))
					>= StoryCast.APART_M, "%s apart from %s" % [who, o.npc])
		t._check(not LocationsCore.has_church_word(c.tag)
			and not LocationsCore.has_church_word(StoryCast.prompt(c)),
			who + " tag has no church word: " + c.tag)
		# He faces the walk the player comes by.
		var look: Vector3 = (p.heart + p.start) / 2.0
		var face := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(c.yaw))
		t._check(face.dot((look - c.pos).normalized()) > 0.99,
			who + " faces the walk")
		_talk(t, p, c, loc)
	# Who answers where (LocationCore.nearest, as the scene asks).
	var things := LocationCore.interactables(p)
	for c in p.cast:
		if not c.placed:
			continue
		var front := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(c.yaw))
		for d in [0.6, StoryCast.APPROACH_M]:
			var near := LocationCore.nearest(things, c.pos + front * d)
			t._check(near.get("id", "") == "cast:" + str(c.npc),
				"%s %s answers %.1f m in front of him (%s)" % [lid, c.npc,
					d, near.get("id", "")])
		# Seen from the door, nobody hides him.
		var door := Vector2(p.start.x, p.start.z)
		for o in p.cast:
			if o.npc != c.npc and o.placed:
				t._check(not StoryCast._behind(Vector2(c.pos.x, c.pos.z),
					Vector2(o.pos.x, o.pos.z), door),
					"%s %s is not hidden behind %s" % [lid, c.npc, o.npc])
	for at in [p.heart + Vector3(0, 0, 1.0), p.heart + Vector3(0, 0, 1.3)]:
		t._check(LocationCore.nearest(things, at).get("id", "") == "heart",
			lid + ": the heart answers at the heart")
	t._check(LocationCore.nearest(things, p.start).get("id", "") != "exit",
		lid + ": at the start the way back does not answer")
	# The built place: one mesh for the people, a tag each.
	var world := LocationBuild.build(p)
	var mesh := world.get_node_or_null("Cast")
	t._check(mesh is MeshInstance3D, lid + ": the people are one mesh")
	if mesh is MeshInstance3D:
		var m: Mesh = (mesh as MeshInstance3D).mesh
		t._check(m.get_surface_count() == 1,
			"%s: one draw call for the people (%d surfaces)" % [lid,
				m.get_surface_count()])
		for i in m.get_surface_count():
			var mat = (mesh as MeshInstance3D).get_active_material(i)
			t._check(not (mat is BaseMaterial3D and mat.emission_enabled),
				lid + ": the people do not glow")
		t._check(mesh.find_children("*", "Light3D", true, false).is_empty(),
			lid + ": the people carry no light")
		var tris := LocationBuild.triangles(mesh)
		t._check(tris <= LocationCore.MAX_TRIS,
			"%s: people %d triangles <= 5000" % [lid, tris])
		var bb := (mesh as MeshInstance3D).get_aabb()
		t._check(bb.size.y > 1.6 and bb.size.y < 1.95,
			"%s: a person's height (%.2f)" % [lid, bb.size.y])
	var tags := 0
	for c in p.cast:
		var tag := world.get_node_or_null("CastName_" + str(c.npc)) \
			as Label3D
		if not c.placed:
			continue
		tags += int(tag != null)
		t._check(tag != null and is_equal_approx(tag.visibility_range_end,
			Mentors.TAG_RANGE_M), "%s %s: tag seen only within 3.2 m"
			% [lid, c.npc])
	t._check(tags == placed, "%s: a tag per person (%d)" % [lid, tags])
	for text in LocationCore.labels(p):
		t._check(not LocationsCore.has_church_word(text),
			"%s: label has no church word: %s" % [lid, text])
	world.free()
	return placed


## A talk with one person: it opens on his node, records the meeting,
## and walks to its end on the first open branch, changing FORM only by
## what each branch declares; the same walk twice gives the same FORM.
func _talk(t: Object, p: Dictionary, c: Dictionary, loc: Dictionary) -> void:
	var who := "%s %s" % [p.id, c.npc]
	var st := {"form": HubCore.new_form(), "actions": RuleCore.normalize({}),
		"day": "2026-10-02"}
	var r := LocationHeart.open_cast(c, st, ctx)
	t._check(r.panel.get("kind") == "talk" and r.panel.node.id == c.node,
		"%s opens on %s" % [who, c.node])
	t._check(int(r.st.actions.met.get(c.npc, 0)) == 1,
		who + ": the meeting is recorded")
	t._check(r.save, who + ": the meeting is saved")
	var text := LocationHeart.text(r.panel, loc, r.st, ctx)
	t._check(text.begins_with(str(c.tag) + ":"), who + " names him: "
		+ text.get_slice("\n", 0))
	t._check(text.contains("Источник:"), who + ": the line names its source")
	var walk := func() -> Dictionary:
		var s: Dictionary = r.st.duplicate(true)
		var panel: Dictionary = r.panel
		var steps := 0
		while not panel.is_empty() and steps < 12:
			var before: Dictionary = s.form.duplicate()
			var open := HubCore.open_branches(panel.node, s.form)
			if open.is_empty():
				break
			var res := LocationHeart.choose(panel, loc, s, ctx, 0)
			var b: Dictionary = open[0]
			for a in HubCore.ATTRIBUTES:
				var d := int(res.st.form[a]) - int(before[a])
				t._check(d == int(b.get("attributeBonuses", {}).get(a, 0)),
					"%s: %s changes by its branch only" % [who, a])
			s = res.st
			panel = res.panel
			steps += 1
		t._check(panel.is_empty(), who + ": the talk comes to its end")
		return s.form
	t._check(str(walk.call()) == str(walk.call()),
		who + ": the same walk, the same FORM")


## The board of each story names its people and where they stand.
func _board(t: Object) -> void:
	for s in cast.stories:
		var lines := StoryCast.people_lines(s.mission, cast)
		t._check(lines.size() >= 2, "story %d board names its people"
			% int(s.mission))
		var text := "\n".join(lines)
		t._check(not LocationsCore.has_church_word(text),
			"story %d board has no church word: %s" % [int(s.mission), text])
		for p in s.people:
			var name: String = Mentors.HUB_TAG.get(p.npc, "") \
				if p.place == "hub" else ""
			if name == "":
				for c in StoryCast.at(p.place, cast):
					if c.npc == p.npc:
						name = c.tag
			t._check(name != "" and text.contains(name)
				and text.contains(p.place_ru), "story %d board: %s at %s"
				% [int(s.mission), p.npc, p.place_ru])
