extends Node
## Economy Demo — Uses the real StrategyPresenter + HeadlessStrategyView pipeline.
##
## Loads the goetz-official scenario through the same code path as the actual game.
## Usage: godot-mono --headless --path . scenes/demos/economy_demo.tscn

const SCENARIO_PATH := "res://resources/strategy/scenarios/goetz-official/scenario.tres"
const HeadlessView = preload("res://src/demos/headless_strategy_view.gd")

const MAX_ECONOMY_TURNS := 20
const HOURS_PER_ECONOMY_TURN := 24

var presenter: StrategyPresenter
var world: World
var engine: EconomyEngine

var _food_thing: Thing


func _ready() -> void:
	Log.set_level(Log.Level.WARN)
	print("\n" + "=".repeat(60))
	print("  ECONOMY DEMO — Real Pipeline (goetz-official)")
	print("=".repeat(60) + "\n")

	await _setup_presenter()

	# --- resolve food ---
	for thing: Thing in world.goods:
		if thing.thing_id == "food":
			_food_thing = thing
			break

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
	assert(engine != null, "Economy engine not initialized")
	print("Scenario loaded: %d locations with economy\n" % world.get_economy_locations().size())


func _print_world_summary() -> void:
	var total_pop := 0
	for loc in world.get_economy_locations():
		var pop := loc.population.size()
		total_pop += pop
		print("  [%s] pop=%d  food=%.0f" % [loc.location_name, pop, loc.inventory.get_available(_food_thing) if _food_thing else 0.0])
	print("  Total population: %d\n" % total_pop)


func _run_simulation() -> void:
	print("Running %d economy turns (%d hourly ticks)...\n" % [MAX_ECONOMY_TURNS, MAX_ECONOMY_TURNS * HOURS_PER_ECONOMY_TURN])

	presenter.on_activity_requested(StrategyTypes.ActivityType.REST)

	var economy_turn := 0
	var total_hours := MAX_ECONOMY_TURNS * HOURS_PER_ECONOMY_TURN

	for hour_idx in range(total_hours):
		presenter.game_clock.force_tick()
		if presenter.is_executing_activity:
			await presenter.tick_completed

		if world.current_hour % HOURS_PER_ECONOMY_TURN == 0:
			economy_turn += 1
			engine.sync_full()

			if economy_turn == 1 or economy_turn % 5 == 0 or economy_turn == MAX_ECONOMY_TURNS:
				_print_turn_report(economy_turn)

	print("")
	_print_final_summary()

	get_tree().quit()


func _print_turn_report(turn: int) -> void:
	print("--- Economy Turn %d (Hour %d) ---" % [turn, world.current_hour])

	for loc in world.get_economy_locations():
		var peasants := loc.population.get_by_class(EconomyTypes.SocialClass.PEASANT)
		var bourgeois := loc.population.get_by_class(EconomyTypes.SocialClass.BOURGEOIS)
		var nobles := loc.population.get_by_class(EconomyTypes.SocialClass.NOBLE)
		print("  [%s] pop=%d (P=%d B=%d N=%d) avg_sat=%.0f avg_money=%.1f food=%.0f@%.2f" % [
			loc.location_name,
			loc.population.size(),
			peasants.size(), bourgeois.size(), nobles.size(),
			loc.population.get_average_satisfaction(),
			loc.population.get_average_money(),
			loc.inventory.get_available(_food_thing) if _food_thing else 0.0,
			loc.inventory.get_price(_food_thing) if _food_thing else 0.0,
		])

	var bank_info := engine.get_bank_info()
	print("  Bank: printed=%.0f reserves=%.0f debt=%.0f loans=%d" % [
		bank_info.get("total_printed", 0.0),
		bank_info.get("reserves", 0.0),
		bank_info.get("outstanding", 0.0),
		bank_info.get("active_loans", 0),
	])

	var total_money := _calc_total_money()
	print("  Total money: %.0f  Deaths: %d  Births: %d  Promotions: %d" % [
		total_money, engine.total_deaths, engine.total_births, engine.total_promotions,
	])
	print("")


func _print_final_summary() -> void:
	engine.sync_full()
	print("=".repeat(60))
	print("  FINAL SUMMARY")
	print("=".repeat(60))

	var total_pop := 0
	for loc in world.get_economy_locations():
		total_pop += loc.population.size()
		print("  [%s] pop=%d avg_sat=%.0f avg_money=%.1f" % [
			loc.location_name,
			loc.population.size(),
			loc.population.get_average_satisfaction(),
			loc.population.get_average_money(),
		])

	print("")
	print("  Total population: %d" % total_pop)
	print("  Deaths: %d  Births: %d  Promotions: %d" % [
		engine.total_deaths, engine.total_births, engine.total_promotions,
	])
	var bank_info := engine.get_bank_info()
	print("  Bank: printed=%.0f debt=%.0f reserves=%.0f" % [
		bank_info.get("total_printed", 0.0),
		bank_info.get("outstanding", 0.0),
		bank_info.get("reserves", 0.0),
	])
	print("  Total money in circulation: %.0f" % _calc_total_money())
	print("=".repeat(60))


func _calc_total_money() -> float:
	var total := 0.0
	for loc in world.get_economy_locations():
		for p in loc.population.people:
			total += p.money
	return total
