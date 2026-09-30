## The Church day, the tone of the week and when the shore bell may ring.
##
## A port of public/ludus/ludus-liturgical-clock.js (liturgical date,
## Paschalion, periods, allowed bell orders) and public/ludus/
## ludus-glas.js (tone of the week).  tests/test_audio.gd checks it on
## the dates of tests/ludus-glas.test.js, and tests/ludus-audio-parity.
## test.js checks that the same table agrees with the JS modules.
##
## Every function takes a local date as a dictionary {year, month, day,
## hour, minute, second} (Time.get_datetime_dict_from_system() gives
## one), so tests never depend on the machine clock or its time zone.
## Astronomy is used only for the Paschalion (CLAUDE.md TABOO 0.35
## rule 23).
class_name LudusTypikon
extends RefCounted

const DAY := 86400
## The liturgical day begins at Vespers; ludus-liturgical-clock.js
## fixes Vespers at 18:00 local time.
const VESPERS_HOUR := 18

## Octoechos: base note of each tone (ludus-glas.js).
const GLASY := {
	1: {"ru": "Глас 1", "base": "Pa"}, 2: {"ru": "Глас 2", "base": "Di"},
	3: {"ru": "Глас 3", "base": "Ga"}, 4: {"ru": "Глас 4", "base": "Pa"},
	5: {"ru": "Глас 5", "base": "Pa"}, 6: {"ru": "Глас 6", "base": "Pa"},
	7: {"ru": "Глас 7", "base": "Zo"}, 8: {"ru": "Глас 8", "base": "Ni"},
}
## Tonic of each tone in Hz, Ni = C3 (GLAS_TONIC, ludus-sacred-synth.js).
const GLAS_TONIC := {1: 146.83, 2: 196.0, 3: 174.61, 4: 146.83,
	5: 146.83, 6: 146.83, 7: 116.54, 8: 130.81}
## Bright Week: day after Pascha -> tone; the grave tone 7 is not sung.
const BRIGHT := [1, 2, 3, 4, 5, 6, 8]

## Fixed great feasts on the civil calendar (Julian date + 13 days).
const FIXED_FEASTS := {
	"01-07": "Nativity of Christ", "01-19": "Theophany",
	"02-15": "Meeting of the Lord", "04-07": "Annunciation",
	"08-19": "Transfiguration", "08-28": "Dormition",
	"09-21": "Nativity of the Theotokos",
	"09-27": "Exaltation of the Cross",
	"12-04": "Entry of the Theotokos",
}

## The call to Vespers heard from the shore.  kolokol ch. 25: the
## благовест, measured single strokes on the largest bell, announces
## the beginning of a service.  How long before Vespers it begins is
## not in the sources; ten minutes is a design choice, and so is the
## five-second stroke (docs/SOUND_THEOLOGY_RULES.md: "4 to 6 s ... a
## design choice, not a sourced fact").
const CALL_MINUTES := 10
const STROKE_EVERY := 5.0
## kolokol ch. 25: on the weekdays of Great Lent twelve strokes are
## struck before Vespers, the stepped Lenten call.
const LENTEN_VESPERS_STROKES := 12


## Midnight UTC of a civil date, as seconds; only used as a day index.
static func _day(y: int, m: int, d: int) -> int:
	return Time.get_unix_time_from_datetime_dict({"year": y, "month": m,
		"day": d, "hour": 0, "minute": 0, "second": 0})


## Pascha by the Julian computus (Meeus), shifted to the civil calendar:
## +13 days, valid for 1900-2099.  Returns the day index in seconds.
static func pascha_civil(year: int) -> int:
	var a := year % 4
	var b := year % 7
	var c := year % 19
	var d := (19 * c + 15) % 30
	var e := (2 * a + 4 * b - d + 34) % 7
	var month := (d + e + 114) / 31
	var day := ((d + e + 114) % 31) + 1
	return _day(year, month, day) + 13 * DAY


## The liturgical date of a local moment: after Vespers the next day.
static func liturgical_date(now: Dictionary) -> int:
	var t := _day(now.year, now.month, now.day)
	if int(now.get("hour", 0)) >= VESPERS_HOUR:
		t += DAY
	return t


