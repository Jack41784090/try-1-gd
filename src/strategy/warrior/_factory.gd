class_name WarriorFactory

static var _class_weapon_map: Dictionary = {
	EntityClasses.Types.Landsknecht: "res://resources/combat/weapon/flammenschwert.tres",
	EntityClasses.Types.Healer: "",
	EntityClasses.Types.Crossbowman: "res://resources/combat/weapon/crossbow.tres",
	EntityClasses.Types.Arquebusier: "res://resources/combat/weapon/arquebus.tres",
	EntityClasses.Types.Pikeman: "res://resources/combat/weapon/pike.tres",
	EntityClasses.Types.Feldprediger: "res://resources/combat/weapon/mace.tres",
	EntityClasses.Types.Gelehrter: "res://resources/combat/weapon/alchemical-fire.tres",
}

static var _class_armor_map: Dictionary = {
	EntityClasses.Types.Landsknecht: "res://resources/combat/armor/leather-armor.tres",
	EntityClasses.Types.Healer: "",
	EntityClasses.Types.Crossbowman: "res://resources/combat/armor/padded-armor.tres",
	EntityClasses.Types.Arquebusier: "",
	EntityClasses.Types.Pikeman: "res://resources/combat/armor/half-plate.tres",
	EntityClasses.Types.Feldprediger: "res://resources/combat/armor/padded-armor.tres",
	EntityClasses.Types.Gelehrter: "",
}

static func create_warrior(class_id: EntityClasses.Types, id: String, name: String, religion: StrategyTypes.Religion, combat_stats: EntityBaseStats) -> Warrior:
	var warrior = Warrior.new()
	warrior.class_id = class_id
	warrior.id = id
	warrior.name = name
	warrior.religion = religion
	warrior.combat_stats = combat_stats
	warrior.morale = 100.0
	warrior.attributes = {
		"diplomacy": 50,
		"survival": 50,
		"perception": 50,
		"leadership": 50,
		"stealth": 50
	}
	_assign_default_equipment(warrior)
	return warrior


static func _assign_default_equipment(warrior: Warrior) -> void:
	if warrior.equipment_weapon != null and warrior.equipment_armor != null:
		return
	var weapon_path: String = _class_weapon_map.get(warrior.class_id, "")
	if weapon_path != "" and warrior.equipment_weapon == null:
		var weapon_res = load(weapon_path)
		if weapon_res is WeaponConfig:
			warrior.equipment_weapon = weapon_res.duplicate(true)
	var armor_path: String = _class_armor_map.get(warrior.class_id, "")
	if armor_path != "" and warrior.equipment_armor == null:
		var armor_res = load(armor_path)
		if armor_res is ArmorConfig:
			warrior.equipment_armor = armor_res.duplicate(true)
