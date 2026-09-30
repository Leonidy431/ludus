## The rules of the dive, ported from public/ludus/dive/dive-core.js.
##
## The JS module is the reference: tests/dive-core.test.js checks the
## rules there, and godot/tests/test_dive_core.gd checks that this port
## gives the same numbers on a shared fixture
## (godot/tests/fixture.json, written by scripts/godot/make_fixture.js).
## Everything is deterministic: the same seed gives the same lake
## (CLAUDE.md TABOO 0.35 rule 15, no randomness).
class_name DiveCore
extends RefCounted

## Shore distance (m) -> floor depth (m); see dive-core.js for why.
const PROFILE := [[0.0, 0.0], [40.0, 3.0], [160.0, 20.0], [230.0, 32.0],
	[260.0, 38.0], [420.0, 125.0], [520.0, 150.0], [700.0, 165.0]]
const LENGTH_M := 700.0
const HALF_WIDTH_M := 90.0
const THERMOCLINE_M := 50.0
## Things gather along the dive line so the ROV meets them.
const CORRIDOR_M := 30.0
const T_SURFACE := 18.0
const T_DEEP := 4.5
const ROV := {
	"max_speed": 1.0, "max_vertical": 0.5, "accel": 0.8, "drag": 1.2,
	"yaw_rate": 0.9, "battery_sec": 1800.0, "min_clearance": 0.6,
	"max_depth": 300.0,
}
# Water physics (public/ludus/ludus-water.js, rule 19).
const C_ABOVE := 1480.0
const C_BELOW := 1435.0
const SURFACE_BAR := 1.01325
const METRES_PER_BAR := 10.2
const MAX_ASCENT_M_PER_MIN := 10.0
const ABSORPTION := {"red": 0.34, "green": 0.057, "blue": 0.009}
const MASK := 0xFFFFFFFF
const IN_WATER := ["plankton", "caustics", "shafts", "thermo", "snow",
	"bubbles", "turbid", "seiche", "karman", "intwave", "plume",
	"langmuir", "upwelling"]
const LOOT_WORDS := {
	"keep": "Взято в сумку.",
	"release": "Записано в журнал улова и отпущено: эту рыбу озеро бережёт.",
	"hand-over": "Отложено для скриптория: чей это дом — узнает писец.",
	"none": "Взять нечего — только смотреть.",
	"cross": "На ней крест. Не трогаем, оставляем на месте.",
	"site": "Это часть памятника. Оставить на месте.",
	"bird": "Живая птица. Только смотреть.",
	"water": "Воду не унести. Только смотреть.",
}


## 32-bit multiply like JS Math.imul, on unsigned values.  Split in
## 16-bit halves so no product leaves the 64-bit integer range.
static func _imul(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	var lo := (a & 0xFFFF) * b
	var hi := (((a >> 16) * b) & 0xFFFF) << 16
	return (lo + hi) & MASK


## FNV-1a over UTF-16 code units, as the JS hash() does.
static func _hash(text: String) -> int:
	var h := 2166136261
	for i in text.length():
		h ^= text.unicode_at(i)
		h = _imul(h, 16777619)
	return h & MASK


## A seeded generator (mulberry32): returns a Callable giving [0, 1).
static func rng(seed_text: String) -> Callable:
	var state := [_hash(seed_text)]
	return func() -> float:
		state[0] = (state[0] + 0x6D2B79F5) & MASK
		var t: int = state[0]
		t = _imul(t ^ (t >> 15), t | 1)
		t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & MASK)) & MASK
		return float((t ^ (t >> 14)) & MASK) / 4294967296.0


static func base_depth(x: float) -> float:
	var cx := clampf(x, 0.0, LENGTH_M)
	for i in range(1, PROFILE.size()):
		var x0: float = PROFILE[i - 1][0]
		var d0: float = PROFILE[i - 1][1]
		var x1: float = PROFILE[i][0]
		var d1: float = PROFILE[i][1]
		if cx <= x1:
			return d0 + (d1 - d0) * (cx - x0) / (x1 - x0)
	return PROFILE[-1][1]


static func floor_depth(x: float, z: float) -> float:
	var d := base_depth(x)
	var rough := 0.15 + minf(1.2, d / 60.0)
	return d + rough * (sin(x * 0.11 + z * 0.07)
		+ 0.5 * sin(z * 0.23 - x * 0.05))


