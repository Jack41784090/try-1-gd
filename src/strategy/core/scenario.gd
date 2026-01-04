extends Resource
class_name GameScenario

signal activity_executed(activity: Activity, result: ActivityResult)
signal triggerable_fired(triggerable: Triggerable, result: Variant)
signal mission_completed(mission: Mission)
signal ending_reached(ending: Ending)
signal turn_advanced(turn: int)

var triggerable_manager: TriggerableManager
var player_squad: StrategicSquad

@export var starting_location_id: String
@export var world: World
@export var factions: Array[Faction] = []
@export var endings: Array[Ending] = []
@export var current_location: Location

var rng = RandomNumberGenerator.new()
var game_ended: bool = false
var ending_triggered: Ending = null
var _initialized: bool = false
var previous_location: Location = null  # Track for LOCATION_TRANSITION conditions
var _pending_location_change: String = ""  # Location ID we're traveling to

func _init(config: Dictionary = {}) -> void:
	print(" --- new scenario init --- ")

	if config.is_empty():
		print(" Should follow a \"Manual INIT func call\" ")
	else:
		print(" --- Config is not empty, setting up now using premade configs --- ")
		_setup(config)
		_initialized = true

func initialize(_config = {}) -> void:
	print(" --- Manual INIT func called --- ")
	assert(not _initialized, "scenario->initialize must not be called when it has already initialised through other means.")
	_setup(_config)
	_initialized = true

func _setup(config: Dictionary) -> void:
	print("Scenario setup: ", config);
	# Initialize triggerable_manager first
	triggerable_manager = TriggerableManager.new()
	
	# Use exported properties if already set (from .tres), otherwise use config
	if world == null:
		world = config.get("world", World.new())
	if player_squad == null:
		player_squad = config.get("player_squad", StrategicSquad.new())
	
	# Register factions (either from exported array or config)
	var config_factions = config.get("factions", [])
	if not config_factions.is_empty():
		for faction in config_factions:
			if faction is Faction:
				factions.append(faction)
	
	for faction in factions:
		# Register all missions from this faction
		for mission in faction.missions:
			triggerable_manager.register(mission)
	
	# Register endings (either from exported array or config)
	var config_endings = config.get("endings", [])
	if not config_endings.is_empty():
		for ending in config_endings:
			if ending is Ending:
				endings.append(ending)
	
	for ending in endings:
		triggerable_manager.register(ending)
	
	# Register events - if none provided, load default generic events
	var events: Array = config.get("events", [])
	if events.is_empty():
		events = _load_generic_events()
	for event in events:
		if event is GameEvent:
			triggerable_manager.register(event)
	
	# Register activities - if none provided, load default generic activities
	var activities: Array = config.get("activities", [])
	if activities.is_empty():
		activities = _load_generic_activities()
	for activity in activities:
		if activity is Activity:
			triggerable_manager.register(activity)
	
	# Set starting location
	if starting_location_id == null:
		starting_location_id = config.get("starting_location_id", "")
	
	current_location = world.get_location_by_id(starting_location_id)
	player_squad.set_location(starting_location_id)
	
	# Initialize roaming squads from their starting locations
	for roaming_squad in world.roaming_squads:
		roaming_squad.ensure_initialized()
	
	triggerable_manager.triggerable_fired.connect(_on_triggerable_fired)

func execute_turn(activity: Activity) -> Dictionary:
	print("\n[GameScenario] === execute_turn() START ===")
	print("[GameScenario] Activity: ", activity.trigger_name)
	print("[GameScenario] Squad before: Money=%.1f, Food=%d, Morale=%.1f" % [player_squad.money, player_squad.food, player_squad.get_morale()])
	
	if game_ended:
		return {"error": "Game has ended"}
	
	var pre_activity_triggered = _execute_triggerables(_build_context(activity), StrategyTypes.TriggerWhen.BEFORE_ACTIVITY)
	print("[GameScenario] Pre-activity triggerables: %d" % pre_activity_triggered.size())
	for r in pre_activity_triggered:
		_apply_result(r)
	
	print("[GameScenario] Executing activity: ", activity.trigger_name)
	var activity_result = activity.execute(player_squad, world)
	print("[GameScenario] Activity result: %s" % activity_result)
	_apply_result(activity_result)
	print("[GameScenario] Squad after activity: Money=%.1f, Food=%d, Morale=%.1f" % [player_squad.money, player_squad.food, player_squad.get_morale()])
	activity_executed.emit(activity, activity_result)
	
	var post_act_triggered = _execute_triggerables(_build_context(activity), StrategyTypes.TriggerWhen.AFTER_ACTIVITY)
	print("[GameScenario] Post-activity triggerables: %d" % post_act_triggered.size())
	for r in post_act_triggered:
		print("[GameScenario] Post-triggerable result: squad_changes=", r.squad_stat_changes, ", world_changes=", r.world_stat_changes)
		_apply_result(r)
	
	var completed_missions = _check_mission_completion()
	for mission in completed_missions:
		mission_completed.emit(mission)
	
	var ending = _check_ending_conditions()
	if ending:
		game_ended = true
		ending_triggered = ending
		ending_reached.emit(ending)
	
	world.advance_turn(activity.time_cost)
	turn_advanced.emit(world.turn_count)
	
	print("[GameScenario] Squad final: Money=%.1f, Food=%d, Morale=%.1f" % [player_squad.money, player_squad.food, player_squad.get_morale()])
	print("[GameScenario] === execute_turn() END ===\n")
	
	return {
		"activity": activity.trigger_name,
		"pre_triggerables": pre_activity_triggered,
		"activity_result": {
			"squad_changes": activity_result.squad_stat_changes,
			"world_changes": activity_result.world_stat_changes,
			"event_chain_path": activity_result.event_chain_path
		},
		"post_triggerables": post_act_triggered,
		"missions_completed": completed_missions,
		"ending": ending
	}

