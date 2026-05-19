class_name WarriorFactory


static func create_warrior(background_id: StringName, id: String, name: String, religion: StrategyTypes.Religion, combat_stats: EntityBaseStats = null) -> Warrior:
	var background := WarriorBackgroundFactory.get_background(background_id)
	var warrior := Warrior.new()
	warrior.background_id = background.background_id
	warrior.class_id = EntityClasses.Types.Landsknecht
	warrior.id = id
	warrior.name = name
	warrior.religion = religion
	if combat_stats:
		warrior.combat_stats = combat_stats
	else:
		warrior.combat_stats = _load_stats_template(background.stats_template_path)
	warrior.morale = 100.0
	warrior.attributes = {
		"diplomacy": 50,
		"survival": 50,
		"perception": 50,
		"leadership": 50,
		"stealth": 50
	}
	warrior.logic_type = background.default_role
	warrior.location_prebattle = background.default_position

	for skill_type in background.default_skills:
		warrior.skill_set.set_level(skill_type as SkillType.Types, background.default_skills[skill_type])

	_assign_equipment_from_background(warrior, background)
	return warrior


static func _load_stats_template(path: String) -> EntityBaseStats:
	if path.is_empty():
		return EntityBaseStats.new()
	var res := load(path) as EntityBaseStats
	assert(res != null, "Failed to load stats template from: %s" % path)
	return res.duplicate(true)


static func _assign_equipment_from_background(warrior: Warrior, background: WarriorBackground) -> void:
	if not background.default_weapon_id.is_empty():
		warrior.equipment_weapon_class = _weapon_class_from_id(background.default_weapon_id)
	if not background.default_armor_id.is_empty():
		warrior.equipment_armor_class = _armor_class_from_id(background.default_armor_id)


static func _weapon_class_from_id(weapon_id: StringName) -> WeaponFactory.WeaponClasses:
	match weapon_id:
		&"Flammenschwert":
			return WeaponFactory.WeaponClasses.Flammenschwert
		&"Crossbow":
			return WeaponFactory.WeaponClasses.Crossbow
		&"Arquebus":
			return WeaponFactory.WeaponClasses.Arquebus
		&"Pike":
			return WeaponFactory.WeaponClasses.Pike
		&"Mace":
			return WeaponFactory.WeaponClasses.Mace
		&"AlchemicalFire":
			return WeaponFactory.WeaponClasses.AlchemicalFire
		_:
			return WeaponFactory.WeaponClasses.Unarmed


static func _armor_class_from_id(armor_id: StringName) -> ArmorFactory.ArmorClasses:
	match armor_id:
		&"LeatherArmor":
			return ArmorFactory.ArmorClasses.LeatherArmor
		&"PaddedArmor":
			return ArmorFactory.ArmorClasses.PaddedArmor
		&"HalfPlate":
			return ArmorFactory.ArmorClasses.HalfPlate
		_:
			return ArmorFactory.ArmorClasses.Unarmored

