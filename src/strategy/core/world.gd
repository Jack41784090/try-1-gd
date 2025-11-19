extends Resource
class_name World

@export var end_progression: float = 0.0
@export var global_modifiers: Dictionary = {
	"metal": 0.0,
	"wood": 0.0,
	"water": 0.0,
	"fire": 0.0,
	"earth": 0.0
}
@export var locations: Array[Location] = []
@export var turn_count: int = 0

var travel_graph: TravelGraph = null

func modify_global_modifier(modifier: StrategyTypes.GlobalModifier, amount: float) -> void:
	var key = _modifier_to_key(modifier)
	global_modifiers[key] = clamp(global_modifiers.get(key, 0.0) + amount, -100.0, 100.0)

func get_global_modifier(modifier: StrategyTypes.GlobalModifier) -> float:
	var key = _modifier_to_key(modifier)
	return global_modifiers.get(key, 0.0)

func _modifier_to_key(modifier: StrategyTypes.GlobalModifier) -> String:
	match modifier:
		StrategyTypes.GlobalModifier.METAL:
			return "metal"
		StrategyTypes.GlobalModifier.WOOD:
			return "wood"
		StrategyTypes.GlobalModifier.WATER:
			return "water"
		StrategyTypes.GlobalModifier.FIRE:
			return "fire"
		StrategyTypes.GlobalModifier.EARTH:
			return "earth"
		_:
			return "metal"

func get_location_by_id(location_id: String) -> Location:
	for location in locations:
		if location.location_id == location_id:
			return location
	return null

func add_location(location: Location) -> void:
	locations.append(location)
	if travel_graph:
		travel_graph.add_location(location)

func build_travel_graph() -> void:
	if not travel_graph:
		travel_graph = TravelGraph.new()

	for location in locations:
		travel_graph.add_location(location)

func find_path(from_id: String, to_id: String) -> Array[String]:
	if not travel_graph:
		build_travel_graph()
	
	return travel_graph.find_path(from_id, to_id)

func calculate_travel_time(from_id: String, to_id: String) -> int:
	if not travel_graph:
		build_travel_graph()
	
	var path = travel_graph.find_path(from_id, to_id)
	if path.is_empty():
		return -1
	
	return travel_graph.calculate_path_travel_time(path)

func get_reachable_locations(from_id: String, max_hops: int = -1) -> Array[String]:
	if not travel_graph:
		build_travel_graph()
	return travel_graph.get_all_reachable_locations(from_id, max_hops)

func advance_turn(amount: int = 1) -> void:
	turn_count += amount

func save_state() -> Dictionary:
	var location_data: Array = []
	for location in locations:
		location_data.append({
			"id": location.location_id,
			"name": location.location_name,
			"type": location.type,
			"development": location.development,
			"stability": location.stability,
			"connections": location.connected_location_ids,
			"activities": location.available_activity_types
		})
	
	return {
		"end_progression": end_progression,
		"global_modifiers": global_modifiers,
		"turn_count": turn_count,
		"locations": location_data
	}

func load_state(data: Dictionary) -> void:
	end_progression = data.get("end_progression", 0.0)
	global_modifiers = data.get("global_modifiers", global_modifiers)
	turn_count = data.get("turn_count", 0)
	
	locations.clear()
	var location_data = data.get("locations", [])
	for loc_dict in location_data:
		var location = Location.new()
		location.location_id = loc_dict.get("id", "")
		location.location_name = loc_dict.get("name", "")
		location.type = loc_dict.get("type", StrategyTypes.LocationType.VILLAGE)
		location.development = loc_dict.get("development", 50)
		location.stability = loc_dict.get("stability", 100.0)
		location.connected_location_ids = loc_dict.get("connections", [])
		location.available_activity_types = loc_dict.get("activities", [])
		locations.append(location)
