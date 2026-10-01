## The 24 mentors of the dialogue trees in the headset (HLD
## docs/HLD_APK_GRAPHICS_SOUND_2026-10-01.md, track B).
##
## Where a mentor stands is read from the data, not invented: a mentor
## whose talk is the heart of one of the 99 places
## (godot/data/locations-99.json, heart.npc) stands at that heart, in
## every such place; the four mentors of the gates stand in the
## scriptorium of the hub, as before; a mentor whose plot has no place
## among the 99 stands in the hub beside them, with the courtyard's
## guests (TABOO 0.013: one heart per place, so a second talk is never
## put into a place whose heart is another).  Which place a hub guest
## belongs to is an open question for the chorus (docs/APK_PARITY.md).
##
## A mentor is a person, not a statue and not an icon (TABOO 0.2 p. 2,
## 0.32 p. 3): a body, a head and the covering of his estate, of our own
## procedural volume (a LOD0 proxy, TABOO 0.32 p. 2), with no halo, no
## ring, no glow and no light of his own (TABOO 0.35 rule 7).  The SVG
## portraits of the web game are framed cards, and several carry rays
## above the head; they stay cards and are not stood up as people.  The
## name tag is seen only within 3.2 m (TABOO 0.013 p. 4) and carries no
## church word (TABOO 0.39 p. 3).
##
## Constitution: FORM (the mentor's place, his estate, his tree) ->
## ACTION (the player walks up and talks with his own FORM) -> GOAL (the
## teaching of the tree, said in the mentor's own idiom with its source).
class_name Mentors
extends RefCounted

const TREES := "res://data/dialogue-trees.json"
const LOCATIONS := "res://data/locations-99.json"
## The same as LocationCore.TAG_RANGE_M and ObitelLayout.TAG_RANGE_M.
const TAG_RANGE_M := 3.2

## The four mentors of the gates (HubCore.MENTORS), in the scriptorium.
const GATE_MENTORS := ["elder_sergius", "theodora", "abba_john",
	"sister_catherine"]

## The saints of the trees: every line of theirs is a paraphrase with a
## source (the same list as scripts/check_dialogues.py SAINTS).
const SAINTS := ["abba_moses", "ekaterina", "maximos", "photius",
	"mary_magdalene", "gregory_dialogist", "symeon_stylite", "kassiani",
	"gregory_palamas", "macrina", "isaias"]

## Hub positions on the floor.  The four of the gates stand on their
## line in front of the scriptorium table, with the yard free east of
## them, so each is walked up to straight from the yard and the table
## and its cards stay in sight.  The eight guests stand apart about the
## yard, each by what his own idiom speaks of, never in front of the
## gate line: Gregory the Dialogist by the hearth and the fasting table
## (bread for the poor), Symeon on the open ground by the shore (wind),
## Mary on the way back from the pier (the road to the city), Isaias,
## Palamas, Kassia and Catherine on the west side of the yard between
## the rope and the atlas (scroll, light, verse, premise), the master of
## gesso by the workshop.  Each keeps 1.2 m from the next mentor and
## 0.75 m from every thing (tests/test_mentors.gd), and the way from the
## courtyard to the pier stays open.
const HUB_AT := {
	"elder_sergius": Vector3(-4.6, 0, -3.2),
	"theodora": Vector3(-4.6, 0, -1.8),
	"abba_john": Vector3(-4.6, 0, -0.4),
	"sister_catherine": Vector3(-4.6, 0, 1.0),
	"gregory_palamas": Vector3(-1.6, 0, 2.4),
	"isaias": Vector3(-0.4, 0, 3.6),
	"kassiani": Vector3(-2.0, 0, 4.6),
	"ekaterina": Vector3(-3.4, 0, 4.8),
	"gregory_dialogist": Vector3(3.4, 0, -1.6),
	"symeon_stylite": Vector3(6.2, 0, -1.6),
	"mary_magdalene": Vector3(7.2, 0, 1.6),
	"ikonopisets": Vector3(-3.4, 0, -4.6),
}
## The point of the yard the guests turn to; the gate mentors face east.
const YARD_CENTRE := Vector3(1.0, 0, 1.0)

