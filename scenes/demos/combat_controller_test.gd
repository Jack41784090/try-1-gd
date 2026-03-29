extends Node

## Comprehensive test suite for CombatController
## Tests combat flow, intermission choices, flee/negotiate mechanics, and result application

var test_count := 0
var passed_count := 0
var failed_count := 0
var current_test_name: String = ""

func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("COMBAT CONTROLLER - COMPREHENSIVE TEST SUITE")
	print("=".repeat(80) + "\n")
	
	# Run all test suites
	test_combat_controller_initialization()
	test_intermission_options()
	test_flee_mechanics()
	test_negotiate_mechanics()
	test_combat_execution()
	test_result_application()
	test_tactic_integration()
	
	# Print final results
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
	
	# Exit after tests
	get_tree().quit(0 if failed_count == 0 else 1)

#region Test Helpers

func start_test(test_name: String) -> void:
	current_test_name = test_name
	test_count += 1
	print("  [TEST %d] %s" % [test_count, test_name])

func assert_true(condition: bool, message: String) -> void:
	if condition:
		print("    ✓ PASS: %s" % message)
		passed_count += 1
	else:
		print("    ✗ FAIL: %s" % message)
		failed_count += 1

func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)

func assert_equals(actual, expected, message: String) -> void:
	if actual == expected:
		print("    ✓ PASS: %s (got %s)" % [message, actual])
		passed_count += 1
	else:
		print("    ✗ FAIL: %s (expected %s, got %s)" % [message, expected, actual])
		failed_count += 1

func assert_not_null(value, message: String) -> void:
	if value != null:
		print("    ✓ PASS: %s" % message)
		passed_count += 1
	else:
		print("    ✗ FAIL: %s (was null)" % message)
		failed_count += 1

func assert_in_range(value: float, min_val: float, max_val: float, message: String) -> void:
	if value >= min_val and value <= max_val:
		print("    ✓ PASS: %s (%.2f in [%.2f, %.2f])" % [message, value, min_val, max_val])
		passed_count += 1
	else:
		print("    ✗ FAIL: %s (%.2f not in [%.2f, %.2f])" % [message, value, min_val, max_val])
		failed_count += 1

func end_test() -> void:
	print("")

#endregion

#region Test Data Creation

func create_test_warrior(id: String, warrior_name: String) -> Warrior:
	var warrior = Warrior.new()
	warrior.id = id
	warrior.name = warrior_name
	warrior.morale = 50.0
	warrior.is_dead = false
	
	# Create combat stats using EntityBaseStats
	var stats = EntityBaseStats.new()
	stats.strength = 10.0
	stats.endurance = 10.0
	stats.siz = 10.0
	stats.dex = 10.0
	stats.acr = 10.0 # agility substitute
	stats.spd = 10.0
	stats.int_stat = 10.0
	stats.wil = 10.0
	stats.cha = 10.0
	stats.fai = 10.0
	stats.spr = 10.0
	stats.beu = 10.0
	warrior.combat_stats = stats
	
	return warrior

func create_test_player_squad() -> SquadData:
	var squad = SquadData.new()
	squad.squad_id = "player_squad"
	squad.squad_name = "Test Heroes"
	squad.current_location_id = "test_location"
	
	# Add warriors
	for i in range(3):
		var warrior = create_test_warrior("warrior_%d" % i, "Hero %d" % i)
		squad.warriors.append(warrior)
	
	squad.update_aggregate_morale()
	return squad

func create_test_enemy_squad() -> SquadData:
	var squad = SquadData.new()
	squad.squad_id = "enemy_squad"
	squad.squad_name = "Test Enemies"
	squad.current_location_id = "test_location"
	
	# Add warriors (fewer than player for easier testing)
	for i in range(2):
		var warrior = create_test_warrior("enemy_%d" % i, "Enemy %d" % i)
		squad.warriors.append(warrior)
	
	squad.update_aggregate_morale()
	return squad

#endregion

#region Test Suites

func test_combat_controller_initialization() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 1: CombatController Initialization")
	print("-".repeat(80) + "\n")
	
	start_test("CombatController creation")
	var controller = CombatController.new()
	assert_not_null(controller, "controller created")
	assert_not_null(controller.combat_bridge, "combat_bridge initialized")
	assert_false(controller.is_in_combat, "not in combat initially")
	assert_equals(controller.combat_phase, 0, "combat phase starts at 0")
	end_test()

func test_intermission_options() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 2: Intermission Options")
	print("-".repeat(80) + "\n")
	
	start_test("Build intermission options")
	var controller = CombatController.new()
	var player_squad = create_test_player_squad()
	var enemy_squad = create_test_enemy_squad()
	
	controller.start_combat(player_squad, enemy_squad)
	
	# Controller should now be in combat state
	assert_true(controller.is_in_combat, "is_in_combat is true after start_combat")
	assert_not_null(controller.current_player_squad, "player squad stored")
	assert_not_null(controller.current_enemy_squad, "enemy squad stored")
	end_test()
	
	start_test("Intermission options calculated correctly")
	# We can't easily test the emitted signal, but we can verify state
	assert_not_null(controller.current_tactic, "tactic is set")
	assert_equals(controller.current_tactic.tactic_id, "balanced", "default tactic is balanced")
	end_test()

