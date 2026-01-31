class_name ActivityRunner extends Node

var is_executing_activity = false
var data: ActivityExecuteManager;

var locations:
	get:
		return data.world.travel_graph.locations

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
			walking_towards = null
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
		if _cl is String: current_location = data.scenario.world.travel_graph.get_location(_cl)
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
	return data.scenario.world.travel_graph.calculate_travel_time_from(current_id, location_id)

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
		
		for neighbor_id in current_loc.connected_location_ids:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append([neighbor_id, current_depth + 1])
	
	return reachable;

func exec_x_activity(activity: Activity, _when: StrategyTypes.TriggerWhen):
	var res: Array[GenericResult] = data.execute_triggerables(
		activity,
		_when
	);
	return res

func exec_before(activity: Activity):
	return exec_x_activity(activity, StrategyTypes.TriggerWhen.BEFORE_ACTIVITY)

func exec_activity(activity: Activity):
	var activity_results = activity.execute(data._build_context(activity))
	print("[GameScenario] Activity result: %s" % activity_results)
	var all_activity_result: Array[GenericResult] = []
	for result in activity_results:
		all_activity_result.append(result)
		data._apply_result(result)
	return all_activity_result

func exec_after(activity: Activity):
	return exec_x_activity(activity, StrategyTypes.TriggerWhen.AFTER_ACTIVITY)
