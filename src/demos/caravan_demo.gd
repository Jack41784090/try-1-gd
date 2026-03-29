extends Node
## Caravan Integration Demo — Tests the real StrategyPresenter's economy+caravan pipeline.
##
## Creates a 3-location demo world with EconomyEngine, wires it to
## StrategyPresenter via HeadlessStrategyView, and drives REST turns.
## The presenter's _tick_economy_and_spawn_caravans() handles everything:
## spawning, movement, and delivery. This demo only asserts correctness.
##
## Usage: godot --headless --path . scenes/demos/caravan_demo.tscn

const HeadlessView = preload("res://src/demos/headless_strategy_view.gd")

var presenter: StrategyPresenter
var engine: EconomyEngine
var world: World
var food: Thing
var cloth: Thing
var tools: Thing
var luxury: Thing

var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	Log.set_level(Log.Level.DEBUG)
	Log.info("CaravanDemo", "=== CARAVAN INTEGRATION DEMO ===")
	Log.info("CaravanDemo", "Economy + Strategy bridge via production StrategyPresenter")
	Log.info("CaravanDemo", "")

	var mock_view = HeadlessView.new()
	add_child(mock_view)
	mock_view.setup_headless()

	presenter = StrategyPresenter.new()
	presenter.is_demo_scenario = true
	mock_view.add_child(presenter)

	DemoScenarioFactory.DEFAULT_DEMO_VALUES = {
		"city": {
			"location_id": "market_town",
			"location_name": "Market Town",
			"development": 75,
			"stability": 85.0,
		},
		"village": {
			"location_id": "farmstead",
			"location_name": "Farmstead",
			"development": 30,
			"stability": 60.0,
		},
		"squad": {
			"squad_id": "player_squad",
			"squad_name": "Caravan Watchers",
			"money": 100.0,
			"food": 30,
			"travel_tools": 5,
			"karma": 10.0,
			"starting_location_id": "market_town",
		},
		"world": {
			"turn_count": 0,
			"end_progression": 0.0,
		},
	}
	await presenter.bind_view(mock_view)

	world = presenter.game_scenario.world
	_add_castle_location()
	_setup_economy()

	Log.info("CaravanDemo", "World locations: %s" % [
		world.locations.map(func(l): return l.location_id),
	])

	await _run_simulation()


func _setup_economy() -> void:
	food = Thing.create("food", "Food", EconomyTypes.ThingType.FOOD, 1.0)
	cloth = Thing.create("cloth", "Cloth", EconomyTypes.ThingType.CLOTH, 3.0)
	tools = Thing.create("tools", "Tools", EconomyTypes.ThingType.TOOLS, 5.0)
	luxury = Thing.create("luxury", "Luxuries", EconomyTypes.ThingType.LUXURY, 15.0)
	world.goods = [food, cloth, tools, luxury]

	_setup_econ_location("farmstead", _farmstead_pop(), _farmstead_inv(), _farmstead_rules())
	_setup_econ_location("market_town", _market_town_pop(), _market_town_inv(), _market_town_rules())
	_setup_econ_location("castle", _castle_pop(), _castle_inv(), _castle_rules())

	engine = EconomyEngine.new()
	engine.world = world
	engine.bank = CentralBank.new()
	engine.bank.loan_interest_rate = 0.08
	engine.bank.print_per_turn = 500.0
	engine.noble_loan_threshold = 100.0
	engine.loan_amount = 500.0
	engine.enable_csharp()
	world.economy_engine = engine


func _setup_econ_location(loc_id: String, pop: Population, inv: LocationInventory, rules: Array[SupplyRule]) -> void:
	var loc := world.get_location_by_id(loc_id)
	assert(loc != null, "Location %s not found in world" % loc_id)
	loc.population = pop
	loc.inventory = inv
	loc.supply_rules = rules


func _farmstead_pop() -> Population:
	var pop := Population.new()
	for p in Population.create_batch(50, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 0.0):
		pop.add_person(p)
	for p in Population.create_batch(5, "trader", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 5.0):
		pop.add_person(p)
	for p in Population.create_batch(2, "squire", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 50.0):
		pop.add_person(p)
	return pop

