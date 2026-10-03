## The pilot's rising wonder on stage: one accent light and one small
## swarm of glints in front of the player, driven by WowCore's curve
## (godot/data/pilot-wow.json; docs/HLD_WOW_ESCALATION_2026-10-03.md).
##
## Each beat's level picks an effect: its light breathes between two
## energies at its colour temperature, its glints are as many as the
## budget allows, and its hands get one pulse when the beat begins.  At
## the khachkar WowCore gives nothing, so the stage goes dark and quiet
## (TABOO 0.4 rule 2).  Reduced motion takes the reduced variant: no
## breathing, fewer glints, never a flash.  Nothing here moves the
## camera, and nothing is random: the glints' seed is the level.
##
## Constitution: FORM (the episode's curve of wonder, measured in light,
## glints and touch) -> ACTION (each beat is a little more than the one
## before, and the sacred is the one place it all stops) -> GOAL (the
## player is drawn on by wonder and learns that the greatest moment is
## the quiet one at the khachkar).
class_name WowStage
extends Node3D

var data: Dictionary = {}
var light: OmniLight3D
var glints: MultiMeshInstance3D
var current: Dictionary = {}
var started := -1.0
## The most glints any level asks (pilot-wow.json rules: <= 256).
const MAX_GLINTS := 256
var glint_colour := Color(1, 1, 1, 0.8)
var glint_seed := 1


func _init() -> void:
	name = "WowStage"
	data = WowCore.load_data()
	light = OmniLight3D.new()
	light.omni_range = 4.0
	light.light_energy = 0.0
	light.shadow_enabled = false
	add_child(light)
	# Glints are a MultiMesh, not GPU particles: the own engine cuts
	# the particle classes (scripts/godot/engine/profile.py), as the
	# dive's bubbles do.  Their paths are a hash of the seed, so every run
	# draws the same swarm (Constitution: nothing random).
	glints = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	quad.material = m
	mm.mesh = quad
	mm.instance_count = MAX_GLINTS
	mm.visible_instance_count = 0
	glints.multimesh = mm
	glints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glints)


## The effect for the moment t; returns the effect (empty at the
## khachkar or outside the curve).  A new beat starts its pulse.
func update(t: float, reduced: bool, hands: Array) -> Dictionary:
	var e := WowCore.effect_at(t, reduced, data)
	if e.is_empty():
		current = {}
		light.light_energy = 0.0
		glints.multimesh.visible_instance_count = 0
		return e
	if e.get("beat") != current.get("beat"):
		current = e
		started = t
		_start(e, reduced, hands)
	# The accent grows with the level itself (0.1 at level 1, 1.0 at
	# 10), so the curve is seen even where a level's own effect is fog
	# or water that this stage does not draw.  A level that breathes
	# (pilot-wow.json "breathe_hz", "energy": [low, high]) breathes
	# between those shares of it; reduced motion has no breathing.
	var v: Dictionary = e.get("visual", {})
	var base := 0.1 * float(e.get("level", 0))
	var en = v.get("energy")
	var hz := float(v.get("breathe_hz", 0.0))
	var f := 1.0
	if en is Array and en.size() == 2 and hz > 0.0:
		var k := 0.5 + 0.5 * sin((t - started) * TAU * hz)
		var top := maxf(float(en[1]), 0.001)
		f = lerpf(float(en[0]), float(en[1]), k) / top
	light.light_energy = base * f
	_move_glints(t - started)
	return e


## Each glint drifts up through a 1.6 m sphere and wraps, its start and
## speed taken from a hash of its index and the level's seed.
func _move_glints(age: float) -> void:
	var mm := glints.multimesh
	for i in mm.visible_instance_count:
		var h := hash(i * 7919 + glint_seed * 104729)
		var x := float(h % 1000) / 1000.0 - 0.5
		var z := float((h / 1000) % 1000) / 1000.0 - 0.5
		var y0 := float((h / 1000000) % 1000) / 1000.0
		var speed := 0.02 + 0.04 * float((h / 7) % 100) / 100.0
		var y := fposmod(y0 + age * speed, 1.0) - 0.5
		mm.set_instance_transform(i, Transform3D(Basis(),
			Vector3(x * 1.6, y * 1.6, z * 1.6)))
		mm.set_instance_color(i, glint_colour)


func _start(e: Dictionary, reduced: bool, hands: Array) -> void:
	var v: Dictionary = e.get("visual", {})
	# A level may cross two temperatures ([from, to]); the stage takes
	# the last one, the colour the beat ends in.
	var kv = v.get("kelvin", 2500)
	var kelvin := int(kv[-1]) if kv is Array and not kv.is_empty() \
		else int(kv)
	light.light_color = LocationCore.kelvin(kelvin)
	var n := clampi(int(v.get("particles", 0)), 0, MAX_GLINTS)
	glints.multimesh.visible_instance_count = n
	glint_seed = int(e.get("level", 1))
	glint_colour = Color(LocationCore.kelvin(kelvin), 0.8)
	var h: Dictionary = e.get("haptic", {})
	var kind := str(h.get("kind", ""))
	if kind != "":
		for hand in hands:
			Haptics.pulse(hand, kind, reduced)
