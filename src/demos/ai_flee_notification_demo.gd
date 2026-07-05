extends Node
## AI Flee + Notification Demo — Tests contact notifications when an AI squad
## constantly flees from the player.
##
## Boots the Goetz scenario via StrategyPresenter + HeadlessStrategyView,
## injects a fleeing AI squad ("Retreating Scouts") at oehringen,
## then drives player actions to build/lose contact while checking
## CONTACT_DETECTED, CONTACT_DECAYING, and CONTACT_LOST notifications.
##
## Usage: godot-mono --headless --path . scenes/demos/ai_flee_notification_demo.tscn

const SCENARIO_PATH := "res://resources/scenarios/goetz-official/scenario.tres"
const HeadlessView = preload("res://src/demos/headless_strategy_view.gd")

var presenter: StrategyPresenter
var player_squad: StrategySquad

var _pass_count: int = 0
var _fail_count: int = 0
var _notification_log: Array[Dictionary] = []


func _ready():
	Log.set_level(Log.Level.DEBUG)
	Log.info("FleeDmo", "=== AI FLEE + NOTIFICATION TEST ===")

	var mock_view = HeadlessView.new()
	add_child(mock_view)
	mock_view.setup_headless()

	presenter = StrategyPresenter.new()
	presenter.scenario_path = SCENARIO_PATH
	presenter.is_demo_scenario = false
	mock_view.add_child(presenter)

	await presenter.bind_view(mock_view)

	player_squad = presenter.actor.player_squad

	_inject_fleeing_squad()
	_assign_flee_profile()

	Log.info("FleeDmo", "Player: %s @ %s" % [player_squad.squad_name, player_squad.current_location_id])
	Log.info("FleeDmo", "AI squads: %d" % presenter.ai_fleet.get_ai_squad_count())
	_log_all_squad_positions()

	await _run_test_sequence()
	_print_summary()

	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _inject_fleeing_squad() -> void:
	var runner := SquadDataFactory.create_squad(
		"retreating_scouts",
		"Retreating Scouts",
		200.0,
		100,
		20,
		-10.0,
		"oehringen",
		"oehringen",
	)

	for i in range(3):
		var stats = CombatEntityBaseStats.new()
		var warrior = StrategyEntityFactory.Create(
			EntityClasses.Types.Landsknecht,
			"scout_%d" % i,
			"Scout %d" % (i + 1),
			StrategyTypes.Religion.CATHOLIC,
			stats,
		)
		warrior.attributes["diplomacy"] = 30
		warrior.attributes["survival"] = 60
		warrior.attributes["perception"] = 70
		warrior.attributes["leadership"] = 40
		warrior.attributes["stealth"] = 30
		runner.warriors.append(warrior)

	presenter.game_scenario.world.add_roaming_squad(runner)
	Log.info("FleeDmo", "Injected '%s' at oehringen with %d warriors" % [runner.squad_name, runner.warriors.size()])


func _assign_flee_profile() -> void:
	var flee_action = StrategicAction.new()
	flee_action.action_name = "always-flee"
	flee_action.activity_type = StrategyTypes.ActivityType.TRAVEL
	flee_action.requires_destination = true
	flee_action.destination_strategy = StrategicAITypes.DestinationStrategy.AWAY_FROM_ENEMY

	var flee_consideration = StrategicConsideration.new()
	flee_consideration.name = "always-flee"
	flee_consideration.weight = 100.0
	flee_consideration.returning = flee_action

	var rest_action = StrategicAction.new()
	rest_action.action_name = "fallback-rest"
	rest_action.activity_type = StrategyTypes.ActivityType.REST

	var config = SquadBrainConfig.new()
	config.profile_name = "always-flee"
	config.considerations.append(flee_consideration)
	config.fallback_action = rest_action

	var runner_id := "retreating_scouts"
	var runner_squad: StrategySquad = null
	for sq in presenter.game_scenario.world.roaming_squads:
		if sq.squad_id == runner_id:
			runner_squad = sq
			break
	assert(runner_squad != null, "Runner squad must exist")

	presenter.ai_fleet.squad_brains[runner_id] = SquadBrain.new(runner_squad, config)

	var executor = ActivityExecuteManager.new(true)
	executor.setup(presenter.game_scenario, {"squad": runner_squad})
	presenter.ai_fleet.squad_executors[runner_id] = executor

	Log.info("FleeDmo", "Assigned always-flee profile to %s" % runner_squad.squad_name)