static func x_for_depth(d: float) -> float:
	var cd := clampf(d, 0.0, PROFILE[-1][1])
	for i in range(1, PROFILE.size()):
		var x0: float = PROFILE[i - 1][0]
		var d0: float = PROFILE[i - 1][1]
		var x1: float = PROFILE[i][0]
		var d1: float = PROFILE[i][1]
		if cd <= d1:
			var span := d1 - d0
			if span == 0.0:
				span = 1.0
			return x0 + (x1 - x0) * (cd - d0) / span
	return LENGTH_M


static func temperature(depth: float) -> float:
	var k := 1.0 / (1.0 + exp((depth - THERMOCLINE_M) / 4.0))
	return T_DEEP + (T_SURFACE - T_DEEP) * k


static func light_left(depth: float) -> Dictionary:
	var d := maxf(0.0, depth)
	var out := {}
	for band in ABSORPTION:
		out[band] = exp(-ABSORPTION[band] * d)
	return out


static func sound_speed(depth: float) -> float:
	return C_BELOW if depth > THERMOCLINE_M else C_ABOVE


static func _placement(o: Dictionary) -> String:
	if o.category == "bird":
		return "surface"
	if o.category == "water" or o.item in IN_WATER:
		return "water"
	return "floor"


## Place the lake objects exactly as dive-core.js placeObjects() does.
static func place_objects(objects: Array) -> Array:
	var out := []
	for o in objects:
		if o.category == "fish" or o.item == "tether":
			continue
		var r := rng("dive:" + str(o.id))
		var lo: float = o.depth[0]
		var hi: float = o.depth[1]
		var where := _placement(o)
		var z: float = (r.call() * 2.0 - 1.0) * CORRIDOR_M
		var x: float
		var depth: float
		if where == "floor":
			var target: float = lo + (hi - lo) * (0.2 + 0.6 * r.call())
			x = x_for_depth(target)
			depth = floor_depth(x, z)
			var k := 0
			while k < 40 and (depth < lo or depth > hi):
				x += 1.5 if depth < lo else -1.5
				depth = floor_depth(x, z)
				k += 1
		elif where == "surface":
			depth = minf(hi, 0.5 + r.call() * 2.0)
			x = x_for_depth(maxf(depth + 3.0, 5.0)) + r.call() * 20.0
		else:
			depth = lo + (hi - lo) * (0.25 + 0.5 * r.call())
			x = x_for_depth(depth + 6.0 + r.call() * 10.0)
		out.append({
			"id": o.id, "item": o.item, "category": o.category,
			"ru": o.ru, "shape": o.shape, "colour": o.colour,
			"size": o.size_m, "flags": o.flags, "depth_range": [lo, hi],
			"where": where, "x": x, "z": z, "depth": maxf(0.3, depth),
			"yaw": r.call() * TAU,
		})
	return out


static func fish_schools(fish: Array) -> Array:
	var out := []
	for f in fish:
		var r := rng("school:" + str(f.id))
		var lo: float = f.depth[0]
		var hi: float = f.depth[1]
		var depth: float = lo + (hi - lo) * (0.3 + 0.4 * r.call())
		var bottom: bool = f.get("bottom", false)
		var floor_at: float = depth + 0.8 if bottom \
			else depth + 3.0 + r.call() * 6.0
		var x := x_for_depth(minf(floor_at, PROFILE[-1][1]))
		var count := clampi(roundi(f.school * 2.0), 1, 24)
		out.append({
			"id": f.id, "ru": f.ru, "latin": f.latin, "status": f.status,
			"loot": f.get("loot"), "red_book": f.get("redBook", false),
			"colour": f.colour, "length": f.length, "bottom": bottom,
			"depth_range": [lo, hi],
			"centre": {"x": x, "z": (r.call() * 2.0 - 1.0) * CORRIDOR_M * 0.6,
				"depth": depth},
			"radius": 2.0 + sqrt(count) * 1.5, "count": count,
			"speed": 0.25 + f.length * 0.8, "phase": r.call() * TAU,
		})
	return out


static func fish_at(school: Dictionary, i: int, t: float) -> Dictionary:
	var r := rng(str(school.id) + ":" + str(i))
	var rad: float = school.radius * (0.4 + 0.6 * r.call())
	var off: float = r.call() * TAU
	var dir := 1.0 if str(school.id).length() % 2 == 1 else -1.0
	var a: float = school.phase + off + dir * t * school.speed / rad
	var sway: float = (0.2 if school.bottom else 1.2) * sin(t * 0.4 + off)
	var lo: float = school.depth_range[0]
	var hi: float = school.depth_range[1]
	return {
		"x": school.centre.x + rad * cos(a),
		"z": school.centre.z + rad * sin(a),
		"depth": clampf(school.centre.depth + sway, lo, hi),
		"heading": a + dir * PI / 2.0,
	}


