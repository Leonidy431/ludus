## The sound of the 99 places and of the courtyard (track A of docs/
## HLD_APK_GRAPHICS_SOUND_2026-10-01.md): what can be proved without a
## headset.  Called from run_hub_tests.gd; every check goes through its
## _check().
##
##   - every one of the 99 places has a plan: room tone and breath in
##     -40...-50 dBFS, its crafts from the reference medians, at most
##     PlaceSound.MAX_CRAFTS of them, a machine only where the light is
##     an instrument's, no bell and no ison;
##   - by a holy thing the machine layer is at -60 dBFS or below;
##   - the courtyard's bell is struck only by the Typikon's clock: no
##     script but WitnessAudio strikes a bell, and walking the courtyard
##     at an hour without a cue rings nothing;
##   - levels: the loops are rendered offline and measured (RMS as
##     planned, peak at or below -1 dBFS, no digital zero), and so is the
##     mix at the heart, the door and the holy thing;
##   - the same place sounds the same, sample for sample; loops have no
##     seam; the mix rate is 44100 Hz.
extends RefCounted

## Places whose loops are rendered here: every voice and every bed kind
## at least once (the tool renders all 99 for the review).
const RENDERED := ["forge", "pottery", "water-mill", "weaving", "shipyard",
	"print-shop", "obitel-shore", "deacon-cell", "apiary", "storm-bay",
	"sunken-chapel", "zero-board", "naos", "signal-tower"]
const MIX_SEC := 6.0


func run(t: Object) -> void:
	var items: Array = load("res://tools/render_place_audio.gd").plans()
	t._check(items.size() == 100, "plans: 99 places and the courtyard, %d"
		% items.size())
	var refs := PlaceSound.references()
	var by_id := {}
	var voices := {}
	for item in items:
		var pl: Dictionary = item.plan
		by_id[pl.id] = item
		_plan(t, pl, refs)
		for c in pl.crafts:
			voices[c.voice] = true
	for v in ["impacts", "wheel", "strokes", "lapping", "hearth", "buzz",
			"rain"]:
		t._check(voices.has(v), "some place has the voice " + v)
	var hub: Dictionary = by_id["hub-courtyard"].plan
	t._check(hub.bell and not hub.ison, "courtyard: bell, no ison")
	t._check(PlaceSound.players(hub) == 6, "courtyard: six players")
	_holy(t, items)
	_bell(t, hub)
	_strikers(t)
	_levels(t, by_id)
	_determinism(t, by_id)


func _plan(t: Object, pl: Dictionary, refs: Dictionary) -> void:
	var id: String = pl.id
	var bed: Dictionary = pl.bed
	t._check(bed.room_db <= -40.0 and bed.room_db >= -50.0
		and bed.breath_db <= -40.0 and bed.breath_db >= -50.0,
		id + ": room tone and breath in -40...-50 dBFS")
	t._check(RopeCore.BREATH.has(bed.breath), id + ": breath pattern")
	t._check(pl.crafts.size() <= PlaceSound.MAX_CRAFTS,
		id + ": at most %d crafts" % PlaceSound.MAX_CRAFTS)
	t._check(PlaceSound.players(pl) <= 6, id + ": players %d"
		% PlaceSound.players(pl))
	if id != "hub-courtyard":
		t._check(not pl.bell, id + ": no bell in a place")
		t._check(PlaceSound.players(pl) <= 5, id + ": at most 5 players")
	t._check(not pl.ison, id + ": no ison (never with the bell)")
	var seen := {}
	for c in pl.crafts:
		t._check(refs.has(c.ref.slot) and c.ref.centroid > 0.0,
			id + "/" + c.craft + ": reference median " + c.ref.slot)
		t._check(c.pos is Vector3, id + "/" + c.craft + ": placed")
		t._check(str(c.meaning) != "", id + "/" + c.craft + ": meaning")
		t._check(not seen.has(c.craft), id + ": one " + c.craft)
		seen[c.craft] = true
		if pl.biome == "water":
			t._check(false, id + ": no shore craft under water")
	# The courtyard's light is the hearth's, and its one instrument is
	# the ROV on the pier, lit at 6500 K (hub.gd _build_pier).
	var instrument: bool = pl.light == "instrument" or id == "hub-courtyard"
	t._check((pl.machine != null) == instrument,
		id + ": machine only with instrument light")
	if pl.machine != null:
		t._check(pl.machine.ref.centroid > 0.0
			and pl.machine.click.centroid > 0.0, id + ": machine refs")
		t._check((pl.machine.pos == null) == (pl.biome == "water"),
			id + ": machine placed unless under water")


