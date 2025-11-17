extends Resource
class_name GameScenario

signal activity_executed(activity: Activity, result: ActivityResult)
signal triggerable_fired(triggerable: Triggerable, result: Variant)
signal mission_completed(mission: Mission)
signal ending_reached(ending: Ending)
signal turn_advanced(turn: int)

var triggerable_manager: TriggerableManager
var player_squad: StrategicSquad

@export var world: World
@export var factions: Array[Faction] = []
@export var endings: Array[Ending] = []
@export var current_location: Location

var rng = RandomNumberGenerator.new()
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
		current_location = world.get_location_by_id(result.location_changed)
	
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
			StrategyTypes.SquadProperty.MOOD:
				print("[GameScenario]     -> Adding money: %+.2f" % value)
				player_squad.money += value
			_:
				push_error("[GameScenario] Unknown stat key: %s (enum value: %d)" % [StrategyTypes.SquadProperty.keys()[stat_key], stat_key])
				assert(false, "Unknown stat key: %s" % StrategyTypes.SquadProperty.keys()[stat_key]);

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



func _sort_triggerables_by_priority(triggerables: Array[Triggerable]) -> void:
	triggerables.sort_custom(func(a: Triggerable, b: Triggerable) -> bool:
		var a_pri = (a as GameEvent).emergency_priority if a is GameEvent else 999
		var b_pri = (b as GameEvent).emergency_priority if b is GameEvent else 999
		return a_pri < b_pri
	)

#endregion
