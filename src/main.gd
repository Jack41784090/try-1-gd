extends Node
@onready var level_root: Node2D = $World/LevelRoot
@onready var entity_root: Node2D = $World/EntityRoot
@onready var effects_root: Node2D = $World/EffectsRoot
@onready var hud_root: Control = $HudLayer/Root
@onready var pause_root: Control = $PauseLayer/Root
@onready var trans_root: Control = $TransitionLayer/Root
@onready var debug_root: Control = $DebugLayer/Root
@onready var systems: Node = $Systems

func load_scenario(scenario: GameScenario) -> void:
	
	pass
