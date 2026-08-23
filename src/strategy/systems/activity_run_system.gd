class_name ActivityRunSystem
extends Node

## Wired externally by main.gd to SquadActingSystem.squad_turn (no NodePath lookup); onchange signals come from AEM mutating the squad directly, not from this system.

signal activity_resolved(squad: StrategySquad, activity: Activity, results: Array)
signal request_travel(squad: StrategySquad, travel_route: Array[String])
signal request_combat(squad: StrategySquad, activity_result: ActivityResult)

## Untyped: bare class_name typing on brand-new sibling scripts can fail to resolve ("Could not find type X") before Godot's class cache warms up.
var scenario: GameScenario


func setup(
	_scenario: GameScenario,
) -> void:
	scenario = _scenario


func _on_squad_turn(squad: StrategySquad) -> void:
	var activity := _resolve_activity_for(squad)
	if activity == null:
		LogGd.debug("[ActivityRunSystem] %s: no activity resolved for type %s" % [
			squad.squad_name, StrategyTypes.ActivityType.keys()[squad.current_activity_type],
		])
		return

	var aem := ActivityExecuteManager.new()
	aem.setup(scenario, {"squad": squad})

	aem.exec_before(activity)
	var results: Array[GenericResult] = aem.exec_activity(activity)
	aem.exec_after(activity)

	for result in results:
		if result is ActivityResult and (result as ActivityResult).requires_combat:
			request_combat.emit(squad, result as ActivityResult)

	LogGd.debug("[ActivityRunSystem] %s: ran %s -> %d result(s)" % [
		squad.squad_name, StrategyTypes.ActivityType.keys()[activity.activity_type], results.size(),
	])
	activity_resolved.emit(squad, activity, results)


## TRAVEL needs cross-turn state, so it's resolved via SquadTravelSystem instead of the triggerable_manager lookup used for every other Activity type.
func _resolve_activity_for(squad: StrategySquad) -> Activity:
	if squad.current_activity_type == StrategyTypes.ActivityType.TRAVEL:
		if not squad.travel_route.is_empty():
			request_travel.emit(squad, squad.travel_route)
		return null

	for triggerable in scenario.triggerable_manager.registered_triggerables:
		if triggerable is Activity and triggerable.activity_type == squad.current_activity_type:
			return triggerable as Activity
	return null
