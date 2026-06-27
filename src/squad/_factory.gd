class_name SquadDataFactory extends RefCounted

static func create_squad(
	squad_id: String = "",
	squad_name: String = "",
	money: float = 100.0,
	food: int = 0,
	travel_tools: int = 5,
	karma: float = 0.0,
	starting_location_id: String = "",
	current_location_id: String = "",
	squad_role: StrategyTypes.SquadRole = StrategyTypes.SquadRole.COMBAT,
) -> StrategySquad:
	var squad := StrategySquad.new()
	var resolved_location_id := current_location_id if not current_location_id.is_empty() else starting_location_id

	squad.squad_id = squad_id
	squad.squad_name = squad_name
	squad.money = money
	squad.food = food
	squad.travel_tools = travel_tools
	squad.karma = karma
	squad.starting_location_id = starting_location_id
	squad.current_location_id = resolved_location_id
	squad.squad_role = squad_role

	return squad
