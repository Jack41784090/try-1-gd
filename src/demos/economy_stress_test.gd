extends Node

var world: World
var engine: EconomyEngine
var food: Thing
var cloth: Thing
var tools: Thing
var luxury: Thing

var _turn_times: Array[float] = []
var _gini_history: Array[float] = []
var _starvation_history: Array[float] = []
var _promotion_history: Array[int] = []
var _food_price_history: Dictionary = {}
var _class_counts_history: Array[Dictionary] = []
var _wealth_by_class_history: Array[Dictionary] = []
var _total_money_history: Array[float] = []
var _bank_printed_history: Array[float] = []
var _bank_debt_history: Array[float] = []

const MAX_TURNS := 50
const LOG_INTERVAL := 5

func _ready() -> void:
	Log.set_level(Log.Level.WARN)
	print("")
	print("╔══════════════════════════════════════════════════════════╗")
	print("║     ECONOMY STRESS TEST — ~30,000 Population           ║")
	print("╚══════════════════════════════════════════════════════════╝")
	print("")

	_setup_world()
	_print_world_summary()
	_run_simulation()


func _setup_world() -> void:
	world = World.new()

	food = Thing.create("food", "Food", EconomyTypes.ThingType.FOOD, 1.0)
	cloth = Thing.create("cloth", "Cloth", EconomyTypes.ThingType.CLOTH, 3.0)
	tools = Thing.create("tools", "Tools", EconomyTypes.ThingType.TOOLS, 5.0)
	luxury = Thing.create("luxury", "Luxuries", EconomyTypes.ThingType.LUXURY, 15.0)
	world.goods = [food, cloth, tools, luxury]

	_setup_breadbasket()
	_setup_grain_village()
	_setup_vineyard()
	_setup_mining_town()
	_setup_market_town()
	_setup_great_city()
	_setup_port_city()
	_setup_castle()

	_connect("breadbasket", "grain_village", 1)
	_connect("breadbasket", "market_town", 2)
	_connect("grain_village", "market_town", 1)
	_connect("vineyard", "market_town", 1)
	_connect("mining_town", "market_town", 2)
	_connect("market_town", "great_city", 1)
	_connect("market_town", "port_city", 2)
	_connect("great_city", "port_city", 1)
	_connect("great_city", "castle", 1)
	_connect("port_city", "castle", 2)

	engine = EconomyEngine.new()
	engine.world = world
	engine.bank = CentralBank.new()
	engine.bank.loan_interest_rate = 0.06
	engine.bank.print_per_turn = 4000.0
	engine.noble_loan_threshold = 150.0
	engine.loan_amount = 1000.0
	engine.enable_csharp()
	print("  C# engine: ENABLED")
	world.economy_engine = engine


func _connect(from_id: String, to_id: String, time: int) -> void:
	var from_loc := world.get_location_by_id(from_id)
	var to_loc := world.get_location_by_id(to_id)
	from_loc.add_connection(to_id, time)
	to_loc.add_connection(from_id, time)


func _loc(loc_id: String, loc_name: String, loc_type: StrategyTypes.LocationType) -> Location:
	var loc := Location.new()
	loc.location_id = loc_id
	loc.location_name = loc_name
	loc.type = loc_type
	loc.development = 50
	loc.stability = 100.0
	world.add_location(loc)
	return loc


func _setup_breadbasket() -> void:
	var loc := _loc("breadbasket", "Breadbasket Plains", StrategyTypes.LocationType.VILLAGE)
	loc.population = Population.new()
	_add_batch(loc, 5000, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 2.0)
	_add_batch(loc, 200, "laborer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 1.0)
	_add_batch(loc, 50, "trader", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 10.0)
	_add_batch(loc, 10, "squire", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 100.0)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 8000.0)
	loc.inventory.init_thing(cloth, 600.0)

	loc.natural_resources = [
		NaturalResource.create(food, 12000.0),
		NaturalResource.create(cloth, 800.0),
	]


