extends Node

var world: World
var engine: EconomyEngine
var food: Thing
var cloth: Thing
var tools: Thing
var luxury: Thing

func _ready() -> void:
	Log.set_level(Log.Level.DEBUG)
	Log.info("EconDemo", "=== ECONOMY SIMULATION: MONEY FLOW DEMO ===")
	Log.info("EconDemo", "Central Bank prints Imperial Scrip -> loans to Nobles -> contracts -> wages to workers")
	Log.info("EconDemo", "")

	_setup_world()
	_run_simulation()


func _setup_world() -> void:
	world = World.new()

	food = Thing.create("food", "Food", EconomyTypes.ThingType.FOOD, 1.0)
	cloth = Thing.create("cloth", "Cloth", EconomyTypes.ThingType.CLOTH, 3.0)
	tools = Thing.create("tools", "Tools", EconomyTypes.ThingType.TOOLS, 5.0)
	luxury = Thing.create("luxury", "Luxuries", EconomyTypes.ThingType.LUXURY, 15.0)
	world.goods = [food, cloth, tools, luxury]

	_setup_farmstead()
	_setup_market_town()
	_setup_castle()

	_connect_locations("farmstead", "market_town", 1)
	_connect_locations("market_town", "castle", 1)
	_connect_locations("farmstead", "castle", 2)

	engine = EconomyEngine.new()
	engine.world = world
	engine.bank = CentralBank.new()
	engine.bank.loan_interest_rate = 0.08
	engine.bank.print_per_turn = 500.0
	engine.noble_loan_threshold = 100.0
	engine.loan_amount = 500.0
	world.economy_engine = engine

	Log.info("EconDemo", "World: 3 locations, %d total people" % _total_population())
	Log.info("EconDemo", "Bank: rate=%.0f%% loan_size=%.0f threshold=%.0f" % [
		engine.bank.loan_interest_rate * 100.0,
		engine.loan_amount,
		engine.noble_loan_threshold,
	])


func _connect_locations(from_id: String, to_id: String, time: int) -> void:
	var from_loc := world.get_location_by_id(from_id)
	var to_loc := world.get_location_by_id(to_id)
	from_loc.add_connection(to_id, time)
	to_loc.add_connection(from_id, time)


func _create_location(loc_id: String, loc_name: String, loc_type: StrategyTypes.LocationType) -> Location:
	var loc := Location.new()
	loc.location_id = loc_id
	loc.location_name = loc_name
	loc.type = loc_type
	loc.development = 50
	loc.stability = 100.0
	world.add_location(loc)
	return loc


func _setup_farmstead() -> void:
	var loc := _create_location("farmstead", "Farmstead", StrategyTypes.LocationType.VILLAGE)

	loc.population = Population.new()
	for p in Population.create_batch(50, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 0.0):
		loc.population.add_person(p)
	for p in Population.create_batch(5, "trader", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 5.0):
		loc.population.add_person(p)
	for p in Population.create_batch(2, "squire", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 50.0):
		loc.population.add_person(p)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 60.0)
	loc.inventory.init_thing(cloth, 10.0)

	loc.supply_rules = [
		SupplyRule.create_extract("farmstead_harvest", food, 250.0),
		SupplyRule.create_extract("farmstead_spinning", cloth, 50.0),
	]

	Log.info("EconDemo", "Farmstead: %d people (50 farmers, 5 merchants, 2 squires) - food+cloth" % loc.population.size())


func _setup_market_town() -> void:
	var loc := _create_location("market_town", "Market Town", StrategyTypes.LocationType.CITY)

	loc.population = Population.new()
	for p in Population.create_batch(10, "laborer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 5.0):
		loc.population.add_person(p)
	for p in Population.create_batch(15, "craftsman", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.CRAFTSMAN, 5.0):
		loc.population.add_person(p)
	for p in Population.create_batch(25, "merchant", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 5.0):
		loc.population.add_person(p)
	for p in Population.create_batch(10, "lord", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 50.0):
		loc.population.add_person(p)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 60.0)
	loc.inventory.init_thing(cloth, 5.0)
	loc.inventory.init_thing(tools, 5.0)
	loc.inventory.init_thing(luxury, 2.0)

	loc.supply_rules = [
		SupplyRule.create_import("town_import_food", food, "farmstead", 100.0),
		SupplyRule.create_import("town_import_cloth", cloth, "farmstead", 50.0),
		SupplyRule.create_craft("town_weaving", cloth, 15.0),
		SupplyRule.create_craft("town_toolsmith", tools, 25.0),
		SupplyRule.create_craft("town_luxuries", luxury, 20.0),
	]

	Log.info("EconDemo", "Market Town: %d people (10 laborers, 15 craftsmen, 25 merchants, 10 lords) - tools+luxuries" % loc.population.size())


