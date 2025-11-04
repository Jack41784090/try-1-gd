class_name DamageTranslation extends Resource

@export var Reality: SquadBattleTypes.Reality
@export var PotencyList: Array[PotencyObj]

func _to_string() -> String:
	return "DamageTranslation(Reality=%s, PotencyList=%s)" % [Reality, PotencyList]

# func _init(p_Reality: SquadBattleTypes.Reality, p_PotencyList: Array[PotencyObj]):
# 	Reality = p_Reality
# 	PotencyList = p_PotencyList