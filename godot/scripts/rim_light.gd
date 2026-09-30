## Reading things against the water by light, not by paint (operator,
## 2026-09-30: «в зависимости от того есть ли лампа, а если нет — то
## контровой свет»; docs/HLD_DIVE_BIOMES_BUBBLES_2026-09-30.md, P6).
##
## One term in the fragment shader, a band on the outline of a thing,
## carries two lights.  On meshes the band is the rim of the thing's
## silhouette: its own bounding box, passed per instance, is projected
## on the screen, and only a strip RIM_WIDTH wide inside that outline is
## lit, plus the faces that graze the eye; the face of a disc or a box
## turned to the eye keeps its own colour.  On the D6 drawings the band
## is the edge of their alpha.  The two lights:
##  * the lamp's highlight (подсветка лампой): the light of its beam
##    scattered in the water around a thing outlines it in the lamp's own
##    colour (instrument, 6500 K), only inside the cone and falling off
##    as the SpotLight3D itself does;
##  * the rim light (контровой свет): where the lamp does not reach, the
##    pale tone of the water itself outlines every thing.  It is decided
##    per thing, not for the whole scene: the rim takes the share the
##    beam leaves (1 - beam, the beam 1.0 at the reading point), so a
##    thing past the beam or outside its cone reads as well as with the
##    lamp off, and switching the lamp on never hides what it does not
##    light.  With the lamp off it comes in over FADE_S as the eye
##    settles, and goes back to the beam's share when the lamp returns.
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
## So the lights go to the shader linear, are shared by the beam and
## summed linear per vertex, and only then encoded with the sRGB curve;
## the band multiplies the encoded light, so the light seen is exact at
## the very edge, where the band is 1 (tests/rim_probe.gd measures it).
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
## thickest veil (sediments: fog 0.09 over VIEW_M) that asks for 2.18 on
## the lamp's axis.  At the third-person reading point the beam is 0.93
## of the axis and the need is 2.36, so K = 2.4 keeps about 2 % there:
## the 10 % over 2.18 is almost all spent on the cone (tested, both
## needs are printed).
const K := 2.4
## Seconds for the rim light to come in or go out.
const FADE_S := 1.5
## The rim light's tone is the water's own at the depth
## (DiveCore.water_colour), its hue kept and its saturation brought down
## to RIM_SATURATION by mixing with white: a pale water, not the cyan of
## the instruments and never gold (TABOO 0.38 p. 1).
const RIM_SATURATION := 0.3
## Width of the band on a mesh, a fraction of the distance to the thing
## (about 0.34 degrees of arc, 5 px across the 1280 px proof frames); on
## a thing smaller than twice that the band stops at half its size.
const RIM_WIDTH := 0.006
const RIM_WIDTH_MAX := 0.5
## Faces that graze the eye (|N.V| below this) are part of the band
## too: the true silhouette of curved and hollow things.
const GRAZE := 0.2
## Near the lens the lamp's highlight would burn out: it stops growing at
## twice its strength at VIEW_M, that is 1.5 m from the lamp.
const BEAM_CAP := 2.0
## The width of the band on a D6 drawing, in texture coordinates: six
## texels of its 256.
const DRAWING_BAND := 6.0 / 256.0
## Depth and clearance step at which update() looks the background up
## again.
const BACKGROUND_STEP_M := 0.05
## The background the lights are sized to follows a new one over this
## long (a straight share of the gap per second): crossing the edge of
## the sediments (clearance 2.5 m) while hovering would otherwise step
## both lights by up to 29 % from one frame to the next.
const BACKGROUND_EASE_S := FADE_S
## Global shader uniforms (vec4, the colours linear), set once per frame
## by update().  dive_rim.a is the lamp's presence: 1 while it
## shines, down to 0 over FADE_S after it goes out.
const G_RIM := &"dive_rim"
const G_LAMP := &"dive_lamp"
const G_LAMP_POS := &"dive_lamp_pos"
const G_LAMP_DIR := &"dive_lamp_dir"

