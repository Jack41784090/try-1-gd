class_name RedirectToSelfReactionEffect
extends SkillEffect


func apply(intent: ClashIntent, actor: CombatEntity) -> Array[EntityUpdate]:
	intent.redirect(actor)
	return []
