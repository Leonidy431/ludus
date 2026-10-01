## The ison of the brethren near a scene kit on the path of the witness.
##
## A cappella only (CLAUDE.md TABOO 0.2 point 5, TABOO 0.35 rule 10):
## wordless voices on vowels, no text, no instrument.  Each voice is one
## period of a band-limited saw weighted by vowel formants (the
## voiceTable of ludus-sacred-synth.js): it cannot alias and costs one
## table lookup per voice and sample.  Three singers a few cents apart
## hold the tonic, an октавист an octave below them (the Russian choral
## bass), and the choir breathes on the Athonite cycle of the
## hesychasm-meditation-module (DiveSynth.BREATH, rule 20).
##
## The two kliroi sing antiphonally: one breath cycle the left, the
## next the right, the sound moving gently between the ears.  This is
## the only stereo in the ison; it is a design choice, not a claim that
## a kliros stands at a given ear.
##
## Every ison declares its tone {glas, tonic, final, vowel, kliros}, so
## a test can check what is sung without listening.
class_name IsonSynth
extends RefCounted

const MIX_RATE := 22050.0
const TABLE := 2048
const BREATH := "athonite"
const CENTS := [-3.0, 0.0, 4.0]
const OKTAVIST := 0.5
## Vowel formants (Hz, bandwidth, gain), Peterson and Barney, as in
## ludus-sacred-synth.js VOWELS: a dark "o" and an open "a".
const VOWELS := {
	"o": [[570.0, 140.0, 1.0], [840.0, 160.0, 0.55], [2410.0, 220.0, 0.18]],
	"a": [[730.0, 150.0, 1.0], [1090.0, 170.0, 0.6], [2440.0, 230.0, 0.2]],
}
## How far the sound leans towards one kliros (0 = centre, 1 = one ear).
const KLIROS_LEAN := 0.35

var decl := {}
var table := PackedFloat32Array()
var okt := PackedFloat32Array()
var phase := [0.0, 0.0, 0.0, 0.0]
## Seconds the ison has sung, for the breath and the kliros.
var sung := 0.0


## The declared tone of an ison: the tone of the week and its base note
## (LudusTypikon.GLASY), the vowel of the scene, the kliros.  glas 0
## (Holy Week has no tone of its own) declares no ison.
static func declare(glas: int, vowel: String, kliros: String) -> Dictionary:
	if glas == 0:
		return {}
	return {"glas": glas, "tonic": LudusTypikon.GLAS_TONIC[glas],
		"final": LudusTypikon.GLASY[glas].base, "vowel": vowel,
		"kliros": kliros}


static func _formant(freq: float, vowel: String) -> float:
	var g := 0.015
	for f in VOWELS[vowel]:
		var x: float = (freq - f[0]) / (f[1] / 2.0)
		g += f[2] / (1.0 + x * x)
	return g


static func voice_table(f0: float, vowel: String,
		seed_text: String) -> PackedFloat32Array:
	var r := DiveCore.rng(seed_text)
	var t := PackedFloat32Array()
	t.resize(TABLE + 1)
	var top := minf(MIX_RATE * 0.42, 5200.0)
	var h := 1
	while h * f0 < top:
		var amp := _formant(h * f0, vowel) / h
		var ph: float = r.call() * TAU
		for i in TABLE:
			t[i] += amp * sin(TAU * h * i / TABLE + ph)
		h += 1
	var peak := 0.0
	for i in TABLE:
		peak = maxf(peak, absf(t[i]))
	for i in TABLE:
		t[i] /= maxf(peak, 1e-9)
	t[TABLE] = t[0]
	return t


## Sing a declared tone; the tables are rebuilt only when it changes.
func set_decl(d: Dictionary) -> void:
	if d == decl:
		return
	decl = d
	sung = 0.0
	if d.is_empty():
		table = PackedFloat32Array()
		okt = PackedFloat32Array()
		return
	var tag := "%s:%s:%s" % [d.glas, d.vowel, d.kliros]
	table = voice_table(d.tonic, d.vowel, "ison:" + tag)
	okt = voice_table(d.tonic / 2.0, "o", "ison-okt:" + tag)


## Where the antiphony leans at t seconds: -1 left kliros, +1 right.
static func kliros_side(t: float) -> float:
	var cycle := DiveSynth.breath_cycle(DiveSynth.BREATH[BREATH])
	var n := floori(t / cycle)
	var q := fposmod(t, cycle) / cycle
	var side := -1.0 if n % 2 == 0 else 1.0
	# Cross over in the last tenth of the cycle, while the choir
	# breathes in, so the change of kliros is never a jump.
	if q > 0.9:
		side *= 1.0 - 2.0 * DiveSynth._smooth((q - 0.9) / 0.1)
	return side


## frames of stereo ison with the gain moving from g0 to g1.
func generate(frames: int, g0: float, g1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames)
	if table.is_empty() or (g0 <= 0.0 and g1 <= 0.0):
		return out
	var p: Dictionary = DiveSynth.BREATH[BREATH]
	var dur := frames / MIX_RATE
	var e0 := DiveSynth.breath_envelope(p, sung, 0.35) * g0
	var e1 := DiveSynth.breath_envelope(p, sung + dur, 0.35) * g1
	var s0 := kliros_side(sung)
	var s1 := kliros_side(sung + dur)
	var tonic: float = decl.tonic
	var inc := tonic * TABLE / MIX_RATE
	var incs := []
	for c in CENTS:
		incs.append(inc * pow(2.0, c / 1200.0))
	var i0: float = incs[0]
	var i1: float = incs[1]
	var i2: float = incs[2]
	var io := inc * 0.5
	var p0: float = phase[0]
	var p1: float = phase[1]
	var p2: float = phase[2]
	var p3: float = phase[3]
	var t := table
	var o := okt
	for i in frames:
		p0 = fmod(p0 + i0, TABLE)
		p1 = fmod(p1 + i1, TABLE)
		p2 = fmod(p2 + i2, TABLE)
		p3 = fmod(p3 + io, TABLE)
		var a := int(p0)
		var b := int(p1)
		var c := int(p2)
		var d := int(p3)
		var v := (t[a] + (t[a + 1] - t[a]) * (p0 - a)
			+ t[b] + (t[b + 1] - t[b]) * (p1 - b)
			+ t[c] + (t[c + 1] - t[c]) * (p2 - c)) / 3.0 \
			+ (o[d] + (o[d + 1] - o[d]) * (p3 - d)) * OKTAVIST
		var f := float(i) / frames
		var g := lerpf(e0, e1, f)
		var side := lerpf(s0, s1, f) * KLIROS_LEAN
		out[i] = Vector2(v * g * (1.0 - side), v * g * (1.0 + side)) \
			/ (1.0 + KLIROS_LEAN)
	phase = [p0, p1, p2, p3]
	sung += dur
	return out
