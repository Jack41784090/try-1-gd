@tool
extends Control

@onready var parent: Control = get_parent()

func _ready() -> void:
	parent.resized.connect(_enforce_square)
	_enforce_square()


func _enforce_square() -> void:
	if custom_minimum_size.y != size.x:
		custom_minimum_size.y = size.x
