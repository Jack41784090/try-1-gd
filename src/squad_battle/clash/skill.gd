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

var caster: CombatEntity;
var target: CombatEntity;
var situation: Situation;
var context: Dictionary;

func _to_string() -> String:
	return "Skill(name=%s, effects=%d)" % [name, effects.size()]

func _init(
	_name: String = '',
	_effects: Array[SkillEffect] = [],
	_targeting_consideration: Consideration = Consideration.new(),
	_affected_consideration: Consideration = Consideration.new(),
	_roll_for_damage: bool = true,
) -> void:
	if _name == '':
		return
	name = _name;
	effects = _effects;
	targeting_consideration = _targeting_consideration
	affected_consideration = _affected_consideration
	roll_for_damage = _roll_for_damage
	pass

func inject_context_for_clash(_caster, _situation, _context):
	caster = _caster
	situation = _situation;
	context = _context
	target = return_who_to_cast_at()

func return_who_to_cast_at() -> CombatEntity:
	var r = targeting_consideration.score_then_return(caster, situation, context)
	assert(r is CombatEntity)
	for e in effects:
		e.set_attacker_and_target(caster, r)
	return r;
	# pass

func return_appropriate_skill_effects() -> Array[SkillEffect]:
	return effects # TODO: skill effects will be recursive, instead of the current implementation of following Skill's casted at and caster
	# pass
