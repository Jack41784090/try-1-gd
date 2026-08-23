class_name Consideration
extends Resource

@export var name: String = ""
@export var weight: float = 1.0
@export var op: CsdrTypes.OP = CsdrTypes.OP.ADD
@export var glances: Array[Glance] = []
@export var entity_limiter: String = "all"
@export var skill: Skill = null
@export var average_score_between_glances: bool = false
@export var limited_by_weapon_loc: bool = true

var resolved_target: CombatEntity = null


func score_then_return(entity, situation, context) -> CombatEntity:
	score(entity, situation, context)
	return resolved_target


func score(entity, situation, context) -> float:
	assert(entity_limiter in ["self", "allies", "enemies", "all"], "Invalid entity limiter: %s" % entity_limiter)
	var entities_to_evaluate: Array[CombatEntity] = []
	match entity_limiter:
		"self":
			entities_to_evaluate.append(entity)
		"allies":
			entities_to_evaluate.append_array(_get_weapon_range_entities(entity, situation))
		"enemies":
			entities_to_evaluate.append_array(_get_weapon_range_entities(entity, situation))
		"all":
			entities_to_evaluate.append_array(_get_weapon_range_entities(entity, situation))
		_:
			assert(false, "Unimplemented entity limiter: %s" % entity_limiter)

	resolved_target = null

	if entities_to_evaluate.is_empty():
		print("  [Consideration] No entities to evaluate, returning 0.0")
		return 0.0

	if glances.is_empty():
		return weight

	var glance_scores: Array[float] = []
	var best_score_so_far = -INF
	for entity_to_check in entities_to_evaluate:
		var entity_score = glances.reduce(func(acc: float, glance: Glance): return acc + glance.evaluate(entity_to_check), 0.0)
		if average_score_between_glances:
			entity_score = entity_score / glances.size()
		glance_scores.append(entity_score)

		if best_score_so_far < entity_score:
			resolved_target = entity_to_check
			best_score_so_far = entity_score

	var result: float
	match op:
		CsdrTypes.OP.ADD:
			result = glance_scores.reduce(func(acc: float, val: float): return acc + val, 0.0)
		CsdrTypes.OP.MUL:
			result = glance_scores.reduce(func(acc: float, val: float): return acc * val, 1.0)
		CsdrTypes.OP.AVG:
			result = glance_scores.reduce(func(acc: float, val: float): return acc + val, 0.0) / entities_to_evaluate.size()
		CsdrTypes.OP.RDC:
			result = glance_scores.reduce(func(acc: float, val: float): return acc - val, 0.0)
		_:
			assert(false, "Unimplemented Operation in Consideration used")
			result = 0.0

	result = result * weight
	return result


func _get_weapon_range_entities(entity: CombatEntity, situation: Situation) -> Array[CombatEntity]:
	var countable_entities: Array[CombatEntity] = []
	match entity_limiter:
		"allies":
			countable_entities = situation.all_ally_entities()
		"enemies":
			countable_entities = situation.all_enemy_entities()
		"all":
			countable_entities = situation.all_ally_entities() + situation.all_enemy_entities()
		_:
			assert(false, "Unimplemented entity limiter: %s" % entity_limiter)

	if not limited_by_weapon_loc:
		return countable_entities

	var targetable_locs = entity.weapon.get_range_at_location(situation.my_location())
	var weapon_range_entities: Array[CombatEntity] = []
	for loc in targetable_locs:
		for e in countable_entities:
			if e.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) == loc:
				weapon_range_entities.append(e)

	return weapon_range_entities
