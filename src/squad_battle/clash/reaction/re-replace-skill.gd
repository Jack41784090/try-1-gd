class_name ReplaceSkillReactionEffect
extends SkillEffect

@export var replacement: Skill = null


func apply(intent: ClashIntent, actor: CombatEntity) -> Array[EntityUpdate]:
	assert(replacement != null, "ReplaceSkillReactionEffect requires a replacement skill")
	intent.replace_skill(replacement)
	return []
