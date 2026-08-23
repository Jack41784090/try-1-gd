class_name Location
extends Resource

#region pointless vars
@export var development: int = 50
@export var stability: float = 100.0
@export var available_activity_types: Array[StrategyTypes.ActivityType] = []
@export var clues: Array[Clue] = []
@export var consumer_demand: Dictionary = {} ## Thing -> {"qty": float, "priority": float} — hourly consumer orders for LocationEconomySystem
@export var is_imperial: bool = false
@export var government_config: GovernmentConfig
#endregion

@export var location_id: String = ""
@export var location_name: String = ""
@export var type: StrategyTypes.LocationType = StrategyTypes.LocationType.VILLAGE
@export var connections: TownConnections
@export var shop: Shop
@export var natural_resources: Array[NaturalResource] = []
@export var inventory: LocationInventory
@export var population_config: PopulationConfig
@export var guild_configs: Array[GuildConfig] = []
@export var population: Population

func is_connected_to(location_id_check: String) -> bool:
	return get_connection_to(location_id_check) != null

func get_distance_km(to_location: Location) -> float:
	var conn := get_connection_to(to_location.location_id)
	if conn == null:
		return -1.0
	return conn.distance_km

func get_travel_hours(to_location: Location, base_speed_kmh: float) -> float:
	var dist := get_distance_km(to_location)
	if dist < 0.0:
		return -1.0
	var speed_modifier := 1.0
	if self.type == StrategyTypes.LocationType.ROAD:
		speed_modifier += 0.2
	if to_location.type == StrategyTypes.LocationType.ROAD:
		speed_modifier += 0.2
	if stability < 50.0 or to_location.stability < 50.0:
		speed_modifier -= 0.2
	speed_modifier = max(0.2, speed_modifier)
	var effective_speed := base_speed_kmh * speed_modifier
	return dist / effective_speed

func get_connection_to(location_id_check: String) -> TownConnection:
	if connections == null:
		return null
	for conn in connections.tt:
		if conn.to_location_id == location_id_check:
			return conn
	return null

func has_activity_type(activity_type: StrategyTypes.ActivityType) -> bool:
	return activity_type in available_activity_types

func add_activity_type(activity_type: StrategyTypes.ActivityType) -> void:
	if not has_activity_type(activity_type):
		available_activity_types.append(activity_type)

func has_shop() -> bool:
	if shop == null:
		return false
	assert(inventory != null, "Location '%s' has a shop but no inventory — shops require economy" % location_id)
	return true

func has_economy() -> bool:
	assert(inventory != null, "Location '%s' (%s) is missing inventory but economy is mandatory" % [location_id, StrategyTypes.LocationType.keys()[type]])
	return true

func add_connection(location_id_to_connect: String, _dist: float = 10.0) -> void:
	if connections == null:
		connections = TownConnections.new()
	if not is_connected_to(location_id_to_connect):
		connections.tt.append(TownConnection.new(location_id, location_id_to_connect, _dist))

func add_clue(clue: Clue) -> void:
	clues.append(clue)

func get_active_clues(current_hour: int) -> Array[Clue]:
	var active: Array[Clue] = []
	for clue in clues:
		if not clue.is_expired(current_hour):
			active.append(clue)
	return active

func decay_clues() -> void:
	for clue in clues:
		clue.decay_one_hour()
	
	var i = clues.size() - 1
	while i >= 0:
		if clues[i].decay <= 0:
			clues.remove_at(i)
		i -= 1

func investigate_clues(perception: int, current_hour: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for clue in get_active_clues(current_hour):
		var info = {
			"clue_name": clue.clue_name,
			"age_description": clue.get_age_description(current_hour),
			"destination_hint": clue.get_destination_hint(perception)
		}
		results.append(info)
	return results
