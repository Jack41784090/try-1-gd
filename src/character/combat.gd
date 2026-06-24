class_name CombatEntity extends Resource

var _debug_id = "Entity_script_unknown";

#region Init from Resource
@export var class_id: EntityClasses.Types
@export var entity_name: String

@export var stats: EntityBaseStats
@export var icon: Texture2D

@export var weapon_class: SquadBattleTypes.WeaponClasses = SquadBattleTypes.WeaponClasses.Unarmed
var weapon: SquadWeapon = null

@export var armor_class: SquadBattleTypes.ArmorClasses = SquadBattleTypes.ArmorClasses.Unarmored
var armor: SquadArmor = null

@export var logic_config: SimplifiedLogicConfig
var logic: SimplifiedSquadLogic
#endregion

#region Init after Resource
var side: SquadBattleTypes.Side
var player_id: int = -1
var team: String
var changeable_stats: Dictionary = {
	SquadBattleTypes.EntityChangeable.HP: 0.0,
	SquadBattleTypes.EntityChangeable.STA: 0.0,
	SquadBattleTypes.EntityChangeable.ORG: 0.0,
	SquadBattleTypes.EntityChangeable.POS: 0.0,
	SquadBattleTypes.EntityChangeable.MAG: 0.0,
	SquadBattleTypes.EntityChangeable.LOC: SquadBattleTypes.SquadEntityInSquadLocation.Front
}
#endregion

var retreat_tracker = null

var is_retreating: bool:
	get: return retreat_tracker != null and retreat_tracker.state != 0

var has_last_stand: bool:
	get: return retreat_tracker != null and (retreat_tracker.state == 2 or retreat_tracker.state == 3)

var innate_skills: Array[Skill] = []
var temporary_skills: Array[Skill] = []
var status_effects: Array[StatusEffect] = []
var skill_set: SkillSet

static func quick_dummy():
	return CombatEntity.new(EntityConfig.new(
		EntityClasses.Types.Landsknecht,
		0,
		"Dummy",
		"Dummy",
		EntityBaseStats.new(),
		SquadBattleTypes.SquadEntityInSquadLocation.Front,
		LogicFactory.LogicAvailable.Frontline,
		null,
		SquadBattleTypes.WeaponClasses.Unarmed,
		null,
		SquadBattleTypes.ArmorClasses.Unarmored
	))


func _to_string() -> String:
	var status_str = "alive" if not is_dead() else "DEAD"
	var retreat_str = " [RETREATING]" if is_retreating else ""
	
	var hp = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var hp_max = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	var org = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)
	var org_max = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.ORG)
	var sta = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.STA)
	var pos = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.POS)
	var mag = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.MAG)
	var loc = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC)
	
	var weapon_str = SquadBattleTypes.WeaponClasses.keys()[weapon.weapon_class] if weapon else "NULL"
	var armor_str = SquadBattleTypes.ArmorClasses.keys()[armor.armor_class] if armor else "NULL"
	var icon_str = icon.resource_path if icon else "NULL"
	
	var skills_str = ""
	var all_skills = get_available_skills()
	if all_skills.size() > 0:
		var skill_names = []
		for skill in all_skills:
			skill_names.append(skill.name)
		skills_str = ", ".join(skill_names)
	else:
		skills_str = "NULL"
	
	var status_effects_str = ""
	if status_effects.size() > 0:
		var effect_names = []
		for effect in status_effects:
			effect_names.append(effect.name)
		status_effects_str = ", ".join(effect_names)
	else:
		status_effects_str = "NULL"
	
	return "CombatEntity(PlayerID:%s Team:%s %s%s | HP:%.1f/%.1f ORG:%.1f/%.1f STA:%.1f POS:%.1f MAG:%.1f LOC:%d | Weapon:%s Armor:%s Icon:%s | Skills:[%s] Status:[%s])" % [
		player_id, team, status_str, retreat_str,
		hp, hp_max, org, org_max, sta, pos, mag, loc,
		weapon_str, armor_str, icon_str, skills_str, status_effects_str
	]

func set_player_id(_id):
	_debug_id = "[%d]" % [_id]
	player_id = _id


func set_team(_team):
	team = _team

func init_after():
	_debug_id = "[%d]" % [player_id]
	retreat_tracker = RetreatTracker.new()
	
	changeable_stats[SquadBattleTypes.EntityChangeable.HP] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	changeable_stats[SquadBattleTypes.EntityChangeable.STA] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.STA)
	changeable_stats[SquadBattleTypes.EntityChangeable.ORG] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.ORG)
	changeable_stats[SquadBattleTypes.EntityChangeable.POS] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.POS)
	changeable_stats[SquadBattleTypes.EntityChangeable.MAG] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.MAG)


