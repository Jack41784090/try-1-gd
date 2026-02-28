class_name Glance
extends Resource

enum Glanceable {
	# random
	RDN,

	# Changeable stats
	HP,
	STA,
	ORG,
	POS,
	MAG,
	LOC,

	# Reality
	FORCE,
}

var changeables = [
	Glanceable.HP,
	Glanceable.STA,
	Glanceable.ORG,
	Glanceable.POS,
	Glanceable.MAG,
	Glanceable.LOC,
]
var realities = [
	Glanceable.FORCE,
]

@export var property: Glanceable
@export var normalize_as_percentage: bool = false
@export var use_comparison: bool = false
@export var comparison: CsdrTypes.DETECTION = CsdrTypes.DETECTION.ABOVE
@export var threshold: float = 0.0
@export var or_equal: bool = false
@export var operation_on_other_glance: CsdrTypes.OP = CsdrTypes.OP.ADD
@export var additional_glance: Glance = null
@export var inverse: bool = false

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _glanceable_translate(glanceable: Glanceable):
	match glanceable:
		Glanceable.RDN:
			return rng.randf_range(0.0, threshold)
		Glanceable.HP:
			return SquadBattleTypes.EntityChangeable.HP
		Glanceable.STA:
			return SquadBattleTypes.EntityChangeable.STA
		Glanceable.ORG:
			return SquadBattleTypes.EntityChangeable.ORG
		Glanceable.POS:
			return SquadBattleTypes.EntityChangeable.POS
		Glanceable.MAG:
			return SquadBattleTypes.EntityChangeable.MAG
		Glanceable.LOC:
			return SquadBattleTypes.EntityChangeable.LOC
		Glanceable.FORCE:
			return SquadBattleTypes.Reality.Force
		_:
			assert(false, "Invalid glanceable: %s" % glanceable)


func _to_string() -> String:
	return "Glance(property=%s, normalize=%s, comparison=%s)" % [
		Glanceable.keys()[property] if property >= 0 else "None",
		normalize_as_percentage,
		use_comparison,
	]


func _get_glanceable_value(entity: CharacterCombatStats, glanceable: Glanceable) -> float:
	if glanceable in changeables:
		var value = entity.get_changeable_stat_num(_glanceable_translate(glanceable))
		if inverse:
			value = 1.0 - value
		return value
	elif glanceable in realities:
		var value = entity.calculate_reality_value(_glanceable_translate(glanceable))
		if inverse:
			value = 1.0 - value
		return value
	elif glanceable == Glanceable.RDN:
		return rng.randf_range(0.0, threshold)
	else:
		assert(false, "Invalid glanceable: %s" % glanceable)
	return 0.0


func _get_glanceable_value_max(entity: CharacterCombatStats, glanceable: Glanceable) -> float:
	if glanceable in changeables:
		return entity.get_ceiling_changeable_stat(_glanceable_translate(glanceable))
	elif glanceable in realities:
		return entity.calculate_reality_value(_glanceable_translate(glanceable))
	elif glanceable == Glanceable.RDN:
		return threshold
	else:
		assert(false, "Invalid glanceable: %s" % glanceable)
	return 0.0


func evaluate(entity: CharacterCombatStats) -> float:
	# Reads a single combat stat from an entity, processes it (normalize, inverse, chain, gate)
	# Pipeline: raw_value → normalize_as_percentage → chain additional_glance → comparison gate
	# e.g., Glance(property=HP, normalize=true, inverse=true)
	#   → entity HP=30, max=100 → normalize(30/100)=0.3 → inverse(1.0-0.3)=0.7
	# e.g., Glance(property=LOC, use_comparison=true, comparison=ABOVE, threshold=2)
	#   → entity LOC=1 → check: 1 > 2 → false → returns 0.0
	var value = _get_glanceable_value(entity, property)

	print("Evaluating glance: %s, value=%s" % [self, value])

	if normalize_as_percentage:
		var max_v = _get_glanceable_value_max(entity, property)
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

	if use_comparison and not _check_condition(value):
		value = 0.0

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
