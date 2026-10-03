## The dive scene: the ROV goes down the Issyk-Kul shore.
##
## Everything the player sees is built here from data, so the scene is
## deterministic and reviewable in a diff (docs/HLD_HEADSET_BUILD_*).
## The rules come from DiveCore (a port of public/ludus/dive/
## dive-core.js); this script only draws them and reads the controls.
##
## World axes: x is the distance from the shore (m), y is minus the
## depth (m), z runs along the shore.
extends Node3D

const THERMO_Y := -DiveCore.THERMOCLINE_M
# Instrument light, 6500 K; the lamp's numbers live in RimLight, where
# the readability test reads them too.
const LAMP_COLOUR := RimLight.LAMP_COLOUR
const FLOW_SHAPES := ["current", "eddy", "intwave", "plume", "langmuir",
	"upwelling", "layer", "cloud"]
const ZONE_SHAPES := ["ripples", "gravel", "silt", "meadow", "swarm",
	"fuzz", "shells", "particles", "cloud", "light", "bubbles", "sherds"]
const REACH_M := 4.0
## A flat battery: the player watches the vehicle start up on the
## tether this long, then the black comes in and the slipway follows
## (TABOO 0.017: a quiet return, no death screen).  The rise itself
## stays under 10 m/min in DiveCore; only the watching is cut short.
const RECOVERY_WATCH_SEC := 14.0

var rov := DiveCore.new_rov()
var placed: Array = []
var schools: Array = []
var bag := {"kept": [], "released": [], "handed_over": []}
var game := DiveCore.new_game()
var messages: Array = []
# Sound (scripts/audio): water, breath, sonar and its echo after the
# real 2 * range / c, the ison and the shore bell, spatial water and
# haptics.  This scene only calls its hooks.
var audio: DiveAudio
var t := 0.0
var xr_active := false
var mouse_look := false
var pitch := 0.0
var message := ""
var message_left := 0.0

var env: Environment
var sun: DirectionalLight3D
var rig: Node3D
var camera: Camera3D
var lamp: SpotLight3D
var hud_label: Label
var hud_prompt: Label
var xr_label: Label3D
var xr_prompt: Label3D
# The pilot's console (CockpitPanel in a SubViewport): on the screen a
# strip at the bottom, in the headset a panel under the gaze.
const CONSOLE_PX := Vector2i(1256, 124)
var console_view: SubViewport
var console: CockpitPanel
var console_screen: TextureRect
var console_xr: MeshInstance3D
var console_alpha := 1.0
# Holy things on the lake floor (the bulla bears a cross): near them the
# console goes out (TABOO 0.4 rule 2).
var holy_points: Array = []
# The Water Atlas (TABOO 0.03): the knight's traces on the lake floor,
# placed by the chronicle's choice written in the hub (AtlasTraces).
var atlas_data: Dictionary = AtlasCore.load_data()
var chronicle := ""
var traces: Array = []
# The thing a story's step sent the ROV down for (StoryRoute.dive_target):
# named in the task line; the step closes back in the courtyard.
var story_target := {}
# The Mangustik's body (godot/models/rov/mangustik.glb, the operator's
# drawings).  Third person: the camera rides behind and above it, as a
# chase camera; first person: the camera is the ROV's own eye and the
# body is hidden.  V on the keyboard, Y on the left controller.
# A little to the right of the stern, over the shoulder: straight
# behind, the tether from the shore ran through the middle of the view.
const CHASE := Vector3(0.45, 0.85, 2.6)
const CHASE_PITCH := -0.22
const CHASE_YAW := 0.17
var body: RovBody
# The console's second screen (M8): the front camera's picture, the
# sonar and the posoh hydrophone (HLD_POSOH_HYDROPHONE), in its own
# viewport so screen and headset share it.
const SCREENS_PX := Vector2i(724, 196)
const SONAR_HZ := 10.0
var screens_view: SubViewport
var screens: CockpitScreens
var screens_screen: TextureRect
var screens_xr: MeshInstance3D
var eye_view: SubViewport
var eye: Camera3D
var sonar_left := 0.0
# The hydrophone card refreshes as the posoh firmware reports: every
# PosohCore.REPORT_S seconds.
var hydro_left := 0.0
var third_person := true
var view_was := false
# The manipulator reached out this frame: the tether task needs it.
var arm_now := false
# Seconds left to watch the recovery; negative while the battery lives.
var recovery_left := -1.0
var recovery_sent := false
var left_hand: XRController3D
var right_hand: XRController3D
var fish_meshes: Array = []
## The kits of our own fish drawing (godot/data/fish-drawings.json).
var fish_index := {}
var flow_mesh: ImmediateMesh
var tether_mesh: ImmediateMesh
var webxr: XRInterface
var vr_button: Button
var snap_ready := true
var interact_was := false
var lamp_was := false
# Proof frames for CI and review: --shots=<dir> renders fixed depths.
var shots_dir := ""
var shot_plan := [3.0, 12.0, 35.0, 60.0, 120.0]
var shot_frame := 0
# After the plan, one close look at the hydrophone on the body.
var shot_closeup := false
# The five biomes (HLD_DIVE_BIOMES_BUBBLES): the one the ROV is in now.
var biome := ""
var thermo_mat: ShaderMaterial
# Bubble columns: seeps and bubble streams of the lake, and the
# Mangustik's vent; one MultiMesh for all of them.
const BUBBLE_DRAW := 4.0
const BUBBLE_NEAR_M := 60.0
var columns: Array = []
var vent: Dictionary = {}
var bubble_mm: MultiMesh
var bubble_inst: MultiMeshInstance3D
# Reading things against the water (operator 2026-09-30): the lamp's
# highlight while it shines, the rim light without it; holy things get
# neither.  Made before any material, as it registers the shader globals.
var rim := RimLight.new()
## The node of every lake object and trace built, by id: the test walks
## them to see that no holy thing carries the band.
var thing_nodes := {}
# Proof frames show the settled light, not a fade caught half way.
var rim_settled := false
var rim_us := 0.0
var rim_frames := 0
var drawings := 0
# The D6 drawings as built, for DiveBatch.merge_drawings.
var own_sprites: Array = []
# Б-1: what the batches took (DiveBatch), for the report and the tests.
var batch_stats := {}
# Б-1: the cockpit's viewports take turns (_turn_viewports).
var view_turn := 0
# The cockpit viewports set to draw in the coming frame, so that a
# measurement can tell which of them the frame's draw calls hold.
var drawn_views: Array = []
var batch_off := false
# GPU and CPU render time with the bubbles hidden and shown (shots).
var gpu_ms := {"off": [], "on": []}
# Rough cost of the bubbles, microseconds of CPU per frame (shots only).
var bubble_us := 0.0
var bubble_frames := 0


func _ready() -> void:
	var lake: Dictionary = _load_json("res://data/lake-objects-99.json")
	var fish: Dictionary = _load_json("res://data/issyk-kul-fish.json")
	placed = DiveCore.place_objects(lake.objects)
	var lake_by_id := {}
	for o in lake.objects:
		lake_by_id[o.id] = o
	story_target = StoryRoute.dive_target(StoryRoute.load_data(),
		lake_by_id)
	schools = DiveCore.fish_schools(fish.fish)
	_load_bag()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
		# The same frames without the band, for before/after and cost.
		if arg == "--rim=off":
			rim.enabled = false
		# The scene as drawn before Б-1's batches, for before/after.
		if arg == "--batch=off":
			batch_off = true
	chronicle = _load_chronicle()
	traces = AtlasTraces.place(atlas_data, chronicle)
	holy_points.append_array(AtlasTraces.holy_points(traces))
	_build_environment()
	_build_floor()
	_build_surface()
	_build_thermocline()
	_build_objects()
	_build_stones()
	_build_traces()
	_build_own_drawings()
	_build_fish()
	_build_lines()
	_build_snow()
	_build_bubbles()
	_build_rig()
	_build_body()
	_batch()
	_build_hud()
	_start_xr()
	_build_audio()
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)


func _load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# --- World ------------------------------------------------------------------

## Colour of the water around the ROV: surface light scattered by clear
## water and dimmed band by band (Beer-Lambert, ludus-water.js).
func water_colour(depth: float) -> Color:
	var w := DiveCore.water_colour(depth)
	return Color(w[0], w[1], w[2])


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-75, 20, 0)
	add_child(sun)


