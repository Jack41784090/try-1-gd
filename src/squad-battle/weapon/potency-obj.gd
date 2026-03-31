class_name PotencyObj extends Resource

@export var potency: SquadBattleTypes.Potency
@export var value: float

func _to_string() -> String:
	return "PotencyObj(potency=%s, value=%f)" % [potency, value]