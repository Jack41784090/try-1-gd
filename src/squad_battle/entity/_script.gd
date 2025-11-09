class_name SquadEntity extends Resource

var _debug_id;

#region Init from Resource
@export var entity_name: String
@export var stats: EntityBaseStats
@export var icon: Texture2D

@export var weapon_class: WeaponFactory.WeaponClasses = WeaponFactory.WeaponClasses.Unarmed
var weapon: SquadWeapon = null

@export var armor_class: ArmorFactory.ArmorClasses = ArmorFactory.ArmorClasses.Unarmored
var armor: SquadArmor = null

@export var logic_config: SimplifiedLogicConfig
var logic: SimplifiedSquadLogic
#endregion

#region Init after Resource
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

var is_retreating: bool = false
var innate_skills: Array[Skill] = []
var temporary_skills: Array[Skill] = []
var status_effects: Array[StatusEffect] = []

static func quick_dummy():
	return SquadEntity.new({
		player_id = 0,
		entity_name = "Dummy",
		team = "Dummy",
		stats = EntityBaseStats.new(),
		weapon_class = WeaponFactory.WeaponClasses.Unarmed,
		armor_class = ArmorFactory.ArmorClasses.Unarmored,
	})


func set_player_id(_id):
	_debug_id = "%s[%d]" % [entity_name, _id]
	player_id = _id


func set_team(_team):
	team = _team

func init_after():
	_debug_id = "%s[%d]" % [entity_name, player_id]
	changeable_stats[SquadBattleTypes.EntityChangeable.HP] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	changeable_stats[SquadBattleTypes.EntityChangeable.STA] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.STA)
	changeable_stats[SquadBattleTypes.EntityChangeable.ORG] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.ORG)
	changeable_stats[SquadBattleTypes.EntityChangeable.POS] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.POS)
	changeable_stats[SquadBattleTypes.EntityChangeable.MAG] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.MAG)


func _init(config: Dictionary = {}):
	if config.is_empty():
		return
	
	player_id = config.get("player_id", randi() % 1000 + 1)
	entity_name = config.get("name", entity_name)
	team = config.get("team", "")
	stats = config.get("stats", EntityBaseStats.new())
	logic_config = config.get("logic_config")
	
	if config.has("weapon"):
		weapon = SquadWeapon.new(config["weapon"])
	else:
		weapon_class = config.get("weapon_class", WeaponFactory.WeaponClasses.Unarmed)
		weapon = WeaponFactory.get_weapon(weapon_class)
	
	if config.has("armor"):
		armor = SquadArmor.new(config["armor"])
	else:
		armor_class = config.get("armor_class", ArmorFactory.ArmorClasses.Unarmored)
		armor = ArmorFactory.get_armor(armor_class)
	armor.set_defender(self)
	
	logic = SimplifiedSquadLogic.new({
		"entity": self,
		"our_squad": {},
		"enemy_squad": {}
	}, logic_config)
	
	innate_skills = config.get("innate_skills", [] as Array[Skill])
	changeable_stats[SquadBattleTypes.EntityChangeable.LOC] = config.get("starting_location", SquadBattleTypes.SquadEntityInSquadLocation.Front)
	init_after()

func init_from_resource():
	if weapon != null:
		return
	
	weapon = WeaponFactory.get_weapon(weapon_class)
	armor = ArmorFactory.get_armor(armor_class)
	armor.set_defender(self)
	logic = SimplifiedSquadLogic.new({
		"entity": self,
		"our_squad": {},
		"enemy_squad": {}
	}, logic_config)
	init_after()

func set_logic(new_logic):
	logic = new_logic

func new_round_reset():
	is_retreating = false

func is_dead() -> bool:
	return get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) <= 0

func get_armour():
	return armor

