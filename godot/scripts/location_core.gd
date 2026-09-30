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
		items: Dictionary) -> Dictionary:
	var sh: Dictionary = loc.shell
	var w := float(sh.size_m[0])
	var d := float(sh.size_m[1])
	var h := float(sh.size_m[2])
	var heart := Vector3(float(sh.heart_at[0]), 0.0, float(sh.heart_at[2]))
	# The way back stands at the entrance; the player starts a little
	# inside it, facing the heart.
	var exit := Vector3(0.0, 0.0, d / 2.0 - 0.3)
	var start := Vector3(0.0, 0.0, d / 2.0 - 1.2)
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
	var light: Dictionary = loc.light
	return {"id": loc.id, "title": loc.title_ru, "kind": loc.kind,
		"families": loc.families, "type": sh.type, "w": w, "d": d, "h": h,
		"heart": heart, "heart_spec": loc.heart, "hint": loc.heart.ru,
		"person": person_of(loc.heart), "exit": exit, "start": start,
		"passage": sh.passage, "bench": bench, "light": light,
		"colour": kelvin(int(light.kelvin)) if light["class"] == "hearth"
			else LAMPADA_K if light["class"] == "lampada" else INSTRUMENT_K,
		"lampada": holy_key != "" and loc.holy_place.lampada,
		"holy_key": holy_key, "slots": slots, "missing": missing,
		"lesson": loc.lesson, "constitution": loc.constitution,
		"kiberslav": "kiberslav" in loc.families}


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
		"day": day if day != "" else Time.get_date_string_from_system()}


## Write back what a place may change, keeping every other key of the
## hub's save (the road of missions stays the hub's).
static func write_state(st: Dictionary, hub_path := HUB_SAVE) -> void:
	var data := _read(hub_path)
	data["form"] = st.form
	data["actions"] = st.actions
	data["trials"] = st.trials
	data["passions"] = st.passions
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
