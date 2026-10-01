## The path of the witness: seven scene kits along one path, where the
## player may walk, stand, bow the head and leave, and never cross the
## witness line (docs/SACRAMENTS_VR_SCENES.md, TABOO 0.26 point 10).
##
## Nothing here counts, rewards or records: no attribute, gate, journal
## entry or presence log follows a visit.  The scene kits and their data
## are public/vr/models/scene/sacrament-*.{glb,json}, copied to
## godot/models/scene and compared by CI.
class_name WitnessCore
extends RefCounted

## The order of the Longer Catechism of St Philaret.
const ORDER := ["baptism", "chrismation", "eucharist", "confession",
	"ordination", "marriage", "unction"]
const SPACING_M := 15.0
const FIRST_X := 8.0
## Half-width of the path.  Each kit stands so that its witness line
## lies exactly on the path's edge: walking the path is walking up to
## the line and no further.
const PATH_HALF := 2.0
const START := Vector3(-1.0, 0.0, 0.0)
const END_MARGIN := 6.0
## Room tone, never digital zero (TABOO 0.4 rule 2): -48 dBFS RMS.
const ROOM_TONE_DBFS := -48.0


static func load_meta(id: String) -> Dictionary:
	var path := "res://models/scene/sacrament-%s.json" % id
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Where each kit stands.  witness_z is the witness line's distance in
## front of the kit's centre (its node "witness-line"); a kit without
## one (the ordination memory) keeps the player off its whole depth.
static func bays(witness_z: Dictionary) -> Array:
	var out := []
	for i in ORDER.size():
		var id: String = ORDER[i]
		var meta := load_meta(id)
		var wz: float = witness_z.get(id, meta.bbox_m[2] / 2.0 + 0.5)
		var side := -1.0 if i % 2 == 0 else 1.0
		out.append({"id": id, "meta": meta, "witness_z": wz,
			"x": FIRST_X + SPACING_M * i, "z": side * (wz + PATH_HALF),
			"yaw": 0.0 if side < 0.0 else PI, "side": side})
	return out


static func path_end(n: int) -> float:
	return FIRST_X + SPACING_M * (n - 1) + END_MARGIN


## Keep the walker on the path: between the entrance and the far end,
## and never past a witness line.
static func clamp_walk(p: Vector3, n: int) -> Vector3:
	return Vector3(clampf(p.x, START.x - 1.0, path_end(n)), p.y,
		clampf(p.z, -PATH_HALF, PATH_HALF))


## How far the walker is from a kit's witness line, measured towards
## the kit (negative would mean crossed; clamp_walk never allows it).
static func to_line(p: Vector3, bay: Dictionary) -> float:
	return (PATH_HALF - p.z) if bay.side > 0.0 else (p.z + PATH_HALF)


## One block of room tone: a quiet, darkened noise (one-pole low-pass),
## deterministic.  state is {"seed": int, "lp": float} and carries on
## from block to block, so the blocks join without a click.
static func room_tone(frames: int, state: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(frames)
	# White noise of amplitude a has RMS a / sqrt(3); the one-pole
	# low-pass keeps a fraction k / (2 - k) of its power, so both are
	# undone here to land on ROOM_TONE_DBFS.
	var k := 0.18
	var amp := pow(10.0, ROOM_TONE_DBFS / 20.0) * sqrt(3.0) \
		* sqrt((2.0 - k) / k)
	var lp: float = state.get("lp", 0.0)
	var s: int = state.get("seed", 1)
	for i in frames:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var w := float(s) / float(0x7fffffff) * 2.0 - 1.0
		lp += k * (w * amp - lp)
		out[i] = lp
	state.seed = s
	state.lp = lp
	return out


static func rms_dbfs(samples: PackedFloat32Array) -> float:
	var acc := 0.0
	for v in samples:
		acc += v * v
	return 10.0 * log(acc / maxf(1.0, samples.size()) + 1e-20) / log(10.0)
