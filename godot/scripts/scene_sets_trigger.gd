## Walks the twelve sets as the hero walks: after STEP_M metres the next
## set is chosen (SceneSets.next_index) and its items change one by one,
## each the moment it is out of sight or the screen is dark.  A node of
## its own, so a scene only adds it and names its items like the sets'
## ids (TABOO 0.032).
class_name SceneSetsTrigger
extends Node

## Metres walked between two changes of set.
const STEP_M := 6.0

var env_id := ""
var root: Node3D
var visits := 0
var save_seed := 0
var env: Dictionary = {}
var current := -1
var target := -1
var walked := 0.0
var _last_eye := Vector3.ZERO
var _pending: Array = []


## Start in `scene_root` for `id`; the first set is applied at once.
func begin(id: String, scene_root: Node3D, entry_count: int,
		seed_of_save: int) -> bool:
	env_id = id
	root = scene_root
	visits = entry_count
	save_seed = seed_of_save
	env = SceneSets.load_env(id)
	if env.is_empty():
		return false
	current = SceneSets.next_index(id, visits, save_seed, -1)
	SceneSets.apply(root, env.sets[current])
	return true


## One step: the hero's head position and forward, and the fade (0..1).
func update(eye: Vector3, forward: Vector3, fade := 0.0) -> void:
	if env.is_empty():
		return
	walked += eye.distance_to(_last_eye) if _last_eye != Vector3.ZERO \
		else 0.0
	_last_eye = eye
	if target < 0 and walked >= STEP_M:
		walked = 0.0
		visits += 1
		target = SceneSets.next_index(env_id, visits, save_seed, current)
		_pending = env.sets[target].items.keys()
	if target < 0:
		return
	var ok := SceneSets.swappable(env.sets[current], env.sets[target],
		eye, forward, fade)
	var now := []
	for id in _pending:
		if id in ok:
			now.append(id)
	SceneSets.apply(root, env.sets[target], now)
	for id in now:
		_pending.erase(id)
	if _pending.is_empty():
		current = target
		target = -1
