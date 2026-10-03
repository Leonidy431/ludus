## The diver's wrist computer on the left glove: the lines beside the
## small volumetric screen (docs/missions/rov-pilot-akula/
## DESIGN_ROV_PILOT_PIKE.md, the operator's layout of 2026-10-03).
##
## Every number is computed, not typed: the thermocline from DiveCore,
## the bubble's resonance by Minnaert from VolumetricCore for the lake's
## ~6 PSU, the laser's best wavelength by Bouguer's law in 450-490 nm.
## The tasks come from the operator's course outline as woven into the
## pike mission (RovCourseCore).  The layout keeps the operator's frame
## but not what the game may not show: no brand or course name, no
## made-up OS version, no developer's file and commit on a player's
## screen, and no "waiting for the kayrak": the holy is never a target
## (TABOO 0.4, 0.022 item 4, 0.027).  At the kayrak the screen is empty.
##
## Constitution: FORM (an honest instrument on the hand, knowing only
## what it measures) -> ACTION (the diver reads the water and his tasks
## by turning his wrist) -> GOAL (the course is learnt by doing, and at
## the holy the instrument falls silent).
class_name GloveComputer
extends RefCounted

## The lake's salinity (PSU) the bubble model is set for.
const SALINITY_PSU := 6.0
## The transducer's frequency, kHz.
const BUBBLE_KHZ := 40.0
## The four tasks of the wrist, in the course's order of play.
const TASKS := [["thermocline_check", "Сонар: глубина термоклина"],
	["laser_scale", "Лазер: масштаб на дне"],
	["side_scan_reading", "Боковой обзор: прочесть картинку"],
	["robot_arm", "Манипулятор: мягкий захват"]]
## The widest line, in letters, so the text fits the cuff.
const WIDTH := 44


## The best wavelength in 450-490 nm by Bouguer's law over `metres` of
## clear water, in whole nanometres (5 nm steps).
static func best_wavelength(metres := 5.0) -> int:
	var best := 450
	var best_t := -1.0
	for nm in range(450, 491, 5):
		var t := VolumetricCore.laser_transmission(float(nm), metres, 0.0)
		if t > best_t:
			best_t = t
			best = nm
	return best


## The wrist's text at `depth_m` with the course tasks `done` (ids);
## empty at the holy.
static func text(depth_m: float, done: Array, holy := false) -> String:
	if holy:
		return ""
	var radius := roundi(VolumetricCore.resonant_radius_um(BUBBLE_KHZ, 0.0,
		SALINITY_PSU))
	var layer := DiveCore.THERMOCLINE_M
	var found := depth_m >= layer
	var lines := [
		"ПЕРЧАТКА · ВОДА %d PSU · %.0f м" % [int(SALINITY_PSU), depth_m],
		"ТЕРМОКЛИН %.0f м: %s" % [layer,
			"ПРОЙДЕН" if found else "ВПЕРЕДИ"],
		"ПУЗЫРЬ %d кГц: %d мкм" % [int(BUBBLE_KHZ), radius],
		"ЛАЗЕР %d нм: лучше всего в воде" % best_wavelength(),
		"ЗАДАЧИ:"]
	for task in TASKS:
		var mark := "[x]" if task[0] in done else "[ ]"
		lines.append("%s %s" % [mark, task[1]])
	lines.append("КЛАУД: на связи")
	return "\n".join(lines)


## The course tasks the pilot has done by its beat: the thermocline is
## measured once the vehicle is below it; the rest wait for the mission.
static func done_in_pilot(depth_m: float) -> Array:
	return ["thermocline_check"] if depth_m >= DiveCore.THERMOCLINE_M \
		else []
