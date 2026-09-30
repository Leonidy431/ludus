## Reading things against the water by light, not by paint (operator,
## 2026-09-30: «в зависимости от того есть ли лампа, а если нет — то
## контровой свет»; docs/HLD_DIVE_BIOMES_BUBBLES_2026-09-30.md, P6).
##
## One term in the fragment shader, a band on the outline of a thing
## (on meshes where the surface turns from the eye or lies out on the
## outline seen from the thing's centre; on the D6 drawings the edge of
## their alpha), carries one of two lights:
##  * the lamp's highlight (подсветка лампой): while the lamp shines, the
##    light of its beam scattered in the water around a thing outlines
##    it in the lamp's own colour (instrument, 6500 K), only inside the
##    cone and falling off as the SpotLight3D itself does, so what the
##    lamp does not reach is not outlined;
##  * the rim light (контровой свет): with the lamp off or the battery
##    dead, the cool tone of the water outlines every thing; it comes in
##    over FADE_S as the eye settles, and goes out when the lamp returns.
## Both are sized to the eye's adaptation to what things are seen
## against (background luminance plus the 0.05 flare of the contrast
## ratio), so a thing whose body is too close to the water in brightness
## is read by its outline.  The colour of no thing is changed.  Holy
## things get neither light, nothing that could read as a halo (TABOO 0.2
## p. 2, 0.4 rule 2, 0.35 rule 7): the lamp lights them as it lights a
## stone, and without the lamp they are read by their outline against
## the water or not at all.  Nothing here is random.
##
## The Compatibility renderer (the project's, desktop and Quest) takes
## what a shader writes to EMISSION as sRGB and turns it into linear
## light itself (GLES3 scene shader: emission = srgb_to_linear(emission)).
## So the lights go to the shader sRGB-encoded, the beam too (a power of
## 1 / 2.2), and the band term multiplies the encoded values: the light
## seen is close to the linear light times the band ** 2.2, exact at the
## very edge, where the band is 1.
class_name RimLight
extends RefCounted

## The lamp on the Mangustik (instrument light, 6500 K, TABOO 0.38):
## dive.gd builds its SpotLight3D from these, and the readability test
## measures with the same numbers.
const LAMP_COLOUR := Color(0.95, 0.97, 1.0)
const LAMP_ENERGY := 4.0
const LAMP_RANGE_M := 22.0
const LAMP_ANGLE_DEG := 32.0
const LAMP_ATTENUATION := 1.0
const LAMP_ANGLE_ATTENUATION := 1.0
## In third person the lamp sits on the front skid and points where the
## drawn beams open (rov_body.gd: 15 degrees down, onto the floor
## ahead); before, it pointed 7 degrees down, and a thing on the floor
## 3 m from it, with the ROV hovering 1.2 m over it, got 0.72 of the
## light on the axis (now 0.93).  In first person it rides on the eye.
const LAMP_PITCH_3P := -PI / 12.0
## Where a thing is read: DiveCore.VIEW_M from the lamp, the ROV
## READ_CLEARANCE_M above it (the Atlas proof frames hover so).
const READ_CLEARANCE_M := 1.2
## The contrast a thing must reach (TABOO 0.3 rule 59).
const READABLE := 1.5
## The part of the outline that is measured: where the light is at least
## half its peak (its full width at half maximum).
const BAND := 0.5
## Strength of both lights, a multiple of the eye's adaptation.  A body
## just short of READABLE on the dark side must be lifted by
## (1.5 - 1 / 1.5) of the adaptation; at half peak and through the
## thickest veil (sediments: fog 0.09 over VIEW_M) that asks for 2.18.
## K keeps 10 % over it for the edge of the beam in third person, where
## the reading point gets 0.93 of the axis (tested).
const K := 2.4
## Seconds for the rim light to come in or go out.
const FADE_S := 1.5
## The rim light's tone: the pale, cool tone of lit water seen from
## below.  Never gold: gold is only the canon's (TABOO 0.38).
const RIM_TONE := Color(0.62, 0.82, 0.92)
## Things that bear the holy besides those flagged `holy` in their data
## (the khachkar of the Atlas): the bulla, with its cross.
const HOLY_ITEMS := ["bulla"]
## Near the lens the lamp's highlight would burn out: it stops growing at
## twice its strength at VIEW_M, that is 1.5 m from the lamp.
const BEAM_CAP := 2.0
## The width of the band on a D6 drawing, in texture coordinates: six
## texels of its 256.
const DRAWING_BAND := 6.0 / 256.0
## The encoding of the beam, as the renderer's sRGB curve (near 2.2).
const GAMMA := 2.2
## Depth and clearance step at which update() looks the background up
## again.
const BACKGROUND_STEP_M := 0.05
## Global shader uniforms (vec4, the colours sRGB-encoded), set once per
## frame by update().
const G_RIM := &"dive_rim"
const G_LAMP := &"dive_lamp"
const G_LAMP_POS := &"dive_lamp_pos"
const G_LAMP_DIR := &"dive_lamp_dir"

