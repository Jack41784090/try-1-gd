extends Node
## Inventory & Equipment System — Unit Tests
## Usage: godot --headless --path . scenes/demos/inventory_test_demo.tscn

var _pass_count: int = 0
var _fail_count: int = 0
var _InventoryScript: GDScript
var _LootScript: GDScript


func _ready() -> void:
	_InventoryScript = load("res://src/strategy/core/inventory.gd")
	_LootScript = load("res://src/strategy/core/loot_collector.gd")
	Log.set_level(Log.Level.WARN)
	_print("=== INVENTORY & EQUIPMENT UNIT TESTS ===")

	_test_inventory_add_remove()
	_test_inventory_equip_weapon()
	_test_inventory_equip_armor_swap()
	_test_inventory_unequip()
	_test_inventory_is_empty()
	_test_inventory_get_all_items()
	_test_default_equipment_assignment()
	_test_loot_collector_dead_enemies()
	_test_loot_collector_skips_alive()
	_test_loot_collector_apply()
	_test_loot_collector_duplicates_items()

	_print("")
	_print("=== RESULTS: %d PASSED, %d FAILED ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		_print("!!! SOME TESTS FAILED !!!")
	else:
		_print("All tests passed.")
	get_tree().quit()


#region Helpers

func _print(msg: String) -> void:
	print(msg)

func _check(condition: bool, test_name: String) -> void:
	if condition:
		_pass_count += 1
		_print("  PASS: %s" % test_name)
	else:
		_fail_count += 1
		_print("  FAIL: %s" % test_name)

func _make_warrior(class_id: EntityClasses.Types, warrior_name: String) -> Warrior:
	return WarriorFactory.create_warrior(
		class_id, warrior_name.to_lower(), warrior_name,
		StrategyTypes.Religion.CATHOLIC, EntityBaseStats.new())

func _make_weapon(weapon_name: String) -> WeaponConfig:
	var w := WeaponConfig.new()
	w.weapon_name = weapon_name
	return w

func _make_armor(armor_name: String) -> ArmorConfig:
	var a := ArmorConfig.new()
	a.armor_name = armor_name
	return a

#endregion


#region SquadInventory Tests

func _test_inventory_add_remove() -> void:
	_print("")
	_print("--- SquadInventory: add/remove ---")
	var inv = _InventoryScript.new()
	var sword := _make_weapon("Test Sword")
	var plate := _make_armor("Test Plate")

	inv.add_weapon(sword)
	inv.add_armor(plate)
	_check(inv.weapons.size() == 1, "add_weapon increases count")
	_check(inv.armors.size() == 1, "add_armor increases count")

	var removed = inv.remove_weapon(sword)
	_check(removed == true, "remove_weapon returns true for existing")
	_check(inv.weapons.size() == 0, "remove_weapon decreases count")

	var removed2 = inv.remove_weapon(sword)
	_check(removed2 == false, "remove_weapon returns false for missing")

	var removed3 = inv.remove_armor(plate)
	_check(removed3 == true, "remove_armor returns true for existing")
	_check(inv.armors.size() == 0, "remove_armor decreases count")


func _test_inventory_equip_weapon() -> void:
	_print("")
	_print("--- SquadInventory: equip weapon ---")
	var inv = _InventoryScript.new()
	var warrior := Warrior.new()
	warrior.name = "Test Warrior"
	warrior.equipment_weapon = null

	var sword := _make_weapon("Iron Sword")
	inv.add_weapon(sword)
	_check(inv.weapons.size() == 1, "weapon in inventory before equip")

	inv.equip_weapon(warrior, sword)
	_check(warrior.equipment_weapon == sword, "warrior has weapon after equip")
	_check(inv.weapons.size() == 0, "weapon removed from inventory after equip")


func _test_inventory_equip_armor_swap() -> void:
	_print("")
	_print("--- SquadInventory: equip armor with swap ---")
	var inv = _InventoryScript.new()
	var warrior := Warrior.new()
	warrior.name = "Test Warrior"

	var old_armor := _make_armor("Old Leather")
	warrior.equipment_armor = old_armor

	var new_armor := _make_armor("New Plate")
	inv.add_armor(new_armor)

	inv.equip_armor(warrior, new_armor)
	_check(warrior.equipment_armor == new_armor, "warrior has new armor")
	_check(inv.armors.size() == 1, "old armor swapped back to inventory")
	_check(inv.armors[0] == old_armor, "swapped armor is the old one")


func _test_inventory_unequip() -> void:
	_print("")
	_print("--- SquadInventory: unequip ---")
	var inv = _InventoryScript.new()
	var warrior := Warrior.new()
	warrior.name = "Test Warrior"

	var sword := _make_weapon("Iron Sword")
	warrior.equipment_weapon = sword

	inv.unequip_weapon(warrior)
	_check(warrior.equipment_weapon == null, "warrior weapon null after unequip")
	_check(inv.weapons.size() == 1, "weapon moved to inventory")
	_check(inv.weapons[0] == sword, "correct weapon in inventory")

	inv.unequip_weapon(warrior)
	_check(inv.weapons.size() == 1, "unequip null weapon is no-op")

	var plate := _make_armor("Test Plate")
	warrior.equipment_armor = plate
	inv.unequip_armor(warrior)
	_check(warrior.equipment_armor == null, "warrior armor null after unequip")
	_check(inv.armors.size() == 1, "armor moved to inventory")


func _test_inventory_is_empty() -> void:
	_print("")
	_print("--- SquadInventory: is_empty ---")
	var inv = _InventoryScript.new()
	_check(inv.is_empty(), "new inventory is empty")

	var sword := _make_weapon("Sword")
	inv.add_weapon(sword)
	_check(not inv.is_empty(), "not empty after add_weapon")

	inv.remove_weapon(sword)
	_check(inv.is_empty(), "empty after remove_weapon")


func _test_inventory_get_all_items() -> void:
	_print("")
	_print("--- SquadInventory: get_all_items ---")
	var inv = _InventoryScript.new()
	var sword := _make_weapon("Sword")
	var plate := _make_armor("Plate")
	inv.add_weapon(sword)
	inv.add_armor(plate)

	var all = inv.get_all_items()
	_check(all.size() == 2, "get_all_items returns 2 items")
	_check(all.has(sword), "all items includes weapon")
	_check(all.has(plate), "all items includes armor")
	_check(inv.get_item_count() == 2, "get_item_count returns 2")

#endregion


#region Default Equipment Tests

func _test_default_equipment_assignment() -> void:
	_print("")
	_print("--- WarriorFactory: default equipment ---")
	var lk := _make_warrior(EntityClasses.Types.Landsknecht, "TestLK")
	_check(lk.equipment_weapon != null, "Landsknecht gets weapon")
	_check(lk.equipment_armor != null, "Landsknecht gets armor")
	_check(lk.equipment_weapon.weapon_name != "", "Landsknecht weapon has name")

	var healer := _make_warrior(EntityClasses.Types.Healer, "TestHealer")
	_check(healer.equipment_weapon == null, "Healer has no weapon")
	_check(healer.equipment_armor == null, "Healer has no armor")

	var pike := _make_warrior(EntityClasses.Types.Pikeman, "TestPike")
	_check(pike.equipment_weapon != null, "Pikeman gets weapon")
	_check(pike.equipment_armor != null, "Pikeman gets armor")

	var arq := _make_warrior(EntityClasses.Types.Arquebusier, "TestArq")
	_check(arq.equipment_weapon != null, "Arquebusier gets weapon")
	_check(arq.equipment_armor == null, "Arquebusier has no armor")

#endregion


#region LootCollector Tests

func _test_loot_collector_dead_enemies() -> void:
	_print("")
	_print("--- LootCollector: collect from dead ---")
	var enemy_squad := SquadData.new()
	var dead_warrior := _make_warrior(EntityClasses.Types.Landsknecht, "DeadEnemy")
	dead_warrior.is_dead = true
	enemy_squad.warriors.append(dead_warrior)

	var casualties: Array[String] = [dead_warrior.id]
	var loot = _LootScript.collect_equipment_loot(enemy_squad, casualties)
	var loot_weapons: Array = loot.get("weapons", [])
	var loot_armors: Array = loot.get("armors", [])
	_check(loot_weapons.size() == 1, "looted 1 weapon from dead Landsknecht")
	_check(loot_armors.size() == 1, "looted 1 armor from dead Landsknecht")
	_check(loot_weapons[0].weapon_name == dead_warrior.equipment_weapon.weapon_name, "looted weapon matches source")


func _test_loot_collector_skips_alive() -> void:
	_print("")
	_print("--- LootCollector: skips alive ---")
	var enemy_squad := SquadData.new()
	var alive_warrior := _make_warrior(EntityClasses.Types.Landsknecht, "AliveEnemy")
	alive_warrior.is_dead = false
	enemy_squad.warriors.append(alive_warrior)

	var casualties: Array[String] = []
	var loot = _LootScript.collect_equipment_loot(enemy_squad, casualties)
	var loot_weapons: Array = loot.get("weapons", [])
	var loot_armors: Array = loot.get("armors", [])
	_check(loot_weapons.size() == 0, "no weapons from alive enemy")
	_check(loot_armors.size() == 0, "no armors from alive enemy")


func _test_loot_collector_apply() -> void:
	_print("")
	_print("--- LootCollector: apply loot to inventory ---")
	var inv = _InventoryScript.new()
	var sword := _make_weapon("Looted Sword")
	var plate := _make_armor("Looted Plate")
	var loot := {
		"weapons": [sword],
		"armors": [plate],
	}
	_LootScript.apply_equipment_loot(inv, loot)
	_check(inv.weapons.size() == 1, "apply adds weapon to inventory")
	_check(inv.armors.size() == 1, "apply adds armor to inventory")


func _test_loot_collector_duplicates_items() -> void:
	_print("")
	_print("--- LootCollector: duplicates equipment ---")
	var enemy_squad := SquadData.new()
	var w := _make_warrior(EntityClasses.Types.Pikeman, "DeadPike")
	w.is_dead = true
	enemy_squad.warriors.append(w)

	var original_weapon := w.equipment_weapon
	var casualties: Array[String] = [w.id]
	var loot = _LootScript.collect_equipment_loot(enemy_squad, casualties)
	var loot_weapons: Array = loot.get("weapons", [])
	_check(loot_weapons.size() == 1, "looted 1 weapon from dead Pikeman")
	_check(loot_weapons[0] != original_weapon, "looted weapon is a duplicate (different reference)")
	_check(loot_weapons[0].weapon_name == original_weapon.weapon_name, "duplicate has same name")

#endregion