func _setup_grain_village() -> void:
	var loc := _loc("grain_village", "Grain Village", StrategyTypes.LocationType.VILLAGE)
	loc.population = Population.new()
	_add_batch(loc, 2000, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 2.0)
	_add_batch(loc, 100, "laborer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 1.0)
	_add_batch(loc, 20, "trader", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 8.0)
	_add_batch(loc, 6, "squire", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 80.0)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 4000.0)
	loc.inventory.init_thing(cloth, 300.0)

	loc.natural_resources = [
		NaturalResource.create(food, 5000.0),
		NaturalResource.create(cloth, 400.0),
	]


func _setup_vineyard() -> void:
	var loc := _loc("vineyard", "Vineyard Hills", StrategyTypes.LocationType.VILLAGE)
	loc.population = Population.new()
	_add_batch(loc, 1500, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 3.0)
	_add_batch(loc, 300, "craftsman", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.CRAFTSMAN, 5.0)
	_add_batch(loc, 40, "trader", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 15.0)
	_add_batch(loc, 8, "lord", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 120.0)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 3000.0)
	loc.inventory.init_thing(cloth, 100.0)
	loc.inventory.init_thing(luxury, 80.0)

	loc.natural_resources = [
		NaturalResource.create(food, 3600.0),
		NaturalResource.create_craft(luxury, 400.0),
	]


func _setup_mining_town() -> void:
	var loc := _loc("mining_town", "Iron Hills", StrategyTypes.LocationType.CITY)
	loc.population = Population.new()
	_add_batch(loc, 500, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 2.0)
	_add_batch(loc, 1200, "craftsman", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.CRAFTSMAN, 5.0)
	_add_batch(loc, 300, "laborer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 2.0)
	_add_batch(loc, 60, "trader", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 12.0)
	_add_batch(loc, 10, "mine_lord", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 200.0)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 6000.0)
	loc.inventory.init_thing(tools, 1000.0)

	loc.natural_resources = [
		NaturalResource.create(food, 1000.0),
		NaturalResource.create_craft(tools, 1000.0),
	]


func _setup_market_town() -> void:
	var loc := _loc("market_town", "Marktplatz", StrategyTypes.LocationType.CITY)
	loc.population = Population.new()
	_add_batch(loc, 800, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 3.0)
	_add_batch(loc, 1500, "craftsman", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.CRAFTSMAN, 5.0)
	_add_batch(loc, 500, "laborer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 3.0)
	_add_batch(loc, 400, "merchant", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 20.0)
	_add_batch(loc, 30, "guild_master", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 300.0)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 5000.0)
	loc.inventory.init_thing(cloth, 800.0)
	loc.inventory.init_thing(tools, 400.0)
	loc.inventory.init_thing(luxury, 120.0)

	loc.natural_resources = [
		NaturalResource.create(food, 1600.0),
		NaturalResource.create_craft(cloth, 800.0),
		NaturalResource.create_craft(tools, 500.0),
		NaturalResource.create_craft(luxury, 200.0),
	]


func _setup_great_city() -> void:
	var loc := _loc("great_city", "Kaiserstadt", StrategyTypes.LocationType.CITY)
	loc.population = Population.new()
	_add_batch(loc, 500, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 3.0)
	_add_batch(loc, 3000, "craftsman", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.CRAFTSMAN, 6.0)
	_add_batch(loc, 2000, "laborer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 3.0)
	_add_batch(loc, 500, "servant", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.SERVANT, 2.0)
	_add_batch(loc, 800, "merchant", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 30.0)
	_add_batch(loc, 80, "patrician", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 500.0)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 8000.0)
	loc.inventory.init_thing(cloth, 2000.0)
	loc.inventory.init_thing(tools, 1000.0)
	loc.inventory.init_thing(luxury, 400.0)

	loc.natural_resources = [
		NaturalResource.create(food, 1000.0),
		NaturalResource.create_craft(cloth, 1000.0),
		NaturalResource.create_craft(tools, 600.0),
		NaturalResource.create_craft(luxury, 500.0),
	]


