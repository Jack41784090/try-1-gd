extends Node
## Bandit System Demo — Tests desperation-driven bandit spawning, route danger,
## trade suppression, and mercenary demand using the real pipeline.
##
## Usage: godot-mono --headless --path . scenes/demos/bandit_demo.tscn

const SCENARIO_PATH := "res://resources/scenarios/goetz-official/scenario.tres"
const HeadlessView = preload("res://src/demos/headless_strategy_view.gd")
const HOURS_PER_ECONOMY_TURN := 24
const ECONOMY_TICKS := 10

var presenter: StrategyPresenter
var world: World
var _assertions_passed := 0
var _assertions_failed := 0


func _ready() -> void:
	Log.set_level(Log.Level.WARN)
	print("")
	print("╔══════════════════════════════════════════════════════════╗")
	print("║       BANDIT SYSTEM DEMO — Desperation Spawning        ║")
	print("╚══════════════════════════════════════════════════════════╝")
	print("")

	await _setup_presenter()
	_test_bandit_faction_exists()
	_test_pressure_calculation()
	await _test_forced_spawn()
	await _test_route_danger()
	await _test_mercenary_demand()
	await _test_bandit_lifecycle()
	_print_results()


func _setup_presenter() -> void:
	var mock_view := HeadlessView.new()
	add_child(mock_view)
	mock_view.setup_headless()

	presenter = StrategyPresenter.new()
	presenter.scenario_path = SCENARIO_PATH
	presenter.is_demo_scenario = false
	mock_view.add_child(presenter)
	await presenter.bind_view(mock_view)

	world = presenter.game_scenario.world
	assert(world.economy_engine != null, "Economy engine not initialized")
	print("  Scenario loaded. Locations: %d, Roaming squads: %d" % [
		world.locations.size(), world.roaming_squads.size()])
	print("")


func _test_bandit_faction_exists() -> void:
	print("── Test: Bandit faction exists ──")
	var bandit_faction: Faction = null
	for faction in presenter.game_scenario.factions:
		if faction.faction_id == "bandits":
			bandit_faction = faction
			break
	_assert("Bandit faction registered", bandit_faction != null)
	_assert("Bandit faction name", bandit_faction.faction_name == "Bandits" if bandit_faction else false)
	print("")


func _test_pressure_calculation() -> void:
	print("── Test: Pressure calculation ──")
	var spawner := BanditSpawner.new()
	for loc in world.locations:
		if loc.population == null:
			continue
		var pressure := spawner.calculate_pressure(loc)
		print("  %s: pressure=%.3f (pop=%d)" % [loc.location_name, pressure, loc.population.size()])

	var test_loc := _get_first_economy_location()
	if test_loc:
		var pressure := spawner.calculate_pressure(test_loc)
		_assert("Pressure is non-negative", pressure >= 0.0)
		_assert("Pressure is bounded", pressure <= 3.0)
	print("")


func _test_forced_spawn() -> void:
	print("── Test: Forced bandit spawning (low satisfaction) ──")
	var spawner := BanditSpawner.new()
	var bandit_faction := _get_bandit_faction()
	var test_loc := _get_first_economy_location()
	_assert("Test location found", test_loc != null)
	if test_loc == null:
		return

	for person in test_loc.population.people:
		person.satisfaction = 10.0

	var pressure := spawner.calculate_pressure(test_loc)
	print("  Forced pressure at %s: %.3f" % [test_loc.location_name, pressure])
	_assert("High pressure from low satisfaction", pressure > BanditSpawner.SPAWN_THRESHOLD)

	var initial_bandit_count := spawner.count_total_bandits(world)
	var squad: SquadData = spawner.create_bandit_squad(test_loc, world)
	world.add_roaming_squad(squad)
	bandit_faction.add_army(squad)
	presenter.ai_fleet.register_squad(squad, BanditSpawner.BANDIT_PROFILE_PATH)

	_assert("Bandit squad created", squad != null)
	_assert("Bandit has BANDIT role", squad.squad_role == StrategyTypes.SquadRole.BANDIT)
	_assert("Bandit has warriors", squad.get_living_warriors().size() > 0)
	_assert("Bandit count increased", spawner.count_total_bandits(world) == initial_bandit_count + 1)
	_assert("Bandit in world roaming_squads", world.roaming_squads.has(squad))
	_assert("Bandit in faction armies", bandit_faction.armies.has(squad))

	print("  Spawned: %s (%d warriors) at %s" % [
		squad.squad_name, squad.get_living_warriors().size(), squad.current_location_id])
	print("")


