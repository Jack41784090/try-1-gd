class_name StrategicConsideration extends Resource

@export var name: String = ""
@export var weight: float = 1.0
@export var op: CsdrTypes.OP = CsdrTypes.OP.MUL
@export var glances: Array[StrategicGlance] = []
@export var returning: StrategicAction = null

func score(situation: StrategicSituation) -> float:
	if glances.is_empty():
		return weight

	var glance_values: Array[float] = []
	for glance in glances:
		glance_values.append(glance.evaluate(situation))

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

	return result * weight