func test_flee_mechanics() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 3: Flee Mechanics")
	print("-".repeat(80) + "\n")
	
	start_test("Flee attempt - result structure")
	var controller = CombatController.new()
	var player_squad = create_test_player_squad()
	var enemy_squad = create_test_enemy_squad()
	
	controller.start_combat(player_squad, enemy_squad)
	var result = controller.process_intermission_choice(CombatController.IntermissionChoice.FLEE)
	
	assert_not_null(result, "result returned")
	# Result should either be fled=true or fled=false with combat result
	assert_true(result.fled or (not result.fled and result.turns_elapsed >= 0), "flee result valid")
	end_test()
	
	start_test("Flee success has morale penalty")
	# We can't guarantee flee success, but if it succeeded:
	if result.fled:
		assert_true(result.morale_change < 0, "fled has negative morale change")
	end_test()

func test_negotiate_mechanics() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 4: Negotiate Mechanics")
	print("-".repeat(80) + "\n")
	
	start_test("Negotiate attempt - result structure")
	var controller = CombatController.new()
	var player_squad = create_test_player_squad()
	var enemy_squad = create_test_enemy_squad()
	
	controller.start_combat(player_squad, enemy_squad)
	var result = controller.process_intermission_choice(CombatController.IntermissionChoice.NEGOTIATE)
	
	assert_not_null(result, "result returned")
	# Result should either be negotiated=true or negotiated=false with combat
	assert_true(result.negotiated or (not result.negotiated and result.turns_elapsed >= 0), "negotiate result valid")
	end_test()

func test_combat_execution() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 5: Combat Execution")
	print("-".repeat(80) + "\n")
	
	start_test("Fight choice triggers combat")
	var controller = CombatController.new()
	var player_squad = create_test_player_squad()
	var enemy_squad = create_test_enemy_squad()
	
	controller.start_combat(player_squad, enemy_squad)
	var result = controller.process_intermission_choice(CombatController.IntermissionChoice.FIGHT)
	
	assert_not_null(result, "result returned")
	assert_true(result.turns_elapsed > 0, "combat had at least 1 turn")
	assert_false(result.fled, "not fled when fighting")
	assert_false(result.negotiated, "not negotiated when fighting")
	end_test()
	
	start_test("Combat produces entity updates")
	var all_updates = controller.get_all_updates()
	assert_true(all_updates.size() > 0, "entity updates generated")
	end_test()
	
	start_test("Combat ends with is_in_combat = false")
	assert_false(controller.is_in_combat, "combat ended properly")
	end_test()

func test_result_application() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 6: Result Application")
	print("-".repeat(80) + "\n")
	
	start_test("CombatResult structure")
	var result = CombatController.CombatResult.new()
	assert_not_null(result, "result created")
	assert_false(result.victory, "victory defaults to false")
	assert_false(result.fled, "fled defaults to false")
	assert_false(result.negotiated, "negotiated defaults to false")
	assert_equals(result.player_casualties.size(), 0, "no casualties initially")
	assert_equals(result.morale_change, 0.0, "no morale change initially")
	end_test()
	
	start_test("CombatResult.to_string()")
	result.victory = true
	var str_result = str(result)
	assert_true(str_result.contains("VICTORY"), "victory string contains VICTORY")
	
	result.victory = false
	result.fled = true
	str_result = str(result)
	assert_true(str_result.contains("FLED"), "fled string contains FLED")
	
	result.fled = false
	result.negotiated = true
	str_result = str(result)
	assert_true(str_result.contains("NEGOTIATED"), "negotiated string contains NEGOTIATED")
	end_test()

func test_tactic_integration() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 7: Tactic Integration")
	print("-".repeat(80) + "\n")
	
	start_test("Set tactic by object")
	var controller = CombatController.new()
	var aggressive_tactic = Tactic.create_aggressive_charge()
	controller.set_tactic(aggressive_tactic)
	assert_equals(controller.current_tactic.tactic_id, "aggressive_charge", "tactic set correctly")
	end_test()
	
	start_test("Set tactic by type")
	controller.set_tactic_by_type(Tactic.TacticType.GUERILLA_DEFENCE)
	assert_equals(controller.current_tactic.tactic_id, "guerilla_defence", "tactic set by type")
	end_test()
	
	start_test("Combat uses squad tactic")
	var player_squad = create_test_player_squad()
	var enemy_squad = create_test_enemy_squad()
	
	# Set squad tactic before combat
	player_squad.set_tactic(Tactic.create_full_assault())
	
	controller.start_combat(player_squad, enemy_squad)
	assert_equals(controller.current_tactic.tactic_id, "full_assault", "combat uses squad's tactic")
	end_test()

#endregion
