## The sound of the path of the witness (docs/HLD_WITNESS_SOUND_
## 2026-09-30.md), sample by sample, with nothing random and nothing
## recorded.
##
## Three layers, and no machine among them:
##   room   the room's own tone, -48 dBFS RMS, never digital zero
##          (WitnessCore.room_tone, TABOO 0.4 rule 2);
##   ison   the brethren a cappella near the kit the walker stands by,
##          on the tone of the week and the vowel of the scene
##          (docs/SACRAMENTS_VR_SCENES.md), wordless (IsonSynth);
##   bell   the far monastery's bells, started by the clock and the
##          Typikon only (TypikonCore, BellSynth), by the cues of the
##          one bell table godot/data/bell-rules.json, each with its
##          source (docs/HLD_BELL_RULES_TYPIKON_2026-09-30.md).
##
## The ison and the bell never sound together (TABOO 0.35 rule 10).
## The bell keeps the hour: when a cue begins, the ison ends its breath
## and falls silent first, and the bell is heard only once the ison is
## gone; the ison comes back only after the last stroke has died away.
##
## Nothing here counts or records the walker: the only input is where
## the walker stands, and it only sets how near the ison is.
class_name WitnessAudio
extends RefCounted

const MIX_RATE := 22050.0
const BLOCK := 64

## The ison of each kit: the vowel its scene gives (docs/SACRAMENTS_VR_
## SCENES.md: "исон на «а» у берега" for the font, "исон на «о»" at the
## wedding) and what it means.  Where the scene names no vowel, the
## dark "o" of the brethren's ison is a design choice.
const KIT_ISON := {
	"baptism": {"vowel": "a", "meaning": "У воды поют без слов: "
		+ "свидетель слышит, что здесь молятся, и ничего не делает."},
	"chrismation": {"vowel": "a", "meaning": "Тот же берег, то же "
		+ "пение: новое начинается сразу, без перехода."},
	"eucharist": {"vowel": "o", "meaning": "Пока братия идёт к чаше, "
		+ "звучит только исон; свидетель стоит у колонн."},
	"confession": {"vowel": "o", "meaning": "Далёкое чтение часов "
		+ "без слов: слов у аналоя не слышно никогда."},
	"ordination": {"vowel": "o", "meaning": "Память о служении: голос "
		+ "без слов держит тон, пока рука лежит на голове."},
	"marriage": {"vowel": "o", "meaning": "Пение без слов над двумя, "
		+ "которые станут одним; гость стоит у дверей."},
	"unction": {"vowel": "o", "meaning": "Тихий исон у постели "
		+ "больного: о врачевании, а не о проводах."},
}
## The ison is full within ISON_NEAR_M of the kit's witness line and
## gone beyond ISON_FAR_M: less than half the 15 m between kits, so two
## kits are never heard at once.
const ISON_NEAR_M := 3.0
const ISON_FAR_M := 7.0
const ISON_IN_SEC := 6.0
const ISON_OUT_SEC := 3.0
const BELL_FADE_SEC := 1.5
## Mode-samples of bell clips rendered per frame where there are no
## threads (the Web build): under a millisecond on a desktop, so the
## day's 19 clips take about half a minute of frames.
const WARM_PER_FRAME_WEB := 4000
## Levels: the ison near the line about -30 dBFS RMS, the far bells
## below -1 dBFS peak even in the удар во вся (measured, see the HLD).
const ISON_GAIN := 0.1
const BELL_GAIN := 0.1

var layers := {"room": true, "ison": true, "bell": true}

var ison := IsonSynth.new()
var bells := BellSynth.new()
var room_state := {"seed": 7, "lp": 0.0}

## The clock: seconds since the Unix epoch of the local date, advanced
## by the samples rendered, so a stroke falls on its sample.
var clock := 0.0
var plan_key := ""
var glas_key := ""
var plan: Array = []
var struck := {}

var kit := ""
var nearness := 0.0
var ison_level := 0.0
var ison_target := 0.0
var bell_level := 0.0
var bell_target := 0.0
## Samples in which the ison and the bell were both audible: stays 0.
var overlap_samples := 0
## The bell cues heard this session, with the Typikon's reason: data
## about the bells, never about the walker.
var rung: Array = []


## Set the local moment {year, month, day, hour, minute, second}.
func set_now(now: Dictionary) -> void:
	clock = float(LudusTypikon._day(now.year, now.month, now.day)) \
		+ int(now.get("hour", 0)) * 3600 + int(now.get("minute", 0)) * 60 \
		+ float(now.get("second", 0))
	_replan()


func now() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(int(floor(clock)))


func _replan() -> void:
	var civil := now()
	var key := TypikonCore.day_key(civil)
	# The tone of the week changes with the liturgical day, at Vespers;
	# the ison is declared again for the kit it stands by.  (At that
	# hour the call to Vespers is ringing, so the ison is silent.)
	var eve: bool = int(civil.hour) >= LudusTypikon.VESPERS_HOUR
	var tone_key := key + ("/eve" if eve else "")
	if tone_key != glas_key:
		glas_key = tone_key
		_declare()
	if key == plan_key:
		return
	plan_key = key
	plan = TypikonCore.day_plan(civil)
	for p in plan:
		bells.prepare(p.strokes)


