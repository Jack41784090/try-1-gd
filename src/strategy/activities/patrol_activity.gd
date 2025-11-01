extends Activity
class_name PatrolActivity

func _init() -> void:
	activity_id = "patrol"
	activity_name = "Patrol"
	description = "Assert your squad's presence in the local area, deterring banditry and reassuring the populace."
	activity_type = StrategyTypes.ActivityType.PATROL
	time_cost = 2
	location_requirements = [
		StrategyTypes.LocationType.CITY,
		StrategyTypes.LocationType.TOWN,
		StrategyTypes.LocationType.VILLAGE
	]
	money_cost = 0.0
	food_cost = 0

func execute(squad: StrategicSquad, _world: World, _location: Location) -> StrategyTypes.ActivityResult:
	var result = StrategyTypes.ActivityResult.new()
	
	var stability_increase = 10.0
	_location.modify_stability(stability_increase)
	
	var reputation_gain = 5.0
	squad.modify_karma(reputation_gain)
	result.modify_squad_stat("karma", reputation_gain)
	
	# Trigger EventChain for narrative experience
	result.event_chain_path = "res://resources/event_chains/patrol_activity_chain.tres"
	
	# TEMP: Guarantee chained event for testing
	result.trigger_event("mysterious_stranger")
	
	return result

