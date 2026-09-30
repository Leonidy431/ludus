## Biomes, bubble columns and the thermocline heard
## (docs/HLD_DIVE_BIOMES_BUBBLES_2026-09-30.md).  Called from
## run_tests.gd; every check goes through its _check() and _near().
##
## 1. Parity: the port gives the numbers of dive-core.js on the fixture.
## 2. Bubbles breathe with the hesychast pattern (rule 20) and swell
##    as they rise (Boyle).
## 3. Readability (TABOO 0.3 rule 59) under the operator's decision of
##    2026-09-30 (RimLight): every lake object, every trace of the Water
##    Atlas and every D6 own drawing is measured against the five biome
##    backgrounds twice: the lamp on (its light and its highlight) and
##    the lamp off (the rim light).  Holy things (the khachkar, the
##    bulla) get neither light and are measured by their body alone.
##    What falls below READABLE is listed per light in
##    tests/fixtures/biome_contrast_known.json with its reason, and the
##    list must match the measurement exactly, so a new failure and a
##    silent fix are both caught.
## 4. The thermocline is heard: the crossing shimmer and the layer echo.
## 5. The lights themselves: the model's lamp is the scene's SpotLight3D,
##    the lamp reaches where things are read, the rim light is cool and
##    comes in without a pulse, and no holy thing is dressed.
extends RefCounted

const READABLE := RimLight.READABLE
const KNOWN := "res://tests/fixtures/biome_contrast_known.json"
const LIGHTS := ["lamp", "rim"]

var t: Object
## Every measured failure per light ("lamp": the lamp on, "rim": the
## lamp off), "<kind>:<id>:<biome>" -> ratio; "before": the model before
## the decision (the lamp always on, no band).
var failures := {"lamp": {}, "rim": {}, "before": {}}
var report: Array = []
## The colours of every thing that is not holy, for the sweep off the
## reading point.
var swept: Array = []


func run(tree: Object) -> void:
	t = tree
	var fx: Dictionary = tree._load_json("res://tests/fixture.json").biomes
	_parity(fx)
	_bubbles()
	_readability()
	_lights()
	_heard()
	for line in report:
		print("  biomes: ", line)


func _parity(fx: Dictionary) -> void:
	for l in fx.looks:
		var g := DiveCore.biome_look(l.d, l.c)
		t._check(g.biome == l.biome, "biome at %s m: %s vs %s" % [l.d,
			g.biome, l.biome])
		for i in 3:
			t._near(g.water[i], l.water[i], "water %s m [%d]" % [l.d, i])
		t._near(g.fog, l.fog, "fog %s m" % l.d)
		t._near(g.ambient, l.ambient, "ambient %s m" % l.d)
		t._near(g.sun, l.sun, "sun %s m" % l.d)
	for c in fx.contrast:
		for k in DiveCore.BIOMES.size():
			t._near(DiveCore.biome_contrast(c.hex, DiveCore.BIOMES[k]),
				c.ratio[k], "contrast %s %s" % [c.hex, DiveCore.BIOMES[k]])
	for n in fx.columns.size():
		var e: Dictionary = fx.columns[n]
		var col := DiveCore.bubble_column("fx:" + e.name, 100.0 + n, 2.0 * n,
			12.0 + n * 7.0, 0.2, 3 + n, DiveSynth.BREATH[e.name])
		t._check(col.count == int(e.count), "column %s count" % e.name)
		t._near(DiveCore.bubbles_per_minute(col), e.perMinute,
			"column %s per minute" % e.name)
		for j in col.jitter.size():
			t._near(col.jitter[j].dx, e.jitter[j].dx, "jitter dx")
			t._near(col.jitter[j].phase, e.jitter[j].phase, "jitter phase")
		var times := [0.0, 7.3, 31.9, 64.25]
		for k in times.size():
			var slots := [0, 1, 4, col.count - 1]
			for s in slots.size():
				var a := DiveCore.bubble_at(col, slots[s], times[k], n != 1)
				var b: Dictionary = e.at[k][s]
				var what := "bubble %s %d at %s" % [e.name, slots[s],
					times[k]]
				t._check(a.visible == b.visible, what + " visible")
				t._near(a.x, b.x, what + " x")
				t._near(a.z, b.z, what + " z")
				t._near(a.depth, b.depth, what + " depth")
				t._near(a.size, b.size, what + " size")
		var puff_t := [0.0, 4.2, 6.5, 9.9, 13.1]
		for k in puff_t.size():
			t._near(DiveCore.bubble_puff(DiveSynth.BREATH[e.name],
				puff_t[k]), e.puff[k], "puff %s %s" % [e.name, puff_t[k]])
	var echo_in := [[10.0, 80.0], [49.0, 60.0], [55.0, 90.0], [20.0, 40.0]]
	for k in echo_in.size():
		var want = fx.layerEcho[k]
		var got := DiveCore.layer_echo(echo_in[k][0], echo_in[k][1])
		if want == null:
			t._check(got < 0.0, "no layer echo %s" % [echo_in[k]])
		else:
			t._near(got, want, "layer echo %s" % [echo_in[k]])
	var cross_in := [[49.0, 51.0], [51.0, 49.0], [30.0, 31.0], [50.0, 50.0]]
	for k in cross_in.size():
		var want = fx.crossing[k]
		t._check(DiveCore.thermo_crossing(cross_in[k][0], cross_in[k][1])
			== ("" if want == null else want), "crossing %s" % [cross_in[k]])


