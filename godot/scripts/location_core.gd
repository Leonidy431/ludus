## The builder's logic for the 99 locations of our plots (CLAUDE.md
## TABOO 0.013, docs/HLD_LOCATIONS_99_2026-09-30.md phase L4): what a
## location is made of, before any node is made.
##
## The place comes from data/locations-99.json, which
## scripts/locations/locations_99.py writes from an honest pool
## (TABOO 0.07).  The slots in it are the fixed plan of the place, as
## SLOTS are for the obitel (scripts/obitel_layout.gd): the same data
## always gives the same room.  This file adds what the headset needs to
## build it: the shell and its size, the heart and the way back, the
## light of its class (TABOO 0.38), the bench for small things, and for
## every wished thing the model that shows it:
##   1. our own volume proxy (TABOO 0.32), already in the APK or shipped
##      for the locations into models/locations/ by
##      scripts/locations/ship_models.py;
##   2. an item from the props store of the 99 repos, once the pipeline
##      has passed it (TABOO 0.012, 0.1): data/location-items.json,
##      written by the raw runner; a holy thing is never taken from it;
##      its drawings (kits of twelve passed by eye) are stood in metres
##      by load_kits() and _place_kits(): a drawing fills the slot of a
##      thing with no model, or stands beside our proxy as its second
##      state, where the ground is clear;
##   3. our own drawing where the data asks for one (the oak lectern);
##   and otherwise nothing: the thing is listed as missing, never faked
##   by a box that is not like it (TABOO 0.013 item 3).
## How a proxy is turned and scaled to the thing's real size is fit();
## location.gd builds the nodes, tests/test_location_build.gd checks the
## built rooms.  Nothing here is random.
class_name LocationCore
extends RefCounted

const SCENE := "res://scenes/location.tscn"
const ITEMS := "res://data/location-items.json"
## The scene reads the chosen place from this meta on the tree's root,
## so it outlives the change of scene.
const META_KEY := "ludus_location"
const HUB_SAVE := "user://hub.json"
const DIVE_SAVE := "user://dive.json"
## A name tag shows only when the player comes close (TABOO 0.013 item 4).
const TAG_RANGE_M := 3.2
## A drawn card hangs at this width (as LocationsCore.CARD_M).
const CARD_M := 0.6
## How near the heart and the way back answer a press.
const REACH_M := 2.2
const EXIT_REACH_M := 0.9
## The player starts this far inside the way back, well outside its
## reach, so on arrival the heart (or nothing) answers, never the door
## (TABOO 0.013 item 1: a neighbour does not take over the choice).
const START_IN_M := 1.2
## Near the holy thing the interface goes (TABOO 0.4 item 2, 0.38
## item 3; Atlas node 5): full beyond HOLY_FAR_M from its slot, gone
## inside HOLY_NEAR_M, over CockpitCore.FADE_SECONDS (1.75 s).  The
## dive's 3-6 m is for open water; a cell of 4 m needs room scale, and
## every heart stands beyond HOLY_FAR_M of its place's holy thing, so
## the heart's own words are never faded (tests/test_location_build).
const HOLY_NEAR_M := 1.0
const HOLY_FAR_M := 1.8
## A thing keeps this much room from every place the player acts at.
const CLEAR_M := 0.75
const MAX_TRIS := 5000
## The bench top by shell, as TABLE_TOP of the generator.
const TABLE_TOP := {"room": 0.8, "cave": 0.8, "yard": 0.8, "shore": 0.45,
	"open": 0.45}
## The families of plots in the order of the road (the generator's
## FAMILIES and FAMILY_RU).
const FAMILIES := ["prologue", "trade", "spiritual", "hydrology",
	"diplomacy", "craft", "narrative", "atlas", "kiberslav", "dive",
	"threshold", "road", "witness"]
const FAMILY_RU := {"prologue": "Пролог", "trade": "Акт I",
	"spiritual": "Акт II", "hydrology": "Акт III", "diplomacy": "Акт IV",
	"craft": "Акт V", "narrative": "Финал", "atlas": "Атлас воды",
	"kiberslav": "Киберслав", "dive": "Погружение", "threshold": "Пороги",
	"road": "Дорога страстей", "witness": "Тропа свидетеля"}
