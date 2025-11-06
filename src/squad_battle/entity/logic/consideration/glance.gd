class_name Glance extends Resource

@export var property: SquadBattleTypes.EntityChangeable
@export var normalize_as_percentage: bool = false
@export var use_comparison: bool = false
@export var comparison: CsdrTypes.DETECTION = CsdrTypes.DETECTION.ABOVE
@export var threshold: float = 0.0
@export var or_equal: bool = false
@export var operation_on_other_glance: CsdrTypes.OP = CsdrTypes.OP.ADD
@export var additional_glance: Glance = null


func _to_string() -> String:
	return "Glance(property=%s, normalize=%s, comparison=%s)" % [
		SquadBattleTypes.EntityChangeable.keys()[property] if property >= 0 else "None",
		normalize_as_percentage,
		use_comparison
	]


func evaluate(entity: SquadEntity) -> float:
	var value = entity.get_changeable_stat_num(property)

	print("Evaluating glance: %s, value=%s" % [self, value])
	
	if normalize_as_percentage:
		var max_v = entity.get_ceiling_changeable_stat(property)
		value = value / max(max_v, 1.0)
		print("Normalized value: %s [max_v=%s]" % [value, max_v])

	if additional_glance != null:
		var additional_value = additional_glance.evaluate(entity)
		print("Evaluating additional glance: %s, value=%s" % [additional_glance, additional_value])
		match operation_on_other_glance:
			CsdrTypes.OP.ADD:
				print("Adding additional value: %s + %s = %s" % [value, additional_value, value + additional_value])
				value += additional_value
			CsdrTypes.OP.RDC:
				print("Subtracting additional value: %s - %s = %s" % [value, additional_value, value - additional_value])
				value -= additional_value
			CsdrTypes.OP.MUL:
				print("Multiplying additional value: %s * %s = %s" % [value, additional_value, value * additional_value])
				value *= additional_value
			CsdrTypes.OP.AVG:
				print("Averaging additional value: (%s + %s) / 2 = %s" % [value, additional_value, (value + additional_value) / 2])
				value = (value + additional_value) / 2
			_:
				assert(false, "Unimplemented operation: %s" % operation_on_other_glance)

	if use_comparison and not _check_condition(value): value = 0.0
	
	return value

func _check_condition(value: float) -> bool:
	print("Checking condition: value=%s, threshold=%s, comparison=%s" % [value, threshold, comparison])
	var condition_met = false
	match comparison:
		CsdrTypes.DETECTION.EQUAL:
			condition_met = value == threshold
			print("  [Glance] value == threshold = %s" % condition_met)
		CsdrTypes.DETECTION.ABOVE:
			condition_met = value >= threshold if or_equal else value > threshold
			print("  [Glance] value >= threshold = %s" % condition_met)
		CsdrTypes.DETECTION.BELOW:
			condition_met = value <= threshold if or_equal else value < threshold
			print("  [Glance] value <= threshold = %s" % condition_met)
		_:
			print("  [Glance] Condition not met: unknown comparison type")

	return condition_met