## The lamp's own falloff, in the shader as in Godot's GLES3 scene shader
## (get_omni_spot_attenuation and the linear cone): 1.0 at VIEW_M on the
## axis (dive_lamp_dir.w = 1 / lamp_falloff(VIEW_M, 0)), capped near the
## lens, zero outside the cone
## and beyond the range; per vertex.  The rim light takes the share the
## beam leaves; the two are summed linear and encoded once.
const _BEAM_GLSL := """
global uniform vec4 dive_rim;
global uniform vec4 dive_lamp;
global uniform vec4 dive_lamp_pos;
global uniform vec4 dive_lamp_dir;
varying vec3 band_light;

// The light of the band at a point, sRGB-encoded as the renderer
// decodes it.
vec3 lamp_light(vec3 world) {
	vec3 to = world - dive_lamp_pos.xyz;
	float d = max(length(to), 0.0001);
	float nd = d * dive_lamp.a;
	nd *= nd;
	nd = max(1.0 - nd * nd, 0.0);
	float cone = max(0.0, 1.0 - (1.0 - dot(to / d, dive_lamp_dir.xyz))
		/ (1.0 - dive_lamp_pos.w));
	float b = min(nd * nd * cone * dive_lamp_dir.w / d, %s);
	vec3 l = dive_rim.rgb * (1.0 - min(1.0, b * dive_rim.a))
		+ dive_lamp.rgb * b;
	return mix(12.92 * l, 1.055 * pow(l, vec3(1.0 / 2.4)) - 0.055,
		step(vec3(0.0031308), l));
}
"""

## Lake objects, the Atlas traces and the fish: their own material, plus
## the one term in EMISSION.  rim_c and rim_x/y/z: the thing's centre
## and half axes in this mesh's own space (RimLight.dress), so a moving
## fish of a MultiMesh carries its box with it.
const _MESH_GLSL := """
shader_type spatial;
render_mode %s;
%s
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
instance uniform vec3 rim_c = vec3(0.0);
instance uniform vec3 rim_x = vec3(0.5, 0.0, 0.0);
instance uniform vec3 rim_y = vec3(0.0, 0.5, 0.0);
instance uniform vec3 rim_z = vec3(0.0, 0.0, 0.5);
varying vec3 outward;
varying flat vec3 centre_v;
varying flat vec3 ax;
varying flat vec3 ay;
varying flat vec3 az;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	band_light = lamp_light(world);
	mat3 to_view = mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX);
	centre_v = (VIEW_MATRIX * (MODEL_MATRIX * vec4(rim_c, 1.0))).xyz;
	outward = (VIEW_MATRIX * vec4(world, 1.0)).xyz - centre_v;
	ax = to_view * rim_x;
	ay = to_view * rim_y;
	az = to_view * rim_z;
}

void fragment() {
	ALBEDO = albedo.rgb;
	%s
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	// The band: how far out this point lies towards the outline of the
	// thing's box as the eye sees it (the box's inscribed ellipsoid,
	// projected along the line to its centre), lit only in the last
	// RIM_WIDTH of it; and the faces that graze the eye.
	vec3 dir = normalize(centre_v);
	vec3 o = outward - dot(outward, dir) * dir;
	float r = length(o);
	vec3 u = o / max(r, 0.00001);
	float h = max(sqrt(dot(u, ax) * dot(u, ax) + dot(u, ay) * dot(u, ay)
		+ dot(u, az) * dot(u, az)), 0.0001);
	float w = min(%s * length(centre_v) / h, %s);
	float band = max(smoothstep(1.0 - w, 1.0, r / h),
		1.0 - smoothstep(0.0, %s, abs(dot(NORMAL, VIEW))));
	EMISSION = band_light * band;
}
"""

