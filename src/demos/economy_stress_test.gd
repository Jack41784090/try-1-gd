extends Node
## Loads goetz-official through the real game's code path (GameScenario._setup_economy() → EconomyEngine.tick_full() → TradeMatcher → CaravanBridge) via StrategyPresenter + HeadlessStrategyView. Run: godot-mono --headless --path . scenes/demos/economy_stress_test.tscn

const SCENARIO_PATH := "res://resources/strategy/scenarios/goetz-official/scenario.tres"
const HeadlessView = preload("res://src/demos/headless_strategy_view.gd")

var presenter: StrategyPresenter
var world: World
var engine: EconomyEngine

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
var _bandit_count_history: Array[int] = []
var _bandit_pressure_history: Array[Dictionary] = []
var _route_safety_history: Array[float] = []
var _mercenary_locations_history: Array[int] = []

const MAX_ECONOMY_TURNS := 50
const LOG_INTERVAL := 5
const HOURS_PER_ECONOMY_TURN := 24

var _food_thing: Thing
var _cloth_thing: Thing
var _tools_thing: Thing
var _luxury_thing: Thing


func _ready() -> void:
	MyLog.set_level(MyLog.Level.WARN)
	print("")
	print("╔══════════════════════════════════════════════════════════╗")
	print("║   ECONOMY STRESS TEST — Real Pipeline (goetz-official) ║")
	print("╚══════════════════════════════════════════════════════════╝")
	print("")

	await _setup_presenter()

	for thing: Thing in world.goods:
		match thing.thing_id:
			"food": _food_thing = thing
			"cloth": _cloth_thing = thing
			"tools": _tools_thing = thing
			"luxury": _luxury_thing = thing

	_print_world_summary()
	await _run_simulation()


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
	engine = world.economy_engine
	assert(engine != null, "Economy engine not initialized — scenario must have goods + inventory")
	print("  Scenario loaded: %s" % SCENARIO_PATH)
	print("  Locations with economy: %d" % world.get_economy_locations().size())


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
	print("Running %d economy turns (%d hourly ticks)...\n" % [MAX_ECONOMY_TURNS, MAX_ECONOMY_TURNS * HOURS_PER_ECONOMY_TURN])

	presenter.on_activity_requested(StrategyTypes.ActivityType.REST)

	var economy_turn := 0
	var total_hours := MAX_ECONOMY_TURNS * HOURS_PER_ECONOMY_TURN

	for hour_idx in range(total_hours):
		var start_usec := Time.get_ticks_usec()

		presenter.game_clock.force_tick()
		if presenter.is_executing_activity:
			await presenter.tick_completed

		var elapsed_usec := Time.get_ticks_usec() - start_usec
		var elapsed_ms := elapsed_usec / 1000.0

		if world.current_hour % HOURS_PER_ECONOMY_TURN == 0:
			economy_turn += 1
			_turn_times.append(elapsed_ms)

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
					if p.satisfaction < 20.0:
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

			var gini_value := 0.0
			if not all_money.is_empty():
				var n := all_money.size()
				all_money.sort()
				var gini_total := 0.0
				for v in all_money:
					gini_total += v
				if gini_total > 0.0:
					var weighted_sum := 0.0
					for i in range(n):
						weighted_sum += (2.0 * (i + 1) - n - 1.0) * all_money[i]
					gini_value = weighted_sum / (n * gini_total)

			_gini_history.append(gini_value)
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

			if _food_thing:
				for loc in world.get_economy_locations():
					var loc_id := loc.location_id
					if not _food_price_history.has(loc_id):
						_food_price_history[loc_id] = []
					(_food_price_history[loc_id] as Array).append(loc.inventory.get_price(_food_thing))

			var bandit_count := 0
			for squad in world.roaming_squads:
				if squad.squad_role == StrategyTypes.SquadRole.BANDIT:
					bandit_count += 1
			_bandit_count_history.append(bandit_count)

			var spawner := BanditSpawner.new()
			var pressures: Dictionary = {}
			for loc in world.get_economy_locations():
				pressures[loc.location_name] = spawner.calculate_pressure(loc)
			_bandit_pressure_history.append(pressures)

			var danger_calc := RouteDangerCalculator.new()
			var total_safety := 0.0
			var route_count := 0
			for loc in world.get_economy_locations():
				if loc.connections == null:
					continue
				for conn in loc.connections.tt:
					var route: Array[String] = [loc.location_id, conn.to_location_id]
					total_safety += danger_calc.calculate_route_safety(route, world)
					route_count += 1
			var avg_safety := total_safety / maxf(float(route_count), 1.0)
			_route_safety_history.append(avg_safety)

			var merc_locs := 0
			for loc in world.get_economy_locations():
				if loc.has_activity_type(StrategyTypes.ActivityType.MERCENARY_WORK):
					merc_locs += 1
			_mercenary_locations_history.append(merc_locs)

			if economy_turn == 1 or economy_turn % LOG_INTERVAL == 0 or economy_turn == MAX_ECONOMY_TURNS:
				_print_turn_report(economy_turn, elapsed_ms)

	print("")

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
	print("── BANDIT SYSTEM ──")
	var peak_bandits := 0
	var peak_bandits_turn := 0
	for i in range(_bandit_count_history.size()):
		if _bandit_count_history[i] > peak_bandits:
			peak_bandits = _bandit_count_history[i]
			peak_bandits_turn = i + 1
	print("  Peak bandits: %d at turn %d" % [peak_bandits, peak_bandits_turn])
	print("  Final bandits: %d" % _bandit_count_history.back())
	print("  Route safety: %.3f → %.3f" % [_route_safety_history.front(), _route_safety_history.back()])
	var peak_merc := 0
	for m in _mercenary_locations_history:
		peak_merc = maxi(peak_merc, m)
	print("  Peak mercenary locations: %d" % peak_merc)
	print("  Final mercenary locations: %d" % _mercenary_locations_history.back())
	var peak_pressure := 0.0
	var peak_pressure_loc := ""
	var peak_pressure_turn := 0
	for i in range(_bandit_pressure_history.size()):
		var pdict: Dictionary = _bandit_pressure_history[i]
		for loc_name: String in pdict:
			var p: float = pdict[loc_name]
			if p > peak_pressure:
				peak_pressure = p
				peak_pressure_loc = loc_name
				peak_pressure_turn = i + 1
	print("  Peak pressure: %.3f at %s (turn %d)" % [peak_pressure, peak_pressure_loc, peak_pressure_turn])

	print("")
	print("── FOOD PRICES (turn 1 → %d) ──" % MAX_ECONOMY_TURNS)
	if _food_thing:
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
		var stock_parts: Array[String] = []
		for thing: Thing in world.goods:
			stock_parts.append("%s=%.0f@%.2f" % [
				thing.thing_name.left(5),
				loc.inventory.get_available(thing),
				loc.inventory.get_price(thing),
			])
		print("    %s" % "  ".join(stock_parts))

	print("")
	print("── INTERESTING PHENOMENA ──")

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
		print("  ✗ FROZEN SOCIETY: Zero social mobility in %d turns" % MAX_ECONOMY_TURNS)

	var phen_final_counts: Dictionary = _class_counts_history.back()
	var phen_initial_counts: Dictionary = _class_counts_history.front()
	if phen_final_counts["bourgeois"] > phen_initial_counts["bourgeois"] * 2:
		print("  ★ BOURGEOIS EXPLOSION: merchant class more than doubled (%d → %d)" % [
			phen_initial_counts["bourgeois"], phen_final_counts["bourgeois"],
		])

	var phen_bank_info := engine.get_bank_info()
	var printed: float = phen_bank_info.get("total_printed", 0.0)
	var reserves: float = phen_bank_info.get("reserves", 0.0)
	var outstanding: float = phen_bank_info.get("outstanding", 0.0)

	if printed > _total_money_history.back() * 3:
		print("  ⚠ MONEY PRINTING OUTPACES CIRCULATION: bank created %.0f but only %.0f circulates" % [
			printed, _total_money_history.back(),
		])

	var debt_ratio := outstanding / maxf(_total_money_history.back(), 1.0)
	if debt_ratio > 0.5:
		print("  ⚠ DEBT CRISIS: outstanding debt is %.0f%% of circulating money" % [debt_ratio * 100])

	if _food_thing:
		var max_price := 0.0
		var max_price_loc := ""
		for loc in world.get_economy_locations():
			var p := loc.inventory.get_price(_food_thing)
			if p > max_price:
				max_price = p
				max_price_loc = loc.location_name
		if max_price > _food_thing.base_price * 2.5:
			print("  ⚠ FOOD CRISIS: price peaked at %.2f in %s (base: %.2f)" % [max_price, max_price_loc, _food_thing.base_price])

	for loc in world.get_economy_locations():
		if loc.population.get_average_satisfaction() < 25.0:
			print("  ⚠ UNREST: %s satisfaction at %.0f — population deeply unhappy" % [
				loc.location_name, loc.population.get_average_satisfaction(),
			])

	if _food_thing:
		var has_surplus := false
		var has_deficit := false
		for loc in world.get_economy_locations():
			var f := loc.inventory.get_available(_food_thing)
			var demand := loc.population.get_total_demand(_food_thing)
			if f > demand * 3:
				has_surplus = true
			if f < demand * 0.3:
				has_deficit = true
		if has_surplus and has_deficit:
			print("  ⚠ DISTRIBUTION FAILURE: some locations overflow while others starve")

	if printed > 0.0 and reserves > printed * 0.3:
		print("  ★ FISCAL SURPLUS: bank reserves are %.0f%% of total printed" % [
			reserves / maxf(printed, 1.0) * 100.0,
		])

	var late_gini_trend := 0.0
	var window := mini(20, _gini_history.size())
	if window >= 2:
		var recent := _gini_history.slice(_gini_history.size() - window)
		late_gini_trend = recent.back() - recent.front()
		if absf(late_gini_trend) < 0.01:
			print("  ○ EQUILIBRIUM: Gini stabilized in last %d turns (Δ%.4f)" % [window, late_gini_trend])

	var peak_b := 0
	for b in _bandit_count_history:
		peak_b = maxi(peak_b, b)
	if peak_b > 0:
		print("  ⚔ BANDIT ACTIVITY: peak %d gangs roaming trade routes" % peak_b)
		if _route_safety_history.back() < 0.8:
			print("  ⚠ TRADE ROUTES UNSAFE: avg safety %.3f — bandits suppressing commerce" % _route_safety_history.back())
	else:
		print("  ○ NO BANDITS: desperation pressure never exceeded spawn threshold")

	print("")

	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		get_tree().quit()
	else:
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()


