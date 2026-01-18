# extends RefCounted
# class_name ActivityExecutor

# ## Handles activity execution flow and event chain queuing
# ## Extracted from TrainingGUI for better separation of concerns

# signal activity_started(activity: Activity)
# signal activity_finished(activity: Activity)
# signal event_chain_queued(path: String)
# signal all_chains_completed()

# var game_scenario: GameScenario
# var event_chain_queue: Array[String] = []
# var is_executing: bool = false
# var is_playing_chain: bool = false

# func _init(scenario: GameScenario = null) -> void:
# 	game_scenario = scenario

# func set_scenario(scenario: GameScenario) -> void:
# 	game_scenario = scenario

# func is_busy() -> bool:
# 	return is_executing or is_playing_chain

# func execute_activity(activity: Activity, on_apply_result: Callable, on_play_chain: Callable) -> void:
# 	if is_executing:
# 		print("[ActivityExecutor] Activity already in progress, ignoring duplicate request")
# 		return
	
# 	is_executing = true
# 	activity_started.emit(activity)
	
# 	var player_squad = game_scenario.player_squad
# 	var world = game_scenario.world
# 	print("\n[ActivityExecutor] === execute_turn() START ===")
# 	print("[ActivityExecutor] Activity: ", activity.trigger_name)
# 	print("[ActivityExecutor] Squad before: Money=%.1f, Food=%d, Morale=%.1f" % [player_squad.money, player_squad.food, player_squad.get_morale()])
	
# 	# Pre-activity triggerables
# 	var preact_results: Array[GenericResult] = game_scenario.execute_triggerables(
# 		activity,
# 		StrategyTypes.TriggerWhen.BEFORE_ACTIVITY
# 	)
# 	await _apply_play_wait(preact_results, on_apply_result, on_play_chain)

# 	# Execute activity itself
# 	var activity_result: ActivityResult = activity.execute(player_squad, world)
# 	print("[ActivityExecutor] Activity result: %s" % activity_result)
# 	await _apply_play_wait([activity_result], on_apply_result, on_play_chain)

# 	# Post-activity triggerables
# 	var postact_results: Array[GenericResult] = game_scenario.execute_triggerables(
# 		activity,
# 		StrategyTypes.TriggerWhen.AFTER_ACTIVITY
# 	)
# 	await _apply_play_wait(postact_results, on_apply_result, on_play_chain)
	
# 	# Check missions and endings
# 	var completed_missions: Array[Mission] = game_scenario._check_mission_completion()
# 	for mission in completed_missions:
# 		game_scenario.mission_completed.emit(mission)
	
# 	var ending: Ending = game_scenario._check_ending_conditions()
# 	if ending:
# 		game_scenario.game_ended = true
# 		game_scenario.ending_triggered = ending
# 		game_scenario.ending_reached.emit(ending)
	
# 	# Advance turn
# 	world.advance_turn(activity.time_cost)
# 	game_scenario.turn_advanced.emit(world.turn_count)
	
# 	print("[ActivityExecutor] Squad final: Money=%.1f, Food=%d, Morale=%.1f" % [player_squad.money, player_squad.food, player_squad.get_morale()])
# 	print("[ActivityExecutor] === execute_turn() END ===\n")
	
# 	is_executing = false
# 	activity_finished.emit(activity)

# func _apply_play_wait(results: Array[GenericResult], on_apply_result: Callable, on_play_chain: Callable) -> void:
# 	# Apply changes
# 	for r in results:
# 		game_scenario._apply_result(r)
# 		on_apply_result.call(r)
	
# 	# Queue event chains
# 	_queue_multiple_eventchains_from_results(results)
	
# 	# Play queued chains
# 	await _play_queued_chains(on_play_chain)

# func _queue_multiple_eventchains_from_results(results_list: Array[GenericResult]) -> void:
# 	for result in results_list:
# 		if result is GenericResult:
# 			if result.has_event_chain():
# 				queue_event_chain(result.event_chain_path)
# 		else:
# 			assert(false, "%s" % result)

# func queue_event_chain(chain_path: String) -> void:
# 	event_chain_queue.append(chain_path)
# 	print("[ActivityExecutor] Queued event chain: %s (queue size: %d)" % [chain_path, event_chain_queue.size()])
# 	event_chain_queued.emit(chain_path)

# func has_queued_chains() -> bool:
# 	return not event_chain_queue.is_empty()

# func pop_next_chain() -> String:
# 	if event_chain_queue.is_empty():
# 		return ""
# 	return event_chain_queue.pop_front()

# func clear_queue() -> void:
# 	event_chain_queue.clear()

# func _play_queued_chains(on_play_chain: Callable) -> void:
# 	if event_chain_queue.is_empty():
# 		return
	
# 	is_playing_chain = true
# 	while not event_chain_queue.is_empty():
# 		var chain_path = event_chain_queue.pop_front()
# 		await on_play_chain.call(chain_path)
	
# 	is_playing_chain = false
# 	all_chains_completed.emit()

# func create_travel_activity(location_id: String) -> Activity:
# 	var activity = Activity.new()
# 	activity.trigger_id = "travel-to-%s" % location_id
# 	activity.trigger_name = "Travel"
# 	activity.description = "Travel to another location"
# 	activity.activity_type = StrategyTypes.ActivityType.TRAVEL
# 	activity.time_cost = 1

# 	var squad_changes = {
# 		StrategyTypes.SquadProperty.MORALE: -5,
# 		StrategyTypes.SquadProperty.AMMO_SUPPLIES: -5,
# 	}
# 	activity.result = ActivityResult.new({
# 		"location_changed": location_id,
# 		"squad_stat_changes": squad_changes 
# 	})
# 	activity.result.event_chain_path = "empty"
# 	return activity
