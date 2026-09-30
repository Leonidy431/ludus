## Moving between the hub and the dive (autoload "Nav").
##
## The dive has no exit of its own: B on the right controller, or Esc,
## brings the ROV back to the pier of the obitel.  Kept apart from both
## scenes so neither has to know about the other.
extends Node

const HUB := "res://scenes/hub.tscn"
const DIVE := "res://scenes/dive.tscn"
var was := false


func _process(_dt: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != DIVE:
		was = false
		return
	var back := Input.is_key_pressed(KEY_ESCAPE)
	for c in scene.find_children("*", "XRController3D", true, false):
		if (c as XRController3D).tracker == &"right_hand" \
				and (c as XRController3D).is_button_pressed("by_button"):
			back = true
	if back and not was:
		get_tree().change_scene_to_file(HUB)
	was = back