## The cadence is the active breath: bubbles leave only on the exhale,
## as many per minute as the pattern has breaths, and grow on the way up.
func _bubbles() -> void:
	for name in DiveSynth.BREATH:
		var p: Dictionary = DiveSynth.BREATH[name]
		var col := DiveCore.bubble_column("cad:" + name, 0.0, 0.0, 20.0,
			0.0, 4, p)
		t._near(DiveCore.bubbles_per_minute(col), 4.0 * 60.0
			/ DiveSynth.breath_cycle(p), "%s: 4 bubbles per breath" % name)
		# Count births over two minutes, and check each birth falls in an
		# exhale.
		var births := 0
		var in_exhale := true
		var cycle := DiveSynth.breath_cycle(p)
		for k in int(120.0 / cycle):
			for j in 4:
				var birth: float = k * cycle + p.inhale + p.hold_in \
					+ p.exhale * (j + 0.5) / 4.0
				births += 1
				in_exhale = in_exhale and DiveCore.bubble_puff(p, birth) > 0.0
		t._check(in_exhale, "%s: every bubble leaves on the exhale" % name)
		t._check(DiveCore.bubble_puff(p, p.inhale * 0.5) == 0.0,
			"%s: no bubbles on the inhale" % name)
		# Every bubble that has risen is larger than at birth: Boyle.
		var swell := true
		var risen := 0
		for i in col.count:
			var q := DiveCore.bubble_at(col, i, 95.0)
			if q.visible and q.depth < 15.0:
				risen += 1
				swell = swell and q.size > DiveCore.BUBBLE_R0
		t._check(risen > 0 and swell, "%s: %d risen bubbles swell" % [name,
			risen])
	var ath: Dictionary = DiveSynth.BREATH.athonite
	var c := DiveCore.bubble_column("boyle", 0.0, 0.0, 30.6, 0.0, 1, ath)
	# From 30.6 m (4.01 bar) the volume goes as 1/p, the radius as its
	# cube root: near the surface (1.01 bar) about 1.58 times the start.
	var best := 0.0
	var law := true
	var straight := true
	for i in c.count:
		var q := DiveCore.bubble_at(c, i, 200.0, false)
		if not q.visible:
			continue
		var want := pow((DiveCore.SURFACE_BAR + 30.6
			/ DiveCore.METRES_PER_BAR) / (DiveCore.SURFACE_BAR + q.depth
			/ DiveCore.METRES_PER_BAR), 1.0 / 3.0)
		law = law and absf(q.size / DiveCore.BUBBLE_R0 - want) < 1e-9
		best = maxf(best, q.size / DiveCore.BUBBLE_R0)
		straight = straight and absf(q.x - c.x - c.jitter[0].dx) < 1e-9
	t._check(law, "Boyle: radius follows the cube root of p0 / p")
	t._check(best > 1.45 and best < 1.59, "near the top x%.3f" % best)
	t._check(straight,
		"reduced motion: the column rises straight, without sway")
	report.append("cadence: basic %.1f, athonite %.1f breaths/min" % [
		60.0 / DiveSynth.breath_cycle(DiveSynth.BREATH.basic),
		60.0 / DiveSynth.breath_cycle(ath)])


## Mean colour of the opaque pixels of a D6 drawing.
func _mean_colour(path: String) -> Array:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var s := [0.0, 0.0, 0.0]
	var n := 0.0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.a8 > 16:
				s[0] += c.r
				s[1] += c.g
				s[2] += c.b
				n += 1.0
	return [s[0] / n, s[1] / n, s[2] / n]


