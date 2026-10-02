## The shared table of controller pulses (Haptics; DEF-008, blind spot
## 11): one table for the hub, the places and the dive, the numbers the
## scenes used before, every pulse gentle, no bell rope, reduced motion
## the same everywhere, and no scene sending a pulse of its own.  Called
## from run_hub_tests.gd.
extends RefCounted

## The pulses as the scenes sent them before the shared table:
## hub.gd _pulse(0.5, 0.05) and _pulse(0.2, 0.08), ActCue.HAPTIC and
## DiveAudio.PULSE_*.  Unchanged on purpose.
const BEFORE := {
	"knot": [0.5, 0.05], "breath": [0.2, 0.08],
	"act_right": [0.25, 0.04], "act_wrong": [0.12, 0.09],
	"act_done": [0.4, 0.14],
	"dive_lamp": [0.45, 0.05], "dive_take": [0.35, 0.08],
	"dive_echo": [0.12, 0.03], "dive_layer": [0.2, 0.06],
}
## Every scene that touches the hand, and the kinds it must use.
const USERS := {
	"res://scripts/hub.gd": ["\"knot\"", "\"breath\""],
	"res://scripts/location.gd": ["\"act_\""],
	"res://scripts/audio/dive_audio.gd": ["\"dive_lamp\"", "\"dive_take\"",
		"\"dive_echo\"", "\"dive_layer\""],
}


func run(t: Object) -> void:
	t._check(Haptics.PULSES.size() == BEFORE.size(),
		"the table has the %d pulses the scenes used" % BEFORE.size())
	for k in BEFORE:
		t._check(Haptics.PULSES.get(k) == BEFORE[k],
			"%s: the same amplitude and length as before" % k)
	for k in Haptics.PULSES:
		var s: Array = Haptics.PULSES[k]
		t._check(s[0] > 0.0 and s[0] <= Haptics.MAX_AMPLITUDE
			and s[1] > 0.0 and s[1] <= Haptics.MAX_SECONDS,
			"%s: a touch, not a rumble (%.2f, %.2f s)" % [k, s[0], s[1]])
		# The bell rings by the Typikon only; the player never rings it
		# (TABOO 0.2 item 5; the operator's answer of 2026-10-02).
		t._check(not k.contains("bell") and not k.contains("ring"),
			"%s: no pulse of a bell rope" % k)
	for k in ["right", "wrong", "done"]:
		t._check(not Haptics.spec("act_" + k).is_empty(),
			"every kind of ActCue has its pulse: " + k)
	# Reduced motion: what the player did not cause goes, the rest is
	# halved; without it the pulse is the table's.
	t._check(Haptics.spec("dive_echo", true).is_empty(),
		"reduced motion: no ambient echo pulse")
	t._check(Haptics.spec("knot", true) == [0.25, 0.05]
		and Haptics.spec("act_done", true) == [0.2, 0.14],
		"reduced motion: halved amplitude, same length")
	t._check(Haptics.spec("knot") == [0.5, 0.05], "full pulse otherwise")
	t._check(Haptics.spec("unknown").is_empty()
		and Haptics.pulse(null, "unknown").is_empty(),
		"an unknown kind is not felt")
	t._check(Haptics.pulse(null, "breath") == [0.2, 0.08],
		"without a headset nothing is sent, the pulse is still known")
	# The dive logs what it sent: from the table.
	var audio := DiveAudio.new()
	audio.on_lamp_toggled(true)
	audio.on_taken("keep")
	t._check(audio.pulses == [["dive_lamp", 0.45, 0.05],
		["dive_take", 0.35, 0.08]], "the dive's pulses come from the table")
	audio.free()
	# One place sends pulses: haptics.gd.  Every scene calls it.
	var senders := []
	_scan("res://scripts", senders)
	t._check(senders == ["res://scripts/haptics.gd"],
		"only Haptics calls trigger_haptic_pulse: %s" % [senders])
	for path in USERS:
		var src := FileAccess.get_file_as_string(path)
		t._check(src.contains("Haptics.pulse("),
			path.get_file() + " uses the shared table")
		for kind in USERS[path]:
			t._check(src.contains(kind), "%s sends %s" % [path.get_file(),
				kind])
	# Nothing is counted or saved for a pulse (TABOO 0.2 item 4).
	var own := FileAccess.get_file_as_string("res://scripts/haptics.gd")
	t._check(not own.contains("FileAccess.WRITE")
		and not own.contains("do_practice"),
		"a pulse is never counted or saved")


func _scan(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var path := dir.path_join(f)
			if FileAccess.get_file_as_string(path).contains(
					".trigger_haptic_pulse("):
				out.append(path)
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), out)