## The lamp's own falloff, in the shader as in Godot's GLES3 scene shader
## (get_omni_spot_attenuation and the linear cone): 1.0 at VIEW_M on the
## axis (dive_lamp_dir.w), capped near the lens, zero outside the cone
## and beyond the range; per vertex, encoded like the colours.
const _BEAM_GLSL := """
global uniform vec4 dive_rim;
global uniform vec4 dive_lamp;
global uniform vec4 dive_lamp_pos;
global uniform vec4 dive_lamp_dir;
varying float beam;

float lamp_beam(vec3 world) {
	vec3 to = world - dive_lamp_pos.xyz;
	float d = max(length(to), 0.0001);
	float nd = d * dive_lamp.a;
	nd *= nd;
	nd = max(1.0 - nd * nd, 0.0);
	float cone = max(0.0, 1.0 - (1.0 - dot(to / d, dive_lamp_dir.xyz))
		/ (1.0 - dive_lamp_pos.w));
	return pow(min(nd * nd * cone * dive_lamp_dir.w / d, %s), %s);
}
"""

## Lake objects, the Atlas traces and the fish: their own material, plus
## the one term in EMISSION.
const _MESH_GLSL := """
shader_type spatial;
render_mode %s;
%s
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
varying vec3 outward;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	beam = lamp_beam(world);
	// From the thing's own centre, in view space (per instance for fish).
	outward = mat3(VIEW_MATRIX) * (world - MODEL_MATRIX[3].xyz);
}

void fragment() {
	ALBEDO = albedo.rgb;
	%s
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	// The one term: a band where the surface turns from the eye or lies
	// out on the thing's outline; the flat faces of a proxy turn too
	// little by themselves.
	float facing = abs(dot(NORMAL, VIEW))
		* abs(dot(normalize(outward + vec3(0.0, 0.0, 0.0001)), VIEW));
	EMISSION = (dive_rim.rgb + dive_lamp.rgb * beam) * (1.0 - facing);
}
"""

## The D6 drawings: a flat drawing has no grazing faces, so its band is
## the edge of its alpha, four taps that run only while a light is on.
## Billboard about the vertical axis with the same matrix as Sprite3D's
## BILLBOARD_FIXED_Y material; alpha cut at 0.5 as ALPHA_CUT_DISCARD.
const _DRAWING_GLSL := """
shader_type spatial;
render_mode cull_disabled;
%s
uniform sampler2D drawing : source_color, filter_linear_mipmap, repeat_disable;
uniform float band_uv = %s;

void vertex() {
	beam = lamp_beam(MODEL_MATRIX[3].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0),
			MAIN_CAM_INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz,
			vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(drawing, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
	float edge = 0.0;
	if (dive_rim.a + beam > 0.0) {
		float m = min(
			min(texture(drawing, UV + vec2(band_uv, 0.0)).a,
				texture(drawing, UV - vec2(band_uv, 0.0)).a),
			min(texture(drawing, UV + vec2(0.0, band_uv)).a,
				texture(drawing, UV - vec2(0.0, band_uv)).a));
		edge = 1.0 - m;
	}
	EMISSION = (dive_rim.rgb + dive_lamp.rgb * beam) * edge;
}
"""