## By every holy thing the machine layer sits at -60 dBFS or below at
## its source, and is fully open away from it.
func _holy(t: Object, items: Array) -> void:
	var holy_places := 0
	var with_spot := 0
	for item in items:
		var pl: Dictionary = item.plan
		for spot in item.spots:
			if spot.name == "holy":
				with_spot += 1
		if pl.holy.is_empty():
			continue
		holy_places += 1
		for h in pl.holy:
			var open := PlaceSound.machine_open(pl, h)
			t._check(open == 0.0, pl.id + ": by the holy thing the "
				+ "machine is closed")
			if pl.machine != null:
				var at: float = pl.machine.rms_db \
					+ PlaceSound.machine_gain_db(pl, open)
				t._check(at <= PlaceSound.HOLY_DB + 1e-6,
					"%s: machine by the holy thing %.1f dBFS" % [pl.id, at])
		var far: Vector3 = pl.holy[0] + Vector3(5.0, 0.0, 0.0)
		t._check(PlaceSound.machine_open(pl, far) == 1.0 or pl.holy.size()
			> 1, pl.id + ": machine open away from the holy thing")
	# Every placed holy thing is in its plan (santash-pass's cross is
	# still to be drawn, so it stands in no place yet).
	t._check(holy_places == with_spot and holy_places >= 9,
		"holy places with a plan: %d of %d" % [holy_places, with_spot])


## The bell clock of the courtyard: at an hour without a cue, walking
## and standing everywhere rings nothing; at a cue's hour the Typikon
## rings, with its reason, and the ison never sounds with it.
func _bell(t: Object, hub: Dictionary) -> void:
	var day := {"year": 2026, "month": 10, "day": 1}
	var plan := TypikonCore.day_plan(day)
	t._check(not plan.is_empty(), "bell: the Typikon has cues on 1 Oct")
	# A quiet minute: the first full minute after midnight-plus-an-hour
	# that no cue covers.
	var quiet := -1
	for m in range(60, 24 * 60):
		var sec := m * 60.0
		var busy := false
		for p in plan:
			if sec + 60.0 > p.start and sec < p.end:
				busy = true
		if not busy:
			quiet = m
			break
	t._check(quiet >= 0, "bell: a quiet minute exists")
	var audio := PlaceAudio.new()
	audio.plan = hub
	var clock := PlaceAudio.make_bell_clock({"year": 2026, "month": 10,
		"day": 1, "hour": quiet / 60, "minute": quiet % 60, "second": 0})
	t._check(not clock.layers.ison and not clock.layers.room,
		"bell clock: only the bell layer")
	var spots := [Vector3(0, 0, 3), Vector3(8.4, 0, 0), Vector3(-6.0, 0, 0),
		Vector3(-3.0, 0, 3.2), Vector3(4.0, 0, 3.8)]
	for k in 40:
		audio.listen(spots[k % spots.size()])
		clock.generate(735)
	t._check(clock.rung.is_empty() and clock.bells.ringing.is_empty(),
		"bell: walking the courtyard at a quiet hour rings nothing")
	# At the start of the first cue the Typikon rings.
	var p0: Dictionary = plan[0]
	var at := int(p0.start)
	clock.set_now({"year": 2026, "month": 10, "day": 1, "hour": at / 3600,
		"minute": (at % 3600) / 60, "second": at % 60})
	for k in 20:
		clock.bells.warm(1 << 30)
		clock.generate(735)
	t._check(not clock.rung.is_empty() and str(clock.rung[0].reason) != "",
		"bell: the Typikon rings at %s with its reason" % p0.cue.id)
	t._check(clock.overlap_samples == 0, "bell: never with the ison")
	audio.free()


