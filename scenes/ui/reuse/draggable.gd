extends Control

@onready var parent = get_parent()

@export var preview: Control
@export var return_data = { }


func _get_drag_data(_at_position: Vector2) -> Variant:
	var source: Control = preview if preview else parent
	var parent_dupe = source.duplicate()
	parent_dupe.self_modulate = Color(1, 1, 1, 0.5)

	var wrapper = Control.new()
	wrapper.add_child(parent_dupe)
	parent_dupe.position = -source.size * 0.5

	set_drag_preview(wrapper)
	return return_data
