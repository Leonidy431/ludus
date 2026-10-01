## The fish of Issyk-Kul in our own drawing (DEF-056,
## scripts/raw_assets/fish_procedural.py) as billboards in the dive.
##
## Only the species whose kit reached 12 honest variants are drawn
## (godot/data/fish-drawings.json, written by the generator); the rest
## keep the 3D spindle of dive.gd.  A school stays one MultiMesh with one
## material, so it is one draw call as before (TABOO 0.011: the dive's
## 255 must not grow): its 12 variants sit in one atlas, and each fish
## picks its cell from the instance's custom data.  The schools move as
## before (DiveCore.fish_at) in the species' real depth band, and each
## billboard is sized so that its biggest fish has the real length of
## the species, the young the length of their class.  Which cell a fish
## shows, from which side and whether it lies on the floor is spot()
## below.  The game turns the drawing to the way the fish swims; no
## variant is a mirror (TABOO 0.3 rule 35).  The lamp's band on the
## edge is the rule of the shore's own drawings (RimLight.drawing).
##
## Constitution: FORM (a real species in its real states, length and
## depth) -> ACTION (the operator tells it apart through the camera)
## -> GOAL (knowing the living lake by its real creatures).
class_name FishDrawings
extends RefCounted

const INDEX := "res://data/fish-drawings.json"
const ART := "res://art/derived/"

## The billboard and its light.  INSTANCE_CUSTOM is (column + 8 for a
## view from below or above, row, cos heading, sin heading).  A side view
## turns to the eye about the vertical, as the shore's drawings, and is
## turned (not mirrored) when the fish swims to the eye's right.  A view
## from below or above is drawn for a steep eye (FishDrawings.view), so
## it faces the eye fully, its snout along the fish's heading.
## The normal is the card's own, unscaled, tilted half way to the world's
## up: the drawing carries its own relief, so the card takes the lamp
## that faces it and the sun from above whichever way the eye turns.  In
## r3 the normal faced the eye only, and a card whose eye looked away
## from the sun took ambient light alone: two fish of the proof frame
## came out navy-black beside silver ones (review of r3).
const _GLSL := """
shader_type spatial;
render_mode cull_disabled;
%s
uniform sampler2D drawing : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 cells = vec2(4.0, 3.0);
uniform float band_uv = %s;
varying flat vec2 cell;
varying flat float flip;

void vertex() {
	%s
	float top = step(7.5, INSTANCE_CUSTOM.x);
	cell = vec2(INSTANCE_CUSTOM.x - 8.0 * top, INSTANCE_CUSTOM.y);
	vec3 heading = vec3(INSTANCE_CUSTOM.z, 0.0, INSTANCE_CUSTOM.w);
	vec3 right;
	vec3 up;
	vec3 face;
	if (top > 0.5) {
		face = normalize(MAIN_CAM_INV_VIEW_MATRIX[3].xyz
			- MODEL_MATRIX[3].xyz);
		vec3 along = heading - dot(heading, face) * face;
		// The drawing's snout is at its left edge: right is astern.
		right = -normalize(along + vec3(0.0, 1e-4, 0.0));
		up = normalize(cross(face, right));
		flip = 0.0;
	} else {
		right = normalize(cross(vec3(0.0, 1.0, 0.0),
			MAIN_CAM_INV_VIEW_MATRIX[2].xyz));
		up = vec3(0.0, 1.0, 0.0);
		face = normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz, up));
		// The drawing faces left; a fish swimming to the eye's right
		// is turned by the game, not drawn mirrored.
		flip = dot(heading, right) > 0.0 ? 1.0 : 0.0;
	}
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * s, 0.0),
		vec4(up * s, 0.0), vec4(face * s, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX);
	NORMAL = normalize(face + vec3(0.0, 1.0, 0.0));
}

vec2 at(vec2 uv) {
	return (cell + clamp(uv, vec2(0.0), vec2(1.0))) / cells;
}

// A drawing is matte and carries its own relief, so it takes the light
// that reaches its place half-Lambert: a card turned from a light still
// takes half of it, as the far side of a fish's body would show it.
void light() {
	DIFFUSE_LIGHT += (0.5 + 0.5 * dot(NORMAL, LIGHT)) * ATTENUATION
		* LIGHT_COLOR / PI;
}

void fragment() {
	vec2 uv = vec2(mix(UV.x, 1.0 - UV.x, flip), UV.y);
	vec4 c = texture(drawing, at(uv));
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
	%s
}
"""

