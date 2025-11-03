class_name Squad extends RefCounted

# const SBLog = preload("res://src/utils/SBLog.gd")

var team: String = ""
var entities: Array = []
var squad_name: String
var last_round_received_attack: int = -1

func _init(config: Dictionary):
	var entity_configs = config.get("entities", [])
	
	for entity_config in entity_configs:
		var entity = SquadEntity.new(entity_config)
		var logic_type = entity_config.get("logic_type", "default")
		
		var logic
		match logic_type:
			"frontline":
				logic = SquadLogic.FrontlineLogic.new({"entity": entity, "our_squad": {}, "enemy_squad": {}})
			"archer":
				logic = SquadLogic.ArcherLogic.new({"entity": entity, "our_squad": {}, "enemy_squad": {}})
			"absurd":
				logic = SquadLogic.AbsurdLogic.new({"entity": entity, "our_squad": {}, "enemy_squad": {}})
			"adjust_weapon":
				logic = SquadLogic.AdjustWeaponTestLogic.new({"entity": entity, "our_squad": {}, "enemy_squad": {}})
			_:
				logic = SquadLogic.new({"entity": entity, "our_squad": {}, "enemy_squad": {}})
		
		entity.set_logic(logic)
		entities.append(entity)
	
	squad_name = config.get("name", "Unnamed Squad")
	team = config.get("team", "")

func is_crippled() -> bool:
	return entities.size() == 0

func get_all_entities() -> Dictionary:
	var result = {}
	
	for entity in entities:
		var loc = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
		
		if not result.has(loc):
			result[loc] = []
		result[loc].append(entity)
	
	return result

func recovery():
	SBLog.line(3, "offered a recovery", SBLog.prefix(self, squad_name))
	for entity in entities:
		entity.recover()

func get_last_attacked_at_round() -> int:
	return last_round_received_attack

func squad_attack(enemy_squad: Squad, round_count: int) -> Array[EntityUpdate]:
	SBLog.line(4, "⚔️ [%s]" % enemy_squad.squad_name, SBLog.prefix(self, squad_name))
	var updates_after_attack: Array[EntityUpdate] = []
	
	last_round_received_attack = round_count
	
	var our_squad_metadata = get_all_entities()
	var enemy_squad_metadata = enemy_squad.get_all_entities()
	
	for our_entity in entities:
		var action_results = our_entity.action(our_squad_metadata, enemy_squad_metadata)
		for result in action_results:
			updates_after_attack.append(result)
	
	for enemy_entity in enemy_squad.entities:
		var reaction_results = enemy_entity.reaction(enemy_squad_metadata, our_squad_metadata)
		for result in reaction_results:
			updates_after_attack.append(result)
	
	return updates_after_attack

func choose_enemy_squad(enemy_squads: Array):
	if enemy_squads.size() > 0:
		return enemy_squads[randi() % enemy_squads.size()]
	return null

func act_attack_random(targetable_squads: Array, round_count: int):
	SBLog.line(3, "attacking random enemy", SBLog.prefix(self, squad_name))
	var enemy_squad = choose_enemy_squad(targetable_squads)
	
	if enemy_squad:
		return squad_attack(enemy_squad, round_count)
	return null

func act_idle():
	SBLog.line(3, "idling", SBLog.prefix(self, squad_name))
	return null

func round(enemy_squads: Array, round_count: int) -> Array[EntityUpdate]:
	SBLog.section("%s" % squad_name, 2, 1, 0)
	
	for entity in entities:
		entity.new_round_reset()
	
	var result = act_attack_random(enemy_squads, round_count)
	if result:
		return result
	return []
