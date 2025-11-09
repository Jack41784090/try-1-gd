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
	var best_score_so_far = -INF;
	for entity_to_check in entities_to_evaluate:
		var entity_score = glances.reduce(func(acc: float, glance: Glance): return acc + glance.evaluate(entity_to_check), 0.0)
		if average_score_between_glances: entity_score = entity_score / glances.size()
		glance_scores.append(entity_score)

		# 1.5 if the entity score is the highest so far, 
		if should_return == SkillOrTarget.Target and best_score_so_far < entity_score:
			returning = entity_to_check
	
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

func _get_entities_to_evaluate(entity, situation) -> Array:
	var entities: Array = []
	match entity_limiter:
		"self":
			entities.append(entity)
		"allies":
			var our_squad = situation.get_our_squad()
			for location in our_squad.values():
				if location is Array:
					entities.append_array(location)	
		"enemies":
			var enemy_squad = situation.get_enemy_squad()
			for location in enemy_squad.values():
				if location is Array:
					entities.append_array(location)
		"all":
			var our_squad = situation.get_our_squad()
			# print("Our squad: %s" % our_squad)
			for location in our_squad.values():
				if location is Array:
					entities.append_array(location)
			var enemy_squad = situation.get_enemy_squad()
			# print("Enemy squad: %s" % enemy_squad)
			for location in enemy_squad.values():
				if location is Array:
					entities.append_array(location)
		_:
			assert(false, "Unimplemented entity limiter: %s" % entity_limiter)
	
	# print(entities)
	return entities