func _print_turn_report(turn: int, ms: float) -> void:
	var gini := _gini_history[turn - 1]
	var starve_pct := _starvation_history[turn - 1]
	var counts: Dictionary = _class_counts_history[turn - 1]
	var wealth: Dictionary = _wealth_by_class_history[turn - 1]

	print("══════ Economy Turn %3d (Hour %d, %6.1f ms) ══════" % [turn, world.current_hour, ms])

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

	if _food_thing:
		var food_line := "  Food prices:"
		for loc in world.get_economy_locations():
			food_line += " %s=%.2f" % [loc.location_name.left(6), loc.inventory.get_price(_food_thing)]
		print(food_line)

		var stock_line := "  Food stocks:"
		for loc in world.get_economy_locations():
			stock_line += " %s=%.0f" % [loc.location_name.left(6), loc.inventory.get_available(_food_thing)]
		print(stock_line)

	print("  Moves in transit: %d" % engine.active_moves.size())

	var bandit_n := _bandit_count_history[turn - 1]
	var safety_n := _route_safety_history[turn - 1]
	var merc_n := _mercenary_locations_history[turn - 1]
	var pressure_dict: Dictionary = _bandit_pressure_history[turn - 1]
	var max_pressure := 0.0
	var max_pressure_loc := ""
	for loc_name: String in pressure_dict:
		var p: float = pressure_dict[loc_name]
		if p > max_pressure:
			max_pressure = p
			max_pressure_loc = loc_name
	print("  Bandits: %d  Avg Route Safety: %.3f  Merc Locations: %d  Max Pressure: %s(%.3f)" % [
		bandit_n, safety_n, merc_n, max_pressure_loc.left(10), max_pressure])

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