func _validate_existence() -> void:
	assert(side != SquadBattleTypes.Side.NULL, "Side must not be NULL")


func _init(config: EntityConfig = null):
	if config == null:
		skill_set = SkillSet.new()
		return
	
	skill_set = SkillSet.new()
	player_id = config.player_id
	class_id = config.entity_type_id
	entity_name = config.name
	side = config.side
	team = config.team
	stats = config.stats
	logic_config = LogicFactory.get_logic(config.logic_enum)
	
	if config.weapon:
		weapon = SquadWeapon.new(config.weapon)
	else:
		weapon_class = config.weapon_class
		weapon = WeaponFactory.get_weapon(weapon_class)
	
	if config.armor:
		armor = SquadArmor.new(config.armor)
	else:
		armor_class = config.armor_class
		armor = ArmorFactory.get_armor(armor_class)
	armor.set_defender(self )
	
	logic = SimplifiedSquadLogic.new({
		"entity": self ,
		"our_squad": {},
		"enemy_squad": {}
	}, logic_config)
	
	for skill in config.innate_skills:
		innate_skills.append(skill)

	if config.skill_set:
		skill_set = config.skill_set

	changeable_stats[SquadBattleTypes.EntityChangeable.LOC] = config.starting_location

	_validate_existence()
	init_after()

func init_from_resource():
	if weapon != null:
		return
	
	weapon = WeaponFactory.get_weapon(weapon_class)
	armor = ArmorFactory.get_armor(armor_class)
	armor.set_defender(self )
	logic = SimplifiedSquadLogic.new({
		"entity": self ,
		"our_squad": {},
		"enemy_squad": {}
	}, logic_config)
	init_after()

func set_logic(new_logic):
	logic = new_logic

func new_round_reset():
	retreat_tracker.new_round_reset()

func is_dead() -> bool:
	return get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) <= 0

func get_armour():
	return armor

enum _RealityOp {ADD, MUL}

const _REALITY_TABLE: Dictionary = {
	SquadBattleTypes.Reality.HP: [3.0, _RealityOp.MUL, [["endurance", 5.0], ["siz", 2.0]]],
	SquadBattleTypes.Reality.Force: [1.0, _RealityOp.MUL, [["strength", 2.0], ["spd", 1.0], ["siz", 1.0]]],
	SquadBattleTypes.Reality.Guts: [10.0, _RealityOp.ADD, [["wil", 8.0], ["fai", 5.0]]],
	SquadBattleTypes.Reality.Mana: [0.0, _RealityOp.ADD, [["int_stat", 3.0], ["spr", 2.0], ["fai", 1.0]]],
	SquadBattleTypes.Reality.Spirituality: [0.0, _RealityOp.ADD, [["spr", 2.0], ["fai", 2.0], ["wil", 1.0]]],
	SquadBattleTypes.Reality.Divinity: [0.0, _RealityOp.ADD, [["fai", 3.0], ["wil", 2.0], ["cha", 1.0]]],
	SquadBattleTypes.Reality.Precision: [0.0, _RealityOp.ADD, [["dex", 2.0], ["acr", 1.0], ["spd", 1.0]]],
	SquadBattleTypes.Reality.Maneuver: [0.0, _RealityOp.ADD, [["acr", 2.0], ["spd", 2.0], ["dex", 1.0]]],
	SquadBattleTypes.Reality.Convince: [0.0, _RealityOp.ADD, [["cha", 2.0], ["beu", 1.0], ["int_stat", 1.0]]],
	SquadBattleTypes.Reality.Bravery: [0.0, _RealityOp.ADD, [["wil", 2.0], ["endurance", 1.0], ["fai", 1.0]]],
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
			product *= stats.get(term[0]) * term[1]
		return base + product
	else:
		var total: float = base
		for term in terms:
			total += stats.get(term[0]) * term[1]
		return total

func get_ceiling_changeable_stat(property: SquadBattleTypes.EntityChangeable) -> float:
	match property:
		SquadBattleTypes.EntityChangeable.HP:
			return calculate_reality_value(SquadBattleTypes.Reality.HP)
		SquadBattleTypes.EntityChangeable.ORG:
			return calculate_reality_value(SquadBattleTypes.Reality.Guts)
		SquadBattleTypes.EntityChangeable.LOC:
			return SquadBattleTypes.SquadEntityInSquadLocation.Back
		_:
			return 100.0

func get_floor_changeable_stat(property: SquadBattleTypes.EntityChangeable) -> float:
	match property:
		SquadBattleTypes.EntityChangeable.LOC:
			return SquadBattleTypes.SquadEntityInSquadLocation.Front
		_:
			return 0.0

func mod_changeable_stat(property: SquadBattleTypes.EntityChangeable, by: float) -> EntityChange:
	return set_changeable_stat(property, get_changeable_stat_num(property) + by)

func set_changeable_stat(property: SquadBattleTypes.EntityChangeable, to: float) -> EntityChange:
	var old_value = changeable_stats[property]
	var new_value = clamp(to, get_floor_changeable_stat(property), get_ceiling_changeable_stat(property))
	changeable_stats[property] = new_value
	
	return EntityChange.new(property, old_value, new_value)

func get_changeable_stat_num(property: SquadBattleTypes.EntityChangeable) -> float:
	return changeable_stats[property]

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
	var base_damage_deorg = - (dm * 1.5)
	var current_hp = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var max_hp = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	var hp_percentage = current_hp / max_hp
	var close_to_death_deorg = - ((1.0 - hp_percentage) * 10)
	var changes: Array[EntityUpdate] = [
		EntityUpdate.new(source, affected, mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, base_damage_deorg + close_to_death_deorg))
	]
	
	if retreat_tracker.should_retreat(get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)):
		for u in retreat_tracker.advance(self ):
			changes.append(u)
	
	return changes

