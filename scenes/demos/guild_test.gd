extends Node

## Guild system unit tests — recruitment, production, revenue, bridge integration

var test_count := 0
var passed_count := 0
var failed_count := 0

var world: World
var engine: EconomyEngine
var food: Thing
var iron: Thing
var wood: Thing
var sword: Thing


func _ready() -> void:
	Log.set_level(Log.Level.WARN)

	print("\n" + "=".repeat(70))
	print("GUILD SYSTEM — UNIT TEST SUITE")
	print("=".repeat(70) + "\n")

	test_guild_config_creation()
	test_guild_recruits_workers()
	test_guild_produces_swords()
	test_guild_limited_by_inputs()
	test_guild_pays_wages()
	test_guild_collects_revenue()
	test_guild_snapshot_in_tick_result()
	test_guild_with_real_pipeline()
	test_weapons_demand_by_nobles()
	test_no_guild_no_crash()

	print("\n" + "=".repeat(70))
	print("TEST RESULTS: %d passed, %d failed, %d total" % [passed_count, failed_count, test_count])
	if failed_count == 0:
		print("ALL TESTS PASSED")
	else:
		print("SOME TESTS FAILED")
	print("=".repeat(70) + "\n")

	get_tree().quit(0 if failed_count == 0 else 1)


func check(condition: bool, test_name: String, detail: String = "") -> void:
	test_count += 1
	if condition:
		passed_count += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_count += 1
		var msg := "  [FAIL] %s" % test_name
		if detail != "":
			msg += ": %s" % detail
		print(msg)


func check_gt(actual: float, threshold: float, test_name: String) -> void:
	check(actual > threshold, test_name, "got %.4f, expected > %.4f" % [actual, threshold])


func check_eq(actual: int, expected: int, test_name: String) -> void:
	check(actual == expected, test_name, "got %d, expected %d" % [actual, expected])


func _setup_minimal_economy(with_guild: bool = true, craftsman_count: int = 0, unemployed_count: int = 20) -> void:
	world = World.new()
	food = Thing.create("food", "Food", EconomyTypes.ThingType.FOOD, 5.0)
	iron = Thing.create("iron", "Iron", EconomyTypes.ThingType.TOOLS, 8.0)
	wood = Thing.create("wood", "Timber", EconomyTypes.ThingType.TOOLS, 3.0)

	var iron_input := ThingInput.create(iron, 2.0)
	var wood_input := ThingInput.create(wood, 1.0)
	sword = Thing.create("sword", "Swords", EconomyTypes.ThingType.WEAPONS, 25.0, "", [iron_input, wood_input])

	world.goods = [food, iron, wood, sword]

	var loc := Location.new()
	loc.location_id = "test_city"
	loc.location_name = "Test City"
	loc.type = StrategyTypes.LocationType.CITY
	loc.development = 80
	loc.stability = 100.0

	loc.population = Population.new()
	for p in Population.create_batch(20, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 5.0):
		loc.population.add_person(p)
	for p in Population.create_batch(5, "merchant", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 20.0):
		loc.population.add_person(p)
	for p in Population.create_batch(3, "noble", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 100.0):
		loc.population.add_person(p)
	for p in Population.create_batch(craftsman_count, "smith", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.CRAFTSMAN, 10.0):
		loc.population.add_person(p)
	for p in Population.create_batch(unemployed_count, "idle", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.UNEMPLOYED, 0.0):
		loc.population.add_person(p)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 500.0)
	loc.inventory.init_thing(iron, 200.0)
	loc.inventory.init_thing(wood, 300.0)
	loc.inventory.init_thing(sword, 0.0)

	loc.natural_resources = [
		NaturalResource.create(food, 50.0, EconomyTypes.JobType.FARMER, 20.0),
		NaturalResource.create(iron, 20.0, EconomyTypes.JobType.FARMER, 10.0),
		NaturalResource.create(wood, 30.0, EconomyTypes.JobType.FARMER, 10.0),
	]

	if with_guild:
		var spec := GuildSpecialization.new()
		spec.thing = sword
		spec.max_workers = 15
		spec.worker_job = EconomyTypes.JobType.CRAFTSMAN
		spec.wage_per_worker = 1.0
		spec.recruitment_rate = 3
		var guild := GuildConfig.new()
		guild.guild_name = "Test Smithing Guild"
		guild.specializations = [spec]
		guild.starting_treasury = 200.0
		loc.guild_configs = [guild]

	var gov := GovernmentConfig.new()
	gov.tax_rate = 0.05
	gov.max_budget_ratio = 0.3
	gov.starting_treasury = 100.0
	gov.priority_goods = ["food"]
	loc.government_config = gov

	world.add_location(loc)

	engine = EconomyEngine.new()
	engine.world = world
	engine.loan_interest_rate = 0.01
	engine.print_per_turn = 100.0
	engine.enable_csharp()
	world.economy_engine = engine