static func new_rov() -> Dictionary:
	return {"x": 30.0, "z": 0.0, "depth": 1.5, "yaw": PI / 2.0,
		"vx": 0.0, "vz": 0.0, "vy": 0.0, "battery": 1.0, "lamp": true,
		"history": []}


## Advance the ROV by dt seconds; input keys forward, strafe, vertical,
## turn in [-1, 1].  Mirrors dive-core.js stepRov().
static func step_rov(state: Dictionary, input: Dictionary,
		dt: float) -> Dictionary:
	var s := state.duplicate()
	var hist: Array = state.history.slice(-40)
	var fwd := clampf(input.get("forward", 0.0), -1.0, 1.0)
	var strafe := clampf(input.get("strafe", 0.0), -1.0, 1.0)
	var ver := clampf(input.get("vertical", 0.0), -1.0, 1.0)
	var turn := clampf(input.get("turn", 0.0), -1.0, 1.0)
	var power := 1.0 if s.battery > 0.0 else 0.0
	s.yaw += turn * ROV.yaw_rate * dt * power
	var ax: float = (cos(s.yaw) * fwd - sin(s.yaw) * strafe) \
		* ROV.accel * power
	var az: float = (sin(s.yaw) * fwd + cos(s.yaw) * strafe) \
		* ROV.accel * power
	s.vx += (ax - ROV.drag * s.vx) * dt
	s.vz += (az - ROV.drag * s.vz) * dt
	s.vy += (ver * ROV.accel * power - ROV.drag * s.vy) * dt
	var h := Vector2(s.vx, s.vz).length()
	if h > ROV.max_speed:
		s.vx *= ROV.max_speed / h
		s.vz *= ROV.max_speed / h
	s.vy = clampf(s.vy, -ROV.max_vertical, ROV.max_vertical)
	s.x = clampf(s.x + s.vx * dt, 2.0, LENGTH_M - 2.0)
	# The current carries the ROV whatever the thrusters do.
	var drift: float = input.get("drift", 0.0)
	s.z = clampf(s.z + (s.vz + drift) * dt, -HALF_WIDTH_M + 2.0,
		HALF_WIDTH_M - 2.0)
	s.depth -= s.vy * dt
	var floor_lim: float = floor_depth(s.x, s.z) - ROV.min_clearance
	s.depth = clampf(s.depth, 0.3, minf(floor_lim, ROV.max_depth))
	var load: float = 0.25 + 0.5 * maxf(absf(fwd), maxf(absf(strafe),
		absf(ver))) + (0.25 if s.lamp else 0.0)
	s.battery = maxf(0.0, s.battery - load * dt / ROV.battery_sec)
	hist.append([dt, s.depth])
	s.history = hist
	return s


static func ascent_rate(state: Dictionary) -> Dictionary:
	var hist: Array = state.history
	var i := hist.size() - 1
	if i < 1:
		return {"m_per_min": 0.0, "too_fast": false}
	var now: float = hist[i][1]
	var t := 0.0
	while i > 0 and t < 1.0:
		t += hist[i][0]
		i -= 1
	if t <= 0.0:
		return {"m_per_min": 0.0, "too_fast": false}
	var m := (float(hist[i][1]) - now) / t * 60.0
	return {"m_per_min": m, "too_fast": m > MAX_ASCENT_M_PER_MIN}


static func telemetry(state: Dictionary) -> Dictionary:
	var floor_d := floor_depth(state.x, state.z)
	var rng_m := maxf(0.0, floor_d - state.depth)
	var up := ascent_rate(state)
	var c := sound_speed(state.depth)
	return {
		"depth": state.depth, "floor": floor_d,
		"temperature": temperature(state.depth),
		"pressure_bar": SURFACE_BAR + maxf(0.0, state.depth) / METRES_PER_BAR,
		"heading": fposmod(rad_to_deg(state.yaw), 360.0),
		"ascent_m_per_min": up.m_per_min, "ascent_too_fast": up.too_fast,
		"battery": state.battery, "sound_speed": c,
		"echo_delay": 2.0 * rng_m / c,
		"below_thermocline": state.depth > THERMOCLINE_M,
		"light": light_left(state.depth), "shore_distance": state.x,
	}


