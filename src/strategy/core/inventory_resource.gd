class_name SquadInventoryResource
extends Resource

var weapons: Array[WeaponResource] = []
var armors: Array[ArmorConfig] = []


func add_weapon(weapon: WeaponResource) -> void:
	assert(weapon != null, "Cannot add null weapon")
	weapons.append(weapon)
	changed.emit()


func add_armor(armor: ArmorConfig) -> void:
	assert(armor != null, "Cannot add null armor")
	armors.append(armor)
	changed.emit()


func remove_weapon(weapon: WeaponResource) -> bool:
	var idx := weapons.find(weapon)
	if idx == -1:
		return false
	weapons.remove_at(idx)
	changed.emit()
	return true


func remove_armor(armor: ArmorConfig) -> bool:
	var idx := armors.find(armor)
	if idx == -1:
		return false
	armors.remove_at(idx)
	changed.emit()
	return true


func equip_weapon(warrior: StrategyEntity, weapon: WeaponResource) -> void:
	assert(warrior != null, "Cannot equip to null warrior")
	assert(weapon != null, "Cannot equip null weapon")
	assert(weapons.has(weapon), "Weapon not in inventory")
	weapons.remove_at(weapons.find(weapon))
	if warrior.equipment_weapon != null:
		weapons.append(warrior.equipment_weapon)
	warrior.equipment_weapon = weapon
	changed.emit()


func equip_armor(warrior: StrategyEntity, armor: ArmorConfig) -> void:
	assert(warrior != null, "Cannot equip to null warrior")
	assert(armor != null, "Cannot equip null armor")
	assert(armors.has(armor), "Armor not in inventory")
	armors.remove_at(armors.find(armor))
	if warrior.equipment_armor != null:
		armors.append(warrior.equipment_armor)
	warrior.equipment_armor = armor
	changed.emit()


func unequip_weapon(warrior: StrategyEntity) -> void:
	assert(warrior != null, "Cannot unequip from null warrior")
	if warrior.equipment_weapon == null:
		return
	weapons.append(warrior.equipment_weapon)
	warrior.equipment_weapon = null
	changed.emit()


func unequip_armor(warrior: StrategyEntity) -> void:
	assert(warrior != null, "Cannot unequip from null warrior")
	if warrior.equipment_armor == null:
		return
	armors.append(warrior.equipment_armor)
	warrior.equipment_armor = null
	changed.emit()


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
