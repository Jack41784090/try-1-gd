class_name SquadBattle
extends Resource

signal battle_completed(outcome: SquadBattleTypes.BattleOutcome)

var side_squads_dict: Dictionary[SquadBattleTypes.Side, Array] = {}
var team_names: Array[Variant]
var round_count: int = -1

# Tactic configuration for battle flow
var attacker_tactic: Tactic = null
var defender_tactic: Tactic = null

# Max rounds is determined by attacker's tactic action_count
var max_rounds: int = 3
var retreating_team: Variant = null

var _outcome_notified: bool = false

func _init(teams: Dictionary[SquadBattleTypes.Side, Array], _attacker_tactic: Tactic, _defender_tactic: Tactic):
	# Initializes a squad battle from a config dict containing teams and tactics
	# e.g., config = { teams: {ATTACKER: [squad_config], DEFENDER: [squad_config]}, attacker_tactic: Aggressive, ... }
	#   → creates CombatSquad for each squad, stores in side_squads_dict["player"] and ["enemy"]
	#   → max_rounds = attacker_tactic.action_count (e.g., Aggressive → 4 rounds)
	# var teams = config.get("teams", {})
	# Store tactics if provided
	attacker_tactic = _attacker_tactic
	defender_tactic = _defender_tactic

	# Max rounds comes from attacker's action_count
	max_rounds = attacker_tactic.action_count

	for side in teams:
		assert(side != SquadBattleTypes.Side.NULL)

		var squad_config_tuples := teams[side]
		
		side_squads_dict.set(side, squad_config_tuples.map(func(squad_config_tuple):
			assert(squad_config_tuple.size() == 3)
			assert(squad_config_tuple[0] is String) 	# name
			assert(squad_config_tuple[1] is SquadBattleTypes.Side) 	# side
			assert(squad_config_tuple[2] is Array) 	# entities
			return CombatSquad.new(
				squad_config_tuple[0], 	# name
				squad_config_tuple[1], 	# side
				squad_config_tuple[2], 	# entities
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

	Log.error("SquadBattle", "Entity with ID %d not found!" % entity_id)
	return null


func remove_capitulated_entities(capitulated_entities: Array[CombatEntity]) -> void:
	for entity in capitulated_entities:
		for team_name in side_squads_dict:
			var squads = side_squads_dict[team_name]
			for squad in squads:
				var entities_to_remove = []
				for i in range(squad.entities.size()):
					if squad.entities[i].player_id == entity.player_id:
						entities_to_remove.append(i)
						Log.warn("SquadBattle", "Entity %d has capitulated and left the battle!" % squad.entities[i].player_id)

				for i in range(entities_to_remove.size() - 1, -1, -1):
					squad.entities.remove_at(entities_to_remove[i])


func get_all_enemy_squads(current_team_name: Variant) -> Array[CombatSquad]:
	var enemy_squads: Array[CombatSquad] = []

	for team_name in team_names:
		if team_name != current_team_name:
			for squad in side_squads_dict[team_name]:
				enemy_squads.append(squad)

	return enemy_squads


func choose_weighted_enemy_squad(current_team_name: String) -> CombatSquad:
	var enemy_squads = get_all_enemy_squads(current_team_name)
	var result: CombatSquad = null

	if enemy_squads.size() > 0:
		var weights: Array[float] = []
		for squad in enemy_squads:
			var total_hp = 0.0
			for entity in squad.entities:
				total_hp += entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)

			var avg_hp = total_hp / max(squad.entities.size(), 1)
			weights.append(max(1, 100 - avg_hp))

		var total_weight = 0.0
		for weight in weights:
			total_weight += weight

		var random_value = randf() * total_weight
		var current_weight = 0.0
		var selected_squad: CombatSquad = null

		for i in range(enemy_squads.size()):
			current_weight += weights[i]
			if random_value < current_weight and not selected_squad:
				selected_squad = enemy_squads[i]

		result = selected_squad if selected_squad else enemy_squads[enemy_squads.size() - 1]

	return result


func check_team_strength(team_name: Variant) -> float:
	var strength = 0.0

	if side_squads_dict.has(team_name):
		for squad in side_squads_dict[team_name]:
			for entity in squad.entities:
				strength += entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)

	return strength


func check_victory() -> bool:
	return get_battle_outcome() != SquadBattleTypes.BattleOutcome.ONGOING


func get_battle_outcome() -> SquadBattleTypes.BattleOutcome:
	# Checks current battle state by comparing team strengths (total HP)
	# Returns: ATTACKER_VICTORY if defender HP=0, DEFENDER_VICTORY if attacker HP=0,
	#          DRAW if round_count >= max_rounds, ONGOING otherwise
	# e.g., attacker_strength=150, defender_strength=0 → ATTACKER_VICTORY
	# e.g., round_count=4, max_rounds=4, both alive → DRAW
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

## Same query as [method get_battle_outcome], but emits [signal battle_completed]
## exactly once on the ONGOING → terminal transition.
func evaluate_outcome() -> SquadBattleTypes.BattleOutcome:
	var outcome = get_battle_outcome()
	if outcome != SquadBattleTypes.BattleOutcome.ONGOING and not _outcome_notified:
		_outcome_notified = true
		battle_completed.emit(outcome)
	return outcome


func squad_recoveries() -> void:
	# Between rounds, squads that weren't attacked last round recover some stats
	# e.g., squad "enemy" last_attacked_at=2, round_count=4 → recovery() restores some STA/ORG
	for team_name in side_squads_dict:
		var squads = side_squads_dict[team_name]
		for squad in squads:
			if squad.get_last_attacked_at_round() < round_count:
				squad.recovery()


func order_retreat(team: SquadBattleTypes.Side) -> void:
	retreating_team = team


func _produce_retreat_updates(team_side) -> Array[EntityUpdate]:
	var updates: Array[EntityUpdate] = []
	var squads: Array = side_squads_dict.get(team_side, [])
	for squad in squads:
		for entity in squad.entities:
			if entity.is_dead():
				continue
			for u in entity.retreat_tracker.advance(entity):
				updates.append(u)
	return updates

func _determine_actions(side: SquadBattleTypes.Side) -> Array[EntityUpdate]:
	if retreating_team == side:
		SBLog.section("Round %d/%d - Attacker Retreating" % [round_count, max_rounds], 2, 1, 0)
		return _produce_retreat_updates(side)
	else:
		SBLog.section("Round %d/%d - Attacker Phase" % [round_count, max_rounds], 2, 1, 0)
		var attacker_squads: Array = side_squads_dict.get(SquadBattleTypes.Side.ATTACKER, [])
		var defender_squads: Array = side_squads_dict.get(SquadBattleTypes.Side.DEFENDER, [])
		var performing_squad = attacker_squads if side == SquadBattleTypes.Side.ATTACKER else  defender_squads
		var updates = []
		for squad in performing_squad:
			var squad_updates = squad.perform_actions(
				defender_squads,
				round_count,
				1,
				attacker_tactic.attack_modifier,
			)
			for update in squad_updates:
				updates.append(update)
		return updates

func squad_actions() -> Array[EntityUpdate]:
	var updates: Array[EntityUpdate] = []
	updates.append_array(_determine_actions(SquadBattleTypes.Side.ATTACKER))
	updates.append_array(_determine_actions(SquadBattleTypes.Side.DEFENDER))
	return updates


func remove_dead_entities() -> void:
	for team_name in side_squads_dict:
		var squads = side_squads_dict[team_name]
		for squad in squads:
			var entities_to_remove = []
			for i in range(squad.entities.size()):
				if squad.entities[i].get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) == 0:
					entities_to_remove.append(i)

			for i in range(entities_to_remove.size() - 1, -1, -1):
				squad.entities.remove_at(entities_to_remove[i])


