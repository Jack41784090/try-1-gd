class_name CombatBridge
extends RefCounted

var warrior_to_entity: Dictionary = {}
var entity_to_warrior: Dictionary = {}
var current_battle: SquadBattle = null
var player_combat_squad: CombatSquad = null
var enemy_combat_squad: CombatSquad = null
var current_tactic: Tactic = null
var _next_entity_id: int = 1


func create_battle(
		player_squad: StrategySquad,
		enemy_squad: StrategySquad,
		tactic: Tactic,
) -> SquadBattle:
	clear_mappings()
	current_tactic = tactic

	var player_squad_tuple = _build_squad_config(player_squad, SquadBattleTypes.Side.ATTACKER)
	var enemy_squad_tuple = _build_squad_config(enemy_squad, SquadBattleTypes.Side.DEFENDER)

	print("[CombatBridge] Creating battle with config:")
	print("[CombatBridge]   Player squad: %s (%d entities)" % [player_squad_tuple[0], player_squad_tuple[2].size()])
	print("[CombatBridge]   Enemy squad: %s (%d entities)" % [enemy_squad_tuple[0], enemy_squad_tuple[2].size()])
	print(
		"[CombatBridge]   Attacker Tactic: %s (actions=%d, reactions=%d)" % [
			tactic.tactic_name,
			tactic.action_count,
			tactic.reaction_count,
		],
	)

	var enemy_tactic = Tactic.create_balanced()

	var teams: Dictionary[SquadBattleTypes.Side, Array] = {
		SquadBattleTypes.Side.ATTACKER: [player_squad_tuple],
		SquadBattleTypes.Side.DEFENDER: [enemy_squad_tuple],
	}
	current_battle = SquadBattle.new(teams, tactic, enemy_tactic)

	var attacker_squads: Array = current_battle.side_squads_dict.get(SquadBattleTypes.Side.ATTACKER, [])
	if attacker_squads.size() > 0:
		player_combat_squad = attacker_squads[0]
	var defender_squads: Array = current_battle.side_squads_dict.get(SquadBattleTypes.Side.DEFENDER, [])
	if defender_squads.size() > 0:
		enemy_combat_squad = defender_squads[0]

	return current_battle


func apply_injury_penalties(strategic_squad: StrategySquad) -> void:
	assert(current_battle != null)
	for warrior in strategic_squad.get_living_warriors():
		if not warrior.is_injured:
			continue
		var entity_id = warrior_to_entity.get(warrior.id, -1)
		if entity_id == -1:
			continue
		var entity = current_battle.get_entity_by_id(entity_id)
		if entity == null:
			continue
		var max_hp = entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
		var penalty = max_hp * 0.5
		entity.mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, -penalty)
		Log.info("CombatBridge", "Injured warrior '%s' starts at %.0f/%.0f HP" % [warrior.display_name, max_hp - penalty, max_hp])


func _build_squad_config(strategic_squad: StrategySquad, side: SquadBattleTypes.Side) -> Array:
	var combat_entities: Array[CombatEntity] = []
	var living_warriors = strategic_squad.get_living_warriors()
	var formation = strategic_squad.formation

	for i in range(living_warriors.size()):
		var character: Character = living_warriors[i]
		var entity_id = _next_entity_id
		_next_entity_id += 1

		warrior_to_entity[character.id] = entity_id
		entity_to_warrior[entity_id] = character.id

		var starting_loc = character.location_prebattle
		if i < formation.size():
			starting_loc = formation[i] as SquadBattleTypes.SquadEntityInSquadLocation

		combat_entities.append(character.enter_battle(side, entity_id, starting_loc))

	return [strategic_squad.squad_name, side, combat_entities]


func apply_results(strategic_squad: StrategySquad, updates: Array[EntityUpdate]) -> Dictionary:
	var result = {
		"deaths": [],
		"injuries": [],
		"escaped": [],
		"morale_changes": {},
	}

	for update in updates:
		var warrior_id = get_warrior_for_entity(update.affected)
		if warrior_id.is_empty():
			continue

		var warrior := strategic_squad.get_warrior_by_id(warrior_id)
		if warrior == null:
			continue

		match update.change.property:
			SquadBattleTypes.EntityChangeable.HP:
				var from_hp = update.change.from
				var to_hp = update.change.to

				if to_hp <= 0:
					warrior.is_dead = true
					warrior.get_stat(StatName.I.MORALE).stat_value = 0.0
					result.deaths.append(warrior_id)
				elif to_hp < from_hp:
					warrior.is_injured = true
					var damage_ratio = (from_hp - to_hp) / from_hp if from_hp > 0 else 0.0
					var morale_loss = damage_ratio * 20.0
					warrior.modify_morale(-morale_loss)
					result.injuries.append(warrior_id)
					result.morale_changes[warrior_id] = - morale_loss
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
				warrior.get_stat(StatName.I.MORALE).stat_value = 0.0
				if not result.deaths.has(warrior_id):
					result.deaths.append(warrior_id)
			SquadBattleTypes.EntityChangeable.CAPITULATE:
				warrior.is_injured = true
				if not result.escaped.has(warrior_id):
					result.escaped.append(warrior_id)

	for warrior in strategic_squad.warriors:
		if warrior.combat != null:
			warrior.exit_battle()

	strategic_squad.update_aggregate_morale()
	strategic_squad.remove_dead_warriors()

	return result


func get_warrior_for_entity(entity_id: int) -> String:
	if entity_to_warrior.has(entity_id):
		return entity_to_warrior[entity_id]
	return ""


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
		"player_strength": current_battle.check_team_strength(SquadBattleTypes.Side.ATTACKER),
		"enemy_strength": current_battle.check_team_strength(SquadBattleTypes.Side.DEFENDER),
		"round_count": current_battle.round_count,
		"tactic": current_tactic.tactic_name if current_tactic else "None",
	}