## Sand in the shallows, gravel on the shelf, silt in the deep.
func _floor_colour(depth: float) -> Color:
	var sand := Color(0.78, 0.72, 0.56)
	var gravel := Color(0.58, 0.55, 0.5)
	var silt := Color(0.33, 0.31, 0.28)
	if depth < 30.0:
		return sand.lerp(gravel, depth / 30.0)
	return gravel.lerp(silt, clampf((depth - 30.0) / 90.0, 0.0, 1.0))


func _build_floor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 5.0
	var nx := int(DiveCore.LENGTH_M / step)
	var nz := int(DiveCore.HALF_WIDTH_M * 2.0 / step)
	for i in nx:
		for j in nz:
			var x0 := i * step
			var z0 := -DiveCore.HALF_WIDTH_M + j * step
			var quad := [Vector2(x0, z0), Vector2(x0 + step, z0),
				Vector2(x0 + step, z0 + step), Vector2(x0, z0 + step)]
			for k in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = quad[k]
				var d := DiveCore.floor_depth(p.x, p.y)
				# Ripple banding: light and shade across the sand, so
				# the floor reads as a surface and not a flat fill.
				var band := 0.92 + 0.08 * sin(p.x * 0.9 + p.y * 0.3)
				st.set_color(_floor_colour(d) * band)
				st.add_vertex(Vector3(p.x, -d, p.y))
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	# Both faces: the first web frame showed water through the floor.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = mat
	add_child(mesh)


func _build_surface() -> void:
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(DiveCore.LENGTH_M * 4.0, DiveCore.LENGTH_M * 2.0)
	plane.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Under fog like everything else: from the deep the surface fades
	# out instead of hanging as a bright sheet (first eye check).
	mat.albedo_color = Color(0.75, 0.92, 0.95, 0.55)
	plane.material_override = mat
	plane.position = Vector3(DiveCore.LENGTH_M / 2.0, 0.0, 0.0)
	add_child(plane)


