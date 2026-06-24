class_name ProtectionTranslation extends Resource

@export var Reality: SquadBattleTypes.Reality
@export var PotencyList: Array[PotencyObj]

func _to_string() -> String:
	return "ProtectionTranslation(Reality=%s, PotencyList=%s)" % [Reality, PotencyList]
