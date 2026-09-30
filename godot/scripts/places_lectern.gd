## The road of places in the courtyard: a birch-bark board on two oak
## posts east of the board of missions, listing the 99 locations of our
## plots (docs/HLD_LOCATIONS_99_2026-09-30.md) by the family of their
## plots, in the order of the road.  Near it, the stick up and down (or
## the arrows) moves the mark; a press at it opens a family, and in a
## family a press goes to the marked place (LocationCore.go), whose door
## brings the player back here.  Reading the board counts nothing.
## Placed by a small hook in hub.gd: things.append(PlacesLectern.place(
## self)).
class_name PlacesLectern
extends Node3D

## East of the board of missions, off the way to the pier and out of the
## corner of stillness; the hub's test of the obitel keeps every object
## of the yard 0.75 m from its reach point.
const AT := Vector3(6.2, 0, 2.4)
const OAK := Color(0.42, 0.29, 0.17)
const BARK := Color(0.93, 0.88, 0.76)
const INK := Color(0.2, 0.15, 0.1)
## Lines of a list shown at once, around the mark.
const WINDOW := 11

var hub: Node3D
var fams: Array = []
var state := {"family": -1, "cursor": 0}
var board: Label3D
var nav_was := 0.0


static func place(the_hub: Node3D) -> Dictionary:
	var l := PlacesLectern.new()
	l.name = "PlacesLectern"
	l.hub = the_hub
	the_hub.add_child(l)
	l._build()
	return {"id": "places", "kind": "node", "node": l,
		"pos": AT + Vector3(-0.6, 0, 0),
		"ru": "Дорога мест: выбрать место — стик вверх-вниз, нажать"}


func _build() -> void:
	fams = LocationCore.families(LocationCore.load_data())
	# Posts, rail and bark joined into one mesh, and no lamp of its own:
	# the hub is already over its draw-call budget (docs/APK_REQUIREMENTS
	# row 9), so the board adds one call and a label, not six and a light.
	var g := Node3D.new()
	g.name = "PlacesBoard"
	for dz in [-0.85, 0.85]:
		LocationBuild.box(g, Vector3(0.12, 2.3, 0.12),
			AT + Vector3(0.05, 1.15, dz), OAK)
	LocationBuild.box(g, Vector3(0.12, 0.1, 1.9), AT + Vector3(0.05, 2.33, 0),
		OAK)
	LocationBuild.box(g, Vector3(0.02, 1.75, 1.6), AT + Vector3(0.03, 1.4, 0),
		BARK)
	# The still parts go to the hub itself, not under this scripted node
	# and not pre-joined: StaticBatch leaves scripted nodes and
	# vertex-colour meshes apart, and so the board put the yard over its
	# ratchet (102 of 99).  In the hub the plain oak and bark boxes merge
	# with the yard's own.
	hub.add_child(g)
	board = Label3D.new()
	board.font_size = 26
	board.pixel_size = 0.0024
	board.width = 640
	board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.modulate = INK
	board.outline_size = 0
	board.double_sided = false
	board.position = AT + Vector3(0.0, 1.4, 0)
	board.rotation_degrees = Vector3(0, -90, 0)
	# The list is read at the board, like a tag (TABOO 0.013 p. 4); from
	# across the yard its two text calls are not drawn at all.
	board.visibility_range_end = 4.0
	add_child(board)
	_show()


## The lines of the open list: the families, or the places of one
## family with a way back to the families first.
static func entries(families: Array, st: Dictionary) -> Array:
	var out := []
	if st.family < 0:
		for f in families:
			out.append({"kind": "family", "id": f.id,
				"text": "%s — мест: %d" % [f.ru, f.places.size()]})
		return out
	out.append({"kind": "back", "id": "", "text": "← к сюжетам"})
	for pl in families[st.family].places:
		out.append({"kind": "place", "id": pl.id, "text": pl.title})
	return out


static func move(families: Array, st: Dictionary, step: int) -> Dictionary:
	var n := entries(families, st).size()
	return {"family": st.family, "cursor": posmod(int(st.cursor) + step,
		maxi(1, n))}


## A press: open a family, go back to the families, or go to a place.
## Returns {state, go}: go is the place's id, or "".
static func press(families: Array, st: Dictionary) -> Dictionary:
	var list := entries(families, st)
	if list.is_empty():
		return {"state": st, "go": ""}
	var e: Dictionary = list[clampi(int(st.cursor), 0, list.size() - 1)]
	match e.kind:
		"family":
			return {"state": {"family": int(st.cursor), "cursor": 1},
				"go": ""}
		"back":
			return {"state": {"family": -1, "cursor": maxi(0,
				int(st.family))}, "go": ""}
	return {"state": st, "go": e.id}


static func text(families: Array, st: Dictionary) -> String:
	var list := entries(families, st)
	var head := "ДОРОГА МЕСТ" if st.family < 0 \
		else "ДОРОГА МЕСТ · " + str(families[st.family].ru)
	var lines := [head, ""]
	var first := clampi(int(st.cursor) - WINDOW / 2, 0,
		maxi(0, list.size() - WINDOW))
	if first > 0:
		lines.append("   …")
	for i in range(first, mini(list.size(), first + WINDOW)):
		lines.append("%s%s" % ["▸ " if i == int(st.cursor) else "   ",
			list[i].text])
	if first + WINDOW < list.size():
		lines.append("   …")
	lines += ["", "Стик вверх-вниз — выбрать, нажать — %s." % (
		"открыть" if st.family < 0 else "идти")]
	return "\n".join(lines)


func _show() -> void:
	board.text = text(fams, state)


## The hub calls this on a press at the board.
func use() -> void:
	var r := press(fams, state)
	state = r.state
	_show()
	if r.go != "":
		# The courtyard is saved before leaving, as at the pier.
		hub._save()
		LocationCore.go(get_tree(), r.go)


## While the player stands at the board and no panel is open, the stick
## (or the arrows) moves the mark.
func _process(_dt: float) -> void:
	if hub == null or hub._panel_open() \
			or hub._nearest().get("id", "") != "places":
		nav_was = 0.0
		return
	var nav := float(Input.is_key_pressed(KEY_UP)) \
		- float(Input.is_key_pressed(KEY_DOWN))
	if hub.xr_active:
		nav = hub._stick(hub.right_hand).y
	if absf(nav) > 0.6 and absf(nav_was) <= 0.6:
		state = move(fams, state, -int(signf(nav)))
		_show()
	nav_was = nav
