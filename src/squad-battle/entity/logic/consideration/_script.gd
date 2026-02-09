class_name Consideration extends Resource

enum SkillOrTarget {
	Skill,
	Target
}

@export var should_return: SkillOrTarget = SkillOrTarget.Skill
@export var name: String = ""
@export var weight: float = 1.0
@export var op: CsdrTypes.OP = CsdrTypes.OP.ADD
@export var glances: Array[Glance] = []
@export var entity_limiter: String = "all"
@export var returning: Resource = null
@export var average_score_between_glances: bool = false
@export var limited_by_weapon_loc: bool = true

func score_then_return(entity, situation, context):
	score(entity, situation, context)
	return returning

func score(entity, situation, context) -> float:
	return _score_with_glances(entity, situation, context)

func _score_with_glances(entity, situation, _context) -> float:
	var entities_to_evaluate = _get_entities_to_evaluate(entity, situation)
	
	if entities_to_evaluate.is_empty():
		print("  [Consideration] No entities to evaluate, returning 0.0")
		return 0.0

	if glances.is_empty():
		print("  [Consideration] No glances to evaluate, returning the default weight: %s", weight)
		return weight
	
	# 1. Glance at each entity to evaluate and return a value for each, stored in glance_scores
	var glance_scores: Array[float] = []
	var best_score_so_far = - INF;
	for entity_to_check in entities_to_evaluate:
		var entity_score = glances.reduce(func(acc: float, glance: Glance): return acc + glance.evaluate(entity_to_check), 0.0)
		if average_score_between_glances: entity_score = entity_score / glances.size()
		glance_scores.append(entity_score)

		# 1.5 if the entity score is the highest so far, 
		if should_return == SkillOrTarget.Target and best_score_so_far < entity_score:
			print("  [Consideration] Best score so far: %s" % best_score_so_far)
			print("  [Consideration] Entity score: %s" % entity_score)
			print("  [Consideration] Entity: %s" % entity_to_check.entity_name)
			returning = entity_to_check
			best_score_so_far = entity_score
	
	# 2. Glance scores is then evaluated into result withr egards to the op variable set in the Consdieration
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
	
	# 3. Then the result value is mulitplied by Consideration's weight.
	result = result * weight
	print("  [Consideration] %s operation on %d entities, weight=%.2f → %.2f" % [
		CsdrTypes.OP.keys()[op], entities_to_evaluate.size(), weight, result])
	return result

func _get_weapon_range_entities(entity: CharacterCombatStats, situation: Situation) -> Array:
	var countable_entities: Array = []
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
	var weapon_range_entities = targetable_locs.reduce(func(acc: Array, loc: SquadBattleTypes.SquadEntityInSquadLocation):
		print("  [Consideration] Location: %s" % loc)
		for e in countable_entities.filter(func(e: CharacterCombatStats): return e.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) == loc):
			print("  [Consideration] Entity: %s" % e.entity_name)
			acc.append(e)
		return acc
		, [])

	print("  [Consideration] Weapon range entities: %s" % [str(weapon_range_entities)])
	return weapon_range_entities

func _get_entities_to_evaluate(entity: CharacterCombatStats, situation: Situation) -> Array:
	assert(entity_limiter in ["self", "allies", "enemies", "all"], "Invalid entity limiter: %s" % entity_limiter)
	var entities: Array = []
	match entity_limiter:
		"self":
			entities.append(entity)
		"allies":
			entities.append_array(_get_weapon_range_entities(entity, situation))
		"enemies":
			entities.append_array(_get_weapon_range_entities(entity, situation))
		"all":
			entities.append_array(_get_weapon_range_entities(entity, situation))
			
		_:
			assert(false, "Unimplemented entity limiter: %s" % entity_limiter)
	
	# print(entities)
	return entities
