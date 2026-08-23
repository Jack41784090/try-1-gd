extends Node
## Tests the real economy+caravan pipeline: EconomyEngine.tick_full() dispatches shipments, StrategyPresenter materializes them as MERCHANT squads and reports back on arrival. Run: godot --headless --path . scenes/demos/caravan_demo.tscn

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
	MyLog.set_level(MyLog.Level.DEBUG)
	MyLog.info("CaravanDemo", "=== CARAVAN INTEGRATION DEMO ===")
	MyLog.info("CaravanDemo", "Economy + Strategy bridge via production StrategyPresenter")
	MyLog.info("CaravanDemo", "")

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
			"current_hour": 0,
		},
	}
	await presenter.bind_view(mock_view)

	world = presenter.game_scenario.world

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

	_setup_economy()

	MyLog.info("CaravanDemo", "World locations: %s" % [
		world.locations.map(func(l): return l.location_id),
	])

	await _run_simulation()


func _setup_economy() -> void:
	food = Thing.create("food", "Food", EconomyTypes.ThingType.FOOD, 1.0)
	cloth = Thing.create("cloth", "Cloth", EconomyTypes.ThingType.CLOTH, 3.0)
	tools = Thing.create("tools", "Tools", EconomyTypes.ThingType.TOOLS, 5.0)
	luxury = Thing.create("luxury", "Luxuries", EconomyTypes.ThingType.LUXURY, 15.0)
	world.goods = [food, cloth, tools, luxury]

	var fp := Population.new()
	for p in Population.create_batch(50, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 0.0):
		fp.add_person(p)
	for p in Population.create_batch(5, "trader", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 5.0):
		fp.add_person(p)
	for p in Population.create_batch(2, "squire", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 50.0):
		fp.add_person(p)

	var fi := LocationInventory.new()
	fi.init_thing(food, 60.0)
	fi.init_thing(cloth, 10.0)

	var fr: Array[NaturalResource] = [
		NaturalResource.create(food, 250.0),
		NaturalResource.create(cloth, 50.0),
	]

	_setup_econ_location("farmstead", fp, fi, fr)

	var mp := Population.new()
	for p in Population.create_batch(10, "laborer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 5.0):
		mp.add_person(p)
	for p in Population.create_batch(15, "craftsman", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.CRAFTSMAN, 5.0):
		mp.add_person(p)
	for p in Population.create_batch(25, "merchant", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 5.0):
		mp.add_person(p)
	for p in Population.create_batch(10, "lord", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 50.0):
		mp.add_person(p)

	var mi := LocationInventory.new()
	mi.init_thing(food, 60.0)
	mi.init_thing(cloth, 5.0)
	mi.init_thing(tools, 5.0)
	mi.init_thing(luxury, 2.0)

	var mr: Array[NaturalResource] = [
		NaturalResource.create_craft(cloth, 15.0),
		NaturalResource.create_craft(tools, 25.0),
		NaturalResource.create_craft(luxury, 20.0),
	]

	_setup_econ_location("market_town", mp, mi, mr)

	var cp := Population.new()
	for p in Population.create_batch(10, "servant", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.SERVANT, 5.0):
		cp.add_person(p)
	for p in Population.create_batch(5, "baron", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 50.0):
		cp.add_person(p)

	var ci := LocationInventory.new()
	ci.init_thing(food, 20.0)
	ci.init_thing(cloth, 3.0)
	ci.init_thing(tools, 2.0)
	ci.init_thing(luxury, 1.0)

	var cr: Array[NaturalResource] = []

	_setup_econ_location("castle", cp, ci, cr)

	engine = EconomyEngine.new()
	engine.world = world
	engine.loan_interest_rate = 0.01
	engine.print_per_turn = 500.0
	engine.noble_loan_threshold = 100.0
	engine.loan_amount = 500.0
	engine.enable_csharp()
	world.economy_engine = engine


func _setup_econ_location(loc_id: String, pop: Population, inv: LocationInventory, resources: Array[NaturalResource]) -> void:
	var loc := world.get_location_by_id(loc_id)
	assert(loc != null, "Location %s not found in world" % loc_id)
	loc.population = pop
	loc.inventory = inv
	loc.natural_resources = resources


func _run_simulation() -> void:
	var target_days := 5
	var target_hours := target_days * 24
	MyLog.info("CaravanDemo", "Running %d days (%d hours) with fast clock. Economy ticks every 24h." % [target_days, target_hours])
	MyLog.info("CaravanDemo", "")

	presenter.on_activity_requested(StrategyTypes.ActivityType.REST)
	presenter.game_clock.set_speed(200.0)
	presenter.game_clock.unpause()

	var last_reported_day := -1
	while world.current_hour < target_hours:
		await get_tree().create_timer(0.05).timeout
		var current_day := world.get_day()
		if current_day != last_reported_day:
			last_reported_day = current_day
			MyLog.info("CaravanDemo", "=== DAY %d (hour %d) ===" % [current_day, world.current_hour])

			var caravan_count := 0
			var total_in_world := world.roaming_squads.size()
			for squad in world.roaming_squads:
				if squad.is_caravan():
					caravan_count += 1
					MyLog.debug("CaravanDemo", "    Caravan: %s @ %s → %s (role=%s)" % [
						squad.squad_name,
						squad.current_location_id,
						squad.cargo.destination_id,
						StrategyTypes.SquadRole.keys()[squad.squad_role],
					])
			MyLog.info("CaravanDemo", "  Roaming squads: %d | Caravans: %d | Shipments tracked: %d" % [
				total_in_world, caravan_count, presenter.game_scenario.world.economy_engine.active_shipment_count,
			])

			if current_day <= 3 or current_day % 5 == 0:
				for loc in world.get_economy_locations():
					MyLog.info("CaravanDemo", "    [%s] Food=%.0f Cloth=%.0f Tools=%.0f Lux=%.0f" % [
						loc.location_name,
						loc.inventory.get_available(food),
						loc.inventory.get_available(cloth),
						loc.inventory.get_available(tools),
						loc.inventory.get_available(luxury),
					])

	presenter.game_clock.pause()

	MyLog.info("CaravanDemo", "")
	_print_final_summary()

	MyLog.info("CaravanDemo", "")
	MyLog.info("CaravanDemo", "=== ASSERTIONS ===")

	var castle_loc := world.get_location_by_id("castle")
	_assert_gte("Castle food inventory exists", castle_loc.inventory.get_available(food), 0.0)
	var castle_cloth := castle_loc.inventory.get_available(cloth)
	var castle_luxury := castle_loc.inventory.get_available(luxury)
	_assert_gt("Castle received trade goods", castle_cloth + castle_luxury, 0.0)

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

	MyLog.info("CaravanDemo", "")
	MyLog.info("CaravanDemo", "Results: %d PASS, %d FAIL" % [_pass_count, _fail_count])
	if _fail_count > 0:
		MyLog.error("CaravanDemo", "SOME ASSERTIONS FAILED")
	else:
		MyLog.info("CaravanDemo", "ALL ASSERTIONS PASSED")

	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _print_final_summary() -> void:
	MyLog.info("CaravanDemo", "=== CARAVAN FINAL SUMMARY ===")
	MyLog.info("CaravanDemo", "Active shipments: %d" % presenter.game_scenario.world.economy_engine.active_shipment_count)

	for loc in world.get_economy_locations():
		MyLog.info("CaravanDemo", "  [%s] Food=%.0f Cloth=%.0f Tools=%.0f Lux=%.0f" % [
			loc.location_name,
			loc.inventory.get_available(food),
			loc.inventory.get_available(cloth),
			loc.inventory.get_available(tools),
			loc.inventory.get_available(luxury),
		])

	for squad in world.roaming_squads:
		if squad.is_caravan():
			MyLog.info("CaravanDemo", "  In-transit: %s @ %s → %s" % [
				squad.squad_name, squad.current_location_id, squad.cargo.destination_id,
			])


func _assert_gt(label: String, actual: Variant, minimum: Variant) -> void:
	if actual > minimum:
		_pass_count += 1
		MyLog.info("CaravanDemo", "  PASS: %s = %s (> %s)" % [label, str(actual), str(minimum)])
	else:
		_fail_count += 1
		MyLog.error("CaravanDemo", "  FAIL: %s = %s (expected > %s)" % [label, str(actual), str(minimum)])


func _assert_gte(label: String, actual: Variant, minimum: Variant) -> void:
	if actual >= minimum:
		_pass_count += 1
		MyLog.info("CaravanDemo", "  PASS: %s = %s (>= %s)" % [label, str(actual), str(minimum)])
	else:
		_fail_count += 1
		MyLog.error("CaravanDemo", "  FAIL: %s = %s (expected >= %s)" % [label, str(actual), str(minimum)])


func _assert_true(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		MyLog.info("CaravanDemo", "  PASS: %s" % label)
	else:
		_fail_count += 1
		MyLog.error("CaravanDemo", "  FAIL: %s" % label)
