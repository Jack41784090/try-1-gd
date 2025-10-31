extends RefCounted
class_name GameScenario

signal activity_executed(activity: Activity, result: StrategyTypes.ActivityResult)
signal event_triggered(event: GameEvent, result: StrategyTypes.EventResult)
signal mission_completed(mission: Mission)
signal ending_reached(ending: Ending)
signal turn_advanced(turn: int)

var world: World
var player_squad: StrategicSquad
var factions: Array[Faction] = []
var event_manager: EventManager
var endings: Array[Ending] = []
var current_location: Location

var game_ended: bool = false
var ending_triggered: Ending = null

func _init(config: Dictionary = {}) -> void:
	world = config.get("world", World.new())
	player_squad = config.get("player_squad", StrategicSquad.new())
	factions = config.get("factions", [])
	endings = config.get("endings", [])
	event_manager = EventManager.new()
	
	var events: Array = config.get("events", [])
	for event in events:
		if event is GameEvent:
			event_manager.register_event(event)
	
	var starting_location_id = config.get("starting_location_id", "")
	if not starting_location_id.is_empty():
		current_location = world.get_location_by_id(starting_location_id)
		player_squad.set_location(starting_location_id)
	elif world.locations.size() > 0:
		current_location = world.locations[0]
		player_squad.set_location(current_location.location_id)

func execute_turn(activity: Activity) -> Dictionary:
	if game_ended:
		return {"error": "Game has ended"}
	
	if not activity.can_execute(player_squad, current_location):
		var reason = activity.get_cannot_execute_reason(player_squad, current_location)
		return {"error": reason}
	
	var turn_summary = {
		"activity": activity.activity_name,
		"pre_events": [],
		"activity_result": {},
		"post_events": [],
		"missions_completed": [],
		"ending": null
	}
	
	var context = _build_context(activity)
	
	var pre_events = event_manager.check_triggers(StrategyTypes.TriggerWhen.BEFORE_ACTIVITY, context)
	for event in pre_events:
		var event_result = _handle_event(event)
		turn_summary["pre_events"].append({
			"event_name": event.event_name,
			"result": event_result
		})
	
	var activity_result = activity.execute(player_squad, world, current_location)
	turn_summary["activity_result"] = {
		"narrative": activity_result.narrative_log,
		"squad_changes": activity_result.squad_stat_changes,
		"world_changes": activity_result.world_stat_changes
	}
	
	_apply_activity_result(activity_result)
	activity_executed.emit(activity, activity_result)
	
	context = _build_context(activity)
	
	var post_events = event_manager.check_triggers(StrategyTypes.TriggerWhen.AFTER_ACTIVITY, context)
	for event in post_events:
		var event_result = _handle_event(event)
		turn_summary["post_events"].append({
			"event_name": event.event_name,
			"result": event_result
		})
	
	var completed_missions = _check_mission_completion()
	for mission in completed_missions:
		turn_summary["missions_completed"].append(mission.mission_name)
		mission_completed.emit(mission)
	
	var ending = _check_ending_conditions()
	if ending:
		game_ended = true
		ending_triggered = ending
		turn_summary["ending"] = ending.ending_name
		ending_reached.emit(ending)
	
	world.advance_turn(activity.time_cost)
	turn_advanced.emit(world.turn_count)
	
	return turn_summary

func _handle_event(event: GameEvent) -> StrategyTypes.EventResult:
	var result = event.trigger(player_squad, world)
	event_triggered.emit(event, result)
	return result

func _apply_activity_result(result: StrategyTypes.ActivityResult) -> void:
	if not result.location_changed.is_empty():
		var new_location = world.get_location_by_id(result.location_changed)
		if new_location:
			current_location = new_location
	
	for stat_name in result.world_stat_changes:
		var value = result.world_stat_changes[stat_name]
		if stat_name == "end_progression":
			world.end_progression += value

func _build_context(activity: Activity = null) -> Dictionary:
	var completed_mission_ids: Array[String] = []
	for faction in factions:
		completed_mission_ids.append_array(faction.get_completed_mission_ids())
	
	return {
		"squad": player_squad,
		"world": world,
		"activity": activity,
		"location": current_location,
		"turn": world.turn_count,
		"completed_missions": completed_mission_ids
	}

func _check_mission_completion() -> Array[Mission]:
	var context = _build_context()
	var all_completed: Array[Mission] = []
	
	for faction in factions:
		var completed = faction.check_mission_completions(context)
		all_completed.append_array(completed)
		faction.update_mission_graph()
	
	return all_completed

func _check_ending_conditions() -> Ending:
	var context = _build_context()
	
	for ending in endings:
		if ending.check_conditions(context):
			return ending
	
	return null

func get_available_activities() -> Array[Activity]:
	var available: Array[Activity] = []
	
	for activity_type in current_location.available_activity_types:
		var activity = Activity.create_activity(activity_type)
		if activity and activity.can_execute(player_squad, current_location):
			available.append(activity)
	
	return available

func add_faction(faction: Faction) -> void:
	factions.append(faction)

func get_faction_by_id(faction_id: String) -> Faction:
	for faction in factions:
		if faction.faction_id == faction_id:
			return faction
	return null

func add_ending(ending: Ending) -> void:
	endings.append(ending)

func is_game_ended() -> bool:
	return game_ended

func get_ending() -> Ending:
	return ending_triggered

