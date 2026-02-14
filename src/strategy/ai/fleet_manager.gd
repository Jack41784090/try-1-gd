extends Node
class_name AIFleetManager

## Manages a fleet of AI squad runners executing activities in parallel
## Handles conflict resolution for simultaneous attacks and coordinates turn execution

var ai_runners: Array[AIRunner] = []
var scenario: GameScenario = null

# Tracking data for conflict resolution
var decisions_this_turn: Dictionary = {} # squad_id -> {activity_type, context}
var squads_in_combat: Array[String] = [] # IDs of squads currently engaged in combat

func _ready():
	pass

## Initialize fleet with scenario and spawn AIRunner for each roaming squad
func setup(_scenario: GameScenario) -> void:
	assert(_scenario != null, "AIFleetManager requires a GameScenario")
	scenario = _scenario
	
	print("[AIFleetManager] Setting up fleet with %d roaming squads" % scenario.world.roaming_squads.size())
	
	# Clear existing runners
	for runner in ai_runners:
		runner.queue_free()
	ai_runners.clear()
	
	# Create AIRunner for each roaming squad
	for squad in scenario.world.roaming_squads:
		var runner = AIRunner.new()
		runner.name = "AIRunner_"
		add_child(runner)
		runner.setup(scenario, squad)
		ai_runners.append(runner)
		
		print("[AIFleetManager] Created runner for squad: %s" % squad.squad_name)
	
	print("[AIFleetManager] Fleet setup complete with %d AI runners" % ai_runners.size())

