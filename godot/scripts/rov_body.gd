## The Mangustik's body in the water: the model from the operator's
## drawings, two headlights with their beams seen in the water, a status
## light and the manipulator; the console's front camera follows its
## skid (docs/HLD_MANGUSTIK_COCKPIT M7, M8).
##
## Body coordinates: -Z is the bow, +Y up, metres; the front camera
## skid sits 0.72 m ahead of the centre (08_sensor_and_camera_skid at
## x = 500 mm in 00_full_assembly.scad).
class_name RovBody
extends Node3D

const INSTRUMENT := Color(0.86, 0.92, 1.0)  # 6500 K, the instrument class.
const SKID_Z := -0.72
const HEADLIGHT_X := 0.24
const BRASS := Color(0.71, 0.55, 0.28)
const STEEL := Color(0.62, 0.64, 0.68)

var model: Node3D
var beams: Array = []
var lenses: Array = []
# Lamp housings and lenses: part of the frame, hidden with it.
var fixtures: Array = []
var led: MeshInstance3D
## The posoh hydrophone on the bow end of the top auxiliary tube
## (PosohCore.MOUNT); part of the frame, hidden with it in first person.
var hydrophone: Node3D
var arm_root: Node3D
var arm_upper: Node3D
var arm_fore: Node3D
var fingers: Array = []
## Where the console's front camera sits (it lives in the second
## screen's viewport, dive.gd, and follows this point).
const EYE := Vector3(0, 0.02, SKID_Z - 0.05)
## The beams are on their own render layer, so the front camera does
## not look through its own light haze.
const BEAM_LAYER := 2
var reach_started := -100.0
var battery_alive := true
var frame_on := true
var lamp_on := true


func _ready() -> void:
	# Б-2: the full model within RovLod.NEAR_M of the camera (the
	# front camera on the skid), the far-view proxy beyond (the chase
	# camera, 2.8 m behind).
	model = RovLod.build()
	add_child(model)
	for side in [-1.0, 1.0]:
		_headlight(side * HEADLIGHT_X)
	_status_led()
	_hydrophone()
	_manipulator()


