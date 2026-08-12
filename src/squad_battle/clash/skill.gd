class_name Skill extends Resource

@export var name: String;
@export var effects: Array[SkillEffect]
@export var targeting_consideration: Consideration
@export var roll_for_damage: bool = true
@export var sta_cost: float = 0.0

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
	_roll_for_damage: bool = true,
) -> void:
	if _name == '':
		return
	name = _name;
	effects = _effects;
	targeting_consideration = _targeting_consideration
	roll_for_damage = _roll_for_damage

func instantiate() -> Skill:
	var copy: Skill = duplicate()
	var copied_effects: Array[SkillEffect] = []
	for e in effects:
		copied_effects.append(e.duplicate(true))
	copy.effects = copied_effects
	return copy
