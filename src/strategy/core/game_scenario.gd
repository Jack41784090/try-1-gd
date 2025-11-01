extends Resource
class_name GameScenario

signal activity_executed(activity: Activity, result: StrategyTypes.ActivityResult)
signal triggerable_fired(triggerable: Triggerable, result: Variant)
signal mission_completed(mission: Mission)
signal ending_reached(ending: Ending)
signal turn_advanced(turn: int)

@export var world: World
var player_squad: StrategicSquad
@export var factions: Array[Faction] = []
var triggerable_manager: TriggerableManager
@export var endings: Array[Ending] = []
@export var current_location: Location

var game_ended: bool = false
var ending_triggered: Ending = null

func _init(config: Dictionary = {}) -> void:
	world = config.get("world", World.new())
	player_squad = config.get("player_squad", StrategicSquad.new())
	triggerable_manager = TriggerableManager.new()
	
	var factions_raw: Array = config.get("factions", [])
	for faction in factions_raw:
		if faction is Faction:
			factions.append(faction)
	
	var endings_raw: Array = config.get("endings", [])
	for ending in endings_raw:
		if ending is Ending:
			endings.append(ending)
			triggerable_manager.register(ending)
	
	var events: Array = config.get("events", [])
	for event in events:
		if event is GameEvent:
			triggerable_manager.register(event)
	
	# Register all missions from all factions
	for faction in factions:
		for mission in faction.missions:
			triggerable_manager.register(mission)
	
	var starting_location_id = config.get("starting_location_id", "")
	if not starting_location_id.is_empty():
		current_location = world.get_location_by_id(starting_location_id)
		player_squad.set_location(starting_location_id)
	elif world.locations.size() > 0:
		current_location = world.locations[0]
		player_squad.set_location(current_location.location_id)
	
	# Connect to triggerable_manager signals
	triggerable_manager.triggerable_fired.connect(_on_triggerable_fired)

func execute_turn(activity: Activity) -> Dictionary:
	if game_ended:
		return {"error": "Game has ended"}
	
	if not activity.can_execute(player_squad, current_location):
		var reason = activity.get_cannot_execute_reason(player_squad, current_location)
		return {"error": reason}
	
	var turn_summary = {
		"activity": activity.activity_name,
		"pre_triggerables": [],
		"activity_result": {},
		"post_triggerables": [],
		"missions_completed": [],
		"ending": null
	}
	
	var context = _build_context(activity)
	
	# Triggered [Events/Missions/etc] before the Activity
	var pre_filter = func(t: Triggerable) -> bool:
		if t is GameEvent:
			return (t as GameEvent).when_to_trigger == StrategyTypes.TriggerWhen.BEFORE_ACTIVITY
		return false
	
	var pre_triggerables = triggerable_manager.check_triggers(context, pre_filter)
	_sort_triggerables_by_priority(pre_triggerables)
	
	for triggerable in pre_triggerables:
		var result = triggerable.trigger(player_squad, world)
		turn_summary["pre_triggerables"].append({
			"triggerable_id": triggerable.trigger_id,
			"triggerable_name": triggerable.trigger_name,
			"result": result
		})
	
	# The [Activity] itself executes
	var activity_result = activity.execute(player_squad, world, current_location)
	turn_summary["activity_result"] = {
		"squad_changes": activity_result.squad_stat_changes,
		"world_changes": activity_result.world_stat_changes,
		"event_chain_path": activity_result.event_chain_path
	}
	
	# Changes of the Activity is applied to the Squad
	_apply_activity_result(activity_result)
	activity_executed.emit(activity, activity_result)
	
	# Causes new context
	context = _build_context(activity)
	
	# Post-Activity [Events/Missions/etc] might fire
	var post_filter = func(t: Triggerable) -> bool:
		if t is GameEvent:
			return (t as GameEvent).when_to_trigger == StrategyTypes.TriggerWhen.AFTER_ACTIVITY
		return false
	
	var post_triggerables = triggerable_manager.check_triggers(context, post_filter)
	_sort_triggerables_by_priority(post_triggerables)
	
	for triggerable in post_triggerables:
		var result = triggerable.trigger(player_squad, world)
		turn_summary["post_triggerables"].append({
			"triggerable_id": triggerable.trigger_id,
			"triggerable_name": triggerable.trigger_name,
			"result": result
		})
	
	# [Mission] completions based on changes from Activity, Event results
	var completed_missions = _check_mission_completion()
	for mission in completed_missions:
		turn_summary["missions_completed"].append(mission.mission_name)
		mission_completed.emit(mission)
	
	# Check for [Ending] conditions
	var ending = _check_ending_conditions()
	if ending:
		game_ended = true
		ending_triggered = ending
		turn_summary["ending"] = ending.ending_name
		ending_reached.emit(ending)
	
	world.advance_turn(activity.time_cost)
	turn_advanced.emit(world.turn_count)
	
	return turn_summary

func _on_triggerable_fired(triggerable: Triggerable, result: Variant) -> void:
	triggerable_fired.emit(triggerable, result)

func _apply_activity_result(result: StrategyTypes.ActivityResult) -> void:
	if not result.location_changed.is_empty():
		var new_location = world.get_location_by_id(result.location_changed)
		if new_location:
			current_location = new_location
			
	for _event_triggered in result.triggered_event_ids:
		var e = triggerable_manager.get_by_id(_event_triggered)
		if e and e is GameEvent:
			print("GameScenario: Triggering event '%s'" % _event_triggered)
			(e as GameEvent).trigger(player_squad, world)
		else:
			push_warning("GameScenario: Event to trigger not found in TriggerableManager: '%s'" % _event_triggered)
			print("GameScenario: WARNING - Event '%s' was requested but does not exist" % _event_triggered)
	
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

func _sort_triggerables_by_priority(triggerables: Array[Triggerable]) -> void:
	# Sort by emergency_priority if the triggerable is a GameEvent
	# Lower priority number = higher urgency = plays first
	triggerables.sort_custom(func(a: Triggerable, b: Triggerable) -> bool:
		var a_priority = 999
		var b_priority = 999
		
		if a is GameEvent:
			a_priority = (a as GameEvent).emergency_priority
		if b is GameEvent:
			b_priority = (b as GameEvent).emergency_priority
		
		return a_priority < b_priority
	)
