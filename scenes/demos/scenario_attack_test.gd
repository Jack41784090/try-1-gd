extends Node

## Headless test for scenario boot and combat attack flow
## Simulates booting up combat-test-scenario and attacking the Forest Bandits
## Run with: godot --headless --path . -s scenes/demos/scenario_attack_test.gd

const SCENARIO_PATH = "res://resources/scenarios/combat-test/combat-test-scenario.tres"
const PLAYER_SQUAD_PATH = "res://resources/strategy-squads/test-player-squad.tres"

var test_count := 0
var passed_count := 0
var failed_count := 0

var game_scenario: GameScenario
var combat_controller: CombatController

func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("SCENARIO ATTACK TEST - HEADLESS")
	print("Testing: Boot scenario → Find Forest Bandits → Execute Attack")
	print("=".repeat(80) + "\n")
	
	run_test_sequence()

func run_test_sequence() -> void:
	# Phase 1: Load and initialize scenario
	print_phase("1. LOADING SCENARIO")
	var scenario_loaded = test_load_scenario()
	if not scenario_loaded:
		print("✗ CRITICAL: Failed to load scenario, aborting tests")
		_finish_tests()
		return
	
	# Phase 2: Verify world state
	print_phase("2. VERIFYING WORLD STATE")
	test_verify_world_state()
	
	# Phase 3: Find Forest Bandits
	print_phase("3. FINDING FOREST BANDITS")
	var bandits_found = test_find_forest_bandits()
	if not bandits_found:
		print("✗ CRITICAL: Forest Bandits not found, aborting attack test")
		_finish_tests()
		return
	
	# Phase 4: Execute Attack Activity
	print_phase("4. EXECUTING ATTACK ACTIVITY")
	await test_execute_attack()
	
	# Phase 5: Verify Combat Results
	print_phase("5. VERIFYING COMBAT RESULTS")
	test_verify_combat_results()
	
	_finish_tests()

func print_phase(phase_name: String) -> void:
	print("\n" + "-".repeat(60))
	print(phase_name)
	print("-".repeat(60))

#region Test Helper Functions

func start_test(test_name: String) -> void:
	test_count += 1
	print("  [TEST %d] %s" % [test_count, test_name])

func assert_true(condition: bool, message: String) -> bool:
	if condition:
		passed_count += 1
		print("    ✓ PASS: %s" % message)
		return true
	else:
		failed_count += 1
		print("    ✗ FAIL: %s" % message)
		return false

func assert_equal(actual, expected, message: String) -> bool:
	if actual == expected:
		passed_count += 1
		print("    ✓ PASS: %s (got %s)" % [message, str(actual)])
		return true
	else:
		failed_count += 1
		print("    ✗ FAIL: %s (expected %s, got %s)" % [message, str(expected), str(actual)])
		return false

func assert_not_null(value, message: String) -> bool:
	if value != null:
		passed_count += 1
		print("    ✓ PASS: %s" % message)
		return true
	else:
		failed_count += 1
		print("    ✗ FAIL: %s (was null)" % message)
		return false

func assert_greater_than(actual: float, threshold: float, message: String) -> bool:
	if actual > threshold:
		passed_count += 1
		print("    ✓ PASS: %s (%.2f > %.2f)" % [message, actual, threshold])
		return true
	else:
		failed_count += 1
		print("    ✗ FAIL: %s (%.2f not > %.2f)" % [message, actual, threshold])
		return false

#endregion

#region Phase 1: Load Scenario

