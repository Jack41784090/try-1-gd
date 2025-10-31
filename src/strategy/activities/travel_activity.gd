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
	
	if not _location.is_connected_to(destination_id):
		result.add_narrative("Cannot travel to %s from here." % destination.location_name)
		return result
	
	time_cost = _location.calculate_base_travel_time(destination)
	if time_cost < 0:
		result.add_narrative("Invalid travel route.")
		return result
	
	squad.set_location(destination_id)
	result.location_changed = destination_id
	result.add_narrative("Traveled to %s (took %d turns)" % [destination.location_name, time_cost])
	
	if randf() < 0.6:
		var travel_events = ["ambush", "merchant_encounter", "weather_event", "bandit_sighting"]
		var event_id = travel_events[randi() % travel_events.size()]
		result.trigger_event(event_id)
		result.add_narrative("An event occurs during travel!")
	
	return result

