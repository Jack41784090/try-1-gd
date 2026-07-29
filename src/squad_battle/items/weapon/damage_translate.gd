class_name DamageTranslation extends Resource

@export var reality: SquadBattleTypes.Reality
@export var potency_list: Array[PotencyObj]

func _to_string() -> String:
	return "DamageTranslation(reality=%s, potency_list=%s)" % [reality, potency_list]