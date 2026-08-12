class_name CancelReactionEffect
extends SkillEffect


func apply(intent: ClashIntent, actor: CombatEntity) -> Array[EntityUpdate]:
	intent.cancel()
	return []
