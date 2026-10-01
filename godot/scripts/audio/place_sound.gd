## The sound plan of a place: what is heard in it, where, and how loud
## (docs/HLD_APK_GRAPHICS_SOUND_2026-10-01.md, track A).
##
## The plan is derived from the place's own data, with nothing random:
## its kind of shell (indoor, outdoor or water), its class of light
## (lampada, hearth, instrument; TABOO 0.38 point 1), its sky and the
## real things on its slots.  Four layers, no music among them:
##   bed      room tone and one's own breath, always (never digital
##            zero, TABOO 0.4 rule 2), with the air of an outdoor place
##            (wind by day, insects by night);
##   crafts   the work of the place, at the thing that makes it: the
##            smith's hammer at the anvil, the wheel at the potter's
##            wheel, the water at the pier, the pen at the inkwell;
##   machine  the hum of an instrument (6500 K places only); it drops
##            to -60 dBFS when one stands by a holy thing (TABOO 0.4
##            rule 2);
##   bell     only in the courtyard of the obitel, and only by the
##            clock and the Typikon (TypikonCore through WitnessAudio):
##            no place has a bell, and no plan has a hook to ring one.
## There is no ison in any plan, so the ison and the bell are never
## heard together here (TABOO 0.35 rule 10).
##
## Every craft is synthesised from the medians of its slot in
## godot/data/audio-references.json (centroid, attack, T60): the
## references of the 99 repos are measured, never played (TABOO 0.35
## rule 8).  Where a slot has no T60 (fewer than three single blows),
## the voice names its own fallback, a design choice labelled as such.
class_name PlaceSound
extends RefCounted

const RATE := 44100
const REFERENCES := "res://data/audio-references.json"

## Levels in dBFS RMS of each loop at its source (a craft at 1 m: the
## 3D player's unit size).  Room tone and breath sit in the -40...-50
## band of TABOO 0.4 rule 2; the air of a place is below them.
const ROOM_DB := -48.0
const BREATH_DB := -46.0
const AIR_DB := -52.0
## The holy thing: the machine layer at its source goes down to this.
const HOLY_DB := -60.0
## As the interface does (LocationCore.HOLY_NEAR_M / HOLY_FAR_M).
const HOLY_NEAR_M := 1.0
const HOLY_FAR_M := 1.8
## The breath of the bed: the basic pattern of the hesychasm module
## (RopeCore.BREATH, TABOO 0.35 rule 20); its cycle is the bed's loop.
const BREATH_PATTERN := "basic"

## At most this many crafts sound in one place: with the bed and the
## machine, five players at most (docs/APK_REQUIREMENTS.md, audio).
const MAX_CRAFTS := 3

## The crafts: the reference slot, the voice that synthesises it, its
## loop in seconds, its level at 1 m and what it means.  The order is
## the priority when a place has more than MAX_CRAFTS of them.
const CRAFTS := {
	"forge": {"ref": "workshop.forge", "voice": "impacts",
		"material": "metal", "loop": 3.0, "db": -30.0,
		"meaning": "Кузнец бьёт по наковальне: ремесло слышно раньше, "
			+ "чем видно."},
	"wheel": {"ref": "workshop.wood", "voice": "wheel", "rpm": 90.0,
		"loop": 4.0, "db": -36.0,
		"meaning": "Гончарный круг шуршит под рукой: глина ждёт "
			+ "терпения."},
	"mill": {"ref": "workshop.stone", "voice": "wheel", "rpm": 30.0,
		"loop": 4.0, "db": -34.0,
		"meaning": "Жёрнов мелет медленно: хлеб приходит не сразу."},
	"loom": {"ref": "workshop.wood", "voice": "impacts",
		"material": "wood", "loop": 4.8, "db": -34.0,
		"meaning": "Бёрдо прибивает уток: ткань растёт по нитке."},
	"adze": {"ref": "workshop.wood", "voice": "impacts",
		"material": "wood", "loop": 4.5, "db": -32.0,
		"meaning": "Тесло снимает стружку: дерево слушается руки."},
	"press": {"ref": "workshop.wood", "voice": "strokes", "loop": 6.0,
		"db": -38.0,
		"meaning": "Пресс скрипит под рукой печатника: лист ложится "
			+ "ровно."},
	"hearth": {"ref": "workshop.hearth", "voice": "hearth", "loop": 5.0,
		"db": -36.0,
		"meaning": "Огонь очага потрескивает: человеческая работа и "
			+ "тепло, не лампада."},
	"water": {"ref": "lake.water", "voice": "lapping", "loop": 6.0,
		"db": -34.0,
		"meaning": "Вода плещет у берега: озеро рядом, его слышно."},
	"pen": {"ref": "workshop.scroll", "voice": "strokes", "loop": 6.0,
		"db": -40.0,
		"meaning": "Перо скрипит по листу: писец работает, слова не "
			+ "слышны."},
	"bees": {"ref": "lake.insects", "voice": "buzz", "loop": 4.0,
		"db": -40.0,
		"meaning": "Пчёлы гудят у ульев: труд без суеты."},
	"rain": {"ref": "lake.rain", "voice": "rain", "loop": 5.0,
		"db": -38.0,
		"meaning": "Дождь и ветер бухты: ждут, пока утихнет."},
}