## Apply the loot rule of a thing to the bag; returns {bag, rule, text}.
static func loot_action(thing: Dictionary, bag: Dictionary) -> Dictionary:
	var b := {
		"kept": (bag.get("kept", []) as Array).duplicate(),
		"released": (bag.get("released", []) as Array).duplicate(),
		"handed_over": (bag.get("handed_over", []) as Array).duplicate(),
	}
	var rule = thing.flags.loot if thing.has("flags") else thing.get("loot")
	var id: String = str(thing.get("item", thing.get("id")))
	var text: String = LOOT_WORDS.none
	if rule == "keep":
		if not id in b.kept:
			b.kept.append(id)
		text = LOOT_WORDS.keep
	elif rule == "release":
		b.released.append(id)
		text = LOOT_WORDS.release
	elif rule == "hand-over":
		if not id in b.handed_over:
			b.handed_over.append(id)
		text = LOOT_WORDS["hand-over"]
	elif id == "bulla":
		text = LOOT_WORDS.cross
	elif id == "kosti":
		text = LOOT_WORDS.site
	elif thing.get("category") == "bird":
		text = LOOT_WORDS.bird
	elif thing.get("category") == "water":
		text = LOOT_WORDS.water
	return {"bag": b, "rule": rule, "text": text}


## The nearest thing ahead within reach, or an empty dictionary.
static func nearest(state: Dictionary, things: Array,
		reach: float) -> Dictionary:
	var best := {}
	var best_d := reach
	for t in things:
		var dx: float = t.x - state.x
		var dz: float = t.z - state.z
		var dy: float = t.depth - state.depth
		var d := Vector3(dx, dy, dz).length()
		var ahead: float = dx * cos(state.yaw) + dz * sin(state.yaw)
		if d < best_d and ahead > -0.5:
			best = t
			best_d = d
	if best.is_empty():
		return {}
	return {"thing": best, "distance": best_d}


# --- The dive as a game (dive-core.js stepGame, HLD P2) -------------------

const TASKS := [
	{"id": "hover", "band": "shallows",
		"ru": "Курс: зависнуть на месте 10 с, не уходя по глубине дальше 0,3 м."},
	{"id": "heading", "band": "shallows",
		"ru": "Курс: идти по компасу 10 с, не сбиваясь больше чем на 10°."},
	{"id": "tether", "band": "shallows",
		"ru": "Трос: сделай полный оборот, вернись обратными поворотами к нулю и сними петлю манипулятором."},
	{"id": "slowrise", "band": "shallows",
		"ru": "Курс: подняться на 3 м не быстрее 10 м/мин."},
	{"id": "finds", "band": "shelf",
		"ru": "Шельф: найти три вещи затопленного посада для писца."},
	{"id": "slope", "band": "slope",
		"ru": "Свал: спуститься по тросу на 45 м против течения."},
	{"id": "thermocline", "band": "thermocline",
		"ru": "Термоклин: пересечь слой и услышать, как меняется звук."},
	{"id": "silence", "band": "deep",
		"ru": "Глубина: погасить лампу и замереть на 20 с ниже 100 м."},
]
const SCRIBE_RU := "Писец разложил находки на полотне: «Кирпич с глазурью, черепок, железо. Здесь жил не бедняк — мастер при дороге. Вода пришла, он ушёл, а дом остался говорить за него»."
const SAFETY_STOP_SEC := 15.0
const FALL_AFTER_SEC := 2.0


static func new_game() -> Dictionary:
	var progress := {}
	for t in TASKS:
		progress[t.id] = 0.0
	return {"done": [], "progress": progress, "fallen": false,
		"fast_for": 0.0, "still_for": 0.0, "hold_depth": null,
		"hold_heading": null, "rise_from": null, "crossed_from": null,
		"finds": 0, "scribe_told": false, "turns": 0.0, "last_yaw": null,
		"wound": false, "kink_warned": false}


## Tether turns, as a real ROV console counts them: every full turn of
## the vehicle twists the cable once more.  Three turns kink it.
const KINK_TURNS := 3.0
const UNWOUND_TURNS := 0.1


