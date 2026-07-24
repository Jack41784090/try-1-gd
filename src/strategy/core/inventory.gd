class_name SquadInventory
extends Resource

# signal changed

@export var weapons: Array[WeaponResource] = []
@export var armors: Array[ArmorConfig] = []


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


func equip_weapon(warrior: Character, weapon: WeaponResource) -> void:
	assert(warrior != null, "Cannot equip to null warrior")
	assert(weapon != null, "Cannot equip null weapon")
	assert(weapons.has(weapon), "Weapon not in inventory")
	weapons.remove_at(weapons.find(weapon))
	if warrior.get_equipped_weapon() != null:
		weapons.append(warrior.get_equipped_weapon())
	warrior.equip_weapon(weapon)
	changed.emit()


func equip_armor(warrior: Character, armor: ArmorConfig) -> void:
	assert(warrior != null, "Cannot equip to null warrior")
	assert(armor != null, "Cannot equip null armor")
	assert(armors.has(armor), "Armor not in inventory")
	armors.remove_at(armors.find(armor))
	if warrior.get_equipped_armor() != null:
		armors.append(warrior.get_equipped_armor())
	warrior.equip_armor(armor)
	changed.emit()


func unequip_weapon(warrior: Character) -> void:
	assert(warrior != null, "Cannot unequip from null warrior")
	if warrior.get_equipped_weapon() == null:
		return
	weapons.append(warrior.unequip_weapon())
	changed.emit()


func unequip_armor(warrior: Character) -> void:
	assert(warrior != null, "Cannot unequip from null warrior")
	if warrior.get_equipped_armor() == null:
		return
	armors.append(warrior.unequip_armor())
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
