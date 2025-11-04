class_name SquadEntity extends Resource


@export var entity_name: String
@export var stats: EntityBaseStats
@export var logic_config: SimplifiedLogicConfig
@export var icon: Texture2D

@export var weapon_class: WeaponFactory.WeaponClasses = WeaponFactory.WeaponClasses.Unarmed
var weapon: SquadWeapon = null

var player_id: int
var team: String
var logic: SimplifiedSquadLogic

var changeable_stats: Dictionary = {
	SquadBattleTypes.EntityChangeable.HP: 0.0,
	SquadBattleTypes.EntityChangeable.STA: 0.0,
	SquadBattleTypes.EntityChangeable.ORG: 0.0,
	SquadBattleTypes.EntityChangeable.POS: 0.0,
	SquadBattleTypes.EntityChangeable.MAG: 0.0,
	SquadBattleTypes.EntityChangeable.LOC: SquadBattleTypes.SquadEntityInSquadLocation.Front
}

# var armour = SquadArmour.new()
# var logic = SquadLogic.new({"entity": self, "our_squad": {}, "enemy_squad": {}})

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
		# armour = SquadArmour.new()
	})

func _init(config: Dictionary = {}):
	player_id = config.get("player_id", randi() % 1000 + 1)
	entity_name = config.get("name", entity_name)
	team = config.get("team", "")
	stats = config.get("stats", EntityBaseStats.new())
	var context = {
		"entity": self,
		"our_squad": {},
		"enemy_squad": {}
	}
	logic = SimplifiedSquadLogic.new(context, logic_config)

	if config.has("weapon_class"):
		weapon_class = config["weapon_class"]
	weapon = WeaponFactory.get_weapon(weapon_class)
	# if config.has("armour"):
	# 	armour = config["armour"]
	innate_skills = config.get("innate_skills", [] as Array[Skill])
	changeable_stats[SquadBattleTypes.EntityChangeable.LOC] = config.get("starting_location", SquadBattleTypes.SquadEntityInSquadLocation.Front)
	initialise_changeables()

func initialise_changeables():
	changeable_stats[SquadBattleTypes.EntityChangeable.HP] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	changeable_stats[SquadBattleTypes.EntityChangeable.STA] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.STA)
	changeable_stats[SquadBattleTypes.EntityChangeable.ORG] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.ORG)
	changeable_stats[SquadBattleTypes.EntityChangeable.POS] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.POS)
	changeable_stats[SquadBattleTypes.EntityChangeable.MAG] = get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.MAG)

func set_logic(new_logic):
	logic = new_logic

func new_round_reset():
	is_retreating = false

func is_dead() -> bool:
	return get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) <= 0

# func get_armour():
# 	return armour

func calculate_reality_value(reality: SquadBattleTypes.Reality) -> float:
	match reality:
		SquadBattleTypes.Reality.HP:
			return (stats.endurance * 5) + (stats.siz * 2)
		SquadBattleTypes.Reality.Force:
			return (stats.strength * 2) + (stats.spd * 1) + (stats.siz * 1)
		SquadBattleTypes.Reality.Guts:
			return stats.wil * stats.fai
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
			print("Warning: Reality value for ", reality, " not found")
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

func mod_changeable_stat(property: SquadBattleTypes.EntityChangeable, by: float) -> SquadBattleTypes.EntityChange:
	return set_changeable_stat(property, get_changeable_stat_num(property) + by)

func set_changeable_stat(property: SquadBattleTypes.EntityChangeable, to: float) -> SquadBattleTypes.EntityChange:
	var old_value = changeable_stats[property]
	var new_value = clamp(to, get_floor_changeable_stat(property), get_ceiling_changeable_stat(property))
	changeable_stats[property] = new_value
	
	return SquadBattleTypes.EntityChange.new(property, old_value, new_value)

func get_changeable_stat_num(property: SquadBattleTypes.EntityChangeable) -> float:
	return changeable_stats[property]

func heal(num: float):
	if num < 0 or is_dead():
		return null
	return mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, num)

func boost(num: float):
	if num < 0 or is_dead():
		return null
	return mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, num)

func deorg_after_damage(dm: float, source: int) -> Array:
	if dm <= 0:
		return []
	if is_dead():
		return []
	
	var affected = player_id
	var base_damage_deorg = -(dm * 1.5)
	var close_to_death_deorg = -(get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) / get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)) * 10
	var changes: Array = [
		EntityUpdate.new(source, affected, mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, base_damage_deorg + close_to_death_deorg))
	]
	
	if get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG) <= 0:
		if not is_retreating:
			is_retreating = true
			changes.append(EntityUpdate.new(affected, affected, mod_changeable_stat(SquadBattleTypes.EntityChangeable.LOC, 1)))
			changes.append(EntityUpdate.new(affected, affected, mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, calculate_reality_value(SquadBattleTypes.Reality.Guts) * 0.1)))
	
	return changes

func recover() -> Array:
	if is_dead():
		return []
	var recover_updates: Array = []
	recover_updates.append(mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, 3))
	recover_updates.append(mod_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, 5))
	return recover_updates