func calculate_reality_value(reality: SquadBattleTypes.Reality) -> float:
	match reality:
		SquadBattleTypes.Reality.HP:
			return 3 + (stats.endurance * 5) * (stats.siz * 2)
		SquadBattleTypes.Reality.Force:
			return 1 + (stats.strength * 2) * (stats.spd * 1) * (stats.siz * 1)
		SquadBattleTypes.Reality.Guts:
			return 1 + stats.wil * stats.fai
		SquadBattleTypes.Reality.Mana:
			return (stats.int_stat * 3) + (stats.spr * 2) + (stats.fai * 1)
		SquadBattleTypes.Reality.Spirituality:
			return (stats.spr * 2) + (stats.fai * 2) + (stats.wil * 1)
		SquadBattleTypes.Reality.Divinity:
			return (stats.fai * 3) + (stats.wil * 2) + (stats.cha * 1)
		SquadBattleTypes.Reality.Precision:
			return (stats.dex * 2) + (stats.acr * 1) + (stats.spd * 1)
		SquadBattleTypes.Reality.Maneuver:
			return (stats.acr * 2) + (stats.spd * 2) + (stats.dex * 1)
		SquadBattleTypes.Reality.Convince:
			return (stats.cha * 2) + (stats.beu * 1) + (stats.int_stat * 1)
		SquadBattleTypes.Reality.Bravery:
			return (stats.wil * 2) + (stats.endurance * 1) + (stats.fai * 1)
		_:
			print("[%s]Warning: Reality value for %s not found" % [_debug_id, reality])
			return 0

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
	var base_damage_deorg = -(dm * 1.5)
	var current_hp = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var max_hp = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	var hp_percentage = current_hp / max_hp
	var close_to_death_deorg = -((1.0 - hp_percentage) * 10)
	var changes: Array[EntityUpdate] = [
		EntityUpdate.new(source, affected, mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, base_damage_deorg + close_to_death_deorg))
	]
	
	if get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG) <= 0:
		if not is_retreating:
			is_retreating = true
			changes.append(EntityUpdate.new(affected, affected, mod_changeable_stat(SquadBattleTypes.EntityChangeable.LOC, 1)))
			changes.append(EntityUpdate.new(affected, affected, mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, calculate_reality_value(SquadBattleTypes.Reality.Guts) * 0.1)))
	
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
	
	# 1. Logic updates the situation
	print("[%s] Deciding action..." % [_debug_id])
	var updates: Array = []
	var updated_logic = logic.update_situation({
		"entity": self,
		"our_squad": our_squad,
		"enemy_squad": enemy_squad
	})
	
	# 2. Logic determines the best Consideration and its associated Skill
	var chosen_skill = updated_logic.choose_skill()
	print("[%s] || Chose skill: %s" % [_debug_id, chosen_skill.name if chosen_skill else "None"])
	
	# 3. Entity executes such skill based on Logic
	if chosen_skill:
		var skill_result = execute_skill(chosen_skill, updated_logic)
		for eu in skill_result:
			updates.append(eu)
	else:
		print("[%s] || No skill selected, performing idle action" % [_debug_id])
		for c in recover():
			updates.append(EntityUpdate.new(player_id, player_id, c))
	
	return updates

func reaction(our_squad: Dictionary, enemy_squad: Dictionary) -> Array:
	if is_dead():
		return []
	
	print("[%s] Deciding reaction..." % [_debug_id])
	var updates: Array = []
	var updated_logic = logic.update_situation({
		"entity": self,
		"our_squad": our_squad,
		"enemy_squad": enemy_squad
	})
	
	var chosen_skill = updated_logic.choose_skill()
	print("[%s] || Chose skill for reaction: %s" % [_debug_id, chosen_skill.name if chosen_skill else "None"])
	
	if chosen_skill:
		var skill_result = execute_skill(chosen_skill, updated_logic)
		if skill_result:
			for eu in skill_result:
				updates.append(eu)
	else:
		print("[%s] || No skill selected for reaction, doing nothing" % [_debug_id])
	
	return updates

func execute_skill(skill: Skill, logic_obj: SimplifiedSquadLogic) -> Array:
	if not skill:
		return []
	
	print("[%s] Executing skill: %s" % [_debug_id, skill.name])
	var updates: Array = []
	
	# var needs_target = _skill_needs_target(skill)
	
	# if needs_target:
	# 	var one_clash = logic_obj.choose_clash_with_skill(skill)
	# 	if one_clash:
	# 		var clash_updates = one_clash.commit()
	# 		for eu in clash_updates:
	# 			updates.append(eu)
	# 	else:
	# 		print("[%s] Cannot find target for skill: %s" % [_debug_id, skill.name])
	# else:
	# 	updates = _execute_non_target_skill(skill, logic_obj)

	var clash = logic_obj.choose_clash_with_skill(skill)
	for u in clash.commit():
		updates.append(u)
	
	return updates

func get_available_skills() -> Array[Skill]:
	var skills = innate_skills.duplicate()
	if weapon:
		skills.append_array(weapon.get_weapon_skills(self))
	skills.append_array(temporary_skills)
	return skills

func get_skills_for_purpose(_purpose: String) -> Array[Skill]:
	return get_available_skills()

func add_innate_skill(skill):
	innate_skills.append(skill)

func add_temporary_skill(skill):
	temporary_skills.append(skill)

func remove_temporary_skill(skill_id: String):
	temporary_skills = temporary_skills.filter(func(s): return s.id != skill_id)
