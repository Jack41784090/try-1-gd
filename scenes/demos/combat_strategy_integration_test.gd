extends Node

## Comprehensive test suite for the Combat-Strategy Integration systems
## Tests: Tactic, Clue, CombatBridge, World squad management, Location clues

var test_count := 0
var passed_count := 0
var failed_count := 0

func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("COMBAT-STRATEGY INTEGRATION - COMPREHENSIVE TEST SUITE")
	print("=".repeat(80) + "\n")
	
	test_tactic_system()
	test_clue_system()
	test_world_squad_management()
	test_faction_army_management()
	test_location_clue_management()
	test_strategic_squad_tactic()
	test_combat_bridge()
	test_battle_outcome_system()
	test_tactic_based_rounds()
	
	print_final_results()
	
	get_tree().quit(failed_count)

func print_final_results() -> void:
	print("\n" + "=".repeat(80))
	print("TEST RESULTS")
	print("=".repeat(80))
	print("Total Tests: %d" % test_count)
	print("Passed: %d" % passed_count)
	print("Failed: %d" % failed_count)
	if failed_count == 0:
		print("\n✓ ALL TESTS PASSED!")
	else:
		print("\n✗ SOME TESTS FAILED!")
	print("=".repeat(80) + "\n")

func start_test(test_name: String) -> void:
	test_count += 1
	print("  [TEST %d] %s" % [test_count, test_name])