func damage(num: float, source: int) -> Array:
	if is_dead():
		return []
	
	var old_hp = get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var affected = player_id
	
	if num <= 0:
		return [EntityUpdate.new(source, affected, SquadBattleTypes.EntityChange.new(SquadBattleTypes.EntityChangeable.HP, old_hp, old_hp))]
	else:
		var updates = [EntityUpdate.new(source, affected, mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, -num))]
		
		if get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) == 0:
			updates.append(
				EntityUpdate.new(source, affected,
				SquadBattleTypes.EntityChange.new(SquadBattleTypes.EntityChangeable.DIE, -1, -1)))
		else:
			for u in deorg_after_damage(num, source):
				updates.append(u)
		
		return updates

func action(our_squad: Dictionary, enemy_squad: Dictionary) -> Array:
	if is_dead():
		return []
	
	print("[", entity_name, "] Deciding action...")
	var updates: Array = []
	var updated_logic = logic.update_situation({
		"entity": self,
		"our_squad": our_squad,
		"enemy_squad": enemy_squad
	})
	
	var chosen_action = updated_logic.choose_action()
	print("[", entity_name, "] || Chose action: ", SquadBattleUtils.get_action_string(chosen_action))
	
	match chosen_action:
		SquadBattleTypes.SquadEntityAction.ATTACK:
			var attack_result = action_attack(updated_logic)
			if attack_result:
				for eu in attack_result:
					updates.append(eu)
		
		SquadBattleTypes.SquadEntityAction.FORWARD:
			for eu in action_forward(updated_logic):
				updates.append(eu)
		
		SquadBattleTypes.SquadEntityAction.HEAL:
			var heal_result = action_heal(updated_logic)
			if heal_result:
				for eu in heal_result:
					updates.append(eu)
		
		SquadBattleTypes.SquadEntityAction.IDLE:
			for c in action_idle():
				updates.append(EntityUpdate.new(player_id, player_id, c))
		
		SquadBattleTypes.SquadEntityAction.RETREAT:
			print("[", entity_name, "] retreating!")
			for eu in action_retreat():
				updates.append(eu)
		
		SquadBattleTypes.SquadEntityAction.CAPITULATE:
			print("[", entity_name, "] capitulating!")
			for eu in action_capitulate():
				updates.append(eu)
	
	return updates

func reaction(our_squad: Dictionary, enemy_squad: Dictionary) -> Array:
	if is_dead():
		return []
	
	print("[", entity_name, "] Deciding reaction...")
	var updates: Array = []
	var updated_logic = logic.update_situation({
		"entity": self,
		"our_squad": our_squad,
		"enemy_squad": enemy_squad
	})
	
	var chosen_reaction = updated_logic.choose_reaction()
	print("[", entity_name, "] || Chose reaction: ", chosen_reaction)
	
	match chosen_reaction:
		SquadBattleTypes.SquadEntityAction.ATTACK:
			var attack_result = action_attack(updated_logic)
			if attack_result:
				for eu in attack_result:
					updates.append(eu)
		
		SquadBattleTypes.SquadEntityAction.FORWARD:
			for eu in action_forward(updated_logic):
				updates.append(eu)
		
		SquadBattleTypes.SquadEntityAction.HEAL:
			var heal_result = action_heal(updated_logic)
			if heal_result:
				for eu in heal_result:
					updates.append(eu)
		
		SquadBattleTypes.SquadEntityAction.IDLE:
			for c in action_idle():
				updates.append(EntityUpdate.new(player_id, player_id, c))
		
		SquadBattleTypes.SquadEntityAction.RETREAT:
			print("[", entity_name, "] retreating!")
			for eu in action_retreat():
				updates.append(eu)
		
		SquadBattleTypes.SquadEntityAction.CAPITULATE:
			print("[", entity_name, "] capitulating!")
			for eu in action_capitulate():
				updates.append(eu)
	
	return updates

func action_attack(logic_obj):
	var one_clash = logic_obj.choose_clash()
	if one_clash:
		return one_clash.commit()
	else:
		print("[", entity_name, "] Cannot find target")
	return null

func action_forward(_logic_obj) -> Array:
	return [EntityUpdate.new(player_id, player_id, mod_changeable_stat(SquadBattleTypes.EntityChangeable.LOC, -1))]

func action_heal(logic_obj: SimplifiedSquadLogic):
	var physical_heal = 5
	var spirit_heal = 7

	var fla = logic_obj.situation.frontline_ally()
	var ally = fla[randi() % fla.size()]
	var updates: Array = []
	var h = ally.heal(physical_heal)
	var b = ally.boost(spirit_heal)
	
	if h:
		updates.append(EntityUpdate.new(player_id, ally.player_id, h))
	if b:
		updates.append(EntityUpdate.new(player_id, ally.player_id, b))
	
	return updates

func action_retreat() -> Array:
	if not is_retreating:
		is_retreating = true
		return [EntityUpdate.new(player_id, player_id, mod_changeable_stat(SquadBattleTypes.EntityChangeable.LOC, 1))]
	return []

func action_capitulate() -> Array:
	return [EntityUpdate.new(player_id, player_id, SquadBattleTypes.EntityChange.new(SquadBattleTypes.EntityChangeable.CAPITULATE, -1, -1))]

func action_idle() -> Array:
	return recover()

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
