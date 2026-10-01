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
## the species.  The game turns the drawing to the way the fish swims;
## no variant is a mirror (TABOO 0.3 rule 35).  Lit by the rule of the
## shore's own drawings (RimLight.drawing): the lamp's band on the edge.
##
## Constitution: FORM (a real species in its real states, length and
## depth) -> ACTION (the operator tells it apart through the camera)
## -> GOAL (knowing the living lake by its real creatures).
class_name FishDrawings
extends RefCounted

const INDEX := "res://data/fish-drawings.json"
const ART := "res://art/derived/"

## The billboard turned to the eye about the vertical (as the shore's
## drawings), sized by the instance, its atlas cell and facing taken
## from INSTANCE_CUSTOM: (column, row, cos heading, sin heading).
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
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0),
		MAIN_CAM_INV_VIEW_MATRIX[2].xyz));
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right * s, 0.0),
		vec4(0.0, s, 0.0, 0.0),
		vec4(normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz,
			vec3(0.0, 1.0, 0.0))) * s, 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	cell = INSTANCE_CUSTOM.xy;
	// The drawing faces left; a fish swimming to the eye's right is
	// turned by the game, not drawn mirrored.
	vec3 heading = vec3(INSTANCE_CUSTOM.z, 0.0, INSTANCE_CUSTOM.w);
	flip = dot(heading, right) > 0.0 ? 1.0 : 0.0;
}

vec2 at(vec2 uv) {
	return (cell + clamp(uv, vec2(0.0), vec2(1.0))) / cells;
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


## Which of the 12 variants fish i of a school shows: a fixed queue, so
## no two neighbours in a school repeat (TABOO 0.3 rule 53).
static func variant(i: int) -> int:
	return i % 12


## Edge of the billboard in metres: the biggest fish of the drawing has
## the species' real length.
static func quad_m(index: Dictionary, kit: Dictionary, v: int,
		length_m: float) -> float:
	return length_m * float(index.canvas_px) / float(kit.fish_px[v])


## What each fish of a school shows and how big it is drawn: the one
## choice the headset and the web share (tests/fixtures, test_atlas.gd).
static func school_spots(index: Dictionary, kit: Dictionary,
		school: Dictionary) -> Array:
	var out := []
	for i in int(school.count):
		var v := variant(i)
		out.append({"file": kit.files[v].get_file(),
			"size": quad_m(index, kit, v, float(school.length))})
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
	var cols := int(index.cols)
	for i in mm.instance_count:
		var v := variant(i)
		mm.set_instance_custom_data(i, Color(v % cols, floori(float(v) / cols), 1.0, 0.0))
	return inst


## Move a school's billboards to where DiveCore puts its fish at t.
static func update(index: Dictionary, kit: Dictionary, school: Dictionary,
		mm: MultiMesh, t: float) -> void:
	var cols := int(index.cols)
	for i in int(school.count):
		var p := DiveCore.fish_at(school, i, t)
		var v := variant(i)
		var s := quad_m(index, kit, v, float(school.length))
		mm.set_instance_transform(i, Transform3D(Basis().scaled(
			Vector3.ONE * s), Vector3(p.x, -p.depth, p.z)))
		# The heading as dive.gd turns its 3D fish: Basis(UP, -heading)
		# carries +x to (cos, 0, sin).
		mm.set_instance_custom_data(i, Color(v % cols, floori(float(v) / cols),
			cos(p.heading), sin(p.heading)))
