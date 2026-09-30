## Biomes, bubble columns and the thermocline heard
## (docs/HLD_DIVE_BIOMES_BUBBLES_2026-09-30.md).  Called from
## run_tests.gd; every check goes through its _check() and _near().
##
## 1. Parity: the port gives the numbers of dive-core.js on the fixture.
## 2. Bubbles breathe with the hesychast pattern (rule 20) and swell
##    as they rise (Boyle).
## 3. Readability (TABOO 0.3 rule 59): every lake object, every trace of
##    the Water Atlas and every D6 own drawing is measured against the
##    five biome backgrounds; what falls below READABLE is listed in
##    tests/fixtures/biome_contrast_known.json with its reason, and the
##    list must match the measurement exactly, so a new failure and a
##    silent fix are both caught.
## 4. The thermocline is heard: the crossing shimmer and the layer echo.
extends RefCounted

const READABLE := 1.5
const KNOWN := "res://tests/fixtures/biome_contrast_known.json"

var t: Object
## Every measured failure, "<kind>:<id>:<biome>" -> ratio.
var failures := {}
var report: Array = []


func run(tree: Object) -> void:
	t = tree
	var fx: Dictionary = tree._load_json("res://tests/fixture.json").biomes
	_parity(fx)
	_bubbles()
	_readability()
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


func _measure(kind: String, id: String, rgb: Array) -> void:
	for b in DiveCore.BIOMES:
		var r := DiveCore.biome_contrast_rgb(rgb, b)
		t._check(r >= 1.0 and r < 21.0, "%s %s %s ratio %.2f" % [kind, id,
			b, r])
		if r < READABLE:
			failures["%s:%s:%s" % [kind, id, b]] = r


func _readability() -> void:
	# The five backgrounds differ from each other, so the five checks are
	# five checks and not one.
	var seen := []
	for b in DiveCore.BIOMES:
		var y := DiveCore.luminance(DiveCore.biome_background(b))
		for other in seen:
			t._check(absf(y - other) > 0.001, "background %s is its own" % b)
		seen.append(y)
	var lake: Array = t._load_json("res://data/lake-objects-99.json").objects
	for o in lake:
		_measure("lake", o.id, DiveCore.hex_rgb(o.colour))
	var atlas: Dictionary = AtlasCore.load_data()
	for tr in AtlasTraces.place(atlas, "spare"):
		_measure("atlas", tr.id, DiveCore.hex_rgb(tr.colour))
	var d6 := 0
	for dir in ["DEF-057", "DEF-058", "DEF-059"]:
		for f in DirAccess.get_files_at("res://art/derived/" + dir):
			if f.begins_with("own_") and f.ends_with(".png"):
				_measure("d6", f.get_basename(), _mean_colour(
					"res://art/derived/%s/%s" % [dir, f]))
				d6 += 1
	t._check(d6 == 72, "72 own drawings measured (6 kits x 12): %d" % d6)
	# The known list is grouped: "<kind>:<id>" -> [biomes below READABLE].
	var measured := {}
	for k in failures:
		var parts: PackedStringArray = k.split(":")
		var key := parts[0] + ":" + parts[1]
		if not measured.has(key):
			measured[key] = []
		measured[key].append(parts[2])
	if OS.get_environment("LUDUS_DUMP_KNOWN") == "1":
		print("KNOWN_JSON:", JSON.stringify(measured))
	var known: Dictionary = t._load_json(KNOWN).failures
	var missing := []
	var fixed := []
	for k in measured:
		for b in measured[k]:
			if not b in known.get(k, []):
				missing.append("%s:%s %.2f" % [k, b, failures[k + ":" + b]])
	for k in known:
		for b in known[k]:
			if not b in measured.get(k, []):
				fixed.append(k + ":" + b)
	t._check(missing.is_empty(), "new readability failures: %s" % [missing])
	t._check(fixed.is_empty(), "fixed, drop from the known list: %s" % [fixed])
	var per := {}
	for k in failures:
		var parts: PackedStringArray = k.split(":")
		per[parts[0] + ":" + parts[2]] = per.get(parts[0] + ":" + parts[2],
			0) + 1
	report.append("readability < %.1f: %d of %d (%s)" % [READABLE,
		failures.size(), (lake.size() + 6 + d6) * 5, per])


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
