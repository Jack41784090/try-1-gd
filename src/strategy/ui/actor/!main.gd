class_name ActivityExecuteManager extends RefCounted

var _IS_AI: bool = false

#region ===== DATA =====
var previous_location: Location
var scenario: GameScenario
var world: World:
	get:
		return scenario.world
var player_squad: SquadStrategicData:
	get:
		if player_squad == null and \
			(not _IS_AI and scenario.starting_player_squad != null):
			player_squad = scenario.starting_player_squad.duplicate(true)
		return player_squad
#endregion

func _init(is_ai = false, _ai_squad: SquadStrategicData = null) -> void:
	_IS_AI = is_ai

func setup(_loaded_scenario, context = {}):
	assert(_loaded_scenario is GameScenario)
	assert(not _IS_AI or context.get("squad") != null, "AI must be initialized with a squad")
	scenario = _loaded_scenario
	player_squad = context.get("squad", player_squad)
	# scenario.initialize(context)

## Finds an enemy squad by ID from the world's roaming squads
func _find_enemy_squad(squad_id: String) -> SquadStrategicData:
	for squad in scenario.world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad
	return null

func _apply_stats_changes_result(_scr: GenericResult):
	print("[GameScenario]   Applying %d squad stat change(s)..." % _scr.squad_stat_changes.size())
	for stat_key in _scr.squad_stat_changes:
		var value = _scr.squad_stat_changes[stat_key]
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


func _apply_location_change_result(_lcr: GenericResult):
	assert(_lcr is GenericResult)
	assert(_lcr.location_changed != null)
	print("[GameScenario]   Location changed to: ", _lcr.location_changed)

	var current_location = world.get_location_by_id(player_squad.current_location_id)
	previous_location = current_location
	player_squad.set_location(_lcr.location_changed)


func _apply_result(result: GenericResult) -> void:
	print("[GameScenario] _apply_result() called")
	print("[GameScenario]   Result type: ", result.get_class())
	print("[GameScenario]   SquadCombatData changes: ", result.squad_stat_changes)
	print("[GameScenario]   World changes: ", result.world_stat_changes)
	
	# Apply location changes
	if result is ActivityResult and not result.location_changed.is_empty():
		_apply_location_change_result(result)
	
	# Apply SquadCombatData Changes
	if result.squad_stat_changes.is_empty():
		print("[GameScenario]   No squad stat changes to apply")
	else:
		_apply_stats_changes_result(result)

	# Add new recruits into Player SquadCombatData
	if result.new_recruits.size() > 0:
		print("[GameScenario]   Adding %d new recruit(s) to squad" % result.new_recruits.size())
		for recruit in result.new_recruits:
			player_squad.add_warrior(recruit)

func _build_context(activity: Activity = null) -> Dictionary:
	var completed_mission_ids: Array[String] = []
	var is_location_changing: bool = false
	var next_location: Location = null
	
	if activity and activity.activity_type == StrategyTypes.ActivityType.TRAVEL:
		if activity.result and activity.result is ActivityResult:
			var dest_id = (activity.result as ActivityResult).location_changed
			if not dest_id.is_empty():
				is_location_changing = true
				next_location = world.get_location_by_id(dest_id)
	
	return {
		"squad": player_squad,
		"world": world,
		"activity": activity,
		"location": world.get_location_by_id(player_squad.current_location_id),
		"prev_location": previous_location,
		"next_location": next_location,
		"is_location_changing": is_location_changing,
		"turn": world.turn_count,
		"completed_missions": completed_mission_ids
	}

func execute_triggerables(activity: Activity, when: StrategyTypes.TriggerWhen):
	var context = _build_context(activity)
	var results = _execute_triggerables(context, when );
	for result in results:
		_apply_result(result)
	return results

func execute_triggerables_at(when: StrategyTypes.TriggerWhen) -> Array[GenericResult]:
	var context = _build_context(null)
	var results = _execute_triggerables(context, when )
	for result in results:
		_apply_result(result)
	return results

func _execute_triggerables(context: Dictionary, when: StrategyTypes.TriggerWhen) -> Array[GenericResult]:
	print("[GameScenario] _execute_triggerables() when=", StrategyTypes.TriggerWhen.keys()[ when ])
	var when_filter = func(t: Triggerable) -> bool:
		return t is GameEvent and (t as GameEvent).when_to_trigger == when
	
	# Triggers from universal Triggerables (e.g., Scenario cutscene)
	var triggerables: Array[Triggerable] = scenario.triggerable_manager.get_triggerables_triggered(context, when_filter)
	print("[GameScenario]   Found %d triggered event(s)" % triggerables.size())
	
	_sort_triggerables_by_priority(triggerables)
	print("[GameScenario]   Total triggerables after sorting: %d" % triggerables.size())
	
	var all_results: Array[GenericResult] = []
	for triggerable in triggerables:
		print("[GameScenario]   Triggering: ", triggerable.trigger_name, " (", triggerable.get_class(), ")")
		var triggered_results = triggerable.trigger(context)
		for r in triggered_results:
			print("[GameScenario]     Result: squad_changes=", r.squad_stat_changes, ", world_changes=", r.world_stat_changes)
			all_results.append(r)
	
	print("[GameScenario]   Returning %d result(s)" % all_results.size())
	return all_results

func _check_mission_completion() -> Array[Mission]:
	var context = _build_context()
	var all_completed: Array[Mission] = []
	
	# for faction in factions:
	# 	var completed = faction.check_mission_completions(context)
	# 	all_completed.append_array(completed)
	# 	faction.update_mission_graph()
	
	return all_completed

func _check_ending_conditions() -> Ending:
	var context = _build_context()
	
	# for ending in endings:
	# 	if ending.check_conditions(context):
	# 		return ending
	
	return null


func _sort_triggerables_by_priority(triggerables: Array[Triggerable]) -> void:
	triggerables.sort_custom(func(a: Triggerable, b: Triggerable) -> bool:
		var a_pri = (a as GameEvent).emergency_priority if a is GameEvent else 999
		var b_pri = (b as GameEvent).emergency_priority if b is GameEvent else 999
		return a_pri < b_pri
	)
