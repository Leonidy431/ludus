## The pilot's console: what the cards say and when they warn.
##
## The look and the thresholds come from the operator's own BlueOS
## panels (third_party/mangustik/panels, docs/HLD_MANGUSTIK_COCKPIT):
##   - yacht-blueos vessel-dashboard: DEFAULT_THRESHOLDS
##     lowFuelLevel 15 %, cautionFuelLevel 25 % -> the battery card;
##   - diveguard globals.css: --threat-safe #10b981, --threat-warning
##     #f59e0b, --threat-critical #ef4444 -> the three states;
##   - yacht-blueos globals.css (.dark): card hsl(228 59% 13%), border
##     hsl(229 30% 20%), accent hsl(180 82% 45%), muted hsl(229 20% 60%).
## The ascent limit is the diver's rule already in the dive core
## (10 m/min, TABOO 0.35 rule 19).  The console counts no points: it
## shows the water and the bag, as the telemetry did before.
class_name CockpitCore
extends RefCounted

const CARD := Color(0.053, 0.084, 0.207, 0.88)
const BORDER := Color(0.140, 0.162, 0.260)
const ACCENT := Color(0.081, 0.819, 0.819)
const MUTED := Color(0.520, 0.549, 0.680)
const STATE_COLOUR := {
	# A plain reading is the instrument's cyan (TABOO 0.38 rule 1:
	# cyan belongs to instruments).
	"info": ACCENT,
	"safe": Color(0.063, 0.725, 0.506),  # #10b981
	"warn": Color(0.961, 0.620, 0.043),  # #f59e0b
	"critical": Color(0.937, 0.267, 0.267),  # #ef4444
}

const BATTERY_CRITICAL := 0.15
const BATTERY_CAUTION := 0.25
const ASCENT_LIMIT := 10.0
const ASCENT_CAUTION := 8.0
const CLEARANCE_CRITICAL := 0.8
const CLEARANCE_CAUTION := 2.0
## Near a holy thing the console goes out (TABOO 0.4 rule 2): full
## beyond FADE_FAR metres, almost nothing inside FADE_NEAR, over
## FADE_SECONDS in time.
const FADE_FAR := 6.0
const FADE_NEAR := 3.0
const FADE_MIN := 0.0
const FADE_SECONDS := 1.75

const POINTS := ["С", "СВ", "В", "ЮВ", "Ю", "ЮЗ", "З", "СЗ"]


static func battery_state(level: float) -> String:
	if level < BATTERY_CRITICAL:
		return "critical"
	if level < BATTERY_CAUTION:
		return "warn"
	return "safe"


static func ascent_state(m_per_min: float) -> String:
	if m_per_min > ASCENT_LIMIT:
		return "critical"
	if m_per_min > ASCENT_CAUTION:
		return "warn"
	return "safe"


static func clearance_state(clearance: float) -> String:
	if clearance < CLEARANCE_CRITICAL:
		return "critical"
	if clearance < CLEARANCE_CAUTION:
		return "warn"
	return "safe"


static func compass_point(heading: float) -> String:
	return POINTS[posmod(roundi(fposmod(heading, 360.0) / 45.0), 8)]


## The cards, left to right.  Each is {title, value, sub, state}.
static func cards(tel: Dictionary, bag: Dictionary) -> Array:
	var clearance: float = tel.floor - tel.depth
	var up: float = maxf(0.0, tel.ascent_m_per_min)
	return [
		{"title": "ГЛУБИНА", "value": "%.1f м" % tel.depth,
			"sub": "до дна %.1f м" % clearance,
			"state": clearance_state(clearance)},
		{"title": "ВОДА", "value": "%.1f °C" % tel.temperature,
			"sub": "%.2f бар" % tel.pressure_bar, "state": "info"},
		{"title": "КУРС", "value": "%03d°" % roundi(tel.heading),
			"sub": compass_point(tel.heading), "state": "info"},
		{"title": "СОНАР", "value": "%d м/с" % roundi(tel.sound_speed),
			"sub": "эхо %.3f с" % tel.echo_delay, "state": "info"},
		{"title": "ВСПЛЫТИЕ", "value": "%.1f" % up,
			"sub": "м/мин · предел 10", "state": ascent_state(up)},
		{"title": "ЗАРЯД", "value": "%d %%" % roundi(tel.battery * 100.0),
			"sub": "лампа" if tel.get("lamp", true) else "лампа выкл.",
			"state": battery_state(tel.battery)},
		{"title": "СУМКА", "value": "%d" % bag.kept.size(),
			"sub": "отпущ. %d · писцу %d" % [bag.released.size(),
				bag.handed_over.size()], "state": "info"},
	]


## How visible the console should be at this distance from the nearest
## holy thing.
static func fade_target(distance: float) -> float:
	if distance >= FADE_FAR:
		return 1.0
	if distance <= FADE_NEAR:
		return FADE_MIN
	return lerpf(FADE_MIN, 1.0, (distance - FADE_NEAR) / (FADE_FAR - FADE_NEAR))


