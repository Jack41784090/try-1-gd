class_name CombatEntity
extends Resource

var _debug_id := "Entity_script_unknown"
var resource: CombatEntityResource
var display_name: String

## Only set this when the template's own logic is determined insufficient.
var _logic_override: SimplifiedSquadLogic
var weapon: Weapon
var armor: SquadArmor:
	set(_a):
		armor = _a
		_a.set_defender(self)

var side: SquadBattleTypes.Side
var player_id: int
var team: String

var rs_arr: Dictionary[StatName.I, ReactiveStat] = {}

var retreat_tracker: RetreatTracker = null

var skill_set: SkillSet
var temporary_skills: Array[Skill]
var status_effects: Array[StatusEffect]
var reactions: Array[ReactionSkill] = []


func _init(config: CombatEntityConfig) -> void:
	resource = config.resource
	display_name = resource.codename
	weapon = Weapon.new(resource.weapon_class)
	armor = SquadArmor.new(resource.armor_class)
	side = config.side
	player_id = config.player_id
	skill_set = SkillSet.new()
	_logic_override = SimplifiedSquadLogic.new(
		{
			"entity": self,
			"our_squad": {},
			"enemy_squad": {},
		},
		resource.logic_config,
		resource.personal_rules,
	)
	
	
	var rebuilt: Dictionary[StatName.I, ReactiveStat] = {}
	for key in config.resolved_constants:
		var rs := ReactiveStat.new()
		rs.stat_name = key
		rs.stat_value = config.resolved_constants[key]
		rebuilt[key] = rs
	rs_arr = rebuilt
	
	_debug_id = "[%d]" % [player_id]
	retreat_tracker = RetreatTracker.new()
	_build_runtime_stat(StatName.I.HP, get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP))
	_build_runtime_stat(StatName.I.STA, get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.STA))
	_build_runtime_stat(StatName.I.ORG, get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.ORG))
	_build_runtime_stat(StatName.I.POS, get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.POS))
	_build_runtime_stat(StatName.I.MAG, get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.MAG))
	_build_runtime_stat(StatName.I.LOC, float(config.starting_location))
	assert(side != SquadBattleTypes.Side.NULL, "Side must not be NULL")



func _build_runtime_stat(key: StatName.I, value: float) -> void:
	var rs := ReactiveStat.new()
	rs.stat_name = key
	rs.stat_value = value
	rs_arr[key] = rs


func get_stat(key: StatName.I) -> ReactiveStat:
	return rs_arr.get(key)


func get_stat_value(key: StatName.I) -> Variant:
	var s := get_stat(key)
	return s.stat_value if s else null


func new_round_reset() -> void:
	retreat_tracker.new_round_reset()


func is_dead() -> bool:
	return get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) <= 0


func get_armour():
	return armor


func calculate_reality_value(reality: SquadBattleTypes.Reality) -> float:
	var calculation := RealityCalculationFactory.table.get_calculation(reality)
	assert(calculation != null, "[%s] Reality value for %s not found" % [_debug_id, reality])
	return calculation.evaluate(self)


func get_ceiling_changeable_stat(property: SquadBattleTypes.EntityChangeable) -> float:
	match property:
		SquadBattleTypes.EntityChangeable.HP:
			return calculate_reality_value(SquadBattleTypes.Reality.HP)
		SquadBattleTypes.EntityChangeable.ORG:
			return calculate_reality_value(SquadBattleTypes.Reality.Guts)
		SquadBattleTypes.EntityChangeable.LOC:
			return float(SquadBattleTypes.SquadEntityInSquadLocation.Back)
		_:
			return 100.0


func _statname_for(property: SquadBattleTypes.EntityChangeable) -> StatName.I:
	match property:
		SquadBattleTypes.EntityChangeable.HP:
			return StatName.I.HP
		SquadBattleTypes.EntityChangeable.STA:
			return StatName.I.STA
		SquadBattleTypes.EntityChangeable.ORG:
			return StatName.I.ORG
		SquadBattleTypes.EntityChangeable.POS:
			return StatName.I.POS
		SquadBattleTypes.EntityChangeable.MAG:
			return StatName.I.MAG
		SquadBattleTypes.EntityChangeable.LOC:
			return StatName.I.LOC
		_:
			assert(false, "No StatName mapping for %s" % property)
			return StatName.I.HP