func assert_true(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("    ✓ PASS: %s" % message)
	else:
		failed_count += 1
		print("    ✗ FAIL: %s" % message)

func assert_equal(actual, expected, message: String) -> void:
	if actual == expected:
		passed_count += 1
		print("    ✓ PASS: %s (got %s)" % [message, str(actual)])
	else:
		failed_count += 1
		print("    ✗ FAIL: %s (expected %s, got %s)" % [message, str(expected), str(actual)])

func assert_not_null(value, message: String) -> void:
	if value != null:
		passed_count += 1
		print("    ✓ PASS: %s" % message)
	else:
		failed_count += 1
		print("    ✗ FAIL: %s (was null)" % message)

func end_test() -> void:
	print("")

# ============================================================================
# TEST SUITE 1: Tactic System
# ============================================================================

func test_tactic_system() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 1: Tactic System")
	print("-".repeat(80) + "\n")
	
	test_tactic_balanced()
	test_tactic_aggressive_charge()
	test_tactic_guerilla_defence()
	test_tactic_full_assault()
	test_tactic_defensive_formation()
	test_tactic_create_from_type()

func test_tactic_balanced() -> void:
	start_test("Tactic: create_balanced()")
	
	var tactic = Tactic.create_balanced()
	
	assert_equal(tactic.tactic_id, "balanced", "tactic_id should be 'balanced'")
	assert_equal(tactic.tactic_name, "Balanced", "tactic_name should be 'Balanced'")
	assert_equal(tactic.action_count, 1, "action_count should be 1")
	assert_equal(tactic.reaction_count, 1, "reaction_count should be 1")
	assert_equal(tactic.attack_modifier, 1.0, "attack_modifier should be 1.0")
	assert_equal(tactic.defense_modifier, 1.0, "defense_modifier should be 1.0")
	end_test()

func test_tactic_aggressive_charge() -> void:
	start_test("Tactic: create_aggressive_charge()")
	
	var tactic = Tactic.create_aggressive_charge()
	
	assert_equal(tactic.tactic_id, "aggressive_charge", "tactic_id correct")
	assert_equal(tactic.action_count, 2, "action_count should be 2")
	assert_equal(tactic.reaction_count, 1, "reaction_count should be 1")
	assert_equal(tactic.defense_modifier, 0.8, "defense_modifier should be 0.8")
	end_test()

func test_tactic_guerilla_defence() -> void:
	start_test("Tactic: create_guerilla_defence()")
	
	var tactic = Tactic.create_guerilla_defence()
	
	assert_equal(tactic.tactic_id, "guerilla_defence", "tactic_id correct")
	assert_equal(tactic.action_count, 1, "action_count should be 1")
	assert_equal(tactic.reaction_count, 2, "reaction_count should be 2")
	assert_equal(tactic.attack_modifier, 0.8, "attack_modifier should be 0.8")
	end_test()

func test_tactic_full_assault() -> void:
	start_test("Tactic: create_full_assault()")
	
	var tactic = Tactic.create_full_assault()
	
	assert_equal(tactic.action_count, 3, "action_count should be 3")
	assert_equal(tactic.reaction_count, 0, "reaction_count should be 0")
	assert_equal(tactic.attack_modifier, 1.2, "attack_modifier should be 1.2")
	assert_equal(tactic.defense_modifier, 0.6, "defense_modifier should be 0.6")
	end_test()

func test_tactic_defensive_formation() -> void:
	start_test("Tactic: create_defensive_formation()")
	
	var tactic = Tactic.create_defensive_formation()
	
	assert_equal(tactic.action_count, 0, "action_count should be 0")
	assert_equal(tactic.reaction_count, 3, "reaction_count should be 3")
	assert_equal(tactic.attack_modifier, 0.6, "attack_modifier should be 0.6")
	assert_equal(tactic.defense_modifier, 1.2, "defense_modifier should be 1.2")
	end_test()

func test_tactic_create_from_type() -> void:
	start_test("Tactic: create_from_type()")
	
	var balanced = Tactic.create_from_type(Tactic.TacticType.BALANCED)
	assert_equal(balanced.tactic_id, "balanced", "BALANCED type creates balanced tactic")
	
	var aggressive = Tactic.create_from_type(Tactic.TacticType.AGGRESSIVE_CHARGE)
	assert_equal(aggressive.tactic_id, "aggressive_charge", "AGGRESSIVE_CHARGE type correct")
	
	var guerilla = Tactic.create_from_type(Tactic.TacticType.GUERILLA_DEFENCE)
	assert_equal(guerilla.tactic_id, "guerilla_defence", "GUERILLA_DEFENCE type correct")
	end_test()

# ============================================================================
# TEST SUITE 2: Clue System
# ============================================================================

func test_clue_system() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 2: Clue System")
	print("-".repeat(80) + "\n")
	
	test_clue_creation()
	test_clue_expiry()
	test_clue_age_description()
	test_clue_destination_hint()
	test_clue_random_name()

func test_clue_creation() -> void:
	start_test("Clue: create_clue()")
	
	var clue = Clue.create_clue(
		"Boot Prints",
		"squad_001",
		"warrior_001",
		5,
		30,
		"moscow"
	)
	
	assert_equal(clue.clue_name, "Boot Prints", "clue_name set correctly")
	assert_equal(clue.left_by_squad_id, "squad_001", "squad_id set correctly")
	assert_equal(clue.left_by_warrior_id, "warrior_001", "warrior_id set correctly")
	assert_equal(clue.created_turn, 5, "created_turn set correctly")
	assert_equal(clue.destination_id, "moscow", "destination_id set correctly")
	assert_true(clue.decay >= 3 and clue.decay <= 7, "decay is between 3-7")
	assert_true(clue.detail_level >= 0 and clue.detail_level <= 100, "detail_level clamped correctly")
	end_test()

func test_clue_expiry() -> void:
	start_test("Clue: is_expired() and get_age()")
	
	var clue = Clue.new()
	clue.created_turn = 5
	clue.decay = 3
	
	assert_equal(clue.get_age(5), 0, "age at creation turn is 0")
	assert_equal(clue.get_age(7), 2, "age after 2 turns is 2")
	assert_true(not clue.is_expired(7), "not expired at age 2 with decay 3")
	assert_true(clue.is_expired(8), "expired at age 3 with decay 3")
	end_test()

func test_clue_age_description() -> void:
	start_test("Clue: get_age_description()")
	
	var clue = Clue.new()
	clue.created_turn = 0
	clue.decay = 10
	
	var desc_fresh = clue.get_age_description(0)
	assert_true(desc_fresh.contains("fresh") or desc_fresh.contains("hour"), "fresh clue description")
	
	var desc_1day = clue.get_age_description(1)
	assert_true(desc_1day.contains("1"), "1 day old description")
	
	var desc_old = clue.get_age_description(6)
	assert_true(desc_old.contains("old") or desc_old.contains("fad"), "old clue description")
	end_test()

func test_clue_destination_hint() -> void:
	start_test("Clue: get_destination_hint()")
	
	var clue = Clue.new()
	clue.destination_id = "moscow"
	clue.detail_level = 50
	
	var hint_high = clue.get_destination_hint(80)
	assert_true(hint_high.contains("moscow") or hint_high.contains("heading"), "high perception reveals destination")
	
	var hint_low = clue.get_destination_hint(20)
	assert_true(hint_low.contains("unclear") or hint_low.contains("direction"), "low perception gives vague hint")
	
	var clue_no_dest = Clue.new()
	clue_no_dest.destination_id = ""
	var hint_none = clue_no_dest.get_destination_hint(100)
	assert_true(hint_none.contains("unknown") or hint_none.contains("no"), "no destination gives appropriate message")
	end_test()

func test_clue_random_name() -> void:
	start_test("Clue: get_random_clue_name()")
	
	var name_catholic = Clue.get_random_clue_name(StrategyTypes.Religion.CATHOLIC)
	assert_true(name_catholic.length() > 0, "Catholic clue name generated")
	
	var name_pagan = Clue.get_random_clue_name(StrategyTypes.Religion.PAGAN)
	assert_true(name_pagan.length() > 0, "Pagan clue name generated")
	
	var names_set: Array[String] = []
	for i in range(20):
		var clue_name_gen = Clue.get_random_clue_name(StrategyTypes.Religion.CATHOLIC)
		if not clue_name_gen in names_set:
			names_set.append(clue_name_gen)
	assert_true(names_set.size() > 1, "Multiple different clue names generated")
	end_test()

# ============================================================================
# TEST SUITE 3: World SquadCombatData Management
# ============================================================================

func test_world_squad_management() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 3: World SquadCombatData Management")
	print("-".repeat(80) + "\n")
	
	test_world_add_roaming_squad()
	test_world_get_squads_at_location()
	test_world_remove_roaming_squad()
	test_world_move_squad()
	test_world_get_adjacent_squads()

func create_test_world() -> World:
	var world = World.new()
	
	var loc1 = Location.new()
	loc1.location_id = "moscow"
	loc1.location_name = "Moscow"
	# Must use iterative assignment for typed arrays (GDScript requirement)
	for conn_id in ["smolensk"]:
		loc1.connections.append(conn_id)
	
	var loc2 = Location.new()
	loc2.location_id = "smolensk"
	loc2.location_name = "Smolensk"
	for conn_id in ["moscow", "minsk"]:
		loc2.connections.append(conn_id)
	
	var loc3 = Location.new()
	loc3.location_id = "minsk"
	loc3.location_name = "Minsk"
	for conn_id in ["smolensk"]:
		loc3.connections.append(conn_id)
	
	world.locations.append(loc1)
	world.locations.append(loc2)
	world.locations.append(loc3)
	world.build_travel_graph()
	
	return world

func create_test_strategic_squad(id: String, squad_name: String, location: String) -> SquadStrategicData:
	var squad = SquadStrategicData.new()
	squad.squad_id = id
	squad.squad_name = squad_name
	squad.current_location_id = location
	return squad

func test_world_add_roaming_squad() -> void:
	start_test("World: add_roaming_squad()")
	
	var world = create_test_world()
	var squad = create_test_strategic_squad("enemy_1", "Bandits", "moscow")
	
	assert_equal(world.roaming_squads.size(), 0, "initially no roaming squads")
	world.add_roaming_squad(squad)
	assert_equal(world.roaming_squads.size(), 1, "squad added")
	assert_equal(world.roaming_squads[0].squad_id, "enemy_1", "correct squad added")
	end_test()

func test_world_get_squads_at_location() -> void:
	start_test("World: get_squads_at_location()")
	
	var world = create_test_world()
	var squad1 = create_test_strategic_squad("enemy_1", "Bandits", "moscow")
	var squad2 = create_test_strategic_squad("enemy_2", "Raiders", "moscow")
	var squad3 = create_test_strategic_squad("enemy_3", "Wolves", "smolensk")
	
	world.add_roaming_squad(squad1)
	world.add_roaming_squad(squad2)
	world.add_roaming_squad(squad3)
	
	var moscow_squads = world.get_squads_at_location("moscow")
	assert_equal(moscow_squads.size(), 2, "2 squads in moscow")
	
	var smolensk_squads = world.get_squads_at_location("smolensk")
	assert_equal(smolensk_squads.size(), 1, "1 squad in smolensk")
	
	var minsk_squads = world.get_squads_at_location("minsk")
	assert_equal(minsk_squads.size(), 0, "0 squads in minsk")
	end_test()

func test_world_remove_roaming_squad() -> void:
	start_test("World: remove_roaming_squad()")
	
	var world = create_test_world()
	var squad1 = create_test_strategic_squad("enemy_1", "Bandits", "moscow")
	var squad2 = create_test_strategic_squad("enemy_2", "Raiders", "moscow")
	
	world.add_roaming_squad(squad1)
	world.add_roaming_squad(squad2)
	assert_equal(world.roaming_squads.size(), 2, "2 squads before removal")
	
	world.remove_roaming_squad("enemy_1")
	assert_equal(world.roaming_squads.size(), 1, "1 squad after removal")
	assert_equal(world.roaming_squads[0].squad_id, "enemy_2", "correct squad remains")
	end_test()

func test_world_move_squad() -> void:
	start_test("World: move_squad_to_location()")
	
	var world = create_test_world()
	var squad = create_test_strategic_squad("enemy_1", "Bandits", "moscow")
	world.add_roaming_squad(squad)
	
	assert_equal(world.get_squads_at_location("moscow").size(), 1, "squad starts in moscow")
	
	world.move_squad_to_location("enemy_1", "smolensk")
	
	assert_equal(world.get_squads_at_location("moscow").size(), 0, "no squads in moscow after move")
	assert_equal(world.get_squads_at_location("smolensk").size(), 1, "squad now in smolensk")
	end_test()

func test_world_get_adjacent_squads() -> void:
	start_test("World: get_adjacent_squads()")
	
	var world = create_test_world()
	var squad1 = create_test_strategic_squad("enemy_1", "Bandits", "smolensk")
	var squad2 = create_test_strategic_squad("enemy_2", "Raiders", "minsk")
	
	world.add_roaming_squad(squad1)
	world.add_roaming_squad(squad2)
	
	var adjacent_to_moscow = world.get_adjacent_squads("moscow")
	assert_equal(adjacent_to_moscow.size(), 1, "1 squad adjacent to moscow (in smolensk)")
	
	var adjacent_to_smolensk = world.get_adjacent_squads("smolensk")
	assert_equal(adjacent_to_smolensk.size(), 1, "1 squad adjacent to smolensk (in minsk)")
	end_test()

# ============================================================================
# TEST SUITE 4: Faction Army Management
# ============================================================================

func test_faction_army_management() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 4: Faction Army Management")
	print("-".repeat(80) + "\n")
	
	test_faction_add_army()
	test_faction_get_armies_at_location()
	test_faction_get_army_by_id()

func test_faction_add_army() -> void:
	start_test("Faction: add_army()")
	
	var faction = Faction.new()
	faction.faction_id = "faction_1"
	
	var army = create_test_strategic_squad("army_1", "Legion", "moscow")
	
	assert_equal(faction.armies.size(), 0, "initially no armies")
	faction.add_army(army)
	assert_equal(faction.armies.size(), 1, "army added")
	end_test()

func test_faction_get_armies_at_location() -> void:
	start_test("Faction: get_armies_at_location()")
	
	var faction = Faction.new()
	var army1 = create_test_strategic_squad("army_1", "Legion", "moscow")
	var army2 = create_test_strategic_squad("army_2", "Cohort", "smolensk")
	
	faction.add_army(army1)
	faction.add_army(army2)
	
	var moscow_armies = faction.get_armies_at_location("moscow")
	assert_equal(moscow_armies.size(), 1, "1 army in moscow")
	
	var minsk_armies = faction.get_armies_at_location("minsk")
	assert_equal(minsk_armies.size(), 0, "0 armies in minsk")
	end_test()

func test_faction_get_army_by_id() -> void:
	start_test("Faction: get_army_by_id()")
	
	var faction = Faction.new()
	var army = create_test_strategic_squad("army_1", "Legion", "moscow")
	faction.add_army(army)
	
	var found = faction.get_army_by_id("army_1")
	assert_not_null(found, "army found by id")
	assert_equal(found.squad_name, "Legion", "correct army returned")
	
	var not_found = faction.get_army_by_id("nonexistent")
	assert_true(not_found == null, "null for nonexistent id")
	end_test()

# ============================================================================
# TEST SUITE 5: Location Clue Management
# ============================================================================

func test_location_clue_management() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 5: Location Clue Management")
	print("-".repeat(80) + "\n")
	
	test_location_add_clue()
	test_location_get_active_clues()
	test_location_decay_clues()
	test_location_investigate_clues()

func test_location_add_clue() -> void:
	start_test("Location: add_clue()")
	
	var location = Location.new()
	location.location_id = "moscow"
	
	var clue = Clue.create_clue("Boot Prints", "squad_1", "warrior_1", 0, 30, "smolensk")
	
	assert_equal(location.clues.size(), 0, "initially no clues")
	location.add_clue(clue)
	assert_equal(location.clues.size(), 1, "clue added")
	end_test()

func test_location_get_active_clues() -> void:
	start_test("Location: get_active_clues()")
	
	var location = Location.new()
	
	var clue1 = Clue.new()
	clue1.clue_name = "Fresh Clue"
	clue1.created_turn = 5
	clue1.decay = 3
	
	var clue2 = Clue.new()
	clue2.clue_name = "Old Clue"
	clue2.created_turn = 0
	clue2.decay = 3
	
	location.add_clue(clue1)
	location.add_clue(clue2)
	
	var active_at_turn_6 = location.get_active_clues(6)
	assert_equal(active_at_turn_6.size(), 1, "only 1 active clue at turn 6")
	assert_equal(active_at_turn_6[0].clue_name, "Fresh Clue", "correct clue is active")
	end_test()

func test_location_decay_clues() -> void:
	start_test("Location: decay_clues()")
	
	var location = Location.new()
	
	var clue1 = Clue.new()
	clue1.clue_name = "Clue 1"
	clue1.decay = 2
	
	var clue2 = Clue.new()
	clue2.clue_name = "Clue 2"
	clue2.decay = 1
	
	location.add_clue(clue1)
	location.add_clue(clue2)
	
	location.decay_clues()
	assert_equal(location.clues.size(), 1, "clue with decay 1 removed after decay")
	assert_equal(location.clues[0].decay, 1, "remaining clue decay reduced")
	end_test()

func test_location_investigate_clues() -> void:
	start_test("Location: investigate_clues()")
	
	var location = Location.new()
	
	var clue = Clue.new()
	clue.clue_name = "Test Clue"
	clue.created_turn = 0
	clue.decay = 5
	clue.destination_id = "moscow"
	clue.detail_level = 50
	
	location.add_clue(clue)
	
	var results = location.investigate_clues(80, 2)
	assert_equal(results.size(), 1, "1 clue found")
	assert_true(results[0].has("clue_name"), "result has clue_name")
	assert_true(results[0].has("age_description"), "result has age_description")
	assert_true(results[0].has("destination_hint"), "result has destination_hint")
	end_test()

# ============================================================================
# TEST SUITE 6: SquadStrategicData Tactic Integration
# ============================================================================

func test_strategic_squad_tactic() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 6: SquadStrategicData Tactic Integration")
	print("-".repeat(80) + "\n")
	
	test_squad_default_tactic()
	test_squad_set_tactic()
	test_squad_get_warrior_by_id()

func test_squad_default_tactic() -> void:
	start_test("SquadStrategicData: default tactic")
	
	var squad = SquadStrategicData.new()
	var tactic = squad.get_tactic()
	
	assert_not_null(tactic, "default tactic exists")
	assert_equal(tactic.tactic_id, "balanced", "default is balanced")
	end_test()

func test_squad_set_tactic() -> void:
	start_test("SquadStrategicData: set_tactic()")
	
	var squad = SquadStrategicData.new()
	var aggressive = Tactic.create_aggressive_charge()
	
	squad.set_tactic(aggressive)
	
	assert_equal(squad.current_tactic.tactic_id, "aggressive_charge", "tactic changed")
	assert_equal(squad.get_tactic().action_count, 2, "tactic properties accessible")
	end_test()

func test_squad_get_warrior_by_id() -> void:
	start_test("SquadStrategicData: get_warrior_by_id()")
	
	var squad = SquadStrategicData.new()
	squad.warriors.clear()
	
	var warrior1 = Warrior.new()
	warrior1.id = "w1"
	warrior1.name = "Warrior One"
	
	var warrior2 = Warrior.new()
	warrior2.id = "w2"
	warrior2.name = "Warrior Two"
	
	squad.warriors.append(warrior1)
	squad.warriors.append(warrior2)
	
	var found = squad.get_warrior_by_id("w1")
	assert_not_null(found, "warrior found")
	assert_equal(found.name, "Warrior One", "correct warrior returned")
	
	var not_found = squad.get_warrior_by_id("nonexistent")
	assert_true(not_found == null, "null for nonexistent id")
	end_test()

# ============================================================================
# TEST SUITE 7: CombatBridge
# ============================================================================

func test_combat_bridge() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 7: CombatBridge")
	print("-".repeat(80) + "\n")
	
	test_combat_bridge_mappings()
	test_combat_bridge_clear()

func test_combat_bridge_mappings() -> void:
	start_test("CombatBridge: warrior/entity ID mapping")
	
	var bridge = CombatBridge.new()
	
	bridge.warrior_to_entity["w1"] = 100
	bridge.entity_to_warrior[100] = "w1"
	
	assert_equal(bridge.get_entity_for_warrior("w1"), 100, "warrior to entity mapping works")
	assert_equal(bridge.get_warrior_for_entity(100), "w1", "entity to warrior mapping works")
	assert_equal(bridge.get_warrior_for_entity(999), "", "returns empty for unknown entity")
	assert_equal(bridge.get_entity_for_warrior("unknown"), -1, "returns -1 for unknown warrior")
	end_test()

func test_combat_bridge_clear() -> void:
	start_test("CombatBridge: clear_mappings()")
	
	var bridge = CombatBridge.new()
	bridge.warrior_to_entity["w1"] = 100
	bridge.entity_to_warrior[100] = "w1"
	
	bridge.clear_mappings()
	
	assert_equal(bridge.warrior_to_entity.size(), 0, "warrior_to_entity cleared")
	assert_equal(bridge.entity_to_warrior.size(), 0, "entity_to_warrior cleared")
	assert_true(bridge.current_battle == null, "current_battle cleared")
	end_test()

# ============================================================================
# TEST SUITE 8: BattleOutcome System
# ============================================================================

func test_battle_outcome_system() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 8: BattleOutcome System")
	print("-".repeat(80) + "\n")
	
	test_battle_outcome_enum_values()
	test_tactic_determines_max_rounds()

func test_battle_outcome_enum_values() -> void:
	start_test("BattleOutcome: enum values exist")
	
	assert_equal(SquadBattleTypes.BattleOutcome.ONGOING, 0, "ONGOING is 0")
	assert_equal(SquadBattleTypes.BattleOutcome.ATTACKER_VICTORY, 1, "ATTACKER_VICTORY is 1")
	assert_equal(SquadBattleTypes.BattleOutcome.DEFENDER_VICTORY, 2, "DEFENDER_VICTORY is 2")
	assert_equal(SquadBattleTypes.BattleOutcome.DRAW, 3, "DRAW is 3")
	end_test()

func test_tactic_determines_max_rounds() -> void:
	start_test("Tactic: action_count determines max_rounds")
	
	# Test that each tactic type has the expected action_count that would be used as max_rounds
	var balanced = Tactic.create_balanced()
	assert_equal(balanced.action_count, 1, "balanced has action_count 1 (1 round)")
	
	var aggressive = Tactic.create_aggressive_charge()
	assert_equal(aggressive.action_count, 2, "aggressive_charge has action_count 2 (2 rounds)")
	
	var full_assault = Tactic.create_full_assault()
	assert_equal(full_assault.action_count, 3, "full_assault has action_count 3 (3 rounds)")
	
	var defensive = Tactic.create_defensive_formation()
	assert_equal(defensive.action_count, 0, "defensive_formation has action_count 0 (0 rounds - pure defense)")
	
	var guerilla = Tactic.create_guerilla_defence()
	assert_equal(guerilla.action_count, 1, "guerilla_defence has action_count 1 (1 round)")
	end_test()

# ============================================================================
# TEST SUITE 9: Tactic-Based Battle Rounds
# ============================================================================

func test_tactic_based_rounds() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 9: Tactic-Based Battle Rounds")
	print("-".repeat(80) + "\n")
	
	test_tactic_action_vs_reaction_balance()
	test_combat_bridge_creates_battle_with_tactic()

func test_tactic_action_vs_reaction_balance() -> void:
	start_test("Tactic: action_count + reaction_count patterns")
	
	# Balanced: equal actions and reactions
	var balanced = Tactic.create_balanced()
	assert_equal(balanced.action_count, balanced.reaction_count, "balanced has equal actions and reactions")
	
	# Aggressive: more actions than reactions
	var aggressive = Tactic.create_aggressive_charge()
	assert_true(aggressive.action_count > aggressive.reaction_count, "aggressive has more actions than reactions")
	
	# Guerilla: more reactions than actions
	var guerilla = Tactic.create_guerilla_defence()
	assert_true(guerilla.reaction_count > guerilla.action_count, "guerilla has more reactions than actions")
	
	# Full assault: max actions, no reactions
	var full_assault = Tactic.create_full_assault()
	assert_equal(full_assault.action_count, 3, "full assault has 3 actions")
	assert_equal(full_assault.reaction_count, 0, "full assault has 0 reactions")
	
	# Defensive: no actions, max reactions
	var defensive = Tactic.create_defensive_formation()
	assert_equal(defensive.action_count, 0, "defensive has 0 actions")
	assert_equal(defensive.reaction_count, 3, "defensive has 3 reactions")
	end_test()

func test_combat_bridge_creates_battle_with_tactic() -> void:
	start_test("CombatBridge: create_battle() applies tactic to battle")
	
	var bridge = CombatBridge.new()
	
	# Create minimal strategic squads for testing
	var player_squad = SquadStrategicData.new()
	player_squad.squad_id = "player"
	player_squad.squad_name = "Player SquadCombatData"
	
	var enemy_squad = SquadStrategicData.new()
	enemy_squad.squad_id = "enemy"
	enemy_squad.squad_name = "Enemy SquadCombatData"
	
	# Create warriors with combat stats
	var warrior = Warrior.new()
	warrior.id = "w1"
	warrior.name = "Test Warrior"
	warrior.combat_stats = EntityBaseStats.new()
	player_squad.warriors.append(warrior)
	
	var enemy_warrior = Warrior.new()
	enemy_warrior.id = "e1"
	enemy_warrior.name = "Enemy Warrior"
	enemy_warrior.combat_stats = EntityBaseStats.new()
	enemy_squad.warriors.append(enemy_warrior)
	
	# Test with aggressive charge tactic
	var aggressive = Tactic.create_aggressive_charge()
	var battle = bridge.create_battle(player_squad, enemy_squad, aggressive)
	
	assert_not_null(battle, "battle created")
	assert_equal(battle.attacker_tactic.tactic_id, "aggressive_charge", "attacker_tactic set")
	assert_equal(battle.max_rounds, 2, "max_rounds set from tactic action_count")
	end_test()
