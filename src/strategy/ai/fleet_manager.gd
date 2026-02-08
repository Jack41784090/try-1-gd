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
		runner.name = "AIRunner_%s" % squad.squad_id
		add_child(runner)
		runner.setup(scenario, squad)
		ai_runners.append(runner)
		
		print("[AIFleetManager] Created runner for squad: %s" % squad.squad_name)
	
	print("[AIFleetManager] Fleet setup complete with %d AI runners" % ai_runners.size())

## Execute all AI squad turns in parallel
## Returns dictionary with combat results, movements, and events
func execute_all_ai_turns() -> Dictionary:
	if ai_runners.is_empty():
		return {"combats": [], "movements": [], "events": []}
	
	print("\n[AIFleetManager] === Executing AI Turn for %d squads ===" % ai_runners.size())
	
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
		print("[AIFleetManager] Squad %s executing %s" % [
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
	
	print("[AIFleetManager] AI turn complete: %d combats, %d movements" % [
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
		var target_squad: StrategicSquad = null
		
		if not target_id.is_empty():
			# Specific target specified
			target_squad = _find_squad_by_id(target_id)
		else:
			# Attack enemies at current location
			var enemies = scenario.world.get_squads_at_location(runner.assigned_squad.current_location_id)
			if not enemies.is_empty():
				target_squad = enemies[0]
				target_id = target_squad.squad_id
		
		if not target_squad:
			print("[AIFleetManager] Squad %s has no valid target, skipping attack" % attacker_id)
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
func _find_squad_by_id(squad_id: String) -> StrategicSquad:
	# Check roaming squads
	for squad in scenario.world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad
	
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
