class_name ActivityRunner
extends Node

var is_executing_activity = false
var aem: ActivityExecuteManager
var turn_count: int = 0

@onready var player_squad: SquadStrategicData:
	set(_ps):
		player_squad = _ps
	get:
		if player_squad == null and aem.scenario.starting_player_squad != null:
			player_squad = aem.scenario.starting_player_squad.strategic_data.duplicate(true)
		return player_squad

var locations:
	get:
		return aem.scenario.world.travel_graph.locations

var travel_progress:
	get:
		if walking_towards == null or walking_towards["location"] == null:
			return 0
		return walking_towards["progress"]
	set(_tp):
		assert(_tp is float or _tp is int)
		if walking_towards == null or walking_towards["location"] == null:
			return
		walking_towards["progress"] = _tp

var walking_towards: Variant:
	get:
		if walking_towards == null:
			walking_towards = null # {"location": null, "progress": 0}
		return walking_towards
	set(_cl):
		if !_cl:
			walking_towards = { "location": null, "progress": 0 }
			return

		assert(_cl is String or _cl is Location)
		var new_loc: Location = aem.scenario.world.travel_graph.get_location(_cl) if _cl is String else _cl
		if not walking_towards["location"]:
			walking_towards = { "location": new_loc, "progress": 0 }
		elif new_loc.location_id == walking_towards["location"].location_id:
			walking_towards = { "location": new_loc, "progress": walking_towards["progress"] + 1 }
		else:
			walking_towards = { "location": new_loc, "progress": 0 }

var current_location: Variant:
	get:
		if current_location == null:
			current_location = aem.scenario.starting_location_id
		return current_location
	set(_cl):
		if _cl is String:
			current_location = aem.scenario.world.travel_graph.get_location(_cl).duplicate() # non deep duplicate so we don't dupe the town connections -- dupe to be able to change location type to road for temporary travelling between towns
		elif _cl is Location:
			current_location = _cl
		else:
			assert(false)
		player_squad.set_location(current_location.location_id)


func setup(_loaded_scenario, context = { }):
	# Initializes the ActivityRunner with a loaded GameScenario
	# Creates the underlying ActivityExecuteManager that handles triggerable execution
	# e.g., setup(demo_scenario) → creates ActivityExecuteManager → aem.setup(scenario)
	aem = ActivityExecuteManager.new()
	aem.setup(_loaded_scenario, context)


func embark_new_journey(towards: Location):
	var _squad = aem.player_squad
	current_location = aem.scenario.starting_location_id
	walking_towards = towards


func get_distance(current_id, location_id):
	return aem.scenario.world.travel_graph.calculate_travel_time_between(current_id, location_id)


func get_location_by_id(location_id):
	return aem.scenario.world.get_location_by_id(location_id)


func get_all_reachable_locations(from_id: Variant, max_hops: int = -1) -> Array[String]:
	assert(from_id is String or from_id is Location)
	if from_id is Location:
		from_id = from_id.location_id

	if not locations.has(from_id):
		return []

	var reachable: Array[String] = []
	var visited: Dictionary = { from_id: true }
	var queue: Array = [[from_id, 0]]

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


func exec_at(when: StrategyTypes.TriggerWhen) -> Array[GenericResult]:
	var res: Array[GenericResult] = aem.execute_triggerables_at(when)
	return res


func advance_turn() -> void:
	turn_count += 1
	StrategyEventBus.turn_advanced.emit(turn_count)


func get_activity(_getting_type: StrategyTypes.ActivityType) -> Activity:
	for triggerable in aem.scenario.triggerable_manager.registered_triggerables:
		if triggerable is Activity and triggerable.activity_type == _getting_type:
			return triggerable as Activity
	return null


func create_travel_activity(location_id: String) -> Activity:
	# Creates/configures a TRAVEL activity for a specific destination
	# Manages multi-turn travel: tracks walking_towards destination and progress
	# Three cases:
	#   1. New journey: sets walking_towards, no location change yet (progress=0)
	#   2. Continue: increments progress, checks if arrived (progress >= distance)
	#   3. Destination change: resets progress (TODO: not fully implemented)
	# e.g., travel to "vienna" from "salzburg" (distance=3):
	#   Turn 1: walking_towards={vienna, progress=0}, location_changed="" (still at salzburg)
	#   Turn 2: continue, progress=1, location_changed="" (still en route)
	#   Turn 3: continue, progress=2, progress >= 3? no. progress=2
	#   Turn 4: continue, progress=3, progress >= 3? yes! location_changed="vienna", walking_towards=null
	var activity = get_activity(StrategyTypes.ActivityType.TRAVEL)
	activity.destination_id = location_id

	activity.trigger_id = "travel-to-%s" % location_id
	activity.trigger_name = "Travel"
	activity.description = "Travel to another location"
	activity.activity_type = StrategyTypes.ActivityType.TRAVEL
	activity.time_cost = 1

	# # Create result with travel costs - morale decreases, travel tools consumed
	var travel_result = ActivityResult.new({ "location_changed": location_id })
	travel_result.event_chain_path = "empty"

	# # Travel costs: morale penalty and travel tools consumption
	# # These can be modified based on distance, terrain, etc.
	# travel_result.squad_stat_changes[StrategyTypes.SquadProperty.MORALE] = -5.0
	# travel_result.squad_stat_changes[StrategyTypes.SquadProperty.AMMO_SUPPLIES] = -1.0 # travel_tools

	var walking_towards_location = walking_towards["location"]
	if walking_towards_location == null: # if we are not already travelling
		walking_towards = location_id # set to { "location": confirmed_location_id, "progress": 0 } by setters
		activity.result.location_changed = "" # no location change yet, just starting journey
		Log.debug("Runner", "New journey to %s from %s (progress=0)" % [location_id, current_location.location_id if current_location else "null"])
	elif location_id == walking_towards_location.location_id:
		Log.debug("Runner", "Continuing down the path towards intended location")
		(current_location as Location).type = StrategyTypes.LocationType.ROAD # temporarily set current location to road to allow travel between towns
		walking_towards = location_id # Assigning the same location will increment progres by 1, refer to setter
		var dist = get_distance(current_location, walking_towards_location)
		Log.debug("Runner", "Travel progress: %d / %d (from %s to %s)" % [travel_progress, dist, current_location.location_id, walking_towards_location.location_id])
		if travel_progress >= dist:
			Log.debug("Runner", "Arrived at destination: %s" % location_id)
			current_location = walking_towards_location
			walking_towards = null
			activity.result.location_changed = location_id # signal arrival to _execute_travel
		else:
			activity.result.location_changed = "" # no location change yet
	else:
		Log.debug("Runner", "Changing destination") # TODO

	# activity.result = travel_result
	return activity