## One thing in the five biomes under both lights, and as it was before
## the decision (DiveCore alone: the lamp always on, no band).
func _measure(kind: String, id: String, rgb: Array, holy: bool) -> void:
	if not holy:
		swept.append({"key": kind + ":" + id, "rgb": rgb})
	for b in DiveCore.BIOMES:
		var key := "%s:%s:%s" % [kind, id, b]
		var old := DiveCore.biome_contrast_rgb(rgb, b)
		if old < READABLE:
			failures.before[key] = old
		# The lamp's light on the body is the old model to the last bit:
		# the decision adds light at the outline and changes no colour.
		t._near(RimLight.contrast(rgb, b, true, true), old,
			"%s lamp-lit body is DiveCore's" % key)
		for light in LIGHTS:
			var r := RimLight.contrast(rgb, b, light == "lamp", holy)
			t._check(r >= 1.0 and r < 21.0, "%s %s ratio %.2f" % [key, light,
				r])
			if r < READABLE:
				failures[light][key] = r
		if holy:
			# Withheld, not missing: the band would have lifted it.
			t._check(RimLight.contrast(rgb, b, false, true)
				< RimLight.contrast(rgb, b, false, false),
				"%s: no rim light on the holy" % key)


## Failures grouped as in the known list: "<kind>:<id>" -> [biomes].
static func _grouped(found: Dictionary) -> Dictionary:
	var out := {}
	for k in found:
		var parts: PackedStringArray = k.split(":")
		var key := parts[0] + ":" + parts[1]
		if not out.has(key):
			out[key] = []
		out[key].append(parts[2])
	return out


static func _per_biome(found: Dictionary) -> Dictionary:
	var per := {}
	for b in DiveCore.BIOMES:
		per[b] = 0
	for k in found:
		per[k.split(":")[2]] += 1
	return per


func _readability() -> void:
	# The five backgrounds differ from each other, so the five checks are
	# five checks and not one.
	var seen := []
	for b in DiveCore.BIOMES:
		var y := DiveCore.luminance(DiveCore.biome_background(b))
		for other in seen:
			t._check(absf(y - other) > 0.001, "background %s is its own" % b)
		seen.append(y)
		var ref: Dictionary = DiveCore.BIOME_REF[b]
		var bg := RimLight.background_at(ref.depth, ref.clearance, 1.0)
		for i in 3:
			t._near(bg[i], DiveCore.biome_background(b)[i],
				"%s background with the lamp is DiveCore's" % b)
	var lake: Array = t._load_json("res://data/lake-objects-99.json").objects
	var holy := []
	for o in lake:
		# Holy by the data itself (flags from scripts/lake/lake_objects.py),
		# read here without RimLight, so the test does not grade is_holy
		# by is_holy.
		var f: Dictionary = o.get("flags", {})
		var data_holy := bool(f.get("holy", false)) \
			or bool(f.get("noInteract", false))
		t._check(RimLight.is_holy(o) == data_holy,
			"%s: is_holy follows its flags" % o.id)
		if data_holy:
			holy.append(o.id)
		_measure("lake", o.id, DiveCore.hex_rgb(o.colour), data_holy)
	var atlas: Dictionary = AtlasCore.load_data()
	for tr in AtlasTraces.place(atlas, "spare"):
		var data_holy := bool(tr.get("holy", false)) \
			or bool(tr.get("noInteract", false))
		t._check(RimLight.is_holy(tr) == data_holy,
			"%s: is_holy follows its data" % tr.id)
		if data_holy:
			holy.append(tr.id)
		_measure("atlas", tr.id, DiveCore.hex_rgb(tr.colour), data_holy)
	# A holy flag anywhere the data may put it counts.
	for thing in [{"holy": true}, {"noInteract": true},
			{"flags": {"holy": true}}, {"flags": {"noInteract": true}}]:
		t._check(RimLight.is_holy(thing), "is_holy reads %s" % thing)
	t._check(not RimLight.is_holy({"item": "bulla", "flags": {}}),
		"is_holy reads the data, not a list of names")
	# The holy on the dive line: the bulla with its cross and the
	# khachkar, and nothing else.
	t._check(holy == ["bulla.shallows.0", "khachkar"],
		"holy things without any band: %s" % [holy])
	var d6 := 0
	for dir in ["DEF-057", "DEF-058", "DEF-059"]:
		for f in DirAccess.get_files_at("res://art/derived/" + dir):
			if f.begins_with("own_") and f.ends_with(".png"):
				_measure("d6", f.get_basename(), _mean_colour(
					"res://art/derived/%s/%s" % [dir, f]), false)
				d6 += 1
	t._check(d6 == 72, "72 own drawings measured (6 kits x 12): %d" % d6)
	# No colour at all can fail under either light unless it is holy:
	# the strength K is derived for the worst body, not fitted to these.
	var worst := {"lamp": INF, "rim": INF}
	for n in 65:
		var v := n / 64.0
		for rgb in [[v, v, v], [v, v * 0.6, v * 0.35], [v * 0.4, v * 0.7, v]]:
			for b in DiveCore.BIOMES:
				for light in LIGHTS:
					worst[light] = minf(worst[light], RimLight.contrast(rgb,
						b, light == "lamp", false))
	for light in LIGHTS:
		t._check(worst[light] >= READABLE,
			"any colour under the %s reads: worst %.3f" % [light,
			worst[light]])
	var measured := {}
	for light in LIGHTS:
		measured[light] = _grouped(failures[light])
	if OS.get_environment("LUDUS_DUMP_KNOWN") == "1":
		print("KNOWN_JSON:", JSON.stringify(measured))
	var known: Dictionary = t._load_json(KNOWN)
	for light in LIGHTS:
		var listed: Dictionary = known[light]
		var missing := []
		var fixed := []
		for k in measured[light]:
			for b in measured[light][k]:
				if not b in listed.get(k, []):
					missing.append("%s:%s %.2f" % [k, b,
						failures[light][k + ":" + b]])
		for k in listed:
			for b in listed[k]:
				if not b in measured[light].get(k, []):
					fixed.append(k + ":" + b)
		t._check(missing.is_empty(), "new readability failures, %s: %s"
			% [light, missing])
		t._check(fixed.is_empty(), "fixed, drop from the %s list: %s"
			% [light, fixed])
	var pairs := (lake.size() + 6 + d6) * 5
	report.append("readability < %.1f before (lamp always on, no band): "
		% READABLE + "%d of %d %s" % [failures.before.size(), pairs,
		_per_biome(failures.before)])
	report.append("readability < %.1f lamp on (light + highlight): %d of %d %s"
		% [READABLE, failures.lamp.size(), pairs, _per_biome(failures.lamp)])
	report.append("readability < %.1f lamp off (rim light): %d of %d %s"
		% [READABLE, failures.rim.size(), pairs, _per_biome(failures.rim)])
	report.append("worst of any colour: lamp %.3f, rim %.3f" % [worst.lamp,
		worst.rim])
	_sweep()