## Run battle to completion without scene instantiation or visualization
## Returns all EntityUpdate objects collected across all rounds
## Used for AI vs AI combat resolution
func run_headless() -> Array[EntityUpdate]:
	# Runs the entire battle loop in one call — used for AI-vs-AI headless combat
	# Loop: squad_recoveries() → squad_actions() → remove_dead_entities() until victory or max rounds
	# e.g., 3-round battle: Round 1 (2 hits, 1 kill) → Round 2 (1 hit) → Round 3 (DRAW at max_rounds)
	#   → returns all ~8 EntityUpdate objects collected across all rounds
	var all_updates: Array[EntityUpdate] = []
	var headless_capitulated: Array[CombatEntity] = []

	Log.info("SquadBattle", "Starting headless simulation — attacker '%s' (actions=%d, rounds=%d), defender '%s' (reactions=%d)" % [attacker_tactic.tactic_name, attacker_tactic.action_count, max_rounds, defender_tactic.tactic_name, defender_tactic.reaction_count])

	round_count = 0

	while not check_victory() and round_count < max_rounds:
		round_count += 1
		Log.debug("SquadBattle", "=== Round %d/%d ===" % [round_count, max_rounds])
		squad_recoveries()
		var round_updates = squad_actions()
		for update in round_updates:
			all_updates.append(update)
			if update.change.property == SquadBattleTypes.EntityChangeable.CAPITULATE:
				var entity = get_entity_by_id(update.affected)
				if entity:
					headless_capitulated.append(entity)
		remove_dead_entities()
		remove_capitulated_entities(headless_capitulated)
		headless_capitulated.clear()
		var outcome = get_battle_outcome()
		Log.debug("SquadBattle", "Round %d: %s (attacker HP %d, defender HP %d)" % [round_count, SquadBattleTypes.BattleOutcome.keys()[outcome], check_team_strength(SquadBattleTypes.Side.ATTACKER), check_team_strength(SquadBattleTypes.Side.DEFENDER)])

	var final_outcome = get_battle_outcome()
	Log.info("SquadBattle", "Battle complete after %d round(s): %s" % [round_count, SquadBattleTypes.BattleOutcome.keys()[final_outcome]])

	return all_updates
