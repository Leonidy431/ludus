## The bells of the far monastery, heard on the path of the witness.
##
## A port of the bell model of ludus-sacred-synth.js (bellSpec,
## strokeClip, addModes), which follows kolokol ch. 12: five principal
## partials, hum, prime, tierce (minor), quint and nominal, at 0.5, 1,
## 1.2, 1.5 and 2 times the prime, each with a small fixed detuning
## seeded by the bell's own name (old Russian bells stray from exact
## intervals).  Hum and prime are doublets: the bell is not perfectly
## round, so each of these modes is two close frequencies, which gives
## the slow warble of a living bell.  The upper partials die too fast
## for a warble to be heard, so they are single, as in the JS model.
##
## The partial table and the seeded generator are DiveSynth's and
## DiveCore's, so the благовестник here is the same bell, to the last
## digit, as the shore bell of the dive and as bellSpec(0) of the web
## (tests/test_witness_sound.gd compares them).
##
## A stroke is rendered once per bell and strength (to 0.1) and then
## mixed, as the JS strokeCache does: a трезвон strikes eight bells a
## hundred times.  On the headset the clips are rendered on a worker
## thread (warm_async), so no frame waits for a bell; tests and the
## offline render use warm() on the calling thread.  Both give the same
## samples.  There is no public
## way to ring a bell but strike(), and only WitnessAudio's clock calls
## it (TABOO 0.35 rule 9: never a reward, UI or level-up sound).
class_name BellSynth
extends RefCounted

const MIX_RATE := 22050.0
const ATTACK_SEC := 0.002

## The ensemble of ludus-sacred-synth.js: the three largest bells form
## a C major triad (the Rostov design recorded in kolokol
## RESEARCH_NOTES).  0 is the благовестник, 1-2 подзвонные, 3-7
## зазвонные, smallest last.
const ENSEMBLE := [
	{"name": "blagovestnik", "prime": 130.81},
	{"name": "polieleiny", "prime": 164.81},
	{"name": "lebed", "prime": 196.0},
	{"name": "podzvon-c4", "prime": 261.63},
	{"name": "zazvon-e4", "prime": 329.63},
	{"name": "zazvon-g4", "prime": 392.0},
	{"name": "zazvon-c5", "prime": 523.25},
	{"name": "zazvon-e5", "prime": 659.26},
]

## Rendered strokes: "bell|strength" -> PackedFloat32Array.
var clips := {}
## Clips being rendered: key -> job state (see _job()).
var jobs := {}
## Ringing strokes: [clip, position, gain].  A negative position is a
## stroke that starts later inside the current block.
var ringing: Array = []
## Strokes whose clip had to be rendered at once because warm() had
## not reached it in time.  The headset should keep this at 0.
var cold_strokes := 0
## The worker thread's task and what it has rendered.  The worker only
## writes to done, and the main thread only reads it once the task has
## completed.
var task := -1
var done := {}


## Bigger bells ring longer (ludus-sacred-synth.js bellSpec).
static func ring_of(index: int) -> float:
	var prime: float = ENSEMBLE[index].prime
	return minf(12.0, maxf(1.6, 9.0 * pow(130.81 / prime, 0.8)))


## One bell as ludus-sacred-synth.js bellSpec(index) builds it.
static func spec(index: int) -> Dictionary:
	var bell: Dictionary = ENSEMBLE[index]
	var r := DiveCore.rng("bell:" + bell.name)
	var partials := []
	for p in DiveSynth.BELL_PARTIALS:
		var ratio: float = p.ratio * (1.0 + (r.call() * 2.0 - 1.0) * p.drift)
		var split: float = 0.12 + r.call() * 0.4
		partials.append({"name": p.name, "ratio": ratio,
			"freq": bell.prime * ratio, "split": split, "amp": p.amp,
			"decay": p.decay})
	return {"name": bell.name, "prime": bell.prime,
		"ring": ring_of(index), "partials": partials}


## The modes of one stroke at strength q (ludus-sacred-synth.js
## strokeClip): [[freq, amp, t60]].  A harder strike excites the upper
## partials more than the hum, as in a real bell.
static func modes(s: Dictionary, q: float) -> Array:
	var out := []
	for k in s.partials.size():
		var p: Dictionary = s.partials[k]
		var level: float = p.amp * pow(q, 1.0 + 0.35 * k)
		var t60: float = s.ring * p.decay
		if k < 2:
			out.append([p.freq - p.split / 2.0, level / 2.0, t60])
			out.append([p.freq + p.split / 2.0, level / 2.0, t60])
		else:
			out.append([p.freq, level, t60])
	return out


static func bucket(velocity: float) -> float:
	return maxf(0.1, roundf(velocity * 10.0) / 10.0)


static func key_of(index: int, velocity: float) -> String:
	return "%d|%.1f" % [index, bucket(velocity)]


## Queue the clips a list of strokes [[t, bell, velocity]] needs.
func prepare(strokes: Array) -> void:
	for s in strokes:
		var key := key_of(s[1], s[2])
		if not clips.has(key) and not jobs.has(key):
			jobs[key] = _job(s[1], bucket(s[2]))


func ready(strokes: Array) -> bool:
	for s in strokes:
		if not clips.has(key_of(s[1], s[2])):
			return false
	return true