## Execute all AI squad turns in parallel
## Returns dictionary with combat results, movements, and events
func return_all_ai_turns() -> Dictionary:
	if ai_runners.is_empty():
		return {"combats": [], "movements": [], "events": []}
	
	print("\n[AIFleetManager] === Returning AI Turn for %d squads ===" % ai_runners.size())
	
	# Phase 1: Collect all decisions
	decisions_this_turn.clear()
	squads_in_combat.clear()
	
	for runner in ai_runners:
		var context = {}
		var activity_type = runner.decide_activity(scenario.world, context)
		
		decisions_this_turn[runner.squad_id] = {
			"activity_type": activity_type,
			"context": context,
			"runner": runner
		}
	
	# Phase 2: Resolve conflicts (attacks, travel collisions)
	var combat_pairs = _resolve_attack_conflicts()
	
	# Phase 3: Execute non-combat activities
	var movements: Array = []
	var events: Array = []
	
	for squad_id in decisions_this_turn:
		# Skip squads in combat
		if squad_id in squads_in_combat:
			continue
		
		var decision = decisions_this_turn[squad_id]
		var runner: AIRunner = decision["runner"]
		var activity_type: StrategyTypes.ActivityType = decision["activity_type"]
		var context: Dictionary = decision["context"]
		
		# Execute activity (currently just logs, full execution needs activity system integration)
		print("[AIFleetManager] SquadCombatData %s wants to %s" % [
			runner.assigned_squad.squad_name,
			StrategyTypes.ActivityType.keys()[activity_type]
		])
		
		# Track movements
		if activity_type in [StrategyTypes.ActivityType.TRAVEL, StrategyTypes.ActivityType.FORCE_MARCH]:
			if context.has("travel_destination"):
				movements.append({
					"squad_id": squad_id,
					"from": runner.assigned_squad.current_location_id,
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

## Resolve conflicts when multiple squads attack each other or same location
## Returns Array of combat pairs to be resolved
func _resolve_attack_conflicts() -> Array:
	var combat_pairs: Array = []
	var processed_squads: Dictionary = {} # squad_id -> true if already in a combat
	
	# Find all attack decisions
	var attack_decisions: Array = []
	for squad_id in decisions_this_turn:
		var decision = decisions_this_turn[squad_id]
		if decision["activity_type"] == StrategyTypes.ActivityType.ATTACK:
			attack_decisions.append({
				"squad_id": squad_id,
				"decision": decision
			})
	
	# Process each attack decision
	for attack_data in attack_decisions:
		var attacker_id: String = attack_data["squad_id"]
		var decision: Dictionary = attack_data["decision"]
		var runner: AIRunner = decision["runner"]
		var context: Dictionary = decision["context"]
		
		# Skip if already in combat
		if processed_squads.has(attacker_id):
			continue
		
		# Get target from context or location
		var target_id: String = context.get("attack_target", "")
		var target_squad: SquadStrategicData = null
		
		if not target_id.is_empty():
			# Specific target specified
			target_squad = _find_squad_by_id(target_id)
		else:
			# Attack enemies at current location (excluding self)
			var enemies = scenario.world.get_squads_at_location(runner.assigned_squad.current_location_id)
			var valid_enemies: Array[SquadStrategicData] = []
			for enemy in enemies:
				if enemy.squad_id != attacker_id:
					valid_enemies.append(enemy)
			
			if not valid_enemies.is_empty():
				target_squad = valid_enemies[0]
				target_id = target_squad.squad_id
		
		if not target_squad:
			print("[AIFleetManager] SquadCombatData %s has no valid target, skipping attack" % attacker_id)
			continue
		
		# Check if target is also attacking this squad (mutual attack)
		var is_mutual = false
		if decisions_this_turn.has(target_id):
			var target_decision = decisions_this_turn[target_id]
			if target_decision["activity_type"] == StrategyTypes.ActivityType.ATTACK:
				var target_context = target_decision["context"]
				var target_target = target_context.get("attack_target", "")
				if target_target == attacker_id:
					is_mutual = true
		
		# Create combat pair
		var combat_pair = {
			"attacker_id": attacker_id,
			"defender_id": target_id,
			"is_mutual": is_mutual,
			"location_id": runner.assigned_squad.current_location_id
		}
		combat_pairs.append(combat_pair)
		
		# Mark both squads as in combat
		processed_squads[attacker_id] = true
		processed_squads[target_id] = true
		squads_in_combat.append(attacker_id)
		squads_in_combat.append(target_id)
		
		print("[AIFleetManager] Combat: %s vs %s%s at %s" % [
			attacker_id,
			target_id,
			" (MUTUAL)" if is_mutual else "",
			runner.assigned_squad.current_location_id
		])
	
	return combat_pairs

## Find squad by ID from both roaming squads and player squad
func _find_squad_by_id(squad_id: String) -> SquadStrategicData:
	# Check roaming squads
	for squad in scenario.world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad.strategic_data
	
	# Check player squad
	if scenario.starting_player_squad and scenario.starting_player_squad.squad_id == squad_id:
		return scenario.starting_player_squad
	
	return null

## Get current number of active AI squads
func get_ai_squad_count() -> int:
	return ai_runners.size()

## Get list of all AI squad IDs
func get_ai_squad_ids() -> Array[String]:
	var ids: Array[String] = []
	for runner in ai_runners:
		ids.append(runner.squad_id)
	return ids

## Commit AI decisions - actually execute the activities and resolve combats
## Takes the result from return_all_ai_turns() and commits it to the game state
func commit_ai_decisions(ai_results: Dictionary) -> void:
	print("\n[AIFleetManager] === Committing AI Decisions ===")
	
	# Phase 1: Resolve all combats using headless execution
	var combats: Array = ai_results["combats"]
	for combat_data in combats:
		_execute_headless_combat(combat_data)
	
	# Cleanup defeated squads ONCE after all combats
	_cleanup_defeated_squads()
	
	# Phase 2: Execute non-combat activities
	for squad_id in decisions_this_turn:
		# Skip squads that were in combat
		if squad_id in squads_in_combat:
			continue
		
		var decision = decisions_this_turn[squad_id]
		var runner: AIRunner = decision["runner"]
		var activity_type: StrategyTypes.ActivityType = decision["activity_type"]
		var context: Dictionary = decision["context"]
		
		# Execute the activity through the runner
		runner.execute_activity(activity_type, context)
	
	print("[AIFleetManager] Commit complete")

## Execute a combat using headless SquadBattle
func _execute_headless_combat(combat_data: Dictionary) -> void:
	var attacker_id: String = combat_data["attacker_id"]
	var defender_id: String = combat_data["defender_id"]
	var is_mutual: bool = combat_data.get("is_mutual", false)
	var location_id: String = combat_data["location_id"]
	
	print("\n[AIFleetManager] Resolving combat: %s vs %s%s" % [
		attacker_id,
		defender_id,
		" (MUTUAL)" if is_mutual else ""
	])
	
	# Get squads
	var attacker = _find_squad_by_id(attacker_id)
	var defender = _find_squad_by_id(defender_id)
	
	if not attacker or not defender:
		print("[AIFleetManager] ERROR: Could not find squads for combat")
		return
	
	# Use CombatBridge to convert strategic squads to tactical configuration
	var combat_bridge = CombatBridge.new()
	
	# Create balanced tactic for AI combat
	var attacker_tactic = Tactic.create_balanced()
	
	# Create and run headless battle
	var squad_battle = combat_bridge.create_battle(attacker, defender, attacker_tactic)
	var all_updates = squad_battle.run_headless()
	
	# Determine outcome based on which side survived
	var attacker_strength = squad_battle.check_team_strength(SquadBattleTypes.Side.ATTACKER)
	var defender_strength = squad_battle.check_team_strength(SquadBattleTypes.Side.DEFENDER)
	var outcome = squad_battle.get_battle_outcome()
	
	print("[AIFleetManager] Combat complete: %s" % SquadBattleTypes.BattleOutcome.keys()[outcome])
	print("[AIFleetManager] Rounds: %d, Updates: %d" % [squad_battle.round_count, all_updates.size()])
	
	# Apply results back to strategic squads
	combat_bridge.apply_results(attacker, all_updates)
	combat_bridge.apply_results(defender, all_updates)
	
	# Apply morale changes based on outcome
	if outcome == SquadBattleTypes.BattleOutcome.ATTACKER_VICTORY:
		attacker.modify_morale(15)
		defender.modify_morale(-20)
		print("[AIFleetManager] %s VICTORIOUS (morale: %d)" % [attacker.squad_name, attacker.get_morale()])
		print("[AIFleetManager] %s DEFEATED (morale: %d)" % [defender.squad_name, defender.get_morale()])
	elif outcome == SquadBattleTypes.BattleOutcome.DEFENDER_VICTORY:
		defender.modify_morale(15)
		attacker.modify_morale(-20)
		print("[AIFleetManager] %s VICTORIOUS (morale: %d)" % [defender.squad_name, defender.get_morale()])
		print("[AIFleetManager] %s DEFEATED (morale: %d)" % [attacker.squad_name, attacker.get_morale()])
	else:
		attacker.modify_morale(-5)
		defender.modify_morale(-5)
		print("[AIFleetManager] DRAW - both squads withdraw")

## Remove AI runners for squads that have been eliminated
func _cleanup_defeated_squads() -> void:
	var to_remove: Array[AIRunner] = []
	
	for runner in ai_runners:
		# Check if squad has any living warriors
		var living_count = 0
		var total_count = runner.assigned_squad.warriors.size()
		
		for warrior in runner.assigned_squad.warriors:
			if warrior != null and not warrior.is_dead:
				living_count += 1
		
		print("[AIFleetManager] SquadCombatData %s: %d/%d warriors alive" % [
			runner.assigned_squad.squad_name,
			living_count,
			total_count
		])
		
		if living_count == 0:
			print("[AIFleetManager] SquadCombatData %s eliminated - removing from fleet" % runner.assigned_squad.squad_name)
			to_remove.append(runner)
	
	# Remove defeated squads from world and runners
	for runner in to_remove:
		ai_runners.erase(runner)
		scenario.world.roaming_squads.erase(runner.assigned_squad)
		runner.queue_free()
	
	if to_remove.size() > 0:
		print("[AIFleetManager] %d squads eliminated. Remaining: %d" % [to_remove.size(), ai_runners.size()])