## Things drawn by our own hand in the builder (not holy: a holy thing
## of our own drawing waits for the chorus, TABOO 0.37).
const OWN := ["lectern"]
## The lampada and the instrument light, as the hub has them.
const LAMPADA_K := Color(1.0, 0.52, 0.16)
const INSTRUMENT_K := Color(0.95, 0.97, 1.0)
## Proxies made from the box field of a prompt are stand-in shapes that
## may be stretched to the thing's size; drawn and measured models keep
## their proportions.
const STRETCH_METHOD := "primitive-from-box-field"


static func load_data() -> Dictionary:
	return LocationsCore.load_data()


static func by_id(data: Dictionary, id: String) -> Dictionary:
	for loc in data.get("locations", []):
		if loc.id == id:
			return loc
	return {}


## The places listed by family in the order of the road; a place stands
## under every family its plots belong to.  Empty families are left out.
static func families(data: Dictionary) -> Array:
	var out := []
	for f in FAMILIES:
		var places := []
		for loc in data.get("locations", []):
			if f in loc.families:
				places.append({"id": loc.id, "title": loc.title_ru})
		if not places.is_empty():
			out.append({"id": f, "ru": FAMILY_RU[f], "places": places})
	return out


# --- Models ----------------------------------------------------------------

## The props store's items that passed the pipeline, by thing key.  The
## raw runner writes the file (track B); any of its shapes is read:
## {"items": {key: {"model": path}}} or {"items": [{"thing": key,
## "model": path}]}.  Only a model that exists in the project is taken.
static func load_items(path := ITEMS) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	var list = raw.get("items", {}) if raw is Dictionary else {}
	var out := {}
	if list is Dictionary:
		for k in list:
			if list[k] is Dictionary:
				out[str(k)] = list[k]
	elif list is Array:
		for it in list:
			if not it is Dictionary:
				continue
			var key := str(it.get("thing", it.get("key", it.get("id", ""))))
			if key != "":
				out[key] = it
	var ok := {}
	for k in out:
		var m := str(out[k].get("model", out[k].get("glb", "")))
		if m.begins_with("res://") and ResourceLoader.exists(m):
			ok[k] = {"model": m, "meta": str(out[k].get("meta",
				m.get_basename() + ".json"))}
	return ok


## The proxy paths a source can have: in the APK already, or shipped
## for the locations (scripts/locations/ship_models.py).
static func _proxy_candidates(src: String) -> Array:
	var id := src.get_slice(":", 1)
	match src.get_slice(":", 0):
		"obj":
			return ["res://models/obitel/%s.glb" % id,
				"res://models/locations/%s.glb" % id]
		"lake":
			var f := "lake-%s.glb" % id.replace(".", "-")
			return ["res://models/lake/" + f, "res://models/locations/" + f]
		"atlas":
			return ["res://models/atlas/atlas-%s.glb" % id,
				"res://models/locations/atlas-%s.glb" % id]
	return []


## The model that shows a thing: {from: proxy | item | own | "", path,
## meta, why}.  "" means missing; why says what it waits for.
static func model_of(key: String, thing: Dictionary,
		items: Dictionary) -> Dictionary:
	for p in _proxy_candidates(str(thing.source)):
		if ResourceLoader.exists(p):
			return {"from": "proxy", "path": p,
				"meta": p.get_basename() + ".json"}
	var holy: bool = thing.get("holy") != null
	if items.has(key) and not holy:
		return {"from": "item", "path": items[key].model,
			"meta": items[key].meta}
	if key in OWN and not holy:
		return {"from": "own", "path": "", "meta": "", "own": key}
	var why := "props store (raw pipeline)" if thing.state == "pending-raw" \
		else "own drawing" if thing.state == "pending-own" else "no proxy"
	if holy and thing.state == "pending-own":
		why = "own drawing of a holy thing (chorus, TABOO 0.37)"
	return {"from": "", "path": "", "meta": "", "why": why}


