extends Node
## Tests the real StrategyPresenter's full production turn pipeline (karma-sorted phases, AI fleet, contacts, missions, triggerables) via a no-op HeadlessStrategyView. Run: godot --headless --path . scenes/demos/ai_act_demo.tscn

const SCENARIO_PATH := "res://resources/strategy/scenarios/goetz-official/scenario.tres"
const HeadlessView = preload("res://src/demos/headless_strategy_view.gd")

var presenter: StrategyPresenter
var player_squad: StrategySquad

var _events_fired_this_turn: Array[String] = []
var _missions_completed_this_turn: Array[String] = []
var _all_events_fired: Array[String] = []
var _all_missions_completed: Array[String] = []
var _pass_count: int = 0
var _fail_count: int = 0


func _ready():
	MyLog.set_level(MyLog.Level.DEBUG)
	MyLog.info("AIActDemo", "=== AI ACT HEADLESS TEST (Presenter Mode) ===")

	var mock_view = HeadlessView.new()
	add_child(mock_view)
	mock_view.setup_headless()

	presenter = StrategyPresenter.new()
	presenter.scenario_path = SCENARIO_PATH
	presenter.is_demo_scenario = false
	mock_view.add_child(presenter)

	await presenter.bind_view(mock_view)

	player_squad = presenter.actor.player_squad
	_hook_triggerable_logging()
	_retroactive_detect_game_start_events()
	_log_squad_state("INIT")
	_log_economy_state("INIT")

	var acts := _build_test_sequence()
	MyLog.info("AIActDemo", "Test sequence: %d acts" % acts.size())

	await _run_acts(acts)
	_print_summary()

	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _hook_triggerable_logging():
	var tm = presenter.game_scenario.triggerable_manager
	tm.triggerable_fired.connect(_on_triggerable_fired)


func _on_triggerable_fired(triggerable, _result):
	var tid = triggerable.trigger_id
	if triggerable is Mission:
		_missions_completed_this_turn.append(tid)
		_all_missions_completed.append(tid)
		MyLog.info("AIActDemo", "  MISSION COMPLETED: %s" % tid)
	else:
		_events_fired_this_turn.append(tid)
		_all_events_fired.append(tid)
		MyLog.info("AIActDemo", "  EVENT FIRED: %s" % tid)


func _retroactive_detect_game_start_events():
	for t in presenter.game_scenario.triggerable_manager.registered_triggerables:
		if t is GameEvent and t.times_triggered > 0:
			_all_events_fired.append(t.trigger_id)
			MyLog.info("AIActDemo", "  [INIT] Event already fired: %s (x%d)" % [t.trigger_id, t.times_triggered])
	for faction in presenter.game_scenario.factions:
		for mission in faction.missions:
			if mission.is_completed:
				_all_missions_completed.append(mission.mission_id)
				MyLog.info("AIActDemo", "  [INIT] Mission already completed: %s" % mission.mission_id)


func _build_test_sequence() -> Array[AIAct]:
	var acts: Array[AIAct] = []
	var T := StrategyTypes.ActivityType

	var a1 := AIAct.create(T.REST, "Act 1: Rest at Hornberg Castle — expect first_rest tutorial")
	a1.expect_location = "hornberg_castle"
	a1.expect_events_fired = ["tutorial_first_rest"]
	acts.append(a1)

	var a2 := AIAct.create(T.FORAGE, "Act 2: Forage for supplies")
	a2.expect_location = "hornberg_castle"
	acts.append(a2)

	var a3 := AIAct.create(T.TRAVEL, "Act 3: Travel to Oehringen — expect first_travel tutorial", "oehringen")
	a3.expect_location = "oehringen"
	a3.expect_events_fired = ["tutorial_first_travel"]
	acts.append(a3)

	var a4 := AIAct.create(T.REST, "Act 4: Rest at Oehringen")
	a4.expect_location = "oehringen"
	acts.append(a4)

	var a5 := AIAct.create(T.TRAVEL, "Act 5: Travel to Schwäbisch Hall", "schwaebisch_hall")
	a5.expect_location = "schwaebisch_hall"
	acts.append(a5)

	var a6 := AIAct.create(T.TRAVEL, "Act 6: Travel to Rothenburg", "rothenburg")
	a6.expect_location = "rothenburg"
	acts.append(a6)

	var a7 := AIAct.create(T.TRAVEL, "Act 7: Travel to Nuremberg — expect mission & city toll", "nuremberg")
	a7.expect_location = "nuremberg"
	a7.expect_events_fired = ["city_toll_event", "g1_march_to_nuremberg"]
	acts.append(a7)

	var a8 := AIAct.create(T.REST, "Act 8: Rest at Nuremberg — expect mission completion")
	a8.expect_location = "nuremberg"
	acts.append(a8)

	return acts


