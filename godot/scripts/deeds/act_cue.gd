## The felt answer to a step of a place's act (PlaceDeeds): touch, sound
## and light in the same frame (TABOO 0.35 item 17), so a right step
## feels different from a wrong one without reading the panel
## (docs/BLINDSPOTS_CODE_BREAKTHROUGH_2026-10-01.md, item 8).
##
## The kind of a step is read from the act's own states, so no group has
## to say it: a step that changed only the reply was a wrong one (the act
## stands where it stood and only answered, or noted that it was tried),
## a step that moved anything
## else was a right one, and the step that closed the act is "done".
##
## The sounds are the craft's own, made here sample by sample with no
## chance in them: a dry knock of wood for a right step, a low muffled
## knock for a wrong one, and for "done" a slow breath of air.  None is a
## bell or a chime: the bell rings only by the Typikon and is never a
## "ding" for a reward (TABOO 0.2 item 5, 0.4 item 4).  All stay well
## under the headset's peak of -1 dBTP (TABOO 0.4 item 13).
##
## Constitution: ФОРМА (the step the hands took) → ДЕЙСТВИЕ (the hands,
## the ear and the eye answer it at once) → ЦЕЛЬ (the order of the craft
## is learned by feel, not by a counter).
class_name ActCue
extends RefCounted

const RATE := 44100
## The controller pulse of each kind is Haptics.PULSES "act_<kind>":
## the wrong step softer and longer, a dull push; the right one short and
## clear; the closing one the fullest, still gentle.
## The place's lamp brightens only when the act closes, and for a short
## while: the work is lit, not rewarded with a flash.
const LIGHT_DONE := 1.25
const LIGHT_SECONDS := 1.5
## Keys of an act's state that note what was said, not how far the act
## has gone (the contract in place_deeds.gd reserves them).
const NOTES := ["reply", "tried"]
## Peak of every cue, dBFS.
const PEAK_DB := -18.0

static var _cache := {}


## "done", "right", "wrong" or "" (nothing happened) for the step that
## took the act's state from prev to next.
static func kind(prev: Dictionary, next: Dictionary) -> String:
	if next.get("done", false) and not prev.get("done", false):
		return "done"
	if next == prev:
		return ""
	var a := prev.duplicate()
	var b := next.duplicate()
	for key in NOTES:
		a.erase(key)
		b.erase(key)
	return "wrong" if a == b else "right"


## The cue's sound as 16-bit mono PCM, the same bytes every time.
static func wav(k: String) -> AudioStreamWAV:
	if _cache.has(k):
		return _cache[k]
	var s := samples(k)
	var gain := pow(10.0, PEAK_DB / 20.0)
	var peak := 0.0
	for x in s:
		peak = maxf(peak, absf(x))
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		var v := int(roundf(s[i] / maxf(peak, 1e-9) * gain * 32767.0))
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	_cache[k] = w
	return w


## The raw shape of a cue, before its level is set.
static func samples(k: String) -> PackedFloat32Array:
	match k:
		"right":
			return _knock(440.0, 0.07, 0.012)
		"wrong":
			return _knock(196.0, 0.11, 0.03)
		"done":
			return _breath(0.6)
	return PackedFloat32Array()


## A knock of wood: a short tone that dies fast, struck by a click of
## noise; "soft" is how long the click lasts (a longer one is duller).
static func _knock(f: float, seconds: float,
		soft: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var seed := 12345
	for i in n:
		var t := float(i) / RATE
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var noise := float(seed) / float(0x7fffffff) * 2.0 - 1.0
		var click := noise * exp(-t / soft)
		var tone := sin(TAU * f * t) * exp(-t / (seconds * 0.3))
		out[i] = 0.6 * tone + 0.4 * click
	return out


## A breath of air: noise smoothed into a low hush that swells and
## fades, with no pitch to read as a note.
static func _breath(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var seed := 777
	var low := 0.0
	for i in n:
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var noise := float(seed) / float(0x7fffffff) * 2.0 - 1.0
		low += 0.04 * (noise - low)
		out[i] = low * sin(PI * float(i) / n)
	return out
