## The rim light on a real render against its model (RimLight).
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##     --rendering-driver opengl3 --resolution 640x360 \
##     -s res://tests/rim_probe.gd
##
## The readability test measures RimLight's model; this probe renders
## grey cards in the dark with the scene's lamp and the band shader and
## reads their pixels, so the shader cannot drift from the model while
## the test stays green (a broken lamp_light, a lost highlight or a band
## that fills a face all fail here).  Exit 1 on any failure.
##
## The cases: the rim light alone (lamp off), the lamp on its axis at
## 3 m and at 8 m (highlight and rim light by the beam's share), a card
## outside the cone with the lamp on (the rim light in full), and a disc
## turned 45 degrees with the lamp off (its face stays dark, only its
## outline is lit).  Nothing is random; the scene has no fog, no ambient
## light and a black background, so a pixel is the lamp, the band or
## nothing.
extends SceneTree

## The background the lights are sized to in the probe (any value will
## do: the model gets the same one).
const Y_BG := 0.05
const DEPTH := 140.0
const ALBEDO := 0.5
## The face of a card lit by nothing must stay this dark (linear): a
## band that fills the face fails here.
const DARK := 0.004
## Tolerance of a lit value against the model (the edge pixel is where
## the band reaches 1, a pixel or two wide; 8-bit output).
const TOL := 0.15

var failures := 0
var cam: Camera3D
var lamp: SpotLight3D
var rim := RimLight.new()
var cards: Array = []


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	cam = Camera3D.new()
	root.add_child(cam)
	lamp = SpotLight3D.new()
	lamp.light_color = RimLight.LAMP_COLOUR
	lamp.light_energy = RimLight.LAMP_ENERGY
	lamp.spot_range = RimLight.LAMP_RANGE_M
	lamp.spot_angle = RimLight.LAMP_ANGLE_DEG
	lamp.spot_attenuation = RimLight.LAMP_ATTENUATION
	lamp.spot_angle_attenuation = RimLight.LAMP_ANGLE_ATTENUATION
	lamp.light_specular = 0.0
	cam.add_child(lamp)
	await process_frame
	await _case("rim light, lamp off, card face-on at 3 m", false,
		_card(Vector3(0, 0, -3.0), 0.0, false))
	await _case("lamp on its axis at 3 m", true,
		_card(Vector3(0, 0, -3.0), 0.0, false))
	await _case("lamp on its axis at 8 m", true,
		_card(Vector3(0, 0, -8.0), 0.0, false))
	var off := deg_to_rad(40.0)
	await _case("lamp on, card 40 deg outside the cone", true,
		_card(Vector3(-sin(off), 0, -cos(off)) * 3.0, off, false))
	await _case("disc turned 45 deg, lamp off", false,
		_card(Vector3(0, 0, -3.0), 0.0, true))
	print("rim probe: %d failures" % failures)
	quit(1 if failures else 0)


## A grey card 0.6 m square (or a disc 0.6 m across, turned 45 degrees
## about its horizontal axis) facing the eye, dressed with the band.
func _card(at: Vector3, yaw: float, disc: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	if disc:
		var c := CylinderMesh.new()
		c.top_radius = 0.3
		c.bottom_radius = 0.3
		c.height = 0.02
		c.radial_segments = 48
		m.mesh = c
		m.rotation = Vector3(PI / 2.0 - PI / 4.0, yaw, 0.0)
	else:
		var b := BoxMesh.new()
		b.size = Vector3(0.6, 0.6, 0.02)
		m.mesh = b
		m.rotation.y = yaw
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(ALBEDO, ALBEDO, ALBEDO)
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	m.material_override = mat
	m.position = at
	root.add_child(m)
	_check(rim.dress(m) == 1, "the card is dressed")
	return m


func _case(what: String, lamp_on: bool, card: MeshInstance3D) -> void:
	for c in cards:
		c.visible = false
	cards.append(card)
	lamp.visible = lamp_on
	var l := RimLight.lights(0.0 if lamp_on else 1.0, lamp_on,
		RimLight.LAMP_ENERGY, Y_BG, Y_BG, DEPTH)
	RimLight.apply(lamp, l)
	for k in 4:
		await process_frame
	var img := root.get_texture().get_image()
	var centre := cam.unproject_position(card.global_position)
	var face := _lum(img, Vector2i(centre))
	var peak := 0.0
	var peak_at := Vector2i.ZERO
	for y in img.get_height():
		for x in img.get_width():
			var v := _lum(img, Vector2i(x, y))
			if v > peak:
				peak = v
				peak_at = Vector2i(x, y)
	var to := card.global_position - lamp.global_position
	var d := to.length()
	var a := rad_to_deg(to.normalized().angle_to(-lamp.global_basis.z))
	var b := RimLight.beam(d, a) if lamp_on else 0.0
	var edge := RimLight.edge_mix(l.rim, l.lamp, b, RimLight.rim_share(b,
		l.presence))
	# The body as the renderer lights it: the linear albedo times the
	# lamp's light at the card (E times its falloff, N.L = 1 at the
	# centre of a card facing the lamp).
	var lc := RimLight.LAMP_COLOUR.srgb_to_linear()
	var body := 0.0
	if lamp_on:
		body = Color(ALBEDO, 0, 0).srgb_to_linear().r * RimLight.LAMP_ENERGY \
			* RimLight.lamp_falloff(d, a) * (0.2126 * lc.r + 0.7152 * lc.g
			+ 0.0722 * lc.b)
	print("%s: %.1f m, %.1f deg, beam %.3f; face %.4f (body %.4f), edge "
		% [what, d, a, b, face, body] + "%.4f at %s (model %.4f)"
		% [peak - face, peak_at, edge])
	if lamp_on and b > 0.0:
		_check(absf(face - body) <= TOL * body,
			"%s: the body is lit as the renderer lights it" % what)
	else:
		_check(face <= DARK, "%s: the face stays dark (%.4f)" % [what,
			face])
	_check(absf((peak - face) - edge) <= TOL * edge,
		"%s: the band at the outline is the model's (%.4f vs %.4f)" % [
		what, peak - face, edge])


static func _lum(img: Image, p: Vector2i) -> float:
	var c := img.get_pixelv(p).srgb_to_linear()
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
