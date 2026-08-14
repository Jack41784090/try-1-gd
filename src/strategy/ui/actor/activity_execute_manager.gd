class_name ActivityExecuteManager
extends RefCounted

var _IS_AI: bool = false
var ai_decision_context: Dictionary = {}

#region ===== DATA =====
var previous_location: Location
var scenario: GameScenario
var world: World:
	get:
		return scenario.world
var player_squad: StrategySquad:
	get:
		return player_squad
#endregion

func _init(is_ai = false, _ai_squad: StrategySquad = null) -> void:
	_IS_AI = is_ai


func setup(_loaded_scenario, context = {}):
	assert(_loaded_scenario is GameScenario)
	assert(not _IS_AI or context.get("squad") != null, "AI must be initialized with a squad")
	scenario = _loaded_scenario
	player_squad = context.get("squad", player_squad)


## Finds an enemy squad by ID from the world's roaming squads
func _find_enemy_squad(squad_id: String) -> StrategySquad:
	for squad in scenario.world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad
	return null


func _apply_stats_changes_result(_scr: GenericResult):
	MyLog.debug("AEM", "Applying %d squad stat change(s)" % _scr.squad_stat_changes.size())
	for stat_key in _scr.squad_stat_changes:
		var value = _scr.squad_stat_changes[stat_key]
		MyLog.trace("AEM", "Stat key %s (enum value %d) = %+.2f" % [StrategyTypes.SquadProperty.keys()[stat_key], stat_key, value])
		match stat_key:
			StrategyTypes.SquadProperty.MORALE:
				MyLog.debug("AEM", "Modifying morale by %+.2f" % value)
				player_squad.modify_morale(value)
			StrategyTypes.SquadProperty.FOOD_SUPPLIES:
				MyLog.debug("AEM", "Adding food: %+d" % int(value))
				player_squad.food += int(value)
			StrategyTypes.SquadProperty.MONEY:
				MyLog.debug("AEM", "Adding money: %+.2f" % value)
				player_squad.money += value
			StrategyTypes.SquadProperty.AMMO_SUPPLIES:
				MyLog.debug("AEM", "Travel Tools: %+.2f" % value)
				player_squad.travel_tools += round(value)
			_:
				MyLog.error("AEM", "Unknown stat key: %s (enum value: %d)" % [StrategyTypes.SquadProperty.keys()[stat_key], stat_key])
				assert(false, "Unknown stat key: %s" % StrategyTypes.SquadProperty.keys()[stat_key])


func _apply_location_change_result(_lcr: GenericResult):
	assert(_lcr is GenericResult)
	assert(_lcr.location_changed != null)
	MyLog.debug("AEM", "[%s] Location changed to: %s (from %s)" % [player_squad.squad_name, _lcr.location_changed, player_squad.current_location_id])

	var current_location = world.get_location_by_id(player_squad.current_location_id)
	previous_location = current_location
	player_squad.set_location(_lcr.location_changed)


func _apply_result(result: GenericResult) -> void:
	MyLog.trace("AEM", "_apply_result() called")
	MyLog.trace("AEM", "Result type: %s" % result.get_class())
	MyLog.trace("AEM", "Squad changes: %s" % [result.squad_stat_changes])

	if result is ActivityResult and not result.location_changed.is_empty():
		_apply_location_change_result(result)

	if result.squad_stat_changes.is_empty():
		MyLog.trace("AEM", "No squad stat changes to apply")
	else:
		_apply_stats_changes_result(result)

	if result.new_recruits.size() > 0:
		MyLog.info("AEM", "Adding %d new recruit(s) to squad" % result.new_recruits.size())


func _build_context(activity: Activity = null) -> Dictionary:
	var completed_mission_ids: Array[String] = []
	for faction in scenario.factions:
		for id in faction.get_completed_mission_ids():
			completed_mission_ids.append(id)
	var is_location_changing: bool = false
	var next_location: Location = null

	if activity and activity.activity_type == StrategyTypes.ActivityType.TRAVEL:
		if activity.result and activity.result is ActivityResult:
			var dest_id = (activity.result as ActivityResult).location_changed
			if not dest_id.is_empty():
				is_location_changing = true
				next_location = world.get_location_by_id(dest_id)

	var ctx := {
		"squad": player_squad,
		"world": world,
		"activity": activity,
		"location": world.get_location_by_id(player_squad.current_location_id),
		"prev_location": previous_location,
		"next_location": next_location,
		"is_location_changing": is_location_changing,
		"turn": world.current_hour,
		"completed_missions": completed_mission_ids,
	}
	if _IS_AI:
		ctx.merge(ai_decision_context)
	return ctx


func exec_before(activity: Activity) -> Array[GenericResult]:
	return execute_triggerables(activity, StrategyTypes.TriggerWhen.BEFORE_ACTIVITY)


func exec_activity(activity: Activity) -> Array[GenericResult]:
	var results = activity.execute(_build_context(activity))
	var all_results: Array[GenericResult] = []
	for r in results:
		all_results.append(r)
		_apply_result(r)
	return all_results


func exec_after(activity: Activity) -> Array[GenericResult]:
	return execute_triggerables(activity, StrategyTypes.TriggerWhen.AFTER_ACTIVITY)


func execute_triggerables(activity: Activity, when: StrategyTypes.TriggerWhen):
	var context = _build_context(activity)
	var results = _execute_triggerables(context, when )
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
	if _IS_AI:
		return []
	MyLog.trace("AEM", "_execute_triggerables() when=%s" % StrategyTypes.TriggerWhen.keys()[ when ])
	var when_filter = func(t: Triggerable) -> bool:
		return t is GameEvent and (t as GameEvent).when_to_trigger == when

	var triggerables: Array[Triggerable] = scenario.triggerable_manager.get_triggerables_triggered(context, when_filter)
	MyLog.trace("AEM", "Found %d triggered event(s)" % triggerables.size())

	_sort_triggerables_by_priority(triggerables)
	MyLog.trace("AEM", "Total triggerables after sorting: %d" % triggerables.size())

	var all_results: Array[GenericResult] = []
	for triggerable in triggerables:
		MyLog.debug("AEM", "Triggering: %s (%s)" % [triggerable.trigger_name, triggerable.get_class()])
		var triggered_results = triggerable.trigger(context)
		for r in triggered_results:
			MyLog.trace("AEM", "Result: squad_changes=%s" % [r.squad_stat_changes])
			all_results.append(r)

	MyLog.trace("AEM", "Returning %d result(s)" % all_results.size())
	return all_results


func _sort_triggerables_by_priority(triggerables: Array[Triggerable]) -> void:
	triggerables.sort_custom(
		func(a: Triggerable, b: Triggerable) -> bool:
			var a_pri = (a as GameEvent).emergency_priority if a is GameEvent else 999
			var b_pri = (b as GameEvent).emergency_priority if b is GameEvent else 999
			return a_pri < b_pri
	)
