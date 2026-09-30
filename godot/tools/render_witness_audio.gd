## Offline render of the path of the witness for measurement
## (docs/HLD_WITNESS_SOUND_2026-09-30.md, phase W4):
##
##   godot --headless --path godot \
##       --script res://tools/render_witness_audio.gd \
##       -- --audio-render=<dir>
##   python3 godot/tools/witness_wav_check.py <dir>
##
## The same WitnessAudio code the headset runs, fed at 30 frames a
## second as witness.gd feeds it.  32-bit float stereo WAV, so the
## measurement sees the mix exactly.
extends SceneTree

const RATE := 22050
## name, local moment, where the walker stands, seconds, layers.
const SCENARIOS := [
	["room", "2026-09-30T12:00:00", "between", 20.0, ["room"]],
	["ison-font", "2026-09-30T12:00:00", "font", 40.0, ["room", "ison"]],
	["ison-alone", "2026-09-30T12:00:00", "font", 40.0, ["ison"]],
	["vespers-call", "2026-09-30T17:49:40", "font", 60.0,
		["room", "ison", "bell"]],
	["blagovest-alone", "2026-09-30T17:50:00", "between", 12.0, ["bell"]],
	["trezvon-pascha", "2026-04-12T11:59:58", "between", 30.0,
		["room", "ison", "bell"]],
	["trezvon-alone", "2026-04-12T12:00:00", "between", 28.0, ["bell"]],
]


func _initialize() -> void:
	var dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audio-render="):
			dir = arg.trim_prefix("--audio-render=")
	if dir == "":
		printerr("usage: -- --audio-render=<dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var witness_z := {}
	for id in WitnessCore.ORDER:
		var kit := (load("res://models/scene/sacrament-%s.glb" % id)
			as PackedScene).instantiate() as Node3D
		for c in kit.find_children("*", "Node3D", true, false):
			if String(c.name).to_lower().contains("witness"):
				witness_z[id] = (c as Node3D).position.z
		kit.free()
	var bays := WitnessCore.bays(witness_z)
	var spots := {"font": Vector3(bays[0].x, 0, bays[0].side * 1.5),
		"between": Vector3(bays[0].x + 7.5, 0, 0)}
	for sc in SCENARIOS:
		var a := WitnessAudio.new()
		for k in a.layers:
			a.layers[k] = k in sc[4]
		a.set_now(Time.get_datetime_dict_from_datetime_string(sc[1],
			false))
		var t0 := Time.get_ticks_msec()
		var out := PackedVector2Array()
		var frames := int(sc[3] * RATE)
		while out.size() < frames:
			a.bells.warm(1 << 30)
			a.listen(spots[sc[2]], bays)
			out.append_array(a.generate(mini(735, frames - out.size())))
		var ms := Time.get_ticks_msec() - t0
		var path := "%s/%s.wav" % [dir, sc[0]]
		_write_wav(path, out)
		print("%s: %.1f s in %d ms, overlap %d, rung %s, ison %s" % [
			sc[0], sc[3], ms, a.overlap_samples,
			a.rung.map(func(r): return r.cue), a.ison.decl])
	# One stroke of the благовестник at strength 0.9, alone, and its
	# partials as the model states them, for the spectrum check.
	var bells := BellSynth.new()
	bells.strike(0, 0.9, 0)
	var clip := bells.generate(int(BellSynth.ring_of(0) * RATE))
	var stereo := PackedVector2Array()
	for v in clip:
		stereo.append(Vector2(v, v) * WitnessAudio.BELL_GAIN)
	_write_wav("%s/stroke-blagovestnik.wav" % dir, stereo)
	var spec := BellSynth.spec(0)
	var lines := []
	for p in spec.partials:
		lines.append("%s %.4f %.4f" % [p.name, p.freq, p.split])
	var f := FileAccess.open("%s/stroke-blagovestnik.txt" % dir,
		FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("stroke: ", lines)
	quit(0)


func _write_wav(path: String, buf: PackedVector2Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	var bytes := buf.size() * 2 * 4
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + bytes)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(3)
	f.store_16(2)
	f.store_32(RATE)
	f.store_32(RATE * 2 * 4)
	f.store_16(8)
	f.store_16(32)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(bytes)
	for v in buf:
		f.store_float(v.x)
		f.store_float(v.y)
	f.close()
