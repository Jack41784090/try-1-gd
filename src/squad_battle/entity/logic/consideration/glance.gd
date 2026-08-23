class_name Glance
extends Resource

enum Glanceable {
	RDN,
	HP,
	STA,
	ORG,
	POS,
	MAG,
	LOC,
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


func evaluate(entity: CombatEntity) -> float:
	## Pipeline order: raw_value → normalize_as_percentage → chain additional_glance → comparison gate.
	var value: float
	if property in changeables:
		value = entity.get_changeable_stat_num(_glanceable_translate(property))
		if inverse:
			value = 1.0 - value
	elif property in realities:
		value = entity.calculate_reality_value(_glanceable_translate(property))
		if inverse:
			value = 1.0 - value
	elif property == Glanceable.RDN:
		value = rng.randf_range(0.0, threshold)
	else:
		assert(false, "Invalid glanceable: %s" % property)
		value = 0.0

	if normalize_as_percentage:
		var max_v: float
		if property in changeables:
			max_v = entity.get_ceiling_changeable_stat(_glanceable_translate(property))
		elif property in realities:
			max_v = entity.calculate_reality_value(_glanceable_translate(property))
		elif property == Glanceable.RDN:
			max_v = threshold
		else:
			assert(false, "Invalid glanceable: %s" % property)
			max_v = 0.0
		value = value / max(max_v, 1.0)

	if additional_glance != null:
		var additional_value = additional_glance.evaluate(entity)
		match operation_on_other_glance:
			CsdrTypes.OP.ADD:
				value += additional_value
			CsdrTypes.OP.RDC:
				value -= additional_value
			CsdrTypes.OP.MUL:
				value *= additional_value
			CsdrTypes.OP.AVG:
				value = (value + additional_value) / 2
			_:
				assert(false, "Unimplemented operation: %s" % operation_on_other_glance)

	if use_comparison and not _check_condition(value):
		value = 0.0

	return value


func _check_condition(value: float) -> bool:
	var condition_met = false
	match comparison:
		CsdrTypes.DETECTION.EQUAL:
			condition_met = value == threshold
		CsdrTypes.DETECTION.ABOVE:
			condition_met = value >= threshold if or_equal else value > threshold
		CsdrTypes.DETECTION.BELOW:
			condition_met = value <= threshold if or_equal else value < threshold
		_:
			push_warning("[Glance] Unknown comparison type: %d" % comparison)
	return condition_met