## Off the reading point: nearer and farther along the lamp's axis, at
## the edge of its cone and outside it.  The rim light takes what the
## beam leaves, so switching the lamp on does not make a thing harder to
## read than with the lamp off (where the lamp-off reading is at least
## READABLE, the lamp-on one is too; where it is below, the lamp-on one
## is not lower).  The exceptions are measured and listed in the known
## file ("sweep_worse"), and must match exactly.  Up to SWEEP_READ_M
## every thing reads under either light, but for those; beyond it the
## fog takes things under either light, and the lamp's share there, on a
## body it lifts towards the water, may read lower than the rim light
## alone (reported, not asserted: that is the water, TABOO 0.03 p. 6).
const SWEEP_M := [1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 15.0]
const SWEEP_DEG := [0.0, 16.0, 31.0, 40.0]
const SWEEP_READ_M := 8.0


func _sweep() -> void:
	var worse := {}
	var unread := {"lamp": 0, "rim": 0}
	var far := {}
	var n := 0
	for th in swept:
		for b in DiveCore.BIOMES:
			for d in SWEEP_M:
				for a in SWEEP_DEG:
					var on := RimLight.contrast(th.rgb, b, true, false, d, a)
					var off := RimLight.contrast(th.rgb, b, false, false, d, a)
					n += 1
					var lower := on < minf(off, READABLE) - 1e-9
					if d <= SWEEP_READ_M:
						if lower:
							worse["%s:%s:%.1f:%.0f" % [th.key, b, d, a]] = on
						unread.lamp += int(on < READABLE)
						unread.rim += int(off < READABLE)
					else:
						var k := "%.0f m" % d
						if not far.has(k):
							far[k] = [0, 0, 0]
						far[k][0] += int(on < READABLE)
						far[k][1] += int(off < READABLE)
						far[k][2] += int(lower)
	var listed: Array = t._load_json(KNOWN).sweep_worse
	var got := worse.keys()
	got.sort()
	t._check(got == listed, "lamp on worse than off, as listed: %s"
		% [got])
	var lowest := INF
	for k in worse:
		lowest = minf(lowest, worse[k])
	t._check(unread.rim == 0 and unread.lamp == worse.size(),
		"up to %.0f m every thing reads (lamp on %d, off %d below %.1f)"
		% [SWEEP_READ_M, unread.lamp, unread.rim, READABLE])
	report.append("sweep 1.5-15 m, 0-40 deg off the axis, %d points: up to "
		% n + "%.0f m below %.1f lamp on %d (lowest %.3f), lamp off %d; "
		% [SWEEP_READ_M, READABLE, unread.lamp, lowest, unread.rim]
		+ "beyond (on / off / on lower) %s" % far)


