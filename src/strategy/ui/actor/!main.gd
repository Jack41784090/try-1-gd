class_name ActivityExecuteManager
extends RefCounted

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
			player_squad = scenario.starting_player_squad.strategic_data.duplicate(true)
		return player_squad
#endregion

func _init(is_ai = false, _ai_squad: SquadStrategicData = null) -> void:
	_IS_AI = is_ai


func setup(_loaded_scenario, context = { }):
	# 1. Validate the scenario is the correct type
	# e.g., _loaded_scenario = GameScenario(world=World(locations=[...]), factions=[Faction("Church")])
	assert(_loaded_scenario is GameScenario)
	assert(not _IS_AI or context.get("squad") != null, "AI must be initialized with a squad")
	# 2. Store the scenario reference — gives us access to world, triggerables, factions
	scenario = _loaded_scenario
	# 3. Set the squad — for AI, it's passed in context; for player, lazy-loaded from scenario
	# e.g., context = {"squad": SquadStrategicData(squad_name="Wolves", warriors=[Warrior("Hans"), Warrior("Erik")])}
	player_squad = context.get("squad", player_squad)
	# scenario.initialize(context)


## Finds an enemy squad by ID from the world's roaming squads
func _find_enemy_squad(squad_id: String) -> SquadStrategicData:
	for squad in scenario.world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad
	return null


func _apply_stats_changes_result(_scr: GenericResult):
	# Applies numeric stat changes from a result to the player's squad
	# e.g., _scr.squad_stat_changes = {SquadProperty.MORALE: +10.0, SquadProperty.FOOD_SUPPLIES: -2.0}
	# 1. Iterate over each stat key/value pair in the result's squad_stat_changes dict
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
				assert(false, "Unknown stat key: %s" % StrategyTypes.SquadProperty.keys()[stat_key])


func _apply_location_change_result(_lcr: GenericResult):
	assert(_lcr is GenericResult)
	assert(_lcr.location_changed != null)
	print("[GameScenario]   Location changed to: ", _lcr.location_changed)

	var current_location = world.get_location_by_id(player_squad.current_location_id)
	previous_location = current_location
	player_squad.set_location(_lcr.location_changed)


func _apply_result(result: GenericResult) -> void:
	# Master result applier — takes ANY GenericResult and applies all its effects to the squad/world
	# e.g., result = ActivityResult(location_changed="vienna", squad_stat_changes={MORALE: -5.0}, new_recruits=[Warrior("Otto")])
	print("[GameScenario] _apply_result() called")
	print("[GameScenario]   Result type: ", result.get_class())
	print("[GameScenario]   SquadCombatData changes: ", result.squad_stat_changes)
	print("[GameScenario]   World changes: ", result.world_stat_changes)

	# 1. Apply location changes — if this is a TRAVEL/FORCE_MARCH result, move the squad
	# e.g., result.location_changed = "vienna" → squad moves from "salzburg" to "vienna"
	if result is ActivityResult and not result.location_changed.is_empty():
		_apply_location_change_result(result)

	# 2. Apply squad stat changes — morale, food, money, travel tools
	# e.g., {MORALE: -5.0} → each warrior loses 5 morale
	if result.squad_stat_changes.is_empty():
		print("[GameScenario]   No squad stat changes to apply")
	else:
		_apply_stats_changes_result(result)

	# 3. Add new recruits into player squad — from RECRUIT activity
	# e.g., new_recruits = [CharacterSocialStats(name="Recruit_3")] → appended to squad.warriors
	if result.new_recruits.size() > 0:
		print("[GameScenario]   Adding %d new recruit(s) to squad" % result.new_recruits.size())
		for recruit in result.new_recruits:
			player_squad.add_warrior(recruit)