func test_load_scenario() -> bool:
	start_test("Load scenario resource from path")
	var scenario_resource = load(SCENARIO_PATH)
	if not assert_not_null(scenario_resource, "Scenario resource loaded"):
		return false
	
	start_test("Scenario is GameScenario type")
	if not assert_true(scenario_resource is GameScenario, "Resource is GameScenario"):
		return false
	
	game_scenario = scenario_resource
	
	start_test("Load player squad resource")
	var player_squad = load(PLAYER_SQUAD_PATH)
	if not assert_not_null(player_squad, "Player squad loaded"):
		return false
	
	start_test("Initialize scenario with player squad")
	game_scenario.initialize({
		"player_squad": player_squad
	})
	
	if not assert_true(game_scenario.world != null, "World initialized"):
		return false
	if not assert_true(game_scenario.player_squad != null, "Player squad assigned"):
		return false
	if not assert_true(game_scenario.current_location != null, "Current location set"):
		return false
	
	print("\n  [INFO] Scenario initialized successfully:")
	print("    - World: %s" % game_scenario.world)
	print("    - Player Squad: %s" % game_scenario.player_squad.squad_name)
	print("    - Starting Location: %s" % game_scenario.current_location.location_name)
	print("    - Turn: %d" % game_scenario.world.turn_count)
	
	return true

#endregion

#region Phase 2: Verify World State

func test_verify_world_state() -> void:
	start_test("World has locations")
	assert_greater_than(game_scenario.world.locations.size(), 0, "World has at least 1 location")
	
	start_test("World has roaming squads")
	assert_greater_than(game_scenario.world.roaming_squads.size(), 0, "World has roaming squads")
	
	start_test("Player squad has warriors")
	var living_warriors = game_scenario.player_squad.get_living_warriors()
	assert_greater_than(living_warriors.size(), 0, "Player squad has living warriors")
	
	print("\n  [INFO] World state:")
	print("    - Locations: %d" % game_scenario.world.locations.size())
	for loc in game_scenario.world.locations:
		print("      • %s (%s)" % [loc.location_name, loc.location_id])
	print("    - Roaming Squads: %d" % game_scenario.world.roaming_squads.size())
	for squad in game_scenario.world.roaming_squads:
		print("      • %s at %s (%d warriors)" % [squad.squad_name, squad.current_location_id, squad.get_living_warriors().size()])
	print("    - Player Warriors: %d" % living_warriors.size())
	for warrior in living_warriors:
		print("      • %s" % warrior.warrior_name)

#endregion

#region Phase 3: Find Forest Bandits

func test_find_forest_bandits() -> bool:
	start_test("Search for Forest Bandits in roaming squads")
	
	var forest_bandits: StrategicSquad = null
	for squad in game_scenario.world.roaming_squads:
		print("    [SEARCH] Checking squad: %s" % squad.squad_name)
		if squad.squad_name == "Forest Bandits":
			forest_bandits = squad
			break
	
	if not assert_not_null(forest_bandits, "Forest Bandits found"):
		return false
	
	start_test("Forest Bandits have warriors")
	var bandit_warriors = forest_bandits.get_living_warriors()
	assert_greater_than(bandit_warriors.size(), 0, "Bandits have living warriors")
	
	start_test("Forest Bandits have a location")
	assert_true(forest_bandits.current_location_id != "", "Bandits have current location")
	
	print("\n  [INFO] Forest Bandits details:")
	print("    - Squad ID: %s" % forest_bandits.squad_id)
	print("    - Location: %s" % forest_bandits.current_location_id)
	print("    - Warriors: %d" % bandit_warriors.size())
	for warrior in bandit_warriors:
		print("      • %s" % warrior.warrior_name)
	
	# Move player to bandit location for attack
	start_test("Move player to bandit location for attack")
	var bandit_location = forest_bandits.current_location_id
	game_scenario.current_location = game_scenario.world.get_location_by_id(bandit_location)
	game_scenario.player_squad.set_location(bandit_location)
	assert_equal(game_scenario.player_squad.current_location_id, bandit_location, "Player moved to bandit location")
	
	return true

#endregion

#region Phase 4: Execute Attack

