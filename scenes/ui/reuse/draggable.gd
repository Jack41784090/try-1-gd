extends Control

@onready var parent = get_parent()
@export var return_data = {}

func _get_drag_data(_at_position: Vector2) -> Variant:
	var parent_dupe = parent.duplicate()
	parent_dupe.self_modulate = Color(1, 1, 1, 0.5)
	set_drag_preview(parent_dupe)
	return return_data