func _setup_castle() -> void:
	var loc := _create_location("castle", "Castle", StrategyTypes.LocationType.CITY)

	loc.population = Population.new()
	for p in Population.create_batch(10, "servant", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.SERVANT, 5.0):
		loc.population.add_person(p)
	for p in Population.create_batch(5, "baron", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 50.0):
		loc.population.add_person(p)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 20.0)
	loc.inventory.init_thing(cloth, 3.0)
	loc.inventory.init_thing(tools, 2.0)
	loc.inventory.init_thing(luxury, 1.0)

	loc.supply_rules = [
		SupplyRule.create_import("castle_import_food", food, "market_town", 20.0),
		SupplyRule.create_import("castle_direct_food", food, "farmstead", 40.0, 1),
		SupplyRule.create_import("castle_import_cloth", cloth, "market_town", 15.0),
		SupplyRule.create_import("castle_import_tools", tools, "market_town", 10.0),
		SupplyRule.create_import("castle_import_luxury", luxury, "market_town", 10.0),
	]

	Log.info("EconDemo", "Castle: %d people (10 servants, 5 barons)" % loc.population.size())


func _run_simulation() -> void:
	var max_turns := 40
	Log.info("EconDemo", "Running %d turns..." % max_turns)
	Log.info("EconDemo", "")

	for turn in range(1, max_turns + 1):
		var result := engine.tick(turn)
		result.log_to_console()

		if turn <= 3 or turn % 5 == 0 or turn == max_turns:
			_print_detailed_snapshot(turn)

	Log.info("EconDemo", "")
	_print_final_summary()

	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		get_tree().quit()
	else:
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()


func _print_detailed_snapshot(turn: int) -> void:
	Log.info("EconDemo", "--- Detailed Snapshot (Turn %d) ---" % turn)
	for loc in world.get_economy_locations():
		var peasants := loc.population.get_by_class(EconomyTypes.SocialClass.PEASANT)
		var bourgeois := loc.population.get_by_class(EconomyTypes.SocialClass.BOURGEOIS)
		var nobles := loc.population.get_by_class(EconomyTypes.SocialClass.NOBLE)

		Log.info("EconDemo", "  [%s] Food=%.0f@%.2f Cloth=%.0f@%.2f Tools=%.0f@%.2f Lux=%.0f@%.2f" % [
			loc.location_name,
			loc.inventory.get_available(food), loc.inventory.get_price(food),
			loc.inventory.get_available(cloth), loc.inventory.get_price(cloth),
			loc.inventory.get_available(tools), loc.inventory.get_price(tools),
			loc.inventory.get_available(luxury), loc.inventory.get_price(luxury),
		])
		if not peasants.is_empty():
			Log.info("EconDemo", "    Peasants(%d): avg_money=%.1f avg_sat=%.0f" % [
				peasants.size(), _avg_money(peasants), _avg_satisfaction(peasants),
			])
		if not bourgeois.is_empty():
			Log.info("EconDemo", "    Bourgeois(%d): avg_money=%.1f avg_sat=%.0f" % [
				bourgeois.size(), _avg_money(bourgeois), _avg_satisfaction(bourgeois),
			])
		if not nobles.is_empty():
			Log.info("EconDemo", "    Nobles(%d): avg_money=%.1f avg_sat=%.0f" % [
				nobles.size(), _avg_money(nobles), _avg_satisfaction(nobles),
			])

	Log.info("EconDemo", "  Bank: printed=%.0f reserves=%.0f outstanding=%.0f interest=%.0f" % [
		engine.bank.total_printed,
		engine.bank.reserves,
		engine.bank.get_total_outstanding(),
		engine.bank.total_interest_collected,
	])
	Log.info("EconDemo", "  Contracts: active=%d completed=%d" % [
		engine.active_contracts.size(),
		engine.completed_contracts.size(),
	])
	var total_money := _calc_total_money()
	Log.info("EconDemo", "  Total Scrip in circulation: %.0f" % total_money)