const _BAND := """
	float m = min(
		min(texture(drawing, at(uv + vec2(band_uv, 0.0))).a,
			texture(drawing, at(uv - vec2(band_uv, 0.0))).a),
		min(texture(drawing, at(uv + vec2(0.0, band_uv))).a,
			texture(drawing, at(uv - vec2(0.0, band_uv))).a));
	EMISSION = band_light * (1.0 - m);
"""

## The rule of what a fish shows, the same as fishSpot in
## public/ludus/dive/dive-atlas.js (tests/fixtures replay it):
##  - every PERIOD_S a fish takes the next cell of its queue, so over
##    time every cell of the kit is shown; neighbours in a school are one
##    step apart in the same queue and never repeat (TABOO 0.3 rule 53);
##  - a view from below or above only when the eye sees the fish more
##    than PITCH_DEG from level, the side views otherwise;
##  - a fish of a kit with a "bottom" cell rests one slot in REST_EVERY:
##    it stops, sinks to the floor under it, lies with the lowest pixel
##    of its drawing on the floor line, then rises and swims on from
##    where it stopped; beyond REST_REACH_M it only holds station;
##  - the young are drawn at the length of their age class.
const PERIOD_S := 12.0
const PITCH_DEG := 35.0
const REST_EVERY := 3
## A 35 cm osman dives 8 m in the 3.6 s of SETTLE: about 2 m/s.
const REST_REACH_M := 8.0
const SETTLE := 0.3
## The "bottom" cell is shown only when the fish is all but down.
const REST_SHOWN := 0.95
const VARIANTS := 12

## Shaders by "rim on/off"; one per process, as the RimLight's.
static var _shaders := {}


## The index of shipped kits; empty when nothing reached 12/12.
static func load_index() -> Dictionary:
	if not FileAccess.file_exists(INDEX):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	return parsed if parsed is Dictionary else {}


## The kit of one species, or {} when the species keeps its 3D fish.
static func kit_of(index: Dictionary, species: String) -> Dictionary:
	for kit in index.get("kits", []):
		if kit.id == species:
			return kit
	return {}


## The cells of a kit by how the game shows them.
static func queues(kit: Dictionary) -> Dictionary:
	var q := {"side": [], "below": [], "above": [], "rest": []}
	for v in kit.files.size():
		q["rest" if kit.rest[v] else str(kit.views[v])].append(v)
	return q


## Where in the queues a school starts: fixed by its id.
static func seed_of(school: Dictionary) -> int:
	return floori(DiveCore.rng("cells:" + str(school.id)).call()
		* VARIANTS)


## "below" (the eye looks up), "above" or "side"; eye is {x, depth, z}
## or empty.
static func view(eye: Dictionary, p: Dictionary) -> String:
	return _view(eye, p.x, p.z, p.depth)


static func _view(eye: Dictionary, x: float, z: float,
		depth: float) -> String:
	if eye.is_empty():
		return "side"
	var up: float = eye.depth - depth
	var flat := Vector2(x - eye.x, z - eye.z).length()
	var deg := rad_to_deg(atan2(up, flat))
	if deg > PITCH_DEG:
		return "below"
	return "above" if deg < -PITCH_DEG else "side"