## How a model's proxy was made, from the data alone: a volume of the
## obitel's register ("obj:") is a stand-in shape from a prompt's box
## field; lake and Atlas things are measured kits; an item of the props
## store keeps its proportions.  The proxy's .json says the same (the
## test compares them), but it is not packed into the APK, so the
## headset must not need it.
static func method_of(thing: Dictionary, model: Dictionary) -> String:
	if model.get("from", "") == "own":
		return STRETCH_METHOD
	if model.get("from", "") == "proxy" and thing.state == "volume" \
			and str(thing.source).begins_with("obj:"):
		return STRETCH_METHOD
	return ""


static func read_meta(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var m = JSON.parse_string(FileAccess.get_file_as_string(path))
	return m if m is Dictionary else {}


## How a model is turned and scaled so it takes its thing's real size.
## bbox is the model's own box as measured; the result is applied as
## scale (in the place's axes) over rot (degrees, one axis).  A card or
## a board keeps its face and is scaled to the card's width.  A volume
## is turned so its long and thin axes lie as the thing's do; a stand-in
## shape is then stretched to the size, a drawn or measured model is
## scaled evenly until it fits inside the size.
static func fit(thing: Dictionary, bbox: Vector3, method: String) -> Dictionary:
	var b := Vector3(maxf(bbox.x, 1e-4), maxf(bbox.y, 1e-4),
		maxf(bbox.z, 1e-4))
	if thing.state in ["card", "board"]:
		var s := CARD_M / maxf(b.x, b.y)
		return {"rot": Vector3.ZERO, "scale": Vector3(s, s, s)}
	var sz: Array = thing.size_m
	var size := Vector3(maxf(float(sz[0]), 1e-3), maxf(float(sz[1]), 1e-3),
		maxf(float(sz[2]), 1e-3))
	var turns := [[Vector3.ZERO, b], [Vector3(-90, 0, 0),
		Vector3(b.x, b.z, b.y)], [Vector3(0, 0, 90), Vector3(b.y, b.x, b.z)],
		[Vector3(0, 90, 0), Vector3(b.z, b.y, b.x)]]
	var best: Array = turns[0]
	var best_spread := INF
	for t in turns:
		var cand: Vector3 = t[1]
		var r := [log(size.x / cand.x), log(size.y / cand.y),
			log(size.z / cand.z)]
		var spread: float = r.max() - r.min()
		if spread < best_spread - 1e-9:
			best_spread = spread
			best = t
	var tb: Vector3 = best[1]
	if method == STRETCH_METHOD:
		return {"rot": best[0], "scale": Vector3(size.x / tb.x,
			size.y / tb.y, size.z / tb.z)}
	var s := minf(minf(size.x / tb.x, size.y / tb.y), size.z / tb.z)
	return {"rot": best[0], "scale": Vector3(s, s, s)}


# --- The plan of a place ------------------------------------------------------

## The name the heart's person is known by: the hint's own words, which
## never carry a church title (TABOO 0.39 item 3).
static func person_of(heart: Dictionary) -> String:
	var ru: String = heart.get("ru", "")
	return ru.trim_prefix("Поговорить: ") \
		if heart.get("step", "") == "dialogue" else ""


## Everything the scene builds for one place, from the data alone.
static func plan(loc: Dictionary, things: Dictionary,
		items: Dictionary, kits := {}) -> Dictionary:
	var sh: Dictionary = loc.shell
	var w := float(sh.size_m[0])
	var d := float(sh.size_m[1])
	var h := float(sh.size_m[2])
	var heart := Vector3(float(sh.heart_at[0]), 0.0, float(sh.heart_at[2]))
	# The way back stands at the entrance; the player starts a little
	# inside it, facing the heart.
	var exit := Vector3(0.0, 0.0, d / 2.0 - 0.3)
	var start := exit - Vector3(0.0, 0.0, START_IN_M)
	var slots := []
	var missing := []
	var holy_key := ""
	if loc.holy_place != null:
		holy_key = loc.holy_place.thing
	for s in loc.slots:
		var th: Dictionary = things[s.object]
		var m := model_of(s.object, th, items)
		if m.from == "":
			missing.append({"object": s.object, "ru": th.ru, "why": m.why})
			continue
		var holy: bool = th.get("holy") != null
		var p: Array = s.pos
		var at := Vector3(float(p[0]), float(p[1]), float(p[2]))
		var layer := "heart" if s.mount == "heart" \
			else LocationsCore.layer_of(s)
		# A holy card on open ground is not left in the dust: it stands
		# on a low stone (a stone thing) or an oak post (a pile, a cross
		# at the water), within its own slot.
		var plinth = null
		if holy and layer == "ground":
			var stone := str(th.get("material", "")).contains("камень")
			plinth = {"h": 0.3 if stone else 0.9, "stone": stone}
			at.y += float(plinth.h)
		slots.append({"object": s.object, "ru": th.ru, "mount": s.mount,
			"layer": layer, "pos": at, "plinth": plinth,
			"yaw": float(s.yaw), "holy": holy,
			"flags": {"noInteract": holy, "noLoot": holy},
			"tag": not holy and s.mount != "heart",
			"stand": s.mount == "stand", "model": m, "thing": th})
	var bench = null
	if sh.bench != null:
		bench = {"rect": sh.bench, "top": TABLE_TOP.get(sh.type, 0.8),
			"crate": sh.type in ["shore", "open"]}
	var skipped := _place_kits(loc, things, kits.get(loc.id, []), slots,
		missing, {"w": w, "d": d, "h": h, "heart": heart, "exit": exit,
			"start": start, "type": sh.type, "passage": sh.passage,
			"bench": sh.bench})
	var light: Dictionary = loc.light
	var holy_at = null
	for s in slots:
		if s.holy:
			holy_at = s.pos
	return {"id": loc.id, "title": loc.title_ru, "kind": loc.kind,
		"families": loc.families, "type": sh.type, "w": w, "d": d, "h": h,
		"heart": heart, "heart_spec": loc.heart, "hint": loc.heart.ru,
		"person": person_of(loc.heart), "exit": exit, "start": start,
		"passage": sh.passage, "bench": bench, "light": light,
		"colour": kelvin(int(light.kelvin)) if light["class"] == "hearth"
			else LAMPADA_K if light["class"] == "lampada" else INSTRUMENT_K,
		"lampada": holy_key != "" and loc.holy_place.lampada,
		"holy_key": holy_key, "holy_at": holy_at, "slots": slots,
		"missing": missing,
		"kits_skipped": skipped,
		"lesson": loc.lesson, "constitution": loc.constitution,
		"kiberslav": "kiberslav" in loc.families}


## How visible the interface should be with the player at pos: 1 far
## from the place's holy thing, 0 beside it, linear between (the
## dive's console does the same at open-water scale, CockpitCore).
## The holy thing's slot is measured on the ground, as the player
## walks.  A place with no holy thing keeps its interface.
static func holy_fade_target(p: Dictionary, pos: Vector3) -> float:
	if p.get("holy_at") == null:
		return 1.0
	var at: Vector3 = p.holy_at
	var d := Vector2(at.x - pos.x, at.z - pos.z).length()
	if d >= HOLY_FAR_M:
		return 1.0
	if d <= HOLY_NEAR_M:
		return 0.0
	return (d - HOLY_NEAR_M) / (HOLY_FAR_M - HOLY_NEAR_M)


# --- The kits of the props store ---------------------------------------------

## The drawings of the 99 repos that passed the pipeline and the eye
## (TABOO 0.012, 0.1; track B), by place: data/location-items.json, one
## row per file a place shows, with the file's alpha box on its canvas
## and the metres of one canvas pixel (so the drawing takes its thing's
## real size).  Only a file in the project is taken.
static func load_kits(path := ITEMS) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	var locs = raw.get("locations", {}) if raw is Dictionary else {}
	var out := {}
	if not locs is Dictionary:
		return out
	for id in locs:
		var rows := []
		for r in locs[id]:
			if not r is Dictionary or not r.has("bboxes") \
					or not r.has("px_m"):
				continue
			var files: Array = r.get("files", [])
			var boxes: Array = r.bboxes
			var changes: Array = r.get("changes", [])
			for i in mini(files.size(), boxes.size()):
				var file := "%s/%s" % [r.kit_dir, files[i]]
				if not ResourceLoader.exists(file):
					continue
				rows.append({"item": str(r.item), "path": file,
					"bbox": boxes[i], "px": float(r.px_m),
					"kit": str(r.get("kit", "")),
					"licence": str(r.get("licence", "")),
					"change": str(changes[i]) if i < changes.size() else ""})
		if not rows.is_empty():
			out[str(id)] = rows
	return out


## A drawing stands no taller than this many times its thing's height.
## The drawings are three-quarter views, so the seat of a bench seen
## from above adds to its drawn height; 1.6 keeps a 0.45 m bench under
## 0.72 m.  The review of 2026-09-30 found 2.5 let a bench stand 1.1 m
## tall, a rack rather than a bench (TABOO 0.013 item 3).
const KIT_TALL := 1.6
## A drawing is like its thing only if its drawn width over height is
## within these factors of the thing's own (its longest ground side
## over its height): a stack of benches (0.69 against 2.67) or a 4 m
## log drawn upright (1.1 against 10) is not stood; the thing waits,
## listed with why, rather than stand as something else.
const LIKE_MIN := 0.4
const LIKE_MAX := 3.0
## A drawing hung on a wall is seen whole from the door: every corner
## within this half-angle of the view ahead (the door frame at
## 1280x720 sees about 53 degrees each way; the margin keeps the whole
## drawing inside it).  The frames of 2026-09-30 showed the tools cut by
## the edge in the forge, the silversmith's and the armourer's.
const KIT_VIEW_DEG := 40.0
## Margin between a drawing and anything else, and the step and reach of
## the search for its spot around its slot.
const KIT_GAP := 0.08
const KIT_STEP := 0.1
const KIT_STEPS := 20
## At most two states of one thing in a place (TABOO 0.013 item 4).
const MAX_STATES := 2


## The model of a drawing: the file, the drawn part of its canvas and
## the metres of a pixel, capped by KIT_TALL and the room's height.
static func kit_model(row: Dictionary, thing: Dictionary, wall: bool,
		room_h: float) -> Dictionary:
	var b: Array = row.bbox
	var bw := float(b[2]) - float(b[0])
	var bh := float(b[3]) - float(b[1])
	var px: float = row.px
	var cap := maxf(KIT_TALL * float(thing.size_m[1]), 0.6)
	if room_h > 0.0:
		cap = minf(cap, room_h - 0.4)
	if bh * px > cap:
		px = cap / bh
	return {"from": "kit", "path": row.path, "meta": "",
		"region": Rect2(float(b[0]), float(b[1]), bw, bh), "px": px,
		"w": bw * px, "h": bh * px, "billboard": not wall, "kit": row.kit,
		"licence": row.licence, "change": row.change}


## The ground a drawing takes: a billboard turns about its upright, so
## it takes a square of its width; a drawing on a wall lies along it.
static func kit_rect(at: Vector3, yaw: float, w: float,
		billboard: bool) -> Rect2:
	if billboard:
		return Rect2(at.x - w / 2.0, at.z - w / 2.0, w, w)
	if absf(sin(deg_to_rad(yaw))) > 0.5:
		return Rect2(at.x - 0.03, at.z - w / 2.0, 0.06, w)
	return Rect2(at.x - w / 2.0, at.z - 0.03, w, 0.06)


## The ground a placed thing takes, near enough to keep a drawing off
## it: a card its width, a volume its size, both turned by the yaw.
static func slot_rect(s: Dictionary) -> Rect2:
	if s.model.from == "kit":
		return kit_rect(s.pos, s.yaw, s.model.w, s.model.billboard)
	var th: Dictionary = s.thing
	var a := CARD_M
	var c := 0.12
	if not th.state in ["card", "board"]:
		a = float(th.size_m[0])
		c = float(th.size_m[2])
	if s.stand:
		a = maxf(a, 0.8)
		c = maxf(c, 0.25)
	if absf(sin(deg_to_rad(s.yaw))) > 0.5:
		var t := a
		a = c
		c = t
	return Rect2(s.pos.x - a / 2.0, s.pos.z - c / 2.0, a, c)


static func _rect_of(r: Array) -> Rect2:
	return Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]),
		float(r[3]) - float(r[1]))


