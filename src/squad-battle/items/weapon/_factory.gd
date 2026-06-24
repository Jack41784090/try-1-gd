class_name WeaponFactory

static var pathlib = {
	"Unarmed": "res://resources/combat/weapon/unarmed.tres",
	"Flammenschwert": "res://resources/combat/weapon/flammenschwert.tres",
	"Crossbow": "res://resources/combat/weapon/crossbow.tres",
	"Arquebus": "res://resources/combat/weapon/arquebus.tres",
	"Pike": "res://resources/combat/weapon/pike.tres",
	"Mace": "res://resources/combat/weapon/mace.tres",
	"AlchemicalFire": "res://resources/combat/weapon/alchemical-fire.tres",
}

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

static func get_weapon(_weapon: SquadBattleTypes.WeaponClasses) -> SquadWeapon:
	var path = pathlib.get(_cached_key[_weapon]);
	var weapon_template = load(path)
	assert(weapon_template != null, "Failed to load weapon from path: %s" % path)
	assert(weapon_template is WeaponConfig, "Path %s loaded wrong type; got %s instead of WeaponConfig" % [path, weapon_template.get_class()])
	var weapon_conf = weapon_template.duplicate(true)
	var weapon = SquadWeapon.new(weapon_conf)
	return weapon