func recover() -> Array[EntityChange]:
	if is_dead():
		return []
	var recover_changes: Array[EntityChange] = [
		mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, 3),
		mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, 5)
	]
	return recover_changes

func damage(num: float, source: int) -> Array[EntityUpdate]:
	if is_dead():
		return []
	
	var old_hp = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var affected = player_id
	
	if num <= 0:
		return [EntityUpdate.new(source, affected, EntityChange.new(SquadBattleTypes.EntityChangeable.HP, old_hp, old_hp))]
	else:
		var updates = [
			EntityUpdate.new(
				source, affected,
				mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, -num))
		] as Array[EntityUpdate]
		
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
	var updated_logic = logic.update_situation({
		"entity": self ,
		"our_squad": our_squad,
		"enemy_squad": enemy_squad
	})
	
	# 2. Logic determines the best Consideration and its associated Skill
	var chosen_skill = updated_logic.choose_skill()
	
	# 3. Entity executes such skill based on Logic
	if chosen_skill:
		var skill_result = execute_skill(chosen_skill, updated_logic)
		for eu in skill_result:
			updates.append(eu)
	else:
		Log.debug("Combat", "%s/%s: no skill, idling" % [_debug_id, entity_name])
		for c in recover():
			updates.append(EntityUpdate.new(player_id, player_id, c))
	
	return updates

func reaction(our_squad: Dictionary, enemy_squad: Dictionary) -> Array:
	if is_dead():
		return []
	
	var updates: Array = []
	var updated_logic = logic.update_situation({
		"entity": self ,
		"our_squad": our_squad,
		"enemy_squad": enemy_squad
	})
	
	var chosen_skill = updated_logic.choose_skill()
	
	if chosen_skill:
		var skill_result = execute_skill(chosen_skill, updated_logic)
		if skill_result:
			for eu in skill_result:
				updates.append(eu)
	else:
		Log.debug("Combat", "%s/%s: no skill, skipping reaction" % [_debug_id, entity_name])
	
	return updates

func execute_skill(skill: Skill, logic_obj: SimplifiedSquadLogic) -> Array:
	if not skill:
		return []
	
	var updates: Array = []
	
	var clash = logic_obj.choose_clash_with_skill(skill)
	if clash == null:
		Log.debug("Combat", "%s/%s: no valid target for '%s'" % [_debug_id, entity_name, skill.name])
		return []
	
	for u in clash.commit():
		updates.append(u)
	
	return updates

func get_available_skills() -> Array[Skill]:
	var skills = innate_skills.duplicate()
	skills.append_array(temporary_skills)
	return skills

func get_skills_for_purpose(_purpose: String) -> Array[Skill]:
	return get_available_skills()

func add_innate_skill(skill):
	innate_skills.append(skill)

func add_temporary_skill(skill):
	temporary_skills.append(skill)

func remove_temporary_skill(skill_id: String):
	temporary_skills = temporary_skills.filter(func(s): return s.class_id != skill_id)
