## The headset's session (XrSession, docs/HLD_CHORUS24_FIXES_2026-10-03.md
## phase F2): Home and a lost focus pause the tree and mute the Master
## bus; focus brings both back; Android's pause does the same; a
## recentre is asked for once; 72 Hz is picked when the runtime offers
## it.  Driven by events, without a headset.  Called from
## run_hub_tests.gd.
extends RefCounted

const XR := preload("res://scripts/xr_session.gd")


func _walk(events: Array) -> Dictionary:
	var s: Dictionary = XR.new_state()
	for e in events:
		s = XR.step(s, e)
	return s


func run(t: Object) -> void:
	# No session: the desktop, the web and this runner never pause.
	var s: Dictionary = XR.new_state()
	t._check(not s.paused and not s.muted, "no session, no pause")
	t._check(not XR.step(s, "recentered").paused,
		"a recentre without a session does not pause")

	# The normal start: begun, visible, focussed -> the world runs.
	t._check(_walk(["begun"]).paused, "begun but not focussed waits")
	t._check(_walk(["begun", "visible"]).paused, "visible waits")
	s = _walk(["begun", "visible", "focussed"])
	t._check(not s.paused and not s.muted, "focussed runs the world")

	# Home: the system menu takes focus -> paused and muted; back -> on.
	s = XR.step(s, "visible")
	t._check(s.paused and s.muted, "Home pauses and mutes")
	s = XR.step(s, "focussed")
	t._check(not s.paused and not s.muted, "focus back resumes")

	# The headset taken off: the session stops; only a new focussed
	# session brings the world back, not a resume of the app alone.
	s = XR.step(s, "stopping")
	t._check(s.paused and s.muted, "stopping pauses and mutes")
	t._check(XR.step(s, "app_resumed").paused,
		"a resumed app without focus stays paused")
	s = _walk(["begun", "visible", "focussed", "stopping", "begun",
		"visible", "focussed"])
	t._check(not s.paused, "a new focussed session resumes")

	# Android's own pause, with or without a session.
	s = XR.step(XR.new_state(), "app_paused")
	t._check(s.paused and s.muted, "the app in background pauses")
	t._check(not XR.step(s, "app_resumed").paused,
		"the app in front again resumes (no session)")
	s = _walk(["begun", "focussed", "app_paused"])
	t._check(s.paused, "background pauses a focussed session")
	t._check(not XR.step(s, "app_resumed").paused,
		"back in front with focus resumes")
	s = _walk(["begun", "focussed", "app_paused", "visible",
		"app_resumed"])
	t._check(s.paused, "back in front without focus stays paused")

	# The recentre is asked once, on its own step, and pauses nothing.
	s = _walk(["begun", "focussed"])
	var r: Dictionary = XR.step(s, "recentered")
	t._check(r.recenter and not r.paused, "a recentre is asked for")
	t._check(not XR.step(r, "focussed").recenter,
		"a recentre is not repeated")

	# The same events give the same state: the order is the only input.
	t._check(_walk(["begun", "visible", "focussed", "visible"])
		== _walk(["begun", "visible", "focussed", "visible"]),
		"the state machine is deterministic")

	# The rate: 72 Hz when offered, nothing otherwise.
	t._check(is_equal_approx(XR.pick_rate([90.0, 72.00001, 120.0]),
		72.00001), "72 Hz is picked from the runtime's list")
	t._check(XR.pick_rate([90.0, 120.0]) == 0.0, "no 72 Hz, no request")
	t._check(XR.pick_rate([]) == 0.0, "an empty list, no request")

	# The node applies the state to the engine and runs while paused.
	var tree: SceneTree = t
	var node: Node = XR.new()
	tree.root.add_child(node)
	t._check(node.process_mode == Node.PROCESS_MODE_ALWAYS,
		"the session node runs while the tree is paused")
	var master := AudioServer.get_bus_index("Master")
	var was_muted := AudioServer.is_bus_mute(master)
	node._on("begun")
	node._on("focussed")
	t._check(not tree.paused, "the tree runs while focussed")
	node._on("visible")
	t._check(tree.paused, "the tree pauses on Home")
	t._check(AudioServer.is_bus_mute(master), "Master is muted on Home")
	node._on("focussed")
	t._check(not tree.paused, "the tree runs again on focus")
	t._check(not AudioServer.is_bus_mute(master),
		"Master is unmuted on focus")
	tree.paused = false
	AudioServer.set_bus_mute(master, was_muted)
	node.queue_free()
	t._check(t.root.has_node("XrSession"), "XrSession is an autoload")
