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
		result.add_narrative("No destination set for travel!")
		return result
	
	var destination = _world.get_location_by_id(destination_id)
	if not destination:
		result.add_narrative("Destination not found: %s" % destination_id)
		return result
	
	var path = _world.find_path(_location.location_id, destination_id)
	if path.is_empty():
		result.add_narrative("No path exists to %s from here." % destination.location_name)
		return result
	
	var is_adjacent = _location.is_connected_to(destination_id)
	var next_location_id: String
	
	if is_adjacent:
		next_location_id = destination_id
	else:
		if path.size() < 2:
			result.add_narrative("Invalid path to destination.")
			return result
		next_location_id = path[1]
	
	var next_location = _world.get_location_by_id(next_location_id)
	if not next_location:
		result.add_narrative("Next waypoint not found.")
		return result
	
	time_cost = _location.calculate_base_travel_time(next_location)
	if time_cost < 0:
		result.add_narrative("Invalid travel route.")
		return result
	
	squad.set_location(next_location_id)
	result.location_changed = next_location_id
	
	if next_location_id == destination_id:
		result.add_narrative("Arrived at %s (took %d turns)" % [destination.location_name, time_cost])
	else:
		var remaining_distance = path.size() - 2
		result.add_narrative("Traveled to %s, en route to %s (%d more steps)" % [next_location.location_name, destination.location_name, remaining_distance])
	
	if randf() < 0.6:
		var travel_events = ["ambush", "merchant_encounter", "weather_event", "bandit_sighting"]
		var event_id = travel_events[randi() % travel_events.size()]
		result.trigger_event(event_id)
		result.add_narrative("An event occurs during travel!")
	
	return result