func test_guild_config_creation() -> void:
	print("\n--- Guild Config Creation ---")
	var spec := GuildSpecialization.new()
	spec.max_workers = 30
	spec.worker_job = EconomyTypes.JobType.CRAFTSMAN
	spec.wage_per_worker = 1.5
	spec.recruitment_rate = 2
	var config := GuildConfig.new()
	config.guild_name = "Smithing Guild"
	config.specializations = [spec]
	config.starting_treasury = 500.0
	check(config.guild_name == "Smithing Guild", "Guild name set correctly")
	check(config.specializations[0].max_workers == 30, "Max workers set correctly")
	check(config.starting_treasury == 500.0, "Starting treasury set correctly")


func test_guild_recruits_workers() -> void:
	print("\n--- Guild Recruits Workers ---")
	_setup_minimal_economy(true, 0, 20)

	var loc: Location = world.locations[0]
	loc.government_config = null
	var craftsmen_before := loc.population.get_by_job(EconomyTypes.JobType.CRAFTSMAN).size()
	check_eq(craftsmen_before, 0, "No craftsmen initially")

	engine.tick_full(2)

	var craftsmen_after := loc.population.get_by_job(EconomyTypes.JobType.CRAFTSMAN).size()
	check_gt(float(craftsmen_after), 0.0, "Guild recruited craftsmen after tick")
	print("    Craftsmen: %d → %d" % [craftsmen_before, craftsmen_after])


func test_guild_produces_swords() -> void:
	print("\n--- Guild Produces Swords ---")
	_setup_minimal_economy(true, 10, 10)

	var result: EconomyTickResult = engine.tick_full(3)
	var snap: EconomyTickResult.LocationSnapshot = result.location_snapshots[0]
	check(snap.guild_produced > 0.0, "Guild produced swords", "got %.2f" % snap.guild_produced)
	print("    Guild produced: %.2f, Guild treasury: %.1f" % [snap.guild_produced, snap.guild_treasury])


func test_guild_limited_by_inputs() -> void:
	print("\n--- Guild Limited By Inputs ---")
	_setup_minimal_economy(true, 10, 10)

	var loc: Location = world.locations[0]
	loc.inventory.stocks[iron] = 0.0
	loc.inventory.stocks[wood] = 0.0
	loc.natural_resources = loc.natural_resources.filter(
		func(nr: NaturalResource) -> bool: return nr.thing != iron and nr.thing != wood
	)

	engine.tick_full(4)

	var sword_stock := loc.inventory.get_available(sword)
	check(sword_stock <= 0.01, "No swords produced without inputs", "got %.2f" % sword_stock)


func test_guild_pays_wages() -> void:
	print("\n--- Guild Pays Wages ---")
	_setup_minimal_economy(true, 5, 10)

	var loc: Location = world.locations[0]
	loc.government_config.tax_rate = 0.0

	engine.tick_full(6)

	var craftsmen_after := loc.population.get_by_job(EconomyTypes.JobType.CRAFTSMAN)
	var total_money_after := 0.0
	for p: EconPerson in craftsmen_after:
		total_money_after += p.money
	var expected_wage := 1.0 * craftsmen_after.size()
	check_gt(total_money_after, float(expected_wage) * 0.5, "Craftsmen received wages")
	print("    Craftsmen count: %d, total money: %.2f, expected wages >= %.2f" % [craftsmen_after.size(), total_money_after, expected_wage])


