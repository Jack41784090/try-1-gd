class_name SquadTravelSystem
extends Node

## Stateless: operates purely on whichever StrategySquad is passed in, unlike the earlier per-actor Runner design — no parallel per-instance state to keep in sync.

signal location_changed(squad_id: String, from_id: String, to_id: String)
signal travel_progress_updated(squad_id: String, current_km: float, total_km: float, destination_name: String)

var scenario: GameScenario


func setup(_scenario: GameScenario) -> void:
	scenario = _scenario


func on_request_travel(squad: StrategySquad, _route: Array[String]) -> void:
	advance_travel(squad)


func get_distance(from_id, to_id) -> float:
	return scenario.world.travel_graph.calculate_distance_km_between(from_id, to_id)


func get_location_by_id(location_id: String) -> Location:
	return scenario.world.get_location_by_id(location_id)


func get_all_reachable_locations(from_id: Variant, max_hops: int = -1) -> Array[String]:
	assert(from_id is String or from_id is Location)
	if from_id is Location:
		from_id = from_id.location_id

	var locations := scenario.world.travel_graph.locations
	if not locations.has(from_id):
		return []

	var reachable: Array[String] = []
	var visited: Dictionary = {from_id: true}
	var queue: Array[Array] = [[from_id, 0]]

	while queue.size() > 0:
		var current = queue.pop_front()
		var current_id: String = current[0]
		var current_depth: int = current[1]

		if current_id != from_id:
			reachable.append(current_id)

		if max_hops >= 0 and current_depth >= max_hops:
			continue

		var current_loc = locations.get(current_id)
		if not current_loc:
			continue

		for neighbor_id in current_loc.connections:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append([neighbor_id, current_depth + 1])

	return reachable


func begin_travel(squad: StrategySquad, destination_id: String) -> void:
	var path: Array[String] = scenario.world.travel_graph.find_path(squad.current_location_id, destination_id)
	if path.size() < 2:
		_arrive(squad, destination_id)
		return

	var route: Array[String] = []
	for p in path:
		route.append(p)
	squad.travel_route = route
	squad.travel_segment_index = 0
	squad.travel_progress_km = 0.0
	squad.current_activity_type = StrategyTypes.ActivityType.TRAVEL
	LogGd.debug("[SquadTravelSystem] %s: new journey to %s (route: %s)" % [squad.squad_name, destination_id, route])
	travel_progress_updated.emit(squad.squad_id, 0.0, _route_total_km(route), get_location_by_id(destination_id).location_name)


func advance_travel(squad: StrategySquad) -> Activity:
	if not squad.consume_supplies_by_demand():
		squad.modify_morale(-5.0)
	squad.apply_travel_morale_penalty(-2.0)

	var activity := _find_travel_activity_definition()
	var destination_id: String = squad.travel_route[-1]
	activity.destination_id = destination_id
	activity.trigger_id = "travel-to-%s" % destination_id
	activity.trigger_name = "Travel"
	activity.description = "Travel to another location"
	activity.activity_type = StrategyTypes.ActivityType.TRAVEL
	activity.time_cost = 1
	activity.result = ActivityResult.new({"location_changed": ""})
	activity.result.event_chain_path = "empty"

	var speed := squad.get_speed_kmh()
	squad.travel_progress_km += speed

	var current_seg_from := squad.travel_route[squad.travel_segment_index]
	var current_seg_to := squad.travel_route[squad.travel_segment_index + 1]
	var seg_dist := get_distance(current_seg_from, current_seg_to)

	while squad.travel_progress_km >= seg_dist and squad.travel_segment_index < squad.travel_route.size() - 2:
		squad.travel_progress_km -= seg_dist
		squad.travel_segment_index += 1
		var arrived_at := squad.travel_route[squad.travel_segment_index]
		_set_location(squad, arrived_at)
		LogGd.debug("[SquadTravelSystem] %s: reached waypoint %s" % [squad.squad_name, arrived_at])

		if squad.travel_segment_index < squad.travel_route.size() - 1:
			current_seg_from = squad.travel_route[squad.travel_segment_index]
			current_seg_to = squad.travel_route[squad.travel_segment_index + 1]
			seg_dist = get_distance(current_seg_from, current_seg_to)
		else:
			break

	var route_total := _route_total_km(squad.travel_route)
	if squad.travel_segment_index >= squad.travel_route.size() - 2 and squad.travel_progress_km >= seg_dist:
		_arrive(squad, destination_id)
		activity.result.location_changed = destination_id
		travel_progress_updated.emit(squad.squad_id, route_total, route_total, get_location_by_id(destination_id).location_name)
	else:
		var covered := _route_covered_km(squad.travel_route, squad.travel_segment_index, squad.travel_progress_km)
		travel_progress_updated.emit(squad.squad_id, covered, route_total, get_location_by_id(destination_id).location_name)

	return activity


func _arrive(squad: StrategySquad, destination_id: String) -> void:
	_set_location(squad, destination_id)
	squad.travel_route = []
	squad.travel_segment_index = 0
	squad.travel_progress_km = 0.0
	LogGd.debug("[SquadTravelSystem] %s: arrived at %s" % [squad.squad_name, destination_id])


func _set_location(squad: StrategySquad, location_id: String) -> void:
	var from_id := squad.current_location_id
	squad.set_location(location_id)
	if from_id != location_id:
		location_changed.emit(squad.squad_id, from_id, location_id)


func _route_total_km(route: Array[String]) -> float:
	var total := 0.0
	for i in range(route.size() - 1):
		total += get_distance(route[i], route[i + 1])
	return total


func _route_covered_km(route: Array[String], segment_index: int, progress_km: float) -> float:
	var covered := 0.0
	for i in range(segment_index):
		covered += get_distance(route[i], route[i + 1])
	return covered + progress_km


func _find_travel_activity_definition() -> Activity:
	for triggerable in scenario.triggerable_manager.registered_triggerables:
		if triggerable is Activity and triggerable.activity_type == StrategyTypes.ActivityType.TRAVEL:
			return triggerable as Activity
	return null
