extends Activity
class_name TravelActivity

@export var destination_id: String = ""

func _init() -> void:
	activity_id = "travel"
	activity_name = "Travel"
	description = "Move from one location to the next. The foundation of any journey."
	activity_type = StrategyTypes.ActivityType.TRAVEL
	time_cost = 1
	location_requirements = [
		StrategyTypes.LocationType.ROAD,
		StrategyTypes.LocationType.VILLAGE,
		StrategyTypes.LocationType.TOWN,
		StrategyTypes.LocationType.CITY,
		StrategyTypes.LocationType.FORT
	]
	money_cost = 0.0
	food_cost = 0

func execute(squad: StrategicSquad, _world: World, _location: Location) -> StrategyTypes.ActivityResult:
	var result = StrategyTypes.ActivityResult.new()
	
	if destination_id.is_empty():
		# Error case - no EventChain needed
		return result
	
	var destination = _world.get_location_by_id(destination_id)
	if not destination:
		# Error case - no EventChain needed
		return result
	
	var path = _world.find_path(_location.location_id, destination_id)
	if path.is_empty():
		# Error case - no EventChain needed
		return result
	
	var is_adjacent = _location.is_connected_to(destination_id)
	var next_location_id: String
	
	if is_adjacent:
		next_location_id = destination_id
	else:
		if path.size() < 2:
			# Error case - no EventChain needed
			return result
		next_location_id = path[1]
	
	var next_location = _world.get_location_by_id(next_location_id)
	if not next_location:
		# Error case - no EventChain needed
		return result
	
	time_cost = _location.calculate_base_travel_time(next_location)
	if time_cost < 0:
		# Error case - no EventChain needed
		return result
	
	squad.set_location(next_location_id)
	result.location_changed = next_location_id
	
	# Trigger EventChain for narrative experience
	result.event_chain_path = "res://resources/event_chains/travel_activity_chain.tres"
	
	if randf() < 0.6:
		var travel_events = ["ambush", "merchant_encounter", "weather_event", "bandit_sighting"]
		var event_id = travel_events[randi() % travel_events.size()]
		result.trigger_event(event_id)
	
	return result