func _run_acts(acts: Array[AIAct]):
	for i in range(acts.size()):
		var act := acts[i]
		_events_fired_this_turn.clear()
		_missions_completed_this_turn.clear()

		MyLog.info("AIActDemo", "")
		MyLog.info("AIActDemo", "=== ACT %d: %s ===" % [i + 1, act.get_display_name()])
		if not act.description.is_empty():
			MyLog.info("AIActDemo", "  Description: %s" % act.description)

		await _execute_via_presenter(act)
		_check_assertions(act, i + 1)
		_log_squad_state("TURN %d" % (i + 1))
		_log_economy_state("TURN %d" % (i + 1))

		await get_tree().create_timer(0.1).timeout


func _execute_via_presenter(act: AIAct):
	if act.activity_type == StrategyTypes.ActivityType.TRAVEL:
		assert(not act.destination_id.is_empty(), "TRAVEL acts require destination_id")
		presenter.on_activity_requested(StrategyTypes.ActivityType.TRAVEL)
		presenter.on_travel_confirmed(act.destination_id)
		await _force_tick_and_wait()
		while presenter.actor.walking_towards["location"] != null:
			MyLog.debug("AIActDemo", "  Continuing travel towards %s..." % act.destination_id)
			await _force_tick_and_wait()
	elif act.activity_type == StrategyTypes.ActivityType.FORCE_MARCH:
		assert(not act.destination_id.is_empty(), "FORCE_MARCH acts require destination_id")
		presenter.on_activity_requested(StrategyTypes.ActivityType.FORCE_MARCH)
		presenter.on_travel_confirmed(act.destination_id)
		await _force_tick_and_wait()
		while presenter.actor.walking_towards["location"] != null:
			MyLog.debug("AIActDemo", "  Continuing force march towards %s..." % act.destination_id)
			await _force_tick_and_wait()
	else:
		presenter.on_activity_requested(act.activity_type)
		await _force_tick_and_wait()


func _force_tick_and_wait():
	presenter.game_clock.force_tick.call_deferred()
	await presenter.tick_completed


#region Assertions

func _check_assertions(act: AIAct, act_num: int):
	if not act.has_assertions():
		return

	MyLog.info("AIActDemo", "  --- Assertions for Act %d ---" % act_num)

	if not act.expect_location.is_empty():
		_assert_eq(
			"location",
			player_squad.current_location_id,
			act.expect_location,
		)

	if act.expect_min_food >= 0:
		_assert_gte("food", player_squad.food, act.expect_min_food)

	if act.expect_max_food >= 0:
		_assert_lte("food", player_squad.food, act.expect_max_food)

	if act.expect_min_morale > -9999:
		_assert_gte("morale", player_squad.get_morale(), act.expect_min_morale)

	if act.expect_min_warriors >= 0:
		_assert_gte(
			"living_warriors",
			player_squad.get_living_warriors().size(),
			act.expect_min_warriors,
		)

	if not act.expect_event_fired.is_empty():
		_assert_event_fired(act.expect_event_fired)

	for expected_event in act.expect_events_fired:
		_assert_event_fired(expected_event)


