## The operator's own hydrophone, "model 1" of the posoh repo, mounted
## on the Mangustik: what it can hear at the ROV's depth
## (docs/HLD_POSOH_HYDROPHONE_2026-09-30.md).
##
## Two kinds of numbers live here, kept apart on purpose:
##   - REAL: taken from third_party/posoh (Leonidy431/posoh @ 55f44d0):
##     the firmware's sample rate, the preamp's component values, the
##     drawing's dimensions.  The filter corners are computed from the
##     components, not typed.
##   - ASSUMED: the posoh hydrophone has no calibrated sensitivity (its
##     own HYDROPHONE_V1.md says so), so it cannot say how loud the lake
##     is.  The noise levels below are textbook orders of magnitude,
##     marked ASSUMED, and the console never shows them as a measured
##     dB re 1 uPa; it shows differences (thrusters over the lake) and
##     a hearing range, which the assumptions change far less.
##
## Pure logic, no randomness: the same stick and depth give the same
## reading, and a test can check every number.
class_name PosohCore
extends RefCounted

# --- REAL: hardware/firmware/hydrophone_v1/hydrophone_v1.ino -----------
const SAMPLE_RATE_HZ := 40000.0
const ADC_BITS := 12
## The firmware prints a LEVEL line every REPORT_INTERVAL_MS = 500; the
## console card refreshes at the same cadence, as the serial log would.
const REPORT_S := 0.5

# --- REAL: hardware/HYDROPHONE_V1.md section 2 (preamp) ---------------
const AA_R_OHM := 10000.0  # R6, anti-alias low-pass.
const AA_C_F := 330e-12  # C2.
const COUPLE_C_F := 1e-6  # C1, AC coupling into the preamp.
## C1 sees the bias divider R4 = R5 = 100 kOhm from Vcc/2, i.e. the two
## in parallel: 50 kOhm.
const BIAS_R_OHM := 100000.0 / 2.0
## Dolphin whistles 4-20 kHz, clicks up to ~150 kHz: the band the
## author scoped model 1 against (the lake has no dolphins; the numbers
## stay as the instrument's own design band).
const WHISTLE_LOW_HZ := 4000.0
const CLICK_HIGH_HZ := 150000.0

# --- REAL: hardware/cad/hydrophone_v1.scad ------------------------------
## piezo_diameter = 20 mm is [UNVERIFIED] in the drawing itself (the
## toothbrush disc was never measured); the tube sizes follow from it
## and from the ESP32 devkit.  godot/models/posoh/hydrophone.json holds
## the same numbers as echoed by OpenSCAD; test_posoh.gd compares them.
const PIEZO_D_M := 0.020
const TUBE_OD_M := 0.0564
const TUBE_LEN_M := 0.1035

# --- Mount on the Mangustik (body coordinates, metres, -Z bow) ----------
## The hydrophone continues the Mangustik's top auxiliary tube
## (04_auxiliary_sensor_tubes_top, "hydrophone & telemetry housing",
## placed at x = -200..200 mm, z = 440 mm in 00_full_assembly.scad):
## its end cap sits on the tube's bow end, the potted piezo looks
## forward into the water the ROV moves into, and the cable to the
## tube's own front end is the shortest.
const MOUNT := Vector3(0.0, 0.44, -0.2)
const SENSOR := Vector3(0.0, 0.44, -0.2 - TUBE_LEN_M)
## Thruster module origins from 00_full_assembly.scad (05 horizontal at
## x = -500, y = +-300; 06 vertical at x = 400 and -350, z = 140),
## turned into body coordinates as mangustik_rov.py does: (-y, z, -x).
const THRUSTERS := [Vector3(0.3, 0.0, 0.5), Vector3(-0.3, 0.0, 0.5),
	Vector3(0.0, 0.14, -0.4), Vector3(0.0, 0.14, 0.35)]

# --- ASSUMED (not in posoh; see the HLD, open question 1) ---------------
## One small electric ROV thruster at full thrust, broadband source
## level, dB re 1 uPa at 1 m: an order of magnitude for this class of
## vehicle, not a measurement of the Mangustik.
const THRUSTER_SL_DB := 130.0
## Propeller noise grows with speed at roughly 50-60 dB per decade
## (Ross, Mechanics of Underwater Noise); 50 is the gentler end.
const THRUST_LAW_DB := 50.0
## The calm lake over the band, dB re 1 uPa.  Surface-made noise is
## nearly the same at every depth when absorption is small, so it does
## not change with depth here.
const AMBIENT_DB := 85.0
## A source is heard when it stands above the noise (0 dB SNR); the
## reference source is another vehicle like this one at full thrust.
const DETECT_DB := 0.0
const REFERENCE_SL_DB := THRUSTER_SL_DB
const RANGE_MAX_M := 1000.0
## Thrusters count as stopped below this command: the sticks' dead
## zone, so a resting thumb does not deafen the hydrophone.
const THRUST_OFF := 0.02


## Nyquist of the firmware's sampling: the top of what it can record.
static func nyquist_hz() -> float:
	return SAMPLE_RATE_HZ / 2.0


