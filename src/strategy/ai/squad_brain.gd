class_name SquadBrain
extends RefCounted

var config: SquadBrainConfig
var squad: StrategySquad
var _rng := RandomNumberGenerator.new()

func _init(p_squad: StrategySquad, p_config: SquadBrainConfig) -> void:
	assert(p_squad != null, "SquadBrain requires a squad")
	assert(p_config != null, "SquadBrain requires a config")
	squad = p_squad
	config = p_config
	_rng.randomize()


func decide(world: World, faction: Faction, directive: FactionDirective) -> Dictionary:
	## Core AI decision function — evaluates all considerations and picks the best action
	## e.g., squad="Wolves" at "salzburg", world has enemies at "linz"
	##   → considerations: ["low_food_forage" → 0.8, "enemy_nearby_attack" → 0.6, "need_rest" → 0.3]
	##   → best = "low_food_forage" (0.8) → returns {activity_type: FORAGE, context: {}}
	##
	## 1. Build a StrategicSituation snapshot — lazy-evaluated context about squad, enemies, distances
	## e.g., StrategicSituation(squad="Wolves", location="salzburg", enemies_here=[], nearest_town="vienna")
	var situation = StrategicSituation.new(squad, world, faction, directive)

	var best_score := -INF
	var best_action: StrategicAction = null

	## 2. Score each consideration from the brain's config (loaded from .tres profile)
	## Each consideration has: glances (what to look at), weight, and a returning StrategicAction
	for consideration in config.considerations:
		## 2.1 Score = weight × combined_glance_values
		## e.g., "low_food" consideration: glance(FOOD, inverse=true, normalize/100) → 0.8 × weight(1.0) = 0.8
		var score = consideration.score(situation)
		var action = consideration.returning
		if action == null:
			continue

		## 2.2 Skip zero/negative scores
		if score <= 0.0:
			continue

		## 2.3 Add noise (±10%) to break determinism
		score *= _rng.randf_range(0.9, 1.1)

		## 2.4 Check if the action is actually executable in this situation
		## e.g., TRAVEL needs a valid destination, ATTACK needs a tracked enemy
		var at = action.activity_type
		var location_independent := [
			StrategyTypes.ActivityType.TRAVEL,
			StrategyTypes.ActivityType.FORCE_MARCH,
			StrategyTypes.ActivityType.ATTACK,
			StrategyTypes.ActivityType.REST,
			StrategyTypes.ActivityType.HEAL,
			StrategyTypes.ActivityType.BUY_SUPPLIES,
			StrategyTypes.ActivityType.FORAGE,
			StrategyTypes.ActivityType.PATROL,
			StrategyTypes.ActivityType.DRILL,
			StrategyTypes.ActivityType.MERCENARY_WORK,
		]
		var can_exec := false
		if at in location_independent:
			can_exec = action.can_resolve(situation)
		elif situation.location.has_activity_type(at):
			can_exec = action.can_resolve(situation)
		if not can_exec:
			continue

		Log.trace("Brain:%s" % squad.squad_name, "%s → %.2f" % [consideration.name, score])

		## 2.5 Track the highest-scoring action
		if score > best_score:
			best_score = score
			best_action = action

	## 3. Fallback if no consideration scored > 0 — use profile's default action (usually REST)
	if best_action == null:
		best_action = config.fallback_action
		Log.debug("Brain:%s" % squad.squad_name, "Using fallback: %s" % [best_action.action_name if best_action else "NONE"])

	if best_action == null:
		return {"activity_type": StrategyTypes.ActivityType.REST, "context": {}}

	## 4. Resolve context for the chosen action (e.g., pick travel destination, pick attack target)
	## e.g., StrategicAction(TRAVEL, destination_strategy=NEAREST_TOWN) → context={travel_destination: "vienna"}
	var context = best_action.resolve_context(situation)
	Log.debug("Brain:%s" % squad.squad_name, "Decided: %s (score=%.2f)" % [best_action.action_name, best_score])
	return {"activity_type": best_action.activity_type, "context": context}



