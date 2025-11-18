extends Resource
class_name Location

@export var location_id: String = ""
@export var location_name: String = ""
@export var type: StrategyTypes.LocationType = StrategyTypes.LocationType.VILLAGE
@export var development: int = 50
@export var stability: float = 100.0
@export var connected_location_ids: Array[String] = []
@export var available_activity_types: Array[StrategyTypes.ActivityType] = []

func modify_stability(amount: float) -> void:
	stability = clamp(stability + amount, 0.0, 200.0)

func modify_development(amount: int) -> void:
	development = clamp(development + amount, 0, 200)

func is_connected_to(location_id_check: String) -> bool:
	return location_id_check in connected_location_ids

func calculate_base_travel_time(to_location: Location) -> int:
	if not is_connected_to(to_location.location_id):
		return -1
	
	var base_time = 1
	
	if self.type == StrategyTypes.LocationType.ROAD:
		base_time -= 1
	
	if to_location.type == StrategyTypes.LocationType.ROAD:
		base_time -= 1
	
	base_time = max(1, base_time)
	
	if stability < 50.0 or to_location.stability < 50.0:
		base_time += 1
	
	return base_time

func has_activity_type(activity_type: StrategyTypes.ActivityType) -> bool:
	return activity_type in available_activity_types

func add_activity_type(activity_type: StrategyTypes.ActivityType) -> void:
	if not has_activity_type(activity_type):
		available_activity_types.append(activity_type)

func set_activity_types(types: Array[StrategyTypes.ActivityType]) -> void:
	available_activity_types.clear()
	available_activity_types.append_array(types)

func add_connection(location_id_to_connect: String) -> void:
	if not location_id_to_connect in connected_location_ids:
		connected_location_ids.append(location_id_to_connect)

func set_connections(connections: Array[String]) -> void:
	connected_location_ids.clear()
	connected_location_ids.append_array(connections)

