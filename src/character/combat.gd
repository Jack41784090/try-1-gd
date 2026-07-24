class_name CombatEntity
extends RefCounted

var _debug_id := "Entity_script_unknown"
var resource: CombatEntityResource
var display_name: String

## !! Only set this when the template's logic is determined no sufficient
var _logic_override: SimplifiedSquadLogic
var weapon: Weapon
var armor: SquadArmor

var side: SquadBattleTypes.Side
var player_id: int
var team: String

var rs_arr: Dictionary[StatName.I, ReactiveStat] = {}

var retreat_tracker: RetreatTracker = null

var is_retreating: bool:
	get:
		return retreat_tracker != null and retreat_tracker.state != 0

var has_last_stand: bool:
	get:
		return retreat_tracker != null and (retreat_tracker.state == 2 or retreat_tracker.state == 3)

var skill_set: SkillSet
var temporary_skills: Array[Skill]
var status_effects: Array[StatusEffect]


func _init(config: CombatEntityConfig) -> void:
	resource = config.resource
	display_name = resource.codename
	weapon = Weapon.new(resource.weapon_class)
	armor = SquadArmor.new(resource.armor_class)
	armor.set_defender(self)
	side = config.side
	player_id = config.player_id
	skill_set = SkillSet.new()
	_seed_constants(config.resolved_constants)
	init_after(config.starting_location)
	_validate_existence()


## Receives already-resolved constant values (from Character.enter_battle(), or
## CombatEntityFactory's template-only path). Never reads resource.rs_array directly.
func _seed_constants(resolved: Dictionary[StatName.I, Variant]) -> void:
	var rebuilt: Dictionary[StatName.I, ReactiveStat] = {}
	for key in resolved:
		var rs := ReactiveStat.new()
		rs.stat_name = key
		rs.stat_value = resolved[key]
		rebuilt[key] = rs
	rs_arr = rebuilt


func init_after(starting_location: SquadBattleTypes.SquadEntityInSquadLocation) -> void:
	_debug_id = "[%d]" % [player_id]
	retreat_tracker = RetreatTracker.new()
	_build_runtime_stat(StatName.I.HP, get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP))
	_build_runtime_stat(StatName.I.STA, get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.STA))
	_build_runtime_stat(StatName.I.ORG, get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.ORG))
	_build_runtime_stat(StatName.I.POS, get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.POS))
	_build_runtime_stat(StatName.I.MAG, get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.MAG))
	_build_runtime_stat(StatName.I.LOC, float(starting_location))


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


func _validate_existence() -> void:
	assert(side != SquadBattleTypes.Side.NULL, "Side must not be NULL")


func set_logic(new_logic) -> void:
	_logic_override = new_logic


func new_round_reset() -> void:
	retreat_tracker.new_round_reset()


func is_dead() -> bool:
	return get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) <= 0


func get_armour():
	return armor


enum _RealityOp { ADD, MUL }

const _REALITY_TABLE: Dictionary = {
	SquadBattleTypes.Reality.HP: [3.0, _RealityOp.MUL, [[StatName.I.ENDURANCE, 5.0], [StatName.I.SIZ, 2.0]]],
	SquadBattleTypes.Reality.Force: [1.0, _RealityOp.MUL, [[StatName.I.STRENGTH, 2.0], [StatName.I.SPD, 1.0], [StatName.I.SIZ, 1.0]]],
	SquadBattleTypes.Reality.Guts: [10.0, _RealityOp.ADD, [[StatName.I.WIL, 8.0], [StatName.I.FAI, 5.0]]],
	SquadBattleTypes.Reality.Mana: [0.0, _RealityOp.ADD, [[StatName.I.INT_STAT, 3.0], [StatName.I.SPR, 2.0], [StatName.I.FAI, 1.0]]],
	SquadBattleTypes.Reality.Spirituality: [0.0, _RealityOp.ADD, [[StatName.I.SPR, 2.0], [StatName.I.FAI, 2.0], [StatName.I.WIL, 1.0]]],
	SquadBattleTypes.Reality.Divinity: [0.0, _RealityOp.ADD, [[StatName.I.FAI, 3.0], [StatName.I.WIL, 2.0], [StatName.I.CHA, 1.0]]],
	SquadBattleTypes.Reality.Precision: [0.0, _RealityOp.ADD, [[StatName.I.DEX, 2.0], [StatName.I.ACR, 1.0], [StatName.I.SPD, 1.0]]],
	SquadBattleTypes.Reality.Maneuver: [0.0, _RealityOp.ADD, [[StatName.I.ACR, 2.0], [StatName.I.SPD, 2.0], [StatName.I.DEX, 1.0]]],
	SquadBattleTypes.Reality.Convince: [0.0, _RealityOp.ADD, [[StatName.I.CHA, 2.0], [StatName.I.BEU, 1.0], [StatName.I.INT_STAT, 1.0]]],
	SquadBattleTypes.Reality.Bravery: [0.0, _RealityOp.ADD, [[StatName.I.WIL, 2.0], [StatName.I.ENDURANCE, 1.0], [StatName.I.FAI, 1.0]]],
}


