## Waiting out the storm is seen and heard, and a tremor of the hand does
## not reset it (StormCalm; blind spot 9).  The logic first, then the
## storm bay in the real scene: the lantern steadies and the surf grows
## quieter over the wait, with no number; a real step brings the storm
## back; the wait no longer knocks a "right" cue every frame.  Called
## from run_hub_tests.gd.
extends RefCounted

const ACT := "wait-out-storm"
const DT := 1.0 / 72.0


func run(t: Object) -> void:
	_logic(t)
	_tremor(t)
	_scene(t)


func _logic(t: Object) -> void:
	t._check(StormCalm.has_wait(ACT), "the storm act has a waiting step")
	t._check(not StormCalm.has_wait("forge-nail")
		and StormCalm.calm("forge-nail", PlaceDeeds.start("forge-nail"))
		== -1.0, "an act with no wait shows no storm")
	var s := PlaceDeeds.start(ACT)
	t._check(StormCalm.calm(ACT, s) == 0.0, "before the wait: full storm")
	s = _to_wait(s)
	var wait := StormCalm.wait_seconds(ACT, s)
	t._check(wait > 0.0, "the waiting step has its seconds (%.0f)" % wait)
	var last := -1.0
	var rising := true
	while not s.get("done", false):
		var c := StormCalm.calm(ACT, s)
		rising = rising and c >= last
		last = c
		s = PlaceDeeds.tick(ACT, s, DT, true)
	t._check(rising, "the calm only grows while one stands")
	t._check(StormCalm.calm(ACT, s) == 1.0, "done: the storm has passed")
	# Light: steady when calm, swinging by at most FLICKER in the storm,
	# less as the calm grows; the same at the same time.
	var swing := func(c: float) -> float:
		var m := 0.0
		for i in 720:
			m = maxf(m, absf(StormCalm.lamp_factor(c, i * 0.05) - 1.0))
		return m
	t._check(swing.call(1.0) == 0.0, "calm: the lantern is steady")
	t._check(swing.call(0.0) <= StormCalm.FLICKER + 1e-6
		and swing.call(0.0) > 0.5 * StormCalm.FLICKER,
		"storm: the lantern swings, within its bound")
	t._check(swing.call(0.5) < swing.call(0.0)
		and swing.call(0.9) < swing.call(0.5), "the flicker settles")
	t._check(StormCalm.lamp_factor(0.2, 3.7)
		== StormCalm.lamp_factor(0.2, 3.7), "the light is deterministic")
	for g in StormCalm.GUSTS:
		t._check(g[0] < 3.0, "a gust under 3 Hz: no flashing (%.2f)" % g[0])
	# Sound: the surf and the rain grow quieter, never to silence.
	t._check(StormCalm.surf_db(0.0) == 0.0
		and StormCalm.surf_db(1.0) == StormCalm.SURF_CALM_DB
		and StormCalm.surf_db(0.5) < 0.0
		and StormCalm.SURF_CALM_DB > -20.0, "the surf settles, not muted")
	# The storm comes back at a pace, it does not jump.
	t._check(StormCalm.follow(0.2, 0.6, DT) == 0.6, "calm follows at once")
	var back := StormCalm.follow(0.8, 0.0, DT)
	t._check(back < 0.8 and back > 0.7, "the storm rises, not jumps")


## Hand tremor: readings that once reset the wait now close it; a real
## step still starts it again.
func _tremor(t: Object) -> void:
	var w := StormCalm.new_watch()
	var s := _to_wait(PlaceDeeds.start(ACT))
	var old := s.duplicate(true)
	var frames := int(20.0 / DT)
	for i in frames:
		# Drift of a resting thumb (0.18) and, twice a second, a twitch
		# over the dead zone for 0.2 s.
		var stick := 0.18 if i % 2 == 0 else 0.05
		if i % 36 < 14:
			stick = 0.4
		w = StormCalm.watch(w, stick, DT)
		s = PlaceDeeds.tick(ACT, s, DT, w.still)
		old = PlaceDeeds.tick(ACT, old, DT, stick < 0.1)
	t._check(s.get("done", false), "a tremor of the hand does not reset")
	t._check(not old.get("done", false),
		"(the old threshold of 0.1 never let the storm pass)")
	w = StormCalm.new_watch()
	s = _to_wait(PlaceDeeds.start(ACT))
	for i in int(6.0 / DT):
		w = StormCalm.watch(w, 0.0, DT)
		s = PlaceDeeds.tick(ACT, s, DT, w.still)
	var stood: float = s.waited
	for i in int(0.7 / DT):
		w = StormCalm.watch(w, 1.0, DT)
		s = PlaceDeeds.tick(ACT, s, DT, w.still)
	t._check(stood > 5.0 and float(s.waited) < 0.5,
		"a real step starts the wait again (%.1f s -> %.1f s)" % [stood,
			s.waited])


