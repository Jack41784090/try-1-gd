class_name SquadCombatData
extends Resource

var entities: Array[CharacterCombatStats] = []
var squad_name: String = ""
var last_round_received_attack: int = -1


func _init(config: Dictionary = { }):
	squad_name = config.get("name", "")
	var entity_configs = config.get("entities", [])
	var next_player_id = randi() % 1000 + 1

	for entity_config in entity_configs:
		var entity: CharacterCombatStats
		if entity_config is EntityClasses.Types:
			entity = EntityFactory.get_entity(entity_config)
			entity.init_from_resource()
			entity.set_player_id(next_player_id)
			next_player_id += 1
		elif entity_config is EntityConfig:
			entity = CharacterCombatStats.new(entity_config)
		elif entity_config is CharacterCombatStats:
			entity = entity_config
			entity.set_player_id(next_player_id)
			next_player_id += 1
		else:
			push_error("Invalid entity config: %s" % [entity_config, entity_config.get_class()])
			continue

		entity.side = config.get("side")
		assert(entity.side != null)
		entities.append(entity)


func is_crippled() -> bool:
	return entities.size() == 0


func get_all_entities() -> Dictionary:
	var result = { }

	for entity in entities:
		if entity.is_dead():
			continue

		var loc = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int

		if not result.has(loc):
			result[loc] = []
		result[loc].append(entity)

	return result


func recovery():
	SBLog.line(3, "offered a recovery", SBLog.prefix(self))
	for entity in entities:
		entity.recover()


func get_last_attacked_at_round() -> int:
	return last_round_received_attack


func _format_enemy_positions(metadata: Dictionary) -> String:
	var parts = []
	for loc in [1, 2, 3]:
		if metadata.has(loc):
			var names = []
			for e in metadata[loc]:
				names.append("%s(ID:%d,HP:%.0f)" % [e.entity_name, e.player_id, e.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)])
			parts.append("LOC%d:[%s]" % [loc, ", ".join(names)])
	return "{%s}" % " ".join(parts)


func squad_attack(enemy_squad: SquadCombatData, round_count: int) -> Array[EntityUpdate]:
	SBLog.line(4, "⚔️ [%s]" % enemy_squad.squad_name, SBLog.prefix(self))
	var updates_after_attack: Array[EntityUpdate] = []

	last_round_received_attack = round_count

	for our_entity in entities:
		var our_squad_metadata = get_all_entities()
		var enemy_squad_metadata = enemy_squad.get_all_entities()

		SBLog.line(5, "Entity [%s] acting. Enemy positions: %s" % [our_entity.entity_name, _format_enemy_positions(enemy_squad_metadata)])

		var action_results = our_entity.action(our_squad_metadata, enemy_squad_metadata)
		for result in action_results:
			updates_after_attack.append(result)

	SBLog.line(4, "↻ Refreshing positions after actions, before reactions", SBLog.prefix(self))

	for enemy_entity in enemy_squad.entities:
		var our_squad_metadata = get_all_entities()
		var enemy_squad_metadata = enemy_squad.get_all_entities()
		var reaction_results = enemy_entity.reaction(enemy_squad_metadata, our_squad_metadata)
		for result in reaction_results:
			updates_after_attack.append(result)

	return updates_after_attack


func perform_actions(enemy_squads: Array, round_count: int, action_count: int, _attack_modifier: float) -> Array[EntityUpdate]:
	var updates: Array[EntityUpdate] = []

	if action_count <= 0:
		SBLog.line(3, "No actions available this round (tactic: 0 actions)", SBLog.prefix(self))
		return updates

	SBLog.line(3, "Performing %d action(s)" % action_count, SBLog.prefix(self))

	for entity in entities:
		entity.new_round_reset()

	# Each entity gets to act up to action_count times
	for action_num in range(action_count):
		SBLog.line(4, "Action %d/%d" % [action_num + 1, action_count], SBLog.prefix(self))

		var enemy_squad = choose_enemy_squad(enemy_squads)
		if not enemy_squad:
			SBLog.line(4, "No enemy squad available to attack", SBLog.prefix(self))
			break

		last_round_received_attack = round_count

		for our_entity in entities:
			if our_entity.is_dead():
				continue

			var our_squad_metadata = get_all_entities()
			var enemy_squad_metadata = enemy_squad.get_all_entities()

			SBLog.line(
				5,
				"Entity [%s] action %d. Enemy positions: %s" % [
					our_entity.entity_name,
					action_num + 1,
					_format_enemy_positions(enemy_squad_metadata),
				],
			)

			var action_results = our_entity.action(our_squad_metadata, enemy_squad_metadata)
			for result in action_results:
				updates.append(result)

	return updates


func perform_reactions(enemy_squads: Array, _round_count: int, reaction_count: int, _defense_modifier: float) -> Array[EntityUpdate]:
	var updates: Array[EntityUpdate] = []

	if reaction_count <= 0:
		SBLog.line(3, "No reactions available this round (tactic: 0 reactions)", SBLog.prefix(self))
		return updates

	SBLog.line(3, "Performing %d reaction(s)" % reaction_count, SBLog.prefix(self))

	# Each entity gets to react up to reaction_count times
	for reaction_num in range(reaction_count):
		SBLog.line(4, "Reaction %d/%d" % [reaction_num + 1, reaction_count], SBLog.prefix(self))

		var enemy_squad = choose_enemy_squad(enemy_squads)
		if not enemy_squad:
			SBLog.line(4, "No enemy squad to react against", SBLog.prefix(self))
			break

		for our_entity in entities:
			if our_entity.is_dead():
				continue

			var our_squad_metadata = get_all_entities()
			var enemy_squad_metadata = enemy_squad.get_all_entities()

			SBLog.line(
				5,
				"Entity [%s] reaction %d. Enemy positions: %s" % [
					our_entity.entity_name,
					reaction_num + 1,
					_format_enemy_positions(enemy_squad_metadata),
				],
			)

			var reaction_results = our_entity.reaction(our_squad_metadata, enemy_squad_metadata)
			for result in reaction_results:
				updates.append(result)

	return updates


func choose_enemy_squad(enemy_squads: Array):
	if enemy_squads.size() > 0:
		return enemy_squads[randi() % enemy_squads.size()]
	return null


func act_attack_random(targetable_squads: Array, round_count: int):
	SBLog.line(3, "attacking random enemy", SBLog.prefix(self))
	var enemy_squad = choose_enemy_squad(targetable_squads)

	if enemy_squad:
		return squad_attack(enemy_squad, round_count)
	return null


func act_idle():
	SBLog.line(3, "idling", SBLog.prefix(self))
	return null


func round(enemy_squads: Array, round_count: int) -> Array[EntityUpdate]:
	SBLog.section("SQUAD ROUND", 2, 1, 0)

	for entity in entities:
		entity.new_round_reset()

	var result = act_attack_random(enemy_squads, round_count)
	if result:
		return result
	return []
