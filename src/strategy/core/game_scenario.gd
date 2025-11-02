extends Resource
class_name GameScenario

signal activity_executed(activity: Activity, result: ActivityResult)
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
	
	# Register factions
	for faction in config.get("factions", []):
		if faction is Faction:
			factions.append(faction)
			# Register all missions from this faction
			for mission in faction.missions:
				triggerable_manager.register(mission)
	
	# Register endings
	for ending in config.get("endings", []):
		if ending is Ending:
			endings.append(ending)
			triggerable_manager.register(ending)
	
	# Register events
	for event in config.get("events", []):
		if event is GameEvent:
			triggerable_manager.register(event)
	
	# Register activities
	for activity in config.get("activities", []):
		if activity is Activity:
			triggerable_manager.register(activity)
	
	# Set starting location
	var starting_location_id = config.get("starting_location_id", "")
	if not starting_location_id.is_empty():
		current_location = world.get_location_by_id(starting_location_id)
		player_squad.set_location(starting_location_id)
	elif world.locations.size() > 0:
		current_location = world.locations[0]
		player_squad.set_location(current_location.location_id)
	
	triggerable_manager.triggerable_fired.connect(_on_triggerable_fired)

func execute_turn(activity: Activity) -> Dictionary:
	if game_ended:
		return {"error": "Game has ended"}
	
	if not activity.can_execute(player_squad, current_location):
		var reason = activity.get_cannot_execute_reason(player_squad, current_location)
		return {"error": reason}
	
	var turn_summary = {
		"activity": activity.trigger_name,
		"pre_triggerables": [],
		"activity_result": {},
		"post_triggerables": [],
		"missions_completed": [],
		"ending": null
	}
	
	# Execute pre and post-activity triggerables
	turn_summary["pre_triggerables"] = _execute_triggerables(_build_context(activity), StrategyTypes.TriggerWhen.BEFORE_ACTIVITY)
	for r in turn_summary["pre_triggerables"]:
		_apply_result(r["result"])
	
	# The [Activity] itself executes
	var activity_result = activity.execute(player_squad, world)
	turn_summary["activity_result"] = {
		"squad_changes": activity_result.squad_stat_changes,
		"world_changes": activity_result.world_stat_changes,
		"event_chain_path": activity_result.event_chain_path
	}
	_apply_result(activity_result)
	activity_executed.emit(activity, activity_result)
	
	# Post-activity triggerables with updated context
	turn_summary["post_triggerables"] = _execute_triggerables(_build_context(activity), StrategyTypes.TriggerWhen.AFTER_ACTIVITY)
	for r in turn_summary["post_triggerables"]:
		_apply_result(r["result"])
	
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

func _apply_result(result: GenericResult) -> void:
	if not result.location_changed.is_empty():
		current_location = world.get_location_by_id(result.location_changed)
	
	for event_id in result.triggered_event_ids:
		var event = triggerable_manager.get_by_id(event_id)
		if event and event is GameEvent:
			print("GameScenario: Triggering event '%s'" % event_id)
			(event as GameEvent).trigger(player_squad, world)
		else:
			push_warning("GameScenario: Event '%s' not found in TriggerableManager" % event_id)
	
	# Apply world stat changes using proper enum key
	if result.world_stat_changes.has(StrategyTypes.GlobalModifier.END):
		world.end_progression += result.world_stat_changes[StrategyTypes.GlobalModifier.END]
	
	# Apply squad stat changes
	for stat_key in result.squad_stat_changes:
		var value = result.squad_stat_changes[stat_key]
		match stat_key:
			StrategyTypes.SquadProperty.MORALE:
				player_squad.modify_morale(value)
				print("GameScenario: Applied morale change: %+.1f (new: %.1f)" % [value, player_squad.get_morale()])
			StrategyTypes.SquadProperty.FOOD_SUPPLIES:
				player_squad.food += int(value)
				print("GameScenario: Applied food change: %+d (new: %d)" % [int(value), player_squad.food])
			StrategyTypes.SquadProperty.MOOD:
				# Mood could map to money or karma depending on design
				player_squad.money += value
				print("GameScenario: Applied money change: %+.1f (new: %.1f)" % [value, player_squad.money])
			_:
				push_warning("GameScenario: Unhandled squad property: %s" % stat_key)

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

func _execute_triggerables(context: Dictionary, when: StrategyTypes.TriggerWhen) -> Array:
	var filter = func(t: Triggerable) -> bool:
		return t is GameEvent and (t as GameEvent).when_to_trigger == when
	
	var triggerables = triggerable_manager.check_triggers(context, filter)
	_sort_triggerables_by_priority(triggerables)
	
	var results: Array = []
	for triggerable in triggerables:
		var result = triggerable.trigger(player_squad, world)
		results.append({
			"triggerable_id": triggerable.trigger_id,
			"triggerable_name": triggerable.trigger_name,
			"result": result
		})
	
	return results

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
	
	# Get all registered activities from triggerable manager
	for triggerable in triggerable_manager.registered_triggerables:
		if triggerable is Activity:
			var activity = triggerable as Activity
			# Check if activity type is available at current location
			if activity.activity_type in current_location.available_activity_types:
				if activity.can_execute(player_squad, current_location):
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
	triggerables.sort_custom(func(a: Triggerable, b: Triggerable) -> bool:
		var a_pri = (a as GameEvent).emergency_priority if a is GameEvent else 999
		var b_pri = (b as GameEvent).emergency_priority if b is GameEvent else 999
		return a_pri < b_pri
	)