## The lamp and the two lights (RimLight): the numbers the readability
## model rests on, checked against the scene's own light.
func _lights() -> void:
	# The shader's beam assumes Godot's defaults for these two.
	t._check(RimLight.LAMP_ATTENUATION == 1.0
		and RimLight.LAMP_ANGLE_ATTENUATION == 1.0,
		"lamp: 1/d and a linear cone, as lamp_beam computes")
	# The model's lamp (unit, DiveCore) is the scene's SpotLight3D 3 m
	# ahead on its axis, in the scene's surface sun: 7 % per band and 2 %
	# in luminance (0.99: its 6500 K white is a little short of red).
	var lb := RimLight.lamp_bands()
	var y: float = 0.2126 * lb[0] + 0.7152 * lb[1] + 0.0722 * lb[2]
	for i in 3:
		t._check(absf(lb[i] - 1.0) <= 0.07, "lamp band %d: %.3f of the "
			% [i, lb[i]] + "model's unit")
	t._check(absf(y - 1.0) <= 0.02, "lamp luminance %.4f of the unit" % y)
	# The range reaches past the arm: at REACH_M the range window is
	# still whole.
	t._check(RimLight.lamp_falloff(4.0, 0.0) * 4.0 >= 0.99,
		"lamp window at 4 m: %.4f" % (RimLight.lamp_falloff(4.0, 0.0) * 4.0))
	# In third person the lamp on the skid points 15 degrees down; a
	# thing VIEW_M from it with the ROV READ_CLEARANCE_M above is near
	# its axis, and the highlight there still lifts the worst body.
	var below := rad_to_deg(asin(RimLight.READ_CLEARANCE_M
		/ DiveCore.VIEW_M))
	var off := absf(below + rad_to_deg(RimLight.LAMP_PITCH_3P))
	var cone := RimLight.lamp_falloff(DiveCore.VIEW_M, off) \
		/ RimLight.lamp_falloff(DiveCore.VIEW_M, 0.0)
	var old_off := absf(below - rad_to_deg(0.12))
	var old_cone := RimLight.lamp_falloff(DiveCore.VIEW_M, old_off) \
		/ RimLight.lamp_falloff(DiveCore.VIEW_M, 0.0)
	t._check(cone >= 0.9 and cone > old_cone,
		"3p reading point %.1f deg off the axis: %.3f (was %.3f)" % [off,
		cone, old_cone])
	var max_fog := 0.0
	for b in DiveCore.FOG:
		max_fog = maxf(max_fog, DiveCore.FOG[b])
	var k_min := (1.5 - 1.0 / 1.5) / (RimLight.BAND
		* exp(-max_fog * DiveCore.VIEW_M))
	var probe := RimLight.tone(RimLight.LAMP_COLOUR, 0.127)
	var at_3p := RimLight.edge_luminance(probe, RimLight.beam(
		DiveCore.VIEW_M, off)) / RimLight.edge_luminance(probe, 1.0)
	t._check(RimLight.K >= k_min and RimLight.K * at_3p >= k_min,
		"K %.2f: needs %.3f on the axis, %.3f at the 3p point" % [
		RimLight.K, k_min, k_min / at_3p])
	var k_3p := k_min / at_3p
	# The beam falls with the lamp's own light and is zero where the
	# light is: outside the cone and past the range.
	t._check(RimLight.beam(DiveCore.VIEW_M, RimLight.LAMP_ANGLE_DEG + 1.0)
		== 0.0 and RimLight.beam(RimLight.LAMP_RANGE_M + 1.0, 0.0) == 0.0,
		"no highlight outside the beam")
	t._check(RimLight.beam(6.0, 0.0) < RimLight.beam(3.0, 0.0)
		and RimLight.beam(0.5, 0.0) == RimLight.BEAM_CAP,
		"the highlight falls with distance and is capped at the lens")
	# Colours: the lamp keeps its instrument white; the rim light is the
	# water's own hue, pale, never gold and not the instruments' cyan
	# (TABOO 0.38 p. 1): at every depth from the surface to the floor
	# its hue is the water's and its saturation at most 0.35.
	t._check(RimLight.LAMP_COLOUR == Color(0.95, 0.97, 1.0),
		"lamp stays 6500 K instrument light")
	var hue_gap := 0.0
	var sat := 0.0
	for d in range(0, 200, 5):
		var rt := RimLight.rim_tone(float(d))
		var w: Array = DiveCore.water_colour(float(d))
		var wc := Color(w[0], w[1], w[2])
		var gap := absf(rt.h - wc.h) * 360.0
		hue_gap = maxf(hue_gap, minf(gap, 360.0 - gap))
		sat = maxf(sat, rt.s)
		t._check(rt.b > rt.r, "%d m: the rim light is not gold" % d)
	t._check(hue_gap <= 10.0 and sat <= 0.35,
		"the rim light is the water's pale hue: hue within %.2f deg, "
		% hue_gap + "saturation up to %.3f" % sat)
	for b in DiveCore.BIOMES:
		var ref: Dictionary = DiveCore.BIOME_REF[b]
		var y_off := DiveCore.luminance(RimLight.background_at(ref.depth,
			ref.clearance, 0.0))
		var y_on := DiveCore.luminance(RimLight.background_at(ref.depth,
			ref.clearance, 1.0))
		var l := RimLight.lights(1.0, false, RimLight.LAMP_ENERGY, y_off,
			y_on, ref.depth)
		t._check(l.lamp == Vector3.ZERO and l.presence == 0.0
			and RimLight.rim_share(RimLight.beam(DiveCore.VIEW_M, 0.0),
			l.presence) == 1.0,
			"%s: without the lamp the rim light alone, everywhere" % b)
		var on := RimLight.lights(0.0, true, RimLight.LAMP_ENERGY, y_off,
			y_on, ref.depth)
		t._check(on.lamp != Vector3.ZERO and RimLight.rim_share(
			RimLight.beam(DiveCore.VIEW_M, 0.0), on.presence) == 0.0
			and RimLight.rim_share(RimLight.beam(DiveCore.VIEW_M,
			RimLight.LAMP_ANGLE_DEG + 1.0), on.presence) == 1.0
			and absf(RimLight.rim_share(RimLight.beam(6.0, 0.0),
			on.presence) - (1.0 - RimLight.beam(6.0, 0.0))) < 1e-9,
			"%s: with the lamp, its highlight where it reaches, the rim " % b
			+ "light for the rest")
	# The fade: FADE_S in, FADE_S out, a straight ramp, the same each
	# time (steps of an eighth of it, exact in binary).
	var dt := RimLight.FADE_S / 8.0
	var w := 0.0
	var ramp := [w]
	for k in 10:
		w = RimLight.fade(w, false, dt)
		ramp.append(w)
	var steady := true
	for k in range(1, ramp.size()):
		steady = steady and ramp[k] == minf(1.0, k / 8.0)
	t._check(steady and ramp[7] < 1.0 and ramp[8] == 1.0,
		"rim light comes in over %.1f s without a pulse" % RimLight.FADE_S)
	for k in 8:
		w = RimLight.fade(w, true, dt)
	t._check(w == 0.0, "and goes out as the lamp returns")
	# The renderer the encoding is written for (EMISSION taken as sRGB).
	t._check(ProjectSettings.get_setting("rendering/renderer/rendering_method")
		== "gl_compatibility" and ProjectSettings.get_setting(
		"rendering/renderer/rendering_method.mobile") == "gl_compatibility",
		"the lights are encoded for the Compatibility renderer")
	# The shaders: one term, no clock (nothing pulses), no noise.
	var rim := RimLight.new()
	var sm: ShaderMaterial = rim.material_for(StandardMaterial3D.new())
	var sprite := Sprite3D.new()
	sprite.texture = PlaceholderTexture2D.new()
	rim.drawing(sprite)
	for code in [sm.shader.code,
			(sprite.material_override as ShaderMaterial).shader.code]:
		t._check(code.count("EMISSION") == 1 and not "TIME" in code
			and not "random" in code, "one band term, steady")
		# Both lights in the one term, the rim light by its share.
		t._check("EMISSION = band_light * " in code and "dive_rim.rgb * "
			+ "(1.0 - min(1.0, b * dive_rim.a))\n\t\t+ dive_lamp.rgb * b" in code,
			"the band carries the highlight and the rim light's share")
	t._check("instance uniform vec3 rim_c" in sm.shader.code
		and "smoothstep(1.0 - w, 1.0, r / h)" in sm.shader.code,
		"the mesh band is the outline of the thing's box")
	sprite.free()
	_eased()
	# The khachkar keeps its plain stone; the diary gets the band on
	# every surface.
	var khachkar: Node = (load("res://models/atlas/atlas-khachkar.glb")
		as PackedScene).instantiate()
	var diary: Node = (load("res://models/atlas/atlas-diary.glb")
		as PackedScene).instantiate()
	var traces := AtlasTraces.place(AtlasCore.load_data(), "spare")
	var by_id := {}
	for tr in traces:
		by_id[tr.id] = tr
	t._check(rim.dress(khachkar, RimLight.is_holy(by_id.khachkar)) == 0
		and _shader_surfaces(khachkar) == 0,
		"the khachkar is not dressed: no band, no glow")
	var n := rim.dress(diary, RimLight.is_holy(by_id.diary))
	t._check(n > 0 and _shader_surfaces(diary) == n,
		"the diary is dressed on all %d surfaces" % n)
	# Every dressed mesh holds the whole diary's box: its centre, in
	# the diary's space, is the same from every part.
	var box := RimLight.thing_box(diary)
	var ok := box.size.x > 0.0 and box.size.y > 0.0 and box.size.z > 0.0
	for g in diary.find_children("*", "MeshInstance3D", true, false):
		var c: Vector3 = g.get_instance_shader_parameter("rim_c")
		var at := RimLight._to_ancestor(g, diary) * c
		ok = ok and at.distance_to(box.get_center()) < 1e-4
	t._check(ok, "the diary's parts share its box %s" % box)
	khachkar.free()
	diary.free()
	report.append("lamp 3 m on its axis: %.3f/%.3f/%.3f of the model's "
		% lb + "unit; 3p reading point %.2f of the axis (was %.2f); K %.2f "
		% [cone, old_cone, RimLight.K] + "(needs %.2f on the axis, %.2f at "
		% [k_min, k_3p] + "the 3p point)")