func calculate_reality_value(reality: SquadBattleTypes.Reality) -> float:
	if not _REALITY_TABLE.has(reality):
		push_error("[%s] Reality value for %s not found" % [_debug_id, reality])
		return 0.0
	var entry: Array = _REALITY_TABLE[reality]
	var base: float = entry[0]
	var op: int = entry[1]
	var terms: Array = entry[2]
	if op == _RealityOp.MUL:
		var product: float = 1.0
		for term in terms:
			product *= get_stat_value(term[0]) * term[1]
		return base + product
	else:
		var total: float = base
		for term in terms:
			total += get_stat_value(term[0]) * term[1]
		return total


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


func get_floor_changeable_stat(property: SquadBattleTypes.EntityChangeable) -> float:
	match property:
		SquadBattleTypes.EntityChangeable.LOC:
			return float(SquadBattleTypes.SquadEntityInSquadLocation.Front)
		_:
			return 0.0


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


func set_changeable_stat(property: SquadBattleTypes.EntityChangeable, to: float) -> EntityChange:
	var key := _statname_for(property)
	var old_value: float = get_stat_value(key)
	var new_value: float = clamp(to, get_floor_changeable_stat(property), get_ceiling_changeable_stat(property))
	get_stat(key).stat_value = new_value
	return EntityChange.new(property, old_value, new_value)


func mod_changeable_stat(property: SquadBattleTypes.EntityChangeable, by: float) -> EntityChange:
	return set_changeable_stat(property, get_changeable_stat_num(property) + by)


func heal(num: float) -> EntityChange:
	if num < 0 or is_dead():
		return null
	return mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, num)


func boost(num: float) -> EntityChange:
	if num < 0 or is_dead():
		return null
	return mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, num)


func deorg_after_damage(dm: float, source: int) -> Array[EntityUpdate]:
	if dm <= 0:
		return []
	if is_dead():
		return []

	var affected = player_id
	var base_damage_deorg = -(dm * 1.5)
	var current_hp = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var max_hp = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	var hp_percentage = current_hp / max_hp
	var close_to_death_deorg = -((1.0 - hp_percentage) * 10)
	var changes: Array[EntityUpdate] = [
		EntityUpdate.new(source, affected, mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, base_damage_deorg + close_to_death_deorg)),
	]

	if retreat_tracker.should_retreat(get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)):
		for u in retreat_tracker.advance(self):
			changes.append(u)

	return changes


func recover() -> Array[EntityChange]:
	if is_dead():
		return []
	var recover_changes: Array[EntityChange] = [
		mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, 3),
		mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, 5),
	]
	return recover_changes


func damage(num: float, source: int) -> Array[EntityUpdate]:
	if is_dead():
		return []

	var old_hp = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var affected = player_id

	if num <= 0:
		return [EntityUpdate.new(source, affected, EntityChange.new(SquadBattleTypes.EntityChangeable.HP, old_hp, old_hp))]

	var updates: Array[EntityUpdate] = [
		EntityUpdate.new(
			source, affected,
			mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, -num)),
	]

	if get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) == 0:
		updates.append(
			EntityUpdate.new(
				source, affected,
				EntityChange.new(SquadBattleTypes.EntityChangeable.DIE)))
	else:
		for u in deorg_after_damage(num, source):
			updates.append(u)

	return updates


func action(our_squad: Dictionary, enemy_squad: Dictionary) -> Array:
	if is_dead():
		return []

	var updates: Array = []
	var updated_logic = _logic_override.update_situation(
		{
			"entity": self,
			"our_squad": our_squad,
			"enemy_squad": enemy_squad,
		},
	)

	var chosen_skill = updated_logic.choose_skill()

	if chosen_skill:
		var skill_result = execute_skill(chosen_skill, updated_logic)
		for eu in skill_result:
			updates.append(eu)
	else:
		for c in recover():
			updates.append(EntityUpdate.new(player_id, player_id, c))

	return updates


func reaction(our_squad: Dictionary, enemy_squad: Dictionary) -> Array:
	if is_dead():
		return []

	var updates: Array = []
	var updated_logic = _logic_override.update_situation(
		{
			"entity": self,
			"our_squad": our_squad,
			"enemy_squad": enemy_squad,
		},
	)

	var chosen_skill = updated_logic.choose_skill()

	if chosen_skill:
		var skill_result = execute_skill(chosen_skill, updated_logic)
		if skill_result:
			for eu in skill_result:
				updates.append(eu)
	else:
		Log.debug("Combat", "%s/%s: no skill, skipping reaction" % [_debug_id, display_name])

	return updates


func execute_skill(skill: Skill, logic_obj: SimplifiedSquadLogic) -> Array:
	if not skill:
		return []

	var updates: Array = []

	var clash = logic_obj.choose_clash_with_skill(skill)
	if clash == null:
		Log.debug("Combat", "%s/%s: no valid target for '%s'" % [_debug_id, display_name, skill.name])
		return []

	for u in clash.commit():
		updates.append(u)

	return updates


func add_temporary_skill(skill) -> void:
	temporary_skills.append(skill)


func remove_temporary_skill(skill_id: String) -> void:
	temporary_skills = temporary_skills.filter(func(s): return s.class_id != skill_id)


func set_team(_team) -> void:
	team = _team


func set_player_id(_id) -> void:
	_debug_id = "[%d]" % [_id]
	player_id = _id
