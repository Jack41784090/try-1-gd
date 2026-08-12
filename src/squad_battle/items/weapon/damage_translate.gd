class_name DamageTranslation extends Resource

@export var reality: SquadBattleTypes.Reality
@export var potency_list: Array[PotencyObj]

func _to_string() -> String:
	return "DamageTranslation(reality=%s, potency_list=%s)" % [reality, potency_list]

func evaluate(attacker) -> Dictionary:
	var reality_value: float = attacker.calculate_reality_value(reality)
	var result: Dictionary = {}
	for potency_entry in potency_list:
		var potency_damage: float = potency_entry.curve.sample(reality_value)
		result[potency_entry.potency] = result.get(potency_entry.potency, 0.0) + potency_damage
	return result