## One frame towards the target, never faster than FADE_SECONDS for the
## whole way.
static func fade_step(alpha: float, target: float, dt: float) -> float:
	return move_toward(alpha, target, dt / FADE_SECONDS)


# --- Manipulator --------------------------------------------------------

## One reach of the manipulator lasts ARM_SECONDS: out, a short hold at
## the thing, back.  Time alone decides the pose (no randomness).
const ARM_SECONDS := 1.2


## How far out the arm is (0 stowed, 1 reached) `elapsed` seconds after
## the pilot pressed "take"; < 0 or past the end means stowed.
static func arm_phase(elapsed: float) -> float:
	if elapsed < 0.0 or elapsed >= ARM_SECONDS:
		return 0.0
	var u := elapsed / ARM_SECONDS
	if u < 0.4:
		return smoothstep(0.0, 0.4, u)
	if u < 0.6:
		return 1.0
	return 1.0 - smoothstep(0.6, 1.0, u)


# --- Sonar --------------------------------------------------------------

## A forward imaging sonar like the one on DiveGuard's console: a 90
## degree fan, SONAR_RANGE metres, beams tilted SONAR_TILT down so the
## floor ahead answers, as on a real ROV.
const SONAR_RANGE := 30.0
const SONAR_FAN := PI / 2.0
const SONAR_BEAMS := 31
const SONAR_TILT := 0.5235988  # 30 degrees, as ROV imaging sonars are set.
const SONAR_STEP := 0.5
## Vertical beam width: the floor answers as soon as the beam's lower
## edge touches it.  The operator's rov-platform/HLD.md puts a
## Ping360-class scanning sonar under the camera; its beam is about 25
## degrees tall.
const SONAR_VBEAM := 0.44


## Returns {floor: [range or -1 per beam], echoes: [{angle, range,
## strength}], layer: range or -1}.  layer is the thermocline: sound
## slows from 1480 to 1435 m/s across it (DiveCore.sound_speed), and the
## jump in the medium sends part of the ping back, so a sonar sees the
## layer as a faint arc where its beam's centre crosses 50 m.  rov: the dive core state (x, z, depth, yaw); things:
## anything with x, z, depth and an optional size.  Angle 0 is ahead,
## positive to starboard.
static func sonar_scan(rov: Dictionary, things: Array) -> Dictionary:
	var floor := []
	for b in SONAR_BEAMS:
		var a := -SONAR_FAN / 2.0 + SONAR_FAN * b / (SONAR_BEAMS - 1)
		var yaw: float = rov.yaw + a
		var hit := -1.0
		var d := SONAR_STEP
		while d <= SONAR_RANGE:
			var x: float = rov.x + cos(yaw) * d
			var z: float = rov.z + sin(yaw) * d
			if DiveCore.floor_depth(x, z) <= rov.depth \
					+ d * tan(SONAR_TILT + SONAR_VBEAM / 2.0):
				hit = d
				break
			d += SONAR_STEP
		floor.append(hit)
	var echoes := []
	for th in things:
		var dx: float = th.x - rov.x
		var dz: float = th.z - rov.z
		var r := sqrt(dx * dx + dz * dz)
		if r < 0.5 or r > SONAR_RANGE:
			continue
		var a := wrapf(atan2(dz, dx) - rov.yaw, -PI, PI)
		if absf(a) > SONAR_FAN / 2.0:
			continue
		# The beam is a wedge in depth too: centre tilted down, widening
		# with range.
		var centre: float = rov.depth + r * tan(SONAR_TILT)
		if absf(th.depth - centre) > 2.0 + 0.25 * r:
			continue
		var size := float(th.get("size", 0.5))
		echoes.append({"angle": a, "range": r,
			"strength": clampf(0.3 + size * 0.5, 0.3, 1.0)})
	return {"floor": floor, "echoes": echoes, "layer": thermocline_range(
		rov.depth)}


## Where the tilted beam's centre crosses the thermocline, or -1 when it
## never does within range (from below it, the beam points away).
static func thermocline_range(depth: float) -> float:
	if depth >= DiveCore.THERMOCLINE_M:
		return -1.0
	var r := (DiveCore.THERMOCLINE_M - depth) / tan(SONAR_TILT)
	return r if r <= SONAR_RANGE else -1.0


## The sweep line's angle at time t: across the fan and back every
## 2 * SONAR_SWEEP seconds.
const SONAR_SWEEP := 2.0


static func sonar_sweep(t: float) -> float:
	var u := fposmod(t, 2.0 * SONAR_SWEEP) / SONAR_SWEEP
	var k := u if u <= 1.0 else 2.0 - u
	return -SONAR_FAN / 2.0 + SONAR_FAN * k
