extends RefCounted
class_name SquadBattle

var Types = SquadBattleTypes


var teams_and_squads: Dictionary = {}
var team_names: Array = []
var round_count: int = -1

# Tactic configuration for battle flow
var attacker_tactic: Tactic = null
var defender_tactic: Tactic = null

# Max rounds is determined by attacker's tactic action_count
var max_rounds: int = 3

func _init(config: Dictionary):
	var teams = config.get("teams", {})
	
	# Store tactics if provided
	attacker_tactic = config.get("attacker_tactic", Tactic.create_balanced())
	defender_tactic = config.get("defender_tactic", Tactic.create_balanced())
	
	# Max rounds comes from attacker's action_count
	max_rounds = attacker_tactic.action_count
	
	for team_name in teams:
		var squad_configs = teams[team_name]
		teams_and_squads[team_name] = []
		
		for squad_config in squad_configs:
			var squad = Squad.new(squad_config)
			teams_and_squads[team_name].append(squad)
		
		team_names.append(team_name)

	pass

func get_entity_by_id(entity_id: int):
	for team_name in teams_and_squads:
		var squads = teams_and_squads[team_name]
		for squad in squads:
			for entity in squad.entities:
				if entity.player_id == entity_id:
					return entity
	
	push_error("Entity with ID ", entity_id, " not found!")
	return null

func remove_capitulated_entities(capitulated_entities: Array):
	for entity in capitulated_entities:
		for team_name in teams_and_squads:
			var squads = teams_and_squads[team_name]
			for squad in squads:
				var entities_to_remove = []
				for i in range(squad.entities.size()):
					if squad.entities[i].player_id == entity.player_id:
						entities_to_remove.append(i)
						print("[WARNING] Entity ", squad.entities[i].player_id, " has capitulated and left the battle!")
				
				for i in range(entities_to_remove.size() - 1, -1, -1):
					squad.entities.remove_at(entities_to_remove[i])

func get_all_enemy_squads(current_team_name: Variant) -> Array:
	var enemy_squads: Array = []
	
	for team_name in team_names:
		if team_name != current_team_name:
			for squad in teams_and_squads[team_name]:
				enemy_squads.append(squad)
	
	return enemy_squads

func choose_weighted_enemy_squad(current_team_name: String):
	var enemy_squads = get_all_enemy_squads(current_team_name)
	var result = null
	
	if enemy_squads.size() > 0:
		var weights = []
		for squad in enemy_squads:
			var total_hp = 0.0
			for entity in squad.entities:
				total_hp += entity.get_changeable_stat_num(Types.EntityChangeable.HP)
			
			var avg_hp = total_hp / max(squad.entities.size(), 1)
			weights.append(max(1, 100 - avg_hp))
		
		var total_weight = 0.0
		for weight in weights:
			total_weight += weight
		
		var random_value = randf() * total_weight
		var current_weight = 0.0
		var selected_squad = null
		
		for i in range(enemy_squads.size()):
			current_weight += weights[i]
			if random_value < current_weight and not selected_squad:
				selected_squad = enemy_squads[i]
		
		result = selected_squad if selected_squad else enemy_squads[enemy_squads.size() - 1]
	
	return result

func check_team_strength(team_name: Variant) -> float:
	var strength = 0.0
	
	if teams_and_squads.has(team_name):
		for squad in teams_and_squads[team_name]:
			for entity in squad.entities:
				strength += entity.get_changeable_stat_num(Types.EntityChangeable.HP)
	
	return strength

func check_victory() -> bool:
	return get_battle_outcome() != SquadBattleTypes.BattleOutcome.ONGOING

func get_battle_outcome() -> SquadBattleTypes.BattleOutcome:
	var attacker_strength = check_team_strength(SquadBattleTypes.Side.ATTACKER)
	var defender_strength = check_team_strength(SquadBattleTypes.Side.DEFENDER)
	
	# Check for team elimination
	if attacker_strength <= 0:
		return SquadBattleTypes.BattleOutcome.DEFENDER_VICTORY
	if defender_strength <= 0:
		return SquadBattleTypes.BattleOutcome.ATTACKER_VICTORY
	
	# Check for round exhaustion (Draw)
	if round_count >= max_rounds:
		return SquadBattleTypes.BattleOutcome.DRAW
	
	return SquadBattleTypes.BattleOutcome.ONGOING

