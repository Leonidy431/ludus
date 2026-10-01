## Offline render of the places' sound (track A of docs/HLD_APK_
## GRAPHICS_SOUND_2026-10-01.md), for the level check:
##
##   godot --headless --path godot --script res://tools/render_place_audio.gd \
##       -- [--out=<dir>] [--only=a,b,c] [--seconds=20]
##
## For every place (and the courtyard of the obitel, "hub-courtyard")
## the loops of its plan are rendered by the same PlaceSynth code the
## headset runs, then mixed for a listener at the heart, at the door
## and, where the place has a holy thing, beside it.  The crafts are
## added by the inverse-distance law of AudioStreamPlayer3D with unit
## size 1 m (no panning, no HRTF: the engine's own 3D mix cannot be
## captured headless, so this part is an approximation), and the
## machine layer with the gain PlaceSound gives it at that spot.  With
## --out each mix is written as a 44100 Hz float WAV.  The last line is
## "PLACE_AUDIO_JSON {summary}".
extends SceneTree

var seconds := 20.0


func _initialize() -> void:
	var out_dir := ""
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(",", false))
		elif a.begins_with("--seconds="):
			seconds = float(a.trim_prefix("--seconds="))
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	var rows := []
	for item in plans(only):
		var pl: Dictionary = item.plan
		var t0 := Time.get_ticks_usec()
		var loops := PlaceAudio.render_all(pl)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var row := {"id": pl.id, "render_ms": snappedf(ms, 0.1),
			"players": PlaceSound.players(pl),
			"pcm_bytes": PlaceSound.pcm_bytes(pl), "loops": {}, "mix": {}}
		for k in loops:
			row.loops[k] = {"rms_db": snappedf(PlaceSynth.dbfs(
				PlaceSynth.rms(loops[k])), 0.01), "peak_db": snappedf(
				PlaceSynth.dbfs(PlaceSynth.peak(loops[k])), 0.01)}
		for spot in item.spots:
			var mix := mix_at(pl, loops, spot.pos, seconds)
			row.mix[spot.name] = stats(mix)
			if out_dir != "":
				write_wav("%s/%s-%s.wav" % [out_dir, pl.id, spot.name], mix)
		rows.append(row)
		print(JSON.stringify(row))
	var worst := {"render_ms": 0.0, "players": 0, "pcm_bytes": 0}
	for r in rows:
		for k in worst:
			worst[k] = maxf(worst[k], r[k])
	print("PLACE_AUDIO_JSON ", JSON.stringify({"places": rows.size(),
		"worst": worst}))
	quit(0)


## Every place's plan with the spots it is heard from.
static func plans(only := []) -> Array:
	var data := LocationCore.load_data()
	var items := LocationCore.load_items()
	var kits := LocationCore.load_kits()
	var out := []
	if only.is_empty() or "hub-courtyard" in only:
		var hub := PlaceSound.hub_plan([Vector3(-6.6, 0.0, 0.0)])
		out.append({"plan": hub, "spots": [
			{"name": "courtyard", "pos": Vector3(0, 0, 3)},
			{"name": "pier", "pos": Vector3(7.6, 0, 0)},
			{"name": "holy", "pos": Vector3(-6.0, 0, 0)}]})
	for loc in data.locations:
		if not only.is_empty() and not loc.id in only:
			continue
		var p := LocationCore.plan(loc, data.things, items, kits)
		var pl := PlaceSound.plan(p)
		var spots := [{"name": "heart", "pos": p.heart + Vector3(0, 0, 1.3)},
			{"name": "door", "pos": p.start}]
		if p.holy_at != null:
			spots.append({"name": "holy", "pos": p.holy_at})
		out.append({"plan": pl, "spots": spots})
	return out


## The mix a listener at pos hears, mono, as long as seconds.
static func mix_at(pl: Dictionary, loops: Dictionary, pos: Vector3,
		secs: float) -> PackedFloat32Array:
	var n := int(secs * PlaceSound.RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for v in PlaceAudio.voices(pl):
		var loop: PackedFloat32Array = loops[v[0]]
		var g := 1.0
		var at = null
		if v[1] == "craft":
			at = pl.crafts[v[2]].pos
		elif v[1] == "machine":
			at = pl.machine.pos
			g *= db_to_linear(PlaceSound.machine_gain_db(pl,
				PlaceSound.machine_open(pl, pos)))
		if at != null:
			var d: float = (at as Vector3).distance_to(pos + Vector3(0, 1.6,
				0))
			if d > PlaceAudio.MAX_DISTANCE_M:
				continue
			g /= maxf(d, 0.01)
		for i in n:
			out[i] += loop[i % loop.size()] * g
	return out


## The machine layer alone as heard at pos (for the holy check).
static func machine_at(pl: Dictionary, loops: Dictionary, pos: Vector3,
		secs: float) -> PackedFloat32Array:
	var only := pl.duplicate()
	only.crafts = []
	var n := int(secs * PlaceSound.RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	if pl.machine == null:
		return out
	var g := db_to_linear(PlaceSound.machine_gain_db(pl,
		PlaceSound.machine_open(pl, pos)))
	var loop: PackedFloat32Array = loops.machine
	for i in n:
		out[i] = loop[i % loop.size()] * g
	return out


static func stats(a: PackedFloat32Array) -> Dictionary:
	var run := 0
	var longest := 0
	for v in a:
		if v == 0.0:
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
	return {"rms_db": snappedf(PlaceSynth.dbfs(PlaceSynth.rms(a)), 0.01),
		"peak_db": snappedf(PlaceSynth.dbfs(PlaceSynth.peak(a)), 0.01),
		"longest_zero": longest}


## 32-bit float mono WAV (format 3) at 44100 Hz.
static func write_wav(path: String, mono: PackedFloat32Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	var rate := PlaceSound.RATE
	var bytes := mono.size() * 4
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + bytes)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(3)
	f.store_16(1)
	f.store_32(rate)
	f.store_32(rate * 4)
	f.store_16(4)
	f.store_16(32)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(bytes)
	for v in mono:
		f.store_float(v)
	f.close()
