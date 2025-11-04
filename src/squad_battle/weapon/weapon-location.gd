class_name WeaponLocation extends Resource

@export var from: SquadBattleTypes.SquadEntityInSquadLocation
@export var can_hit: Array[SquadBattleTypes.SquadEntityInSquadLocation]

func _to_string() -> String:
	return "WeaponLocation(from=%s, can_hit=%s)" % [from, can_hit]

# func _init(p_from: SquadBattleTypes.SquadEntityInSquadLocation, p_can_hit: Array[SquadBattleTypes.SquadEntityInSquadLocation]):
# 	from = p_from
# 	can_hit = p_can_hit