## The shader globals live as long as the process; the dive scene is
## made again each time the pilot comes back from the hub.
static var _registered := false

## False: nothing is dressed (--rim=off, the "before" of the proof
## frames and of the render time).
var enabled := true
## The rim light's weight, 0 (lamp shining) .. 1 (settled in the dark).
var weight := 0.0
## Surfaces dressed, and materials left as they were (textured,
## emissive, unshaded, vertex-coloured: none of the lake's proxies is,
## the count says so).
var dressed := 0
var kept := 0
var materials := {}
var drawing_materials := {}
var shaders := {}
var _background_key := Vector2i(-1000000000, 0)
var _y_off := 0.0
var _y_on := 0.0


func _init() -> void:
	if _registered:
		return
	_registered = true
	for g in [G_RIM, G_LAMP, G_LAMP_POS, G_LAMP_DIR]:
		RenderingServer.global_shader_parameter_add(g,
			RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)


# --- The model the readability test measures --------------------------------

static func is_holy(thing: Dictionary) -> bool:
	return bool(thing.get("holy", false)) \
		or str(thing.get("item", "")) in HOLY_ITEMS


## Godot's falloff of this spot light at a distance and an angle off its
## axis (GLES3 scene shader: range window, distance ** -attenuation, the
## cone).  The Compatibility renderer lights a white card with energy E
## at d metres on the axis to E / d (measured under Xvfb, see the HLD).
static func lamp_falloff(distance: float, off_axis_deg: float) -> float:
	var nd := pow(distance / LAMP_RANGE_M, 4.0)
	var window := maxf(1.0 - nd, 0.0)
	var cos_a := cos(deg_to_rad(LAMP_ANGLE_DEG))
	var scos := maxf(cos(deg_to_rad(off_axis_deg)), cos_a)
	var edge := maxf(0.0001, (1.0 - scos) / (1.0 - cos_a))
	return window * window * pow(maxf(distance, 0.0001),
		-LAMP_ATTENUATION) * (1.0 - pow(edge, LAMP_ANGLE_ATTENUATION))


## The scene's lamp VIEW_M ahead on its axis, band by band, in the
## model's unit (the scene's sun at the surface, DiveCore.biome_look).
static func lamp_bands() -> Array:
	var sun: float = DiveCore.biome_look(0.0, 100.0).sun
	var e := LAMP_ENERGY * lamp_falloff(DiveCore.VIEW_M, 0.0) / sun
	var c := LAMP_COLOUR.srgb_to_linear()
	return [e * c.r, e * c.g, e * c.b]


## The lamp's highlight relative to VIEW_M on its axis, as lamp_beam in
## the shader computes it before encoding (it assumes attenuation 1 and a
## linear cone, as the lamp has; the test holds that).
static func beam(distance: float, off_axis_deg: float) -> float:
	return minf(lamp_falloff(distance, off_axis_deg) * DiveCore.VIEW_M,
		BEAM_CAP)


## An albedo seen VIEW_M away at any depth: DiveCore.seen_colour with the
## lamp at `lamp` of its unit (1.0: DiveCore itself; 0.0: lamp off).
static func seen_at(rgb: Array, depth: float, clearance: float,
		lamp: float) -> Array:
	var look := DiveCore.biome_look(depth, clearance)
	var sun := DiveCore.light_left(depth)
	var veil := exp(-float(look.fog) * DiveCore.VIEW_M)
	var out := []
	for i in 3:
		var a: float = DiveCore.ABSORPTION[DiveCore.BANDS[i]]
		var sun_b: float = 0.0 if look.biome == "night" \
			else sun[DiveCore.BANDS[i]]
		var light := sun_b * exp(-a * DiveCore.VIEW_M) \
			+ lamp * exp(-2.0 * a * DiveCore.VIEW_M)
		out.append(minf(1.0, rgb[i] * light) * veil
			+ look.water[i] * (1.0 - veil))
	return out


## What things are seen against at any depth: the water, or the silt
## floor, lit or not by the lamp.
static func background_at(depth: float, clearance: float,
		lamp: float) -> Array:
	var look := DiveCore.biome_look(depth, clearance)
	if look.biome == "sediments":
		return seen_at(DiveCore.SILT, depth, clearance, lamp)
	return look.water


