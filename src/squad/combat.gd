class_name CombatSquad
extends Resource

var entities: Array[CombatEntity] = []
var squad_name: String
var last_round_received_attack: int = -1

var _next_local_player_id: int = randi() % 1000 + 1


## config: { "name": String, "side": SquadBattleTypes.Side, "entities": Array }
## Each "entities" element is one of:
##  - String: a CombatEntityFactory identification, built fresh (demo/scripted squads)
##  - CombatEntityResource: built fresh via CombatEntityFactory.build_config_from_resource()
##  - CombatEntity: already fully built (the real CombatBridge route, via Character.enter_battle())
func _init(_name: String, _side: SquadBattleTypes.Side, _entities_config: Array[Variant]) -> void:
	squad_name = _name
	
	for entity_config in _entities_config:
		var entity := _build_entity(entity_config, _side)
		if entity != null:
			entities.append(entity)


func _build_entity(entity_config, side: SquadBattleTypes.Side) -> CombatEntity:
	if entity_config is CombatEntity:
		return entity_config

	if entity_config is String:
		var entity := CombatEntityFactory.get_by_identification(
			entity_config, side, _next_local_player_id, SquadBattleTypes.SquadEntityInSquadLocation.Front)
		_next_local_player_id += 1
		return entity

	if entity_config is CombatEntityResource:
		var built_config := CombatEntityFactory.build_config_from_resource(
			entity_config, side, _next_local_player_id, SquadBattleTypes.SquadEntityInSquadLocation.Front)
		_next_local_player_id += 1
		return CombatEntity.new(built_config)

	assert(false, "CombatSquad: invalid entity config %s" % str(entity_config))
	return null


func get_all_entities() -> Dictionary:
	var result = {}

	for entity in entities:
		if entity.is_dead():
			continue

		var loc = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int

		if not result.has(loc):
			result[loc] = []
		result[loc].append(entity)

	return result


func get_last_attacked_at_round() -> int:
	return last_round_received_attack


func perform_actions(enemy_squads: Array[CombatSquad], round_count: int, action_count: int, _attack_modifier: float) -> Array[EntityUpdate]:
	var updates: Array[EntityUpdate] = []

	if action_count <= 0:
		SBLog.line(3, "No actions available this round (tactic: 0 actions)", "[%s]" % squad_name)
		return updates

	SBLog.line(3, "Performing %d action(s)" % action_count, "[%s]" % squad_name)

	for entity in entities:
		entity.new_round_reset()

	for action_num in range(action_count):
		SBLog.line(4, "Action %d/%d" % [action_num + 1, action_count], "[%s]" % squad_name)

		var enemy_squad: CombatSquad = null
		if enemy_squads.size() > 0:
			enemy_squad = enemy_squads[randi() % enemy_squads.size()]
		if not enemy_squad:
			SBLog.line(4, "No enemy squad available to attack", "[%s]" % squad_name)
			break

		last_round_received_attack = round_count

		for our_entity in entities:
			if our_entity.is_dead():
				continue

			var our_squad_metadata = get_all_entities()
			var enemy_squad_metadata = enemy_squad.get_all_entities()

			var action_results = our_entity.action(our_squad_metadata, enemy_squad_metadata)
			for result in action_results:
				updates.append(result)

	return updates
