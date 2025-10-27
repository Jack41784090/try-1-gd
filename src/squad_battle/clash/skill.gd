
# export type iSkill = {
#     id: string;
#     name: string;
#     maxStacks?: number;
#     effects: iSkillEffect[]; // The triggered effects this status provides
# }
class_name Skill extends Resource

@export var name: String;
@export var effects: Array[SkillEffect]

func _to_string() -> String:
	return "Skill(name=%s, effects=%d)" % [name, effects.size()]

func _init(
	_name: String = '',
	_effects: Array[SkillEffect] = [],
) -> void:
	if _name == '':
		return
	name = _name;
	effects = _effects;
	pass
