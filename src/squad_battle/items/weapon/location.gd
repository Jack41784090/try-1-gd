class_name WeaponLocation extends Resource

@export var from: SquadBattleTypes.SquadEntityInSquadLocation
@export var can_hit: Array[SquadBattleTypes.SquadEntityInSquadLocation]

func _to_string() -> String:
	return "WeaponLocation(from=%s, can_hit=%s)" % [from, can_hit]