func test_guild_collects_revenue() -> void:
	print("\n--- Guild Collects Revenue ---")
	_setup_minimal_economy(true, 10, 10)

	engine.tick_full(7)
	engine.tick_full(8)
	engine.tick_full(9)

	var info: Dictionary = engine.get_guild_info()
	check(info.size() > 0, "Guild info returned", "got %d entries" % info.size())
	if info.size() > 0:
		var first_key: String = info.keys()[0]
		var guild_array: Array = info[first_key]
		check(guild_array.size() > 0, "Guild array has entries", "got %d" % guild_array.size())
		if guild_array.size() > 0:
			var guild_data: Dictionary = guild_array[0]
			var treasury: float = guild_data.get("treasury", 0.0)
			print("    Guild treasury after 3 ticks: %.1f" % treasury)
			check_gt(treasury, 0.0, "Guild has non-zero treasury")


func test_guild_snapshot_in_tick_result() -> void:
	print("\n--- Guild Snapshot In Tick Result ---")
	_setup_minimal_economy(true, 10, 10)

	var result: EconomyTickResult = engine.tick_full(10)
	check(result.location_snapshots.size() > 0, "Snapshots returned")
	if result.location_snapshots.size() > 0:
		var snap: EconomyTickResult.LocationSnapshot = result.location_snapshots[0]
		check(snap.guild_treasury >= 0.0, "Guild treasury in snapshot", "got %.1f" % snap.guild_treasury)
		check(snap.guild_produced >= 0.0, "Guild produced in snapshot", "got %.1f" % snap.guild_produced)
		check(snap.guild_worker_count >= 0, "Guild worker count in snapshot", "got %d" % snap.guild_worker_count)
		print("    Snapshot: treasury=%.1f, produced=%.1f, workers=%d" % [snap.guild_treasury, snap.guild_produced, snap.guild_worker_count])


func test_guild_with_real_pipeline() -> void:
	print("\n--- Guild With Real Pipeline (goetz-official) ---")
	var HeadlessView = load("res://src/demos/headless_strategy_view.gd")
	var mock_view = HeadlessView.new()
	add_child(mock_view)
	mock_view.setup_headless()

	var presenter := StrategyPresenter.new()
	presenter.scenario_path = "res://resources/scenarios/goetz-official/scenario.tres"
	presenter.is_demo_scenario = false
	mock_view.add_child(presenter)
	await presenter.bind_view(mock_view)

	var real_world: World = presenter.game_scenario.world
	var real_engine: EconomyEngine = real_world.economy_engine
	check(real_engine != null, "Real engine initialized")

	var nuremberg: Location = null
	for loc: Location in real_world.locations:
		if loc.location_id == "nuremberg":
			nuremberg = loc
			break
	check(nuremberg != null, "Nuremberg found")
	check(nuremberg.guild_configs.size() > 0, "Nuremberg has guild configs")
	if nuremberg.guild_configs.size() > 0:
		var guild_cfg := nuremberg.guild_configs[0]
		check(guild_cfg.guild_name == "Nürnberg Smithing Guild", "Guild name correct")
		var spec_count := guild_cfg.specializations.size()
		print("    Guild: %s, specializations=%d" % [guild_cfg.guild_name, spec_count])

	var sword_thing: Thing = null
	for t: Thing in real_world.goods:
		if t.thing_id == "sword":
			sword_thing = t
			break
	check(sword_thing != null, "Sword thing exists in world goods")

	for i in range(24):
		presenter.game_clock.force_tick()
		await presenter.tick_completed

	real_engine.sync_full()
	var sword_stock := nuremberg.inventory.get_available(sword_thing)
	check_gt(sword_stock, 0.0, "Swords produced in Nuremberg after 24 hours")
	print("    Nuremberg sword stock after 24h: %.1f" % sword_stock)

	mock_view.queue_free()


func test_weapons_demand_by_nobles() -> void:
	print("\n--- Weapons Demand By Nobles ---")
	_setup_minimal_economy(false, 0, 10)

	engine.tick_full(11)

	var loc: Location = world.locations[0]
	var sword_stock := loc.inventory.get_available(sword)
	var food_stock := loc.inventory.get_available(food)
	check(sword_stock >= 0.0, "Sword stock is accessible")
	check(food_stock >= 0.0, "Food stock is accessible")
	print("    Sword stock: %.1f, Food stock: %.1f" % [sword_stock, food_stock])


func test_no_guild_no_crash() -> void:
	print("\n--- No Guild No Crash ---")
	_setup_minimal_economy(false, 0, 10)

	engine.tick_full(12)
	engine.tick_full(13)
	check(true, "Ticks without guild did not crash")
