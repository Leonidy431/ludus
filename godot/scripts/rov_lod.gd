## The Mangustik with a far-view proxy (blocker Б-2,
## docs/APK_REQUIREMENTS.md).
##
## The full model (models/rov/mangustik.glb, 18,616 triangles) is over
## the 5,000-triangle limit of a proxy (TABOO 0.32 p.4).  The far-view
## proxy (models/rov/mangustik-lod1.glb, under 5,000) is built from the
## same drawings by scripts/meta3d/mangustik_rov.py.  The renderer's own
## visibility ranges choose between them, so no script runs per frame:
##   - the proxy is one mesh and draws from NEAR_M outwards
##     (visibility_range_begin);
##   - the full model's subtree takes the proxy as its visibility parent,
##     so it draws only while the proxy is hidden for being nearer than
##     NEAR_M.  All parts switch together, by the proxy's centre, and
##     the two are never drawn at once.
## Fade is off: a cross-fade would draw both models in the band, and
## the margin only stops a flicker when the camera stands at the edge.
class_name RovLod
extends RefCounted

const FULL := "res://models/rov/mangustik.glb"
const PROXY := "res://models/rov/mangustik-lod1.glb"
## Within this distance (camera to the vehicle's centre, metres) the
## full model is drawn; beyond it, the proxy.  Measured with
## tools/rov_lod_shots.gd: side by side at 2.4 m the two read as the
## same vehicle, so the dive's chase camera (2.8 m from the centre,
## dive.gd CHASE) and the hub's pier view (3.0 m) draw the proxy, and
## the full model is kept for a look at arm's length on the pier.
const NEAR_M := 2.0
## Hysteresis at the switch (no fade), metres.
const MARGIN_M := 0.2


## The vehicle as one node: "Full" and "Proxy" under it, both placed at
## the model's own origin (the proxy shares the drawings' placements).
## A missing model gives an empty node, as the callers' fallbacks do.
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Mangustik"
	var full_scene := load(FULL) as PackedScene
	var proxy_scene := load(PROXY) as PackedScene
	if full_scene == null:
		return root
	var full := full_scene.instantiate() as Node3D
	full.name = "Full"
	root.add_child(full)
	if proxy_scene == null:
		return root
	var proxy := proxy_scene.instantiate() as Node3D
	proxy.name = "Proxy"
	root.add_child(proxy)
	var lead: GeometryInstance3D = null
	var paint := proxy_paint()
	for g in geometry(proxy):
		g.material_override = paint
		g.visibility_range_begin = NEAR_M
		g.visibility_range_begin_margin = MARGIN_M
		g.visibility_range_fade_mode = \
			GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if lead == null:
			lead = g
	if lead != null:
		# Relative to the full model, so it holds wherever the root is
		# put; the renderer resolves it when the root enters the tree.
		full.visibility_parent = full.get_path_to(lead)
	return root


## The proxy's one material.  Its glb carries the parts' colours as
## vertex colours (COLOR_0, linear: the hex colour / 255), and Godot's
## importer neither uses them as albedo nor gives the paint, so the
## paint of the full model is set here: metallic 0.2, roughness 0.55,
## and the colour taken as linear, as the full model's baseColorFactor
## is, so both read the same under the same lamp.
static func proxy_paint() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	m.albedo_color = Color.WHITE
	m.metallic = 0.2
	m.roughness = 0.55
	return m


## Every drawn mesh under node, in tree order.
static func geometry(node: Node) -> Array:
	var out: Array = []
	for c in node.find_children("*", "GeometryInstance3D", true, false):
		out.append(c)
	if node is GeometryInstance3D:
		out.push_front(node)
	return out


## Which model the renderer draws at a distance d (metres, camera to
## the proxy's centre), ignoring the margin: "full" or "proxy".  Mirrors
## the ranges set in build(), so the tests can state the switch.
static func shown_at(d: float) -> String:
	return "full" if d < NEAR_M else "proxy"


## Triangles of the drawn meshes under node (surfaces of ArrayMesh).
static func triangles(node: Node) -> int:
	var n := 0
	for g in geometry(node):
		if not g is MeshInstance3D or (g as MeshInstance3D).mesh == null:
			continue
		var mesh: Mesh = (g as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			if idx != null and idx.size() > 0:
				n += idx.size() / 3
			else:
				n += arrays[Mesh.ARRAY_VERTEX].size() / 3
	return n