## The real things that make a craft heard, by their id.
const OBJECT_CRAFT := {
	"anvil": "forge", "forge": "forge",
	"potter-wheel": "wheel",
	"mill-wheel": "mill", "hand-mill": "mill",
	"loom": "loom",
	"adze": "adze", "caulker": "adze",
	"binding-press": "press",
	"campfire": "hearth", "tonir": "hearth", "kiln": "hearth",
	"signal-fire": "hearth", "cauldron-camp": "hearth",
	"cauldron-common": "hearth",
	"inkwell": "pen", "wax-tablet": "pen", "parchment": "pen",
	"boat": "water", "boat-hull": "water", "oar": "water", "net": "water",
	"float": "water", "reed-bed": "water", "anchor-stone": "water",
	"sluice": "water", "well-bucket": "water",
	"beehive": "bees",
}

## Places whose kind brings a craft even without its thing on a slot.
const KIND_CRAFT := {"storm-bay": "rain", "water-mill": "water"}

## The things of an instrument place where its hum comes from.
const MACHINE_THINGS := ["server-rack", "screen", "rov-log",
	"depth-gauge", "keyboard", "phone"]
## The machine: the hum of the reference rov.motor and the switches of
## rov.console, at 1 m.
const MACHINE := {"ref": "rov.motor", "click_ref": "rov.console",
	"loop": 4.0, "db": -40.0,
	"meaning": "Прибор гудит ровно; у святыни он смолкает."}

static var _refs: Dictionary = {}


static func references() -> Dictionary:
	if _refs.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(REFERENCES))
		_refs = d.slots if d is Dictionary else {}
	return _refs


## The medians of a reference slot: {centroid, attack, t60}; t60 is 0
## where the slot has none (the voice then uses its own fallback).
static func ref_of(slot: String) -> Dictionary:
	var r: Dictionary = references().get(slot, {})
	return {"slot": slot,
		"centroid": float(r.get("centroid_median_hz", 0.0) if
			r.get("centroid_median_hz") != null else 0.0),
		"attack": float(r.get("attack_median_ms", 0.0) if
			r.get("attack_median_ms") != null else 0.0) / 1000.0,
		"t60": float(r.get("t60_median_s")) if r.get("t60_median_s") != null
			else 0.0}


static func biome(type: String) -> String:
	if type == "underwater":
		return "water"
	if type in ["yard", "open", "shore"]:
		return "outdoor"
	return "indoor"


## A stable seed from a text (FNV-1a, as RopeBreath does).
static func seed_of(text: String) -> int:
	var h := 2166136261
	for ch in text.to_utf8_buffer():
		h = ((h ^ ch) * 16777619) & 0xFFFFFFFF
	return h if h != 0 else 1


static func _craft(id: String, object: String, at: Vector3,
		place: String) -> Dictionary:
	var c: Dictionary = CRAFTS[id]
	var v := {"craft": id, "object": object, "pos": at,
		"voice": c.voice, "loop": float(c.loop), "rms_db": float(c.db),
		"ref": ref_of(c.ref), "meaning": c.meaning,
		"seed": seed_of(place + "|" + id)}
	for k in ["material", "rpm"]:
		if c.has(k):
			v[k] = c[k]
	return v


## The bed of a place: room tone and breath, and the air outside.
static func _bed(place: String, kind: String, sky: String) -> Dictionary:
	var air := ""
	if kind == "outdoor":
		air = "insects" if sky == "night" else "wind"
	return {"room_db": ROOM_DB, "breath_db": BREATH_DB,
		"breath": BREATH_PATTERN, "air": air, "air_db": AIR_DB,
		"air_ref": ref_of("lake.insects" if air == "insects"
			else "lake.wind"),
		"dark": kind != "outdoor",
		"loop": RopeCore.cycle(BREATH_PATTERN),
		"seed": seed_of(place + "|bed")}