## The D6 drawings: a flat drawing has no grazing faces, so its band is
## the edge of its alpha, four taps.  Billboard about the vertical axis
## with the same matrix as Sprite3D's BILLBOARD_FIXED_Y material; alpha
## cut at 0.5 as ALPHA_CUT_DISCARD.
const _DRAWING_GLSL := """
shader_type spatial;
render_mode cull_disabled;
%s
uniform sampler2D drawing : source_color, filter_linear_mipmap, repeat_disable;
uniform float band_uv = %s;

void vertex() {
	band_light = lamp_light(MODEL_MATRIX[3].xyz);
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
	float m = min(
		min(texture(drawing, UV + vec2(band_uv, 0.0)).a,
			texture(drawing, UV - vec2(band_uv, 0.0)).a),
		min(texture(drawing, UV + vec2(0.0, band_uv)).a,
			texture(drawing, UV - vec2(0.0, band_uv)).a));
	EMISSION = band_light * (1.0 - m);
}
"""

## The shader globals live as long as the process; the dive scene is
## made again each time the pilot comes back from the hub.
static var _registered := false

## False: nothing is dressed (--rim=off, the "before" of the proof
## frames and of the render time).
var enabled := true
## The rim light's weight, 0 (lamp shining) .. 1 (settled in the dark);
## the shader gets 1 - weight, the lamp's presence.
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
var _eased := false
var _y_off := 0.0
var _y_on := 0.0
var _y_off_to := 0.0
var _y_on_to := 0.0
var _rate_off := 0.0
var _rate_on := 0.0


func _init() -> void:
	if _registered:
		return
	_registered = true
	for g in [G_RIM, G_LAMP, G_LAMP_POS, G_LAMP_DIR]:
		RenderingServer.global_shader_parameter_add(g,
			RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)


# --- The model the readability test measures --------------------------------

## Holy or not to be touched, by the thing's own data: `holy` or
## `noInteract`, at the top (the Atlas traces) or under `flags` (the
## lake objects, as scripts/lake/lake_objects.py writes them).
static func is_holy(thing: Dictionary) -> bool:
	var flags: Dictionary = thing.get("flags", {}) \
		if thing.get("flags") is Dictionary else {}
	for key in ["holy", "noInteract"]:
		if bool(thing.get(key, false)) or bool(flags.get(key, false)):
			return true
	return false


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


## The lamp's highlight relative to VIEW_M on its axis, as lamp_light in
## the shader computes it before encoding (it assumes attenuation 1 and a
## linear cone, as the lamp has; the test holds that, and
## tests/rim_probe.gd checks the shader against it on a real render).
static func beam(distance: float, off_axis_deg: float) -> float:
	return minf(lamp_at(distance, off_axis_deg), BEAM_CAP)


## The lamp's light on a thing `distance` away and `off_axis_deg` off its
## axis, in the model's unit (1.0 at VIEW_M on the axis, uncapped: the
## light is not capped, only its highlight is).
static func lamp_at(distance: float, off_axis_deg: float) -> float:
	return lamp_falloff(distance, off_axis_deg) \
		/ lamp_falloff(DiveCore.VIEW_M, 0.0)


## An albedo seen `distance` away at any depth: DiveCore.seen_colour with
## the lamp at `lamp` of its unit (1.0 at VIEW_M: DiveCore itself; 0.0:
## lamp off).  Like DiveCore it lights the sRGB-encoded albedo, which is
## darker than the renderer at half light (HLD P6, open question 7).
static func seen_at(rgb: Array, depth: float, clearance: float,
		lamp: float, distance := DiveCore.VIEW_M) -> Array:
	var look := DiveCore.biome_look(depth, clearance)
	var sun := DiveCore.light_left(depth)
	var veil := exp(-float(look.fog) * distance)
	var out := []
	for i in 3:
		var a: float = DiveCore.ABSORPTION[DiveCore.BANDS[i]]
		var sun_b: float = 0.0 if look.biome == "night" \
			else sun[DiveCore.BANDS[i]]
		var light := sun_b * exp(-a * distance) \
			+ lamp * exp(-2.0 * a * distance)
		out.append(minf(1.0, rgb[i] * light) * veil
			+ look.water[i] * (1.0 - veil))
	return out


