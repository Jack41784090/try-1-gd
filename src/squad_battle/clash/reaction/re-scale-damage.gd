class_name ScaleDamageReactionEffect
extends SkillEffect

@export var value: float = 1.0


func apply(intent: ClashIntent, actor: CombatEntity) -> Array[EntityUpdate]:
	intent.damage_multiplier *= value
	return []
