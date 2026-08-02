class_name ReactionEffect
extends Resource

enum Kind { CANCEL, REDIRECT_TO_SELF, SCALE_DAMAGE, ADD_DAMAGE, REPLACE_SKILL }

@export var kind: Kind = Kind.CANCEL
@export var value: float = 1.0
@export var replacement: Skill = null


func apply(intent, reactor: CombatEntity) -> void:
	match kind:
		Kind.CANCEL:
			intent.cancel()
		Kind.REDIRECT_TO_SELF:
			intent.redirect(reactor)
		Kind.SCALE_DAMAGE:
			intent.damage_multiplier *= value
		Kind.ADD_DAMAGE:
			intent.bonus_damage += value
		Kind.REPLACE_SKILL:
			assert(replacement != null, "REPLACE_SKILL requires a replacement skill")
			intent.replace_skill(replacement)
