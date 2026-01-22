class_name ActivityExecuteManager
extends Control

var player_squad: StrategicSquad:
	get:
		return get_parent().player__registered_squad
var is_executing_activity = false
var game_scenario: GameScenario:
	get:
		return get_parent().game_scenario


func exec_x_activity(activity: Activity, _when: StrategyTypes.TriggerWhen):
	var res: Array[GenericResult] = execute_triggerables(
		activity,
		_when 
	);
	for result in res:
		_apply_result(result)
	return res

func exec_before(activity: Activity):
	return exec_x_activity(activity, StrategyTypes.TriggerWhen.BEFORE_ACTIVITY)

func exec_activity(activity: Activity):
	var activity_results = activity.execute(game_scenario._build_context(activity))
	print("[GameScenario] Activity result: %s" % activity_results)
	var all_activity_result: Array[GenericResult] = []
	for result in activity_results:
		all_activity_result.append(result)
	# await _apply_play_wait(all_activity_result)
	
	return all_activity_result

func exec_after(activity: Activity):
	return exec_x_activity(activity, StrategyTypes.TriggerWhen.AFTER_ACTIVITY)

func _execute_activity_with_object(activity: Activity) -> void:
	# Guard against race conditions from double-clicking
	if is_executing_activity:
		print("[TrainingScreen] Activity already in progress, ignoring duplicate request")
		return
	is_executing_activity = true
	
	var player_squad = game_scenario.player_squad
	var world = game_scenario.world
	print("\n[GameScenario] === execute_turn() START ===")
	print("[GameScenario] Activity: ", activity)
	print("[GameScenario] Squad before: Money=%.1f, Food=%d, Morale=%.1f" % [player_squad.money, player_squad.food, player_squad.get_morale()])
	
	var preact_results: Array[GenericResult] = execute_triggerables(
		activity,
		StrategyTypes.TriggerWhen.BEFORE_ACTIVITY
	);
	# await _apply_play_wait(preact_results)

	var activity_results = activity.execute(game_scenario._build_context(activity))
	print("[GameScenario] Activity result: %s" % activity_results)
	var all_activity_result: Array[GenericResult] = []
	for result in activity_results:
		all_activity_result.append(result)
	# await _apply_play_wait(all_activity_result)
	
	# Check if combat was triggered by the activity
	if all_activity_result.any(func(r): return r is ActivityResult and r.requires_combat):
		var _combat;
		for a in all_activity_result:
			if a is ActivityResult and a.requires_combat:
				_combat = a
				break
		assert(_combat.combat_target_squad_id != "", "[GameScenario] Combat required but no target squad ID specified in activity result");
		var enemy_squad = _find_enemy_squad(_combat.combat_target_squad_id)
		# if enemy_squad:
		# 	start_encounter(enemy_squad, {"activity": activity.trigger_name})
		# 	await encounter_resolved
		# else:
		# 	push_warning("[GameScenario] Combat required but enemy squad with ID '%s' not found" % _combat.combat_target_squad_id)
	
	var postact_results: Array[GenericResult] = execute_triggerables(
		activity,
		StrategyTypes.TriggerWhen.AFTER_ACTIVITY
	);
	# await _apply_play_wait(postact_results)
	
	var completed_missions: Array[Mission] = game_scenario._check_mission_completion()
	for mission in completed_missions:
		game_scenario.mission_completed.emit(mission)
	
	var ending: Ending = game_scenario._check_ending_conditions()
	if ending:
		game_scenario.game_ended = true
		game_scenario.ending_triggered = ending
		game_scenario.ending_reached.emit(ending)
	
	world.advance_turn(activity.time_cost)
	game_scenario.turn_advanced.emit(world.turn_count)
	
	print("[GameScenario] Squad final: Money=%.1f, Food=%d, Morale=%.1f" % [player_squad.money, player_squad.food, player_squad.get_morale()])
	print("[GameScenario] === execute_turn() END ===\n")
	
	# Re-enable buttons after activity is complete
	is_executing_activity = false
	# _reenable_activity_buttons()

# func _apply_play_wait(results: Array[GenericResult]):
# 	# apply changes
# 	for r in results:
# 		self._apply_result(r)

# 	# queue and play
# 	_queue_multiple_eventchains_from_results(results)
# 	await _play_next_queued_chain()
	
# 	# 
# 	if is_playing_chain: await vn_completed

# 	_update_ui()



## Finds an enemy squad by ID from the world's roaming squads
func _find_enemy_squad(squad_id: String) -> StrategicSquad:
	if not game_scenario or not game_scenario.world:
		return null
	for squad in game_scenario.world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad
	return null

# func _on_triggerable_fired(triggerable: Triggerable, result: Variant) -> void:
# 	triggerable_fired.emit(triggerable, result)

func _apply_result(result: GenericResult) -> void:
	print("[GameScenario] _apply_result() called")
	print("[GameScenario]   Result type: ", result.get_class())
	print("[GameScenario]   Squad changes: ", result.squad_stat_changes)
	print("[GameScenario]   World changes: ", result.world_stat_changes)
	
	if result is ActivityResult and not result.location_changed.is_empty():
		print("[GameScenario]   Location changed to: ", result.location_changed)
		# Track previous location before changing
		# previous_location = current_location
		# current_location = world.get_location_by_id(result.location_changed)
		# player_squad.set_location(result.location_changed)
		# # Clear pending location change
		# _pending_location_change = ""
	
	if result.world_stat_changes.has(StrategyTypes.GlobalModifier.END):
		var end_change = result.world_stat_changes[StrategyTypes.GlobalModifier.END]
		print("[GameScenario]   Applying END progression: %+.2f" % end_change)
		# world.end_progression += end_change
	
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
	for faction in game_scenario.factions:
		completed_mission_ids.append_array(faction.get_completed_mission_ids())
	
	# Determine if we're in a location transition (travel activity with destination)
	var is_location_changing: bool = false
	var next_location: Location = null
	
	if activity and activity.activity_type == StrategyTypes.ActivityType.TRAVEL:
		if activity.result and activity.result is ActivityResult:
			var dest_id = (activity.result as ActivityResult).location_changed
			if not dest_id.is_empty():
				is_location_changing = true
				# next_location = world.get_location_by_id(dest_id)
		# Also check pending location change
		# elif not _pending_location_change.is_empty():
		# 	is_location_changing = true
		# 	next_location = world.get_location_by_id(_pending_location_change)
	
	return {
		"squad": player_squad,
		# "world": world,
		"activity": activity,
		# "location": current_location,
		# "prev_location": previous_location,
		"next_location": next_location,
		"is_location_changing": is_location_changing,
		# "turn": world.turn_count,
		"completed_missions": completed_mission_ids
	}

func execute_triggerables(activity: Activity, when: StrategyTypes.TriggerWhen):
	var context = _build_context(activity)
	return _execute_triggerables(context, when );

func _execute_triggerables(context: Dictionary, when: StrategyTypes.TriggerWhen) -> Array[GenericResult]:
	print("[GameScenario] _execute_triggerables() when=", StrategyTypes.TriggerWhen.keys()[ when ])
	var when_filter = func(t: Triggerable) -> bool:
		return t is GameEvent and (t as GameEvent).when_to_trigger == when
	
	# Triggers from universal Triggerables (e.g., Scenario cutscene)
	var triggerables: Array[Triggerable] = game_scenario.triggerable_manager.get_triggerables_triggered(context, when_filter)
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
