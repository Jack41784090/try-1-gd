class_name SquadToken
extends Node2D

## Map token for one traveling squad: wagon sprite tinted by role + name label.

const WAGON_SVG := "res://assets/scenery/wagon.svg"

const ROLE_COLORS: Dictionary = {
	StrategyTypes.SquadRole.MERCHANT: Color(0.95, 0.8, 0.4),
	StrategyTypes.SquadRole.MONSTER: Color(0.85, 0.35, 0.3),
	StrategyTypes.SquadRole.BANDIT: Color(0.7, 0.4, 0.75),
	StrategyTypes.SquadRole.COMBAT: Color(0.55, 0.7, 0.95),
}

@onready var sprite: Sprite2D = $Sprite
@onready var label: Label = $Label


func setup(squad: StrategySquad) -> void:
	sprite.texture = SvgLoader.load_svg(WAGON_SVG, 1.0)
	sprite.modulate = ROLE_COLORS.get(squad.squad_role, Color.WHITE)
	label.text = squad.squad_name