## The background the lights are sized to eases: hovering at the edge
## of the sediments (clearance 2.5 m), a step of 0.1 m moves neither
## light by more than 2 % per frame at 72 Hz, and the new background is
## reached within BACKGROUND_EASE_S.
func _eased() -> void:
	var rim := RimLight.new()
	var dt := 1.0 / 72.0
	var worst := 0.0
	var last := {}
	for depth in [35.0, 60.0]:
		rim.settle_background()
		for k in 72 * 4:
			var clearance := 2.55 if k < 72 else 2.45
			var y := rim.track_background(depth, clearance, dt)
			var l := RimLight.lights(0.0, true, RimLight.LAMP_ENERGY, y.off,
				y.on, depth)
			var now := {"rim": l.rim.length(), "lamp": l.lamp.length()}
			if k > 0:
				for key in now:
					worst = maxf(worst, absf(now[key] - last[key])
						/ last[key])
			last = now
		var want := DiveCore.luminance(RimLight.background_at(depth, 2.45,
			1.0))
		var got: float = rim.track_background(depth, 2.45, dt).on
		t._check(absf(got - want) <= 1e-6 * want,
			"%.0f m: the new background reached (%.5f of %.5f)" % [depth,
			got, want])
	t._check(worst <= 0.02, "a biome edge moves the lights %.2f %% per "
		% (100.0 * worst) + "frame at most")
	report.append("biome edge at 2.5 m: lights move at most %.2f %% per "
		% (100.0 * worst) + "frame")


