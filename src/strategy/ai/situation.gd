class_name StrategicSituation extends RefCounted

var squad: SquadStrategicData
var location: Location
var world: World
var faction: Faction
var directive: FactionDirective

var enemies_here: Array[SquadStrategicData]:
	get:
		if not _enemies_here_computed:
			_enemies_here = _find_enemies_here()
			_enemies_here_computed = true
		return _enemies_here

var adjacent_enemies: Array[SquadStrategicData]:
	get:
		if not _adjacent_enemies_computed:
			_adjacent_enemies = _find_adjacent_enemies()
			_adjacent_enemies_computed = true
		return _adjacent_enemies

var nearest_town: Location:
	get:
		if not _nearest_town_computed:
			_nearest_town = _find_nearest_of_type([StrategyTypes.LocationType.CITY, StrategyTypes.LocationType.TOWN])
			_nearest_town_computed = true
		return _nearest_town

var nearest_enemy_location: Location:
	get:
		if not _nearest_enemy_location_computed:
			_nearest_enemy_location = _find_nearest_enemy_location()
			_nearest_enemy_location_computed = true
		return _nearest_enemy_location

var nearest_town_distance: int:
	get:
		if not _nearest_town_distance_computed:
			if nearest_town != null:
				_nearest_town_distance = world.travel_graph.get_distance(location.location_id, nearest_town.location_id)
			else:
				_nearest_town_distance = -1
			_nearest_town_distance_computed = true
		return _nearest_town_distance

var nearest_enemy_distance: int:
	get:
		if not _nearest_enemy_distance_computed:
			if nearest_enemy_location != null:
				_nearest_enemy_distance = world.travel_graph.get_distance(location.location_id, nearest_enemy_location.location_id)
			else:
				_nearest_enemy_distance = -1
			_nearest_enemy_distance_computed = true
		return _nearest_enemy_distance

var clue_destination_id: String:
	get:
		if not _clue_destination_computed:
			_clue_destination_id = _find_clue_destination()
			_clue_destination_computed = true
		return _clue_destination_id

var _enemies_here: Array[SquadStrategicData] = []
var _enemies_here_computed: bool = false
var _adjacent_enemies: Array[SquadStrategicData] = []
var _adjacent_enemies_computed: bool = false
var _nearest_town: Location = null
var _nearest_town_computed: bool = false
var _nearest_enemy_location: Location = null
var _nearest_enemy_location_computed: bool = false
var _nearest_town_distance: int = -1
var _nearest_town_distance_computed: bool = false
var _nearest_enemy_distance: int = -1
var _nearest_enemy_distance_computed: bool = false
var _clue_destination_id: String = ""
var _clue_destination_computed: bool = false

func _init(p_squad: SquadStrategicData, p_world: World, p_faction: Faction, p_directive: FactionDirective) -> void:
	squad = p_squad
	world = p_world
	faction = p_faction
	directive = p_directive
	location = world.get_location_by_id(squad.current_location_id)
	assert(location != null, "Squad %s has invalid location: %s" % [squad.squad_name, squad.current_location_id])

func _find_enemies_here() -> Array[SquadStrategicData]:
	var result: Array[SquadStrategicData] = []
	var squads_at_loc = world.get_squads_at_location(location.location_id)
	for s in squads_at_loc:
		if s.squad_id != squad.squad_id:
			result.append(s)
	return result

func _find_adjacent_enemies() -> Array[SquadStrategicData]:
	var result: Array[SquadStrategicData] = []
	var adjacent = world.get_adjacent_squads(location.location_id)
	for s in adjacent:
		if s.squad_id != squad.squad_id:
			result.append(s)
	return result

func _find_nearest_of_type(types: Array) -> Location:
	if not world.travel_graph:
		return null

	var visited: Dictionary = {}
	var queue: Array = [location.location_id]
	visited[location.location_id] = true

	while queue.size() > 0:
		var current_id = queue.pop_front()
		var current_loc = world.get_location_by_id(current_id)
		if not current_loc:
			continue

		if current_id != location.location_id and current_loc.type in types:
			return current_loc

		for connection in current_loc.connections.tt:
			var neighbor_id = connection.to_location_id
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append(neighbor_id)

	return null

func _find_nearest_enemy_location() -> Location:
	if not world.travel_graph:
		return null

	var visited: Dictionary = {}
	var queue: Array = [location.location_id]
	visited[location.location_id] = true

	while queue.size() > 0:
		var current_id = queue.pop_front()
		if current_id != location.location_id:
			var squads = world.get_squads_at_location(current_id)
			for s in squads:
				if s.squad_id != squad.squad_id:
					return world.get_location_by_id(current_id)

		var current_loc = world.get_location_by_id(current_id)
		if not current_loc:
			continue
		for connection in current_loc.connections.tt:
			var neighbor_id = connection.to_location_id
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append(neighbor_id)

	return null

func _find_clue_destination() -> String:
	var active_clues = location.get_active_clues(world.turn_count)
	if active_clues.is_empty():
		return ""

	var freshest = active_clues[0]
	for clue in active_clues:
		if clue.created_turn > freshest.created_turn:
			freshest = clue

	return freshest.destination_id
