class_name SquadAISystem
extends Node

## Owns the DECISION step for AI-controlled roaming squads — the missing
## piece between SquadBeingSystem's per-hour squad_turn broadcast and
## ActivityRunSystem's "read squad.current_activity_type and run it"
## pipeline. Builds one SquadBrain per scenario.world.roaming_squads entry
## (mirrors AISquadManager.setup(), src/strategy/ai/squad_manager.gd:14-44,
## but owns only decision-making — no executors, no headless combat, no
## bandit lifecycle; those already have real replacements elsewhere in this
## layer: ActivityRunSystem/BattleResolutionSystem).
##
## A squad with no brain (squad_id not in squad_brains — e.g. the player
## squad, which is never added to world.roaming_squads) is left completely
## untouched: _on_squad_turn returns immediately, so ActivityRunSystem still
## reads whatever current_activity_type something else (player input / a
## debug command) already set. No player/AI branching lives anywhere else.
##
## Cross-system handoff for TRAVEL/FORCE_MARCH goes through
## ai_travel_requested, wired by main.gd to SquadTravelSystem.begin_travel —
## this System never holds a SquadTravelSystem ref itself (see the
## documented convention in activity_run_system.gd / debug_command_system.gd).
##
## No dynamic registration: brains are built once, from a snapshot of
## world.roaming_squads at setup() time. A squad added to world.roaming_squads
## afterward (e.g. future bandit spawning) won't get a brain unless a
## register_squad()-style method is added later, mirroring AISquadManager's
## (squad_manager.gd:280-291) — deliberately out of scope here.

signal ai_travel_requested(squad: StrategySquad, destination_id: String)

var scenario: GameScenario
var squad_brains: Dictionary = {} ## squad_id -> SquadBrain


func setup(_scenario: GameScenario) -> void:
	assert(_scenario != null, "SquadAISystem requires a GameScenario")
	scenario = _scenario

	var profile := AIProfileFactory.get_default_squad_profile()
	for squad in scenario.world.roaming_squads:
		## Mirrors AISquadManager.setup() (squad_manager.gd:31-33) — a brain
		## can't be built without a valid current_location_id (StrategicSituation
		## asserts on it, src/strategy/ai/situation.gd:280), so seed it from
		## starting_location_id first.
		if squad.current_location_id.is_empty() and not squad.starting_location_id.is_empty():
			squad.set_location(squad.starting_location_id)
		squad_brains[squad.squad_id] = SquadBrain.new(squad, profile)
		LogGd.debug("[SquadAISystem] built brain for %s (%s)" % [squad.squad_name, squad.squad_id])


## Connected to SquadBeingSystem.squad_turn by main.gd, BEFORE
## ActivityRunSystem's own connection to the same signal — see load_scenario().
## Godot fires listeners in connection order, so the AI's decision for this
## squad_turn emission lands before ActivityRunSystem reads
## current_activity_type for the same emission. Do not reorder those two
## connect() calls without re-checking this.
func _on_squad_turn(squad: StrategySquad) -> void:
	if not squad_brains.has(squad.squad_id):
		return ## no brain registered => not AI-controlled (player squad, etc.)

	## A squad already mid-journey must NOT re-decide: SquadTravelSystem.begin_travel()
	## unconditionally resets travel_progress_km/travel_segment_index/travel_route
	## (squad_travel_system.gd:81-84), so calling it again every hour while still
	## travelling would wipe out the previous hour's accumulated progress — a hop
	## that takes more than one hour of travel would never complete. Let
	## ActivityRunSystem's existing TRAVEL branch (current_activity_type == TRAVEL,
	## travel_route non-empty) drive advance_travel() to completion instead.
	if squad.is_traveling():
		return

	var brain: SquadBrain = squad_brains[squad.squad_id]
	var decision: Dictionary = brain.decide(scenario.world, null, FactionDirective.create_none())
	var activity_type: StrategyTypes.ActivityType = decision["activity_type"]
	var context: Dictionary = decision.get("context", {})

	match activity_type:
		StrategyTypes.ActivityType.TRAVEL:
			_begin_ai_travel(squad, context)
		StrategyTypes.ActivityType.FORCE_MARCH:
			## KNOWN ROUGH EDGE (v1): FORCE_MARCH is downgraded to a plain TRAVEL
			## toward the same next-hop. The real FORCE_MARCH Activity resource
			## (resources/strategy/generic-activities/force-march/force-march.tres)
			## is a single triggerable_manager-registered instance whose
			## destination_id/ultimate_destination_id ActivityRunSystem never sets
			## per-squad (only AISquadManager.prepare_ai_turns(), squad_manager.gd:68-76,
			## does that — and only for the OLD pipeline). Running it as-is here
			## would read a stale or empty destination_id and misplace or no-op the
			## squad. Downgrading loses: 2x supply cost, auto-engage-on-arrival, and
			## the double-hop. "finish-off-enemy" (weight 8.0, in the default
			## balanced-roamer profile) is the one reachable path to FORCE_MARCH —
			## expect the fight to resume one hour later via an attack/hunt
			## consideration rather than engaging immediately on arrival.
			_begin_ai_travel(squad, context)
		_:
			squad.current_activity_type = activity_type


func _begin_ai_travel(squad: StrategySquad, context: Dictionary) -> void:
	var destination: String = context.get("travel_destination", "")
	if destination.is_empty():
		## StrategicAction.resolve_context() returns {} whenever it can't resolve
		## a destination, which makes SquadBrain.decide() fall back to
		## config.fallback_action (usually rest) before returning — reaching here
		## with an empty destination would mean something other than the fallback
		## itself resolved to TRAVEL/FORCE_MARCH with no destination. Shouldn't
		## happen with the authored profiles, but don't leave the squad in a
		## broken TRAVEL state (empty destination) if it ever does.
		squad.current_activity_type = StrategyTypes.ActivityType.REST
		return
	ai_travel_requested.emit(squad, destination)
