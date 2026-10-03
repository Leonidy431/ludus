## The twelve ready sets of one scene (TABOO 0.032, docs/tech/MULTI_ENV_
## SETS_2026-10-03.md), read from data/scene-sets.json that
## scripts/scenes/multi_env_sets.py baked at build time.
##
## Nothing here is random: which set comes next is a count and a hash,
## and a set changes only where the hero is not looking, or while the
## screen is dark (TABOO 0.014), so the room moves behind his back.
## Holy things are never in the sets (the generator fixes them).
##
## Constitution: FORM (one scene with its rules) -> ACTION (twelve
## checked sets follow each other as the hero walks) -> GOAL (the world
## lives and does not repeat, yet every set teaches the same thing).
class_name SceneSets
extends RefCounted

const SETS := 12
const PATH := "res://data/scene-sets.json"


## The baked environment `env_id`, or an empty Dictionary.
static func load_env(env_id: String, path := PATH) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return {}
	return data.get("envs", {}).get(env_id, {})


## The set for the visit number `visits` (a count of entries into the
## environment): a count plus the environment's own hash, never the same
## as `last`, and over twelve visits it meets every set once.
static func next_index(env_id: String, visits: int, save_seed: int,
		last: int) -> int:
	var shift := absi(hash(env_id + ":" + str(save_seed))) % SETS
	var i := posmod(visits + shift, SETS)
	if i == last:
		i = (i + 1) % SETS
	return i


## Is `point` outside the cone the hero looks into?
static func unseen(eye: Vector3, forward: Vector3, point: Vector3,
		half_fov_deg := 70.0) -> bool:
	var to := point - eye
	if to.length() < 0.001:
		return false
	return forward.normalized().dot(to.normalized()) \
		< cos(deg_to_rad(half_fov_deg))


## The items that may change now: all of them while the screen is dark
## (`fade` at 1), otherwise those whose old and new places are both out
## of sight.
static func swappable(old_set: Dictionary, new_set: Dictionary,
		eye: Vector3, forward: Vector3, fade := 0.0) -> Array:
	var out := []
	for id in new_set.get("items", {}):
		var b: Dictionary = new_set.items[id]
		var a: Dictionary = old_set.get("items", {}).get(id, b)
		if fade >= 0.99 or (unseen(eye, forward, _v(a.pos))
				and unseen(eye, forward, _v(b.pos))):
			out.append(id)
	return out


## Put the named items of `root` where the set says (place, turn, size);
## returns how many were found.  Items not in `only` are left alone.
static func apply(root: Node3D, set: Dictionary, only: Array = []) -> int:
	var n := 0
	for id in set.get("items", {}):
		if not only.is_empty() and not id in only:
			continue
		var node := root.get_node_or_null(NodePath(id)) as Node3D
		if node == null:
			continue
		var rec: Dictionary = set.items[id]
		node.position = _v(rec.pos)
		node.rotation_degrees = Vector3(0.0, float(rec.yaw), 0.0)
		node.scale = Vector3.ONE * float(rec.scale)
		n += 1
	return n


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
