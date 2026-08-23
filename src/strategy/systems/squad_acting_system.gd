class_name SquadActingSystem
extends Node

## Holds every Squad in the scenario — player and AI alike, no distinction —
## and owns the per-hour turn broadcast plus the AI DECISION step for
## brain-carrying squads. On each hour_pass from the clock it first lets each
## AI squad's StrategySquadBrain decide (setting current_activity_type or
## emitting ai_travel_requested), THEN broadcasts squad_turn — so listeners
## like ActivityRunSystem always read this hour's fresh decision. The old
## two-system split needed main.gd to order two connect() calls to get the
## same guarantee; that constraint no longer exists.
##
## A squad is AI-controlled iff it carries a brain on its resource
## (squad.resource.brain != null) — the brain travels WITH the squad, so
## register_squad() here is the single registration step (no separate
## AI-side registration). Squads with no brain (player/debug squads) are
## left untouched: no decision runs, and ActivityRunSystem reads whatever
## current_activity_type something else already set.
##
## Cross-system handoff for TRAVEL/FORCE_MARCH goes through
## ai_travel_requested, wired by main.gd to SquadTravelSystem.begin_travel —
## this System never holds a SquadTravelSystem ref itself (see the
## documented convention in activity_run_system.gd / debug_command_system.gd).

signal squad_turn(squad: StrategySquad)
signal squad_registered(squad: StrategySquad)
signal squad_unregistered(squad_id: String)
signal ai_travel_requested(squad: StrategySquad, destination_id: String)

var scenario: GameScenario
var squads: Dictionary = {} ## squad_id -> StrategySquad


func setup(_scenario: GameScenario) -> void:
	assert(_scenario != null, "SquadActingSystem requires a GameScenario")
	scenario = _scenario


func register_squad(squad: StrategySquad) -> void:
	squads[squad.squad_id] = squad
	var brain := _brain_of(squad)
	if brain != null:
		## StrategicSituation asserts a valid location, so seed it from
		## starting_location_id before the brain's first decide().
		if squad.current_location_id.is_empty() and not squad.starting_location_id.is_empty():
			squad.set_location(squad.starting_location_id)
		## Re-bind unconditionally: code-built brains already point at this
		## squad, but a .tres-embedded brain can't reference its owner at
		## authoring time.
		brain.squad = squad
	squad_registered.emit(squad)
	LogGd.debug("[SquadActingSystem] registered %s (%s)%s" % [squad.squad_name, squad.squad_id, " +brain" if brain != null else ""])


func unregister_squad(squad_id: String) -> void:
	if squads.erase(squad_id):
		squad_unregistered.emit(squad_id)
		LogGd.debug("[SquadActingSystem] unregistered %s" % squad_id)


func get_squad(squad_id: String) -> StrategySquad:
	return squads.get(squad_id)


func get_all_squads() -> Array[StrategySquad]:
	var result: Array[StrategySquad] = []
	for squad in squads.values():
		result.append(squad)
	return result


## Connected to the clock's hour signal by main.gd — see load_scenario().
func on_hour_pass(hour: int) -> void:
	LogGd.debug("[SquadActingSystem] hour_pass(%d) — %d squad(s)" % [hour, squads.size()])
	for squad: StrategySquad in squads.values():
		if squad.get_living_warriors().is_empty():
			continue
		_decide(squad)
		squad_turn.emit(squad)


func _decide(squad: StrategySquad) -> void:
	var brain := _brain_of(squad)
	if brain == null:
		return ## no brain => not AI-controlled (player squad, etc.)

	## Must NOT re-decide mid-journey: begin_travel() unconditionally resets
	## travel progress (squad_travel_system.gd), so re-triggering it every
	## hour would wipe a multi-hour hop's progress and it would never
	## complete. ActivityRunSystem's TRAVEL branch drives advance_travel()
	## to completion instead.
	if squad.is_traveling():
		return

	var decision: Dictionary = brain.decide(scenario.world, null, FactionDirective.create_none())
	var activity_type: StrategyTypes.ActivityType = decision["activity_type"]
	var context: Dictionary = decision.get("context", {})

	match activity_type:
		StrategyTypes.ActivityType.TRAVEL:
			_begin_ai_travel(squad, context)
		StrategyTypes.ActivityType.FORCE_MARCH:
			## KNOWN ROUGH EDGE (v1): downgrades FORCE_MARCH to plain TRAVEL —
			## ActivityRunSystem never sets per-squad destination_id on the
			## real FORCE_MARCH Activity, so running it as-is would misplace
			## the squad. Loses 2x supply cost, auto-engage-on-arrival, and
			## the double-hop.
			_begin_ai_travel(squad, context)
		_:
			squad.current_activity_type = activity_type


func _begin_ai_travel(squad: StrategySquad, context: Dictionary) -> void:
	var destination: String = context.get("travel_destination", "")
	if destination.is_empty():
		## An unresolvable destination must not leave the squad in a broken
		## TRAVEL state — fall back to REST instead.
		squad.current_activity_type = StrategyTypes.ActivityType.REST
	else:
		ai_travel_requested.emit(squad, destination)


func _brain_of(squad: StrategySquad) -> StrategySquadBrain:
	if squad.resource == null:
		return null
	return squad.resource.brain
