class_name ForageHandler
extends ActivityHandler


func execute(context: Dictionary, result: ActivityResult) -> ActivityResult:
	var squad = context.get("squad") as SquadData
	var world = context.get("world") as World
	var location = world.get_location_by_id(squad.current_location_id)

	if not location:
		return result

	var food_gained: int = 0
	match location.type:
		StrategyTypes.LocationType.ROAD:
			food_gained = randi_range(1, 2)
		StrategyTypes.LocationType.VILLAGE:
			food_gained = randi_range(2, 4)
		StrategyTypes.LocationType.FORT:
			food_gained = randi_range(1, 2)
		StrategyTypes.LocationType.TOWN:
			food_gained = randi_range(0, 1)
		StrategyTypes.LocationType.CITY:
			food_gained = 0

	squad.food += food_gained
	Log.info("ForageHandler", "FORAGE at %s (%s): gained %d food (now %d)" % [
		location.location_name,
		StrategyTypes.LocationType.keys()[location.type],
		food_gained,
		squad.food,
	])

	return result