## Whether a drawing may take this ground: inside the place, clear of
## the heart and the way back, off the walk from the door, off every
## other thing, on the bench if it is a bench thing and off it if not.
static func _kit_fits(r: Rect2, layer: String, room: Dictionary,
		taken: Array) -> bool:
	var inner := Rect2(-room.w / 2.0 + 0.1, -room.d / 2.0 + 0.1,
		room.w - 0.2, room.d - 0.2)
	if layer == "wall":
		inner = inner.grow(0.15)
		if not _in_view(r, room):
			return false
	if not inner.encloses(r):
		return false
	var heart := Vector2(room.heart.x, room.heart.z)
	var exit := Vector2(room.exit.x, room.exit.z)
	if LocationsCore.gap(heart, r) < CLEAR_M + 0.05 \
			or LocationsCore.gap(exit, r) < CLEAR_M + 0.05:
		return false
	if room.passage != null and layer != "wall" \
			and _rect_of(room.passage).intersects(r):
		return false
	for o in taken:
		if (o as Rect2).grow(KIT_GAP).intersects(r):
			return false
	if layer == "top":
		return room.bench != null \
			and _rect_of(room.bench).grow(0.05).encloses(r)
	if layer == "ground" and room.bench != null \
			and _rect_of(room.bench).grow(KIT_GAP).intersects(r):
		return false
	return true