func _run_test_sequence() -> void:
	var T := StrategyTypes.ActivityType

	Log.info("FleeDmo", "\n=== PHASE 1: Travel to Öhringen (runner's location) ===")
	await _do_travel("oehringen")
	_capture_notifications("Phase 1: Arrive at Öhringen")
	_log_all_squad_positions()
	_log_contact_state()

	Log.info("FleeDmo", "\n=== PHASE 2: Patrol to build contact ===")
	await _do_activity(T.PATROL)
	_capture_notifications("Phase 2: First patrol")
	_log_all_squad_positions()
	_log_contact_state()

	var detected := _has_notification_type(NotificationData.NotificationType.CONTACT_DETECTED)
	if not detected:
		Log.info("FleeDmo", "No CONTACT_DETECTED yet, patrolling again...")
		await _do_activity(T.PATROL)
		_capture_notifications("Phase 2b: Second patrol")
		_log_all_squad_positions()
		_log_contact_state()
	_assert_ever_seen("CONTACT_DETECTED", NotificationData.NotificationType.CONTACT_DETECTED)

	Log.info("FleeDmo", "\n=== PHASE 3: Continue patrolling — runner should be fleeing, contact should change ===")
	for i in range(5):
		await _do_activity(T.PATROL)
		_capture_notifications("Phase 3 patrol %d" % (i + 1))
		_log_all_squad_positions()
		_log_contact_state()

		if _has_notification_type(NotificationData.NotificationType.CONTACT_LOST):
			Log.info("FleeDmo", "CONTACT_LOST detected at patrol %d!" % (i + 1))
			break
		if _has_notification_type(NotificationData.NotificationType.CONTACT_DECAYING):
			Log.info("FleeDmo", "CONTACT_DECAYING detected at patrol %d" % (i + 1))

	Log.info("FleeDmo", "\n=== PHASE 4: Chase runner to try to regain contact ===")
	var runner_loc := _get_runner_location()
	if not runner_loc.is_empty() and runner_loc != player_squad.current_location_id:
		Log.info("FleeDmo", "Runner is at %s, pursuing..." % runner_loc)
		await _do_travel(runner_loc)
		_capture_notifications("Phase 4: Chase to runner")
		_log_all_squad_positions()
		_log_contact_state()

		await _do_activity(T.PATROL)
		_capture_notifications("Phase 4: Patrol at runner's last location")
		_log_all_squad_positions()
		_log_contact_state()

	Log.info("FleeDmo", "\n=== PHASE 5: Rest while runner flees further — expect contact loss ===")
	for i in range(4):
		await _do_activity(T.REST)
		_capture_notifications("Phase 5 rest %d" % (i + 1))
		_log_contact_state()

		if _has_notification_type(NotificationData.NotificationType.CONTACT_LOST):
			Log.info("FleeDmo", "CONTACT_LOST detected at rest %d!" % (i + 1))
			break

	Log.info("FleeDmo", "\n=== NOTIFICATION LOG ===")
	for entry in _notification_log:
		Log.info("FleeDmo", "  [Turn %d] %s: %s" % [entry["turn"], entry["phase"], entry["notifications"]])

	_assert_ever_seen("CONTACT_DETECTED", NotificationData.NotificationType.CONTACT_DETECTED)
	var saw_decaying := _ever_seen(NotificationData.NotificationType.CONTACT_DECAYING)
	var saw_lost := _ever_seen(NotificationData.NotificationType.CONTACT_LOST)
	if saw_decaying:
		_pass("CONTACT_DECAYING seen during test")
	else:
		_info("CONTACT_DECAYING not seen (runner may have stayed adjacently visible)")
	if saw_lost:
		_pass("CONTACT_LOST seen during test")
	else:
		_info("CONTACT_LOST not seen (runner never got far enough to lose contact)")

	if not saw_decaying and not saw_lost:
		_fail("Expected at least one of CONTACT_DECAYING or CONTACT_LOST, got neither")


