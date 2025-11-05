class_name Consideration extends Resource

@export var weight: float = 1.0
@export var op: CsdrTypes.OP

@export var subcsdr: Array[Consideration]
@export var glances: Array[Glance] = []
@export var entity_limiter: String = "all"
@export var skill: Skill = null

func score(entity, situation, context) -> float:
	var result: float
	
	if glances.size() > 0:
		result = _score_with_glances(entity, situation, context)
	else:
		result = _score_with_subcsdr(entity, situation, context)
	
	return result

func _score_with_glances(entity, situation, context) -> float:
	var entities_to_evaluate = _get_entities_to_evaluate(entity, situation)
	
	if entities_to_evaluate.is_empty():
		return 0.0
	
	var glance_scores: Array[float] = []
	for entity_to_check in entities_to_evaluate:
		var entity_score = 0.0
		for glance in glances:
			entity_score += glance.evaluate(entity_to_check)
		glance_scores.append(entity_score)
	
	var result: float
	match op:
		CsdrTypes.OP.ADD:
			result = glance_scores.reduce(func(acc: float, val: float): return acc + val, 0.0)
		CsdrTypes.OP.MUL:
			result = glance_scores.reduce(func(acc: float, val: float): return acc * val, 1.0)
		CsdrTypes.OP.AVG:
			if glance_scores.size() > 0:
				result = glance_scores.reduce(func(acc: float, val: float): return acc + val, 0.0) / glance_scores.size()
			else:
				result = 0.0
		CsdrTypes.OP.RDC:
			result = glance_scores.reduce(func(acc: float, val: float): return acc - val, 0.0)
		_:
			assert(false, "Unimplemented Operation in Consideration used")
			result = 0.0
	
	result = result * weight
	print("  [Consideration] %s operation on %d entities, weight=%.2f → %.2f" % [
		CsdrTypes.OP.keys()[op], entities_to_evaluate.size(), weight, result])
	return result

func _score_with_subcsdr(entity, situation, context) -> float:
	var result: float
	match op:
		CsdrTypes.OP.ADD:
			var sum: float = subcsdr.reduce(func(acc: float, csdr: Consideration): return acc + csdr.score(entity, situation, context), 0.0)
			result = sum * weight
			print("  [Consideration.ADD] sum=%.2f, weight=%.2f → %.2f" % [sum, weight, result])
		CsdrTypes.OP.RDC:
			var sum: float = subcsdr.reduce(func(acc: float, csdr: Consideration): return acc - csdr.score(entity, situation, context), 0.0)
			result = sum * weight
			print("  [Consideration.RDC] sum=%.2f, weight=%.2f → %.2f" % [sum, weight, result])
		CsdrTypes.OP.MUL:
			var sum: float = subcsdr.reduce(func(acc: float, csdr: Consideration): return acc * csdr.score(entity, situation, context), 1.0)
			result = sum * weight
			print("  [Consideration.MUL] sum=%.2f, weight=%.2f → %.2f" % [sum, weight, result])
		CsdrTypes.OP.AVG:
			if subcsdr.size() > 0:
				var sum: float = subcsdr.reduce(func(acc: float, csdr: Consideration): return acc + csdr.score(entity, situation, context), 0.0)
				result = (sum / subcsdr.size()) * weight
				print("  [Consideration.AVG] avg=%.2f, weight=%.2f → %.2f" % [sum / subcsdr.size(), weight, result])
			else:
				result = 0.0
		_:
			assert(false, "Unimplemented Operation in Consideration used")
			result = 0.0
	return result

func _get_entities_to_evaluate(entity, situation) -> Array:
	var entities: Array = []
	match entity_limiter:
		"self":
			entities.append(entity)
		"allies":
			var unwrapped = situation.unwrap()
			if unwrapped.has("our_squad"):
				var our_squad = unwrapped["our_squad"]
				for location in our_squad.values():
					if location is Array:
						entities.append_array(location)
		"enemies":
			var unwrapped = situation.unwrap()
			if unwrapped.has("enemy_squad"):
				var enemy_squad = unwrapped["enemy_squad"]
				for location in enemy_squad.values():
					if location is Array:
						entities.append_array(location)
		"all":
			var unwrapped = situation.unwrap()
			if unwrapped.has("our_squad"):
				var our_squad = unwrapped["our_squad"]
				for location in our_squad.values():
					if location is Array:
						entities.append_array(location)
			if unwrapped.has("enemy_squad"):
				var enemy_squad = unwrapped["enemy_squad"]
				for location in enemy_squad.values():
					if location is Array:
						entities.append_array(location)
		_:
			entities.append(entity)
	
	return entities