## Whether all of a ground rectangle lies ahead of the door within
## KIT_VIEW_DEG of the view.
static func _in_view(r: Rect2, room: Dictionary) -> bool:
	var st: Vector3 = room.start
	var k := tan(deg_to_rad(KIT_VIEW_DEG))
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)]:
		var ahead: float = st.z - c.y
		if ahead < 0.3 or absf(c.x - st.x) > ahead * k:
			return false
	return true


## How a drawing's proportions stand to its thing's: drawn width over
## height, divided by the thing's longest ground side over its height.
## 1 is the thing's own; LIKE_MIN and LIKE_MAX bound what is stood.
static func likeness(km: Dictionary, thing: Dictionary) -> float:
	var sz: Array = thing.size_m
	var real := maxf(float(sz[0]), float(sz[2])) / maxf(float(sz[1]), 1e-3)
	return (float(km.w) / maxf(float(km.h), 1e-4)) / real


## The first spot around base where a drawing fits, nearest first: along
## the wall for a wall, on a ring of eight ways for the ground and the
## bench.  null when none within KIT_STEPS steps.
static func _kit_spot(base: Vector3, yaw: float, km: Dictionary,
		layer: String, room: Dictionary, taken: Array) -> Variant:
	var along := Vector3(1, 0, 0).rotated(Vector3.UP, deg_to_rad(yaw))
	for k in KIT_STEPS + 1:
		var dirs := [Vector3.ZERO]
		if k > 0:
			dirs = [along, -along] if layer == "wall" else []
			if layer != "wall":
				for i in 8:
					dirs.append(Vector3(1, 0, 0).rotated(Vector3.UP,
						i * PI / 4.0))
		# On each ring the spots farther from the door come first: the
		# frames showed a drawing hung by the door, cut by the view as
		# the player enters; deeper in, it is seen with the heart.
		var ring := []
		for i in dirs.size():
			var at: Vector3 = base + dirs[i] * (k * KIT_STEP)
			at = Vector3(snappedf(at.x, 0.001), at.y, snappedf(at.z, 0.001))
			ring.append([-Vector2(at.x - room.exit.x,
				at.z - room.exit.z).length(), i, at])
		ring.sort_custom(_nearer)
		for c in ring:
			if _kit_fits(kit_rect(c[2], yaw, km.w, km.billboard), layer,
					room, taken):
				return c[2]
	return null