static func _smooth(a: float, b: float, x: float) -> float:
	var k := clampf((x - a) / (b - a), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## How far a resting fish has settled (0 swimming, 1 on the floor).
static func settle(s: float) -> float:
	return _smooth(0.0, SETTLE, s) * (1.0 - _smooth(1.0 - SETTLE, 1.0, s))


## Edge of the billboard in metres: the biggest fish of the drawing has
## the species' real length, times the age of the variant.
static func quad_m(index: Dictionary, kit: Dictionary, v: int,
		length_m: float) -> float:
	return length_m * float(index.canvas_px) / float(kit.fish_px[v]) \
		* float(kit.age[v])


## Fish i of a school at time t, seen from eye: the cell it shows, its
## size and where it is.
static func spot(index: Dictionary, kit: Dictionary, school: Dictionary,
		i: int, t: float, eye: Dictionary,
		q: Dictionary = {}, seed: int = -1) -> Dictionary:
	if q.is_empty():
		q = queues(kit)
	if seed < 0:
		seed = seed_of(school)
	var rests: Array = q.rest
	var k := floori(t / PERIOD_S)
	var c := i + k + seed
	var resting := rests.size() > 0 and c % REST_EVERY == 0
	var tau := t
	if rests.size() > 0:
		# The swim clock stops while the fish rests, so it rises where
		# it sank and swims on without a jump.
		var j0 := posmod(-(i + seed), REST_EVERY)
		var done := floori(float(k - 1 - j0) / REST_EVERY) + 1 \
			if k > j0 else 0
		tau = t - PERIOD_S * done \
			- ((t - k * PERIOD_S) if resting else 0.0)
	var p := DiveCore.fish_at(school, i, tau)
	var e := 0.0
	var floor_d: float = p.depth
	if resting:
		floor_d = DiveCore.floor_depth(p.x, p.z)
		if floor_d > p.depth and floor_d - p.depth <= REST_REACH_M:
			e = settle((t - k * PERIOD_S) / PERIOD_S)
	var near: float = p.depth + (floor_d - p.depth) * e
	var seen := _view(eye, p.x, p.z, near)
	var v: int
	if seen != "side" and (q[seen] as Array).size() > 0:
		v = q[seen][c % (q[seen] as Array).size()]
	elif e >= REST_SHOWN:
		v = rests[floori(float(c) / REST_EVERY) % rests.size()]
	else:
		v = q.side[c % (q.side as Array).size()]
	var size := quad_m(index, kit, v, float(school.length))
	# On the floor the lowest pixel of the drawing lies on the floor.
	var lie: float = floor_d - (float(kit.foot[v]) - 0.5) * size
	return {"id": school.id, "i": i, "v": v,
		"file": str(kit.files[v]).get_file(), "size": size,
		"top": str(kit.views[v]) != "side", "x": p.x, "z": p.z,
		"depth": p.depth + (lie - p.depth) * e, "heading": p.heading}


## Every fish of a school at t, seen from eye: the one choice the
## headset and the web share (tests/fixtures, test_atlas.gd).
static func school_spots(index: Dictionary, kit: Dictionary,
		school: Dictionary, t: float = 0.0, eye: Dictionary = {}) -> Array:
	var q := queues(kit)
	var seed := seed_of(school)
	var out := []
	for i in int(school.count):
		out.append(spot(index, kit, school, i, t, eye, q, seed))
	return out


static func _material(index: Dictionary, kit: Dictionary,
		rim: RimLight) -> ShaderMaterial:
	var key := "on" if rim.enabled else "off"
	if not _shaders.has(key):
		var sh := Shader.new()
		if rim.enabled:
			sh.code = _GLSL % [rim._beam_glsl(),
				"%.6f" % (RimLight.DRAWING_BAND / float(index.cols)),
				"band_light = lamp_light(MODEL_MATRIX[3].xyz);", _BAND]
		else:
			sh.code = _GLSL % ["", "0.0", "", ""]
		_shaders[key] = sh
	var sm := ShaderMaterial.new()
	sm.shader = _shaders[key]
	sm.set_shader_parameter("drawing", load(ART + kit.atlas) as Texture2D)
	sm.set_shader_parameter("cells", Vector2(index.cols, index.rows))
	return sm


## One school as one MultiMesh of billboards.
static func build(index: Dictionary, kit: Dictionary, school: Dictionary,
		rim: RimLight) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = int(school.count)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _material(index, kit, rim)
	# A flat card casts a card's shadow; the spindle it replaces cast
	# none worth a pass either.
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.set_meta("fish_drawing", kit.id)
	return inst


## Move a school's billboards to where the rule puts its fish at t,
## seen from eye ({x, depth, z} of the camera).
static func update(index: Dictionary, kit: Dictionary, school: Dictionary,
		mm: MultiMesh, t: float, eye: Dictionary = {}) -> void:
	var cols := int(index.cols)
	# The queues and the seed of a school do not change: worked out
	# once, not for every fish of every frame.
	if not school.has("_fish_q"):
		school["_fish_q"] = queues(kit)
		school["_fish_seed"] = seed_of(school)
	for i in int(school.count):
		var p := spot(index, kit, school, i, t, eye, school._fish_q,
			school._fish_seed)
		var v: int = p.v
		mm.set_instance_transform(i, Transform3D(Basis().scaled(
			Vector3.ONE * float(p.size)), Vector3(p.x, -p.depth, p.z)))
		# The heading as dive.gd turns its 3D fish: Basis(UP, -heading)
		# carries +x to (cos, 0, sin).  A view from below or above is
		# flagged by +8 on the column.
		mm.set_instance_custom_data(i, Color(
			v % cols + (8.0 if p.top else 0.0), floori(float(v) / cols),
			cos(p.heading), sin(p.heading)))
