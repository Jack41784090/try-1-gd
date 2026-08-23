class_name SquadBattle
extends Resource

signal battle_completed(outcome: SquadBattleTypes.BattleOutcome)

var side_squads_dict: Dictionary[SquadBattleTypes.Side, Array] = {}
var team_names: Array[Variant]
var round_count: int = -1

var attacker_tactic: Tactic = null
var defender_tactic: Tactic = null

var max_rounds: int = 3
var retreating_team: Variant = null

var _outcome_notified: bool = false

func _init(teams: Dictionary[SquadBattleTypes.Side, Array], _attacker_tactic: Tactic, _defender_tactic: Tactic):
	attacker_tactic = _attacker_tactic
	defender_tactic = _defender_tactic

	max_rounds = attacker_tactic.action_count

	for side in teams:
		assert(side != SquadBattleTypes.Side.NULL)

		var squad_config_tuples := teams[side]
		
		side_squads_dict.set(side, squad_config_tuples.map(func(squad_config_tuple):
			assert(squad_config_tuple.size() == 3)
			assert(squad_config_tuple[0] is String)
			assert(squad_config_tuple[1] is SquadBattleTypes.Side)
			assert(squad_config_tuple[2] is Array)
			return CombatSquad.new(
				squad_config_tuple[0],
				squad_config_tuple[1],
				squad_config_tuple[2],
			)
		))

		team_names.append(side)


func get_entity_by_id(entity_id: int) -> CombatEntity:
	for team_name in side_squads_dict:
		var squads = side_squads_dict[team_name]
		for squad in squads:
			for entity in squad.entities:
				if entity.player_id == entity_id:
					return entity

	MyLog.error("SquadBattle", "Entity with ID %d not found!" % entity_id)
	return null


func check_team_strength(team_name: Variant) -> float:
	var strength = 0.0

	if side_squads_dict.has(team_name):
		for squad in side_squads_dict[team_name]:
			for entity in squad.entities:
				strength += entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)

	return strength


func get_battle_outcome() -> SquadBattleTypes.BattleOutcome:
	var attacker_strength = check_team_strength(SquadBattleTypes.Side.ATTACKER)
	var defender_strength = check_team_strength(SquadBattleTypes.Side.DEFENDER)

	if attacker_strength <= 0:
		return SquadBattleTypes.BattleOutcome.DEFENDER_VICTORY
	if defender_strength <= 0:
		return SquadBattleTypes.BattleOutcome.ATTACKER_VICTORY

	if round_count >= max_rounds:
		return SquadBattleTypes.BattleOutcome.DRAW

	return SquadBattleTypes.BattleOutcome.ONGOING

## Emits [signal battle_completed] exactly once, on the ONGOING → terminal transition.
func evaluate_outcome() -> SquadBattleTypes.BattleOutcome:
	var outcome = get_battle_outcome()
	if outcome != SquadBattleTypes.BattleOutcome.ONGOING and not _outcome_notified:
		_outcome_notified = true
		battle_completed.emit(outcome)
	return outcome


func order_retreat(team: SquadBattleTypes.Side) -> void:
	retreating_team = team


func _determine_actions(side: SquadBattleTypes.Side) -> Array[EntityUpdate]:
	var side_label := "Attacker" if side == SquadBattleTypes.Side.ATTACKER else "Defender"
	var tactic: Tactic = attacker_tactic if side == SquadBattleTypes.Side.ATTACKER else defender_tactic

	if retreating_team == side:
		SBLog.section("Round %d/%d - %s Retreating" % [round_count, max_rounds, side_label], 2, 1, 0)
		var retreat_updates: Array[EntityUpdate] = []
		var retreat_squads: Array = side_squads_dict.get(side, [])
		for squad in retreat_squads:
			for entity in squad.entities:
				if entity.is_dead():
					continue
				for u in entity.retreat_tracker.advance(entity):
					retreat_updates.append(u)
		return retreat_updates

	SBLog.section("Round %d/%d - %s Phase" % [round_count, max_rounds, side_label], 2, 1, 0)

	var enemy_side := SquadBattleTypes.Side.DEFENDER if side == SquadBattleTypes.Side.ATTACKER else SquadBattleTypes.Side.ATTACKER
	var performing_squads: Array[CombatSquad] = []
	for s in side_squads_dict.get(side, []):
		performing_squads.append(s)
	var enemy_squads: Array[CombatSquad] = []
	for s in side_squads_dict.get(enemy_side, []):
		enemy_squads.append(s)

	var updates: Array[EntityUpdate] = []
	for squad in performing_squads:
		var squad_updates = squad.perform_actions(
			enemy_squads,
			round_count,
			tactic.action_count,
			tactic.attack_modifier,
		)
		for update in squad_updates:
			updates.append(update)
	return updates


