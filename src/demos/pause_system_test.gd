extends Node
## Pause System Test — Validates pause/unpause behavior with HeadlessStrategyView.
##
## Tests:
## 1. Game starts paused
## 2. Selecting an activity does NOT auto-unpause
## 3. Menu-opening handlers auto-pause
## 4. RESTING banner state tracks activity + pause
## 5. Explicit unpause via toggle works
##
## Usage: godot --headless --path . scenes/demos/pause_system_test.tscn

const SCENARIO_PATH := "res://resources/scenarios/goetz-official/scenario.tres"
const HeadlessView = preload("res://src/demos/headless_strategy_view.gd")

var presenter: StrategyPresenter
var _pass_count: int = 0
var _fail_count: int = 0


func _ready():
	Log.set_level(Log.Level.INFO)
	Log.info("PauseTest", "=== PAUSE SYSTEM TEST ===")

	var mock_view = HeadlessView.new()
	add_child(mock_view)
	mock_view.setup_headless()

	presenter = StrategyPresenter.new()
	presenter.scenario_path = SCENARIO_PATH
	presenter.is_demo_scenario = false
	mock_view.add_child(presenter)

	await presenter.bind_view(mock_view)

	_run_tests()

	Log.info("PauseTest", "")
	Log.info("PauseTest", "=== RESULTS: %d passed, %d failed ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		Log.error("PauseTest", "SOME TESTS FAILED")
	else:
		Log.info("PauseTest", "ALL TESTS PASSED")

	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _run_tests():
	_test_game_starts_paused()
	_test_activity_does_not_unpause()
	_test_pause_toggle()
	_test_menu_handlers_pause()
	_test_resting_banner_state()


func _test_game_starts_paused():
	Log.info("PauseTest", "--- Test: Game starts paused ---")
	_assert_true(
		presenter.game_scenario.world.is_paused,
		"Game should start paused"
	)


func _test_activity_does_not_unpause():
	Log.info("PauseTest", "--- Test: Activity selection does not unpause ---")
	presenter.game_clock.pause()
	_assert_true(presenter.game_scenario.world.is_paused, "Precondition: game is paused")

	presenter.on_activity_requested(StrategyTypes.ActivityType.DRILL)
	_assert_true(
		presenter.game_scenario.world.is_paused,
		"Game should remain paused after selecting DRILL"
	)
	_assert_eq(
		presenter.actor.player_squad.current_activity_type,
		StrategyTypes.ActivityType.DRILL,
		"Activity should be DRILL"
	)

	presenter.on_activity_requested(StrategyTypes.ActivityType.PATROL)
	_assert_true(
		presenter.game_scenario.world.is_paused,
		"Game should remain paused after selecting PATROL"
	)

	presenter.on_activity_requested(StrategyTypes.ActivityType.REST)
	_assert_true(
		presenter.game_scenario.world.is_paused,
		"Game should remain paused after selecting REST"
	)


func _test_pause_toggle():
	Log.info("PauseTest", "--- Test: Explicit pause toggle ---")
	presenter.game_clock.pause()
	_assert_true(presenter.game_scenario.world.is_paused, "Should be paused")

	presenter.on_pause_toggle()
	_assert_true(
		not presenter.game_scenario.world.is_paused,
		"Should be unpaused after toggle"
	)

	presenter.on_pause_toggle()
	_assert_true(
		presenter.game_scenario.world.is_paused,
		"Should be paused again after second toggle"
	)


func _test_menu_handlers_pause():
	Log.info("PauseTest", "--- Test: Menu handlers auto-pause ---")

	presenter.game_clock.unpause()
	_assert_true(not presenter.game_scenario.world.is_paused, "Precondition: game is unpaused")

	presenter.on_travel_requested()
	_assert_true(
		presenter.game_scenario.world.is_paused,
		"Travel menu should auto-pause"
	)

	presenter.game_clock.unpause()
	presenter.on_recruit_requested()
	_assert_true(
		presenter.game_scenario.world.is_paused,
		"Recruitment menu should auto-pause"
	)

	presenter.game_clock.unpause()
	presenter.on_manage_squad_requested()
	_assert_true(
		presenter.game_scenario.world.is_paused,
		"Manage squad menu should auto-pause"
	)

	presenter.game_clock.unpause()
	presenter.on_investigate_requested()
	_assert_true(
		presenter.game_scenario.world.is_paused,
		"Investigation menu should auto-pause"
	)

	presenter.game_clock.unpause()
	presenter.on_scouting_requested()
	_assert_true(
		presenter.game_scenario.world.is_paused,
		"Scouting menu should auto-pause"
	)

	presenter.game_clock.unpause()
	presenter.on_missions_requested()
	_assert_true(
		presenter.game_scenario.world.is_paused,
		"Missions menu should auto-pause"
	)


func _test_resting_banner_state():
	Log.info("PauseTest", "--- Test: Resting banner state ---")
	presenter.game_clock.pause()
	presenter.on_activity_requested(StrategyTypes.ActivityType.REST)
	var squad := presenter.actor.player_squad
	_assert_eq(
		squad.current_activity_type,
		StrategyTypes.ActivityType.REST,
		"Activity should be REST"
	)

	presenter.on_activity_requested(StrategyTypes.ActivityType.DRILL)
	_assert_eq(
		squad.current_activity_type,
		StrategyTypes.ActivityType.DRILL,
		"Activity should be DRILL after selecting drill"
	)

	presenter.on_activity_requested(StrategyTypes.ActivityType.REST)
	_assert_eq(
		squad.current_activity_type,
		StrategyTypes.ActivityType.REST,
		"Activity should return to REST"
	)


#region Assertions

func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
		Log.info("PauseTest", "  PASS: %s" % msg)
	else:
		_fail_count += 1
		Log.error("PauseTest", "  FAIL: %s" % msg)


func _assert_eq(actual, expected, msg: String) -> void:
	if actual == expected:
		_pass_count += 1
		Log.info("PauseTest", "  PASS: %s" % msg)
	else:
		_fail_count += 1
		Log.error("PauseTest", "  FAIL: %s (expected %s, got %s)" % [msg, expected, actual])

#endregion
