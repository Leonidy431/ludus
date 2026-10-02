## The one table of controller pulses for the whole headset game: the
## hub's rope of the evening watch, the act at the heart of a place and
## the dive (CLAUDE.md TABOO 0.35 rule 17: touch is the third share of
## the response triad; docs/BLINDSPOTS_CODE_BREAKTHROUGH_2026-10-01.md,
## item 11; DEF-008).
##
## Before this file each scene called trigger_haptic_pulse with its own
## numbers, so the same kind of touch could drift apart from scene to
## scene and no test saw all of them.  The amplitudes and durations below
## are the ones the scenes used, unchanged:
##   breath      hub.gd _rope_tick: the hand is touched as the breath
##               turns outward while the rope is held;
##   knot        hub.gd _rule_select: a knot tied on the exhale;
##   act_*       location.gd _cue, formerly ActCue.HAPTIC;
##   dive_*      dive_audio.gd, formerly its PULSE_* constants.
##
## What is not here, on purpose: a bell rope.  The bell rings only by
## the Typikon and the player never rings it (TABOO 0.2 item 5); by the
## operator's answer of 2026-10-02 the player may stand near the
## bell-ringer, with no action, counter or record, and so with no pulse.
## A pulse accompanies a practice and never scores or strengthens it
## (TABOO 0.2 item 4): nothing here is counted or saved.
##
## Reduced motion (user://settings.json {"reduced_motion": true} or
## --reduced-motion): ambient pulses that the player did not cause are
## dropped and the others are halved, as the dive already did.  The hub
## and the places follow the same rule now (TABOO 0.35 rule 17: every
## effect has its reduced-motion form); without the setting their
## pulses are the same as before.
##
## Constitution: ФОРМА (the hand that holds the rope, the tool, the
## manipulator) → ДЕЙСТВИЕ (one gentle pulse answers what the hand did)
## → ЦЕЛЬ (the order of the practice is learned by feel, not by a
## counter).
class_name Haptics
extends RefCounted

## Amplitude 0..1 and seconds of every pulse.  Frequency 0 lets the
## runtime choose its default.
const PULSES := {
	"breath": [0.2, 0.08],
	"knot": [0.5, 0.05],
	"act_right": [0.25, 0.04],
	"act_wrong": [0.12, 0.09],
	"act_done": [0.4, 0.14],
	"dive_lamp": [0.45, 0.05],
	"dive_take": [0.35, 0.08],
	"dive_echo": [0.12, 0.03],
	"dive_layer": [0.2, 0.06],
}
## Pulses the player did not cause: under reduced motion they go.
const AMBIENT := ["dive_echo"]
## No pulse may be strong or long: a touch, not a rumble.
const MAX_AMPLITUDE := 0.5
const MAX_SECONDS := 0.15
const SETTINGS := "user://settings.json"

static var _reduced = null


## [amplitude, seconds] of a pulse as it is felt, or [] when it is not
## felt at all (an unknown kind, or an ambient one under reduced motion).
static func spec(kind: String, reduced := false) -> Array:
	if not PULSES.has(kind):
		return []
	if reduced and kind in AMBIENT:
		return []
	var s: Array = PULSES[kind]
	var amp: float = s[0] * (0.5 if reduced else 1.0)
	return [amp, float(s[1])]


## Send one pulse to hand (null when no headset is on: nothing is sent)
## and return what was felt, so callers and tests can log it.
static func pulse(hand: XRController3D, kind: String, reduced := false,
		delay := 0.0) -> Array:
	var s := spec(kind, reduced)
	if s.is_empty():
		return s
	if hand != null:
		hand.trigger_haptic_pulse("haptic", 0.0, s[0], s[1], delay)
	return s


## Whether the player asked for reduced motion; read once a run.
static func prefers_reduced() -> bool:
	if _reduced == null:
		_reduced = "--reduced-motion" in OS.get_cmdline_user_args()
		if not _reduced and FileAccess.file_exists(SETTINGS):
			var data = JSON.parse_string(
				FileAccess.get_file_as_string(SETTINGS))
			_reduced = data is Dictionary \
				and data.get("reduced_motion", false) == true
	return _reduced