func _unshaded(colour: Color, additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	if colour.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
	return m


func _metal(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.metallic = 0.6
	m.roughness = 0.45
	return m


## A lamp housing, its lit lens and the beam: a long faint cone that
## the water makes visible (scattering), additive so it only brightens.
func _headlight(x: float) -> void:
	var housing := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.045
	cyl.height = 0.08
	housing.mesh = cyl
	housing.material_override = _metal(STEEL)
	housing.rotation_degrees = Vector3(90, 0, 0)
	housing.position = Vector3(x, -0.02, SKID_Z)
	add_child(housing)
	fixtures.append(housing)
	var lens := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.038
	disc.bottom_radius = 0.038
	disc.height = 0.01
	lens.mesh = disc
	lens.material_override = _unshaded(INSTRUMENT)
	lens.rotation_degrees = Vector3(90, 0, 0)
	lens.position = Vector3(x, -0.02, SKID_Z - 0.045)
	add_child(lens)
	lenses.append(lens)
	fixtures.append(lens)
	var beam := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.04
	cone.bottom_radius = 1.4
	cone.height = 4.5
	cone.cap_top = false
	cone.cap_bottom = false
	beam.mesh = cone
	beam.material_override = _beam_material()
	# The cone's axis is +Y with the narrow end on top.  Turned 75
	# degrees about X its top points back and up, so the wide end opens
	# forward and 15 degrees down, onto the floor ahead; then its narrow end is moved
	# onto the lens.
	beam.rotation_degrees = Vector3(75, 0, 0)
	beam.position = Vector3(x, -0.02, SKID_Z - 0.05) \
		- Basis.from_euler(beam.rotation) * Vector3(0, 2.25, 0)
	beam.layers = 1 << (BEAM_LAYER - 1)
	add_child(beam)
	beams.append(beam)


## The beam's light in the water: strongest at the lens, fading to
## nothing at the far end, so it reads as scattered light and, seen
## from behind along the beam, as a soft glow rather than a hard disc.
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 tint;
uniform float strength = 0.07;
void fragment() {
	// UV.y runs from the narrow end at the lens (0) to the wide end.
	ALBEDO = tint;
	ALPHA = strength * pow(1.0 - UV.y, 1.5);
}
"""


func _beam_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = BEAM_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("tint", Vector3(INSTRUMENT.r, INSTRUMENT.g,
		INSTRUMENT.b))
	return m


## A small status light on the central control module (instrument
## cyan): on while the battery lives.
func _status_led() -> void:
	led = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.018
	s.height = 0.036
	led.mesh = s
	led.material_override = _unshaded(Color(0.08, 0.82, 0.82))
	led.position = Vector3(0, 0.6, 0.05)
	add_child(led)


## The operator's own hydrophone (posoh "model 1",
## godot/models/posoh/hydrophone.glb, built from hydrophone_v1.scad).
## The model's origin is its end-cap flange and its sensor looks along
## -Z, so it only needs to be put on the mount: the cap against the
## top tube's bow end, the potted piezo facing the water ahead.
func _hydrophone() -> void:
	var scene := load("res://models/posoh/hydrophone.glb") as PackedScene
	hydrophone = scene.instantiate() if scene else Node3D.new()
	hydrophone.name = "PosohHydrophone"
	hydrophone.position = PosohCore.MOUNT
	add_child(hydrophone)
	fixtures.append(hydrophone)


## Two links and a claw under the front of the frame, at the tool
## plate (09_manipulator_and_tool_interface at z = -200 mm).  Brass
## links, steel claw: the Order's workshop builds its instruments.
func _manipulator() -> void:
	arm_root = Node3D.new()
	arm_root.position = Vector3(0, -0.2, SKID_Z + 0.1)
	add_child(arm_root)
	arm_upper = _link(0.34, 0.03, BRASS)
	arm_root.add_child(arm_upper)
	arm_fore = _link(0.3, 0.025, BRASS)
	arm_fore.position = Vector3(0, 0, -0.34)
	arm_upper.add_child(arm_fore)
	var wrist := Node3D.new()
	wrist.position = Vector3(0, 0, -0.3)
	arm_fore.add_child(wrist)
	_tool_flange(wrist)
	# The drawings stop at the flange: the claw below is a stand-in,
	# not a drawn part (docs/HLD_MANGUSTIK_COCKPIT M11).
	for side in [-1.0, 1.0]:
		var f := _link(0.09, 0.012, STEEL)
		f.rotation.y = side * 0.35
		wrist.add_child(f)
		fingers.append(f)
	set_arm(0.0)


## The tool flange of 09_manipulator_and_tool_interface.scad: six M6
## bolts on a 90 mm pitch circle round a 30 mm pass-through, anodised
## aluminium (LightSteelBlue in the drawing).
func _tool_flange(wrist: Node3D) -> void:
	var disc := MeshInstance3D.new()
	var d := CylinderMesh.new()
	d.top_radius = 0.06
	d.bottom_radius = 0.06
	d.height = 0.012
	disc.mesh = d
	disc.material_override = _metal(Color(0.69, 0.77, 0.87))
	disc.rotation_degrees = Vector3(90, 0, 0)
	wrist.add_child(disc)
	var hole := MeshInstance3D.new()
	var h := CylinderMesh.new()
	h.top_radius = 0.015
	h.bottom_radius = 0.015
	h.height = 0.014
	hole.mesh = h
	hole.material_override = _unshaded(Color(0.05, 0.06, 0.08))
	hole.rotation_degrees = Vector3(90, 0, 0)
	wrist.add_child(hole)
	for i in 6:
		var bolt := MeshInstance3D.new()
		var b := CylinderMesh.new()
		b.top_radius = 0.005
		b.bottom_radius = 0.005
		b.height = 0.016
		bolt.mesh = b
		bolt.material_override = _metal(STEEL)
		bolt.rotation_degrees = Vector3(90, 0, 0)
		var a := TAU * i / 6.0
		bolt.position = Vector3(cos(a), sin(a), 0) * 0.045
		wrist.add_child(bolt)


## A link along -Z from its own origin (the joint).
func _link(length: float, radius: float, colour: Color) -> Node3D:
	var joint := Node3D.new()
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	m.mesh = cyl
	m.material_override = _metal(colour)
	m.rotation_degrees = Vector3(90, 0, 0)
	m.position = Vector3(0, 0, -length / 2.0)
	joint.add_child(m)
	var knuckle := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = radius * 1.4
	ball.height = radius * 2.8
	knuckle.mesh = ball
	knuckle.material_override = _metal(STEEL)
	joint.add_child(knuckle)
	return joint


## Pose the arm: 0 folded back under the frame, 1 reached forward and a
## little down, claw open at the reach.
func set_arm(phase: float) -> void:
	arm_upper.rotation.x = lerpf(-2.6, -0.25, phase)
	arm_fore.rotation.x = lerpf(2.4, 0.1, phase)
	for i in fingers.size():
		var side := -1.0 if i == 0 else 1.0
		fingers[i].rotation.y = side * lerpf(0.12, 0.5, phase)


func reach(now: float) -> void:
	reach_started = now


func set_lamp(on: bool) -> void:
	lamp_on = on
	# From the lens itself the beam is no haze to look through: the
	# cones show only from outside, in third person.
	for b in beams:
		b.visible = on and frame_on
	for l in lenses:
		l.material_override.albedo_color = INSTRUMENT if on \
			else Color(0.2, 0.22, 0.25)


func set_battery(alive: bool) -> void:
	battery_alive = alive
	led.visible = battery_alive and frame_on


func update(now: float) -> void:
	set_arm(CockpitCore.arm_phase(now - reach_started))


## The model only (not the arm or the lights) hides in first person:
## the ROV's own eye does not see its frame, but it sees its arm.
func show_frame(on: bool) -> void:
	frame_on = on
	model.visible = on
	for f in fixtures:
		f.visible = on
	set_lamp(lamp_on)
	led.visible = battery_alive and frame_on
