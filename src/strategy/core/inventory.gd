class_name SquadInventory
extends RefCounted

var weapons: Array[WeaponConfig] = []
var armors: Array[ArmorConfig] = []


func add_weapon(weapon: WeaponConfig) -> void:
	assert(weapon != null, "Cannot add null weapon")
	weapons.append(weapon)


func add_armor(armor: ArmorConfig) -> void:
	assert(armor != null, "Cannot add null armor")
	armors.append(armor)


func remove_weapon(weapon: WeaponConfig) -> bool:
	var idx := weapons.find(weapon)
	if idx == -1:
		return false
	weapons.remove_at(idx)
	return true


func remove_armor(armor: ArmorConfig) -> bool:
	var idx := armors.find(armor)
	if idx == -1:
		return false
	armors.remove_at(idx)
	return true


func equip_weapon(warrior: CharacterSocialStats, weapon: WeaponConfig) -> void:
	assert(warrior != null, "Cannot equip to null warrior")
	assert(weapon != null, "Cannot equip null weapon")
	assert(weapons.has(weapon), "Weapon not in inventory")
	remove_weapon(weapon)
	if warrior.equipment_weapon != null:
		add_weapon(warrior.equipment_weapon)
	warrior.equipment_weapon = weapon


func equip_armor(warrior: CharacterSocialStats, armor: ArmorConfig) -> void:
	assert(warrior != null, "Cannot equip to null warrior")
	assert(armor != null, "Cannot equip null armor")
	assert(armors.has(armor), "Armor not in inventory")
	remove_armor(armor)
	if warrior.equipment_armor != null:
		add_armor(warrior.equipment_armor)
	warrior.equipment_armor = armor


func unequip_weapon(warrior: CharacterSocialStats) -> void:
	assert(warrior != null, "Cannot unequip from null warrior")
	if warrior.equipment_weapon == null:
		return
	add_weapon(warrior.equipment_weapon)
	warrior.equipment_weapon = null


func unequip_armor(warrior: CharacterSocialStats) -> void:
	assert(warrior != null, "Cannot unequip from null warrior")
	if warrior.equipment_armor == null:
		return
	add_armor(warrior.equipment_armor)
	warrior.equipment_armor = null


func get_all_items() -> Array:
	var items: Array = []
	for w in weapons:
		items.append(w)
	for a in armors:
		items.append(a)
	return items


func get_item_count() -> int:
	return weapons.size() + armors.size()


func is_empty() -> bool:
	return weapons.is_empty() and armors.is_empty()


func _to_string() -> String:
	return "SquadInventory(weapons=%d, armors=%d)" % [weapons.size(), armors.size()]
