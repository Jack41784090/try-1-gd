extends Node

var engine: EconomyEngine
var food: Thing

func _ready() -> void:
	Log.set_level(Log.Level.DEBUG)
	Log.info("EconDemo", "=== ECONOMY SIMULATION DEMO ===")

	_setup_world()
	_run_simulation()


func _setup_world() -> void:
	engine = EconomyEngine.new()

	food = Thing.create("food", "Food", EconomyTypes.ThingType.FOOD, 1.0)
	engine.register_goods([food])

	_setup_farmstead()
	_setup_market_town()
	_setup_castle()

	engine.set_travel_time("farmstead", "market_town", 1)
	engine.set_travel_time("market_town", "farmstead", 1)
	engine.set_travel_time("market_town", "castle", 1)
	engine.set_travel_time("castle", "market_town", 1)
	engine.set_travel_time("farmstead", "castle", 2)
	engine.set_travel_time("castle", "farmstead", 2)

	Log.info("EconDemo", "World: 3 locations, %d total people" % _total_population())


func _setup_farmstead() -> void:
	var pop := Population.new()
	for p in Population.create_batch(50, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 5.0):
		pop.add_person(p)
	for p in Population.create_batch(5, "trader", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 50.0):
		pop.add_person(p)

	var inv := LocationInventory.new()
	inv.init_thing(food, 20.0)

	var rules: Array[SupplyRule] = [
		SupplyRule.create_extract("farmstead_harvest", food, 200.0),
	]

	engine.register_location("farmstead", "Farmstead", pop, inv, rules)
	Log.info("EconDemo", "Farmstead: %d people (50 farmers, 5 merchants) — capacity 200 food/turn" % pop.size())


func _setup_market_town() -> void:
	var pop := Population.new()
	for p in Population.create_batch(20, "laborer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 3.0):
		pop.add_person(p)
	for p in Population.create_batch(30, "merchant", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 50.0):
		pop.add_person(p)
	for p in Population.create_batch(10, "lord", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 200.0):
		pop.add_person(p)

	var inv := LocationInventory.new()
	inv.init_thing(food, 10.0)

	var rules: Array[SupplyRule] = [
		SupplyRule.create_import("town_import_food", food, "farmstead", 100.0),
	]

	engine.register_location("market_town", "Market Town", pop, inv, rules)
	Log.info("EconDemo", "Market Town: %d people (20 laborers, 30 merchants, 10 nobles)" % pop.size())


func _setup_castle() -> void:
	var pop := Population.new()
	for p in Population.create_batch(10, "servant", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.SERVANT, 2.0):
		pop.add_person(p)
	for p in Population.create_batch(5, "baron", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 500.0):
		pop.add_person(p)

	var inv := LocationInventory.new()
	inv.init_thing(food, 5.0)

	var rules: Array[SupplyRule] = [
		SupplyRule.create_import("castle_import_food", food, "market_town", 30.0),
		SupplyRule.create_import("castle_direct_food", food, "farmstead", 20.0, 1),
	]

	engine.register_location("castle", "Castle", pop, inv, rules)
	Log.info("EconDemo", "Castle: %d people (10 servants, 5 nobles)" % pop.size())


func _run_simulation() -> void:
	var max_turns := 20
	var disruption_turn := 10

	Log.info("EconDemo", "Running %d turns (disruption at turn %d)..." % [max_turns, disruption_turn])
	Log.info("EconDemo", "")

	for turn in range(1, max_turns + 1):
		if turn == disruption_turn:
			Log.info("EconDemo", "!!! DISRUPTION: Farmstead food production HALVED !!!")
			var rules: Array = engine.supply_rules["farmstead"]
			for rule: SupplyRule in rules:
				if rule.action == EconomyTypes.RuleAction.EXTRACT:
					rule.capacity_per_turn = 100.0

		var result := engine.tick(turn)
		result.log_to_console()

		if turn % 5 == 0 or turn == 1 or turn == disruption_turn or turn == disruption_turn + 1:
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
	for loc_id in engine.locations:
		var pop: Population = engine.populations[loc_id]
		var inv: LocationInventory = engine.inventories[loc_id]
		var peasants := pop.get_by_class(EconomyTypes.SocialClass.PEASANT)
		var bourgeois := pop.get_by_class(EconomyTypes.SocialClass.BOURGEOIS)
		var nobles := pop.get_by_class(EconomyTypes.SocialClass.NOBLE)

		Log.info("EconDemo", "  [%s] food=%.1f price=%.2f" % [
			engine.locations[loc_id],
			inv.get_available(food),
			inv.get_price(food),
		])
		if not peasants.is_empty():
			var avg_m := _avg_money(peasants)
			var avg_s := _avg_satisfaction(peasants)
			Log.info("EconDemo", "    Peasants(%d): avg_money=%.1f avg_sat=%.0f" % [peasants.size(), avg_m, avg_s])
		if not bourgeois.is_empty():
			var avg_m := _avg_money(bourgeois)
			var avg_s := _avg_satisfaction(bourgeois)
			Log.info("EconDemo", "    Bourgeois(%d): avg_money=%.1f avg_sat=%.0f" % [bourgeois.size(), avg_m, avg_s])
		if not nobles.is_empty():
			var avg_m := _avg_money(nobles)
			var avg_s := _avg_satisfaction(nobles)
			Log.info("EconDemo", "    Nobles(%d): avg_money=%.1f avg_sat=%.0f" % [nobles.size(), avg_m, avg_s])
	Log.info("EconDemo", "  Active trade moves: %d" % engine.active_moves.size())


func _print_final_summary() -> void:
	Log.info("EconDemo", "=== FINAL SUMMARY ===")
	for loc_id in engine.locations:
		var pop: Population = engine.populations[loc_id]
		var inv: LocationInventory = engine.inventories[loc_id]
		Log.info("EconDemo", "[%s] pop=%d avg_sat=%.0f food=%.1f price=%.2f avg_money=%.1f" % [
			engine.locations[loc_id],
			pop.size(),
			pop.get_average_satisfaction(),
			inv.get_available(food),
			inv.get_price(food),
			pop.get_average_money(),
		])

	var total_food := 0.0
	var total_money := 0.0
	for loc_id in engine.populations:
		var pop: Population = engine.populations[loc_id]
		var inv: LocationInventory = engine.inventories[loc_id]
		total_food += inv.get_available(food)
		for p in pop.people:
			total_money += p.money
			total_food += p.get_food_in_inventory(food)
	Log.info("EconDemo", "Global: total_food=%.1f total_money=%.1f" % [total_food, total_money])


func _total_population() -> int:
	var total := 0
	for loc_id in engine.populations:
		total += (engine.populations[loc_id] as Population).size()
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