func get_changeable_stat_num(property: SquadBattleTypes.EntityChangeable) -> float:
	return get_stat_value(_statname_for(property))


func set_changeable_stat(property: SquadBattleTypes.EntityChangeable, to: float, p_metadata: Dictionary = {}) -> EntityChange:
	var key := _statname_for(property)
	var old_value: float = get_stat_value(key)
	var floor_val: float
	match property:
		SquadBattleTypes.EntityChangeable.LOC:
			floor_val = float(SquadBattleTypes.SquadEntityInSquadLocation.Front)
		_:
			floor_val = 0.0
	var new_value: float = clamp(to, floor_val, get_ceiling_changeable_stat(property))
	get_stat(key).stat_value = new_value
	return EntityChange.new(property, old_value, new_value, p_metadata)


func mod_changeable_stat(property: SquadBattleTypes.EntityChangeable, by: float, p_metadata: Dictionary = {}) -> EntityChange:
	return set_changeable_stat(property, get_changeable_stat_num(property) + by, p_metadata)


func heal(num: float, p_metadata: Dictionary = {}) -> EntityChange:
	if num < 0 or is_dead():
		return null
	return mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, num, p_metadata)


func recover() -> Array[EntityChange]:
	if is_dead():
		return []
	var recover_changes: Array[EntityChange] = [
		mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, 3),
		mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, 5),
	]
	return recover_changes


func damage(num: float, source: int, p_metadata: Dictionary = {}) -> Array[EntityUpdate]:
	if is_dead():
		return []

	var old_hp = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var affected = player_id

	if num <= 0:
		return [EntityUpdate.new(source, affected, EntityChange.new(SquadBattleTypes.EntityChangeable.HP, old_hp, old_hp, p_metadata))]

	var updates: Array[EntityUpdate] = [
		EntityUpdate.new(
			source, affected,
			mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, -num, p_metadata)),
	]

	if get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) == 0:
		updates.append(
			EntityUpdate.new(
				source, affected,
				EntityChange.new(SquadBattleTypes.EntityChangeable.DIE, -1, -1, p_metadata)))
	else:
		if num > 0 and not is_dead():
			var affected_deorg = player_id
			var base_damage_deorg = -(num * 1.5)
			var current_hp = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
			var max_hp = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
			var hp_percentage = current_hp / max_hp
			var close_to_death_deorg = -((1.0 - hp_percentage) * 10)
			updates.append(
				EntityUpdate.new(source, affected_deorg, mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, base_damage_deorg + close_to_death_deorg)))

	return updates


func action(our_squad: Dictionary, enemy_squad: Dictionary) -> Array[EntityUpdate]:
	if is_dead():
		return []

	var updates: Array[EntityUpdate] = []
	var updated_logic = _logic_override.update_situation(
		{
			"entity": self,
			"our_squad": our_squad,
			"enemy_squad": enemy_squad,
		},
	)

	var chosen_skill = updated_logic.choose_skill()

	if chosen_skill:
		var target = chosen_skill.targeting_consideration.score_then_return(self, updated_logic.situation, updated_logic.context)
		assert(target is CombatEntity or target == null)
		if target != null:
			var all_entities: Array[CombatEntity] = []
			for loc_entities in updated_logic.context.get("our_squad", {}).values():
				for e in loc_entities:
					all_entities.append(e)
			for loc_entities in updated_logic.context.get("enemy_squad", {}).values():
				for e in loc_entities:
					all_entities.append(e)
			var intent := ClashIntent.new(self, chosen_skill, target, 0, null, updated_logic.situation)
			var resolver := ClashResolver.new()
			resolver.set_entities(all_entities)
			var skill_result = resolver.resolve(intent)
			for eu in skill_result:
				updates.append(eu)
		else:
			MyLog.debug("Combat", "%s/%s: no valid target for '%s'" % [_debug_id, display_name, chosen_skill.name])
	else:
		for c in recover():
			updates.append(EntityUpdate.new(player_id, player_id, c))

	return updates
