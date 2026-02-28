extends Node
class_name AIFleetManager

var scenario: GameScenario = null
var squad_brains: Dictionary = {}
var squad_executors: Dictionary = {}
var faction_brain: FactionBrain = FactionBrain.new()

var decisions_this_turn: Dictionary = {}
var squads_in_combat: Array[String] = []

func setup(_scenario: GameScenario) -> void:
	assert(_scenario != null, "AIFleetManager requires a GameScenario")
	scenario = _scenario

	print("[AIFleetManager] Setting up fleet with %d roaming squads" % scenario.world.roaming_squads.size())

	squad_brains.clear()
	squad_executors.clear()

	var profile = AIProfileFactory.get_default_squad_profile()

	var AEM = load("res://src/strategy/ui/actor/!main.gd")

	for squad in scenario.world.roaming_squads:
		if squad.current_location_id.is_empty() and not squad.starting_location_id.is_empty():
			squad.set_location(squad.starting_location_id)

		_ensure_unique_warriors(squad)

		var brain = SquadBrain.new(squad, profile)
		squad_brains[squad.squad_id] = brain

		var executor = AEM.new(true)
		executor.setup(scenario, {"squad": squad})
		squad_executors[squad.squad_id] = executor

		print("[AIFleetManager] Created brain for squad: %s" % squad.squad_name)

	print("[AIFleetManager] Fleet setup complete with %d squad brains" % squad_brains.size())

func return_all_ai_turns() -> Dictionary:
	if squad_brains.is_empty():
		return {"combats": [], "movements": [], "events": []}

	print("\n[AIFleetManager] === Returning AI Turn for %d squads ===" % squad_brains.size())

	decisions_this_turn.clear()
	squads_in_combat.clear()

	var directives = faction_brain.produce_directives(scenario.world)
	var default_directive = directives[0] if not directives.is_empty() else FactionDirective.create_none()

	for squad_id in squad_brains:
		var brain: SquadBrain = squad_brains[squad_id]
		var result = brain.decide(scenario.world, null, default_directive)

		decisions_this_turn[squad_id] = {
			"activity_type": result["activity_type"],
			"context": result["context"],
			"squad": brain.squad
		}

	var combat_pairs = _resolve_attack_conflicts()

	var movements: Array = []
	var events: Array = []

	for squad_id in decisions_this_turn:
		if squad_id in squads_in_combat:
			continue

		var decision = decisions_this_turn[squad_id]
		var squad: SquadStrategicData = decision["squad"]
		var activity_type: StrategyTypes.ActivityType = decision["activity_type"]
		var context: Dictionary = decision["context"]

		print("[AIFleetManager] Squad %s wants to %s" % [
			squad.squad_name,
			StrategyTypes.ActivityType.keys()[activity_type]
		])

		if activity_type in [StrategyTypes.ActivityType.TRAVEL, StrategyTypes.ActivityType.FORCE_MARCH]:
			if context.has("travel_destination"):
				movements.append({
					"squad_id": squad_id,
					"from": squad.current_location_id,
					"to": context["travel_destination"]
				})

	print("[AIFleetManager] AI showing intentions complete: %d combats, %d movements" % [
		combat_pairs.size(),
		movements.size()
	])

	return {
		"combats": combat_pairs,
		"movements": movements,
		"events": events
	}

