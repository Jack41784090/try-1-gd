class_name HudLayerRoot
extends CanvasLayer

@onready var root: Control = $Root
@onready var time_label: ClockSystemHud = $Root/TimerHud

var command_bar_hud: CommandBarHud


## command_bar_hud is plain UI, not a System.
func setup() -> void:
	command_bar_hud = CommandBarHud.new()
	command_bar_hud.name = "CommandBarHud"
	root.add_child(command_bar_hud)
	
	