## The anti-alias RC's corner, 1 / (2 pi R C): about 48 kHz, above
## Nyquist, so it only softens what folds back (the author's note).
static func aa_corner_hz() -> float:
	return 1.0 / (TAU * AA_R_OHM * AA_C_F)


## The AC coupling's corner: C1 into the 50 kOhm bias.  About 3 Hz, so
## the low rumble of the lake and the thrusters' hum pass.
static func coupling_corner_hz() -> float:
	return 1.0 / (TAU * BIAS_R_OHM * COUPLE_C_F)


## What the recording spans: from the coupling corner to Nyquist.
static func band() -> Dictionary:
	return {"low_hz": coupling_corner_hz(), "high_hz": nyquist_hz(),
		"whistle_hz": [WHISTLE_LOW_HZ, nyquist_hz()],
		"clicks_heard": CLICK_HIGH_HZ <= nyquist_hz()}


## Wavelength in the water at this depth: the sound speed steps from
## 1480 to 1435 m/s across the 50 m thermocline (DiveCore).
static func wavelength_m(freq_hz: float, depth: float) -> float:
	return DiveCore.sound_speed(depth) / freq_hz


## ka of the piezo disc (k = 2 pi / lambda, a its radius).  Below 1 the
## disc is small against the wave and hears from every side.
static func ka(freq_hz: float, depth: float) -> float:
	return PI * PIEZO_D_M / wavelength_m(freq_hz, depth)


static func omnidirectional(depth: float) -> bool:
	return ka(nyquist_hz(), depth) < 1.0


## How much of a sound the thermocline sends back at normal incidence,
## dB: the impedance step of 1480 against 1435 m/s (the density step of
## ~0.1 % is left out).  About -36 dB: the layer is a faint mirror, as
## the sonar's arc shows, and nearly all the sound goes through.
static func layer_reflection_db() -> float:
	var r := (DiveCore.C_BELOW - DiveCore.C_ABOVE) \
		/ (DiveCore.C_BELOW + DiveCore.C_ABOVE)
	return 20.0 * log(absf(r)) / log(10.0)


static func _db_sum(levels: Array) -> float:
	var p := 0.0
	for l in levels:
		p += pow(10.0, float(l) / 10.0)
	return -INF if p <= 0.0 else 10.0 * log(p) / log(10.0)


static func _log10(x: float) -> float:
	return log(x) / log(10.0)


## Distance from the piezo to the nearest thruster module.
static func nearest_thruster_m() -> float:
	var d := INF
	for p in THRUSTERS:
		d = minf(d, SENSOR.distance_to(p))
	return d


## The Mangustik's own thrusters at the piezo, dB (ASSUMED levels):
## every module at the same command, spread spherically to the sensor.
## -INF when they are stopped: no self-noise at all.
static func self_noise_db(thrust: float) -> float:
	var t := clampf(absf(thrust), 0.0, 1.0)
	if t < THRUST_OFF:
		return -INF
	var sl := THRUSTER_SL_DB + THRUST_LAW_DB * _log10(t)
	var levels := []
	for p in THRUSTERS:
		levels.append(sl - 20.0 * _log10(SENSOR.distance_to(p)))
	return _db_sum(levels)


static func noise_db(thrust: float) -> float:
	return _db_sum([AMBIENT_DB, self_noise_db(thrust)])


## How far a source of level sl_db is heard: spherical spreading down
## to the noise (absorption in the band is well under 1 dB/km in fresh
## and brackish water, so it is left out), capped at RANGE_MAX_M.
static func hearing_range_m(sl_db: float, thrust: float) -> float:
	var r := pow(10.0, (sl_db - noise_db(thrust) - DETECT_DB) / 20.0)
	return minf(r, RANGE_MAX_M)


## The reading for the console.  thrust is the largest stick command
## (0..1).  Returns {self_db, ambient_db, over_db, masked, range_m,
## sound_speed, wavelength_cm, omni}.  over_db is the thrusters above
## the lake (0 when stopped); masked when they drown the lake.
static func reading(depth: float, thrust: float) -> Dictionary:
	var own := self_noise_db(thrust)
	var over := 0.0 if own == -INF else maxf(0.0, own - AMBIENT_DB)
	return {
		"self_db": own, "ambient_db": AMBIENT_DB, "over_db": over,
		"masked": own > AMBIENT_DB,
		"range_m": hearing_range_m(REFERENCE_SL_DB, thrust),
		"sound_speed": DiveCore.sound_speed(depth),
		"wavelength_cm": 100.0 * wavelength_m(nyquist_hz(), depth),
		"omni": omnidirectional(depth),
	}


## The card: title, value, sub, state as CockpitCore.cards() makes
## them.  The instrument's plain reading is cyan ("info"); when the
## ROV's own thrusters drown the lake the card warns, and the words say
## what to do: stop and listen.  No points, no reward.
static func card(depth: float, thrust: float) -> Dictionary:
	var r := reading(depth, thrust)
	var far := "до %d м" % roundi(r.range_m) if r.range_m >= 10.0 \
		else "до %.1f м" % r.range_m
	return {
		"title": "ГИДРОФОН",
		"value": "винты +%d дБ" % roundi(r.over_db) if r.masked
			else "слышно озеро",
		"sub": "такой же ROV %s" % far,
		"state": "warn" if r.masked else "info",
	}