func _resolve_attack_conflicts() -> Array:
	var combat_pairs: Array = []
	var processed_squads: Dictionary = {}

	var attack_decisions: Array = []
	for squad_id in decisions_this_turn:
		var decision = decisions_this_turn[squad_id]
		if decision["activity_type"] == StrategyTypes.ActivityType.ATTACK:
			attack_decisions.append({
				"squad_id": squad_id,
				"decision": decision
			})

	for attack_data in attack_decisions:
		var attacker_id: String = attack_data["squad_id"]
		var decision: Dictionary = attack_data["decision"]
		var squad: SquadStrategicData = decision["squad"]
		var context: Dictionary = decision["context"]

		if processed_squads.has(attacker_id):
			continue

		var target_id: String = context.get("attack_target", "")
		var target_squad: SquadStrategicData = null

		if not target_id.is_empty():
			target_squad = _find_squad_by_id(target_id)
		else:
			var enemies = scenario.world.get_squads_at_location(squad.current_location_id)
			var valid_enemies: Array[SquadStrategicData] = []
			for enemy in enemies:
				if enemy.squad_id != attacker_id:
					valid_enemies.append(enemy)

			if not valid_enemies.is_empty():
				target_squad = valid_enemies[0]
				target_id = target_squad.squad_id

		if not target_squad:
			print("[AIFleetManager] Squad %s has no valid target, skipping attack" % attacker_id)
			continue

		var contact = scenario.world.contact_tracker.get_contact(attacker_id, target_id)
		if not contact or contact.get_state() < StrategyTypes.ContactState.SUSPECTED:
			var state_name = StrategyTypes.ContactState.keys()[contact.get_state()] if contact else "NONE"
			print("[AIFleetManager] Squad %s attack blocked — contact on %s only %s" % [
				attacker_id, target_id, state_name
			])
			continue

		var is_mutual = false
		if decisions_this_turn.has(target_id):
			var target_decision = decisions_this_turn[target_id]
			if target_decision["activity_type"] == StrategyTypes.ActivityType.ATTACK:
				var target_context = target_decision["context"]
				var target_target = target_context.get("attack_target", "")
				if target_target == attacker_id:
					is_mutual = true

		var combat_pair = {
			"attacker_id": attacker_id,
			"defender_id": target_id,
			"is_mutual": is_mutual,
			"location_id": squad.current_location_id
		}
		combat_pairs.append(combat_pair)

		processed_squads[attacker_id] = true
		processed_squads[target_id] = true
		squads_in_combat.append(attacker_id)
		squads_in_combat.append(target_id)

		print("[AIFleetManager] Combat: %s vs %s%s at %s" % [
			attacker_id,
			target_id,
			" (MUTUAL)" if is_mutual else "",
			squad.current_location_id
		])

	return combat_pairs

func _find_squad_by_id(squad_id: String) -> SquadStrategicData:
	for squad in scenario.world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad

	if scenario.starting_player_squad and scenario.starting_player_squad.strategic_data.squad_id == squad_id:
		return scenario.starting_player_squad.strategic_data

	return null

func get_ai_squad_count() -> int:
	return squad_brains.size()

func get_ai_squad_ids() -> Array[String]:
	var ids: Array[String] = []
	for squad_id in squad_brains:
		ids.append(squad_id)
	return ids

func commit_ai_decisions(ai_results: Dictionary) -> void:
	print("\n[AIFleetManager] === Committing AI Decisions ===")

	var combats: Array = ai_results["combats"]
	for combat_data in combats:
		_execute_headless_combat(combat_data)

	_cleanup_defeated_squads()

	for squad_id in decisions_this_turn:
		if squad_id in squads_in_combat:
			continue

		var decision = decisions_this_turn[squad_id]
		var activity_type: StrategyTypes.ActivityType = decision["activity_type"]
		var context: Dictionary = decision["context"]

		_execute_activity(squad_id, activity_type, context)

	for squad_id in squad_brains:
		var brain: SquadBrain = squad_brains[squad_id]
		var squad = brain.squad
		if squad.food > 0:
			squad.consume_food(1)

	print("[AIFleetManager] Commit complete")

func _execute_activity(squad_id: String, activity_type: StrategyTypes.ActivityType, context: Dictionary) -> void:
	if not squad_executors.has(squad_id):
		print("[AIFleetManager] No executor for squad %s" % squad_id)
		return

	var executor: ActivityExecuteManager = squad_executors[squad_id]

	var activity = _get_activity_from_scenario(activity_type)
	if not activity:
		push_error("[AIFleetManager] Could not find activity of type %s" % StrategyTypes.ActivityType.keys()[activity_type])
		return

	match activity_type:
		StrategyTypes.ActivityType.TRAVEL, StrategyTypes.ActivityType.FORCE_MARCH:
			var destination = context.get("travel_destination", "")
			if destination.is_empty():
				push_error("[AIFleetManager] TRAVEL activity requires destination in context")
				return
			activity.destination_id = destination
			if activity_type == StrategyTypes.ActivityType.FORCE_MARCH:
				activity.ultimate_destination_id = context.get("ultimate_destination", "")

	var exec_context = executor._build_context(activity)
	var results = activity.execute(exec_context)

	if results.is_empty():
		return

	var result = results[0]
	executor._apply_result(result)

func _get_activity_from_scenario(activity_type: StrategyTypes.ActivityType) -> Activity:
	for triggerable in scenario.triggerable_manager.registered_triggerables:
		if triggerable is Activity and triggerable.activity_type == activity_type:
			return triggerable
	return null

