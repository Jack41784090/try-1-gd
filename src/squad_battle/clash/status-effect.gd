class_name StatusEffect extends Resource

@export var effect_name: String = ""
@export var duration: int = 1
@export var stat_modifiers: Dictionary = {}
@export var window: SquadBattleTypes.ReactionWindow = 5

var remaining_turns: int = 0


func apply_to(entity: CombatEntity) -> void:
	remaining_turns = duration
	for stat_key in stat_modifiers:
		entity.mod_changeable_stat(stat_key, stat_modifiers[stat_key])


func tick() -> bool:
	remaining_turns -= 1
	return remaining_turns <= 0


func is_expired() -> bool:
	return remaining_turns <= 0
