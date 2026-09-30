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
