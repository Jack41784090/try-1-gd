extends RefCounted

class_name CombatEntityConfig

var resource: CombatEntityResource
var side: SquadBattleTypes.Side
var player_id: int
var starting_location: SquadBattleTypes.SquadEntityInSquadLocation = SquadBattleTypes.SquadEntityInSquadLocation.Front


func _init(
		_resource: CombatEntityResource,
		_player_id: int,
		_starting_location: SquadBattleTypes.SquadEntityInSquadLocation,
):
	resource = _resource
	player_id = _player_id
	starting_location = _starting_location
