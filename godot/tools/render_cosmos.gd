## Offline render of the suite «Наука. Любовь. Познание.» with the same
## CosmosSynth the headset runs, for the ear, the loudness check and the
## cost on the CPU.
##
##   godot --headless --path godot --script res://tools/render_cosmos.gd \
##       -- --out=<dir> [--seconds=40]
##   python3 scripts/godot/loudness.py <dir>/*.wav
##
## Writes one WAV per node (each cue alone) and suite.wav, the nine
## nodes in the order of the pilot with the morph between them, and
## prints how long the synth took per second of sound.
extends SceneTree

const ORDER := ["I", "V", "VI", "III", "II", "VIII", "VII", "IV", "IX"]


func _initialize() -> void:
	var dir := ""
	var seconds := 40.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
	if dir == "":
		printerr("usage: -- --out=<dir> [--seconds=40]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var spent := 0.0
	var made := 0.0
	for id in ORDER:
		var s := CosmosSynth.new()
		s.set_cue(id)
		var t0 := Time.get_ticks_usec()
		var buf := s.generate(int(seconds * CosmosSynth.MIX_RATE))
		spent += (Time.get_ticks_usec() - t0) / 1e6
		made += seconds
		_save(dir + "/cosmos-%s.wav" % id, buf)
	var suite := CosmosSynth.new()
	var all := PackedVector2Array()
	for id in ORDER:
		suite.set_cue(id)
		all.append_array(suite.generate(int(seconds
			* CosmosSynth.MIX_RATE)))
	_save(dir + "/suite.wav", all)
	print("cosmos: %.1f s of sound in %.2f s of CPU, %.1f %% of one core"
		% [made, spent, 100.0 * spent / made])
	quit(0)


func _save(path: String, buf: PackedVector2Array) -> void:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.stereo = true
	w.mix_rate = int(CosmosSynth.MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 4)
	for i in buf.size():
		bytes.encode_s16(i * 4, int(clampf(buf[i].x, -1.0, 1.0) * 32767.0))
		bytes.encode_s16(i * 4 + 2,
			int(clampf(buf[i].y, -1.0, 1.0) * 32767.0))
	w.data = bytes
	w.save_to_wav(path)
