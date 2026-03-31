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
@export var current_hour: int = 0
@export var is_paused: bool = true
@export var speed_multiplier: float = 1.0
@export var roaming_squads: Array[SquadData] = []
@export var map_scene: PackedScene
@export var goods: Array[Thing] = []

var economy_engine: EconomyEngine = null

func get_day() -> int:
	return current_hour / 24 + 1

func get_hour_of_day() -> int:
	return current_hour % 24

func get_clock_display() -> String:
	return "Day %d — %02d:00" % [get_day(), get_hour_of_day()]

func get_economy_locations() -> Array[Location]:
	var result: Array[Location] = []
	for loc in locations:
		if loc.has_economy():
			result.append(loc)
	return result

var contact_tracker:
	get:
		if contact_tracker == null:
			var TrackerClass = load("res://src/strategy/core/contact/tracker.gd")
			contact_tracker = TrackerClass.new()
		return contact_tracker

var travel_graph: TravelGraph = null:
	get:
		if travel_graph == null:
			travel_graph = TravelGraph.new()
			for location in locations:
				travel_graph.add_location(location)
		return travel_graph

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
	for location in locations:
		travel_graph.add_location(location)

func find_path(from_id: String, to_id: String) -> Array[String]:
	if not travel_graph:
		build_travel_graph()
	
	return travel_graph.find_path(from_id, to_id)

func calculate_travel_hours(from_id: String, to_id: String, speed_kmh: float) -> float:
	var path = travel_graph.find_path(from_id, to_id)
	if path.is_empty():
		return -1.0
	return travel_graph.calculate_travel_hours(path, speed_kmh)

func get_squads_at_location(location_id: String) -> Array[SquadData]:
	var squads_at_loc: Array[SquadData] = []
	for squad in roaming_squads:
		if squad.current_location_id == location_id:
			squads_at_loc.append(squad)
	return squads_at_loc

func add_roaming_squad(squad: SquadData) -> void:
	roaming_squads.append(squad)

func remove_roaming_squad(squad_id: String) -> void:
	for i in range(roaming_squads.size() - 1, -1, -1):
		if roaming_squads[i].squad_id == squad_id:
			roaming_squads.remove_at(i)
			break

func move_squad_to_location(squad_id: String, location_id: String) -> void:
	for squad in roaming_squads:
		if squad.squad_id == squad_id:
			squad.set_location(location_id)
			break


func find_nearest_location(from_id: String) -> String:
	var visited: Dictionary = {}
	var queue: Array[String] = []
	visited[from_id] = true
	var from_loc = get_location_by_id(from_id)
	if not from_loc or not from_loc.connections:
		return ""
	for conn in from_loc.connections.tt:
		if not visited.has(conn.to_location_id):
			queue.append(conn.to_location_id)
			visited[conn.to_location_id] = true
	while queue.size() > 0:
		var current_id = queue.pop_front()
		if current_id != from_id:
			return current_id
		var loc = get_location_by_id(current_id)
		if loc and loc.connections:
			for conn in loc.connections.tt:
				if not visited.has(conn.to_location_id):
					queue.append(conn.to_location_id)
					visited[conn.to_location_id] = true
	return ""

func get_adjacent_squads(location_id: String) -> Array[SquadData]:
	var adjacent_squads: Array[SquadData] = []
	var location = get_location_by_id(location_id)
	if not location:
		return adjacent_squads
	
	for connected_id in location.connections:
		var squads_there = get_squads_at_location(connected_id)
		for squad in squads_there:
			adjacent_squads.append(squad)
	return adjacent_squads

func save_state() -> Dictionary:
	var location_data: Array = []
	for location in locations:
		location_data.append({
			"id": location.location_id,
			"name": location.location_name,
			"type": location.type,
			"development": location.development,
			"stability": location.stability,
			"connections": location.connections,
			"activities": location.available_activity_types
		})
	
	return {
		"end_progression": end_progression,
		"global_modifiers": global_modifiers,
		"current_hour": current_hour,
		"locations": location_data
	}

func load_state(data: Dictionary) -> void:
	end_progression = data.get("end_progression", 0.0)
	global_modifiers = data.get("global_modifiers", global_modifiers)
	current_hour = data.get("current_hour", 0)
	
	locations.clear()
	var location_data = data.get("locations", [])
	for loc_dict in location_data:
		var location = Location.new()
		location.location_id = loc_dict.get("id", "")
		location.location_name = loc_dict.get("name", "")
		location.type = loc_dict.get("type", StrategyTypes.LocationType.VILLAGE)
		location.development = loc_dict.get("development", 50)
		location.stability = loc_dict.get("stability", 100.0)
		location.connections = loc_dict.get("connections", [])
		location.available_activity_types = loc_dict.get("activities", [])
		locations.append(location)