## No script strikes a bell but the Typikon's clock (WitnessAudio):
## the place scripts have no way to ring one.
func _strikers(t: Object) -> void:
	var found := []
	for dir in ["res://scripts", "res://scripts/audio"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir + "/" + f)
			if text.contains(".strike("):
				found.append(f)
	t._check(found == ["witness_audio.gd"],
		"bell: only witness_audio.gd strikes (%s)" % str(found))
	for f in ["place_sound.gd", "place_synth.gd", "place_audio.gd"]:
		var text := FileAccess.get_file_as_string("res://scripts/audio/"
			+ f)
		t._check(not text.contains("strike(") and not text.contains(
			"_strike"), f + ": no strike")


func _levels(t: Object, by_id: Dictionary) -> void:
	var tool = load("res://tools/render_place_audio.gd")
	for id in RENDERED + ["hub-courtyard"]:
		var item: Dictionary = by_id[id]
		var pl: Dictionary = item.plan
		var loops := PlaceAudio.render_all(pl)
		for v in PlaceAudio.voices(pl):
			var a: PackedFloat32Array = loops[v[0]]
			var want: float
			match v[1]:
				"bed":
					want = NAN
				"craft":
					want = pl.crafts[v[2]].rms_db
				_:
					want = pl.machine.rms_db
			var r := PlaceSynth.dbfs(PlaceSynth.rms(a))
			var pk := PlaceSynth.dbfs(PlaceSynth.peak(a))
			if v[1] == "bed":
				t._check(r >= -50.0 and r <= -40.0,
					"%s bed: %.2f dBFS RMS in -50...-40" % [id, r])
				_seam(t, a, id + " bed")
			else:
				t._check(absf(r - want) < 0.05, "%s %s: %.2f dBFS as %.1f"
					% [id, v[0], r, want])
			t._check(pk <= -1.0, "%s %s: peak %.2f dBFS" % [id, v[0], pk])
			t._check(a.size() == int(round((pl.bed.loop if v[1] == "bed"
				else pl.crafts[v[2]].loop if v[1] == "craft"
				else pl.machine.loop) * PlaceSound.RATE)),
				id + " " + v[0] + ": loop length")
		for spot in item.spots:
			var mix: PackedFloat32Array = tool.mix_at(pl, loops, spot.pos,
				MIX_SEC)
			var s: Dictionary = tool.stats(mix)
			t._check(s.rms_db >= -50.0 and s.rms_db <= -20.0
				and s.peak_db <= -1.0 and s.longest_zero < 2,
				"%s at %s: %s" % [id, spot.name, str(s)])
			if spot.name == "holy" and pl.machine != null:
				var m: PackedFloat32Array = tool.machine_at(pl, loops,
					spot.pos, MIX_SEC)
				var md := PlaceSynth.dbfs(PlaceSynth.rms(m))
				t._check(md <= -60.0 + 0.05,
					"%s: machine by the holy thing %.2f dBFS" % [id, md])
	var w := PlaceSynth.stream(PlaceSynth.render_bed(by_id["naos"].plan.bed))
	t._check(w.mix_rate == 44100 and w.loop_mode
		== AudioStreamWAV.LOOP_FORWARD, "stream: 44100 Hz, looped")


## The jump across the seam is no larger than the loop's own steps.
func _seam(t: Object, a: PackedFloat32Array, what: String) -> void:
	var biggest := 0.0
	for i in range(1, a.size()):
		biggest = maxf(biggest, absf(a[i] - a[i - 1]))
	var jump := absf(a[0] - a[a.size() - 1])
	t._check(jump <= biggest, "%s: seam %.6f within steps %.6f"
		% [what, jump, biggest])


func _determinism(t: Object, by_id: Dictionary) -> void:
	var items: Array = load("res://tools/render_place_audio.gd").plans(
		["forge"])
	t._check(str(items[0].plan) == str(by_id["forge"].plan),
		"determinism: the same plan twice")
	var pl: Dictionary = by_id["forge"].plan
	var a := PlaceSynth.render_craft(pl.crafts[0])
	var b := PlaceSynth.render_craft(pl.crafts[0])
	t._check(a == b, "determinism: the same forge loop twice")
	var c := PlaceSynth.render_bed(pl.bed)
	var d := PlaceSynth.render_bed(pl.bed)
	t._check(c == d, "determinism: the same bed twice")