## Farther from the door first; on a tie, the earlier way (deterministic).
static func _nearer(a: Array, b: Array) -> bool:
	if absf(a[0] - b[0]) > 1e-6:
		return a[0] < b[0]
	return a[1] < b[1]


## Stands the place's drawings: a drawing fills the slot of a thing that
## has no model yet, or stands as the second state beside our own proxy
## of it (never more than MAX_STATES of one thing, never a holy thing).
## Returns what could not be stood, and why; nothing is hidden.
static func _place_kits(loc: Dictionary, things: Dictionary, rows: Array,
		slots: Array, missing: Array, room: Dictionary) -> Array:
	var skipped := []
	var taken := []
	for s in slots:
		taken.append(slot_rect(s))
	var states := {}
	for s in slots:
		states[s.object] = int(states.get(s.object, 0)) + 1
	for row in rows:
		var key: String = row.item
		var th: Dictionary = things.get(key, {})
		var slot = null
		for s in loc.slots:
			if s.object == key:
				slot = s
				break
		if th.is_empty() or slot == null:
			skipped.append({"object": key, "why": "no slot in the place"})
			continue
		if th.get("holy") != null:
			skipped.append({"object": key, "why": "holy, never raw"})
			continue
		if int(states.get(key, 0)) >= MAX_STATES:
			skipped.append({"object": key, "why": "two states already"})
			continue
		var fill: bool = missing.any(func(m): return m.object == key)
		var layer := LocationsCore.layer_of(slot)
		# Beside a proxy on posts, the drawing lies on the ground.
		if slot.mount == "stand" and not fill:
			layer = "ground"
		var p: Array = slot.pos
		var base := Vector3(float(p[0]), 0.0 if layer == "ground"
			else float(p[1]), float(p[2]))
		var km := kit_model(row, th, layer == "wall", room.h)
		var like := likeness(km, th)
		if like < LIKE_MIN or like > LIKE_MAX:
			skipped.append({"object": key, "why":
				"not like its thing (drawn %.2f of its proportions)" % like})
			continue
		var yaw := float(slot.yaw)
		var at = _kit_spot(base, yaw, km, layer, room, taken)
		if at == null and layer == "wall" \
				and room.type in ["room", "cave", "yard"]:
			# A side wall near the door is not seen whole from it; the
			# back wall, facing the door, is (KIT_VIEW_DEG).
			# It starts a quarter of the room off the middle, on its own
			# wall's side: the middle of the back wall is behind the heart,
			# and a drawing there stood behind the person's head.
			yaw = 0.0
			at = _kit_spot(Vector3(signf(base.x) * room.w / 4.0, base.y,
				-room.d / 2.0 + 0.05), yaw, km, layer, room, taken)
		if at == null:
			skipped.append({"object": key,
				"why": "no clear ground near its slot"})
			continue
		var s := {"object": key, "ru": th.ru, "mount": slot.mount if fill
			else "beside", "layer": layer, "pos": at, "plinth": null,
			"yaw": yaw, "holy": false,
			"flags": {"noInteract": false, "noLoot": false}, "tag": fill,
			"stand": false, "model": km, "thing": th, "second": not fill}
		slots.append(s)
		taken.append(slot_rect(s))
		states[key] = int(states.get(key, 0)) + 1
		if fill:
			for i in missing.size():
				if missing[i].object == key:
					missing.remove_at(i)
					break
	return skipped


