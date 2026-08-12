class_name PotencyObj extends Resource

@export var potency: SquadBattleTypes.Potency
@export var curve: Curve

func _to_string() -> String:
	return "PotencyObj(potency=%s, curve=%s)" % [potency, curve]