## What things are seen against at any depth: the water, or the silt
## floor, lit or not by the lamp.
static func background_at(depth: float, clearance: float,
		lamp: float, distance := DiveCore.VIEW_M) -> Array:
	var look := DiveCore.biome_look(depth, clearance)
	if look.biome == "sediments":
		return seen_at(DiveCore.SILT, depth, clearance, lamp, distance)
	return look.water


static func ratio(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


## Peak luminance of either light for a background luminance.
static func peak(y_background: float) -> float:
	return K * (y_background + 0.05)


## The rim light's tone at a depth: the water's colour with its hue and
## a saturation of RIM_SATURATION (mixed with white).
static func rim_tone(depth: float) -> Color:
	var w: Array = DiveCore.water_colour(depth)
	var hi := maxf(maxf(w[0], w[1]), w[2])
	var lo := minf(minf(w[0], w[1]), w[2])
	var s := 1.0 - lo / hi
	var f := minf(1.0, RIM_SATURATION / maxf(s, 0.0001))
	var c := Color(w[0] / hi, w[1] / hi, w[2] / hi)
	return Color(1.0, 1.0, 1.0).lerp(c, f)


## A tone scaled to a luminance, in linear light.
static func tone(c: Color, y: float) -> Vector3:
	var l := c.srgb_to_linear()
	var ly := 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
	return Vector3(l.r, l.g, l.b) * (y / ly)


## A linear light as the sRGB the renderer decodes (see the header).
static func encode(c: Vector3) -> Color:
	return Color(c.x, c.y, c.z).linear_to_srgb()


## Luminance the renderer shows at the very edge (the band term at 1)
## for one light and a beam.
static func edge_luminance(light: Vector3, b: float) -> float:
	return edge_mix(light, Vector3.ZERO, 0.0, b)


## The same for both lights, as the shader sums them: the rim light by
## its share, the lamp's highlight by the beam, linear, encoded once and
## decoded by the renderer.
static func edge_mix(rim: Vector3, lamp: Vector3, b: float,
		rim_share: float) -> float:
	var l := encode(rim * maxf(rim_share, 0.0) + lamp * b).srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## The rim light's share for a beam and the lamp's presence, as in
## lamp_light in the shader.
static func rim_share(b: float, presence: float) -> float:
	return 1.0 - minf(1.0, b * presence)


## The two lights for a frame: {rim, lamp} in linear light at full
## strength (the shader shares them per thing by the beam), and the
## lamp's presence.  y_off and y_on: luminance of the background without
## and with the lamp; energy: the lamp's energy now (a fall dims it).
static func lights(w: float, lamp_lit: bool, energy: float, y_off: float,
		y_on: float, depth: float) -> Dictionary:
	var hl := Vector3.ZERO
	if lamp_lit:
		hl = tone(LAMP_COLOUR, peak(y_on) * energy / LAMP_ENERGY)
	return {"rim": tone(rim_tone(depth), peak(y_off)), "lamp": hl,
		"presence": 1.0 - w}


## Contrast of an albedo in a biome, the lamp on (settled) or off (the
## rim light settled): the larger of the body's and the band's.  The
## thing lies `distance` from the lamp and `off_axis_deg` off its axis
## (by default the reading point, VIEW_M on the axis).  A holy thing has
## no band.
static func contrast(rgb: Array, biome: String, lamp_on: bool,
		holy: bool, distance := DiveCore.VIEW_M,
		off_axis_deg := 0.0) -> float:
	var ref: Dictionary = DiveCore.BIOME_REF[biome]
	var body := DiveCore.luminance(seen_at(rgb, ref.depth, ref.clearance,
		lamp_at(distance, off_axis_deg) if lamp_on else 0.0, distance))
	var y_off := DiveCore.luminance(background_at(ref.depth,
		ref.clearance, 0.0))
	var y_on := DiveCore.luminance(background_at(ref.depth,
		ref.clearance, 1.0))
	# What the thing is seen against where it lies: the silt floor there
	# gets the lamp's light as the thing does (the reading point: y_on).
	var bg := DiveCore.luminance(background_at(ref.depth, ref.clearance,
		lamp_at(distance, off_axis_deg), distance)) if lamp_on \
		else DiveCore.luminance(background_at(ref.depth, ref.clearance,
		0.0, distance))
	var c := ratio(body, bg)
	if holy:
		return c
	var l := lights(0.0 if lamp_on else 1.0, lamp_on, LAMP_ENERGY, y_off,
		y_on, ref.depth)
	var b := beam(distance, off_axis_deg)
	var edge := edge_mix(l.rim, l.lamp, b, rim_share(b, l.presence))
	var look := DiveCore.biome_look(ref.depth, ref.clearance)
	var veil := exp(-float(look.fog) * distance)
	return maxf(c, ratio(body + veil * BAND * edge, bg))


## The rim light's weight after dt: towards 1 in the dark, towards 0
## while the lamp shines, at a constant rate (no overshoot, no pulse).
static func fade(w: float, lamp_lit: bool, dt: float) -> float:
	return move_toward(w, 0.0 if lamp_lit else 1.0, dt / FADE_S)


# --- The scene ----------------------------------------------------------

## The background luminances the lights are sized to, {off, on}: looked
## up again only when the ROV has moved a step of BACKGROUND_STEP_M in
## depth or clearance (the water does not change within a few
## centimetres, and the frame's script time is tight,
## docs/APK_REQUIREMENTS.md, row 17), and eased towards a new value
## along a straight ramp over BACKGROUND_EASE_S, so a biome edge crossed
## while hovering does not step the lights.
func track_background(depth: float, clearance: float,
		dt: float) -> Dictionary:
	var key := Vector2i(roundi(depth / BACKGROUND_STEP_M),
		roundi(clearance / BACKGROUND_STEP_M))
	if key != _background_key:
		_background_key = key
		_y_off_to = DiveCore.luminance(background_at(depth, clearance, 0.0))
		_y_on_to = DiveCore.luminance(background_at(depth, clearance, 1.0))
		_rate_off = absf(_y_off_to - _y_off) / BACKGROUND_EASE_S
		_rate_on = absf(_y_on_to - _y_on) / BACKGROUND_EASE_S
	if not _eased:
		_eased = true
		_y_off = _y_off_to
		_y_on = _y_on_to
	# A straight ramp, as the rim light's own fade: no overshoot.
	_y_off = move_toward(_y_off, _y_off_to, _rate_off * dt)
	_y_on = move_toward(_y_on, _y_on_to, _rate_on * dt)
	return {"off": _y_off, "on": _y_on}


## Take the next background as it is, without easing (the proof frames,
## which jump from place to place).
func settle_background() -> void:
	_eased = false


## Set the lights for this frame (dive.gd, once per frame); returns them
## in linear light.
func update(lamp: Node3D, lamp_lit: bool, energy: float, depth: float,
		clearance: float, dt: float) -> Dictionary:
	weight = fade(weight, lamp_lit, dt)
	var y := track_background(depth, clearance, dt)
	var l := lights(weight, lamp_lit, energy, y.off, y.on, depth)
	apply(lamp, l)
	return l


## Hand the lights and the lamp's place to the shaders.
static func apply(lamp: Node3D, l: Dictionary) -> void:
	var rim: Vector3 = l.rim
	var hl: Vector3 = l.lamp
	var at := lamp.global_position
	var ahead := -lamp.global_basis.z.normalized()
	RenderingServer.global_shader_parameter_set(G_RIM,
		Vector4(rim.x, rim.y, rim.z, l.presence))
	RenderingServer.global_shader_parameter_set(G_LAMP,
		Vector4(hl.x, hl.y, hl.z, 1.0 / LAMP_RANGE_M))
	RenderingServer.global_shader_parameter_set(G_LAMP_POS,
		Vector4(at.x, at.y, at.z, cos(deg_to_rad(LAMP_ANGLE_DEG))))
	RenderingServer.global_shader_parameter_set(G_LAMP_DIR,
		Vector4(ahead.x, ahead.y, ahead.z,
		1.0 / lamp_falloff(DiveCore.VIEW_M, 0.0)))


func _shader(key: String, code: String) -> Shader:
	if not shaders.has(key):
		var s := Shader.new()
		s.code = code
		shaders[key] = s
	return shaders[key]


func _beam_glsl() -> String:
	return _BEAM_GLSL % ["%.1f" % BEAM_CAP]


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
			alpha, "%.4f" % RIM_WIDTH, "%.2f" % RIM_WIDTH_MAX,
			"%.2f" % GRAZE])
		sm.set_shader_parameter("albedo", m.albedo_color)
		sm.set_shader_parameter("roughness", m.roughness)
		sm.set_shader_parameter("metallic", m.metallic)
		sm.set_shader_parameter("specular", m.metallic_specular)
		materials[key] = sm
	dressed += 1
	return materials[key]


