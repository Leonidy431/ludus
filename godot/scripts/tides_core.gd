## The water's daily rhythm around Issyk-Kul and the north Caspian, read
## from the operator's BlueOS tides module (github.com/Leonidy431/tides,
## TABOO 0.029).  The module bakes the same series it serves at
## /v1.0/level into data/tides-ep1.json, so the headset needs no network.
##
## Honest physics, as the module states it: the lake's astronomical tide
## is millimetres, the rivers have no tide at all (their "tide" is the
## daily glacier melt, in cubic metres a second), and the Caspian's metres
## come from wind surge.  The game shows what the series says, never more.
##
## Constitution: FORM (a real instrument's series of the water) -> ACTION
## (the hero reads the rise and fall at the hour of his dive) -> GOAL
## (I.6: truth has layers, and the machine shows only what it measures).
class_name TidesCore
extends RefCounted

const PATH := "res://data/tides-ep1.json"


## The baked data, or an empty Dictionary if the file is missing.
static func load_data(path := PATH) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


## The series point of `site` nearest to `hour` (hours from the start).
static func at(data: Dictionary, site: String, hour: float) -> Dictionary:
	var s: Dictionary = data.get("sites", {}).get(site, {})
	var series: Array = s.get("series", [])
	if series.is_empty():
		return {}
	var step := float(data.get("step_min", 60)) / 60.0
	var i := clampi(roundi(hour / step), 0, series.size() - 1)
	return series[i]


## The largest absolute value of `component` over a site's series.
static func peak(data: Dictionary, site: String, component: String) -> float:
	var best := 0.0
	for p in data.get("sites", {}).get(site, {}).get("series", []):
		best = maxf(best, absf(float(p.get(component, 0.0))))
	return best
