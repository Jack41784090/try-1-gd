class_name AttackHandler
extends ActivityHandler


func can_execute(activity, _squad: StrategySquad, location: Location) -> bool:
	assert(activity.attack_config, "AttackHandler requires attack_config on Activity")
	return location.stability < activity.attack_config.min_stability_to_block


func execute(context: Dictionary, result: ActivityResult) -> ActivityResult:
	var world = context.get("world") as World
	var squad = context.get("squad") as StrategySquad
	var tracker = world.contact_tracker

	var enemies_here = world.get_squads_at_location(squad.current_location_id)

	if enemies_here.is_empty():
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -5.0)
		return result

	var target_enemy: StrategySquad = null
	var chosen_id = context.get("attack_target", "")
	if not chosen_id.is_empty():
		for e in enemies_here:
			if e.squad_id == chosen_id:
				target_enemy = e
				break

	if target_enemy == null:
		var best_progress: float = -1.0
		for e in enemies_here:
			var c = tracker.get_contact(squad.squad_id, e.squad_id)
			if c and c.progress > best_progress:
				best_progress = c.progress
				target_enemy = e
		if target_enemy == null:
			target_enemy = enemies_here[0]

	var contact = tracker.get_contact(squad.squad_id, target_enemy.squad_id)
	if not contact or contact.get_state() < StrategyTypes.ContactState.LOCKED:
		var state_name = StrategyTypes.ContactState.keys()[contact.get_state()] if contact else "NONE"
		Log.info("AttackHandler", "ATTACK blocked — contact on %s is only %s (need LOCKED)" % [
			target_enemy.squad_name, state_name])
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -3.0)
		return result

	result.requires_combat = true
	result.combat_target_squad_id = target_enemy.squad_id
	result.requires_async = true
	result.engagement_type = tracker.classify_engagement(squad.squad_id, target_enemy.squad_id)

	Log.info("AttackHandler", "ATTACK engagement: %s vs %s [%s]" % [
		squad.squad_name, target_enemy.squad_name,
		StrategyTypes.EngagementType.keys()[result.engagement_type]])
	return result
