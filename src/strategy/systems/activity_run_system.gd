class_name ActivityRunSystem
extends Node

## Connected to SquadBeingSystem.squad_turn (wired externally by main.gd, not
## looked up via NodePath). For each squad-turn signal: resolves whichever
## Activity applies (redirecting to SquadTravelSystem for TRAVEL), runs it
## through a fresh, per-call ActivityExecuteManager, and — if the result
## demands it — redirects to BattleResolutionSystem. AEM already mutates the
## squad in place; whatever signals the squad itself fires as a side effect
## of that (today: StrategyEventBus.squad_resource_changed / money_changed
## on the squad's own gain_money()-driven paths) are the "onchange" hook a
## HUD would listen to — this system doesn't fire anything on the squad's
## behalf itself.

signal activity_resolved(squad: StrategySquad, activity: Activity, results: Array)

## Untyped sibling-system refs: bare class_name typing across brand-new
## scripts in the same compile batch can fail to resolve ("Could not find
## type X in the current scope") before Godot's global class cache has
## indexed them. Dynamic dispatch sidesteps it.
var scenario: GameScenario
var squad_being_system
var travel_system
var battle_system


func setup(
	_scenario: GameScenario,
	_squad_being_system,
	_travel_system,
	_battle_system,
) -> void:
	scenario = _scenario
	squad_being_system = _squad_being_system
	travel_system = _travel_system
	battle_system = _battle_system


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
			await _dispatch_combat(squad, result as ActivityResult)

	LogGd.debug("[ActivityRunSystem] %s: ran %s -> %d result(s)" % [
		squad.squad_name, StrategyTypes.ActivityType.keys()[activity.activity_type], results.size(),
	])
	activity_resolved.emit(squad, activity, results)


## TRAVEL is the one Activity type that needs cross-turn state, so it's the
## one type resolved by asking SquadTravelSystem instead of just looking the
## Activity resource up in the triggerable_manager.
func _resolve_activity_for(squad: StrategySquad) -> Activity:
	if squad.current_activity_type == StrategyTypes.ActivityType.TRAVEL:
		if squad.travel_route.is_empty():
			return null
		return travel_system.advance_travel(squad)

	for triggerable in scenario.triggerable_manager.registered_triggerables:
		if triggerable is Activity and triggerable.activity_type == squad.current_activity_type:
			return triggerable as Activity
	return null


func _dispatch_combat(squad: StrategySquad, result: ActivityResult) -> void:
	var enemy: StrategySquad = squad_being_system.get_squad(result.combat_target_squad_id)
	if enemy == null:
		LogGd.warn("[ActivityRunSystem] combat required but enemy squad '%s' not found in SquadBeingSystem" % result.combat_target_squad_id)
		return
	await battle_system.resolve_combat(squad, enemy, result.engagement_type)