func test_execute_attack() -> void:
	start_test("Initialize CombatController")
	combat_controller = CombatController.new()
	assert_not_null(combat_controller, "CombatController created")
	
	# Find enemy squad at current location
	start_test("Find enemies at current location")
	var enemies_here = game_scenario.world.get_squads_at_location(game_scenario.current_location.location_id)
	assert_greater_than(enemies_here.size(), 0, "Enemies found at location")
	
	if enemies_here.is_empty():
		print("    [ERROR] No enemies at location, cannot test combat")
		return
	
	var enemy_squad = enemies_here[0]
	print("\n  [INFO] Initiating combat against: %s" % enemy_squad.squad_name)
	
	# Inject combat context (simulating what TrainingScreen does)
	start_test("Inject combat context")
	# We don't have a viewport in headless mode, so we create a mock
	var mock_viewport = SubViewport.new()
	add_child(mock_viewport)
	var mock_overlay = CanvasLayer.new()
	add_child(mock_overlay)
	
	var combat_options = combat_controller.inject_context(
		game_scenario.player_squad,
		enemy_squad,
		mock_viewport,
		mock_overlay
	)
	
	assert_not_null(combat_options, "Combat options returned")
	
	print("\n  [INFO] Combat options:")
	print("    - Can Fight: %s" % combat_options.get("can_fight", false))
	print("    - Can Flee: %s (%.1f%% chance)" % [combat_options.get("can_flee", false), combat_options.get("flee_chance", 0.0) * 100])
	print("    - Can Negotiate: %s (%.1f%% chance)" % [combat_options.get("can_negotiate", false), combat_options.get("negotiate_chance", 0.0) * 100])
	print("    - Enemy: %s (%d warriors)" % [combat_options.get("enemy_name", "Unknown"), combat_options.get("enemy_count", 0)])
	
	# Execute FIGHT choice
	start_test("Process FIGHT choice")
	print("\n  [COMBAT] Executing tactical combat...")
	print("  [COMBAT] This will run the full SquadBattle simulation")
	
	var combat_result: CombatController.CombatResult = await combat_controller.process_intermission_choice(
		CombatController.IntermissionChoice.FIGHT
	)
	
	assert_not_null(combat_result, "Combat result returned")
	
	print("\n  [COMBAT RESULT]")
	print("    - Victory: %s" % combat_result.victory)
	print("    - Fled: %s" % combat_result.fled)
	print("    - Negotiated: %s" % combat_result.negotiated)
	print("    - Turns Elapsed: %d" % combat_result.turns_elapsed)
	print("    - Morale Change: %+.1f" % combat_result.morale_change)
	print("    - Player Casualties: %d" % combat_result.player_casualties.size())
	print("    - Enemy Casualties: %d" % combat_result.enemy_casualties.size())
	if combat_result.loot.size() > 0:
		print("    - Loot: %s" % combat_result.loot)
	
	# Cleanup mock nodes
	mock_viewport.queue_free()
	mock_overlay.queue_free()

#endregion

#region Phase 5: Verify Results

func test_verify_combat_results() -> void:
	start_test("Combat concluded properly")
	# Combat should have ended one way or another
	assert_true(not combat_controller.is_in_combat, "Combat is no longer active")
	
	start_test("Player squad still exists after combat")
	assert_not_null(game_scenario.player_squad, "Player squad still valid")
	
	start_test("Player squad has warriors (some may be dead)")
	var player_warriors = game_scenario.player_squad.warriors
	assert_greater_than(player_warriors.size(), 0, "Player squad has warriors array")
	
	print("\n  [POST-COMBAT STATUS]")
	print("    Player Squad: %s" % game_scenario.player_squad.squad_name)
	print("    Living Warriors: %d" % game_scenario.player_squad.get_living_warriors().size())
	print("    Morale: %.1f" % game_scenario.player_squad.get_morale())
	print("    Money: %.1f" % game_scenario.player_squad.money)
	print("    Food: %d" % game_scenario.player_squad.food)

#endregion

func _finish_tests() -> void:
	print("\n" + "=".repeat(80))
	print("SCENARIO ATTACK TEST - FINAL RESULTS")
	print("=".repeat(80))
	print("Total Tests: %d" % test_count)
	print("Passed: %d" % passed_count)
	print("Failed: %d" % failed_count)
	
	if failed_count == 0:
		print("\n✓ ALL TESTS PASSED!")
	else:
		print("\n✗ SOME TESTS FAILED!")
	
	print("=".repeat(80) + "\n")
	
	# Exit with appropriate code
	get_tree().quit(failed_count)
