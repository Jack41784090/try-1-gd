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

	if situation.enemies_here.size() > 0:
		print("[SquadBrain:%s] DEBUG: %d enemies at %s, best_contact=%.1f" % [
			squad.squad_name, situation.enemies_here.size(),
			squad.current_location_id, situation.our_best_contact
		])

	var best_score := -INF
	var best_action: StrategicAction = null

	for consideration in config.considerations:
		var score = consideration.score(situation)
		var action = consideration.returning

		if situation.enemies_here.size() > 0 and consideration.name == "attack-weak-enemy":
			var glance_vals: Array[float] = []
			for glance in consideration.glances:
				glance_vals.append(glance.evaluate(situation))
			print("[SquadBrain:%s] TRACE attack-weak-enemy: glances=%s op=%d weight=%.1f score=%.4f action=%s" % [
				squad.squad_name, str(glance_vals), consideration.op, consideration.weight, score,
				action.action_name if action else "null"
			])

		if action == null:
			continue

		if score <= 0.0:
			continue

		if not _can_execute_action(action, situation):
			if action.activity_type == StrategyTypes.ActivityType.ATTACK:
				print("[SquadBrain:%s] BLOCKED %s (score=%.2f, enemies_here=%d, can_resolve=%s)" % [
					squad.squad_name, consideration.name, score,
					situation.enemies_here.size(),
					str(action.can_resolve(situation))
				])
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
