class_name ActivityRunner extends Node

var is_executing_activity = false
var data: ActivityExecuteManager;

var locations:
	get:
		return data.world.travel_graph.locations

var walking_towards: Variant:
	set(_cl):
		if _cl is String: walking_towards = data.scenario.travel_graph.get_location(_cl)
		elif _cl is Location: walking_towards = _cl
		else: assert(false)

var current_location: Variant:
	set(_cl):
		if _cl is String: current_location = data.scenario.travel_graph.get_location(_cl)
		elif _cl is Location: current_location = _cl
		else: assert(false)

func setup(_loaded_scenario, context = {}):
	data = ActivityExecuteManager.new()
	data.setup(_loaded_scenario, context)

func embark_new_journey(towards: Location):
	var squad = data.player_squad
	current_location = data.scenario.starting_location_id
	data.world.travel_graph.walking_towards = towards
	

func get_all_reachable_locations(from_id: String, max_hops: int = -1) -> Array[String]:
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
		
		if not current_location:
			continue
		
		for neighbor_id in current_location.connected_location_ids:
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