## The real dive scene (run_tests.gd adds it to the tree and waits a
## frame): no holy thing carries the band, every other lake object and
## trace does, and the holy points of the scene are exactly the holy
## things.
func in_dive(scene: Node) -> void:
	var holy_at := []
	var dressed := 0
	var bare := []
	for id in scene.thing_nodes:
		var node: Node3D = scene.thing_nodes[id]
		var thing := {}
		for p in scene.placed + scene.traces:
			if p.id == id:
				thing = p
		var banded := _band_surfaces(node)
		if RimLight.is_holy(thing):
			holy_at.append(node.position)
			t._check(banded == 0, "%s is holy and carries no band (%d)"
				% [id, banded])
		elif banded > 0:
			dressed += 1
		else:
			bare.append(id)
	t._check(holy_at.size() == 2, "two holy things in the scene: %d"
		% holy_at.size())
	var points: Array = scene.holy_points
	var same := points.size() == holy_at.size()
	for p in holy_at:
		same = same and points.any(func(q): return q.distance_to(p) < 1e-3)
	t._check(same, "the scene's holy points are the holy things: %s vs %s"
		% [points, holy_at])
	t._check(bare.is_empty(), "every other thing is dressed: %s" % [bare])
	print("  biomes: dive scene: %d things dressed, %d holy bare" % [
		dressed, holy_at.size()])


## Surfaces under a node whose material carries the band.
static func _band_surfaces(node: Node) -> int:
	var n := 0
	for g in [node] + node.find_children("*", "GeometryInstance3D", true,
			false):
		if not g is GeometryInstance3D:
			continue
		var mats := []
		if g.material_override != null:
			mats.append(g.material_override)
		if g is MeshInstance3D and g.mesh != null:
			for i in g.mesh.get_surface_count():
				mats.append(g.get_active_material(i))
		for m in mats:
			if m is ShaderMaterial and m.shader != null \
					and "dive_rim" in m.shader.code:
				n += 1
	return n


## Surfaces under a node that carry a ShaderMaterial.
static func _shader_surfaces(node: Node) -> int:
	var n := 0
	var stack: Array = [node]
	while not stack.is_empty():
		var g: Node = stack.pop_back()
		stack.append_array(g.get_children())
		if g is MeshInstance3D:
			for i in g.mesh.get_surface_count():
				if g.get_active_material(i) is ShaderMaterial:
					n += 1
	return n