func _build_context(activity: Activity = null) -> Dictionary:
	# Builds the shared context Dictionary used by ALL triggerables (activities, events, missions)
	# to evaluate their conditions and execute their logic.
	# e.g., returns {"squad": SquadStrategicData, "world": World, "location": Location("salzburg"), "turn": 5, ...}
	#
	# 1. Gather completed missions for condition checks (e.g., "requires mission_01 completed")
	var completed_mission_ids: Array[String] = []
	# 2. Check if this is a TRAVEL activity that will change location (for LOCATION_TRANSITION conditions)
	# e.g., if activity = Activity(TRAVEL, destination="vienna") → is_location_changing = true
	var is_location_changing: bool = false
	var next_location: Location = null

	if activity and activity.activity_type == StrategyTypes.ActivityType.TRAVEL:
		if activity.result and activity.result is ActivityResult:
			var dest_id = (activity.result as ActivityResult).location_changed
			if not dest_id.is_empty():
				is_location_changing = true
				next_location = world.get_location_by_id(dest_id)

	# 3. Assemble and return the context dictionary — this is passed to every .evaluate() and .execute()
	return {
		"squad": player_squad,
		"world": world,
		"activity": activity,
		"location": world.get_location_by_id(player_squad.current_location_id),
		"prev_location": previous_location,
		"next_location": next_location,
		"is_location_changing": is_location_changing,
		"turn": world.turn_count,
		"completed_missions": completed_mission_ids,
	}


func execute_triggerables(activity: Activity, when: StrategyTypes.TriggerWhen):
	# Main entry point: runs all GameEvents that match the current context + timing
	# Called by the UI presenter BEFORE and AFTER each activity
	# e.g., execute_triggerables(Activity(REST), BEFORE_ACTIVITY)
	#   → checks all registered GameEvents where when_to_trigger == BEFORE_ACTIVITY
	#   → any that pass their conditions get triggered, results applied to squad
	# 1. Build context dict with current squad, world, location, activity
	var context = _build_context(activity)
	# 2. Find and trigger matching events, collect their results
	var results = _execute_triggerables(context, when)
	# 3. Apply each result (stat changes, location changes, recruits)
	for result in results:
		_apply_result(result)
	return results


func execute_triggerables_at(when: StrategyTypes.TriggerWhen) -> Array[GenericResult]:
	var context = _build_context(null)
	var results = _execute_triggerables(context, when)
	for result in results:
		_apply_result(result)
	return results


func _execute_triggerables(context: Dictionary, when: StrategyTypes.TriggerWhen) -> Array[GenericResult]:
	# Core triggerable execution engine — finds all matching GameEvents and fires them
	# e.g., context = {squad: Wolves, world: World(turn=5), location: Salzburg, activity: REST}
	#       when = AFTER_ACTIVITY
	print("[GameScenario] _execute_triggerables() when=", StrategyTypes.TriggerWhen.keys()[when])
	# 1. Create a filter that only matches GameEvents scheduled for this timing
	# e.g., GameEvent("Ambush", when=AFTER_ACTIVITY) passes, GameEvent("Dawn", when=TURN_START) is skipped
	var when_filter = func(t: Triggerable) -> bool:
		return t is GameEvent and (t as GameEvent).when_to_trigger == when

	# 2. Ask TriggerableManager to check ALL registered triggerables against the context
	# Each triggerable's conditions are evaluated (location, squad_status, time, etc.)
	# e.g., GameEvent("Ambush") conditions: [LOCATION_TYPE=ROAD, SQUAD_STATUS(morale<30)] → if both pass, included
	var triggerables: Array[Triggerable] = scenario.triggerable_manager.get_triggerables_triggered(context, when_filter)
	print("[GameScenario]   Found %d triggered event(s)" % triggerables.size())

	# 3. Sort by emergency_priority (lower = higher priority, fires first)
	# e.g., GameEvent(priority=0, "Betrayal") fires before GameEvent(priority=10, "Market Day")
	_sort_triggerables_by_priority(triggerables)
	print("[GameScenario]   Total triggerables after sorting: %d" % triggerables.size())

	# 4. Fire each triggerable and collect results
	# e.g., GameEvent("Ambush").trigger(context) → EventResult(squad_stat_changes={MORALE: -10})
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
	triggerables.sort_custom(
		func(a: Triggerable, b: Triggerable) -> bool:
			var a_pri = (a as GameEvent).emergency_priority if a is GameEvent else 999
			var b_pri = (b as GameEvent).emergency_priority if b is GameEvent else 999
			return a_pri < b_pri
	)
