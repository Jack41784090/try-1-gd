class_name MoveReactionEffect
extends SkillEffect

@export var value: float = 0.0

func apply(intent: ClashIntent, actor: CombatEntity) -> Array[EntityUpdate]:
	actor.mod_changeable_stat(SquadBattleTypes.EntityChangeable.LOC, value)
	return []
