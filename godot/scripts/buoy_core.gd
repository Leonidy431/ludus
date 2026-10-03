## The operator's autonomous buoy, the first techno-artefact to restore
## (TABOO 0.024 item 8; his repo stm32_bouy, inventory item
## mooring_buoy).  Each calibrated matrix repairs one system, and the buoy
## shows it at once.  The data is godot/data/buoy.json.
##
## The buoy is built from primitives (a proxy under 5000 triangles,
## TABOO 0.32): a yellow float, a mast with its beacon, a solar panel with
## one dark cell, a winch, and the hydrophone cable that hangs loose until
## the hearing is repaired.  A repaired system lights its diode green.
class_name BuoyCore
extends RefCounted

const DATA := "res://data/buoy.json"
const OFF := Color(0.35, 0.08, 0.05)
const ON := Color(0.45, 1.0, 0.4)


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


static func start(data: Dictionary) -> Dictionary:
	var st := {"repaired": [], "systems": []}
	for s in data.get("systems", []):
		st.systems.append(s.id)
	return st


static func repair(st: Dictionary, system: String) -> Dictionary:
	var s := st.duplicate(true)
	if system in s.systems and not system in s.repaired:
		s.repaired.append(system)
	return s


static func _m(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func _add(parent: Node3D, mesh: Mesh, m: Material, at: Vector3,
		name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


static func build(st: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Buoy"
	var stand := BoxMesh.new()
	stand.size = Vector3(0.5, 0.12, 0.5)
	_add(root, stand, _m(Color(0.2, 0.18, 0.15)), Vector3(0, 0.06, 0))
	var f := CylinderMesh.new()
	f.top_radius = 0.24
	f.bottom_radius = 0.2
	f.height = 0.42
	_add(root, f, _m(Color(0.85, 0.65, 0.08)), Vector3(0, 0.33, 0))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = 0.24
	cone.height = 0.16
	_add(root, cone, _m(Color(0.85, 0.65, 0.08)), Vector3(0, 0.62, 0))
	var mast := CylinderMesh.new()
	mast.top_radius = 0.012
	mast.bottom_radius = 0.016
	mast.height = 0.5
	_add(root, mast, _m(Color(0.6, 0.62, 0.65)), Vector3(0, 0.95, 0))
	var panel := BoxMesh.new()
	panel.size = Vector3(0.22, 0.008, 0.16)
	var p := _add(root, panel, _m(Color(0.05, 0.08, 0.2)),
		Vector3(0.0, 0.73, 0.0))
	p.rotation.x = deg_to_rad(-25.0)
	var cell := BoxMesh.new()
	cell.size = Vector3(0.05, 0.01, 0.07)
	_add(p, cell, _m(Color(0.02, 0.02, 0.02)), Vector3(0.07, 0.002, 0.03))
	var winch := CylinderMesh.new()
	winch.top_radius = 0.05
	winch.bottom_radius = 0.05
	winch.height = 0.1
	var w := _add(root, winch, _m(Color(0.3, 0.3, 0.32)),
		Vector3(-0.27, 0.2, 0.0))
	w.rotation.z = PI / 2.0
	# The hydrophone: a dark capsule on its cable, lying loose on the
	# stand while the hearing is broken, hanging true when repaired.
	var cable := CylinderMesh.new()
	cable.top_radius = 0.005
	cable.bottom_radius = 0.005
	cable.height = 0.5
	var c := _add(root, cable, _m(Color(0.05, 0.05, 0.05)),
		Vector3(0.3, 0.2, 0.15), "HydroCable")
	c.rotation.z = deg_to_rad(70.0)
	var cap := CapsuleMesh.new()
	cap.radius = 0.025
	cap.height = 0.12
	_add(root, cap, _m(Color(0.12, 0.2, 0.55)), Vector3(0.5, 0.13, 0.15),
		"Hydrophone")
	var i := 0
	for id in st.systems:
		var led := SphereMesh.new()
		led.radius = 0.014
		led.height = 0.028
		var d := _add(root, led, _m(OFF, 1.0),
			Vector3(-0.18 + 0.072 * float(i), 0.47, 0.235), "Led_" + id)
		d.set_meta("system", id)
		i += 1
	var tag := Label3D.new()
	tag.name = "Status"
	tag.font_size = 22
	tag.pixel_size = 0.0012
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.45, 0.92, 1.0)
	tag.outline_size = 4
	tag.position = Vector3(0, 1.32, 0)
	root.add_child(tag)
	show(root, st)
	return root


## Show the state: each system's diode green when repaired; the
## hydrophone hangs straight down on its cable once hearing works.
static func show(root: Node3D, st: Dictionary) -> void:
	for n in root.get_children():
		if n.has_meta("system"):
			var on: bool = n.get_meta("system") in st.repaired
			(n as MeshInstance3D).material_override = _m(ON if on else OFF,
				2.0 if on else 0.6)
	var tag := root.get_node_or_null("Status") as Label3D
	if tag:
		tag.text = "автономный буй\nслух: %s · систем в строю: %d из %d" % [
			"работает" if "hearing" in st.repaired else "нет",
			st.repaired.size(), st.systems.size()]
	var heard: bool = "hearing" in st.repaired
	var c: Node3D = root.get_node("HydroCable")
	var h: Node3D = root.get_node("Hydrophone")
	if heard:
		c.rotation.z = 0.0
		c.position = Vector3(0.3, 0.32, 0.15)
		h.position = Vector3(0.3, 0.05, 0.15)
	else:
		c.rotation.z = deg_to_rad(70.0)
		c.position = Vector3(0.3, 0.2, 0.15)
		h.position = Vector3(0.5, 0.13, 0.15)
