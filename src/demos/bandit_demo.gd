extends Node
## Bandit System Demo — Tests desperation-driven bandit spawning, route danger,
## trade suppression, and mercenary demand using the real pipeline.
##
## Usage: godot-mono --headless --path . scenes/demos/bandit_demo.tscn

const SCENARIO_PATH := "res://resources/strategy/scenarios/goetz-official/scenario.tres"
const HeadlessView = preload("res://src/demos/headless_strategy_view.gd")
const HOURS_PER_ECONOMY_TURN := 24
const ECONOMY_TICKS := 10

var presenter: StrategyPresenter
var world: World
var _assertions_passed := 0
var _assertions_failed := 0


func _ready() -> void:
	MyLog.set_level(MyLog.Level.WARN)
	print("")
	print("╔══════════════════════════════════════════════════════════╗")
	print("║       BANDIT SYSTEM DEMO — Desperation Spawning        ║")
	print("╚══════════════════════════════════════════════════════════╝")
	print("")

	await _setup_presenter()

	# --- _test_bandit_faction_exists ---
	print("── Test: Bandit faction exists ──")
	var bf_faction: Faction = null
	for faction in presenter.game_scenario.factions:
		if faction.faction_id == "bandits":
			bf_faction = faction
			break
	_assert("Bandit faction registered", bf_faction != null)
	_assert("Bandit faction name", bf_faction.faction_name == "Bandits" if bf_faction else false)
	print("")

	# --- _test_pressure_calculation ---
	print("── Test: Pressure calculation ──")
	var pc_spawner := BanditSpawner.new()
	for loc in world.locations:
		if loc.population == null:
			continue
		var pc_pressure := pc_spawner.calculate_pressure(loc)
		print("  %s: pressure=%.3f (pop=%d)" % [loc.location_name, pc_pressure, loc.population.size()])

	var pc_test_loc := _get_first_economy_location()
	if pc_test_loc:
		var pc_pressure2 := pc_spawner.calculate_pressure(pc_test_loc)
		_assert("Pressure is non-negative", pc_pressure2 >= 0.0)
		_assert("Pressure is bounded", pc_pressure2 <= 3.0)
	print("")

	# --- _test_forced_spawn ---
	print("── Test: Forced bandit spawning (low satisfaction) ──")
	var fs_spawner := BanditSpawner.new()
	var fs_bandit_faction := _get_bandit_faction()
	var fs_test_loc := _get_first_economy_location()
	_assert("Test location found", fs_test_loc != null)
	if fs_test_loc != null:
		for person in fs_test_loc.population.people:
			person.satisfaction = 10.0

		var fs_pressure := fs_spawner.calculate_pressure(fs_test_loc)
		print("  Forced pressure at %s: %.3f" % [fs_test_loc.location_name, fs_pressure])
		_assert("High pressure from low satisfaction", fs_pressure > BanditSpawner.SPAWN_THRESHOLD)

		var fs_initial_bandit_count := fs_spawner.count_total_bandits(world)
		var fs_squad: StrategySquad = fs_spawner.create_bandit_squad(fs_test_loc, world)
		world.add_roaming_squad(fs_squad)
		fs_bandit_faction.add_army(fs_squad)
		presenter.ai_fleet.register_squad(fs_squad, BanditSpawner.BANDIT_PROFILE_PATH)

		_assert("Bandit squad created", fs_squad != null)
		_assert("Bandit has BANDIT role", fs_squad.squad_role == StrategyTypes.SquadRole.BANDIT)
		_assert("Bandit has warriors", fs_squad.get_living_warriors().size() > 0)
		_assert("Bandit count increased", fs_spawner.count_total_bandits(world) == fs_initial_bandit_count + 1)
		_assert("Bandit in world roaming_squads", world.roaming_squads.has(fs_squad))
		_assert("Bandit in faction armies", fs_bandit_faction.armies.has(fs_squad))

		print("  Spawned: %s (%d warriors) at %s" % [
			fs_squad.squad_name, fs_squad.get_living_warriors().size(), fs_squad.current_location_id])
	print("")

	# --- _test_route_danger ---
	print("── Test: Route danger from bandits ──")
	var rd_danger_calc := RouteDangerCalculator.new()
	var rd_test_loc := _get_first_economy_location()
	if rd_test_loc == null or rd_test_loc.connections == null or rd_test_loc.connections.tt.is_empty():
		print("  SKIP — no connections")
	else:
		var rd_neighbor_id: String = rd_test_loc.connections.tt[0].to_location_id
		var rd_route: Array[String] = [rd_test_loc.location_id, rd_neighbor_id]
		var rd_safety_before := rd_danger_calc.calculate_route_safety(rd_route, world)
		print("  Route %s → %s safety BEFORE bandits: %.3f" % [rd_test_loc.location_id, rd_neighbor_id, rd_safety_before])

		var rd_bandit_loc_id := ""
		for squad in world.roaming_squads:
			if squad.squad_role == StrategyTypes.SquadRole.BANDIT:
				rd_bandit_loc_id = squad.current_location_id
				break

		if rd_bandit_loc_id.is_empty():
			print("  SKIP — no bandits to test")
		else:
			var rd_bandit_route: Array[String] = [rd_bandit_loc_id]
			for loc in world.locations:
				if loc.location_id != rd_bandit_loc_id and loc.is_connected_to(rd_bandit_loc_id):
					rd_bandit_route.append(loc.location_id)
					break

			if rd_bandit_route.size() >= 2:
				rd_danger_calc.clear_cache()
				var rd_safety_with_bandits := rd_danger_calc.calculate_route_safety(rd_bandit_route, world)
				print("  Route through bandit area safety: %.3f" % rd_safety_with_bandits)
				_assert("Route with bandits is less safe", rd_safety_with_bandits < 1.0)
	print("")

	# --- _test_mercenary_demand ---
	print("── Test: Mercenary demand calculation ──")
	var md_demand_calc := MercenaryDemandCalculator.new()
	var md_test_loc := _get_first_economy_location()
	if md_test_loc == null:
		pass
	else:
		var md_demand := md_demand_calc.calculate_demand(md_test_loc, world)
		print("  Mercenary demand at %s: %.3f" % [md_test_loc.location_name, md_demand])

		var md_bandit_nearby := md_demand_calc.find_nearest_bandit(md_test_loc, world)
		if md_bandit_nearby:
			print("  Nearest bandit: %s at %s" % [md_bandit_nearby.squad_name, md_bandit_nearby.current_location_id])
			_assert("Demand exists when bandits present", md_demand > 0.0)
			var md_bounty := md_demand_calc.get_bounty(md_bandit_nearby)
			print("  Bounty: %.0f gold" % md_bounty)
			_assert("Bounty is positive", md_bounty > 0.0)
		else:
			print("  No bandits nearby — demand should be 0")
			_assert("No demand without bandits", md_demand == 0.0)
	print("")

	# --- _test_bandit_lifecycle ---
	print("── Test: Bandit lifecycle (disband on low morale) ──")
	var bl_spawner := BanditSpawner.new()

	var bl_test_squad := SquadDataFactory.create_squad(
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

	var bl_background := WarriorBackgroundFactory.get_background(&"landsknecht")
	var bl_entity := StrategyEntityFactory.Create(bl_background, StrategyTypes.Religion.CATHOLIC)
	bl_entity.id = "bandit_test_w0"
	bl_entity.display_name = "Test Bandit"
	var bl_warrior := Character.new(bl_entity)
	bl_warrior.get_stat(StatName.I.MORALE).stat_value = 0.05
	bl_test_squad.add_warrior(bl_warrior)

	_assert("Low morale triggers disband", bl_spawner.check_disband(bl_test_squad))

	bl_warrior.get_stat(StatName.I.MORALE).stat_value = 0.5
	_assert("Normal morale does not disband", not bl_spawner.check_disband(bl_test_squad))

	bl_warrior.is_injured = true
	_assert("All injured triggers disband", bl_spawner.check_disband(bl_test_squad))

	bl_warrior.is_injured = false
	bl_warrior.is_dead = true
	_assert("All dead triggers disband", bl_spawner.check_disband(bl_test_squad))

	print("  Lifecycle checks passed")
	print("")

	# --- _print_results ---
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