func _declare() -> void:
	if kit == "":
		return
	var g := LudusTypikon.glas_of(now())
	ison.set_decl(IsonSynth.declare(g, KIT_ISON[kit].vowel, "antiphonal"))


## The declared ison of a kit today: {glas, tonic, final, vowel,
## kliros, meaning}, or {} when none is sung.
func ison_of(id: String) -> Dictionary:
	var d := IsonSynth.declare(LudusTypikon.glas_of(now()),
		KIT_ISON[id].vowel, "antiphonal")
	if not d.is_empty():
		d.meaning = KIT_ISON[id].meaning
	return d


## Where the walker stands, and the kits of the path (WitnessCore.bays).
## Only the nearest kit's ison is heard, by how close its line is.
func listen(pos: Vector3, bays: Array) -> void:
	var best := ""
	var best_d := INF
	for b in bays:
		var line := Vector3(b.x, 0.0, b.side * WitnessCore.PATH_HALF)
		var d := Vector2(pos.x - line.x, pos.z - line.z).length()
		if d < best_d:
			best_d = d
			best = b.id
	var near := clampf((ISON_FAR_M - best_d) / (ISON_FAR_M - ISON_NEAR_M),
		0.0, 1.0)
	if best != kit:
		# A new kit is sung only after the old one has fallen silent.
		if ison_level > 0.0:
			nearness = 0.0
			return
		kit = best
		_declare()
	nearness = near


## The cue sounding at a second of the day, or {}.
func _cue_at(sec: float) -> Dictionary:
	for p in plan:
		if sec >= p.start and sec < p.end:
			return p
	return {}


## Strike the strokes whose time falls in this block.  This is the only
## place a bell is ever struck.
func _ring_due(sec0: float, n: int) -> void:
	for p in plan:
		if sec0 + n / MIX_RATE < p.start or sec0 >= p.end:
			continue
		for k in p.strokes.size():
			var s: Array = p.strokes[k]
			var at: float = p.start + s[0]
			if at >= sec0 and at < sec0 + n / MIX_RATE:
				var id := "%s#%s#%d" % [plan_key, p.cue.id, k]
				if struck.has(id):
					continue
				struck[id] = true
				var tag := "%s#%s" % [plan_key, p.cue.id]
				if not struck.has(tag):
					struck[tag] = true
					rung.append({"cue": p.cue.id, "order": p.cue.order,
						"reason": p.reason, "meaning": p.cue.meaning})
				bells.strike(s[1], s[2], int((at - sec0) * MIX_RATE))


func _ramp(level: float, target: float, seconds: float, n: int) -> float:
	var step := n / (seconds * MIX_RATE)
	if level < target:
		return minf(target, level + step)
	return maxf(target, level - step)


## Render frames of stereo sound.
func generate(frames: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames)
	var done := 0
	while done < frames:
		var n := mini(BLOCK, frames - done)
		_block(out, done, n)
		done += n
	return out


func _block(out: PackedVector2Array, at: int, n: int) -> void:
	_replan()
	var day := now()
	var sec := clock - float(LudusTypikon._day(day.year, day.month,
		day.day))
	var bell_hour: bool = layers.bell and not _cue_at(sec).is_empty()
	if layers.bell:
		_ring_due(sec, n)
	# The bell keeps the hour; the ison yields first, and each waits
	# for the other to be silent.
	var want_ison: bool = layers.ison and nearness > 0.0 \
		and not ison.decl.is_empty() and not bell_hour
	if bell_hour:
		ison_target = 0.0
		bell_target = 1.0 if ison_level <= 0.0 else 0.0
	else:
		bell_target = 0.0
		ison_target = nearness if want_ison and bell_level <= 0.0 else 0.0
	var i0 := ison_level
	ison_level = _ramp(ison_level, ison_target,
		ISON_IN_SEC if ison_target > ison_level else ISON_OUT_SEC, n)
	var b0 := bell_level
	bell_level = _ramp(bell_level, bell_target, BELL_FADE_SEC, n)
	if (i0 > 0.0 or ison_level > 0.0) and (b0 > 0.0 or bell_level > 0.0):
		overlap_samples += n
	var room := PackedFloat32Array()
	if layers.room:
		room = WitnessCore.room_tone(n, room_state)
	var voice := ison.generate(n, i0 * ISON_GAIN, ison_level * ISON_GAIN)
	if i0 <= 0.0 and ison_level <= 0.0:
		ison.sung = 0.0
	var bell := bells.generate(n)
	var use_bell: bool = b0 > 0.0 or bell_level > 0.0
	for i in n:
		var v := voice[i]
		if layers.room:
			v += Vector2(room[i], room[i])
		if use_bell:
			var g := lerpf(b0, bell_level, float(i) / n) * BELL_GAIN
			v += Vector2(bell[i], bell[i]) * g
		out[at + i] = v
	clock += n / MIX_RATE