## The layer is heard: crossing it down glides the sonar pitch by the
## ratio of the sound speeds, and above it the sonar hears its echo.
func _heard() -> void:
	var s := DiveSynth.new()
	for k in s.layers:
		s.layers[k] = k == "events"
	var fps := 60.0
	var frames := int(DiveSynth.MIX_RATE / fps)
	var out := PackedFloat32Array()
	var depth := 49.5
	for k in 60:
		depth += 0.02
		s.update({"depth": depth}, 1.0 / fps)
		out.append_array(s.generate(frames))
	t._check(s.crossings == ["down"], "crossing down heard once: %s"
		% [s.crossings])
	var peak := 0.0
	for v in out:
		peak = maxf(peak, absf(v))
	t._check(peak > 0.005 and peak < 0.1,
		"the shimmer is quiet but there: peak %.4f" % peak)
	# The scatter sits around the ping frequency: far more power at
	# 2400 Hz than an octave and more below.
	var hi := _goertzel(out, DiveSynth.PING_HZ)
	var low := _goertzel(out, 600.0)
	t._check(hi > 20.0 * low, "the shimmer is the sonar's band: x%.0f"
		% (hi / maxf(low, 1e-12)))
	# The room steps down across the layer (darker, quieter): measured
	# on the room layer alone, 5 s at 48 m and 5 s at 52 m.
	var r48 := _only_room(48.0)
	var r52 := _only_room(52.0)
	var step := 20.0 * log(r48 / r52) / log(10.0)
	t._check(step > 2.0, "the room is %.1f dB quieter below the layer" % step)
	# Standing still at the layer does not repeat the shimmer.
	for k in 120:
		s.update({"depth": depth}, 1.0 / fps)
		s.generate(frames)
	t._check(s.crossings.size() == 1, "no shimmer while the ROV holds")
	# The layer echo: above the layer over the deep floor, the ping has
	# a second, fainter answer 2 * (50 - d) / 1480 s after it.
	var sonar := DiveSynth.new()
	for k in sonar.layers:
		sonar.layers[k] = k == "sonar"
	var d := 20.0
	var floor_echo := 2.0 * 120.0 / 1480.0
	var a := PackedFloat32Array()
	for k in int(4.5 * fps):
		sonar.update({"depth": d, "echo_delay": floor_echo,
			"layer_echo": DiveCore.layer_echo(d, 140.0)}, 1.0 / fps)
		a.append_array(sonar.generate(frames))
	var onsets := []
	var quiet := 0
	for k in a.size():
		if absf(a[k]) > 0.0:
			if quiet > int(0.005 * DiveSynth.MIX_RATE) or onsets.is_empty():
				onsets.append(k)
			quiet = 0
		else:
			quiet += 1
	t._check(onsets.size() == 3, "ping, layer echo, floor echo: %d onsets"
		% onsets.size())
	if onsets.size() == 3:
		var gap: float = (onsets[1] - onsets[0]) / DiveSynth.MIX_RATE
		t._check(absf(gap - 2.0 * 30.0 / 1480.0) <= 2.0 / DiveSynth.MIX_RATE,
			"layer echo after 2 * 30 m / c: %.4f s" % gap)
		var lp := 0.0
		var fp := 0.0
		for k in range(onsets[1], onsets[1] + 400):
			lp = maxf(lp, absf(a[k]))
		for k in range(onsets[2], onsets[2] + 400):
			fp = maxf(fp, absf(a[k]))
		t._check(lp < fp, "the layer answers fainter than the floor")
	report.append("thermocline: shimmer peak %.4f, room step %.1f dB"
		% [peak, step])


func _goertzel(a: PackedFloat32Array, f: float) -> float:
	var w := TAU * f / DiveSynth.MIX_RATE
	var c := 2.0 * cos(w)
	var s1 := 0.0
	var s2 := 0.0
	for v in a:
		var s0 := v + c * s1 - s2
		s2 = s1
		s1 = s0
	return s1 * s1 + s2 * s2 - c * s1 * s2


func _only_room(d: float) -> float:
	var s := DiveSynth.new()
	for k in s.layers:
		s.layers[k] = k == "room"
	var a := PackedFloat32Array()
	for k in 300:
		s.update({"depth": d}, 1.0 / 60.0)
		a.append_array(s.generate(int(DiveSynth.MIX_RATE / 60.0)))
	var sum := 0.0
	for k in range(a.size() / 2, a.size()):
		sum += a[k] * a[k]
	return sqrt(sum / (a.size() / 2))
