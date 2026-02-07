class_name ActivityRunner extends Node

var is_executing_activity = false
var data: ActivityExecuteManager;
var turn_count: int = 0


@onready var player_squad: StrategicSquad:
	set(_ps):
		player_squad = _ps
	get:
		if player_squad == null and data.scenario.starting_player_squad != null:
			player_squad = data.scenario.starting_player_squad.duplicate(true)
		return player_squad

var locations:
	get:
		return data.scenario.world.travel_graph.locations

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
			walking_towards = {"location": null, "progress": 0}
			return
			
		assert(_cl is String or _cl is Location)
		var new_loc: Location = data.scenario.world.travel_graph.get_location(_cl) if _cl is String else _cl
		if not walking_towards["location"]:
			walking_towards = {"location": new_loc, "progress": 0}
		elif new_loc.location_id == walking_towards["location"].location_id:
			walking_towards = {"location": new_loc, "progress": walking_towards["progress"] + 1}
		else:
			walking_towards = {"location": new_loc, "progress": 0}

var current_location: Variant:
	get:
		if current_location == null:
			current_location = data.scenario.starting_location_id
		return current_location
	set(_cl):
		if _cl is String: current_location = data.scenario.world.travel_graph.get_location(_cl).duplicate() # non deep duplicate so we don't dupe the town connections -- dupe to be able to change location type to road for temporary travelling between towns
		elif _cl is Location: current_location = _cl
		else: assert(false)

func setup(_loaded_scenario, context = {}):
	data = ActivityExecuteManager.new()
	data.setup(_loaded_scenario, context)

func embark_new_journey(towards: Location):
	var _squad = data.player_squad
	current_location = data.scenario.starting_location_id
	walking_towards = towards

func get_distance(current_id, location_id):
	return data.scenario.world.travel_graph.calculate_travel_time_between(current_id, location_id)

func get_location_by_id(location_id):
	return data.scenario.world.get_location_by_id(location_id)

func get_all_reachable_locations(from_id: Variant, max_hops: int = -1) -> Array[String]:
	assert(from_id is String or from_id is Location)
	if from_id is Location:
		from_id = from_id.location_id
	
	if not locations.has(from_id):
		return []
	
	var reachable: Array[String] = []
	var visited: Dictionary = {from_id: true}
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
	
	return reachable;

func exec_x_when(activity: Activity, _when: StrategyTypes.TriggerWhen):
	var res: Array[GenericResult] = data.execute_triggerables(
		activity,
		_when
	);
	return res

func exec_before(activity: Activity):
	return exec_x_when(activity, StrategyTypes.TriggerWhen.BEFORE_ACTIVITY)

func exec_activity(activity: Activity):
	var activity_results = activity.execute(data._build_context(activity))
	print("[GameScenario] Activity result: %s" % activity_results)
	var all_activity_result: Array[GenericResult] = []
	for result in activity_results:
		all_activity_result.append(result)
		data._apply_result(result)
	return all_activity_result

func exec_after(activity: Activity):
	return exec_x_when(activity, StrategyTypes.TriggerWhen.AFTER_ACTIVITY)

func advance_turn() -> void:
	turn_count += 1
	StrategyEventBus.turn_advanced.emit(turn_count)


func get_activity(_getting_type: StrategyTypes.ActivityType) -> Activity:
	for triggerable in data.scenario.triggerable_manager.registered_triggerables:
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
	
	# # Create result with travel costs - morale decreases, travel tools consumed
	var travel_result = ActivityResult.new({"location_changed": location_id})
	travel_result.event_chain_path = "empty"
	
	# # Travel costs: morale penalty and travel tools consumption
	# # These can be modified based on distance, terrain, etc.
	# travel_result.squad_stat_changes[StrategyTypes.SquadProperty.MORALE] = -5.0
	# travel_result.squad_stat_changes[StrategyTypes.SquadProperty.AMMO_SUPPLIES] = -1.0 # travel_tools


	var walking_towards_location = walking_towards["location"]
	if walking_towards_location == null: # if we are not already travelling
		walking_towards = location_id # set to { "location": confirmed_location_id, "progress": 0 } by setters
	elif location_id == walking_towards_location.location_id:
		print("continuing down the path towards intended location")
		(current_location as Location).type = StrategyTypes.LocationType.ROAD # temporarily set current location to road to allow travel between towns
		walking_towards = location_id # Assigning the same location will increment progres by 1, refer to setter
		if travel_progress >= get_distance(current_location, walking_towards_location):
			print("arrived at destination")
			current_location = walking_towards_location
			walking_towards = null
		else:
			activity.result.location_changed = "" # no location change yet
	else:
		print("changing destination") # TODO
	
	# activity.result = travel_result
	return activity