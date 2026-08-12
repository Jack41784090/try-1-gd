class_name SkillEffect extends Resource

@export var name: String = ""
@export var window: SquadBattleTypes.ReactionWindow = SquadBattleTypes.ReactionWindow.ON_CAST

var source: CombatEntity
var affected: CombatEntity
var situation: Situation = null

func set_attacker_and_target(attacker: CombatEntity, target: CombatEntity, _situation: Situation = null) -> void:
	source = attacker
	affected = target
	situation = _situation

func apply(intent: ClashIntent, actor: CombatEntity) -> Array[EntityUpdate]:
	assert(false, "SkillEffect.apply() must be overridden")
	return []
