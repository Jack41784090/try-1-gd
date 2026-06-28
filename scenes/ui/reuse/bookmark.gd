@tool
class_name PanelBookmark
extends PanelContainer

@onready var label: Label = $Rim/Label2
@export var text: String = "":
	set(value):
		text = value
		if is_node_ready():
			label.text = value

func _ready() -> void:
	label.text = text
