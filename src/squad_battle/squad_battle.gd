extends RefCounted
class_name SquadBattle

const Types = preload("res://src/squad_battle/types.gd")

var teams_and_squads: Dictionary = {}
var team_names: Array = []
var round_count: int = -1

func _init(config: Dictionary):
	var teams = config.get("teams", {})
	
	for team_name in teams:
		var squad_configs = teams[team_name]
		teams_and_squads[team_name] = []
		
		for squad_config in squad_configs:
			var squad = Squad.new(squad_config)
			teams_and_squads[team_name].append(squad)
		
		team_names.append(team_name)

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

func get_all_enemy_squads(current_team_name: String) -> Array:
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
				total_hp += entity.get_changeable_stat_num("HP")
			
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

func check_team_strength(team_name: String) -> float:
	var strength = 0.0
	
	if teams_and_squads.has(team_name):
		for squad in teams_and_squads[team_name]:
			for entity in squad.entities:
				strength += entity.get_changeable_stat_num("HP")
	
	return strength

func check_victory() -> bool:
	var alive_teams = 0
	var dead_teams = 0
	
	for team_name in teams_and_squads:
		var team_strength = check_team_strength(team_name)
		if team_strength <= 0:
			dead_teams += 1
		else:
			alive_teams += 1
	
	print("Check victory: alive[", alive_teams, "] dead[", dead_teams, "]")
	return alive_teams <= 1

func squad_recoveries():
	for team_name in teams_and_squads:
		var squads = teams_and_squads[team_name]
		for squad in squads:
			if squad.get_last_attacked_at_round() < round_count:
				squad.recovery()

func squad_actions() -> Array:
	var updates: Array = []
	
	for team_name in teams_and_squads:
		var squads = teams_and_squads[team_name]
		var target_squads = get_all_enemy_squads(team_name)
		
		for squad in squads:
			var squad_update = squad.round(target_squads, round_count)
			
			if squad_update:
				for update in squad_update:
					updates.append(update)
	
	print("--- Round ", round_count, " Updates ---")
	for update in updates:
		var change_str = ""
		
		match update.change.property:
			"HP", "ORG":
				change_str = "%s %s -> %s" % [update.change.property, update.change.from, update.change.to]
			"DIE", "RETREAT", "LEAVE":
				change_str = update.change.property
			"LOC":
				change_str = "LOC %s -> %s" % [update.change.from, update.change.to]
			"CLINK":
				change_str = "CLINK! %s failed to pierce %s" % [update.source, update.affected]
			"DODGE":
				change_str = "DODGE! %s misses %s" % [update.source, update.affected]
			"PROC":
				var display = update.change.metadata.get("display", "-")
				change_str = "PROC! %s -%s-> on %s; V: %s -> %s" % [update.source, display, update.affected, update.change.from, update.change.to]
		
		print("  - ", update.source, " -> ", update.affected, ": ", change_str)
	
	print("------------------------------")
	return updates

func remove_dead_entities():
	for team_name in teams_and_squads:
		var squads = teams_and_squads[team_name]
		for squad in squads:
			var entities_to_remove = []
			for i in range(squad.entities.size()):
				if squad.entities[i].get_changeable_stat_num("HP") == 0:
					entities_to_remove.append(i)
			
			for i in range(entities_to_remove.size() - 1, -1, -1):
				squad.entities.remove_at(entities_to_remove[i])
