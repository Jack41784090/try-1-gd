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

var highest_contact_on_us: float:
	get:
		if not _highest_contact_on_us_computed:
			_highest_contact_on_us = _compute_highest_contact_on_us()
			_highest_contact_on_us_computed = true
		return _highest_contact_on_us

var our_best_contact: float:
	get:
		if not _our_best_contact_computed:
			_our_best_contact = _compute_our_best_contact()
			_our_best_contact_computed = true
		return _our_best_contact

var can_ambush: bool:
	get:
		if not _can_ambush_computed:
			_can_ambush = _compute_can_ambush()
			_can_ambush_computed = true
		return _can_ambush

var ambush_target_id: String:
	get:
		if not _ambush_target_computed:
			_compute_can_ambush()
		return _ambush_target_id

var weakest_tracked_enemy_warriors: int:
	get:
		if not _weakest_tracked_enemy_warriors_computed:
			_weakest_tracked_enemy_warriors = _compute_weakest_tracked_enemy_warriors()
			_weakest_tracked_enemy_warriors_computed = true
		return _weakest_tracked_enemy_warriors

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
var _highest_contact_on_us: float = 0.0
var _highest_contact_on_us_computed: bool = false
var _our_best_contact: float = 0.0
var _our_best_contact_computed: bool = false
var _can_ambush: bool = false
var _can_ambush_computed: bool = false
var _ambush_target_id: String = ""
var _ambush_target_computed: bool = false
var _weakest_tracked_enemy_warriors: int = 0
var _weakest_tracked_enemy_warriors_computed: bool = false

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

func _compute_highest_contact_on_us() -> float:
	var tracker = world.contact_tracker
	var contacts_on = tracker.get_contacts_on(squad.squad_id)
	var highest := 0.0
	for c in contacts_on:
		if c.progress > highest:
			highest = c.progress
	return highest

func _compute_our_best_contact() -> float:
	var tracker = world.contact_tracker
	var our_contacts = tracker.get_contacts_for(squad.squad_id)
	var best := 0.0
	for c in our_contacts:
		if c.progress > best:
			best = c.progress
	return best

func _compute_can_ambush() -> bool:
	_can_ambush_computed = true
	_ambush_target_computed = true
	var tracker = world.contact_tracker
	var our_contacts = tracker.get_contacts_for(squad.squad_id)
	for c in our_contacts:
		if c.get_state() != StrategyTypes.ContactState.LOCKED:
			continue
		var their_contact = tracker.get_contact(c.target_id, squad.squad_id)
		if not their_contact or their_contact.get_state() in [StrategyTypes.ContactState.NONE, StrategyTypes.ContactState.SUSPECTED]:
			_ambush_target_id = c.target_id
			return true
	_ambush_target_id = ""
	return false

func _compute_weakest_tracked_enemy_warriors() -> int:
	var tracker = world.contact_tracker
	var our_contacts = tracker.get_contacts_for(squad.squad_id)
	var min_warriors := 999
	for c in our_contacts:
		if c.get_state() < StrategyTypes.ContactState.TRACKED:
			continue
		var target = _find_squad_by_id(c.target_id)
		if target:
			var living = target.get_living_warriors().size()
			min_warriors = mini(min_warriors, living)
	return min_warriors if min_warriors < 999 else 0

func _find_squad_by_id(target_id: String) -> SquadStrategicData:
	for s in world.roaming_squads:
		if s.squad_id == target_id:
			return s
	return null