func _do_travel(destination: String) -> void:
	Log.info("FleeDmo", "  → Travel to %s" % destination)
	await presenter.on_travel_confirmed(destination)
	while presenter.actor.walking_towards["location"] != null:
		Log.debug("FleeDmo", "  Continuing travel towards %s..." % destination)
		presenter.game_clock.force_tick()
		await presenter.tick_completed


func _do_activity(activity_type: StrategyTypes.ActivityType) -> void:
	var act_name: String = StrategyTypes.ActivityType.keys()[activity_type]
	Log.info("FleeDmo", "  → %s" % act_name)
	await presenter.on_activity_requested(activity_type)


func _capture_notifications(phase: String) -> void:
	var view = presenter.view
	var notifs: Array = view.last_notifications if "last_notifications" in view else []
	var descs: Array[String] = []
	for n in notifs:
		var type_name: String = NotificationData.NotificationType.keys()[n.type]
		descs.append("[%s] %s" % [type_name, n.title])
	_notification_log.append({
		"phase": phase,
		"turn": presenter.game_scenario.world.current_hour,
		"notifications": descs,
		"raw": notifs.duplicate(),
	})
	if not descs.is_empty():
		Log.info("FleeDmo", "  Notifications: %s" % ", ".join(descs))
	else:
		Log.debug("FleeDmo", "  No notifications this turn")


func _has_notification_type(type: NotificationData.NotificationType) -> bool:
	if _notification_log.is_empty():
		return false
	var last_entry: Dictionary = _notification_log[_notification_log.size() - 1]
	for n in last_entry["raw"]:
		if n.type == type:
			return true
	return false


func _ever_seen(type: NotificationData.NotificationType) -> bool:
	for entry in _notification_log:
		for n in entry["raw"]:
			if n.type == type:
				return true
	return false


func _get_runner_location() -> String:
	for sq in presenter.game_scenario.world.roaming_squads:
		if sq.squad_id == "retreating_scouts":
			return sq.current_location_id
	return ""


func _log_all_squad_positions() -> void:
	Log.info("FleeDmo", "  Positions: Player @ %s" % player_squad.current_location_id)
	for sq in presenter.game_scenario.world.roaming_squads:
		Log.info("FleeDmo", "    %s @ %s" % [sq.squad_name, sq.current_location_id])


func _log_contact_state() -> void:
	var tracker = presenter.game_scenario.world.contact_tracker
	var contacts = tracker.get_contacts_for(player_squad.squad_id)
	for c in contacts:
		var state_name: String = StrategyTypes.ContactState.keys()[c.get_state()]
		Log.info("FleeDmo", "  Contact: %s → %s = %.1f (%s)" % [c.observer_id, c.target_id, c.progress, state_name])


#region Assertions

func _assert_ever_seen(label: String, type: NotificationData.NotificationType) -> void:
	if _ever_seen(type):
		_pass("%s seen during test" % label)
	else:
		_fail("%s never fired during entire test" % label)


func _pass(msg: String) -> void:
	_pass_count += 1
	Log.info("FleeDmo", "  PASS: %s" % msg)


func _fail(msg: String) -> void:
	_fail_count += 1
	Log.error("FleeDmo", "  FAIL: %s" % msg)


func _info(msg: String) -> void:
	Log.info("FleeDmo", "  INFO: %s" % msg)

#endregion


func _print_summary() -> void:
	Log.info("FleeDmo", "")
	Log.info("FleeDmo", "=== SUMMARY ===")
	Log.info("FleeDmo", "PASS: %d  FAIL: %d" % [_pass_count, _fail_count])
	if _fail_count > 0:
		Log.error("FleeDmo", "TEST FAILED")
	else:
		Log.info("FleeDmo", "ALL TESTS PASSED")