static func ratio(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


## Peak luminance of either light for a background luminance.
static func peak(y_background: float) -> float:
	return K * (y_background + 0.05)


## A tone scaled to a luminance, in linear light.
static func tone(c: Color, y: float) -> Vector3:
	var l := c.srgb_to_linear()
	var ly := 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
	return Vector3(l.r, l.g, l.b) * (y / ly)


## A linear light, sRGB-encoded for EMISSION (see the header).
static func encode(c: Vector3) -> Color:
	return Color(c.x, c.y, c.z).linear_to_srgb()


## Luminance the renderer shows at the very edge (the band term at 1)
## for a light and a beam: the encoded colour times the encoded beam,
## turned back into linear light as the GLES3 scene shader does.
static func edge_luminance(light: Vector3, b: float) -> float:
	var e := encode(light)
	var k := pow(b, 1.0 / GAMMA)
	var l := Color(e.r * k, e.g * k, e.b * k).srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## The two lights for a frame: {rim, lamp} in linear light.  y_off and
## y_on: luminance of the background without and with the lamp; energy:
## the lamp's energy now (a fall dims it).
static func lights(w: float, lamp_lit: bool, energy: float, y_off: float,
		y_on: float) -> Dictionary:
	var hl := Vector3.ZERO
	if lamp_lit:
		hl = tone(LAMP_COLOUR, peak(y_on) * energy / LAMP_ENERGY)
	return {"rim": tone(RIM_TONE, peak(y_off) * w), "lamp": hl}


## Contrast of an albedo in a biome, the lamp on (its light and its
## highlight at the reading point, VIEW_M on its axis) or off (the
## settled rim light): the larger of the body's and the band's.  A holy
## thing has no band.
static func contrast(rgb: Array, biome: String, lamp_on: bool,
		holy: bool) -> float:
	var ref: Dictionary = DiveCore.BIOME_REF[biome]
	var body := DiveCore.luminance(seen_at(rgb, ref.depth, ref.clearance,
		1.0 if lamp_on else 0.0))
	var y_off := DiveCore.luminance(background_at(ref.depth,
		ref.clearance, 0.0))
	var y_on := DiveCore.luminance(background_at(ref.depth,
		ref.clearance, 1.0))
	var bg := y_on if lamp_on else y_off
	var c := ratio(body, bg)
	if holy:
		return c
	var l := lights(1.0, lamp_on, LAMP_ENERGY, y_off, y_on)
	var edge := edge_luminance(l.lamp, beam(DiveCore.VIEW_M, 0.0)) \
		if lamp_on else edge_luminance(l.rim, 1.0)
	var look := DiveCore.biome_look(ref.depth, ref.clearance)
	var veil := exp(-float(look.fog) * DiveCore.VIEW_M)
	return maxf(c, ratio(body + veil * BAND * edge, bg))


## The rim light's weight after dt: towards 1 in the dark, towards 0
## while the lamp shines, at a constant rate (no overshoot, no pulse).
static func fade(w: float, lamp_lit: bool, dt: float) -> float:
	return move_toward(w, 0.0 if lamp_lit else 1.0, dt / FADE_S)


# --- The scene ----------------------------------------------------------

## Set the lights for this frame (dive.gd, once per frame); returns them
## in linear light.  The background is looked up again only when the ROV
## has moved a step of BACKGROUND_STEP_M in depth or clearance: the water
## does not change within a few centimetres, and the frame's script time
## is tight (docs/APK_REQUIREMENTS.md, row 17).
func update(lamp: Node3D, lamp_lit: bool, energy: float, depth: float,
		clearance: float, dt: float) -> Dictionary:
	weight = fade(weight, lamp_lit, dt)
	var key := Vector2i(roundi(depth / BACKGROUND_STEP_M),
		roundi(clearance / BACKGROUND_STEP_M))
	if key != _background_key:
		_background_key = key
		_y_off = DiveCore.luminance(background_at(depth, clearance, 0.0))
		_y_on = DiveCore.luminance(background_at(depth, clearance, 1.0))
	var l := lights(weight, lamp_lit, energy, _y_off, _y_on)
	var rim := encode(l.rim)
	var hl := encode(l.lamp)
	var at := lamp.global_position
	var ahead := -lamp.global_basis.z.normalized()
	RenderingServer.global_shader_parameter_set(G_RIM,
		Vector4(rim.r, rim.g, rim.b, weight))
	RenderingServer.global_shader_parameter_set(G_LAMP,
		Vector4(hl.r, hl.g, hl.b, 1.0 / LAMP_RANGE_M))
	RenderingServer.global_shader_parameter_set(G_LAMP_POS,
		Vector4(at.x, at.y, at.z, cos(deg_to_rad(LAMP_ANGLE_DEG))))
	RenderingServer.global_shader_parameter_set(G_LAMP_DIR,
		Vector4(ahead.x, ahead.y, ahead.z, DiveCore.VIEW_M))
	return l


func _shader(key: String, code: String) -> Shader:
	if not shaders.has(key):
		var s := Shader.new()
		s.code = code
		shaders[key] = s
	return shaders[key]


func _beam_glsl() -> String:
	return _BEAM_GLSL % ["%.1f" % BEAM_CAP, "%.6f" % (1.0 / GAMMA)]


## The same look as a StandardMaterial3D of the lake's proxies, with the
## band; any other material is returned as it is.
func material_for(base: Material) -> Material:
	var m := base as BaseMaterial3D
	if m == null or m.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL \
			or m.albedo_texture != null or m.emission_enabled \
			or m.normal_enabled or m.vertex_color_use_as_albedo \
			or m.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED \
			or not m.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED,
				BaseMaterial3D.TRANSPARENCY_ALPHA,
				BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]:
		kept += 1
		return base
	var key := "%s|%.3f|%.3f|%.3f|%d|%d" % [m.albedo_color.to_html(),
		m.roughness, m.metallic, m.metallic_specular, m.transparency,
		m.cull_mode]
	if not materials.has(key):
		var mode: String = ["cull_back", "cull_front",
			"cull_disabled"][m.cull_mode]
		var alpha := ""
		if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			alpha = "ALPHA = albedo.a;"
		if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
			mode += ", depth_prepass_alpha"
		var sm := ShaderMaterial.new()
		sm.shader = _shader(mode + alpha, _MESH_GLSL % [mode, _beam_glsl(),
			alpha])
		sm.set_shader_parameter("albedo", m.albedo_color)
		sm.set_shader_parameter("roughness", m.roughness)
		sm.set_shader_parameter("metallic", m.metallic)
		sm.set_shader_parameter("specular", m.metallic_specular)
		materials[key] = sm
	dressed += 1
	return materials[key]