## The colour of a warm light of the given temperature (Tanner Helland's
## fit of the black-body curve), for the hearth class of 1900-2500 K.
static func kelvin(k: int) -> Color:
	var t := k / 100.0
	var r := 255.0
	var g := 99.4708025861 * log(t) - 161.1195681661
	var b := 0.0 if t <= 19.0 else 138.5177312231 * log(t - 10.0) \
		- 305.0447927307
	if t > 66.0:
		r = 329.698727446 * pow(t - 60.0, -0.1332047592)
		g = 288.1221695283 * pow(t - 60.0, -0.0755148492)
		b = 255.0
	return Color(clampf(r / 255.0, 0, 1), clampf(g / 255.0, 0, 1),
		clampf(b / 255.0, 0, 1))


## The name tags and labels a place shows, for the check that no church
## word is a label (TABOO 0.39 item 3).
static func labels(p: Dictionary) -> Array:
	var out := [p.title, p.hint, exit_ru(p)]
	if p.person != "":
		out.append(p.person)
	for s in p.slots:
		if s.tag:
			out.append(s.ru)
	return out


static func exit_ru(p: Dictionary) -> String:
	return "Всплыть: назад к пристани обители" if p.type == "underwater" \
		else "Дорога назад во двор обители"


# --- Going there and back -----------------------------------------------------