## The tag of a hub mentor: his name and, in the manner of the places'
## hearts ("Макрина с зерном на ладони", "Фотий-книжник у светильника"),
## a sign of his craft from the tree's idiom.  No church word and no
## epithet of the calendar (TABOO 0.39 p. 3, 0.013 p. 6): the epithets
## "Столпник", "Двоеслов", "мироносица" are in LocationsCore.CHURCH_WORDS.
## The list goes to the chorus of 12 (TABOO 0.37) with the place of the
## guests (docs/APK_PARITY.md).
const HUB_TAG := {
	"elder_sergius": "Старец Сергий",
	"theodora": "Феодора",
	"abba_john": "Авва Иоанн",
	"sister_catherine": "Сестра Екатерина",
	"gregory_palamas": "Григорий Палама",
	"isaias": "Исаия со свитком",
	"kassiani": "Кассия с пером и напевом",
	"ekaterina": "Екатерина из Александрии",
	"gregory_dialogist": "Григорий, что пишет беседы",
	"symeon_stylite": "Симеон, что стоит на ветру",
	"mary_magdalene": "Мария с сосудом мира",
	"ikonopisets": "Мастер левкаса и темперы",
}


## The turn of a hub mentor about the vertical, in degrees: the gate
## mentors face the yard to the east, a guest faces the yard's centre.
## The figure's face is its local +Z.
static func facing(id: String) -> float:
	if id in GATE_MENTORS:
		return 90.0
	var p: Vector3 = HUB_AT.get(id, YARD_CENTRE)
	var d := YARD_CENTRE - p
	return rad_to_deg(atan2(d.x, d.z))

## The covering of each mentor's estate, from the craft of his idiom:
## hood - a monk's dark hood; veil - a woman's head cloth; cap - a felt
## cap of the steppe or the town; bare - a working man's head.  Cloth is
## undyed wool, linen or dark monastic cloth: no gold, no light.
const DRESS := {
	"elder_sergius": ["hood", Color(0.1, 0.1, 0.11)],
	"theodora": ["veil", Color(0.2, 0.17, 0.22)],
	"abba_john": ["hood", Color(0.25, 0.2, 0.15)],
	"sister_catherine": ["veil", Color(0.12, 0.12, 0.16)],
	"abba_moses": ["hood", Color(0.16, 0.13, 0.11)],
	"anahit": ["veil", Color(0.36, 0.2, 0.16)],
	"ekaterina": ["veil", Color(0.3, 0.16, 0.18)],
	"gregory_dialogist": ["hood", Color(0.22, 0.2, 0.18)],
	"gregory_palamas": ["hood", Color(0.11, 0.1, 0.1)],
	"ikonopisets": ["bare", Color(0.42, 0.36, 0.27)],
	"isaias": ["bare", Color(0.38, 0.33, 0.26)],
	"kassiani": ["veil", Color(0.1, 0.1, 0.12)],
	"khan": ["cap", Color(0.34, 0.16, 0.12)],
	"macrina": ["veil", Color(0.14, 0.12, 0.12)],
	"mary_magdalene": ["veil", Color(0.33, 0.24, 0.2)],
	"maximos": ["hood", Color(0.13, 0.12, 0.12)],
	"melik": ["cap", Color(0.24, 0.25, 0.3)],
	"photius": ["bare", Color(0.2, 0.18, 0.2)],
	"rybak_issyk_kul": ["bare", Color(0.3, 0.32, 0.34)],
	"sargis": ["cap", Color(0.4, 0.3, 0.2)],
	"strazhnik": ["cap", Color(0.28, 0.24, 0.18)],
	"symeon_stylite": ["hood", Color(0.3, 0.27, 0.22)],
	"tabib": ["cap", Color(0.36, 0.34, 0.3)],
	"vardan": ["bare", Color(0.26, 0.22, 0.18)],
}
const SKIN := Color(0.78, 0.62, 0.5)


