class_name LootCollector
extends RefCounted

static func collect_equipment_loot(enemy_squad: StrategySquad, enemy_casualties: Array[String]) -> Dictionary:
	var looted_weapons: Array[WeaponResource] = []
	var looted_armors: Array[ArmorConfig] = []

	for warrior in enemy_squad.warriors:
		if not warrior.is_dead:
			continue
		if warrior.equipment_weapon != null:
			looted_weapons.append(warrior.equipment_weapon.duplicate(true))
			Log.debug("LootCollector", "Looted weapon '%s' from %s" % [SquadBattleTypes.WeaponClasses.keys()[warrior.equipment_weapon.weapon_class], warrior.name])
		if warrior.equipment_armor != null:
			looted_armors.append(warrior.equipment_armor.duplicate(true))
			Log.debug("LootCollector", "Looted armor '%s' from %s" % [SquadBattleTypes.ArmorClasses.keys()[warrior.equipment_armor.armor_class], warrior.name])

	return {
		"weapons": looted_weapons,
		"armors": looted_armors,
	}


static func apply_equipment_loot(inventory, loot: Dictionary) -> void:
	var weapons: Array = loot.get("weapons", [])
	var armors: Array = loot.get("armors", [])

	for weapon in weapons:
		if weapon is WeaponResource:
			inventory.add_weapon(weapon)

	for armor in armors:
		if armor is ArmorConfig:
			inventory.add_armor(armor)

	if weapons.size() > 0 or armors.size() > 0:
		Log.info("LootCollector", "Added %d weapons and %d armors to inventory" % [weapons.size(), armors.size()])
