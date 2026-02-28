class_name StrategicConsideration
extends Resource

@export var name: String = ""
@export var weight: float = 1.0
@export var op: CsdrTypes.OP = CsdrTypes.OP.MUL
@export var glances: Array[StrategicGlance] = []
@export var returning: StrategicAction = null


func score(situation: StrategicSituation) -> float:
	# Scores this consideration by evaluating all its glances against the situation
	# e.g., consideration "low_food" with glances=[Glance(FOOD, inverse=true, normalize/100)]
	#   → squad.food=20, normalize_max=100 → 0.2, inverse → 0.8
	#   → result = 0.8 × weight(1.0) = 0.8
	# Returns: final score (higher = more desirable)
	if glances.is_empty():
		# No glances means this consideration always returns its base weight
		return weight

	# 1. Evaluate each glance and collect their values
	# e.g., glance1 → 0.8 (low food), glance2 → 1.0 (enemy_nearby threshold passed)
	var glance_values: Array[float] = []
	for glance in glances:
		glance_values.append(glance.evaluate(situation))

	# 2. Combine glance values using the configured operation
	# e.g., op=MUL: 0.8 × 1.0 = 0.8 (both conditions must be somewhat true)
	# e.g., op=ADD: 0.8 + 1.0 = 1.8 (additive scoring)
	# e.g., op=AVG: (0.8 + 1.0) / 2 = 0.9
	var result: float
	match op:
		CsdrTypes.OP.ADD:
			result = glance_values.reduce(func(acc: float, val: float): return acc + val, 0.0)
		CsdrTypes.OP.MUL:
			result = glance_values.reduce(func(acc: float, val: float): return acc * val, 1.0)
		CsdrTypes.OP.AVG:
			result = glance_values.reduce(func(acc: float, val: float): return acc + val, 0.0) / glance_values.size()
		CsdrTypes.OP.RDC:
			result = glance_values.reduce(func(acc: float, val: float): return acc - val, 0.0)
		_:
			assert(false, "Unknown OP in StrategicConsideration: %s" % op)
			result = 0.0

	# 3. Multiply by consideration weight to get final score
	# e.g., result=0.8, weight=1.5 → final=1.2
	return result * weight
