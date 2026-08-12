class_name AddDamageReactionEffect
extends SkillEffect

@export var value: float = 1.0


func apply(intent: ClashIntent, actor: CombatEntity) -> Array[EntityUpdate]:
	intent.bonus_damage += value
	return []
