class_name HudLayerRoot
extends CanvasLayer

@onready var root: Control = $Root

var command_bar_hud: CommandBarHud


## command_bar_hud is plain UI, not a System — see main.gd's load_scenario().
func setup() -> void:
	command_bar_hud = CommandBarHud.new()
	command_bar_hud.name = "CommandBarHud"
	root.add_child(command_bar_hud)
