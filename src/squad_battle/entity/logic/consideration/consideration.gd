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
	## Core scoring logic: evaluates each entity (self, allies, or enemies) using all glances
	## Then combines per-entity scores using the OP (ADD/MUL/AVG/RDC) and multiplies by weight
	## For Target considerations, also tracks the best-scoring entity as the return value
	##
	## e.g., entity_limiter="enemies", glances=[HP(inverse, normalize)], op=AVG, weight=1.0
	##   → enemies: [Fritz(HP=30/100 → 0.3 → inverse=0.7), Karl(HP=80/100 → 0.8 → inverse=0.2)]
	##   → AVG(0.7, 0.2) = 0.45 × weight(1.0) = 0.45
	##   → if Target: returning = Fritz (highest entity_score=0.7)
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

	## 2. Glance scores is then evaluated into result with regards to the op variable set in the Consideration
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

	## 3. Then the result value is multiplied by Consideration's weight.
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