## The storm bay in the real scene, its frames driven as _process does.
func _scene(t: Object) -> void:
	var scene: Node = (load(LocationCore.SCENE) as PackedScene).instantiate()
	scene.location_id = "storm-bay"
	(t as SceneTree).root.add_child(scene)
	scene.proof = true  # Nothing is written by this test.
	t._check(scene.lamp != null, "the bay has its lantern")
	scene._apply(LocationHeart.open(scene.loc, scene.st, scene.ctx))
	var steps := StormCalm._steps(ACT)
	while StormCalm.wait_seconds(ACT, scene.heart_panel.deed) == 0.0 \
			and not scene.heart_panel.deed.get("done", false):
		var i := int(scene.heart_panel.deed.step)
		scene._apply(LocationHeart.choose(scene.heart_panel, scene.loc,
			scene.st, scene.ctx, _right(steps[i])))
	var cues_before: int = scene.cues.size()
	var dbs := []
	var swings := []
	var swing := 0.0
	var frames := 0
	while not scene.heart_panel.deed.get("done", false) and frames < 2000:
		scene.t += DT
		scene._light(DT)
		swing = maxf(swing, absf(scene.lamp.light_energy
			/ scene.lamp_energy - 1.0))
		scene.still_watch = StormCalm.watch(scene.still_watch, 0.12, DT)
		scene._apply(LocationHeart.tick(scene.heart_panel, scene.loc,
			scene.st, scene.ctx, DT, scene.still_watch.still), true)
		scene._storm(DT)
		frames += 1
		if frames == 360:
			# The body of the panel: the choices are numbered for the
			# keys 1-4, the words of the place are not.
			var text := "\n".join(LocationHeart.lines(scene.heart_panel,
				scene.loc, scene.st, scene.ctx))
			t._check(RegEx.create_from_string("\\d").search(text) == null,
				"no number on the panel while one waits")
		if frames % 144 == 0:
			dbs.append(scene.sound.craft_db)
			swings.append(swing)
			swing = 0.0
	t._check(scene.heart_panel.deed.get("done", false),
		"standing with a resting thumb waits the storm out (%d frames)"
		% frames)
	var quieter := dbs.size() >= 4
	for i in range(1, dbs.size()):
		quieter = quieter and dbs[i] < dbs[i - 1]
	t._check(quieter, "the surf grows quieter as one stands: %s" % [dbs])
	t._check(swings.size() >= 4 and swings[-1] < swings[0] * 0.5,
		"the lantern steadies: %s" % [swings])
	t._check(scene.cues.slice(cues_before) == ["done"],
		"the wait answers once, when it closes: %s"
		% [scene.cues.slice(cues_before)])
	t._check(scene.sound.craft_db == StormCalm.SURF_CALM_DB,
		"after the storm the bay stays calm")
	scene.free()


## Through the steps before the wait, each by its right option.
func _to_wait(s: Dictionary) -> Dictionary:
	var steps := StormCalm._steps(ACT)
	while StormCalm.wait_seconds(ACT, s) == 0.0 and not s.get("done", false):
		for o in steps[int(s.step)].o:
			if o[2]:
				s = PlaceDeeds.choose(ACT, s, o[0])
				break
	return s


## The index of the right option of a step among the panel's choices.
func _right(step: Dictionary) -> int:
	var opts: Array = step.o
	for i in opts.size():
		if opts[i][2]:
			return i
	return -1
