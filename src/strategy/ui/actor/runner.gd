class_name ActivityRunner
extends Node

var aem: ActivityExecuteManager
var hour_count: int = 0

@onready var player_squad: StrategySquad:
	set(_ps):
		player_squad = _ps
	get:
		## Building a runtime StrategySquad from StrategySquadResource needs a runtime-build bridge not yet written, so this just returns the raw property.
		return player_squad

var locations:
	get:
		return aem.scenario.world.travel_graph.locations

var walking_towards: Variant:
	get:
		if walking_towards == null:
			walking_towards = null
		return walking_towards
	set(_cl):
		if !_cl:
			walking_towards = {"location": null, "progress": 0}
			return

		assert(_cl is String or _cl is Location)
		var new_loc: Location = aem.scenario.world.travel_graph.get_location(_cl) if _cl is String else _cl
		if not walking_towards["location"]:
			walking_towards = {"location": new_loc, "progress": 0}
		elif new_loc.location_id == walking_towards["location"].location_id:
			walking_towards = {"location": new_loc, "progress": walking_towards["progress"] + 1}
		else:
			walking_towards = {"location": new_loc, "progress": 0}

var current_location: Variant:
	get:
		if current_location == null:
			current_location = aem.scenario.starting_location_id
		return current_location
	set(_cl):
		if _cl is String:
			var world_location: Location = aem.scenario.world.travel_graph.get_location(_cl)
			assert(world_location != null, "Invalid location id '%s'" % _cl)
			## Shallow duplicate: keeps town connections shared, but lets us flip location type to road for temporary inter-town travel.
			current_location = world_location.duplicate()
			if current_location.population == null and world_location.population != null:
				current_location.population = world_location.population
		elif _cl is Location:
			current_location = _cl
		else:
			assert(false)
		player_squad.set_location(current_location.location_id)


func setup(_loaded_scenario, context = {}):
	aem = ActivityExecuteManager.new()
	aem.setup(_loaded_scenario, context)


func embark_new_journey(towards: Location):
	current_location = aem.scenario.starting_location_id
	walking_towards = towards


func get_distance(current_id, location_id):
	return aem.scenario.world.travel_graph.calculate_distance_km_between(current_id, location_id)


func get_location_by_id(location_id):
	return aem.scenario.world.get_location_by_id(location_id)


func get_all_reachable_locations(from_id: Variant, max_hops: int = -1) -> Array[String]:
	assert(from_id is String or from_id is Location)
	if from_id is Location:
		from_id = from_id.location_id

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


func exec_before(activity: Activity):
	return aem.exec_before(activity)


func exec_activity(activity: Activity):
	return aem.exec_activity(activity)


func exec_after(activity: Activity):
	return aem.exec_after(activity)

func exec_at(when: StrategyTypes.TriggerWhen):
	return aem.execute_triggerables_at(when )


func advance_hour() -> void:
	hour_count = aem.scenario.world.current_hour


func get_activity(_getting_type: StrategyTypes.ActivityType) -> Activity:
	for triggerable in aem.scenario.triggerable_manager.registered_triggerables:
		if triggerable is Activity and triggerable.activity_type == _getting_type:
			return triggerable as Activity
	return null


func create_travel_activity(location_id: String) -> Activity:
	var activity = get_activity(StrategyTypes.ActivityType.TRAVEL)
	activity.destination_id = location_id
	activity.trigger_id = "travel-to-%s" % location_id
	activity.trigger_name = "Travel"
	activity.description = "Travel to another location"
	activity.activity_type = StrategyTypes.ActivityType.TRAVEL
	activity.time_cost = 1

	var travel_result = ActivityResult.new({"location_changed": location_id})
	travel_result.event_chain_path = "empty"

	var squad := player_squad
	var from_id: String = squad.current_location_id
	var path: Array[String] = aem.scenario.world.travel_graph.find_path(from_id, location_id)

	if path.size() < 2:
		activity.result.location_changed = location_id
		squad.set_location(location_id)
		return activity

	var walking_towards_location = walking_towards["location"]
	if walking_towards_location == null:
		var route: Array[String] = []
		for p in path:
			route.append(p)
		squad.travel_route = route
		squad.travel_segment_index = 0
		squad.travel_progress_km = 0.0
		squad.current_activity_type = StrategyTypes.ActivityType.TRAVEL
		walking_towards = location_id
		activity.result.location_changed = ""
		MyLog.debug("Runner", "New journey to %s from %s (route: %s)" % [location_id, from_id, route])
	elif location_id == walking_towards_location.location_id:
		MyLog.debug("Runner", "Continuing journey towards %s (progress: %.1f km, segment: %d)" % [location_id, squad.travel_progress_km, squad.travel_segment_index])
		var speed := squad.get_speed_kmh()
		squad.travel_progress_km += speed

		var current_seg_from := squad.travel_route[squad.travel_segment_index]
		var current_seg_to := squad.travel_route[squad.travel_segment_index + 1]
		var seg_dist := aem.scenario.world.travel_graph.calculate_distance_km_between(current_seg_from, current_seg_to)

		while squad.travel_progress_km >= seg_dist and squad.travel_segment_index < squad.travel_route.size() - 2:
			squad.travel_progress_km -= seg_dist
			squad.travel_segment_index += 1
			var arrived_at := squad.travel_route[squad.travel_segment_index]
			squad.set_location(arrived_at)
			current_location = arrived_at
			MyLog.debug("Runner", "Reached waypoint: %s" % arrived_at)

			if squad.travel_segment_index < squad.travel_route.size() - 1:
				current_seg_from = squad.travel_route[squad.travel_segment_index]
				current_seg_to = squad.travel_route[squad.travel_segment_index + 1]
				seg_dist = aem.scenario.world.travel_graph.calculate_distance_km_between(current_seg_from, current_seg_to)
			else:
				break

		if squad.travel_segment_index >= squad.travel_route.size() - 2 and squad.travel_progress_km >= seg_dist:
			var final_dest := squad.travel_route[squad.travel_route.size() - 1]
			squad.set_location(final_dest)
			current_location = final_dest
			walking_towards = null
			squad.clear_travel()
			activity.result.location_changed = final_dest
			MyLog.debug("Runner", "Arrived at final destination: %s" % final_dest)
		else:
			activity.result.location_changed = ""
	else:
		MyLog.debug("Runner", "Changing destination to %s" % location_id)
		var route: Array[String] = []
		for p in path:
			route.append(p)
		squad.travel_route = route
		squad.travel_segment_index = 0
		squad.travel_progress_km = 0.0
		squad.current_activity_type = StrategyTypes.ActivityType.TRAVEL
		walking_towards = location_id
		activity.result.location_changed = ""

	return activity
