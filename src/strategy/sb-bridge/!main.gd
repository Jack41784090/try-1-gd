extends RefCounted
class_name CombatBridge

# signal combat_requested(player_squad: StrategicSquad, enemy_squad: StrategicSquad, context: Dictionary)
# signal combat_phase_completed(updates: Array[EntityUpdate])
# signal combat_ended(result: Dictionary)

var warrior_to_entity: Dictionary = {}
var entity_to_warrior: Dictionary = {}
var current_battle: SquadBattle = null
var player_combat_squad: Squad = null
var enemy_combat_squad: Squad = null
var current_tactic: Tactic = null
var _next_entity_id: int = 1

func create_battle(
	player_squad: StrategicSquad,
	enemy_squad: StrategicSquad,
	tactic: Tactic
) -> SquadBattle:
	clear_mappings()
	current_tactic = tactic
	
	var player_squad_config = _build_squad_config(player_squad, "player", SquadBattleTypes.Side.ATTACKER)
	var enemy_squad_config = _build_squad_config(enemy_squad, "enemy", SquadBattleTypes.Side.DEFENDER)
	
	print("[CombatBridge] Creating battle with config:")
	print("[CombatBridge]   Player squad: %s (%d entities)" % [player_squad_config.name, player_squad_config.entities.size()])
	print("[CombatBridge]   Enemy squad: %s (%d entities)" % [enemy_squad_config.name, enemy_squad_config.entities.size()])
	print("[CombatBridge]   Attacker Tactic: %s (actions=%d, reactions=%d)" % [
		tactic.tactic_name, tactic.action_count, tactic.reaction_count
	])
	
	# Enemy uses balanced tactic by default
	var enemy_tactic = Tactic.create_balanced()
	
	current_battle = SquadBattle.new({
		"teams": {
			SquadBattleTypes.Side.ATTACKER: [player_squad_config],
			SquadBattleTypes.Side.DEFENDER: [enemy_squad_config]
		},
		"attacker_tactic": tactic,
		"defender_tactic": enemy_tactic
	})
	
	# Store Squad references after battle creation
	if current_battle.teams_and_squads.has("player") and current_battle.teams_and_squads["player"].size() > 0:
		player_combat_squad = current_battle.teams_and_squads["player"][0]
	if current_battle.teams_and_squads.has("enemy") and current_battle.teams_and_squads["enemy"].size() > 0:
		enemy_combat_squad = current_battle.teams_and_squads["enemy"][0]
	
	return current_battle

func _build_squad_config(strategic_squad: StrategicSquad, team: String, side: SquadBattleTypes.Side) -> Dictionary:
	var entity_configs: Array = []
	var living_warriors = strategic_squad.get_living_warriors()
	var formation = strategic_squad.formation
	
	for i in range(living_warriors.size()):
		var warrior: Warrior = living_warriors[i]
		var entity_id = _next_entity_id
		_next_entity_id += 1
		
		warrior_to_entity[warrior.id] = entity_id
		entity_to_warrior[entity_id] = warrior.id
		
		var starting_loc = warrior.location_prebattle
		if i < formation.size():
			starting_loc = formation[i] as SquadBattleTypes.SquadEntityInSquadLocation
		

		var entity_config = EntityConfig.new(
			warrior.id,
			entity_id,
			warrior.name,
			team,
			warrior.combat_stats if warrior.combat_stats else EntityBaseStats.new(),
			starting_loc,
			warrior.logic_type
		)
		
		if warrior.equipment_weapon:
			entity_config.weapon = warrior.equipment_weapon
		else:
			entity_config.weapon_class = WeaponFactory.WeaponClasses.Unarmed
			print("[CombatBridge]   Warrior '%s' has no weapon, using Unarmed" % warrior.name)
		
		if warrior.equipment_armor:
			entity_config.armor = warrior.equipment_armor
		else:
			entity_config.armor_class = ArmorFactory.ArmorClasses.Unarmored
			print("[CombatBridge]   Warrior '%s' has no armor, using Unarmored" % warrior.name)
		
		entity_configs.append(entity_config)
	
	var squad_config = {
		"entities": entity_configs,
		"name": strategic_squad.squad_name,
		"team": team,
		"side": side
	}
	
	return squad_config

func apply_results(strategic_squad: StrategicSquad, updates: Array[EntityUpdate]) -> Dictionary:
	var result = {
		"deaths": [],
		"injuries": [],
		"morale_changes": {}
	}
	
	for update in updates:
		var warrior_id = get_warrior_for_entity(update.affected)
		var warrior = strategic_squad.get_warrior_by_id(warrior_id)
		match update.change.property:
			SquadBattleTypes.EntityChangeable.HP:
				var from_hp = update.change.from
				var to_hp = update.change.to
				
				if to_hp <= 0:
					warrior.is_dead = true
					warrior.morale = 0.0
					result.deaths.append(warrior_id)
				elif to_hp < from_hp:
					warrior.is_injured = true
					var damage_ratio = (from_hp - to_hp) / from_hp if from_hp > 0 else 0.0
					var morale_loss = damage_ratio * 20.0
					warrior.modify_morale(-morale_loss)
					result.injuries.append(warrior_id)
					result.morale_changes[warrior_id] = -morale_loss
			
			SquadBattleTypes.EntityChangeable.ORG:
				var org_change = update.change.to - update.change.from
				var morale_change = org_change * 0.5
				warrior.modify_morale(morale_change)
				if result.morale_changes.has(warrior_id):
					result.morale_changes[warrior_id] += morale_change
				else:
					result.morale_changes[warrior_id] = morale_change
			
			SquadBattleTypes.EntityChangeable.DIE:
				warrior.is_dead = true
				warrior.morale = 0.0
				if not result.deaths.has(warrior_id):
					result.deaths.append(warrior_id)
	
	strategic_squad.update_aggregate_morale()
	strategic_squad.remove_dead_warriors()
	
	return result

func get_warrior_for_entity(entity_id: int) -> String:
	return entity_to_warrior.get(entity_id, "")

func get_entity_for_warrior(warrior_id: String) -> int:
	return warrior_to_entity.get(warrior_id, -1)

func clear_mappings() -> void:
	warrior_to_entity.clear()
	entity_to_warrior.clear()
	current_battle = null
	player_combat_squad = null
	enemy_combat_squad = null
	current_tactic = null
	_next_entity_id = 1

func get_battle_summary() -> Dictionary:
	if not current_battle:
		return {}
	
	return {
		"player_strength": current_battle.check_team_strength("player"),
		"enemy_strength": current_battle.check_team_strength("enemy"),
		"round_count": current_battle.round_count,
		"tactic": current_tactic.tactic_name if current_tactic else "None"
	}
