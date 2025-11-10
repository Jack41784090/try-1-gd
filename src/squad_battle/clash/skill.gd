
# export type iSkill = {
#     id: string;
#     name: string;
#     maxStacks?: number;
#     effects: iSkillEffect[]; // The triggered effects this status provides
# }
class_name Skill extends Resource

@export var name: String;
@export var effects: Array[SkillEffect]
@export var targeting_consideration: Consideration
@export var affected_consideration: Consideration;
@export var roll_for_damage: bool = true

var caster: SquadEntity;
var target: SquadEntity;
var situation: Situation;
var context: Dictionary;

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

func inject_context_for_clash(_caster, _situation, _context):
	caster = _caster
	situation = _situation;
	context = _context
	target = return_who_to_cast_at()

func return_who_to_cast_at() -> SquadEntity:
	var r = targeting_consideration.score_then_return(caster, situation, context)
	assert(r is SquadEntity)
	for e in effects:
		e.set_attacker_and_target(caster, r)
	return r;
	# pass

func return_appropriate_skill_effects() -> Array[SkillEffect]:
	return effects # TODO: skill effects will be recursive, instead of the current implementation of following Skill's casted at and caster
	# pass