func advance_round() -> Array[EntityUpdate]:
	round_count += 1
	var updates: Array[EntityUpdate] = []

	for team_name in side_squads_dict:
		var squads = side_squads_dict[team_name]
		for squad in squads:
			if squad.get_last_attacked_at_round() < round_count:
				for entity in squad.entities:
					for change in entity.recover():
						updates.append(EntityUpdate.new(entity.player_id, entity.player_id, change))

	updates.append_array(_determine_actions(SquadBattleTypes.Side.ATTACKER))
	updates.append_array(_determine_actions(SquadBattleTypes.Side.DEFENDER))

	for team_name in side_squads_dict:
		for squad in side_squads_dict[team_name]:
			for entity in squad.entities:
				if entity.is_dead():
					continue
				var expired: Array[StatusEffect] = []
				for se in entity.status_effects:
					if se.tick():
						expired.append(se)
				for se in expired:
					entity.status_effects.erase(se)

	var capitulated: Array[CombatEntity] = []
	for update in updates:
		if update.change.property == SquadBattleTypes.EntityChangeable.CAPITULATE:
			var entity = get_entity_by_id(update.affected)
			if entity:
				capitulated.append(entity)

	for team_name in side_squads_dict:
		var squads = side_squads_dict[team_name]
		for squad in squads:
			var entities_to_remove: Array[int] = []
			for i in range(squad.entities.size()):
				if squad.entities[i].get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) == 0:
					entities_to_remove.append(i)
			for i in range(entities_to_remove.size() - 1, -1, -1):
				squad.entities.remove_at(entities_to_remove[i])

	for cap_entity in capitulated:
		for team_name in side_squads_dict:
			var squads = side_squads_dict[team_name]
			for squad in squads:
				var cap_entities_to_remove: Array[int] = []
				for i in range(squad.entities.size()):
					if squad.entities[i].player_id == cap_entity.player_id:
						cap_entities_to_remove.append(i)
						MyLog.warn("SquadBattle", "Entity %d has capitulated and left the battle!" % squad.entities[i].player_id)
				for i in range(cap_entities_to_remove.size() - 1, -1, -1):
					squad.entities.remove_at(cap_entities_to_remove[i])

	var outcome = get_battle_outcome()
	MyLog.debug("SquadBattle", "Round %d: %s (attacker HP %d, defender HP %d)" % [round_count, SquadBattleTypes.BattleOutcome.keys()[outcome], check_team_strength(SquadBattleTypes.Side.ATTACKER), check_team_strength(SquadBattleTypes.Side.DEFENDER)])
	return updates


func run_headless() -> Array[EntityUpdate]:
	var all_updates: Array[EntityUpdate] = []

	MyLog.info("SquadBattle", "Starting headless simulation — attacker '%s' (actions=%d, rounds=%d), defender '%s' (reactions=%d)" % [attacker_tactic.tactic_name, attacker_tactic.action_count, max_rounds, defender_tactic.tactic_name, defender_tactic.reaction_count])

	round_count = 0

	while get_battle_outcome() == SquadBattleTypes.BattleOutcome.ONGOING and round_count < max_rounds:
		MyLog.debug("SquadBattle", "=== Round %d/%d ===" % [round_count + 1, max_rounds])
		all_updates.append_array(advance_round())

	var final_outcome = get_battle_outcome()
	MyLog.info("SquadBattle", "Battle complete after %d round(s): %s" % [round_count, SquadBattleTypes.BattleOutcome.keys()[final_outcome]])

	return all_updates
