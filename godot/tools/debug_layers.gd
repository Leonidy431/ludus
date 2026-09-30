## Debug: render the start view with one child of the scene hidden at a
## time, to find which node draws a stray shape.
extends SceneTree

var scene: Node3D
var frame := 0
var idx := -1
var out := "/tmp/claude-0/-home-user-ludus/00bfaacc-916a-5377-9b22-7beb9ad7416e/scratchpad/layers"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	scene = load("res://scenes/dive.tscn").instantiate()
	root.add_child(scene)


func _process(_dt: float) -> bool:
	frame += 1
	if frame % 10 != 0:
		return false
	if idx >= 0:
		root.get_viewport().get_texture().get_image().save_png(
			"%s/hide-%02d-%s.png" % [out, idx, scene.get_child(idx).get_class()])
		scene.get_child(idx).visible = true
	idx += 1
	if idx >= scene.get_child_count():
		return true
	var c = scene.get_child(idx)
	if "visible" in c:
		c.visible = false
	return false
