## The operator's own apparatus in the game (CLAUDE.md TABOO 0.022): 41
## ideas from his repos, each placed on the robot or at the surface, each
## in the beat of the pilot where it works, each with the video a screen
## shows.  The inventory and its evidence (file:line in the repos) are in
## docs/story/OPERATOR_APPARATUS_2026-10-02.md; the data is
## godot/data/apparatus.json.
##
## Here: which instrument a beat shows, what its screen draws (ScreenFeed
## from the scene's telemetry), and the rules the data keeps: a known
## beat, robot or surface, a known kind of video, no brand name in what
## the player reads, nothing on a screen at the holy.
class_name ApparatusCore
extends RefCounted

const DATA := "res://data/apparatus.json"
const HOLY_BEATS := ["khachkar"]
## Brand and product names stay in the development documents; the
## player reads common words (TABOO 0.03 item 7).
const BRANDS := ["blueos", "raspberry", "hailo", "cesium", "hackrf",
	"tfmini", "pelican", "arduino", "stm32", "esp32", "ardupilot",
	"qgroundcontrol", "nvidia", "jetson", "ping360", "bluerobotics"]
const READ_FIELDS := ["name_ru", "measures", "units", "law_ru"]


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


## The instruments of a beat in one place ("robot" or "surface"), in the
## order of the inventory.  Nothing at the holy.
static func for_beat(data: Dictionary, beat: String, where: String) \
		-> Array:
	var out := []
	if beat in HOLY_BEATS:
		return out
	for i in data.get("items", []):
		if str(i.beat) == beat and str(i.where) == where:
			out.append(i)
	return out


## The instrument whose screen a beat shows first: one with a picture
## (sonar, curve, spectrogram, range, camera, map) before one with only
## a status line.
static func screen_of(data: Dictionary, beat: String, where: String) \
		-> Dictionary:
	var items := for_beat(data, beat, where)
	for i in items:
		if str(i.video.kind) != "status":
			return i
	return items[0] if not items.is_empty() else {}


static func check(data: Dictionary, pilot: Dictionary) -> Array:
	var bad := []
	var beats := {}
	for b in pilot.get("beats", []):
		beats[b.id] = true
	var ids := {}
	for i in data.get("items", []):
		var id := str(i.get("id", ""))
		if ids.has(id):
			bad.append("%s twice" % id)
		ids[id] = true
		if not beats.has(str(i.get("beat", ""))):
			bad.append("%s: no beat %s" % [id, i.get("beat", "")])
		if str(i.get("beat", "")) in HOLY_BEATS:
			bad.append("%s: a screen at the holy" % id)
		if not str(i.get("where", "")) in ["robot", "surface"]:
			bad.append("%s: neither robot nor surface" % id)
		if not str(i.get("video", {}).get("kind", "")) in ScreenFeed.KINDS \
				and str(i.get("video", {}).get("kind", "")) != "map":
			bad.append("%s: unknown video" % id)
		if i.get("holy", false):
			bad.append("%s: an instrument is never holy" % id)
		var read := ""
		for k in READ_FIELDS:
			read += " " + str(i.get(k, ""))
		read += " " + str(i.get("video", {}).get("shows_ru", ""))
		read = read.to_lower()
		for b in BRANDS:
			if b in read:
				bad.append("%s: brand «%s» in what the player reads" % [id, b])
	if data.get("items", []).is_empty():
		bad.append("no apparatus")
	return bad
