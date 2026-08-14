class_name WeaponFactory


const WEAPONS: Registry = preload("res://resources/registries/weapon_registry.tres")

static var _skill_map: Dictionary = {
	SquadBattleTypes.WeaponClasses.Unarmed: SkillType.Types.Healing,
	SquadBattleTypes.WeaponClasses.Flammenschwert: SkillType.Types.Swords,
	SquadBattleTypes.WeaponClasses.Crossbow: SkillType.Types.Crossbows,
	SquadBattleTypes.WeaponClasses.Arquebus: SkillType.Types.Firearms,
	SquadBattleTypes.WeaponClasses.Pike: SkillType.Types.Polearms,
	SquadBattleTypes.WeaponClasses.Mace: SkillType.Types.Maces,
	SquadBattleTypes.WeaponClasses.AlchemicalFire: SkillType.Types.Scholarship,
}

static var _cached_key = SquadBattleTypes.WeaponClasses.keys()

static func get_skill_used(weapon_class: SquadBattleTypes.WeaponClasses) -> SkillType.Types:
	return _skill_map.get(weapon_class, SkillType.Types.Swords)

static func get_weapon(_weapon: SquadBattleTypes.WeaponClasses) -> Weapon:
	var id: String = _cached_key[_weapon].to_snake_case()
	var weapon_template := WEAPONS.load_entry(id) as WeaponResource
	assert(weapon_template != null, "Weapon not registered in weapon_registry.tres: %s" % id)
	var weapon_conf = weapon_template.duplicate(true)
	var weapon = Weapon.new(weapon_conf)
	return weapon
