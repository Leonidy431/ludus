## The headset's session and the game's clock (docs/HLD_CHORUS24_FIXES_
## 2026-10-03.md, phase F2).  Autoload "XrSession".
##
## When the player presses Home, takes the headset off or the system
## shows its own menu, the OpenXR session loses focus.  The world must
## not go on without him: a dive that keeps sinking, a beat that passes
## unseen, a voice that talks into an empty room.  So the tree pauses
## and the Master bus is muted until focus comes back.  Android's own
## pause (the app sent to the background) does the same.
##
## The rule lives in one pure function, step(), so a test can drive it
## without a headset: the node only turns signals into events and
## applies what step() returns.
##
## The node itself runs while the tree is paused (PROCESS_MODE_ALWAYS),
## or it would never hear that focus came back.
##
## Constitution: ФОРМА (the body in the headset and its attention) →
## ДЕЙСТВИЕ (the world stops when he looks away and waits for him) →
## ЦЕЛЬ (nothing that teaches passes unseen; contemplation is not
## broken by a world that ran on without him — IX.5, VII.5).
extends Node

## The rate the scenes are budgeted for (docs/APK_REQUIREMENTS.md).
## Quest 3 offers 72, 90 and 120 Hz; the runtime's default may differ
## between system versions, so the game asks for it explicitly.
const REFRESH_HZ := 72.0

## The events step() knows, named after the signals that bring them.
const EVENTS := ["begun", "visible", "focussed", "stopping",
	"app_paused", "app_resumed", "recentered"]

## The current state; see new_state() for its fields.
var state := new_state()
var _xr: XRInterface = null


## The state before any signal: no XR session, the app in front.
## "xr" is true while an OpenXR session runs; "focus" while it has the
## input focus; "app" while Android keeps the app in the foreground;
## "held" after the session stops, until a new session is focussed.
static func new_state() -> Dictionary:
	return {"xr": false, "focus": false, "app": true, "held": false,
		"paused": false, "muted": false, "recenter": false}


## The state machine, pure: the old state and one event give the new
## state.  Paused and muted are always derived from the three facts,
## never toggled, so no order of signals can leave the game stuck.
## "recenter" is true only on the step that asks for it.
static func step(old: Dictionary, event: String) -> Dictionary:
	var s := old.duplicate()
	s.recenter = false
	match event:
		"begun":
			# Begun is not yet focussed: the runtime says so next.
			s.xr = true
			s.focus = false
		"visible":
			# Visible but not focussed: the system menu is over the game.
			s.xr = true
			s.focus = false
		"focussed":
			s.xr = true
			s.focus = true
			s.held = false
		"stopping":
			# The runtime is taking the headset away: the world waits
			# until a new session is focussed, not merely resumed.
			s.xr = false
			s.focus = false
			s.held = true
		"app_paused":
			s.app = false
		"app_resumed":
			s.app = true
		"recentered":
			s.recenter = true
		_:
			push_warning("XrSession: unknown event " + event)
	# Without a session (desktop, web, the test runner) only Android's
	# pause stops the world.  With a session, a lost focus stops it too.
	s.paused = not s.app or (s.xr and not s.focus) or s.held
	s.muted = s.paused
	return s


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var xr := XRServer.find_interface("OpenXR")
	if xr == null:
		return
	_xr = xr
	xr.session_begun.connect(_on.bind("begun"))
	xr.session_visible.connect(_on.bind("visible"))
	xr.session_focussed.connect(_on.bind("focussed"))
	xr.session_stopping.connect(_on.bind("stopping"))
	xr.pose_recentered.connect(_on.bind("recentered"))
	# The session may have begun before this autoload was ready.
	if xr.is_initialized():
		_set_refresh_rate()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_on("app_paused")
		NOTIFICATION_APPLICATION_RESUMED:
			_on("app_resumed")


## Turns one event into the new state and applies it to the engine.
func _on(event: String) -> void:
	var was := state
	state = step(state, event)
	if state.paused != was.paused:
		get_tree().paused = state.paused
	if state.muted != was.muted:
		var master := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(master, state.muted)
	if state.recenter:
		# The player asked the system to recentre: the game's origin
		# follows his head, but the horizon stays where gravity is.
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
	if event == "begun":
		_set_refresh_rate()


## Asks the runtime for 72 Hz when it offers that rate.  Not every
## runtime lists its rates; then the default stays and nothing breaks.
func _set_refresh_rate() -> void:
	if _xr == null or not _xr.has_method(
			"get_available_display_refresh_rates"):
		return
	var rates: Array = _xr.get_available_display_refresh_rates()
	if pick_rate(rates) > 0.0:
		_xr.display_refresh_rate = pick_rate(rates)


## The rate to ask for: 72 Hz if offered (within a rounding error, as
## runtimes report 72.0 or 72.00001), otherwise none (0.0).
static func pick_rate(rates: Array) -> float:
	for r in rates:
		if absf(float(r) - REFRESH_HZ) < 0.5:
			return float(r)
	return 0.0