func _farmstead_inv() -> LocationInventory:
	var inv := LocationInventory.new()
	inv.init_thing(food, 60.0)
	inv.init_thing(cloth, 10.0)
	return inv

func _farmstead_rules() -> Array[SupplyRule]:
	return [
		SupplyRule.create_extract("farmstead_harvest", food, 250.0),
		SupplyRule.create_extract("farmstead_spinning", cloth, 50.0),
	]


func _market_town_pop() -> Population:
	var pop := Population.new()
	for p in Population.create_batch(10, "laborer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 5.0):
		pop.add_person(p)
	for p in Population.create_batch(15, "craftsman", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.CRAFTSMAN, 5.0):
		pop.add_person(p)
	for p in Population.create_batch(25, "merchant", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 5.0):
		pop.add_person(p)
	for p in Population.create_batch(10, "lord", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 50.0):
		pop.add_person(p)
	return pop

func _market_town_inv() -> LocationInventory:
	var inv := LocationInventory.new()
	inv.init_thing(food, 60.0)
	inv.init_thing(cloth, 5.0)
	inv.init_thing(tools, 5.0)
	inv.init_thing(luxury, 2.0)
	return inv

func _market_town_rules() -> Array[SupplyRule]:
	return [
		SupplyRule.create_import("town_import_food", food, "farmstead", 100.0),
		SupplyRule.create_import("town_import_cloth", cloth, "farmstead", 50.0),
		SupplyRule.create_craft("town_weaving", cloth, 15.0),
		SupplyRule.create_craft("town_toolsmith", tools, 25.0),
		SupplyRule.create_craft("town_luxuries", luxury, 20.0),
	]


func _castle_pop() -> Population:
	var pop := Population.new()
	for p in Population.create_batch(10, "servant", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.SERVANT, 5.0):
		pop.add_person(p)
	for p in Population.create_batch(5, "baron", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 50.0):
		pop.add_person(p)
	return pop

func _castle_inv() -> LocationInventory:
	var inv := LocationInventory.new()
	inv.init_thing(food, 20.0)
	inv.init_thing(cloth, 3.0)
	inv.init_thing(tools, 2.0)
	inv.init_thing(luxury, 1.0)
	return inv

func _castle_rules() -> Array[SupplyRule]:
	return [
		SupplyRule.create_import("castle_import_food", food, "market_town", 20.0),
		SupplyRule.create_import("castle_direct_food", food, "farmstead", 40.0, 1),
		SupplyRule.create_import("castle_import_cloth", cloth, "market_town", 15.0),
		SupplyRule.create_import("castle_import_tools", tools, "market_town", 10.0),
		SupplyRule.create_import("castle_import_luxury", luxury, "market_town", 10.0),
	]


func _add_castle_location() -> void:
	var castle := Location.new()
	castle.location_id = "castle"
	castle.location_name = "Castle"
	castle.type = StrategyTypes.LocationType.CITY
	castle.development = 60
	castle.stability = 90.0
	castle.add_connection("market_town", 1)
	world.add_location(castle)

	var market := world.get_location_by_id("market_town")
	if market:
		market.add_connection("castle", 1)
	var farmstead := world.get_location_by_id("farmstead")
	if farmstead:
		farmstead.add_connection("castle", 2)
		castle.add_connection("farmstead", 2)


func _run_simulation() -> void:
	var max_turns := 15
	Log.info("CaravanDemo", "Running %d turns (REST each turn, economy ticks via presenter)..." % max_turns)
	Log.info("CaravanDemo", "")

	for turn in range(1, max_turns + 1):
		Log.info("CaravanDemo", "=== TURN %d ===" % turn)
		presenter.on_activity_requested(StrategyTypes.ActivityType.REST)
		await get_tree().create_timer(0.1).timeout
		_print_turn_summary(turn)

	Log.info("CaravanDemo", "")
	_print_final_summary()
	_run_assertions()

	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _print_turn_summary(turn: int) -> void:
	var caravan_count := 0
	var total_in_world := world.roaming_squads.size()
	for squad in world.roaming_squads:
		if squad.is_caravan():
			caravan_count += 1
			Log.debug("CaravanDemo", "    Caravan: %s @ %s → %s (role=%s)" % [
				squad.squad_name,
				squad.current_location_id,
				squad.cargo.destination_id,
				StrategyTypes.SquadRole.keys()[squad.squad_role],
			])
	Log.info("CaravanDemo", "  Roaming squads: %d | Caravans: %d | Shipments tracked: %d" % [
		total_in_world, caravan_count, presenter._active_shipments.size(),
	])

	if turn <= 3 or turn % 5 == 0:
		for loc in world.get_economy_locations():
			Log.info("CaravanDemo", "    [%s] Food=%.0f Cloth=%.0f Tools=%.0f Lux=%.0f" % [
				loc.location_name,
				loc.inventory.get_available(food),
				loc.inventory.get_available(cloth),
				loc.inventory.get_available(tools),
				loc.inventory.get_available(luxury),
			])


func _print_final_summary() -> void:
	Log.info("CaravanDemo", "=== CARAVAN FINAL SUMMARY ===")
	Log.info("CaravanDemo", "Active shipments: %d" % presenter._active_shipments.size())

	for loc in world.get_economy_locations():
		Log.info("CaravanDemo", "  [%s] Food=%.0f Cloth=%.0f Tools=%.0f Lux=%.0f" % [
			loc.location_name,
			loc.inventory.get_available(food),
			loc.inventory.get_available(cloth),
			loc.inventory.get_available(tools),
			loc.inventory.get_available(luxury),
		])

	for squad in world.roaming_squads:
		if squad.is_caravan():
			Log.info("CaravanDemo", "  In-transit: %s @ %s → %s" % [
				squad.squad_name, squad.current_location_id, squad.cargo.destination_id,
			])


func _run_assertions() -> void:
	Log.info("CaravanDemo", "")
	Log.info("CaravanDemo", "=== ASSERTIONS ===")

	var castle_loc := world.get_location_by_id("castle")
	_assert_gte("Castle food inventory exists", castle_loc.inventory.get_available(food), 0.0)
	_assert_gt("Castle received tools", castle_loc.inventory.get_available(tools), 0.0)

	var farmstead_loc := world.get_location_by_id("farmstead")
	_assert_gt("Farmstead produced food (source)", farmstead_loc.inventory.get_available(food), 0.0)

	for squad in world.roaming_squads:
		if squad.is_caravan():
			_assert_true(
				"Caravan %s has MERCHANT role" % squad.squad_name,
				squad.squad_role == StrategyTypes.SquadRole.MERCHANT,
			)
			_assert_true(
				"Caravan %s has destination" % squad.squad_name,
				not squad.cargo.destination_id.is_empty(),
			)
			_assert_true(
				"Caravan %s has warriors" % squad.squad_name,
				squad.get_living_warriors().size() > 0,
			)

	Log.info("CaravanDemo", "")
	Log.info("CaravanDemo", "Results: %d PASS, %d FAIL" % [_pass_count, _fail_count])
	if _fail_count > 0:
		Log.error("CaravanDemo", "SOME ASSERTIONS FAILED")
	else:
		Log.info("CaravanDemo", "ALL ASSERTIONS PASSED")


func _assert_gt(label: String, actual: Variant, minimum: Variant) -> void:
	if actual > minimum:
		_pass_count += 1
		Log.info("CaravanDemo", "  PASS: %s = %s (> %s)" % [label, str(actual), str(minimum)])
	else:
		_fail_count += 1
		Log.error("CaravanDemo", "  FAIL: %s = %s (expected > %s)" % [label, str(actual), str(minimum)])


func _assert_gte(label: String, actual: Variant, minimum: Variant) -> void:
	if actual >= minimum:
		_pass_count += 1
		Log.info("CaravanDemo", "  PASS: %s = %s (>= %s)" % [label, str(actual), str(minimum)])
	else:
		_fail_count += 1
		Log.error("CaravanDemo", "  FAIL: %s = %s (expected >= %s)" % [label, str(actual), str(minimum)])


func _assert_true(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		Log.info("CaravanDemo", "  PASS: %s" % label)
	else:
		_fail_count += 1
		Log.error("CaravanDemo", "  FAIL: %s" % label)