## The plan of one place from LocationCore.plan(): the same place gives
## the same plan, sample for sample.
static func plan(p: Dictionary) -> Dictionary:
	var kind := biome(str(p.type))
	var light: String = p.light["class"]
	var crafts: Array = []
	var seen := {}
	var found: Array = []
	for s in p.slots:
		var id: String = OBJECT_CRAFT.get(s.object, "")
		if id == "" or s.holy:
			continue
		found.append([id, s.object, s.pos])
	if KIND_CRAFT.has(p.kind):
		found.append([KIND_CRAFT[p.kind], "", p.heart])
	# On a shore the water is heard at its edge, behind the place.
	if p.type == "shore":
		found.append(["water", "", Vector3(0.0, 0.0, -p.d / 2.0 - 0.5)])
	var order := CRAFTS.keys()
	found.sort_custom(func(a, b): return order.find(a[0]) < order.find(b[0]))
	for f in found:
		if seen.has(f[0]) or crafts.size() >= MAX_CRAFTS:
			continue
		# Under water nothing of the shore is heard but the machine.
		if kind == "water":
			continue
		seen[f[0]] = true
		crafts.append(_craft(f[0], f[1], f[2], p.id))
	var machine = null
	if light == "instrument":
		var at = null
		for s in p.slots:
			if s.object in MACHINE_THINGS:
				at = s.pos
				break
		# An instrument room whose instrument is not drawn hums at its
		# heart, the panel one works at; under water the hum is the ROV
		# one sits in, so it is not placed.
		if at == null:
			at = p.heart + Vector3(0.0, 1.0, 0.0)
		machine = _machine(p.id, at if kind != "water" else null)
	var holy: Array = []
	for s in p.slots:
		if s.holy:
			holy.append(s.pos)
	return {"id": p.id, "biome": kind, "light": light,
		"bed": _bed(p.id, kind, str(p.light.get("sky", ""))),
		"crafts": crafts, "machine": machine, "holy": holy,
		"bell": false, "ison": false}


static func _machine(place: String, at) -> Dictionary:
	return {"pos": at, "loop": float(MACHINE.loop),
		"rms_db": float(MACHINE.db), "ref": ref_of(MACHINE.ref),
		"click": ref_of(MACHINE.click_ref), "meaning": MACHINE.meaning,
		"seed": seed_of(place + "|machine")}


## The courtyard of the obitel (hub.gd): the lake on the east, the
## hearth of the workshop, the scriptorium's pen, the ROV on the pier,
## the evening air; and the bell of the obitel, by the Typikon only.
## holy: the places of the lampada and of the holy image of the cell.
static func hub_plan(holy: Array) -> Dictionary:
	var id := "hub-courtyard"
	return {"id": id, "biome": "outdoor", "light": "hearth",
		"bed": _bed(id, "outdoor", "dusk"),
		"crafts": [_craft("hearth", "hearth", Vector3(2.2, 0.3, -2.4), id),
			_craft("water", "", Vector3(9.5, 0.0, -3.0), id),
			_craft("pen", "inkwell", Vector3(-5.6, 0.85, 1.2), id)],
		"machine": _machine(id, Vector3(8.4, 0.85, 0.0)),
		"holy": holy, "bell": true, "ison": false}


## How far the machine layer is let through with the listener at pos:
## 1 away from every holy thing, 0 beside one, linear between.
static func machine_open(pl: Dictionary, pos: Vector3) -> float:
	var f := 1.0
	for h in pl.holy:
		var d := Vector2(h.x - pos.x, h.z - pos.z).length()
		var g := clampf((d - HOLY_NEAR_M) / (HOLY_FAR_M - HOLY_NEAR_M),
			0.0, 1.0)
		f = minf(f, g)
	return f


## The gain in dB on the machine layer when it is let through by open:
## 0 dB fully open, and at 0 its source sits at HOLY_DB.
static func machine_gain_db(pl: Dictionary, open: float) -> float:
	if pl.machine == null:
		return 0.0
	var mute: float = HOLY_DB - float(pl.machine.rms_db)
	return lerpf(mute, 0.0, clampf(open, 0.0, 1.0))


## The count of players a plan needs: the bed, its crafts, the machine
## and, in the courtyard, the bell's generator.
static func players(pl: Dictionary) -> int:
	return 1 + pl.crafts.size() + (1 if pl.machine != null else 0) \
		+ (1 if pl.bell else 0)


## Bytes of 16-bit mono PCM the plan's loops hold in RAM.
static func pcm_bytes(pl: Dictionary) -> int:
	var sec: float = pl.bed.loop
	for c in pl.crafts:
		sec += c.loop
	if pl.machine != null:
		sec += pl.machine.loop
	return int(round(sec * RATE)) * 2