func _test_route_danger() -> void:
	print("── Test: Route danger from bandits ──")
	var danger_calc := RouteDangerCalculator.new()
	var test_loc := _get_first_economy_location()
	if test_loc == null or test_loc.connections == null or test_loc.connections.tt.is_empty():
		print("  SKIP — no connections")
		return

	var neighbor_id: String = test_loc.connections.tt[0].to_location_id
	var route: Array[String] = [test_loc.location_id, neighbor_id]
	var safety_before := danger_calc.calculate_route_safety(route, world)
	print("  Route %s → %s safety BEFORE bandits: %.3f" % [test_loc.location_id, neighbor_id, safety_before])

	var bandit_loc_id := ""
	for squad in world.roaming_squads:
		if squad.squad_role == StrategyTypes.SquadRole.BANDIT:
			bandit_loc_id = squad.current_location_id
			break

	if bandit_loc_id.is_empty():
		print("  SKIP — no bandits to test")
		return

	var bandit_route: Array[String] = [bandit_loc_id]
	for loc in world.locations:
		if loc.location_id != bandit_loc_id and loc.is_connected_to(bandit_loc_id):
			bandit_route.append(loc.location_id)
			break

	if bandit_route.size() >= 2:
		danger_calc.clear_cache()
		var safety_with_bandits := danger_calc.calculate_route_safety(bandit_route, world)
		print("  Route through bandit area safety: %.3f" % safety_with_bandits)
		_assert("Route with bandits is less safe", safety_with_bandits < 1.0)

	print("")


func _test_mercenary_demand() -> void:
	print("── Test: Mercenary demand calculation ──")
	var demand_calc := MercenaryDemandCalculator.new()
	var test_loc := _get_first_economy_location()
	if test_loc == null:
		return

	var demand := demand_calc.calculate_demand(test_loc, world)
	print("  Mercenary demand at %s: %.3f" % [test_loc.location_name, demand])

	var bandit_nearby := demand_calc.find_nearest_bandit(test_loc, world)
	if bandit_nearby:
		print("  Nearest bandit: %s at %s" % [bandit_nearby.squad_name, bandit_nearby.current_location_id])
		_assert("Demand exists when bandits present", demand > 0.0)
		var bounty := demand_calc.get_bounty(bandit_nearby)
		print("  Bounty: %.0f gold" % bounty)
		_assert("Bounty is positive", bounty > 0.0)
	else:
		print("  No bandits nearby — demand should be 0")
		_assert("No demand without bandits", demand == 0.0)

	print("")


func _test_bandit_lifecycle() -> void:
	print("── Test: Bandit lifecycle (disband on low morale) ──")
	var spawner := BanditSpawner.new()
	var bandit_faction := _get_bandit_faction()

	var test_squad := SquadDataFactory.create_squad(
		"bandit_test_lifecycle",
		"Test Bandits",
		100.0,
		0,
		5,
		0.0,
		"",
		"",
		StrategyTypes.SquadRole.BANDIT,
	)

	var warrior := WarriorFactory.create_warrior(
		EntityClasses.Types.Landsknecht,
		"bandit_test_w0", "Test Bandit",
		StrategyTypes.Religion.CATHOLIC,
		EntityBaseStats.new(),
	)
	warrior.morale = 5.0
	test_squad.add_warrior(warrior)

	_assert("Low morale triggers disband", spawner.check_disband(test_squad))

	warrior.morale = 50.0
	_assert("Normal morale does not disband", not spawner.check_disband(test_squad))

	warrior.is_injured = true
	_assert("All injured triggers disband", spawner.check_disband(test_squad))

	warrior.is_injured = false
	warrior.is_dead = true
	_assert("All dead triggers disband", spawner.check_disband(test_squad))

	print("  Lifecycle checks passed")
	print("")


func _test_economy_tick_integration() -> void:
	print("── Test: Economy tick integration ──")
	var initial_bandits := _count_bandits()
	print("  Bandits before ticks: %d" % initial_bandits)

	for i in range(ECONOMY_TICKS):
		for _h in range(HOURS_PER_ECONOMY_TURN):
			presenter.game_clock.force_tick()
			await presenter.tick_completed

	var final_bandits := _count_bandits()
	print("  Bandits after %d economy ticks: %d" % [ECONOMY_TICKS, final_bandits])
	print("")


func _get_first_economy_location() -> Location:
	var best: Location = null
	for loc in world.locations:
		if loc.population != null and loc.population.size() > 0:
			if best == null or loc.population.size() > best.population.size():
				best = loc
	return best


func _get_bandit_faction() -> Faction:
	for faction in presenter.game_scenario.factions:
		if faction.faction_id == "bandits":
			return faction
	return null


func _count_bandits() -> int:
	var count := 0
	for squad in world.roaming_squads:
		if squad.squad_role == StrategyTypes.SquadRole.BANDIT:
			count += 1
	return count


func _assert(description: String, condition: bool) -> void:
	if condition:
		_assertions_passed += 1
		print("  ✓ %s" % description)
	else:
		_assertions_failed += 1
		print("  ✗ FAIL: %s" % description)


func _print_results() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  Results: %d passed, %d failed" % [_assertions_passed, _assertions_failed])
	if _assertions_failed > 0:
		print("  *** FAILURES DETECTED ***")
	else:
		print("  All assertions passed!")
	print("═══════════════════════════════════════════════════════════")
	print("")

	if _assertions_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)
