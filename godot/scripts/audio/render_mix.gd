## Offline render of the dive mix for the loudness check (TABOO 0.4
## rule 13: -16 LUFS, true peak <= -1 dBTP).
##
##   godot --headless --path godot --script res://scripts/audio/render_mix.gd \
##       -- --audio-render=<dir>
##   python3 scripts/godot/loudness.py <dir>/*.wav
##
## Each scenario is 30 s of the same DiveSynth code the headset runs,
## with the ROV held where dive.gd --shots puts it for that depth.
## The spatial water sources are added by an inverse-distance estimate
## of AudioStreamPlayer3D (no panning, no HRTF): the engine's own 3D mix
## cannot be captured headless, so this part is an approximation.
extends SceneTree

const SECONDS := 30.0
const FPS := 60.0
const NOON := {"year": 2026, "month": 9, "day": 29, "hour": 12,
	"minute": 0, "second": 0}
const CALL := {"year": 2026, "month": 9, "day": 29, "hour": 17,
	"minute": 51, "second": 0}
## name, depth, thrust, lamp, still (silence), date, x override.
const SCENARIOS := [
	["dive-003m-cruise", 3.0, 0.6, true, false, NOON, -1.0],
	["dive-060m-cruise", 60.0, 0.6, true, false, NOON, -1.0],
	["dive-120m-cruise", 120.0, 0.6, true, false, NOON, -1.0],
	["dive-120m-silence", 120.0, 0.0, false, true, NOON, -1.0],
	["surface-bell-call", 1.0, 0.3, true, false, CALL, 30.0],
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
	var fish: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/issyk-kul-fish.json")).fish
	var schools := DiveCore.fish_schools(fish)
	var loop := _loop_samples(DiveAudio.water_loop())
	for sc in SCENARIOS:
		var path := "%s/%s.wav" % [dir, sc[0]]
		var data := _render(sc, schools, loop)
		_write_wav(path, data)
		print("rendered ", path)
	quit(0)


func _loop_samples(wav: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := wav.data.size() / 2
	out.resize(n)
	for i in n:
		out[i] = wav.data.decode_s16(i * 2) / 32768.0
	return out


func _render(sc: Array, schools: Array,
		loop: PackedFloat32Array) -> PackedFloat32Array:
	var synth := DiveSynth.new()
	var rov := DiveCore.new_rov()
	var depth: float = sc[1]
	rov.x = sc[6] if sc[6] > 0.0 else DiveCore.x_for_depth(depth + 6.0) - 8.0
	rov.depth = depth
	rov.lamp = sc[3]
	var tel := DiveCore.telemetry(rov)
	var out := PackedFloat32Array()
	var frames := int(DiveSynth.MIX_RATE / FPS)
	var gain_db := db_to_linear(DiveAudio.WATER_DB)
	var start: Dictionary = sc[5]
	var u0 := Time.get_unix_time_from_datetime_dict(start)
	var pos := 0
	for k in int(SECONDS * FPS):
		var t := k / FPS
		synth.set_now(Time.get_datetime_dict_from_unix_time(u0 + int(t)))
		synth.update({"depth": depth, "thrust": sc[2], "shore_m": rov.x,
			"silence": sc[4], "echo_delay": tel.echo_delay}, 1.0 / FPS)
		var block := synth.generate(frames)
		# Water near the fish: each school in reach at its own offset.
		var here := Vector3(rov.x, -depth, rov.z)
		for i in schools.size():
			var p := DiveCore.fish_at(schools[i], 0, t)
			var d := here.distance_to(Vector3(p.x, -p.depth, p.z))
			if d > DiveAudio.WATER_MAX_M:
				continue
			var g := gain_db * minf(1.0, DiveAudio.WATER_UNIT_M / maxf(d,
				0.01))
			var off := int(fmod(i * 0.61803 * DiveAudio.WATER_LOOP_SEC,
				DiveAudio.WATER_LOOP_SEC) * DiveSynth.MIX_RATE)
			for j in frames:
				block[j] += loop[(pos + off + j) % loop.size()] * g
		pos += frames
		out.append_array(block)
	return out


## 32-bit float stereo WAV (format 3): the measurement sees the mix
## exactly, without 16-bit rounding.
func _write_wav(path: String, mono: PackedFloat32Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	var rate := int(DiveSynth.MIX_RATE)
	var bytes := mono.size() * 2 * 4
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + bytes)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(3)
	f.store_16(2)
	f.store_32(rate)
	f.store_32(rate * 2 * 4)
	f.store_16(8)
	f.store_16(32)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(bytes)
	for v in mono:
		f.store_float(v)
		f.store_float(v)
	f.close()
