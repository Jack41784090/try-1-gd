class_name SquadBrain extends RefCounted

var config: SquadBrainConfig
var squad: SquadStrategicData

func _init(p_squad: SquadStrategicData, p_config: SquadBrainConfig) -> void:
	assert(p_squad != null, "SquadBrain requires a squad")
	assert(p_config != null, "SquadBrain requires a config")
	squad = p_squad
	config = p_config

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

		if not _can_execute_action(action, situation):
			continue

		print("[SquadBrain:%s] %s → %.2f" % [squad.squad_name, consideration.name, score])

		if score > best_score:
			best_score = score
			best_action = action

	if best_action == null:
		best_action = config.fallback_action
		print("[SquadBrain:%s] Using fallback: %s" % [squad.squad_name, best_action.action_name if best_action else "NONE"])

	if best_action == null:
		return {"activity_type": StrategyTypes.ActivityType.REST, "context": {}}

	var context = best_action.resolve_context(situation)
	print("[SquadBrain:%s] Decided: %s (score=%.2f)" % [squad.squad_name, best_action.action_name, best_score])
	return {"activity_type": best_action.activity_type, "context": context}

func _can_execute_action(action: StrategicAction, situation: StrategicSituation) -> bool:
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

	if at in location_independent:
		return action.can_resolve(situation)

	if not situation.location.has_activity_type(at):
		return false

	return action.can_resolve(situation)