## Give every mesh under `node` the band, unless the thing is holy.
## Returns how many materials were replaced.
func dress(node: Node, holy := false) -> int:
	if holy or not enabled:
		return 0
	var n := 0
	var stack: Array = [node]
	while not stack.is_empty():
		var g: Node = stack.pop_back()
		stack.append_array(g.get_children())
		if g is GeometryInstance3D and g.material_override != null:
			var r := material_for(g.material_override)
			if r != g.material_override:
				g.material_override = r
				n += 1
		elif g is MeshInstance3D and g.mesh != null:
			for i in g.mesh.get_surface_count():
				var base: Material = g.get_active_material(i)
				var r := material_for(base)
				if r != base:
					g.set_surface_override_material(i, r)
					n += 1
	return n


## A D6 drawing's Sprite3D gets its band through its material: one per
## texture.
func drawing(sprite: Sprite3D) -> void:
	if not enabled:
		return
	var tex := sprite.texture
	if not drawing_materials.has(tex):
		var sm := ShaderMaterial.new()
		sm.shader = _shader("drawing", _DRAWING_GLSL % [_beam_glsl(),
			"%.6f" % DRAWING_BAND])
		sm.set_shader_parameter("drawing", tex)
		drawing_materials[tex] = sm
	sprite.material_override = drawing_materials[tex]
