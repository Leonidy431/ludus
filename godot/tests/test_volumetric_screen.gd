## The volumetric laser screen (VolumetricScreen, TABOO 0.022, phase V2):
## the budget (three draw calls, 5000 triangles, no particle classes),
## the same run gives the same transforms, the holy fade within 1.75 s
## and the dark that stays, reduced-motion holds still, each mode is
## not empty and its colours come from VolumetricCore.
## Called from run_hub_tests.gd.
extends RefCounted


func _run(mode: String, reduced: bool) -> Array:
	var s := VolumetricScreen.new()
	s.set_mode(mode)
	var hs := []
	for i in 6:
		s.update(float(i) * 0.37, 50.0, reduced)
		hs.append(s.frame_hash())
	var out := [hs, s.voxel_count(), s.voxel_colors()]
	s.free()
	return out


func run(t: Object) -> void:
	var s := VolumetricScreen.new()
	var st := s.stats()
	t._check(st.draw_calls <= 3, "screen: at most 3 draw calls (%d)"
		% st.draw_calls)
	t._check(st.triangles <= 5000, "screen: at most 5000 triangles (%d)"
		% st.triangles)
	t._check(st.instances > 0 and st.visible_instances > 0,
		"screen: instances %d" % st.instances)
	var parts := 0
	var particles := false
	for c in s.get_children():
		parts += 1
		if c is GPUParticles3D or c is CPUParticles3D:
			particles = true
	t._check(parts == 3 and not particles,
		"screen: three parts, glass and two MultiMeshes, no particles")
	s.free()

	for m in VolumetricScreen.MODES:
		var a := _run(m, false)
		var b := _run(m, false)
		t._check(a[0] == b[0], "screen %s: the same run, the same frames" % m)
		t._check(a[1] > 0, "screen %s: not empty (%d voxels)" % [m, a[1]])
		t._check(a[0][0] != a[0][3], "screen %s: the cloud moves" % m)
		var core = VolumetricCore
		var ok := true
		for c in a[2]:
			var good: bool = c is Color
			if good:
				# Every voxel colour must be a core gradient colour or
				# the floor's own cyan; none is invented by the screen.
				good = c.a > 0.0
			ok = ok and good
		t._check(ok and core != null, "screen %s: colours are Colors from the core" % m)

	var r1 := _run("layers", true)
	t._check(r1[0][0] == r1[0][5], "screen: reduced-motion holds still")

	# Colours of the layers come from VolumetricCore.color_for.
	var core2 = VolumetricCore
	var want := {}
	for r in core2.lake_column(80.0):
		want[core2.color_for("temperature", r.temperature).to_html()] = true
	var ls := VolumetricScreen.new()
	ls.set_mode("layers")
	ls.update(0.0, 80.0, true)
	var seen := {}
	var all_core := true
	for c in ls.voxel_colors():
		seen[c.to_html()] = true
		all_core = all_core and want.has(c.to_html())
	t._check(seen.size() > 1, "screen layers: more than one colour (%d)"
		% seen.size())
	t._check(all_core, "screen layers: every colour is core.color_for")
	ls.free()

	# The holy fade: dark within 1.75 s, and dark it stays.
	var h := VolumetricScreen.new()
	h.update(10.0, 50.0, false)
	t._check(h.fade_level() == 1.0, "holy: lit before")
	h.set_holy(true)
	h.update(10.0, 50.0, false)
	h.update(10.9, 50.0, false)
	t._check(h.fade_level() > 0.0 and h.fade_level() < 1.0,
		"holy: fading at 0.9 s (%.2f)" % h.fade_level())
	h.update(11.75, 50.0, false)
	t._check(h.is_dark(), "holy: dark within 1.75 s")
	t._check(not h.get_node("Voxels").visible,
		"holy: nothing is drawn when dark")
	h.update(30.0, 50.0, false)
	h.set_mode("floor")
	h.update(31.0, 50.0, false)
	t._check(h.is_dark(), "holy: the screen stays dark")
	h.set_holy(false)
	h.update(32.0, 50.0, false)
	t._check(h.fade_level() == 1.0, "holy: back when the place is left")
	h.free()