## The transform from a node to one of its ancestors (the tree is not
## needed: a thing can be dressed before it enters the scene).
static func _to_ancestor(g: Node, root: Node) -> Transform3D:
	var x := Transform3D.IDENTITY
	var n: Node = g
	while n != root and n != null:
		if n is Node3D:
			x = (n as Node3D).transform * x
		n = n.get_parent()
	return x


## The thing's box in its root's space: all its meshes together, so the
## band runs on the outline of the whole thing, not of each part.
static func thing_box(node: Node) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [node]
	while not stack.is_empty():
		var g: Node = stack.pop_back()
		stack.append_array(g.get_children())
		if g is MeshInstance3D and g.mesh != null:
			var b: AABB = _to_ancestor(g, node) * g.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box


## The box of a thing in the space of one of its meshes, as the shader
## reads it: {c, x, y, z}.
static func box_in(space: Transform3D, box: AABB) -> Dictionary:
	var inv := space.affine_inverse()
	var h := box.size * 0.5
	return {"c": inv * (box.position + h),
		"x": inv.basis * Vector3(h.x, 0.0, 0.0),
		"y": inv.basis * Vector3(0.0, h.y, 0.0),
		"z": inv.basis * Vector3(0.0, 0.0, h.z)}


static func _set_box(g: GeometryInstance3D, b: Dictionary) -> void:
	for k in ["c", "x", "y", "z"]:
		g.set_instance_shader_parameter("rim_" + k, b[k])


## Give every mesh under `node` the band, unless the thing is holy, and
## hand each the thing's box.  A MultiMesh (a school of fish) gets its
## mesh's own box: each fish carries it.  Returns how many materials
## were replaced.
func dress(node: Node, holy := false) -> int:
	if holy or not enabled:
		return 0
	var box := thing_box(node)
	var n := 0
	var stack: Array = [node]
	while not stack.is_empty():
		var g: Node = stack.pop_back()
		stack.append_array(g.get_children())
		var changed := false
		if g is GeometryInstance3D and g.material_override != null:
			var r := material_for(g.material_override)
			if r != g.material_override:
				g.material_override = r
				n += 1
				changed = true
		elif g is MeshInstance3D and g.mesh != null:
			for i in g.mesh.get_surface_count():
				var base: Material = g.get_active_material(i)
				var r := material_for(base)
				if r != base:
					g.set_surface_override_material(i, r)
					n += 1
					changed = true
		if not changed:
			continue
		if g is MultiMeshInstance3D:
			_set_box(g, box_in(Transform3D.IDENTITY,
				(g as MultiMeshInstance3D).multimesh.mesh.get_aabb()))
		else:
			_set_box(g, box_in(_to_ancestor(g, node), box))
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