static func describe(now: Dictionary) -> Dictionary:
	var t := liturgical_date(now)
	var civil := Time.get_datetime_dict_from_unix_time(t)
	var pascha := pascha_civil(civil.year)
	var offset := roundi(float(t - pascha) / DAY)
	var md := "%02d-%02d" % [civil.month, civil.day]
	var weekday: int = civil.weekday
	var period := "ordinary"
	var feast = FIXED_FEASTS.get(md, null)
	if offset == -2:
		period = "great-friday"
	elif offset == -1:
		period = "great-saturday"
	elif offset >= -6 and offset <= -3:
		period = "holy-week"
	elif offset == -7:
		feast = "Entry into Jerusalem"
	elif offset == 0:
		period = "pascha"
		feast = "Pascha"
	elif offset >= 1 and offset <= 6:
		period = "bright-week"
	elif offset >= -48 and offset <= -8:
		period = "great-lent"
	elif offset == 39:
		feast = "Ascension"
	elif offset == 49:
		feast = "Pentecost"
	var great: bool = feast != null or weekday == 0
	var rank := "pascha" if period == "pascha" else (
		"great" if great else "daily")
	return {"date": Time.get_date_string_from_unix_time(t),
		"weekday": weekday, "offset": offset, "period": period,
		"feast": feast, "rank": rank}


## Bell orders the Typikon allows on this day (ludus-liturgical-clock.js
## allowedOrders).
static func allowed_orders(info: Dictionary) -> Array:
	match info.period:
		"great-friday", "great-saturday":
			return ["благовест", "перебор"]
		"holy-week":
			return ["благовест"]
		"great-lent":
			if info.rank == "great":
				return ["благовест", "трезвон", "двои"]
			return ["благовест", "двои"]
		"pascha", "bright-week":
			return ["благовест", "трезвон", "перезвон"]
	return ["благовест", "трезвон", "перезвон", "перебор", "двои"]


static func may_ring(order: String, now: Dictionary) -> bool:
	return order in allowed_orders(describe(now))


## The tone of the liturgical day, or 0 in Holy Week (no tone of its
## own).  ludus-glas.js glasOf returns null there.
static func glas_of(now: Dictionary) -> int:
	var day := liturgical_date(now)
	var year: int = Time.get_datetime_dict_from_unix_time(day).year
	var pascha := pascha_civil(year)
	var offset := roundi(float(day - pascha) / DAY)
	if offset >= -6 and offset <= -1:
		return 0
	if offset >= 0 and offset <= 6:
		return BRIGHT[offset]
	# Thomas Sunday of this year, or of the last one before Pascha.
	var thomas := pascha + 7 * DAY
	if day < thomas:
		thomas = pascha_civil(year - 1) + 7 * DAY
	var weeks := floori(roundi(float(day - thomas) / DAY) / 7.0)
	return (weeks % 8) + 1


## Tonic of the week's tone in Hz, or 0.0 when there is no tone.
static func tonic_of(now: Dictionary) -> float:
	var g := glas_of(now)
	return GLAS_TONIC.get(g, 0.0)


## The shore bell at a local moment: {ring, stroke_times, reason}.
## stroke_times are seconds from the start of the call, and "since" is
## how long the call has been going.  The bell is the call to Vespers
## and nothing else: no task, find or button reaches this function.
static func bell_call(now: Dictionary) -> Dictionary:
	var minute_of_day: int = int(now.get("hour", 0)) * 60 \
		+ int(now.get("minute", 0))
	var start := VESPERS_HOUR * 60 - CALL_MINUTES
	var since := float(minute_of_day - start) * 60.0 \
		+ float(now.get("second", 0))
	var off := {"ring": false, "stroke_times": [], "since": since,
		"reason": ""}
	if minute_of_day < start or minute_of_day >= VESPERS_HOUR * 60:
		off.reason = "not the hour of the call to Vespers"
		return off
	# Before 18:00 the moment still belongs to the civil day, and the
	# Vespers being called opens the next liturgical day.  The order
	# is asked of the day whose Vespers it is.
	var vespers := now.duplicate()
	vespers.hour = VESPERS_HOUR
	vespers.minute = 0
	if not may_ring("благовест", vespers):
		off.reason = "the Typikon does not allow благовест"
		return off
	var info := describe(now)
	var times := []
	# A Lenten weekday is Monday to Friday of a day that is not a feast.
	var weekday: int = info.weekday
	if info.period == "great-lent" and info.rank == "daily" \
			and weekday >= 1 and weekday <= 5:
		for k in LENTEN_VESPERS_STROKES:
			times.append(k * STROKE_EVERY)
	else:
		var n := int(CALL_MINUTES * 60 / STROKE_EVERY)
		for k in n:
			times.append(k * STROKE_EVERY)
	return {"ring": true, "stroke_times": times, "since": since,
		"reason": "благовест to Vespers (%s)" % info.period}