## The thermocline is a boundary one can see: two shimmering sheets
## the thickness of the layer apart, refraction bands drifting on them
## (the temperature step bends light as it bends sound).  The sheets
## brighten while the ROV is inside the band, so the crossing is seen
## together with its sound and pulse (TABOO 0.35 rules 17, 19).
const THERMO_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 tint : source_color = vec4(0.72, 0.85, 0.9, 0.1);
uniform float strength = 1.0;
uniform float clock = 0.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float warp = sin(wp.z * 0.21 + clock * 0.4) * 1.7;
	float band = 0.5 + 0.5 * sin(wp.x * 0.35 + warp + clock * 0.25);
	float fine = 0.5 + 0.5 * sin(wp.x * 1.3 - wp.z * 0.9 + clock * 0.9);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * strength * (0.35 + 0.45 * band + 0.2 * fine);
}
"""


func _build_thermocline() -> void:
	var shader := Shader.new()
	shader.code = THERMO_SHADER
	thermo_mat = ShaderMaterial.new()
	thermo_mat.shader = shader
	for dy in [-DiveCore.THERMO_BAND_M * 0.5, DiveCore.THERMO_BAND_M * 0.5]:
		var sheet := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(DiveCore.LENGTH_M, DiveCore.HALF_WIDTH_M * 2.0)
		sheet.mesh = pm
		sheet.material_override = thermo_mat
		sheet.position = Vector3(DiveCore.LENGTH_M / 2.0 + 150.0,
			THERMO_Y + dy, 0.0)
		add_child(sheet)


## The sheets shimmer with the scene clock; inside the band they are
## twice as strong.  Reduced motion stills the bands.
func _update_thermocline(depth: float) -> void:
	var inside := absf(depth - DiveCore.THERMOCLINE_M) \
		<= DiveCore.THERMO_BAND_M
	thermo_mat.set_shader_parameter("strength", 2.0 if inside else 1.0)
	thermo_mat.set_shader_parameter("clock",
		0.0 if audio.reduced_motion else t)


func _build_objects() -> void:
	for p in placed:
		if p.where == "water" or p.shape in ZONE_SHAPES:
			# Water phenomena are flow lines, and flat fields (ripples,
			# silt, meadows) are the floor itself: their slab proxies
			# lay on the sand as huge pale wedges in the first frame.
			continue
		var node: Node3D
		if p.category == "bird":
			node = _blob(Color(p.colour), Vector3(0.45, 0.18, 0.2))
		else:
			var path := "res://models/lake/lake-%s.glb" % str(p.id).replace(
				".", "-")
			var scene: PackedScene = load(path) if ResourceLoader.exists(
				path) else null
			node = scene.instantiate() if scene else _blob(Color(p.colour),
				Vector3.ONE * maxf(0.3, p.size))
		node.position = Vector3(p.x, -p.depth, p.z)
		node.rotation.y = p.yaw
		add_child(node)
		thing_nodes[p.id] = node
		# The bulla bears a cross (holy in its data): no outline of light
		# on it, and the console falls silent there.
		rim.dress(node, RimLight.is_holy(p))
		if RimLight.is_holy(p):
			holy_points.append(node.position)


## Stones and pebbles that dress the floor of the dive corridor.  They
## are scenery, not lake objects: placed by seed, never loot.
## The knight's traces, drawn from simple shapes by their `shape` (own
## procedural drawing: the khachkar above all is never raw material,
## TABOO 0.35 rule 6).  Stone and iron only: no glow, no gold.
func _build_traces() -> void:
	for p in traces:
		var node := Node3D.new()
		node.position = Vector3(p.x, -p.depth, p.z)
		node.rotation.y = p.yaw
		if p.shape in ["khachkar", "spare", "vault"]:
			# A khachkar faces west, and on this shore west is up the
			# slope, where the ROV comes from; so does the passage.
			node.rotation.y = -PI / 2.0
		var c := Color(p.colour)
		# The five traces have their own models (scripts/meta3d,
		# godot/models/atlas); the primitives below stay as the fallback
		# and draw the passage, which has no model.
		var path := "res://models/atlas/atlas-%s.glb" % p.id
		if p.kind == "trace" and ResourceLoader.exists(path):
			node.add_child((load(path) as PackedScene).instantiate())
			add_child(node)
			thing_nodes[p.id] = node
			# The khachkar is holy: it keeps its plain stone.
			rim.dress(node, RimLight.is_holy(p))
			continue
		match p.shape:
			"book":
				_part(node, BoxMesh, Vector3(0.3, 0.08, 0.22),
					Vector3(0, 0.02, 0), c)
			"amphora":
				# Lying on its side, half in the silt.
				var a := _part(node, CylinderMesh, Vector3(0.22, 0.55, 0.22),
					Vector3(0, 0.08, 0), c)
				a.rotation.z = 1.4
				_part(node, SphereMesh, Vector3(0.3, 0.3, 0.3),
					Vector3(0.05, 0.08, 0), c)
			"astrolabe":
				var ring := _part(node, TorusMesh, Vector3(0.26, 0.26, 0.26),
					Vector3(0, 0.03, 0), c, 0.35, 0.8)
				ring.rotation.x = 0.25
				_part(node, BoxMesh, Vector3(0.24, 0.015, 0.03),
					Vector3(0, 0.04, 0), c.darkened(0.2), 0.4, 0.8)
			"shield":
				var disc := _part(node, CylinderMesh, Vector3(0.9, 0.05, 0.9),
					Vector3(0, 0.05, 0), c, 0.7, 0.6)
				disc.rotation.x = 0.3
				_part(node, SphereMesh, Vector3(0.18, 0.1, 0.18),
					Vector3(0, 0.14, -0.03), c.darkened(0.15), 0.6, 0.6)
			"khachkar":
				_khachkar(node, c)
			"spare":
				for dx in [-1.1, 1.1]:
					_part(node, BoxMesh, Vector3(0.5, 2.2, 0.6),
						Vector3(dx, 1.1, 0), c)
				_part(node, BoxMesh, Vector3(2.8, 0.45, 0.7),
					Vector3(0, 2.4, 0), c)
			"vault":
				var r := DiveCore.rng("atlas:rubble")
				for i in 9:
					var k := _part(node, BoxMesh, Vector3(0.5, 0.35, 0.45)
						* (0.7 + 0.6 * r.call()), Vector3((r.call() - 0.5)
						* 2.4, 0.15 + 0.2 * (i % 3), (r.call() - 0.5) * 1.6),
						c.darkened(0.1 * (i % 3)))
					k.rotation = Vector3(r.call(), r.call() * TAU, r.call())
		add_child(node)
		thing_nodes[p.id] = node
		rim.dress(node, RimLight.is_holy(p))


## A khachkar of our own drawing: an upright slab with a cross in low
## relief, its arms ending in split tips, and a rosette under it.  The
## same stone as the slab; it is seen by its shadows, not by a light.
func _khachkar(node: Node3D, stone: Color) -> void:
	_part(node, BoxMesh, Vector3(0.9, 1.6, 0.22), Vector3(0, 0.8, 0), stone)
	var relief := stone.lightened(0.15)
	var z := 0.14
	_part(node, BoxMesh, Vector3(0.1, 0.8, 0.07), Vector3(0, 1.0, z), relief)
	_part(node, BoxMesh, Vector3(0.56, 0.1, 0.07), Vector3(0, 1.15, z),
		relief)
	for tip in [Vector3(0, 1.42, z), Vector3(0, 0.58, z),
			Vector3(-0.3, 1.15, z), Vector3(0.3, 1.15, z)]:
		_part(node, BoxMesh, Vector3(0.12, 0.12, 0.07), tip, relief)
	var rose := _part(node, CylinderMesh, Vector3(0.22, 0.04, 0.22),
		Vector3(0, 0.3, z), relief)
	rose.rotation.x = PI / 2.0


func _part(parent: Node3D, kind, size: Vector3, at: Vector3, colour: Color,
		rough := 0.95, metal := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh: PrimitiveMesh = kind.new()
	if mesh is BoxMesh:
		mesh.size = size
	elif mesh is CylinderMesh:
		mesh.top_radius = size.x / 2.0
		mesh.bottom_radius = size.z / 2.0
		mesh.height = size.y
	elif mesh is SphereMesh:
		mesh.radius = 0.5
		mesh.height = 1.0
		m.scale = size
	elif mesh is TorusMesh:
		mesh.outer_radius = size.x / 2.0
		mesh.inner_radius = size.x / 2.0 - 0.025
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = rough
	mat.metallic = metal
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


## The neutral things of the shore drawn by our own generator (D6,
## scripts/raw_assets/neutral_procedural.py): each kit has 12 variants,
## laid out in a deterministic queue so no two neighbours repeat
## (TABOO 0.3 rule 53).  Real size in metres and the depth band where
## the thing lives on this shore; scenery only, never loot.
const OWN_DRAWINGS := [
	{"dir": "DEF-057", "kit": "own_boulder", "size": 0.9, "depth": [3.0, 25.0], "n": 24},
	{"dir": "DEF-057", "kit": "own_quartz", "size": 0.25, "depth": [0.5, 6.0], "n": 24},
	{"dir": "DEF-058", "kit": "own_trostnik", "size": 1.6, "depth": [0.3, 2.0], "n": 36},
	{"dir": "DEF-058", "kit": "own_rdest", "size": 0.9, "depth": [1.5, 8.0], "n": 30},
	{"dir": "DEF-059", "kit": "own_balka", "size": 1.8, "depth": [4.0, 18.0], "n": 12},
	{"dir": "DEF-059", "kit": "own_khum", "size": 0.8, "depth": [8.0, 22.0], "n": 8},
]


func _build_own_drawings() -> void:
	for kit in OWN_DRAWINGS:
		for spot in own_drawing_spots(kit):
			var sp := Sprite3D.new()
			sp.texture = load(spot.file) as Texture2D
			sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			# Lit like everything else under water: an unshaded sprite
			# kept its full colour at 140 m, against Beer-Lambert.
			sp.shaded = true
			sp.pixel_size = float(kit.size) / 256.0
			# The drawing stands on its lower edge, on the floor
			# (own_drawing_spots, shared with the web fixture).
			sp.position = Vector3(spot.x, -spot.y, spot.z)
			# Its material turns it to the eye, cuts its alpha and draws
			# the band on its edge (RimLight.drawing).
			rim.drawing(sp)
			drawings += 1
			add_child(sp)
			own_sprites.append(sp)


## Б-1 (docs/APK_REQUIREMENTS.md): the still parts are drawn in fewer
## calls (DiveBatch).  The body's model, its hydrophone and each link of
## the arm are baked within themselves; each lake object and trace keeps
## its own node, its box and its band, and only its own surfaces are
## joined, so the arm reaches it as before; a holy thing is not touched;
## the drawings of the shore are drawn from texture arrays.
func _batch() -> void:
	if batch_off:
		return
	batch_stats["body"] = DiveBatch.merge_body(body)
	var cache := {}
	var joined := 0
	for p in placed + traces:
		if thing_nodes.has(p.id) and not RimLight.is_holy(p):
			joined += DiveBatch.merge_thing(thing_nodes[p.id], rim, cache)
	batch_stats["thing_surfaces_joined"] = joined
	batch_stats["drawings_batched"] = DiveBatch.merge_drawings(own_sprites,
		rim)
	own_sprites = own_sprites.filter(func(s): return is_instance_valid(s))


## Б-1: the three cockpit viewports were drawn every frame (102 calls at
## 3 m on top of the view).  They take turns now, one a frame: the front
## camera, then the screens that show its picture, then the console.
## Each is drawn at a third of the frame rate (24 Hz in the headset at
## 72 Hz), and no frame carries more than one; the screens show the
## camera's picture of the frame before, as a monitor does.
func _turn_viewports() -> void:
	if batch_off:
		drawn_views = [eye_view, screens_view, console_view]
		for v in drawn_views:
			v.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	view_turn = (view_turn + 1) % 3
	var views: Array = [eye_view, screens_view, console_view]
	(views[view_turn] as SubViewport).render_target_update_mode = \
		SubViewport.UPDATE_ONCE
	drawn_views = [views[view_turn]]


## Where each drawing of one kit stands: the one placement the scene
## builds and test_atlas.gd checks against the web fixture, so the two
## cannot part.  y is the depth of the drawing's centre: it stands on
## its lower edge, on the floor.  Empty when the kit has no files.
static func own_drawing_spots(kit: Dictionary) -> Array:
	var out := []
	var files := _kit_files("res://art/derived/%s" % kit.dir, kit.kit)
	if files.is_empty():
		return out
	var r := DiveCore.rng("own:" + str(kit.kit))
	for i in int(kit.n):
		var d: float = lerpf(kit.depth[0], kit.depth[1], r.call())
		var z: float = (r.call() * 2.0 - 1.0) * DiveCore.CORRIDOR_M
		var x := DiveCore.x_for_depth(d)
		out.append({"x": x, "z": z,
			"y": DiveCore.floor_depth(x, z) - float(kit.size) * 0.45,
			"file": files[i % files.size()]})
	return out


## The kit's variant files, sorted; in an exported build the folder
## lists the ".import" stubs, so the suffix is dropped.
static func _kit_files(dir: String, kit: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		var name := f.trim_suffix(".import").trim_suffix(".remap")
		if name.begins_with(kit) and name.ends_with(".png") \
				and not dir.path_join(name) in out:
			out.append(dir.path_join(name))
	out.sort()
	return out


## After the depth frames: the knight's diary, the khachkar (the console
## gone, as it settles after FADE_SECONDS) and the passage of the
## chronicle, each from behind the body, the ROV 3 m short of it.
func _atlas_shots() -> void:
	var plan := ["diary", "khachkar", "passage"]
	# After the depth frames and the 20 frames of the hydrophone close-up.
	var k := (shot_frame - 40 * shot_plan.size() - 20) / 40
	if k >= plan.size():
		_biome_shots(k - plan.size())
		return
	var p := {}
	for tr in traces:
		if tr.id == plan[k]:
			p = tr
	if not third_person:
		third_person = true
		_place_view()
	var back: float = {"diary": 3.5, "khachkar": 2.6,
		"passage": 7.0}[plan[k]]
	# Coming down the slope from the shore, a little to one side so the
	# body does not hide the thing; the ROV hangs over its own floor.
	rov.x = p.x - back
	rov.z = p.z - 1.2
	rov.depth = DiveCore.floor_depth(rov.x, rov.z) - 1.2
	rov.yaw = 0.0
	pitch = -0.2
	var here := Vector3(rov.x, -rov.depth, rov.z)
	var nearest := INF
	for h in holy_points:
		nearest = minf(nearest, here.distance_to(h))
	console_alpha = CockpitCore.fade_target(nearest)
	if shot_frame % 40 == 39:
		get_viewport().get_texture().get_image().save_png(
			"%s/dive-atlas-%s.png" % [shots_dir, plan[k]])
	shot_frame += 1


func _build_stones() -> void:
	var r := DiveCore.rng("dive:stones")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var s := SphereMesh.new()
	s.radial_segments = 8
	s.rings = 4
	mm.mesh = s
	mm.instance_count = 900
	for i in mm.instance_count:
		var x: float = 5.0 + r.call() * (DiveCore.LENGTH_M - 10.0)
		var z: float = (r.call() * 2.0 - 1.0) * DiveCore.CORRIDOR_M * 1.6
		var d := DiveCore.floor_depth(x, z)
		# Boulders roll down the slope; the shallows keep small pebbles.
		var size: float = (0.08 + r.call() * 0.3) * (1.0 + minf(3.0, d / 40.0))
		var basis := Basis(Vector3.UP, r.call() * TAU).scaled(
			Vector3(size * (1.0 + r.call()), size * 0.6, size))
		mm.set_instance_transform(i, Transform3D(basis,
			Vector3(x, -d + size * 0.15, z)))
		var grey: float = 0.35 + r.call() * 0.3
		mm.set_instance_color(i, Color(grey, grey * 0.97, grey * 0.9))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	inst.material_override = mat
	add_child(inst)


func _blob(colour: Color, size: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	m.mesh = s
	m.scale = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	m.material_override = mat
	return m


## A fish of unit length along +x: a flattened spindle and a tail fork.
func _fish_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := 8
	var rows := [[0.5, 0.0], [0.35, 0.1], [0.1, 0.16], [-0.15, 0.13],
		[-0.35, 0.06], [-0.42, 0.02]]
	for r in rows.size() - 1:
		for k in ring:
			var a0 := TAU * k / ring
			var a1 := TAU * (k + 1) / ring
			var pts := []
			for rr in [r, r + 1]:
				for a in [a0, a1]:
					var rad: float = rows[rr][1]
					pts.append(Vector3(rows[rr][0], rad * sin(a),
						rad * 0.45 * cos(a)))
			for idx in [0, 2, 1, 1, 2, 3]:
				st.add_vertex(pts[idx])
	# Tail fork.
	for v in [Vector3(-0.4, 0, 0), Vector3(-0.62, 0.16, 0),
			Vector3(-0.55, 0, 0), Vector3(-0.4, 0, 0),
			Vector3(-0.55, 0, 0), Vector3(-0.62, -0.16, 0)]:
		st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _build_fish() -> void:
	var mesh := _fish_mesh()
	fish_index = FishDrawings.load_index()
	for s in schools:
		# Species with a 12/12 kit of our own drawing (DEF-056) swim as
		# billboards, one MultiMesh each, as the 3D school was.
		var kit := FishDrawings.kit_of(fish_index, str(s.id))
		if not kit.is_empty():
			var card := FishDrawings.build(fish_index, kit, s, rim)
			add_child(card)
			fish_meshes.append(card)
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = s.count
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(s.colour)
		mat.metallic = 0.3
		mat.roughness = 0.5
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		inst.material_override = mat
		# One material per school: the band costs nothing more here.
		rim.dress(inst)
		add_child(inst)
		fish_meshes.append(inst)


func _line_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _build_lines() -> void:
	flow_mesh = ImmediateMesh.new()
	var flows := MeshInstance3D.new()
	flows.mesh = flow_mesh
	flows.material_override = _line_material()
	add_child(flows)
	tether_mesh = ImmediateMesh.new()
	var tether := MeshInstance3D.new()
	tether.mesh = tether_mesh
	tether.material_override = _line_material()
	add_child(tether)


## Marine snow drifts down around the ROV wherever it goes.
func _build_snow() -> void:
	var snow := CPUParticles3D.new()
	snow.amount = 400
	snow.lifetime = 12.0
	snow.preprocess = 12.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(12, 8, 12)
	snow.direction = Vector3(0, -1, 0)
	snow.initial_velocity_min = 0.02
	snow.initial_velocity_max = 0.08
	snow.gravity = Vector3(0, -0.01, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.9, 0.95, 0.95, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = mat
	snow.mesh = q
	snow.name = "Snow"
	add_child(snow)


## Bubble columns (DEF-006, HLD_DIVE_BIOMES_BUBBLES): the bubble
## streams and the spring seep of the lake rise from their floor to the
## surface, the Mangustik's vent bleeds the air of its frame in the
## first 10.2 m.  They leave only on the exhale of the player's breath
## (DiveSynth.PLAYER_BREATH, hesychasm module), rise at 0.25 m/s and
## swell by Boyle's law.  Each instance is a small puff of bubbles,
## drawn BUBBLE_DRAW times the physical radius so it reads in the
## headset; the ratio between depths stays physical.
func _build_bubbles() -> void:
	var p: Dictionary = DiveSynth.BREATH[DiveSynth.PLAYER_BREATH]
	for o in placed:
		if o.item == "bubbles" or o.item == "spring":
			var bottom := DiveCore.floor_depth(o.x, o.z)
			columns.append(DiveCore.bubble_column(str(o.id), o.x, o.z,
				bottom, 0.0, 5 if o.item == "bubbles" else 2, p))
	vent = DiveCore.bubble_column("mangustik:vent", 0.0, 0.0, 2.0, 0.0,
		3, p)
	var total: int = vent.count
	for c in columns:
		total += c.count
	bubble_mm = MultiMesh.new()
	bubble_mm.transform_format = MultiMesh.TRANSFORM_3D
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 6
	s.rings = 3
	bubble_mm.mesh = s
	bubble_mm.instance_count = total
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.91, 0.96, 0.97, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	mat.metallic_specular = 0.9
	bubble_inst = MultiMeshInstance3D.new()
	bubble_inst.multimesh = bubble_mm
	bubble_inst.material_override = mat
	bubble_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bubble_inst)


func _update_bubbles() -> void:
	var t0 := Time.get_ticks_usec()
	var wobble := not audio.reduced_motion
	var here := Vector3(rov.x, -rov.depth, rov.z)
	var n := 0
	var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for c in columns:
		var near := Vector2(c.x - here.x, c.z - here.z).length() \
			< BUBBLE_NEAR_M
		if not near and not c.get("shown", true):
			# Far and already hidden: nothing to write this frame.
			n += int(c.count)
			continue
		c["shown"] = near
		for i in c.count:
			var q := DiveCore.bubble_at(c, i, t, wobble) if near else {}
			n = _put_bubble(n, q, Vector3.ZERO, hidden)
	# The vent rides on the ROV: its column is the 2 m above the body,
	# and it breathes only while the frame still holds air.
	var venting: bool = rov.depth < DiveCore.VENT_UNTIL_M
	# Born 0.3 m above the centre of the body, 2 m below the column top.
	var origin := here + Vector3(0.0, 0.3 + vent.bottom, 0.0)
	for i in vent.count:
		var q := DiveCore.bubble_at(vent, i, t, wobble) if venting else {}
		n = _put_bubble(n, q, origin, hidden)
	bubble_us += Time.get_ticks_usec() - t0
	bubble_frames += 1


func _put_bubble(n: int, q: Dictionary, origin: Vector3,
		hidden: Transform3D) -> int:
	if q.is_empty() or not q.visible:
		bubble_mm.set_instance_transform(n, hidden)
	else:
		var r: float = q.size * BUBBLE_DRAW
		bubble_mm.set_instance_transform(n, Transform3D(
			Basis.from_scale(Vector3(r, r * 0.8, r)),
			origin + Vector3(q.x, -q.depth, q.z)))
	return n + 1


## Proof frames of the five biomes, from behind the body: 40 frames
## each, the bubbles hidden for frames 10-24 and shown for 25-39 so the
## render time of both halves can be compared; the frame is saved last.
const BIOME_SHOTS := [
	{"name": "shallows", "depth": 9.0, "column": "bubbles.shelf.1"},
	{"name": "thermocline", "depth": 49.0},
	{"name": "deep", "depth": 80.0},
	{"name": "night", "depth": 140.0},
	{"name": "sediments", "depth": 90.0, "clearance": 1.0},
]


func _biome_shots(k: int) -> void:
	var f := shot_frame % 40
	if k >= BIOME_SHOTS.size():
		_rim_shots(k - BIOME_SHOTS.size())
		return
	var plan: Dictionary = BIOME_SHOTS[k]
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	if not third_person:
		third_person = true
		_place_view()
	rov.yaw = 0.0
	pitch = -0.1
	rov.z = 0.0
	if plan.has("column"):
		for c in columns:
			if c.id == plan.column:
				rov.x = c.x - 6.0
				rov.z = c.z
		rov.depth = plan.depth
	elif plan.has("clearance"):
		rov.x = DiveCore.x_for_depth(plan.depth)
		rov.depth = DiveCore.floor_depth(rov.x, 0.0) - plan.clearance
		pitch = -0.35
	else:
		# Out over deeper water, so the floor does not make it the
		# sediments.
		rov.x = DiveCore.x_for_depth(plan.depth + 30.0)
		rov.depth = plan.depth
	# The night of the deep: the lamp stays on, it is the only light.
	rov.lamp = true
	t = 30.0 + k
	bubble_inst.visible = f < 10 or f >= 25
	if f >= 12 and f < 25:
		gpu_ms.off.append(RenderingServer.viewport_get_measured_render_time_gpu(
			rid))
	elif f >= 27:
		gpu_ms.on.append(RenderingServer.viewport_get_measured_render_time_gpu(
			rid))
	if f == 39:
		print("biome shot %s: in %s at %.1f m; GPU ms hidden %.2f, shown %.2f"
			% [plan.name, biome, rov.depth, _mean(gpu_ms.off.slice(-13)),
			_mean(gpu_ms.on.slice(-13))])
		get_viewport().get_texture().get_image().save_png(
			"%s/dive-biome-%s.png" % [shots_dir, plan.name])
	shot_frame += 1


## Proof frames of the operator's decision on reading things (RimLight):
## the knight's shield in the night of the deep with the lamp off (the
## rim light) and on (its highlight), in first and third person; the
## khachkar with the lamp off and on and the bulla with the lamp off (no
## light on the holy); the passage of the chronicle and the diary with
## the lamp off and on.  In first person the lamp rides on the eye and
## looks where it looks.
const RIM_SHOTS := [
	{"name": "night-off", "trace": "shield", "lamp": false, "back": 3.0,
		"above": 3.0, "first": true},
	{"name": "night-on", "trace": "shield", "lamp": true, "back": 3.0,
		"above": 3.0, "first": true},
	{"name": "night-off-3p", "trace": "shield", "lamp": false, "back": 4.0,
		"above": 3.0, "first": false},
	{"name": "night-on-3p", "trace": "shield", "lamp": true, "back": 4.0,
		"above": 3.0, "first": false},
	{"name": "khachkar-off", "trace": "khachkar", "lamp": false, "back": 2.6,
		"above": 1.2, "first": false},
	{"name": "khachkar-on", "trace": "khachkar", "lamp": true, "back": 2.6,
		"above": 1.2, "first": false},
	{"name": "bulla-off", "thing": "bulla.shallows.0", "lamp": false,
		"back": 0.9, "above": 0.5, "first": true},
	{"name": "passage-off", "trace": "passage", "lamp": false, "back": 7.0,
		"above": 1.2, "first": false},
	{"name": "passage-on", "trace": "passage", "lamp": true, "back": 7.0,
		"above": 1.2, "first": false},
	{"name": "diary-off", "trace": "diary", "lamp": false, "back": 3.5,
		"above": 1.2, "first": false},
]
var rim_lights := {}


func _rim_shots(k: int) -> void:
	if k >= RIM_SHOTS.size():
		_report_costs()
		get_tree().quit()
		return
	var plan: Dictionary = RIM_SHOTS[k]
	rim_settled = true
	rov.lamp = plan.lamp
	if third_person == plan.first:
		third_person = not plan.first
		_place_view()
	var p := {}
	for tr in traces + placed:
		if tr.id == plan.get("trace", plan.get("thing")):
			p = tr
	rov.yaw = 0.0
	rov.x = p.x - plan.back
	rov.z = p.z - (0.0 if plan.first else 1.2)
	rov.depth = minf(DiveCore.floor_depth(rov.x, rov.z), p.depth) \
		- plan.above
	# In first person the eye (and the lamp on it) looks down at the
	# thing; from behind, the chase camera does.
	pitch = -atan2(plan.above, plan.back + RovBody.EYE.z) if plan.first \
		else -0.2
	t = 40.0 + k
	if shot_frame % 40 == 39:
		print("rim shot %s: in %s at %.1f m, lamp %s, rim %.3f, lamp %.3f"
			% [plan.name, biome, rov.depth, "on" if plan.lamp else "off",
			_y(rim_lights.get("rim", Vector3.ZERO)),
			_y(rim_lights.get("lamp", Vector3.ZERO))])
		get_viewport().get_texture().get_image().save_png(
			"%s/dive-rim-%s.png" % [shots_dir, plan.name])
	shot_frame += 1


## Luminance of a linear colour.
static func _y(c: Vector3) -> float:
	return 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z


static func _mean(a: Array) -> float:
	var sum := 0.0
	for v in a:
		sum += v
	return sum / maxf(1.0, a.size())


func _report_costs() -> void:
	print("bubbles: %d instances, %.1f us CPU per frame over %d frames"
		% [bubble_mm.instance_count, bubble_us / maxf(1.0, bubble_frames),
		bubble_frames])
	print("render GPU ms: bubbles hidden %.3f, shown %.3f (n=%d/%d)" % [
		_mean(gpu_ms.off), _mean(gpu_ms.on), gpu_ms.off.size(),
		gpu_ms.on.size()])
	print("rim: %d surfaces dressed with %d materials, %d kept as they "
		% [rim.dressed, rim.materials.size(), rim.kept]
		+ "were, %d drawings with %d materials, %d shaders; %.1f us CPU"
		% [drawings, rim.drawing_materials.size(), rim.shaders.size(),
		rim_us / maxf(1.0, rim_frames)] + " per frame")


func _build_rig() -> void:
	rig = XROrigin3D.new()
	add_child(rig)
	camera = XRCamera3D.new()
	camera.current = true
	camera.near = 0.1
	camera.far = 300.0
	rig.add_child(camera)
	lamp = SpotLight3D.new()
	lamp.light_color = LAMP_COLOUR
	lamp.light_energy = RimLight.LAMP_ENERGY
	lamp.spot_range = RimLight.LAMP_RANGE_M
	lamp.spot_angle = RimLight.LAMP_ANGLE_DEG
	lamp.spot_attenuation = RimLight.LAMP_ATTENUATION
	lamp.spot_angle_attenuation = RimLight.LAMP_ANGLE_ATTENUATION
	camera.add_child(lamp)
	left_hand = XRController3D.new()
	left_hand.tracker = &"left_hand"
	rig.add_child(left_hand)
	right_hand = XRController3D.new()
	right_hand.tracker = &"right_hand"
	rig.add_child(right_hand)


## The ROV's body from the operator's drawings, with the lamp on its
## front camera skid when it is seen from behind.
func _build_body() -> void:
	body = RovBody.new()
	add_child(body)
	_place_view()


## Put the lamp where the eye is: on the camera in first person, on the
## body's front skid (0.7 m ahead of its centre) in third person, so the
## light comes from the vehicle the player sees.
func _place_view() -> void:
	# The frame hides in first person; the arm and the lamps stay, as
	# the ROV's own camera sees its arm below it.
	body.show_frame(third_person)
	var holder: Node3D = body if third_person else camera
	if lamp.get_parent() != holder:
		lamp.reparent(holder, false)
	lamp.position = Vector3(0, 0.02, -0.72) if third_person else Vector3.ZERO
	# Down with the drawn beams, onto the floor where things are read.
	lamp.rotation = Vector3(RimLight.LAMP_PITCH_3P, 0, 0) if third_person \
		else Vector3.ZERO


# --- Telemetry and messages ---------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_prompt = Label.new()
	hud_prompt.position = Vector2(24, 20)
	hud_prompt.add_theme_font_size_override("font_size", 20)
	layer.add_child(hud_prompt)
	# The pilot's console sits below the window on the water (operator,
	# 2026-09-30: "телеметрию ниже, а выше окно"), drawn once into its
	# own viewport so the screen and the headset show the same panel.
	console_view = SubViewport.new()
	console_view.transparent_bg = true
	console_view.size = CONSOLE_PX
	console_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(console_view)
	console = CockpitPanel.new()
	console.position = Vector2(8, 8)
	console_view.add_child(console)
	console_screen = TextureRect.new()
	console_screen.texture = console_view.get_texture()
	console_screen.anchor_left = 0.5
	console_screen.anchor_right = 0.5
	console_screen.anchor_top = 1.0
	console_screen.anchor_bottom = 1.0
	console_screen.offset_left = -CONSOLE_PX.x / 2.0
	console_screen.offset_top = -CONSOLE_PX.y - 8.0
	layer.add_child(console_screen)
	# The task line rides just above the console.
	hud_label = Label.new()
	hud_label.anchor_top = 1.0
	hud_label.anchor_bottom = 1.0
	hud_label.offset_top = -CONSOLE_PX.y - 40.0
	hud_label.offset_left = 24
	hud_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(hud_label)
	# In the headset the same console is a panel under the gaze, tilted
	# towards the eyes like a pult.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.62, 0.62 * CONSOLE_PX.y / CONSOLE_PX.x)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_texture = console_view.get_texture()
	console_xr = MeshInstance3D.new()
	console_xr.mesh = quad
	console_xr.material_override = mat
	console_xr.position = Vector3(0, -0.34, -0.72)
	console_xr.rotation_degrees = Vector3(-25, 0, 0)
	console_xr.visible = false
	camera.add_child(console_xr)
	_build_screens(layer)
	for which in ["telemetry", "prompt"]:
		var l := Label3D.new()
		l.pixel_size = 0.0007
		l.font_size = 32
		l.no_depth_test = true
		l.fixed_size = false
		l.modulate = Color(0.85, 0.95, 1.0)
		l.position = Vector3(0, -0.19 if which == "telemetry" else 0.12,
			-0.8)
		l.visible = false
		camera.add_child(l)
		if which == "telemetry":
			xr_label = l
		else:
			xr_prompt = l


## The second screen: the front camera renders the shared world into a
## small viewport of its own; the sonar is drawn from CockpitCore.
func _build_screens(layer: CanvasLayer) -> void:
	eye_view = SubViewport.new()
	eye_view.size = CockpitScreens.CAMERA_PX
	eye_view.world_3d = get_viewport().world_3d
	eye_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(eye_view)
	eye = Camera3D.new()
	eye.fov = 70.0
	eye.far = 60.0
	# Not through its own beams' haze (RovBody.BEAM_LAYER).
	eye.cull_mask = 0xFFFFF & ~(1 << (RovBody.BEAM_LAYER - 1))
	eye_view.add_child(eye)
	screens_view = SubViewport.new()
	screens_view.transparent_bg = true
	screens_view.size = SCREENS_PX
	screens_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(screens_view)
	screens = CockpitScreens.new()
	screens.position = Vector2(8, 8)
	screens_view.add_child(screens)
	screens.picture.texture = eye_view.get_texture()
	screens_screen = TextureRect.new()
	screens_screen.texture = screens_view.get_texture()
	screens_screen.anchor_left = 1.0
	screens_screen.anchor_right = 1.0
	screens_screen.offset_left = -SCREENS_PX.x - 8.0
	screens_screen.offset_top = 8.0
	layer.add_child(screens_screen)
	# In the headset: a panel to the right of the gaze, turned to it.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.47, 0.47 * SCREENS_PX.y / SCREENS_PX.x)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_texture = screens_view.get_texture()
	screens_xr = MeshInstance3D.new()
	screens_xr.mesh = quad
	screens_xr.material_override = mat
	screens_xr.position = Vector3(0.5, -0.1, -0.7)
	screens_xr.rotation_degrees = Vector3(0, -30, 0)
	screens_xr.visible = false
	camera.add_child(screens_xr)


## The camera follows the skid; the sonar pings SONAR_HZ times a second
## (enough for the eye, and cheap on the Quest's CPU); the hydrophone
## hears the ROV's own thrusters at the command the sticks give.
func _update_screens(dt: float, thrust: float) -> void:
	hydro_left -= dt
	if hydro_left <= 0.0:
		hydro_left = PosohCore.REPORT_S
		screens.hydro.show_reading(rov.depth, thrust)
	eye.global_transform = body.global_transform \
		* Transform3D(Basis(), RovBody.EYE)
	sonar_left -= dt
	if sonar_left <= 0.0:
		sonar_left = 1.0 / SONAR_HZ
		var things: Array = placed + traces
		for sc in schools:
			var p := DiveCore.fish_at(sc, 0, t)
			things.append({"x": p.x, "z": p.z, "depth": p.depth,
				"size": 0.4})
		screens.sonar.show_scan(CockpitCore.sonar_scan(rov, things), t)


## The spoken line above the console: the task, and the diver's rule
## in words when the ascent is too fast (the card turns red as well).
func _console_line(tel: Dictionary) -> String:
	var line := _task_line()
	if tel.ascent_too_fast:
		line = "Всплытие %.0f м/мин — быстрее 10 м/мин. Сбавь ход.\n" \
			% tel.ascent_m_per_min + line
	return line


# --- Controls ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		mouse_look = event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	elif event is InputEventMouseMotion and mouse_look and not xr_active:
		rov.yaw += event.relative.x * 0.004
		pitch = clampf(pitch - event.relative.y * 0.003, -1.2, 1.2)


func _key(a: Key, b: Key) -> float:
	return float(Input.is_key_pressed(a)) - float(Input.is_key_pressed(b))


func _stick(hand: XRController3D) -> Vector2:
	var v := hand.get_vector2("primary")
	if v == Vector2.ZERO:
		v = hand.get_vector2("thumbstick")
	return v


func _read_input() -> Dictionary:
	var inp := {
		"forward": _key(KEY_W, KEY_S), "strafe": _key(KEY_D, KEY_A),
		"vertical": _key(KEY_R, KEY_F), "turn": _key(KEY_E, KEY_Q),
	}
	var interact := Input.is_key_pressed(KEY_SPACE)
	var lamp_key := Input.is_key_pressed(KEY_L)
	if xr_active:
		var move := _stick(left_hand)
		var aux := _stick(right_hand)
		# Move where the head looks, so the body follows the eyes.
		var head := camera.transform.basis.z
		var phi := atan2(-head.x, -head.z)
		var f := move.y
		var s := move.x
		inp.forward = f * cos(phi) - s * sin(phi)
		inp.strafe = f * sin(phi) + s * cos(phi)
		inp.vertical = aux.y
		# Snap turn of 30 degrees: smooth turning makes people sick.
		if absf(aux.x) > 0.7 and snap_ready:
			rov.yaw += deg_to_rad(30.0) * signf(aux.x)
			snap_ready = false
		elif absf(aux.x) < 0.3:
			snap_ready = true
		interact = interact or right_hand.is_button_pressed("trigger_click")
		lamp_key = lamp_key or right_hand.is_button_pressed("ax_button")
	var view_key := Input.is_key_pressed(KEY_V) or (xr_active
		and left_hand.is_button_pressed("by_button"))
	if view_key and not view_was:
		third_person = not third_person
		_place_view()
	view_was = view_key
	if interact and not interact_was:
		_interact()
	interact_was = interact
	if lamp_key and not lamp_was:
		rov.lamp = not rov.lamp
		audio.on_lamp_toggled(rov.lamp)
	lamp_was = lamp_key
	return inp


func _interact() -> void:
	var things: Array = placed + traces
	for s in schools:
		var p := DiveCore.fish_at(s, 0, t)
		things.append({"id": s.id, "loot": s.loot, "x": p.x, "z": p.z,
			"depth": p.depth, "ru": s.ru, "category": "fish"})
	var hit := DiveCore.nearest(rov, things, REACH_M)
	if not hit.is_empty() and hit.thing.get("kind") in ["trace", "passage"]:
		# The knight's things go to the scribe; at the khachkar the arm
		# does not move at all (TABOO 0.4 rule 1).
		var res := AtlasTraces.take(bag, hit.thing)
		if res.reach:
			body.reach(t)
			audio.on_arm()
			arm_now = true
		bag = res.bag
		_save_bag()
		_say(res.text)
		return
	# At a holy thing on the floor (the lead bulla) the arm does not
	# move and nothing is said: the interface goes, as at the khachkar
	# (TABOO 0.4 rules 1-2; chorus audit 2026-10-03, voice 9).
	if not hit.is_empty() and RimLight.is_holy(hit.thing):
		return
	# The arm reaches whatever it finds: an empty reach is the answer
	# "nothing here" too.
	body.reach(t)
	audio.on_arm()
	arm_now = true
	if hit.is_empty():
		# With the tether unwound the empty reach lifts the loop, and the
		# core says so itself this frame.
		if game.wound and absf(game.turns) <= DiveCore.UNWOUND_TURNS \
				and not "tether" in game.done:
			return
		_say("Рядом ничего нет. Подойди ближе.")
		return
	var res := DiveCore.loot_action(hit.thing, bag)
	# loot_action is the port of dive-core.js and knows three pockets;
	# what went to the scribe from the Atlas stays where it is.
	var atlas_given: Array = bag.get("atlas", [])
	bag = res.bag
	bag["atlas"] = atlas_given
	_save_bag()
	audio.on_taken(res.rule)
	_say("%s. %s" % [hit.thing.ru, res.text])


func _say(text: String) -> void:
	message = text
	message_left = 7.0


## The next task not yet done, in the order of the bands downwards.
func _task_line() -> String:
	var target := ""
	if not story_target.is_empty():
		target = "Миссия %d: %s, %s–%s м. " % [story_target.mission,
			story_target.ru.get_slice(":", 0),
			MissionCore.js_num(story_target.depth[0]),
			MissionCore.js_num(story_target.depth[1])]
	return target + _dive_task_line()


func _dive_task_line() -> String:
	if game.recovering:
		return "Заряд кончился. Аппарат выбирают тросом к стапелю."
	if game.fallen:
		return "Остановка безопасности: стой на месте %d с." % maxi(0,
			roundi(DiveCore.SAFETY_STOP_SEC - game.still_for))
	for task in DiveCore.TASKS:
		if not task.id in game.done:
			return task.ru
	return "Все задачи погружения пройдены."


## The battery is flat: the hub starts loading at once (TABOO 0.014),
## and after a short watch, or at the surface, the player goes back to
## the slipway through ModuleLoader's fade.  The proof frames stay.
func _update_recovery(dt: float) -> void:
	if not game.recovering or recovery_sent or shots_dir != "":
		return
	if recovery_left < 0.0:
		recovery_left = RECOVERY_WATCH_SEC
		ModuleLoader.prefetch(ModuleLoader.HUB)
	recovery_left -= dt
	if recovery_left <= 0.0 or game.recovered:
		recovery_sent = true
		_save_bag()
		_say(DiveCore.RECOVERED_RU)
		ModuleLoader.go(ModuleLoader.HUB)


func _save_bag() -> void:
	SaveSlot.write_json(SaveSlot.dive(), {"bag": bag, "done": game.done})


## The chronicle's choice is written in the hub (hub.json); the dive only
## reads it.  Proof frames show the "spare" floor without saving it.
func _load_chronicle() -> String:
	var data := SaveSlot.read_json(SaveSlot.hub())
	if not data.is_empty():
		var c := AtlasTraces.write_chronicle(atlas_data,
			data.get("chronicle"), "")
		if c != "":
			return c
	return "spare" if shots_dir != "" else ""


func _load_bag() -> void:
	# A spoiled save falls back to its last good copy; wrong shapes are
	# skipped, not merged (a merge of a non-Dictionary would stop the run).
	var data := SaveSlot.read_json(SaveSlot.dive())
	if data.get("bag") is Dictionary:
		bag.merge(data.bag, true)
	if data.get("done") is Array:
		game.done = data.done


# --- XR ---------------------------------------------------------------------

func _start_xr() -> void:
	var openxr := XRServer.find_interface("OpenXR")
	if openxr and openxr.is_initialized():
		get_viewport().use_xr = true
		xr_active = true
		_on_xr_started()
		return
	webxr = XRServer.find_interface("WebXR")
	if webxr and webxr.is_initialized():
		# The session survives a scene change: coming back from the hub
		# in the headset, the dive goes straight into it, no button.
		webxr.session_ended.connect(_on_webxr_ended)
		_on_webxr_started()
		return
	if webxr:
		webxr.session_supported.connect(_on_webxr_supported)
		webxr.session_started.connect(_on_webxr_started)
		webxr.session_ended.connect(_on_webxr_ended)
		webxr.is_session_supported("immersive-vr")


func _on_webxr_supported(mode: String, supported: bool) -> void:
	if mode != "immersive-vr" or not supported:
		return
	vr_button = Button.new()
	vr_button.text = "Войти в шлем"
	vr_button.position = Vector2(24, 64)
	vr_button.add_theme_font_size_override("font_size", 28)
	vr_button.pressed.connect(_enter_webxr)
	hud_prompt.get_parent().add_child(vr_button)


func _enter_webxr() -> void:
	webxr.session_mode = "immersive-vr"
	webxr.requested_reference_space_types = "local-floor, local"
	webxr.required_features = "local"
	webxr.optional_features = "local-floor"
	webxr.initialize()


func _on_webxr_started() -> void:
	get_viewport().use_xr = true
	xr_active = true
	_on_xr_started()


func _on_webxr_ended() -> void:
	get_viewport().use_xr = false
	xr_active = false
	xr_label.visible = false
	xr_prompt.visible = false
	console_xr.visible = false
	console_screen.visible = true
	screens_xr.visible = false
	screens_screen.visible = true


func _on_xr_started() -> void:
	xr_label.visible = true
	xr_prompt.visible = true
	console_xr.visible = true
	console_screen.visible = false
	screens_xr.visible = true
	screens_screen.visible = false
	if vr_button:
		vr_button.visible = false


# --- Frame ------------------------------------------------------------------

func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	t += dt
	var inp := _read_input()
	# The seiche current on the slope carries the ROV sideways.
	inp["drift"] = DiveCore.current(rov.x, t)
	rov = DiveCore.step_rov(rov, inp, dt)
	var out := DiveCore.step_game(game, rov, dt, bag.handed_over.size(),
		arm_now)
	arm_now = false
	if out.game.done.size() != game.done.size() or out.game.fallen != game.fallen:
		game = out.game
		_save_bag()
	game = out.game
	for text in out.say:
		_say(text)
	_update_recovery(dt)
	if shots_dir != "":
		_shots()
	var tel := DiveCore.telemetry(rov)
	var at := Vector3(rov.x, -rov.depth, rov.z)
	rig.rotation.y = -(rov.yaw + PI / 2.0)
	body.position = at
	body.rotation.y = rig.rotation.y
	body.update(t)
	body.set_lamp(rov.lamp and rov.battery > 0.0)
	body.set_battery(rov.battery > 0.0)
	# In first person the eye is the front camera on the skid, as on
	# the real vehicle, so the arm is seen reaching out below it.
	rig.position = at + rig.basis * RovBody.EYE
	if third_person:
		# Behind and above the body, turned with it; never above the
		# surface, where the chase camera would look at the sky.
		rig.position = at + rig.basis * CHASE
		rig.position.y = minf(rig.position.y, -0.25)
	if not xr_active:
		camera.rotation.x = pitch + (CHASE_PITCH if third_person else 0.0)
		# Turn the eye back onto the body (atan(0.45 / 2.6)); in the
		# headset the head does that itself.
		camera.rotation.y = CHASE_YAW if third_person else 0.0
	lamp.visible = rov.lamp and rov.battery > 0.0
	# A fall dims the world until the safety stop is held.
	lamp.light_energy = RimLight.LAMP_ENERGY * (0.3 if game.fallen else 1.0)
	_update_water(tel)
	# Things are read by the lamp's highlight where it shines and by the
	# rim light where it does not (the operator's decision, RimLight).
	# The proof frames jump from place to place: there the lights are
	# settled at once instead of easing.
	if rim_settled:
		rim.weight = 0.0 if lamp.visible else 1.0
		rim.settle_background()
	var rim_t0 := Time.get_ticks_usec()
	rim_lights = rim.update(lamp, lamp.visible, lamp.light_energy,
		tel.depth, maxf(0.0, tel.floor - tel.depth), dt)
	rim_us += Time.get_ticks_usec() - rim_t0
	rim_frames += 1
	_update_thermocline(tel.depth)
	_update_bubbles()
	audio.update(tel, rov, inp, schools, t, dt, xr_active)
	if game.fallen:
		env.ambient_light_energy *= 0.35
		sun.light_energy *= 0.35
	_update_fish()
	_update_lines()
	($Snow as CPUParticles3D).position = rig.position
	message_left = maxf(0.0, message_left - dt)
	var prompt := message if message_left > 0.0 else _hint()
	var text := _console_line(tel)
	var shown := tel.duplicate()
	shown["lamp"] = rov.lamp
	console.show_cards(CockpitCore.cards(shown, bag, game.turns))
	_fade_console(dt)
	# Every thruster answers some stick, turning included: the largest
	# command is what the hydrophone hears.
	var thrust := 0.0
	for k in ["forward", "strafe", "vertical", "turn"]:
		thrust = maxf(thrust, absf(inp.get(k, 0.0)))
	if rov.battery <= 0.0:
		thrust = 0.0
	_update_screens(dt, thrust)
	_turn_viewports()
	if shot_closeup:
		_closeup_view()
	hud_label.text = text
	hud_prompt.text = prompt
	xr_label.text = text
	xr_prompt.text = prompt


## Near a holy thing the console, the task line and the hints go out
## over CockpitCore.FADE_SECONDS; the ROV itself still answers the
## sticks.
func _fade_console(dt: float) -> void:
	var here := Vector3(rov.x, -rov.depth, rov.z)
	var nearest := INF
	for p in holy_points:
		nearest = minf(nearest, here.distance_to(p))
	console_alpha = CockpitCore.fade_step(console_alpha,
		CockpitCore.fade_target(nearest), dt)
	for node in [console_screen, screens_screen, hud_label, hud_prompt]:
		node.modulate.a = console_alpha
	console_xr.transparency = 1.0 - console_alpha
	screens_xr.transparency = 1.0 - console_alpha
	xr_label.modulate.a = console_alpha
	xr_prompt.modulate.a = console_alpha


## Place the ROV at each planned depth over the slope, facing away from
## the shore, wait for the frame to settle, save it, then quit.
func _shots() -> void:
	# Each depth twice: from the ROV's eye, then from behind its body.
	var n := shot_frame / 40
	if n >= shot_plan.size():
		_shot_closeup(n)
		return
	var chase := shot_frame % 40 >= 20
	if chase != third_person:
		third_person = chase
		_place_view()
	var depth: float = shot_plan[n]
	# The manipulator is shown at full reach in both views.
	body.reach(20.0 + n - 0.6)
	rov.x = DiveCore.x_for_depth(depth + 6.0) - 8.0
	rov.z = 0.0
	rov.depth = depth
	rov.yaw = 0.0
	pitch = -0.25
	t = 20.0 + n
	if shot_frame % 20 == 19:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/dive-%03dm%s.png" % [shots_dir, roundi(depth),
			"-3p" if chase else ""])
	shot_frame += 1


## The last proof frame: third person at 12 m, the camera beside the
## top tube's bow end, looking at the hydrophone (docs/audit).
func _shot_closeup(n: int) -> void:
	var k := shot_frame - 40 * shot_plan.size()
	if k >= 20:
		# Then the knight's traces of the Water Atlas.
		shot_closeup = false
		_atlas_shots()
		return
	shot_closeup = true
	if not third_person:
		third_person = true
		_place_view()
	rov.x = DiveCore.x_for_depth(18.0) - 8.0
	rov.z = 0.0
	rov.depth = 12.0
	rov.yaw = 0.0
	t = 20.0 + n
	if k == 19:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/dive-posoh-closeup.png" % shots_dir)
	shot_frame += 1


func _closeup_view() -> void:
	var target := body.to_global(PosohCore.MOUNT
		+ Vector3(0, 0, -PosohCore.TUBE_LEN_M / 2.0))
	rig.global_position = body.to_global(Vector3(0.42, 0.62, -0.62))
	rig.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.look_at(target, Vector3.UP)


func _build_audio() -> void:
	audio = DiveAudio.new()
	add_child(audio)
	var flows := []
	for p in placed:
		if p.where == "water" and p.shape in FLOW_SHAPES:
			flows.append(p)
	audio.build(camera, right_hand, schools, flows)


func _hint() -> String:
	var things: Array = placed + traces
	var hit := DiveCore.nearest(rov, things, REACH_M)
	if not hit.is_empty() and RimLight.is_holy(hit.thing):
		# No hint at a holy thing: the interface is gone there.
		return ""
	if hit.is_empty():
		# The first seconds teach the view switch, then stay quiet.
		return "V (или Y на левом контроллере) — вид: из глаза ROV или " \
			+ "со стороны корпуса" if t < 12.0 else ""
	return "%s — нажми, чтобы взять или рассмотреть" % hit.thing.ru


## The water per biome (DiveCore.biome_look): colour and light from the
## absorption of clear water, fog per biome; in the night of the deep
## the lamp is the only light.
func _update_water(tel: Dictionary) -> void:
	var look := DiveCore.biome_look(tel.depth, maxf(0.0, tel.floor
		- tel.depth))
	biome = look.biome
	var c := Color(look.water[0], look.water[1], look.water[2])
	env.background_color = c
	env.fog_light_color = c
	env.fog_density = look.fog
	var left: Dictionary = tel.light
	sun.light_energy = look.sun
	sun.light_color = Color(0.35 + 0.65 * left.red,
		0.5 + 0.5 * left.green, 0.6 + 0.4 * left.blue)
	env.ambient_light_color = c.lightened(0.3)
	env.ambient_light_energy = look.ambient


func _update_fish() -> void:
	# The fish of our own drawing choose their view by where the eye is.
	var eye := {}
	if is_instance_valid(camera) and camera.is_inside_tree():
		var c := camera.global_position
		eye = {"x": c.x, "depth": -c.y, "z": c.z}
	for n in schools.size():
		var s: Dictionary = schools[n]
		var mm: MultiMesh = fish_meshes[n].multimesh
		if fish_meshes[n].has_meta("fish_drawing"):
			FishDrawings.update(fish_index, FishDrawings.kit_of(fish_index,
				str(s.id)), s, mm, t, eye)
			continue
		for i in s.count:
			var p := DiveCore.fish_at(s, i, t)
			var basis := Basis(Vector3.UP, -p.heading).scaled(
				Vector3.ONE * float(s.length))
			mm.set_instance_transform(i, Transform3D(basis,
				Vector3(p.x, -p.depth, p.z)))


## Flow lines in the manner the operator liked in the 2D view: moving
## polylines that trace the water, each after its own physics.
func _flow_lines(p: Dictionary) -> Array:
	var o := Vector3(p.x, -p.depth, p.z)
	var lines := []
	var shape: String = p.shape
	if shape == "eddy":
		for i in 4:
			var pts := []
			var cx := o.x + i * 3.0 + fmod(t * 0.8, 3.0)
			var side := 1.0 if i % 2 else -1.0
			for k in 14:
				var a := k / 13.0 * TAU * side + t * 2.0
				var r := 0.3 + k * 0.08
				pts.append(Vector3(cx + r * cos(a), o.y + r * 0.6 * sin(a),
					o.z + side * 1.2))
			lines.append(pts)
	elif shape in ["intwave", "layer"]:
		for i in 4:
			var pts := []
			for k in 24:
				pts.append(Vector3(o.x - 30.0 + k * 2.6, THERMO_Y + i * 0.5
					+ 1.5 * sin(k * 0.45 - t * 0.6 + i * 0.3), o.z + i))
			lines.append(pts)
	elif shape == "plume":
		for i in 6:
			var pts := []
			for k in 12:
				pts.append(Vector3(o.x + k * 0.8, o.y + (i - 2.5) * (0.1
					+ k * 0.08), o.z + 0.3 * sin(k + t * 2.0 + i)))
			lines.append(pts)
	elif shape == "langmuir":
		for i in 5:
			var pts := []
			for k in 12:
				pts.append(Vector3(o.x + i * 2.0 + 0.2 * sin(k + t * 1.5),
					-0.4, o.z - 6.0 + k))
			lines.append(pts)
	elif shape == "upwelling":
		for i in 5:
			var pts := []
			for k in 12:
				pts.append(Vector3(o.x + (i - 2) * (0.3 + k * 0.15)
					+ 0.2 * sin(k + t * 2.0), o.y + k * 0.6, o.z))
			lines.append(pts)
	else:
		# The seiche current and drifting clouds: parallel slow lines.
		for i in 5:
			var pts := []
			for k in 12:
				pts.append(Vector3(o.x - 3.0 + k * 0.5, o.y + i * 0.4
					+ 0.2 * sin(k + t * 2.0), o.z + i * 0.3))
			lines.append(pts)
	return lines


func _update_lines() -> void:
	flow_mesh.clear_surfaces()
	# The lines and the tether follow the vehicle, not the camera.
	var here := body.position
	var any := false
	for p in placed:
		if p.where != "water" or not p.shape in FLOW_SHAPES:
			continue
		if Vector3(p.x, -p.depth, p.z).distance_to(here) > 45.0:
			continue
		var col := Color(p.colour)
		col.a = 0.7
		for pts in _flow_lines(p):
			if not any:
				flow_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
				any = true
			for k in pts.size() - 1:
				flow_mesh.surface_set_color(col)
				flow_mesh.surface_add_vertex(pts[k])
				flow_mesh.surface_set_color(col)
				flow_mesh.surface_add_vertex(pts[k + 1])
	if any:
		flow_mesh.surface_end()
	# The tether: from the boat at the shore to the ROV, sagging.
	tether_mesh.clear_surfaces()
	tether_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var a := Vector3(30.0, 0.0, 0.0)
	# The tether leaves the top of the body, by its central module.
	var b := here + Vector3(0, 0.45, 0)
	var mid := (a + b) / 2.0 + Vector3(0, -3.0 - a.distance_to(b) * 0.08, 0)
	for k in 21:
		var u := k / 20.0
		tether_mesh.surface_set_color(Color(0.88, 0.63, 0.25))
		tether_mesh.surface_add_vertex(a.lerp(mid, u).lerp(mid.lerp(b, u),
			u))
	tether_mesh.surface_end()