#region Helper Functions

func _on_triggerable_fired(triggerable: Triggerable, result: Variant) -> void:
	triggerable_fired.emit(triggerable, result)

func _apply_result(result: GenericResult) -> void:
	print("[GameScenario] _apply_result() called")
	print("[GameScenario]   Result type: ", result.get_class())
	print("[GameScenario]   Squad changes: ", result.squad_stat_changes)
	print("[GameScenario]   World changes: ", result.world_stat_changes)
	
	if result is ActivityResult and not result.location_changed.is_empty():
		print("[GameScenario]   Location changed to: ", result.location_changed)
		# Track previous location before changing
		previous_location = current_location
		current_location = world.get_location_by_id(result.location_changed)
		player_squad.set_location(result.location_changed)
		# Clear pending location change
		_pending_location_change = ""
	
	if result.world_stat_changes.has(StrategyTypes.GlobalModifier.END):
		var end_change = result.world_stat_changes[StrategyTypes.GlobalModifier.END]
		print("[GameScenario]   Applying END progression: %+.2f" % end_change)
		world.end_progression += end_change
	
	if result.squad_stat_changes.is_empty():
		print("[GameScenario]   No squad stat changes to apply")
	else:
		print("[GameScenario]   Applying %d squad stat change(s)..." % result.squad_stat_changes.size())
	
	for stat_key in result.squad_stat_changes:
		var value = result.squad_stat_changes[stat_key]
		print("[GameScenario]     Stat key %s (enum value %d) = %+.2f" % [StrategyTypes.SquadProperty.keys()[stat_key], stat_key, value])
		match stat_key:
			StrategyTypes.SquadProperty.MORALE:
				print("[GameScenario]     -> Modifying morale by %+.2f" % value)
				player_squad.modify_morale(value)
			StrategyTypes.SquadProperty.FOOD_SUPPLIES:
				print("[GameScenario]     -> Adding food: %+d" % int(value))
				player_squad.food += int(value)
			StrategyTypes.SquadProperty.MONEY:
				print("[GameScenario]     -> Adding money: %+.2f" % value)
				player_squad.money += value
			StrategyTypes.SquadProperty.AMMO_SUPPLIES:
				print("[GameScenario]     -> Travel Tools: %+.2f" % value)
				player_squad.travel_tools += round(value)
			_:
				push_error("[GameScenario] Unknown stat key: %s (enum value: %d)" % [StrategyTypes.SquadProperty.keys()[stat_key], stat_key])
				assert(false, "Unknown stat key: %s" % StrategyTypes.SquadProperty.keys()[stat_key]);

	if result.new_recruits.size() > 0:
		print("[GameScenario]   Adding %d new recruit(s) to squad" % result.new_recruits.size())
		for recruit in result.new_recruits:
			player_squad.add_warrior(recruit)

