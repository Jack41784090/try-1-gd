class_name CombatEntityConfig
extends RefCounted


var resource: CombatEntityResource
var side: SquadBattleTypes.Side
var player_id: int
var starting_location: SquadBattleTypes.SquadEntityInSquadLocation = SquadBattleTypes.SquadEntityInSquadLocation.Front
var resolved_constants: Dictionary[StatName.I, Variant] = {}


func _init(
		_resource: CombatEntityResource,
		_side: SquadBattleTypes.Side,
		_player_id: int,
		_starting_location: SquadBattleTypes.SquadEntityInSquadLocation,
		_resolved_constants: Dictionary[StatName.I, Variant] = {},
):
	resource = _resource
	side = _side
	player_id = _player_id
	starting_location = _starting_location
	resolved_constants = _resolved_constants
