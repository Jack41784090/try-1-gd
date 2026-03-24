extends Resource
class_name Location

@export var location_id: String = ""
@export var location_name: String = ""
@export var type: StrategyTypes.LocationType = StrategyTypes.LocationType.VILLAGE
@export var development: int = 50
@export var stability: float = 100.0
@export var connections: TownConnections
@export var available_activity_types: Array[StrategyTypes.ActivityType] = []
@export var shop: Shop
@export var clues: Array[Clue] = []
@export var supply_rules: Array[SupplyRule] = []
@export var inventory: LocationInventory
@export var population_config: PopulationConfig

var population: Population

func has_economy() -> bool:
	return population != null and inventory != null

func modify_stability(amount: float) -> void:
	stability = clamp(stability + amount, 0.0, 200.0)

func modify_development(amount: int) -> void:
	development = clamp(development + amount, 0, 200)

func is_connected_to(location_id_check: String) -> bool:
	return get_connection_to(location_id_check) != null

func calculate_base_travel_time(to_location: Location) -> int:
	var conn := get_connection_to(to_location.location_id)
	if conn == null:
		return -1
	
	var base_time: int = conn.travel_time
	
	if self.type == StrategyTypes.LocationType.ROAD:
		base_time -= 1
	
	if to_location.type == StrategyTypes.LocationType.ROAD:
		base_time -= 1
	
	base_time = max(1, base_time)
	
	if stability < 50.0 or to_location.stability < 50.0:
		base_time += 1
	
	return base_time

func get_connection_to(location_id_check: String) -> TownConnection:
	if connections == null:
		return null
	for conn in connections.tt:
		if conn.to_location_id == location_id_check:
			return conn
	return null

func has_shop() -> bool:
	return shop != null and shop.items.size() > 0

func has_activity_type(activity_type: StrategyTypes.ActivityType) -> bool:
	return activity_type in available_activity_types

func add_activity_type(activity_type: StrategyTypes.ActivityType) -> void:
	if not has_activity_type(activity_type):
		available_activity_types.append(activity_type)

func set_activity_types(types: Array[StrategyTypes.ActivityType]) -> void:
	available_activity_types.clear()
	available_activity_types.append_array(types)

func add_connection(location_id_to_connect: String, _time: int = 1) -> void:
	if connections == null:
		connections = TownConnections.new()
	if not is_connected_to(location_id_to_connect):
		connections.tt.append(TownConnection.new(location_id, location_id_to_connect, _time))

func add_clue(clue: Clue) -> void:
	clues.append(clue)

func get_active_clues(current_turn: int) -> Array[Clue]:
	var active: Array[Clue] = []
	for clue in clues:
		if not clue.is_expired(current_turn):
			active.append(clue)
	return active

func decay_clues() -> void:
	for clue in clues:
		clue.decay_one_turn()
	
	var i = clues.size() - 1
	while i >= 0:
		if clues[i].decay <= 0:
			clues.remove_at(i)
		i -= 1

func investigate_clues(perception: int, current_turn: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for clue in get_active_clues(current_turn):
		var info = {
			"clue_name": clue.clue_name,
			"age_description": clue.get_age_description(current_turn),
			"destination_hint": clue.get_destination_hint(perception)
		}
		results.append(info)
	return results