## A bank of decaying sinusoids by complex rotation (addModes): four
## multiplies per mode and sample; each mode stops at its own -60 dB.
func _job(index: int, q: float) -> Dictionary:
	var list := []
	for m in modes(spec(index), q):
		list.append(m)
	# Longest first, so the active modes are always a prefix.
	list.sort_custom(func(a, b): return a[2] > b[2])
	var n := list.size()
	var j := {"k": 0, "active": n, "re": PackedFloat64Array(),
		"im": PackedFloat64Array(), "c": PackedFloat64Array(),
		"s": PackedFloat64Array(), "env": PackedFloat64Array(),
		"d": PackedFloat64Array(), "lim": PackedInt32Array(),
		"data": PackedFloat32Array()}
	for key in ["re", "im", "c", "s", "env", "d"]:
		j[key].resize(n)
	j.lim.resize(n)
	for i in n:
		var w: float = TAU * list[i][0] / MIX_RATE
		j.re[i] = 1.0
		j.im[i] = 0.0
		j.c[i] = cos(w)
		j.s[i] = sin(w)
		j.env[i] = list[i][1]
		j.d[i] = pow(10.0, -3.0 / (list[i][2] * MIX_RATE))
		j.lim[i] = int(ceil(list[i][2] * MIX_RATE))
	j.data.resize(j.lim[0])
	return j


## Render up to budget mode-samples of queued clips; true when none
## is left.  witness.gd calls it every frame with a small budget.
func warm(budget: int) -> bool:
	while budget > 0 and not jobs.is_empty():
		var key: String = jobs.keys()[0]
		var j: Dictionary = jobs[key]
		budget -= _advance(j, budget)
		if j.k >= j.data.size():
			clips[key] = j.data
			jobs.erase(key)
	return jobs.is_empty()


func _advance(j: Dictionary, budget: int) -> int:
	# Take the arrays out of the job before writing to them: packed
	# arrays are copy-on-write, and a second reference would make every
	# call copy the whole clip.
	var re: PackedFloat64Array = j.re
	var im: PackedFloat64Array = j.im
	var env: PackedFloat64Array = j.env
	var data: PackedFloat32Array = j.data
	j.re = PackedFloat64Array()
	j.im = PackedFloat64Array()
	j.env = PackedFloat64Array()
	j.data = PackedFloat32Array()
	var c: PackedFloat64Array = j.c
	var sn: PackedFloat64Array = j.s
	var d: PackedFloat64Array = j.d
	var lim: PackedInt32Array = j.lim
	var active: int = j.active
	var k: int = j.k
	var total := data.size()
	var attack := maxi(1, roundi(ATTACK_SEC * MIX_RATE))
	var spent := 0
	while k < total and spent < budget:
		while active > 0 and lim[active - 1] <= k:
			active -= 1
		var sum := 0.0
		for i in active:
			sum += im[i] * env[i]
			var nre := re[i] * c[i] - im[i] * sn[i]
			im[i] = re[i] * sn[i] + im[i] * c[i]
			re[i] = nre
			env[i] *= d[i]
		data[k] = sum * k / attack if k < attack else sum
		# Renormalise the rotators so rounding never lets them grow.
		if (k & 4095) == 4095:
			for i in active:
				var m := 1.0 / sqrt(re[i] * re[i] + im[i] * im[i])
				re[i] *= m
				im[i] *= m
		k += 1
		spent += maxi(1, active)
	j.re = re
	j.im = im
	j.env = env
	j.data = data
	j.active = active
	j.k = k
	return spent


## Render the queued clips on a worker thread; call it every frame.
## A finished task hands its clips over here, on the main thread.
func warm_async() -> void:
	if task != -1:
		if not WorkerThreadPool.is_task_completed(task):
			return
		WorkerThreadPool.wait_for_task_completion(task)
		task = -1
		for key in done:
			clips[key] = done[key]
			jobs.erase(key)
		done = {}
	if jobs.is_empty():
		return
	task = WorkerThreadPool.add_task(_render_jobs.bind(jobs.duplicate()))


func _render_jobs(todo: Dictionary) -> void:
	var out := {}
	for key in todo:
		var j: Dictionary = todo[key]
		_advance(j, 1 << 30)
		out[key] = j.data
	done = out


## Start one stroke delay samples into the next generate() call.  The
## exact strength is a gain on the clip of its 0.1 bucket (strike()).
func strike(index: int, velocity: float, delay: int) -> void:
	var key := key_of(index, velocity)
	if not clips.has(key):
		# Not rendered in time: render it now, from a fresh job, since
		# the queued one may be on the worker thread.
		cold_strokes += 1
		var j := _job(index, bucket(velocity))
		_advance(j, 1 << 30)
		clips[key] = j.data
	ringing.append([clips[key], -delay, velocity / bucket(velocity)])


func is_ringing() -> bool:
	return not ringing.is_empty()


## Mix the ringing strokes into frames of mono sound.
func generate(frames: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(frames)
	for r in ringing:
		var clip: PackedFloat32Array = r[0]
		var pos: int = r[1]
		var g: float = r[2]
		var from := maxi(0, -pos)
		var n := clip.size()
		for i in range(from, frames):
			var at := pos + i
			if at >= n:
				break
			out[i] += clip[at] * g
		r[1] = pos + frames
	ringing = ringing.filter(func(r): return r[1] < r[0].size())
	return out