static func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Every mentor's place: {id: {"hub": Vector3 or null, "places": [ids]}},
## from the trees and the 99 places.  Deterministic: data order.
static func places(trees = null, locations = null) -> Dictionary:
	if trees == null:
		trees = _json(TREES).trees
	if locations == null:
		locations = _json(LOCATIONS).locations
	var out := {}
	for id in trees:
		out[id] = {"hub": HUB_AT.get(id), "places": []}
	for loc in locations:
		var h: Dictionary = loc.get("heart", {})
		var npc := str(h.get("npc", ""))
		if npc != "" and out.has(npc):
			out[npc].places.append(loc.id)
	return out


## The figure of a mentor at the origin: a body, a head and the covering
## of his estate.  The parts are separate meshes; the caller joins them
## (LocationBuild.join in a place, StaticBatch in the hub), so a figure
## costs no draw call of its own.  Nothing in it shines.
static func figure(id: String) -> Node3D:
	var g := Node3D.new()
	g.name = "Mentor_" + id
	var d: Array = DRESS.get(id, ["bare", Color(0.25, 0.2, 0.15)])
	var cloth: Color = d[1]
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.24
	cap.height = 1.5
	cap.radial_segments = 12
	cap.rings = 4
	body.mesh = cap
	body.material_override = LocationBuild.mat(cloth)
	body.position = Vector3(0, 0.75, 0)
	g.add_child(body)
	var head := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.26
	sp.radial_segments = 12
	sp.rings = 6
	head.mesh = sp
	head.material_override = LocationBuild.mat(SKIN)
	head.position = Vector3(0, 1.62, 0)
	g.add_child(head)
	match d[0]:
		"hood":
			# A hood falling to the shoulders, open in front: a cone of
			# the robe's cloth over the back of the head.
			var hood := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.12
			cm.bottom_radius = 0.21
			cm.height = 0.3
			cm.radial_segments = 12
			cm.rings = 1
			hood.mesh = cm
			hood.material_override = LocationBuild.mat(cloth.darkened(0.15))
			hood.position = Vector3(0, 1.6, -0.1)
			g.add_child(hood)
		"veil":
			# A head cloth over the head and down to the shoulders.
			var veil := MeshInstance3D.new()
			var vm := CylinderMesh.new()
			vm.top_radius = 0.12
			vm.bottom_radius = 0.24
			vm.height = 0.42
			vm.radial_segments = 12
			vm.rings = 1
			veil.mesh = vm
			veil.material_override = LocationBuild.mat(cloth.darkened(0.25))
			veil.position = Vector3(0, 1.53, -0.085)
			g.add_child(veil)
		"cap":
			# A low felt cap on the crown.
			var hat := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.top_radius = 0.1
			hm.bottom_radius = 0.135
			hm.height = 0.1
			hm.radial_segments = 12
			hm.rings = 1
			hat.mesh = hm
			hat.material_override = LocationBuild.mat(cloth.lightened(0.15))
			hat.position = Vector3(0, 1.76, 0)
			g.add_child(hat)
	# A belt of the same cloth, darker: the waist reads at a distance.
	var belt := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.245
	bm.bottom_radius = 0.245
	bm.height = 0.05
	bm.radial_segments = 12
	bm.rings = 1
	belt.mesh = bm
	belt.material_override = LocationBuild.mat(cloth.darkened(0.4))
	belt.position = Vector3(0, 0.95, 0)
	g.add_child(belt)
	return g


## The name tag over a mentor: seen only near, no church word.
static func tag(text: String, at: Vector3,
		node_name := "MentorName") -> Label3D:
	var name_label := Label3D.new()
	name_label.name = node_name
	name_label.text = text
	name_label.font_size = 30
	name_label.pixel_size = 0.0026
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position = at + Vector3(0, 2.0, 0)
	name_label.modulate = Color(0.95, 0.9, 0.8)
	name_label.visibility_range_end = TAG_RANGE_M
	return name_label