func _assert_eq(label: String, actual: Variant, expected: Variant):
	if actual == expected:
		_pass_count += 1
		MyLog.info("AIActDemo", "  PASS: %s == %s" % [label, actual])
	else:
		_fail_count += 1
		MyLog.error("AIActDemo", "  FAIL: %s == %s (expected %s)" % [label, actual, expected])


func _assert_gte(label: String, actual: Variant, minimum: Variant):
	if actual >= minimum:
		_pass_count += 1
		MyLog.info("AIActDemo", "  PASS: %s = %s (>= %s)" % [label, actual, minimum])
	else:
		_fail_count += 1
		MyLog.error("AIActDemo", "  FAIL: %s = %s (expected >= %s)" % [label, actual, minimum])


func _assert_lte(label: String, actual: Variant, maximum: Variant):
	if actual <= maximum:
		_pass_count += 1
		MyLog.info("AIActDemo", "  PASS: %s = %s (<= %s)" % [label, actual, maximum])
	else:
		_fail_count += 1
		MyLog.error("AIActDemo", "  FAIL: %s = %s (expected <= %s)" % [label, actual, maximum])


func _assert_event_fired(event_id: String):
	var found := event_id in _events_fired_this_turn or event_id in _missions_completed_this_turn
	if found:
		_pass_count += 1
		MyLog.info("AIActDemo", "  PASS: event/mission '%s' fired this act" % event_id)
	else:
		_fail_count += 1
		MyLog.error("AIActDemo", "  FAIL: event/mission '%s' NOT fired (events: %s, missions: %s)" % [
			event_id,
			_events_fired_this_turn,
			_missions_completed_this_turn,
		])

#endregion


func _log_squad_state(tag: String):
	var living = player_squad.get_living_warriors()
	var injured := 0
	for w in living:
		if w.is_injured:
			injured += 1
	MyLog.info("AIActDemo", "[%s] %s @ %s — Warriors:%d Injured:%d Morale:%.0f Food:%d Gold:%.0f" % [
		tag,
		player_squad.squad_name,
		player_squad.current_location_id,
		living.size(),
		injured,
		player_squad.get_morale(),
		player_squad.food,
		player_squad.money,
	])


func _log_economy_state(tag: String):
	var world = presenter.game_scenario.world
	assert(world.economy_engine != null, "AIActDemo requires initialized economy engine")
	MyLog.info("AIActDemo", "[%s] --- Economy State ---" % tag)
	for loc in world.get_economy_locations():
		var pop_count := loc.population.size() if loc.population else 0
		var avg_sat := loc.population.get_average_satisfaction() if loc.population else 0.0
		var food_stock := 0.0
		assert(loc.inventory != null, "AIActDemo economy location '%s' missing inventory" % loc.location_id)
		for thing in loc.inventory.stocks:
			if thing.thing_type == EconomyTypes.ThingType.FOOD:
				food_stock = loc.inventory.stocks[thing]
				break
		var fed_ratio := food_stock / maxf(pop_count, 1.0)
		MyLog.info("AIActDemo", "  %s: Pop=%d Sat=%.0f Food=%.0f (%.1f turns)" % [
			loc.location_name, pop_count, avg_sat, food_stock, fed_ratio])


func _print_summary():
	MyLog.info("AIActDemo", "")
	MyLog.info("AIActDemo", "=== TEST SUMMARY ===")
	MyLog.info("AIActDemo", "Assertions: %d passed, %d failed" % [_pass_count, _fail_count])
	MyLog.info("AIActDemo", "All events fired: %s" % [_all_events_fired])
	MyLog.info("AIActDemo", "All missions completed: %s" % [_all_missions_completed])
	_log_squad_state("FINAL")

	if _fail_count > 0:
		MyLog.error("AIActDemo", "SOME TESTS FAILED")
	else:
		MyLog.info("AIActDemo", "ALL TESTS PASSED")
