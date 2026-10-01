## The soft sound of one's own breath at the lectern of the rope: one
## breath cycle of RopeCore.BREATH, computed here, no recording.  It is
## air, not voice: a low-passed noise from an integer xorshift seeded by
## the pattern's name, so it sounds the same every time and a test can
## measure it (TABOO 0.35 rule 8; nothing random).  The shape is the
## breath envelope of ludus-sacred-synth.js as DiveSynth ports it, and
## the level is DiveSynth's breath, about -45 dBFS RMS: breath near the
## floor of hearing, never a loud cue and never digital zero.
class_name RopeBreath
extends RefCounted

const RATE := 22050
## RMS of the cycle: -45 dBFS, the level the dive's breath is calibrated
## to (DiveSynth.BREATH_LEVEL is that layer's amplitude, not its RMS).
## It is played unpositioned: it is one's own breath, not the lectern's.
const LEVEL := 0.0056234
## Room tone under the breath, so the holds are quiet, not dead.
const FLOOR := 0.08


static func _seed(name: String) -> int:
	var h := 2166136261
	for ch in name.to_utf8_buffer():
		h = ((h ^ ch) * 16777619) & 0xFFFFFFFF
	return h if h != 0 else 1


## One cycle of the pattern as samples in [-1, 1].
static func render(name: String) -> PackedFloat32Array:
	var p: Dictionary = RopeCore.BREATH[name]
	var n := int(round(RopeCore.cycle(name) * RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var s := _seed("rope:" + name)
	var lp := 0.0
	var lp2 := 0.0
	var raw := PackedFloat32Array()
	raw.resize(n)
	var sum := 0.0
	for i in n:
		s ^= (s << 13) & 0xFFFFFFFF
		s ^= s >> 17
		s ^= (s << 5) & 0xFFFFFFFF
		var white := float(s & 0xFFFF) / 32768.0 - 1.0
		# Two gentle poles: breath through the nose is soft, not a hiss.
		lp += 0.08 * (white - lp)
		lp2 += 0.2 * (lp - lp2)
		var env := DiveSynth.breath_envelope(p, float(i) / RATE, FLOOR)
		raw[i] = lp2 * env
		sum += raw[i] * raw[i]
	var rms := sqrt(sum / maxf(1.0, float(n)))
	var k := LEVEL / rms if rms > 0.0 else 0.0
	for i in n:
		out[i] = clampf(raw[i] * k, -1.0, 1.0)
	return out


static func stream(name: String) -> AudioStreamWAV:
	var pcm := render(name)
	var bytes := PackedByteArray()
	bytes.resize(pcm.size() * 2)
	for i in pcm.size():
		bytes.encode_s16(i * 2, int(round(pcm[i] * 32767.0)))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
