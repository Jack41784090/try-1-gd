class_name SquadAISystem
extends Node

## Owns only AI decision-making (builds one StrategySquadBrain per roaming squad) — no executors/combat/bandit lifecycle, and never holds a SquadTravelSystem ref, handing TRAVEL/FORCE_MARCH off via ai_travel_requested instead.

signal ai_travel_requested(squad: StrategySquad, destination_id: String)

var scenario: GameScenario
var squad_brains: Dictionary[StringName, StrategySquadBrain] = {} ## squad_id -> StrategySquadBrain


func setup(_scenario: GameScenario) -> void:
	assert(_scenario != null, "SquadAISystem requires a GameScenario")
	scenario = _scenario

	var profile := AIProfileFactory.get_default_squad_profile()
	for squad in scenario.world.roaming_squads:
		## Seed current_location_id from starting_location_id first — StrategicSituation asserts a valid location before a brain can be built.
		if squad.current_location_id.is_empty() and not squad.starting_location_id.is_empty():
			squad.set_location(squad.starting_location_id)
		squad_brains[squad.squad_id] = StrategySquadBrain.new(squad, profile)
		LogGd.debug("[SquadAISystem] built brain for %s (%s)" % [squad.squad_name, squad.squad_id])

func _on_squad_turn(squad: StrategySquad) -> void:
	if not squad_brains.has(squad.squad_id):
		return ## no brain registered => not AI-controlled (player squad, etc.)

	## Must NOT re-decide mid-journey: begin_travel() unconditionally resets travel progress, so re-triggering it every hour would wipe a multi-hour hop's progress and it would never complete.
	if squad.is_traveling():
		return

	var brain: StrategySquadBrain = squad_brains[squad.squad_id]
	var decision: Dictionary = brain.decide(scenario.world, null, FactionDirective.create_none())
	var activity_type: StrategyTypes.ActivityType = decision["activity_type"]
	var context: Dictionary = decision.get("context", {})

	match activity_type:
		StrategyTypes.ActivityType.TRAVEL:
			_begin_ai_travel(squad, context)
		StrategyTypes.ActivityType.FORCE_MARCH:
			## KNOWN ROUGH EDGE (v1): downgrades FORCE_MARCH to plain TRAVEL — ActivityRunSystem never sets per-squad destination_id on the real FORCE_MARCH Activity, so running it as-is would misplace the squad. Loses 2x supply cost, auto-engage-on-arrival, and the double-hop.
			_begin_ai_travel(squad, context)
		_:
			squad.current_activity_type = activity_type

func register_squad(squad: StrategySquad, profile_path: String = "") -> void:
	assert(scenario != null, "SquadAISystem.register_squad requires setup() first")
	assert(not squad_brains.has(squad.squad_id), "squad %s already has a brain" % squad.squad_id)
	if squad.current_location_id.is_empty() and not squad.starting_location_id.is_empty():
		squad.set_location(squad.starting_location_id)
	var profile := AIProfileFactory.get_squad_profile(profile_path)
	squad_brains[squad.squad_id] = StrategySquadBrain.new(squad, profile)
	LogGd.debug("[SquadAISystem] registered brain for %s (%s)" % [squad.squad_name, squad.squad_id])

func _begin_ai_travel(squad: StrategySquad, context: Dictionary) -> void:
	var destination: String = context.get("travel_destination", "")
	if destination.is_empty():
		squad.current_activity_type = StrategyTypes.ActivityType.REST
	else: ai_travel_requested.emit(squad, destination)
