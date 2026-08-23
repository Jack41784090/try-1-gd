class_name StrategySquadBrain
extends Resource

var config: SquadBrainConfig
var squad: StrategySquad
var _rng := RandomNumberGenerator.new()

func _init(p_squad: StrategySquad, p_config: SquadBrainConfig) -> void:
	assert(p_squad != null, "StrategySquadBrain requires a squad")
	assert(p_config != null, "StrategySquadBrain requires a config")
	squad = p_squad
	config = p_config
	_rng.randomize()


func decide(world: World, faction: Faction, directive: FactionDirective) -> Dictionary:
	var situation = StrategicSituation.new(squad, world, faction, directive)

	var best_score := -INF
	var best_action: StrategicAction = null

	for consideration in config.considerations:
		var score = consideration.score(situation)
		var action = consideration.returning
		if action == null:
			continue

		if score <= 0.0:
			continue

		# noise breaks ties/determinism between equally-scored actions
		score *= _rng.randf_range(0.9, 1.1)

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

		MyLog.trace("Brain:%s" % squad.squad_name, "%s → %.2f" % [consideration.name, score])

		if score > best_score:
			best_score = score
			best_action = action

	if best_action == null:
		best_action = config.fallback_action
		MyLog.debug("Brain:%s" % squad.squad_name, "Using fallback: %s" % [best_action.action_name if best_action else "NONE"])

	if best_action == null:
		return {"activity_type": StrategyTypes.ActivityType.REST, "context": {}}

	var context = best_action.resolve_context(situation)
	MyLog.debug("Brain:%s" % squad.squad_name, "Decided: %s (score=%.2f)" % [best_action.action_name, best_score])
	return {"activity_type": best_action.activity_type, "context": context}
