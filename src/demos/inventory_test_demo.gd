extends Node
## Inventory & Equipment System — Unit Tests
## Usage: godot --headless --path . scenes/demos/inventory_test_demo.tscn

var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	MyLog.set_level(MyLog.Level.WARN)
	_print("=== INVENTORY & EQUIPMENT UNIT TESTS ===")

	# --- _test_inventory_add_remove ---
	_print("")
	_print("--- SquadInventory: add/remove ---")
	var ar_inv = SquadInventory.new()
	var ar_sword := _make_weapon("Test Sword")
	var ar_plate := _make_armor("Test Plate")

	ar_inv.add_weapon(ar_sword)
	ar_inv.add_armor(ar_plate)
	_check(ar_inv.weapons.size() == 1, "add_weapon increases count")
	_check(ar_inv.armors.size() == 1, "add_armor increases count")

	var ar_removed = ar_inv.remove_weapon(ar_sword)
	_check(ar_removed == true, "remove_weapon returns true for existing")
	_check(ar_inv.weapons.size() == 0, "remove_weapon decreases count")

	var ar_removed2 = ar_inv.remove_weapon(ar_sword)
	_check(ar_removed2 == false, "remove_weapon returns false for missing")

	var ar_removed3 = ar_inv.remove_armor(ar_plate)
	_check(ar_removed3 == true, "remove_armor returns true for existing")
	_check(ar_inv.armors.size() == 0, "remove_armor decreases count")

	# --- _test_inventory_equip_weapon ---
	_print("")
	_print("--- SquadInventory: equip weapon ---")
	var ew_inv = SquadInventory.new()
	var ew_entity := StrategyEntity.new()
	ew_entity.id = "test_strategy_entity"
	var ew_warrior := Character.new(ew_entity)
	ew_warrior.unequip_weapon()

	var ew_sword := _make_weapon("Iron Sword")
	ew_inv.add_weapon(ew_sword)
	_check(ew_inv.weapons.size() == 1, "weapon in inventory before equip")

	ew_inv.equip_weapon(ew_warrior, ew_sword)
	_check(ew_warrior.get_equipped_weapon() == ew_sword, "warrior has weapon after equip")
	_check(ew_inv.weapons.size() == 0, "weapon removed from inventory after equip")

	# --- _test_inventory_equip_armor_swap ---
	_print("")
	_print("--- SquadInventory: equip armor with swap ---")
	var as_inv = SquadInventory.new()
	var as_entity := StrategyEntity.new()
	as_entity.id = "test_strategy_entity"
	var as_warrior := Character.new(as_entity)

	var as_old_armor := _make_armor("Old Leather")
	as_warrior.equip_armor(as_old_armor)

	var as_new_armor := _make_armor("New Plate")
	as_inv.add_armor(as_new_armor)

	as_inv.equip_armor(as_warrior, as_new_armor)
	_check(as_warrior.get_equipped_armor() == as_new_armor, "warrior has new armor")
	_check(as_inv.armors.size() == 1, "old armor swapped back to inventory")
	_check(as_inv.armors[0] == as_old_armor, "swapped armor is the old one")

	# --- _test_inventory_unequip ---
	_print("")
	_print("--- SquadInventory: unequip ---")
	var ue_inv = SquadInventory.new()
	var ue_entity := StrategyEntity.new()
	ue_entity.id = "test_strategy_entity"
	var ue_warrior := Character.new(ue_entity)

	var ue_sword := _make_weapon("Iron Sword")
	ue_warrior.equip_weapon(ue_sword)

	ue_inv.unequip_weapon(ue_warrior)
	_check(ue_warrior.get_equipped_weapon() == null, "warrior weapon null after unequip")
	_check(ue_inv.weapons.size() == 1, "weapon moved to inventory")
	_check(ue_inv.weapons[0] == ue_sword, "correct weapon in inventory")

	ue_inv.unequip_weapon(ue_warrior)
	_check(ue_inv.weapons.size() == 1, "unequip null weapon is no-op")

	var ue_plate := _make_armor("Test Plate")
	ue_warrior.equip_armor(ue_plate)
	ue_inv.unequip_armor(ue_warrior)
	_check(ue_warrior.get_equipped_armor() == null, "warrior armor null after unequip")
	_check(ue_inv.armors.size() == 1, "armor moved to inventory")

	# --- _test_inventory_is_empty ---
	_print("")
	_print("--- SquadInventory: is_empty ---")
	var ie_inv = SquadInventory.new()
	_check(ie_inv.is_empty(), "new inventory is empty")

	var ie_sword := _make_weapon("Sword")
	ie_inv.add_weapon(ie_sword)
	_check(not ie_inv.is_empty(), "not empty after add_weapon")

	ie_inv.remove_weapon(ie_sword)
	_check(ie_inv.is_empty(), "empty after remove_weapon")

	# --- _test_inventory_get_all_items ---
	_print("")
	_print("--- SquadInventory: get_all_items ---")
	var ga_inv = SquadInventory.new()
	var ga_sword := _make_weapon("Sword")
	var ga_plate := _make_armor("Plate")
	ga_inv.add_weapon(ga_sword)
	ga_inv.add_armor(ga_plate)

	var ga_all = ga_inv.get_all_items()
	_check(ga_all.size() == 2, "get_all_items returns 2 items")
	_check(ga_all.has(ga_sword), "all items includes weapon")
	_check(ga_all.has(ga_plate), "all items includes armor")
	_check(ga_inv.get_item_count() == 2, "get_item_count returns 2")

	# --- _test_default_equipment_assignment ---
	_print("")
	_print("--- StrategyEntityFactory: default equipment ---")
	var de_lk := _make_warrior(EntityClasses.Types.Landsknecht, "TestLK")
	_check(de_lk.get_equipped_weapon() != null, "Landsknecht gets weapon")
	_check(de_lk.get_equipped_armor() != null, "Landsknecht gets armor")
	_check(de_lk.get_equipped_weapon().weapon_class != SquadBattleTypes.WeaponClasses.Unarmed, "Landsknecht weapon is not Unarmed")

	var de_healer := _make_warrior(EntityClasses.Types.Healer, "TestHealer")
	_check(de_healer.get_equipped_weapon() == null, "Healer has no weapon")
	_check(de_healer.get_equipped_armor() == null, "Healer has no armor")

	var de_pike := _make_warrior(EntityClasses.Types.Pikeman, "TestPike")
	_check(de_pike.get_equipped_weapon() != null, "Pikeman gets weapon")
	_check(de_pike.get_equipped_armor() != null, "Pikeman gets armor")

	var de_arq := _make_warrior(EntityClasses.Types.Arquebusier, "TestArq")
	_check(de_arq.get_equipped_weapon() != null, "Arquebusier gets weapon")
	_check(de_arq.get_equipped_armor() == null, "Arquebusier has no armor")

	# --- _test_loot_collector_dead_enemies ---
	_print("")
	_print("--- LootCollector: collect from dead ---")
	var lcd_enemy_squad := SquadDataFactory.create_squad()
	var lcd_dead_warrior := _make_warrior(EntityClasses.Types.Landsknecht, "DeadEnemy")
	lcd_dead_warrior.is_dead = true
	lcd_enemy_squad.warriors.append(lcd_dead_warrior)

	var lcd_casualties: Array[String] = [lcd_dead_warrior.id]
	var lcd_loot = LootCollector.collect_equipment_loot(lcd_enemy_squad, lcd_casualties)
	var lcd_loot_weapons: Array = lcd_loot.get("weapons", [])
	var lcd_loot_armors: Array = lcd_loot.get("armors", [])
	_check(lcd_loot_weapons.size() == 1, "looted 1 weapon from dead Landsknecht")
	_check(lcd_loot_armors.size() == 1, "looted 1 armor from dead Landsknecht")
	_check(lcd_loot_weapons[0].weapon_class == lcd_dead_warrior.get_equipped_weapon().weapon_class, "looted weapon matches source")

	# --- _test_loot_collector_skips_alive ---
	_print("")
	_print("--- LootCollector: skips alive ---")
	var lsa_enemy_squad := SquadDataFactory.create_squad()
	var lsa_alive_warrior := _make_warrior(EntityClasses.Types.Landsknecht, "AliveEnemy")
	lsa_alive_warrior.is_dead = false
	lsa_enemy_squad.warriors.append(lsa_alive_warrior)

	var lsa_casualties: Array[String] = []
	var lsa_loot = LootCollector.collect_equipment_loot(lsa_enemy_squad, lsa_casualties)
	var lsa_loot_weapons: Array = lsa_loot.get("weapons", [])
	var lsa_loot_armors: Array = lsa_loot.get("armors", [])
	_check(lsa_loot_weapons.size() == 0, "no weapons from alive enemy")
	_check(lsa_loot_armors.size() == 0, "no armors from alive enemy")

	# --- _test_loot_collector_apply ---
	_print("")
	_print("--- LootCollector: apply loot to inventory ---")
	var lca_inv = SquadInventory.new()
	var lca_sword := _make_weapon(SquadBattleTypes.WeaponClasses.Flammenschwert)
	var lca_plate := _make_armor(SquadBattleTypes.ArmorClasses.LeatherArmor)
	var lca_loot := {
		"weapons": [lca_sword],
		"armors": [lca_plate],
	}
	LootCollector.apply_equipment_loot(lca_inv, lca_loot)
	_check(lca_inv.weapons.size() == 1, "apply adds weapon to inventory")
	_check(lca_inv.armors.size() == 1, "apply adds armor to inventory")

	# --- _test_loot_collector_duplicates_items ---
	_print("")
	_print("--- LootCollector: duplicates equipment ---")
	var lcdu_enemy_squad := SquadDataFactory.create_squad()
	var lcdu_w := _make_warrior(EntityClasses.Types.Pikeman, "DeadPike")
	lcdu_w.is_dead = true
	lcdu_enemy_squad.warriors.append(lcdu_w)

	var lcdu_original_weapon := lcdu_w.get_equipped_weapon()
	var lcdu_casualties: Array[String] = [lcdu_w.id]
	var lcdu_loot = LootCollector.collect_equipment_loot(lcdu_enemy_squad, lcdu_casualties)
	var lcdu_loot_weapons: Array = lcdu_loot.get("weapons", [])
	_check(lcdu_loot_weapons.size() == 1, "looted 1 weapon from dead Pikeman")
	_check(lcdu_loot_weapons[0] != lcdu_original_weapon, "looted weapon is a duplicate (different reference)")
	_check(lcdu_loot_weapons[0].weapon_class == lcdu_original_weapon.weapon_class, "duplicate has same class")

	_print("")
	_print("=== RESULTS: %d PASSED, %d FAILED ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		_print("!!! SOME TESTS FAILED !!!")
	else:
		_print("All tests passed.")
	get_tree().quit()


func _print(msg: String) -> void:
	print(msg)

func _check(condition: bool, test_name: String) -> void:
	if condition:
		_pass_count += 1
		_print("  PASS: %s" % test_name)
	else:
		_fail_count += 1
		_print("  FAIL: %s" % test_name)

func _make_warrior(class_id: EntityClasses.Types, warrior_name: String) -> Character:
	var background_id := StringName(EntityClasses.Types.keys()[class_id].to_lower())
	var background := WarriorBackgroundFactory.get_background(background_id)
	var entity := StrategyEntityFactory.Create(background, StrategyTypes.Religion.CATHOLIC)
	entity.id = warrior_name.to_lower()
	return Character.new(entity)

func _make_weapon(wc = SquadBattleTypes.WeaponClasses.Unarmed) -> WeaponResource:
	var w := WeaponResource.new()
	if wc is int:
		w.weapon_class = wc
	return w

func _make_armor(ac = SquadBattleTypes.ArmorClasses.Unarmored) -> ArmorConfig:
	var a := ArmorConfig.new()
	if ac is int:
		a.armor_class = ac
	return a