func _setup_port_city() -> void:
	var loc := _loc("port_city", "Hafenstadt", StrategyTypes.LocationType.CITY)
	loc.population = Population.new()
	_add_batch(loc, 300, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 2.0)
	_add_batch(loc, 1500, "craftsman", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.CRAFTSMAN, 5.0)
	_add_batch(loc, 1000, "laborer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 3.0)
	_add_batch(loc, 200, "servant", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.SERVANT, 2.0)
	_add_batch(loc, 500, "merchant", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 25.0)
	_add_batch(loc, 40, "ship_lord", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 400.0)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 5000.0)
	loc.inventory.init_thing(cloth, 600.0)
	loc.inventory.init_thing(tools, 600.0)
	loc.inventory.init_thing(luxury, 200.0)

	loc.natural_resources = [
		NaturalResource.create(food, 600.0),
		NaturalResource.create_craft(tools, 500.0),
		NaturalResource.create_craft(luxury, 240.0),
	]


func _setup_castle() -> void:
	var loc := _loc("castle", "Kaiserpfalz", StrategyTypes.LocationType.CITY)
	loc.population = Population.new()
	_add_batch(loc, 100, "farmer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 2.0)
	_add_batch(loc, 200, "craftsman", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.CRAFTSMAN, 4.0)
	_add_batch(loc, 400, "servant", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.SERVANT, 2.0)
	_add_batch(loc, 100, "laborer", EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 2.0)
	_add_batch(loc, 50, "steward", EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 40.0)
	_add_batch(loc, 24, "baron", EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 800.0)

	loc.inventory = LocationInventory.new()
	loc.inventory.init_thing(food, 1600.0)
	loc.inventory.init_thing(cloth, 200.0)
	loc.inventory.init_thing(tools, 160.0)
	loc.inventory.init_thing(luxury, 120.0)

	loc.natural_resources = [
		NaturalResource.create(food, 200.0),
	]


func _add_batch(loc: Location, count: int, prefix: String, cls: EconomyTypes.SocialClass, job: EconomyTypes.JobType, money: float) -> void:
	for p in Population.create_batch(count, prefix, cls, job, money):
		loc.population.add_person(p)


func _print_world_summary() -> void:
	var total_pop := 0
	var total_peasants := 0
	var total_bourgeois := 0
	var total_nobles := 0

	print("┌─────────────────────┬───────┬─────────┬──────────┬────────┐")
	print("│ Location            │  Pop  │ Peasant │ Bourgeois│ Noble  │")
	print("├─────────────────────┼───────┼─────────┼──────────┼────────┤")

	for loc in world.get_economy_locations():
		var p := loc.population.get_by_class(EconomyTypes.SocialClass.PEASANT).size()
		var b := loc.population.get_by_class(EconomyTypes.SocialClass.BOURGEOIS).size()
		var n := loc.population.get_by_class(EconomyTypes.SocialClass.NOBLE).size()
		var t := loc.population.size()
		total_pop += t
		total_peasants += p
		total_bourgeois += b
		total_nobles += n
		print("│ %-19s │ %5d │  %5d  │   %5d  │  %4d  │" % [
			loc.location_name.left(19), t, p, b, n,
		])

	print("├─────────────────────┼───────┼─────────┼──────────┼────────┤")
	print("│ TOTAL               │ %5d │  %5d  │   %5d  │  %4d  │" % [
		total_pop, total_peasants, total_bourgeois, total_nobles,
	])
	print("└─────────────────────┴───────┴─────────┴──────────┴────────┘")
	print("")


func _run_simulation() -> void:
	print("Running %d turns...\n" % MAX_TURNS)

	for turn in range(1, MAX_TURNS + 1):
		var start_usec := Time.get_ticks_usec()
		var result := engine.tick(turn)
		var elapsed_usec := Time.get_ticks_usec() - start_usec
		var elapsed_ms := elapsed_usec / 1000.0
		_turn_times.append(elapsed_ms)

		engine.sync_full()
		_record_metrics(turn)

		if turn == 1 or turn % LOG_INTERVAL == 0 or turn == MAX_TURNS:
			_print_turn_report(turn, elapsed_ms, result)

	print("")
	_print_final_analysis()

	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		get_tree().quit()
	else:
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()


func _record_metrics(_turn: int) -> void:
	var all_money: Array[float] = []
	var starving := 0
	var total := 0
	var class_counts := {
		"peasant": 0,
		"bourgeois": 0,
		"noble": 0,
	}
	var wealth_by_class := {
		"peasant": 0.0,
		"bourgeois": 0.0,
		"noble": 0.0,
	}

	for loc in world.get_economy_locations():
		for p in loc.population.people:
			all_money.append(p.money)
			total += 1
			if not p._fed_this_turn and p.satisfaction < 30.0:
				starving += 1
			match p.social_class:
				EconomyTypes.SocialClass.PEASANT:
					class_counts["peasant"] += 1
					wealth_by_class["peasant"] += p.money
				EconomyTypes.SocialClass.BOURGEOIS:
					class_counts["bourgeois"] += 1
					wealth_by_class["bourgeois"] += p.money
				EconomyTypes.SocialClass.NOBLE:
					class_counts["noble"] += 1
					wealth_by_class["noble"] += p.money

	_gini_history.append(_calculate_gini(all_money))
	_starvation_history.append(float(starving) / maxf(float(total), 1.0) * 100.0)
	_promotion_history.append(engine.total_promotions)
	_class_counts_history.append(class_counts)
	_wealth_by_class_history.append(wealth_by_class)

	var total_money := 0.0
	for m in all_money:
		total_money += m
	_total_money_history.append(total_money)
	var bank_info := engine.get_bank_info()
	_bank_printed_history.append(bank_info.get("total_printed", 0.0))
	_bank_debt_history.append(bank_info.get("outstanding", 0.0))

	for loc in world.get_economy_locations():
		var loc_id := loc.location_id
		if not _food_price_history.has(loc_id):
			_food_price_history[loc_id] = []
		(_food_price_history[loc_id] as Array).append(loc.inventory.get_price(food))


func _calculate_gini(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var n := values.size()
	values.sort()
	var total := 0.0
	for v in values:
		total += v
	if total <= 0.0:
		return 0.0
	var weighted_sum := 0.0
	for i in range(n):
		weighted_sum += (2.0 * (i + 1) - n - 1.0) * values[i]
	return weighted_sum / (n * total)


func _print_turn_report(turn: int, ms: float, _result: EconomyTickResult) -> void:
	var gini := _gini_history[turn - 1]
	var starve_pct := _starvation_history[turn - 1]
	var counts: Dictionary = _class_counts_history[turn - 1]
	var wealth: Dictionary = _wealth_by_class_history[turn - 1]

	print("══════ Turn %3d (%6.1f ms) ══════" % [turn, ms])

	print("  Classes: Peasant=%d  Bourgeois=%d  Noble=%d  Promotions=%d" % [
		counts["peasant"], counts["bourgeois"], counts["noble"],
		engine.total_promotions,
	])

	var p_avg: float = float(wealth["peasant"]) / maxf(float(counts["peasant"]), 1.0)
	var b_avg: float = float(wealth["bourgeois"]) / maxf(float(counts["bourgeois"]), 1.0)
	var n_avg: float = float(wealth["noble"]) / maxf(float(counts["noble"]), 1.0)
	print("  Avg Wealth: Peasant=%.1f  Bourgeois=%.1f  Noble=%.1f" % [p_avg, b_avg, n_avg])
	print("  Gini=%.3f  Starving=%.1f%%  Money Supply=%.0f" % [
		gini, starve_pct, _total_money_history[turn - 1],
	])

	var bank_info := engine.get_bank_info()
	print("  Bank: printed=%.0f  reserves=%.0f  debt=%.0f  loans=%d" % [
		bank_info.get("total_printed", 0.0),
		bank_info.get("reserves", 0.0),
		bank_info.get("outstanding", 0.0),
		bank_info.get("active_loans", 0),
	])
	print("  Contracts: active=%d  completed=%d" % [
		engine.active_contracts_count,
		engine.completed_contracts_count,
	])

	var food_line := "  Food prices:"
	for loc in world.get_economy_locations():
		food_line += " %s=%.2f" % [loc.location_name.left(6), loc.inventory.get_price(food)]
	print(food_line)

	var stock_line := "  Food stocks:"
	for loc in world.get_economy_locations():
		stock_line += " %s=%.0f" % [loc.location_name.left(6), loc.inventory.get_available(food)]
	print(stock_line)

	print("  Moves in transit: %d" % engine.active_moves.size())

	var worst_loc := ""
	var worst_sat := 100.0
	var best_loc := ""
	var best_sat := 0.0
	for loc in world.get_economy_locations():
		var sat := loc.population.get_average_satisfaction()
		if sat < worst_sat:
			worst_sat = sat
			worst_loc = loc.location_name
		if sat > best_sat:
			best_sat = sat
			best_loc = loc.location_name
	print("  Satisfaction: best=%s(%.0f)  worst=%s(%.0f)" % [best_loc, best_sat, worst_loc, worst_sat])
	print("")


func _print_final_analysis() -> void:
	print("╔══════════════════════════════════════════════════════════╗")
	print("║                   FINAL ANALYSIS                       ║")
	print("╚══════════════════════════════════════════════════════════╝")
	print("")

	print("── PERFORMANCE ──")
	var avg_ms := 0.0
	var max_ms := 0.0
	var min_ms := 999999.0
	for t in _turn_times:
		avg_ms += t
		max_ms = maxf(max_ms, t)
		min_ms = minf(min_ms, t)
	avg_ms /= _turn_times.size()
	print("  Avg tick: %.1f ms  Min: %.1f ms  Max: %.1f ms  Total: %.1f s" % [
		avg_ms, min_ms, max_ms, avg_ms * _turn_times.size() / 1000.0,
	])

	print("")
	print("── SOCIAL MOBILITY ──")
	var final_counts: Dictionary = _class_counts_history.back()
	var initial_counts: Dictionary = _class_counts_history.front()
	print("  Peasants: %d → %d  (Δ%d)" % [
		initial_counts["peasant"], final_counts["peasant"],
		final_counts["peasant"] - initial_counts["peasant"],
	])
	print("  Bourgeois: %d → %d  (Δ%+d)" % [
		initial_counts["bourgeois"], final_counts["bourgeois"],
		final_counts["bourgeois"] - initial_counts["bourgeois"],
	])
	print("  Nobles: %d → %d  (unchanged — no demotion mechanic)" % [
		initial_counts["noble"], final_counts["noble"],
	])
	print("  Total promotions: %d" % engine.total_promotions)

	print("")
	print("── INEQUALITY ──")
	print("  Gini coefficient: %.3f → %.3f" % [
		_gini_history.front(), _gini_history.back(),
	])
	var final_wealth: Dictionary = _wealth_by_class_history.back()
	var total_wealth: float = float(final_wealth["peasant"]) + float(final_wealth["bourgeois"]) + float(final_wealth["noble"])
	if total_wealth > 0.0:
		print("  Wealth share (final):")
		print("    Peasants (%d people): %.0f Scrip (%.1f%%)" % [
			final_counts["peasant"], final_wealth["peasant"],
			final_wealth["peasant"] / total_wealth * 100.0,
		])
		print("    Bourgeois (%d people): %.0f Scrip (%.1f%%)" % [
			final_counts["bourgeois"], final_wealth["bourgeois"],
			final_wealth["bourgeois"] / total_wealth * 100.0,
		])
		print("    Nobles (%d people): %.0f Scrip (%.1f%%)" % [
			final_counts["noble"], final_wealth["noble"],
			final_wealth["noble"] / total_wealth * 100.0,
		])
		var noble_per_capita: float = float(final_wealth["noble"]) / maxf(float(final_counts["noble"]), 1.0)
		var peasant_per_capita: float = float(final_wealth["peasant"]) / maxf(float(final_counts["peasant"]), 1.0)
		if peasant_per_capita > 0.0:
			print("    Noble/Peasant per-capita ratio: %.1fx" % [noble_per_capita / peasant_per_capita])

	print("")
	print("── MONETARY SYSTEM ──")
	var final_bank := engine.get_bank_info()
	print("  Total printed: %.0f Scrip" % final_bank.get("total_printed", 0.0))
	print("  Outstanding debt: %.0f Scrip" % final_bank.get("outstanding", 0.0))
	print("  Interest collected: %.0f Scrip" % final_bank.get("total_interest_collected", 0.0))
	print("  Bank reserves: %.0f Scrip" % final_bank.get("reserves", 0.0))
	print("  Active loans: %d" % final_bank.get("active_loans", 0))
	print("  Money in circulation: %.0f → %.0f" % [
		_total_money_history.front(), _total_money_history.back(),
	])
	if _total_money_history.front() > 0:
		print("  Inflation factor: %.2fx" % [
			_total_money_history.back() / _total_money_history.front(),
		])

	print("")
	print("── FOOD SECURITY ──")
	var peak_starve := 0.0
	var peak_starve_turn := 0
	for i in range(_starvation_history.size()):
		if _starvation_history[i] > peak_starve:
			peak_starve = _starvation_history[i]
			peak_starve_turn = i + 1
	print("  Peak distress: %.1f%% at turn %d" % [peak_starve, peak_starve_turn])
	print("  Final distress: %.1f%%" % _starvation_history.back())

	print("")
	print("── FOOD PRICES (turn 1 → %d) ──" % MAX_TURNS)
	for loc in world.get_economy_locations():
		var prices: Array = _food_price_history[loc.location_id]
		var p_start: float = prices.front()
		var p_end: float = prices.back()
		var p_max := 0.0
		var p_min := 999.0
		for p: float in prices:
			p_max = maxf(p_max, p)
			p_min = minf(p_min, p)
		print("  %s: %.2f → %.2f  (range: %.2f–%.2f)" % [
			loc.location_name, p_start, p_end, p_min, p_max,
		])

	print("")
	print("── PER-LOCATION FINAL STATE ──")
	for loc in world.get_economy_locations():
		var sat := loc.population.get_average_satisfaction()
		var avg_m := loc.population.get_average_money()
		var peasants := loc.population.get_by_class(EconomyTypes.SocialClass.PEASANT).size()
		var bourgeois := loc.population.get_by_class(EconomyTypes.SocialClass.BOURGEOIS).size()
		var nobles := loc.population.get_by_class(EconomyTypes.SocialClass.NOBLE).size()
		print("  [%s] pop=%d (P:%d B:%d N:%d) sat=%.0f avg$=%.1f" % [
			loc.location_name, loc.population.size(), peasants, bourgeois, nobles, sat, avg_m,
		])
		print("    Food=%.0f@%.2f  Cloth=%.0f@%.2f  Tools=%.0f@%.2f  Lux=%.0f@%.2f" % [
			loc.inventory.get_available(food), loc.inventory.get_price(food),
			loc.inventory.get_available(cloth), loc.inventory.get_price(cloth),
			loc.inventory.get_available(tools), loc.inventory.get_price(tools),
			loc.inventory.get_available(luxury), loc.inventory.get_price(luxury),
		])

	print("")
	print("── INTERESTING PHENOMENA ──")
	_detect_phenomena()
	print("")


func _detect_phenomena() -> void:
	if _gini_history.back() > 0.6:
		print("  ⚠ EXTREME INEQUALITY: Gini %.3f suggests oligarchic wealth concentration" % _gini_history.back())
	elif _gini_history.back() > 0.4:
		print("  ⚠ HIGH INEQUALITY: Gini %.3f — significant wealth gap between classes" % _gini_history.back())

	if _gini_history.back() < _gini_history.front() - 0.05:
		print("  ↓ CONVERGENCE: Inequality decreased (%.3f → %.3f)" % [_gini_history.front(), _gini_history.back()])
	elif _gini_history.back() > _gini_history.front() + 0.05:
		print("  ↑ DIVERGENCE: Inequality increased (%.3f → %.3f)" % [_gini_history.front(), _gini_history.back()])

	if engine.total_promotions > 100:
		print("  ★ MASS SOCIAL MOBILITY: %d peasants rose to bourgeois" % engine.total_promotions)
	elif engine.total_promotions == 0:
		print("  ✗ FROZEN SOCIETY: Zero social mobility in %d turns" % MAX_TURNS)

	var final_counts: Dictionary = _class_counts_history.back()
	var initial_counts: Dictionary = _class_counts_history.front()
	if final_counts["bourgeois"] > initial_counts["bourgeois"] * 2:
		print("  ★ BOURGEOIS EXPLOSION: merchant class more than doubled (%d → %d)" % [
			initial_counts["bourgeois"], final_counts["bourgeois"],
		])

	if engine.bank.total_printed > _total_money_history.back() * 3:
		print("  ⚠ MONEY PRINTING OUTPACES CIRCULATION: bank created %.0f but only %.0f circulates" % [
			engine.bank.total_printed, _total_money_history.back(),
		])

	var debt_ratio := engine.bank.get_total_outstanding() / maxf(_total_money_history.back(), 1.0)
	if debt_ratio > 0.5:
		print("  ⚠ DEBT CRISIS: outstanding debt is %.0f%% of circulating money" % [debt_ratio * 100])

	var max_price := 0.0
	var max_price_loc := ""
	for loc in world.get_economy_locations():
		var p := loc.inventory.get_price(food)
		if p > max_price:
			max_price = p
			max_price_loc = loc.location_name
	if max_price > 2.5:
		print("  ⚠ FOOD CRISIS: price peaked at %.2f in %s (base: 1.00)" % [max_price, max_price_loc])

	for loc in world.get_economy_locations():
		if loc.population.get_average_satisfaction() < 25.0:
			print("  ⚠ UNREST: %s satisfaction at %.0f — population deeply unhappy" % [
				loc.location_name, loc.population.get_average_satisfaction(),
			])

	var has_surplus := false
	var has_deficit := false
	for loc in world.get_economy_locations():
		var f := loc.inventory.get_available(food)
		var demand := loc.population.get_total_demand(food)
		if f > demand * 3:
			has_surplus = true
		if f < demand * 0.3:
			has_deficit = true
	if has_surplus and has_deficit:
		print("  ⚠ DISTRIBUTION FAILURE: some locations overflow while others starve")

	if engine.bank.reserves > engine.bank.total_printed * 0.3:
		print("  ★ FISCAL SURPLUS: bank reserves are %.0f%% of total printed" % [
			engine.bank.reserves / maxf(engine.bank.total_printed, 1.0) * 100.0,
		])

	var late_gini_trend := 0.0
	var window := mini(20, _gini_history.size())
	if window >= 2:
		var recent := _gini_history.slice(_gini_history.size() - window)
		late_gini_trend = recent.back() - recent.front()
		if absf(late_gini_trend) < 0.01:
			print("  ○ EQUILIBRIUM: Gini stabilized in last %d turns (Δ%.4f)" % [window, late_gini_trend])