static func go(tree: SceneTree, id: String) -> void:
	tree.root.set_meta(META_KEY, id)
	tree.change_scene_to_file(SCENE)


static func chosen(tree: SceneTree) -> String:
	return str(tree.root.get_meta(META_KEY, ""))


# --- The player's saves -------------------------------------------------------

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## What a place reads of the hub's save, in the same known shapes the
## hub's _load keeps (a hand-edited save cannot smuggle in counters).
static func read_state(hub_path := HUB_SAVE, dive_path := DIVE_SAVE,
		day := "") -> Dictionary:
	var data := _read(hub_path)
	var form := HubCore.new_form()
	var src_form = data.get("form", {})
	if src_form is Dictionary:
		for a in HubCore.ATTRIBUTES:
			form[a] = int(src_form.get(a, form[a]))
	var actions := RuleCore.normalize(data.get("actions", {}))
	var trials := TrialCore.empty_state()
	var ts = data.get("trials", {})
	if ts is Dictionary:
		for g in TrialCore.GATE_IDS:
			if ts.get("trials", {}).get(g, false) == true:
				trials.trials[g] = true
			var wt = ts.get("trial_wait", {}).get(g)
			if typeof(wt) in [TYPE_INT, TYPE_FLOAT]:
				trials.trial_wait[g] = int(wt)
		var f = ts.get("fall")
		if f is Dictionary and f.get("since") is Dictionary:
			trials.fall = f
	var bag = _read(dive_path).get("bag", {})
	var given = bag.get("atlas", []) if bag is Dictionary else []
	return {"form": form, "actions": actions, "trials": trials,
		"passions": PassionCore.normalize_record(data.get("passions", {})),
		"chronicle": data.get("chronicle"),
		"atlas_given": given if given is Array else [],
		"deeds": PlaceDeeds.normalize(data.get("deeds", {})),
		# The road of missions, for the step of a story done at a heart
		# (StoryRoute); only the shapes MissionCore keeps come back.
		"missions": _missions(data.get("missions", {})),
		"day": day if day != "" else Time.get_date_string_from_system()}


static func _missions(raw) -> Dictionary:
	var ms := MissionCore.normalize_state(raw)
	return {"done": ms.done, "current": ms.current, "flags": ms.flags,
		"lines": ms.lines}


## Write back what a place may change, keeping every other key of the
## hub's save.  The road of missions is written only when the state
## carries it (a story's step done at a heart, StoryRoute).
static func write_state(st: Dictionary, hub_path := HUB_SAVE) -> void:
	var data := _read(hub_path)
	if st.has("missions"):
		data["missions"] = _missions(st.missions)
	data["form"] = st.form
	data["actions"] = st.actions
	data["trials"] = st.trials
	data["passions"] = st.passions
	data["deeds"] = PlaceDeeds.normalize(st.get("deeds", {}))
	if typeof(st.chronicle) == TYPE_STRING and st.chronicle != "":
		data["chronicle"] = st.chronicle
	var f := FileAccess.open(hub_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


## The knight's things handed to the scribe go into the dive's save,
## beside its own pockets, as dive.gd keeps them.
static func write_given(given: Array, dive_path := DIVE_SAVE) -> void:
	var data := _read(dive_path)
	var bag = data.get("bag", {})
	if not bag is Dictionary:
		bag = {}
	for k in ["kept", "released", "handed_over"]:
		if not bag.has(k):
			bag[k] = []
	bag["atlas"] = given
	data["bag"] = bag
	if not data.has("done"):
		data["done"] = []
	var f := FileAccess.open(dive_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