## arm: true on the step the manipulator reached out (dive.gd).
static func step_game(game: Dictionary, rov: Dictionary, dt: float,
		handed_over: int, arm := false) -> Dictionary:
	var g := game.duplicate(true)
	var say := []
	var tel := telemetry(rov)
	var finish := func(id: String, text: String) -> void:
		if not id in g.done:
			g.done.append(id)
			say.append(text)
	# The tether twists with every turn, fallen or not: the cable does
	# not know about the light.
	if g.last_yaw != null:
		g.turns += wrapf(rov.yaw - g.last_yaw, -PI, PI) / TAU
	g.last_yaw = rov.yaw
	if absf(g.turns) >= 1.0:
		g.wound = true
	if not g.kink_warned and absf(g.turns) >= KINK_TURNS:
		g.kink_warned = true
		say.append("Трос закручен на три оборота: так ломают кабель. Разверни его обратно.")
	elif absf(g.turns) < KINK_TURNS - 1.0:
		g.kink_warned = false
	g.fast_for = g.fast_for + dt if tel.ascent_too_fast else 0.0
	if not g.fallen and g.fast_for >= FALL_AFTER_SEC:
		g.fallen = true
		g.still_for = 0.0
		say.append("Слишком быстро вверх. Свет тускнеет. Остановись и постой: остановка безопасности снимет это.")
	var still := Vector3(rov.vx, rov.vz, rov.vy).length() < 0.05
	g.still_for = g.still_for + dt if still else 0.0
	if g.fallen:
		if g.still_for >= SAFETY_STOP_SEC:
			g.fallen = false
			g.still_for = 0.0
			say.append("Остановка выдержана. Свет вернулся.")
		return {"game": g, "say": say}
	var d: float = rov.depth
	if d < 6.0:
		if still or absf(rov.vy) < 0.03:
			if g.hold_depth == null:
				g.hold_depth = d
			var ok: bool = absf(d - g.hold_depth) <= 0.3
			g.progress.hover = g.progress.hover + dt if ok else 0.0
			if not ok:
				g.hold_depth = d
		else:
			g.hold_depth = null
			g.progress.hover = 0.0
		if g.progress.hover >= 10.0:
			finish.call("hover", "Зависание удалось: ты держишь глубину, а не она тебя.")
		var moving := Vector2(rov.vx, rov.vz).length() > 0.2
		if moving:
			if g.hold_heading == null:
				g.hold_heading = tel.heading
			var diff := absf(fposmod(tel.heading - g.hold_heading + 540.0,
				360.0) - 180.0)
			g.progress.heading = g.progress.heading + dt if diff <= 10.0 \
				else 0.0
			if diff > 10.0:
				g.hold_heading = tel.heading
		else:
			g.hold_heading = null
			g.progress.heading = 0.0
		if g.progress.heading >= 10.0:
			finish.call("heading", "Курс выдержан: компас ведёт, когда глаз ничего не видит.")
	# Tether: wound a full turn, brought back to zero the same way, and
	# the loop lifted off with the manipulator.
	if g.wound and absf(g.turns) <= UNWOUND_TURNS and arm:
		finish.call("tether", "Петля снята: трос не рвут, его разворачивают тем же путём.")
	if rov.vy > 0.01 and not tel.ascent_too_fast:
		if g.rise_from == null:
			g.rise_from = d
		if g.rise_from - d >= 3.0:
			finish.call("slowrise", "Медленное всплытие: воздух в теле успевает за тобой.")
	else:
		g.rise_from = null
	if handed_over > 0:
		g.finds = handed_over
	if g.finds >= 3:
		finish.call("finds", "Три находки у писца.")
		if not g.scribe_told:
			g.scribe_told = true
			say.append(SCRIBE_RU)
	if rov.x >= 260.0 and d >= 45.0:
		finish.call("slope", "Свал пройден: трос держит, течение не унесло.")
	if d < 45.0:
		g.crossed_from = "above"
	elif d > 55.0 and g.crossed_from == "above":
		finish.call("thermocline", "Слой пройден. Вода стала холодной, а звук медленнее: 1480 → 1435 м/с. Эхо приходит позже.")
	if d > 100.0 and not rov.lamp and still:
		g.progress.silence += dt
		if g.progress.silence >= 20.0:
			finish.call("silence", "Тишина глубины. Здесь слышно только своё дыхание.")
	else:
		g.progress.silence = 0.0
	return {"game": g, "say": say}


static func current(x: float, t: float) -> float:
	if x < 230.0 or x > 440.0:
		return 0.0
	var k := sin(PI * (x - 230.0) / 210.0)
	return 0.18 * k * sin(t / 45.0)
