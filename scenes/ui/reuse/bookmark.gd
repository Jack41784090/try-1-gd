@tool
class_name PanelBookmark
extends PanelContainer

@onready var label: Label = $Rim/Label2
@export var text: String = "":
	set(value):
		text = value
		if is_node_ready():
			label.text = value
## Which dock side this bookmark reveals on. Wire FloatingControl.docked/undocked
## to on_docked/on_undocked; the bookmark decides its own visibility.
@export var show_on_side: DockControl.DockSide = DockControl.DockSide.NONE

func _ready() -> void:
	label.text = text


func on_docked(dock: Control) -> void:
	visible = dock != null and dock.side == show_on_side


func on_undocked() -> void:
	visible = false
