extends Node
## Validates pause/unpause behavior with HeadlessStrategyView. Run: godot --headless --path . scenes/demos/pause_system_test.tscn

const SCENARIO_PATH := "res://resources/strategy/scenarios/goetz-official/scenario.tres"
const HeadlessView = preload("res://src/demos/headless_strategy_view.gd")

var presenter: StrategyPresenter
var _pass_count: int = 0
var _fail_count: int = 0


func _ready():
	MyLog.set_level(MyLog.Level.INFO)
	MyLog.info("PauseTest", "=== PAUSE SYSTEM TEST ===")

	var mock_view = HeadlessView.new()
	add_child(mock_view)
	mock_view.setup_headless()

	presenter = StrategyPresenter.new()
	presenter.scenario_path = SCENARIO_PATH
	presenter.is_demo_scenario = false
	mock_view.add_child(presenter)

	await presenter.bind_view(mock_view)

	MyLog.info("PauseTest", "--- Test: Game starts paused ---")
	_assert_true(
		presenter.game_scenario.world.is_paused,
		"Game should start paused"
	)

	MyLog.info("PauseTest", "--- Test: Activity selection does not unpause ---")
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

	MyLog.info("PauseTest", "--- Test: Explicit pause toggle ---")
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

	MyLog.info("PauseTest", "--- Test: Menu handlers auto-pause ---")

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

	MyLog.info("PauseTest", "--- Test: Resting banner state ---")
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

	MyLog.info("PauseTest", "")
	MyLog.info("PauseTest", "=== RESULTS: %d passed, %d failed ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		MyLog.error("PauseTest", "SOME TESTS FAILED")
	else:
		MyLog.info("PauseTest", "ALL TESTS PASSED")

	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
		MyLog.info("PauseTest", "  PASS: %s" % msg)
	else:
		_fail_count += 1
		MyLog.error("PauseTest", "  FAIL: %s" % msg)


func _assert_eq(actual, expected, msg: String) -> void:
	if actual == expected:
		_pass_count += 1
		MyLog.info("PauseTest", "  PASS: %s" % msg)
	else:
		_fail_count += 1
		MyLog.error("PauseTest", "  FAIL: %s (expected %s, got %s)" % [msg, expected, actual])
