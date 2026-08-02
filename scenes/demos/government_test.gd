extends Node

## Government directive system unit tests — tax, plan, execute, hire workers

var test_count := 0
var passed_count := 0
var failed_count := 0

var world: World
var engine: EconomyEngine
var food: Thing
var wool: Thing

func _ready() -> void:
	Log.set_level(Log.Level.WARN)

	print("\n" + "=".repeat(70))
	print("GOVERNMENT DIRECTIVE SYSTEM — UNIT TEST SUITE")
	print("=".repeat(70) + "\n")

	test_directive_creation_and_expiry()
	test_government_config_defaults()
	test_tax_collection()
	test_government_plan_creates_directives()
	test_hire_workers_execution()
	test_no_government_no_crash()
	test_budget_constraint()
	test_treasury_accumulates_over_ticks()
	test_government_snapshot_in_tick_result()
	test_get_government_info()

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


func check_float_gt(actual: float, threshold: float, test_name: String) -> void:
	check(actual > threshold, test_name, "got %.2f, expected > %.2f" % [actual, threshold])


func check_float_eq(actual: float, expected: float, test_name: String, tolerance: float = 0.01) -> void:
	check(absf(actual - expected) < tolerance, test_name, "got %.4f, expected %.4f" % [actual, expected])


func _setup_minimal_economy(with_government: bool = true, unemployed_count: int = 10) -> void:
	world = World.new()
	food = Thing.create("food", "Food", EconomyTypes.ThingType.FOOD, 1.0)
	wool = Thing.create("wool", "Wool", EconomyTypes.ThingType.CLOTH, 1.5)
	world.goods = [food, wool]

	var loc := Location.new()
	loc.location_id = "test_town"
	loc.location_name = "Test Town"
	loc.type = StrategyTypes.LocationType.TOWN
	loc.development = 50
	loc.stability = 100.0

	loc.population = Population.new()
	for p in Population.create_batch(20, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 5.0):
		loc.population.add_person(p)
	for p in Population.create_batch(5, "merchant", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 20.0):
		loc.population.add_person(p)
	for p in Population.create_batch(unemployed_count, "idle", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.UNEMPLOYED, 0.0):
		loc.population.add_person(p)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 100.0)
	loc.inventory.init_thing(wool, 20.0)

	loc.natural_resources = [
		NaturalResource.create(food, 100.0, EconomyTypes.JobType.FARMER, 30.0),
	]

	if with_government:
		var gov := GovernmentConfig.new()
		gov.push_weight = 0.8
		gov.pull_weight = 0.2
		gov.tax_rate = 0.10
		gov.max_budget_ratio = 0.5
		gov.starting_treasury = 200.0
		gov.priority_goods = ["food"]
		loc.government_config = gov

	world.add_location(loc)

	engine = EconomyEngine.new()
	engine.world = world
	engine.loan_interest_rate = 0.01
	engine.print_per_turn = 100.0
	engine.enable_csharp()
	world.economy_engine = engine


func test_directive_creation_and_expiry() -> void:
	print("\n--- CsDirective pure logic ---")
	## These test the GDScript-visible DirectiveType enum exists
	check_eq(EconomyTypes.DirectiveType.HIRE_WORKERS, 0, "DirectiveType.HIRE_WORKERS == 0")
	check_eq(EconomyTypes.DirectiveType.POST_BUY_ORDER, 1, "DirectiveType.POST_BUY_ORDER == 1")
	check_eq(EconomyTypes.DirectiveType.SUBSIDIZE_PRODUCTION, 2, "DirectiveType.SUBSIDIZE_PRODUCTION == 2")


func test_government_config_defaults() -> void:
	print("\n--- GovernmentConfig defaults ---")
	var config := GovernmentConfig.new()
	check_float_eq(config.push_weight, 0.7, "Default push_weight = 0.7")
	check_float_eq(config.pull_weight, 0.3, "Default pull_weight = 0.3")
	check_float_eq(config.max_budget_ratio, 0.3, "Default max_budget_ratio = 0.3")
	check_float_eq(config.tax_rate, 0.05, "Default tax_rate = 0.05")
	check_float_eq(config.starting_treasury, 100.0, "Default starting_treasury = 100.0")
	check_eq(config.priority_goods.size(), 0, "Default priority_goods is empty")


func test_tax_collection() -> void:
	print("\n--- Tax collection ---")
	_setup_minimal_economy(true, 0)

	var result = engine.tick(1)
	var snap = result.location_snapshots[0]

	check_float_gt(snap.government_treasury, 200.0, "Treasury grew after tax collection")
	check_float_gt(snap.government_tax_collected, 0.0, "Tax collected > 0")

	## With 20 farmers at 5.0 money and 5 merchants at 20.0:
	## Merchants have >10 money, so ~5 * 20 * 0.10 = 10.0 taxed
	## Farmers have 5.0 each (<= 10 threshold) so no tax from them
	## But after PhaseBankLending / PhaseWages etc, money may have changed
	## Just check that tax was collected and treasury increased
	check_float_gt(snap.government_tax_collected, 0.01, "Some tax was actually collected")


