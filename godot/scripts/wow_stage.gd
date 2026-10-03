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
var glints: GPUParticles3D
var current: Dictionary = {}
var started := -1.0


func _init() -> void:
	name = "WowStage"
	data = WowCore.load_data()
	light = OmniLight3D.new()
	light.omni_range = 4.0
	light.light_energy = 0.0
	light.shadow_enabled = false
	add_child(light)
	glints = GPUParticles3D.new()
	glints.emitting = false
	glints.amount = 8
	glints.lifetime = 2.5
	glints.randomness = 0.0
	# Same glints every run: a fixed seed, set per level (Constitution).
	glints.use_fixed_seed = true
	glints.fixed_fps = 30
	glints.visibility_aabb = AABB(Vector3(-1.5, -1.5, -1.5),
		Vector3(3, 3, 3))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.8
	mat.gravity = Vector3(0, 0.03, 0)
	mat.initial_velocity_min = 0.02
	mat.initial_velocity_max = 0.06
	mat.scale_min = 0.6
	mat.scale_max = 1.0
	glints.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.8)
	quad.material = m
	glints.draw_pass_1 = quad
	add_child(glints)


## The effect for the moment t; returns the effect (empty at the
## khachkar or outside the curve).  A new beat starts its pulse.
func update(t: float, reduced: bool, hands: Array) -> Dictionary:
	var e := WowCore.effect_at(t, reduced, data)
	if e.is_empty():
		current = {}
		light.light_energy = 0.0
		glints.emitting = false
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
	return e


func _start(e: Dictionary, reduced: bool, hands: Array) -> void:
	var v: Dictionary = e.get("visual", {})
	# A level may cross two temperatures ([from, to]); the stage takes
	# the last one, the colour the beat ends in.
	var kv = v.get("kelvin", 2500)
	var kelvin := int(kv[-1]) if kv is Array and not kv.is_empty() \
		else int(kv)
	light.light_color = LocationCore.kelvin(kelvin)
	var n := int(v.get("particles", 0))
	glints.emitting = n > 0
	if n > 0:
		glints.amount = n
		glints.seed = int(e.get("level", 1))
		var quad: QuadMesh = glints.draw_pass_1
		var m: StandardMaterial3D = quad.material
		m.albedo_color = Color(LocationCore.kelvin(kelvin), 0.8)
	var h: Dictionary = e.get("haptic", {})
	var kind := str(h.get("kind", ""))
	if kind != "":
		for hand in hands:
			Haptics.pulse(hand, kind, reduced)