func squad_recoveries():
	for team_name in teams_and_squads:
		var squads = teams_and_squads[team_name]
		for squad in squads:
			if squad.get_last_attacked_at_round() < round_count:
				squad.recovery()

func squad_actions() -> Array[EntityUpdate]:
	var updates: Array[EntityUpdate] = []
	
	# Get attacker and defender squads
	var attacker_squads: Array = teams_and_squads.get(Types.Side.ATTACKER, [])
	var defender_squads: Array = teams_and_squads.get(Types.Side.DEFENDER, [])
	
	SBLog.section("Round %d/%d - Attacker Phase" % [round_count, max_rounds], 2, 1, 0)
	
	# Phase 1: Attackers act (1 action each, modified by tactic)
	for squad in attacker_squads:
		var squad_updates = squad.perform_actions(
			defender_squads,
			round_count,
			1,
			attacker_tactic.attack_modifier
		)
		for update in squad_updates:
			updates.append(update)
	
	SBLog.section("Round %d/%d - Defender Phase (%d reactions)" % [round_count, max_rounds, defender_tactic.reaction_count], 2, 1, 0)
	
	# Phase 2: Defenders react (using defender_tactic.reaction_count)
	for squad in defender_squads:
		var squad_updates = squad.perform_reactions(
			attacker_squads,
			round_count,
			defender_tactic.reaction_count,
			defender_tactic.defense_modifier
		)
		for update in squad_updates:
			updates.append(update)

	SBLog.section("Round %d Updates" % round_count, 2, 1, 0)
	for update in updates:
		SBLog.line(3, str(update))
	SBLog.line(2, "End of updates")
	return updates

func remove_dead_entities():
	for team_name in teams_and_squads:
		var squads = teams_and_squads[team_name]
		for squad in squads:
			var entities_to_remove = []
			for i in range(squad.entities.size()):
				if squad.entities[i].get_changeable_stat_num(Types.EntityChangeable.HP) == 0:
					entities_to_remove.append(i)
			
			for i in range(entities_to_remove.size() - 1, -1, -1):
				squad.entities.remove_at(entities_to_remove[i])

## Run battle to completion without scene instantiation or visualization
## Returns all EntityUpdate objects collected across all rounds
## Used for AI vs AI combat resolution
func run_headless() -> Array[EntityUpdate]:
	var all_updates: Array[EntityUpdate] = []
	
	print("[SquadBattle.run_headless] Starting headless combat simulation")
	print("  Attacker tactic: %s (max_rounds=%d)" % [attacker_tactic, max_rounds])
	print("  Defender tactic: %s" % defender_tactic)
	
	round_count = 0
	
	while not check_victory() and round_count < max_rounds:
		round_count += 1
		
		print("[SquadBattle.run_headless] === Round %d/%d ===" % [round_count, max_rounds])
		
		# Execute squad recoveries
		squad_recoveries()
		
		# Execute all squad actions for this round
		var round_updates = squad_actions()
		
		# Collect updates
		for update in round_updates:
			all_updates.append(update)
		
		# Remove dead/capitulated entities
		remove_dead_entities()
		
		# Check battle state
		var outcome = get_battle_outcome()
		print("[SquadBattle.run_headless] Round %d outcome: %s" % [round_count, SquadBattleTypes.BattleOutcome.keys()[outcome]])
		print("  Attacker strength: %d, Defender strength: %d" % [
			check_team_strength(SquadBattleTypes.Side.ATTACKER),
			check_team_strength(SquadBattleTypes.Side.DEFENDER)
		])
	
	var final_outcome = get_battle_outcome()
	print("[SquadBattle.run_headless] Battle complete after %d rounds: %s" % [
		round_count,
		SquadBattleTypes.BattleOutcome.keys()[final_outcome]
	])
	print("  Total updates: %d" % all_updates.size())
	
	return all_updates