func _print_final_summary() -> void:
	Log.info("EconDemo", "=== FINAL SUMMARY ===")
	for loc in world.get_economy_locations():
		Log.info("EconDemo", "[%s] pop=%d avg_sat=%.0f avg_money=%.1f" % [
			loc.location_name,
			loc.population.size(),
			loc.population.get_average_satisfaction(),
			loc.population.get_average_money(),
		])
		Log.info("EconDemo", "  Goods: Food=%.0f Cloth=%.0f Tools=%.0f Lux=%.0f" % [
			loc.inventory.get_available(food), loc.inventory.get_available(cloth),
			loc.inventory.get_available(tools), loc.inventory.get_available(luxury),
		])
		var peasant_count := loc.population.get_by_class(EconomyTypes.SocialClass.PEASANT).size()
		var bourgeois_count := loc.population.get_by_class(EconomyTypes.SocialClass.BOURGEOIS).size()
		var noble_count := loc.population.get_by_class(EconomyTypes.SocialClass.NOBLE).size()
		Log.info("EconDemo", "  Classes: Peasants=%d Bourgeois=%d Nobles=%d" % [
			peasant_count, bourgeois_count, noble_count,
		])

	Log.info("EconDemo", "")
	Log.info("EconDemo", "=== MONEY FLOW ANALYSIS ===")
	Log.info("EconDemo", "Total Scrip printed: %.0f" % engine.bank.total_printed)
	Log.info("EconDemo", "Outstanding debt: %.0f" % engine.bank.get_total_outstanding())
	Log.info("EconDemo", "Interest collected: %.0f" % engine.bank.total_interest_collected)
	Log.info("EconDemo", "Active loans: %d" % engine.bank.active_loans.size())
	Log.info("EconDemo", "Contracts completed: %d" % engine.completed_contracts.size())
	Log.info("EconDemo", "Peasants promoted to Bourgeois: %d" % engine.total_promotions)

	var noble_money := 0.0
	var merchant_money := 0.0
	var worker_money := 0.0
	var total := 0.0
	for loc in world.get_economy_locations():
		for p in loc.population.people:
			total += p.money
			match p.social_class:
				EconomyTypes.SocialClass.NOBLE:
					noble_money += p.money
				EconomyTypes.SocialClass.BOURGEOIS:
					merchant_money += p.money
				EconomyTypes.SocialClass.PEASANT:
					worker_money += p.money

	Log.info("EconDemo", "")
	Log.info("EconDemo", "=== WEALTH DISTRIBUTION ===")
	Log.info("EconDemo", "Nobles hold: %.0f Scrip (%.0f%%)" % [noble_money, noble_money / maxf(total, 1.0) * 100.0])
	Log.info("EconDemo", "Merchants hold: %.0f Scrip (%.0f%%)" % [merchant_money, merchant_money / maxf(total, 1.0) * 100.0])
	Log.info("EconDemo", "Workers hold: %.0f Scrip (%.0f%%)" % [worker_money, worker_money / maxf(total, 1.0) * 100.0])
	Log.info("EconDemo", "Total circulating: %.0f Scrip" % total)


func _calc_total_money() -> float:
	var total := 0.0
	for loc in world.get_economy_locations():
		for p in loc.population.people:
			total += p.money
	return total


func _total_population() -> int:
	var total := 0
	for loc in world.get_economy_locations():
		total += loc.population.size()
	return total


func _avg_money(people: Array[EconPerson]) -> float:
	if people.is_empty():
		return 0.0
	var total := 0.0
	for p in people:
		total += p.money
	return total / people.size()


func _avg_satisfaction(people: Array[EconPerson]) -> float:
	if people.is_empty():
		return 0.0
	var total := 0.0
	for p in people:
		total += p.satisfaction
	return total / people.size()