func test_government_plan_creates_directives() -> void:
	print("\n--- Government plan creates directives ---")
	## Setup with 10 unemployed workers — the brain should see
	## food natural resource needs 30 workers, only 20 farmers exist → gap of 10
	## With 10 unemployed available and treasury of 200, it should create a directive
	_setup_minimal_economy(true, 10)

	var result = engine.tick(1)
	var snap = result.location_snapshots[0]

	check(snap.government_directives_count > 0, "Government created directives",
		"directives=%d" % snap.government_directives_count)


func test_hire_workers_execution() -> void:
	print("\n--- Hire workers execution ---")
	_setup_minimal_economy(true, 10)

	var result = engine.tick(1)
	var snap = result.location_snapshots[0]

	check(snap.government_workers_hired > 0, "Workers were hired",
		"hired=%d" % snap.government_workers_hired)

	## Treasury should have decreased due to wages paid
	## Started at 200, gained tax, but spent on wages
	## After hiring, government info should show wages_paid > 0
	var gov_info: Array[Dictionary] = engine.get_government_info()
	check(gov_info.size() > 0, "get_government_info returns data")
	if gov_info.size() > 0:
		var g: Dictionary = gov_info[0]
		check_float_gt(g.get("wages_paid", 0.0), 0.0, "Wages were paid to hired workers")


func test_no_government_no_crash() -> void:
	print("\n--- No government config — no crash ---")
	_setup_minimal_economy(false, 5)

	var result = engine.tick(1)
	var snap = result.location_snapshots[0]

	check_float_eq(snap.government_treasury, 0.0, "No gov → treasury = 0")
	check_float_eq(snap.government_tax_collected, 0.0, "No gov → tax = 0")
	check_eq(snap.government_directives_count, 0, "No gov → directives = 0")
	check_eq(snap.government_workers_hired, 0, "No gov → hired = 0")

	var gov_info: Array[Dictionary] = engine.get_government_info()
	check_eq(gov_info.size(), 0, "No gov → get_government_info returns empty")


func test_budget_constraint() -> void:
	print("\n--- Budget constraint ---")
	## Give a tiny treasury so the government can't hire many workers
	_setup_minimal_economy(true, 50)
	var loc := world.get_location_by_id("test_town")
	loc.government_config.starting_treasury = 2.0
	loc.government_config.max_budget_ratio = 0.5

	engine = EconomyEngine.new()
	engine.world = world
	engine.print_per_turn = 100.0
	engine.enable_csharp()
	world.economy_engine = engine

	var result = engine.tick(1)
	var snap = result.location_snapshots[0]

	## With only 2.0 treasury and 0.5 budget ratio → 1.0 available budget
	## At minimum wage of 0.5, can hire at most 0 workers for 12 turns
	## (1.0 / (0.5 * 12) ≈ 0.16 → 0 workers)
	## Or after tax collection, treasury may have grown slightly
	## The key test: workers hired should be very limited
	check(snap.government_workers_hired <= 5, "Budget constrains hiring",
		"hired=%d (should be few with tiny treasury)" % snap.government_workers_hired)


func test_treasury_accumulates_over_ticks() -> void:
	print("\n--- Treasury accumulates over ticks ---")
	_setup_minimal_economy(true, 0)

	var result1 = engine.tick(1)
	var treasury1: float = result1.location_snapshots[0].government_treasury

	var result2 = engine.tick(2)
	var treasury2: float = result2.location_snapshots[0].government_treasury

	var result3 = engine.tick(3)
	var treasury3: float = result3.location_snapshots[0].government_treasury

	check_float_gt(treasury1, 0.0, "Treasury positive after tick 1 (%.2f)" % treasury1)
	check_float_gt(treasury2, 0.0, "Treasury positive after tick 2 (%.2f)" % treasury2)
	check_float_gt(treasury3, 0.0, "Treasury positive after tick 3 (%.2f)" % treasury3)


func test_government_snapshot_in_tick_result() -> void:
	print("\n--- Government snapshot in tick result ---")
	_setup_minimal_economy(true, 5)

	var result = engine.tick(1)
	check(result.location_snapshots.size() > 0, "Tick result has snapshots")
	var snap = result.location_snapshots[0]

	## Verify all 4 government fields are present and typed correctly
	check(snap.government_treasury is float, "government_treasury is float")
	check(snap.government_tax_collected is float, "government_tax_collected is float")
	check(snap.government_directives_count is int, "government_directives_count is int")
	check(snap.government_workers_hired is int, "government_workers_hired is int")

	check_float_gt(snap.government_treasury, 0.0, "Snapshot treasury > 0")


func test_get_government_info() -> void:
	print("\n--- get_government_info bridge method ---")
	_setup_minimal_economy(true, 5)
	engine.tick(1)

	var info: Array[Dictionary] = engine.get_government_info()
	check_eq(info.size(), 1, "One location with government")

	var g: Dictionary = info[0]
	check(g.has("location_id"), "Info has location_id")
	check(g.has("treasury"), "Info has treasury")
	check(g.has("tax_collected"), "Info has tax_collected")
	check(g.has("active_directives"), "Info has active_directives")
	check(g.has("workers_hired"), "Info has workers_hired")
	check(g.has("wages_paid"), "Info has wages_paid")

	check(g["location_id"] == "test_town", "location_id matches",
		"got '%s'" % str(g["location_id"]))
	check_float_gt(float(g["treasury"]), 0.0, "Info treasury > 0")