func _build_context(activity: Activity = null) -> Dictionary:
	var completed_mission_ids: Array[String] = []
	for faction in factions:
		completed_mission_ids.append_array(faction.get_completed_mission_ids())
	
	# Determine if we're in a location transition (travel activity with destination)
	var is_location_changing: bool = false
	var next_location: Location = null
	
	if activity and activity.activity_type == StrategyTypes.ActivityType.TRAVEL:
		if activity.result and activity.result is ActivityResult:
			var dest_id = (activity.result as ActivityResult).location_changed
			if not dest_id.is_empty():
				is_location_changing = true
				next_location = world.get_location_by_id(dest_id)
		# Also check pending location change
		elif not _pending_location_change.is_empty():
			is_location_changing = true
			next_location = world.get_location_by_id(_pending_location_change)
	
	return {
		"squad": player_squad,
		"world": world,
		"activity": activity,
		"location": current_location,
		"prev_location": previous_location,
		"next_location": next_location,
		"is_location_changing": is_location_changing,
		"turn": world.turn_count,
		"completed_missions": completed_mission_ids
	}

func execute_triggerables(activity: Activity, when: StrategyTypes.TriggerWhen):
	var context = _build_context(activity)
	return _execute_triggerables(context, when);

func _execute_triggerables(context: Dictionary, when: StrategyTypes.TriggerWhen) -> Array[GenericResult]:
	print("[GameScenario] _execute_triggerables() when=", StrategyTypes.TriggerWhen.keys()[when])
	var when_filter = func(t: Triggerable) -> bool:
		return t is GameEvent and (t as GameEvent).when_to_trigger == when
	
	# Triggers from universal Triggerables (e.g., Scenario cutscene)
	var triggerables: Array[Triggerable] = triggerable_manager.get_triggerables_triggered(context, when_filter)
	print("[GameScenario]   Found %d triggered event(s)" % triggerables.size())

	# Trigger chains from selected Activity
	if when == StrategyTypes.TriggerWhen.AFTER_ACTIVITY:
		var activity: Activity = context.get("activity")
		if activity:
			print("[GameScenario]   Checking activity trigger chains: %d" % activity.trigger_chains.size())
			for chain in activity.trigger_chains:
				var chained_trigger = chain.another_trigger
				var chance = chain.chance
				if (chance < 1.0 and rng.randf() <= chance) or chance == 1.0:
					print("[GameScenario]     Added chained trigger: ", chained_trigger.trigger_name)
					triggerables.append(chained_trigger)
				else:
					print("[GameScenario]     Skipped chained trigger (chance failed): ", chained_trigger.trigger_name)

	
	_sort_triggerables_by_priority(triggerables)
	print("[GameScenario]   Total triggerables after sorting: %d" % triggerables.size())
	
	var results: Array[GenericResult] = []
	for triggerable in triggerables:
		print("[GameScenario]   Triggering: ", triggerable.trigger_name, " (", triggerable.get_class(), ")")
		var result = triggerable.trigger(player_squad, world)
		print("[GameScenario]     Result: squad_changes=", result.squad_stat_changes, ", world_changes=", result.world_stat_changes)
		results.append(result)
	
	print("[GameScenario]   Returning %d result(s)" % results.size())
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


func _load_generic_events() -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	_collect_event_resources("res://resources/generic-events", events)
	return events

func _collect_event_resources(base_path: String, target: Array) -> void:
	var dir := DirAccess.open(base_path)
	if dir == null:
		push_warning("GameScenario: Missing event directory: %s" % base_path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				_collect_event_resources("%s/%s" % [base_path, entry], target)
		elif entry.ends_with(".tres"):
			var rp = "%s/%s" % [base_path, entry]
			var resource = load(rp)
			if resource and resource is GameEvent:
				target.append(resource)
			else:
				push_warning("GameScenario: Skipping non-GameEvent resource: %s" % rp)
		entry = dir.get_next()
	dir.list_dir_end()

func _load_generic_activities() -> Array[Activity]:
	var activities: Array[Activity] = []
	_collect_activity_resources("res://resources/generic-activities", activities)
	print(activities)
	return activities

func _collect_activity_resources(base_path: String, target: Array) -> void:
	var dir := DirAccess.open(base_path)
	if dir == null:
		push_warning("TrainingScreen: Missing activity directory: %s" % base_path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				_collect_activity_resources("%s/%s" % [base_path, entry], target)
		elif entry.ends_with(".tres"):
			var rp = "%s/%s" % [base_path, entry]
			var resource = load(rp)
			if resource:
				target.append(resource)
			else:
				push_warning("TrainingScreen: Skipping non-Activity resource: %s" % rp)
		entry = dir.get_next()
	dir.list_dir_end()



func _sort_triggerables_by_priority(triggerables: Array[Triggerable]) -> void:
	triggerables.sort_custom(func(a: Triggerable, b: Triggerable) -> bool:
		var a_pri = (a as GameEvent).emergency_priority if a is GameEvent else 999
		var b_pri = (b as GameEvent).emergency_priority if b is GameEvent else 999
		return a_pri < b_pri
	)

#endregion