func _execute_headless_combat(combat_data: Dictionary) -> void:
	var attacker_id: String = combat_data["attacker_id"]
	var defender_id: String = combat_data["defender_id"]
	var is_mutual: bool = combat_data.get("is_mutual", false)

	print("\n[AIFleetManager] Resolving combat: %s vs %s%s" % [
		attacker_id,
		defender_id,
		" (MUTUAL)" if is_mutual else ""
	])

	var attacker = _find_squad_by_id(attacker_id)
	var defender = _find_squad_by_id(defender_id)

	if not attacker or not defender:
		print("[AIFleetManager] ERROR: Could not find squads for combat")
		return

	var atk_living = attacker.get_living_warriors()
	var def_living = defender.get_living_warriors()
	var atk_strength := atk_living.size() * (attacker.get_morale() + 50.0)
	var def_strength := def_living.size() * (defender.get_morale() + 50.0)

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	atk_strength *= rng.randf_range(0.7, 1.3)
	def_strength *= rng.randf_range(0.7, 1.3)

	print("[AIFleetManager] Strength: %s=%.0f vs %s=%.0f" % [
		attacker.squad_name, atk_strength, defender.squad_name, def_strength
	])

	var winner: SquadStrategicData
	var loser: SquadStrategicData
	if atk_strength >= def_strength:
		winner = attacker
		loser = defender
	else:
		winner = defender
		loser = attacker

	var loser_living = loser.get_living_warriors()
	var casualties = maxi(1, loser_living.size() / 2)
	for i in range(mini(casualties, loser_living.size())):
		loser_living[i].is_dead = true
	print("[AIFleetManager] %s lost %d warriors" % [loser.squad_name, casualties])

	var winner_living = winner.get_living_warriors()
	if winner_living.size() > 1 and rng.randf() < 0.4:
		winner_living[0].is_injured = true
		print("[AIFleetManager] %s had 1 warrior injured" % winner.squad_name)

	winner.modify_morale(15)
	loser.modify_morale(-20)
	print("[AIFleetManager] %s VICTORIOUS (morale: %d)" % [winner.squad_name, winner.get_morale()])
	print("[AIFleetManager] %s DEFEATED (morale: %d, living: %d)" % [
		loser.squad_name, loser.get_morale(), loser.get_living_warriors().size()
	])

func _cleanup_defeated_squads() -> void:
	var to_remove: Array[String] = []

	for squad_id in squad_brains:
		var brain: SquadBrain = squad_brains[squad_id]
		var squad = brain.squad

		var living_count = 0
		var total_count = squad.warriors.size()

		for warrior in squad.warriors:
			if warrior != null and not warrior.is_dead:
				living_count += 1

		print("[AIFleetManager] Squad %s: %d/%d warriors alive" % [
			squad.squad_name,
			living_count,
			total_count
		])

		if living_count == 0:
			print("[AIFleetManager] Squad %s eliminated - removing from fleet" % squad.squad_name)
			to_remove.append(squad_id)

	for squad_id in to_remove:
		var brain: SquadBrain = squad_brains[squad_id]
		scenario.world.roaming_squads.erase(brain.squad)
		scenario.world.contact_tracker.clear_contacts_for(squad_id)
		squad_brains.erase(squad_id)
		squad_executors.erase(squad_id)

	if to_remove.size() > 0:
		print("[AIFleetManager] %d squads eliminated. Remaining: %d" % [to_remove.size(), squad_brains.size()])

func fill_activity_log(activity_log: Dictionary, edge_log: Dictionary) -> void:
	for squad_id in decisions_this_turn:
		var decision = decisions_this_turn[squad_id]
		var squad: SquadStrategicData = decision["squad"]
		var activity_type: StrategyTypes.ActivityType = decision["activity_type"]
		var context: Dictionary = decision["context"]

		activity_log[squad_id] = activity_type

		if activity_type in [StrategyTypes.ActivityType.TRAVEL, StrategyTypes.ActivityType.FORCE_MARCH]:
			var destination = context.get("travel_destination", "")
			if not destination.is_empty():
				edge_log[squad_id] = {"from": squad.current_location_id, "to": destination}

func _ensure_unique_warriors(squad: SquadStrategicData) -> void:
	var unique_warriors: Array[CharacterSocialStats] = []
	for i in range(squad.warriors.size()):
		var copy: CharacterSocialStats = squad.warriors[i].duplicate(true)
		copy.id = "%s_w%d" % [squad.squad_id, i]
		unique_warriors.append(copy)
	squad.warriors = unique_warriors
