class_name StrategyPresenter
extends Node

enum UIMode {
	STRATEGY,
	VISUAL_NOVEL,
	COMBAT_INTERMISSION,
}

signal encounter_resolved()
signal tick_completed()

@export var scenario_path: String
@export var is_demo_scenario: bool = true

var view
var actor: ActivityRunner
var ai_fleet: AIFleetManager
var vn_view
var stage_presenter
var combat_orch: CombatOrchestrator
var economy_orch: EconomyOrchestrator
var contact_orch: ContactOrchestrator
var game_clock: GameClock

var game_scenario: GameScenario:
	get:
		return actor.aem.scenario

var ui_mode: UIMode = UIMode.STRATEGY
var is_executing_activity: bool = false
var stat_snapshot: Dictionary = { }
var encounter_timeout_timer: float = 0.0
var combat_options: Dictionary = { }
var _pending_results: Array[GenericResult] = []
var visited_locations: Array[String] = []
var _notification_collector := NotificationCollector.new()
var _last_mission_results: Array = []
var _last_unlocked_missions: Array[String] = []
var turn_log: Array[String] = []

var current_location:
	get:
		return actor.current_location
var walking_towards: Variant:
	set(_loc):
		if not _loc:
			actor.walking_towards = null
			return
		assert(_loc is Location or _loc is String)
		actor.walking_towards = _loc
	get:
		return actor.walking_towards["location"]


func bind_view(v) -> void:
	_bind_view_references(v)
	_initialize_scenario()
	_setup_components()
	StrategyEventBus.hour_advanced.connect(_on_hour_advanced)
	view.update_morale_bar(actor.player_squad.get_morale())
	if not game_scenario._initialized:
		game_scenario.initialize(actor.aem._build_context())
	_update_ui()
	_track_starting_location()
	stage_presenter.start_march(actor.player_squad)
	await _execute_story_triggerables(StrategyTypes.TriggerWhen.GAME_START)
	await _check_missions()


func _bind_view_references(v) -> void:
	view = v
	actor = view.actor
	ai_fleet = view.ai_fleet
	vn_view = view.vn_view
	stage_presenter = view.get_stage_presenter()


func _track_starting_location() -> void:
	if actor.player_squad.current_location_id not in visited_locations:
		visited_locations.append(actor.player_squad.current_location_id)


func _process(delta: float) -> void:
	if game_clock:
		game_clock.process(delta)
	if combat_orch and combat_orch.is_in_encounter and encounter_timeout_timer > 0:
		encounter_timeout_timer -= delta
		view.update_combat_timer(encounter_timeout_timer, combat_options.get("timeout_seconds", 30.0))
		if encounter_timeout_timer <= 0:
			_on_combat_timeout()

#region Initialization

func _initialize_scenario() -> void:
	# Loads the GameScenario resource (demo or from file) and passes it to ActivityRunner.setup()
	# e.g., is_demo_scenario=true → DemoScenarioFactory.create_demo_scenario() → actor.setup(scenario)
	# e.g., scenario_path="res://resources/scenarios/campaign.tres" → ResourceLoader.load() → actor.setup(scenario)
	Log.info("Presenter", "Initialising scenario")
	if is_demo_scenario:
		Log.info("Presenter", "Loading DEMO scenario")
		actor.setup(DemoScenarioFactory.create_demo_scenario())
	else:
		Log.info("Presenter", "Loading scenario: %s" % scenario_path)
		assert(not scenario_path.is_empty(), "Scenario path is empty")
		assert(ResourceLoader.exists(scenario_path), "Scenario resource does not exist at path: %s" % scenario_path)

		var loaded = ResourceLoader.load(scenario_path)
		if loaded == null:
			var error_msg = "Failed to load scenario from path: %s\nPossible causes:\n" % scenario_path
			error_msg += "  - Script class not found (check class_name matches)\n"
			error_msg += "  - Missing dependencies (check ExtResource paths)\n"
			error_msg += "  - Circular reference in resources\n"
			error_msg += "  - Corrupted .tres file\n"
			Log.error("Presenter", error_msg)
			assert(false, error_msg)

		assert(loaded is GameScenario, "Loaded resource is not a GameScenario (got %s): %s" % [loaded.get_class(), scenario_path])
		actor.setup(loaded)


func _setup_components() -> void:
	combat_orch = CombatOrchestrator.new()
	combat_orch.setup(game_scenario.world.contact_tracker)
	economy_orch = EconomyOrchestrator.new()
	contact_orch = ContactOrchestrator.new()
	game_clock = GameClock.new(game_scenario.world)
	game_clock.hour_ticked.connect(_on_hour_tick)
	game_clock.pause()
	view.setup_child_guis(actor)
	ai_fleet.setup(game_scenario)
	vn_view.presenter.set_stage_presenter(stage_presenter)
	Log.info("Presenter", "Orchestrators initialized")
	Log.info("Presenter", "AIFleetManager initialized with %d AI squads" % ai_fleet.get_ai_squad_count())

#endregion

#region UI Mode State Machine

func set_ui_mode(mode: UIMode, trans_type: EventChain.TransitionType = EventChain.TransitionType.QUICK) -> void:
	if ui_mode == mode:
		return
	ui_mode = mode
	match mode:
		UIMode.STRATEGY:
			view.hide_combat_panel()
			stage_presenter.set_mode(StagePresenter.StageMode.MARCH)
			await view.transition_to_strategy()
			if is_executing_activity:
				view.disable_all_activity_buttons()
			else:
				_update_activity_buttons()
		UIMode.VISUAL_NOVEL:
			view.hide_combat_panel()
			view.disable_all_activity_buttons()
			view.action_buttons.visible = false
			stage_presenter.set_mode(StagePresenter.StageMode.VN)
			await view.transition_to_vn(trans_type)
		UIMode.COMBAT_INTERMISSION:
			stage_presenter.set_mode(StagePresenter.StageMode.HIDDEN)
			view.show_combat_ui()

#endregion

#region User Action Handlers

func on_activity_requested(type: StrategyTypes.ActivityType) -> void:
	actor.player_squad.current_activity_type = type
	_update_activity_buttons()
	view.update_resting_banner(type == StrategyTypes.ActivityType.REST)


func on_travel_requested() -> void:
	game_clock.pause()
	view.update_pause_state(true)
	view.show_travel_menu(game_scenario, actor.locations)


func on_investigate_requested() -> void:
	game_clock.pause()
	view.update_pause_state(true)
	view.show_investigation_menu()


func on_recruit_requested() -> void:
	game_clock.pause()
	view.update_pause_state(true)
	view.show_recruitment_menu()


func on_manage_squad_requested() -> void:
	game_clock.pause()
	view.update_pause_state(true)
	view.show_manage_squad(actor.player_squad, actor)


func on_shop_requested() -> void:
	var location = actor.current_location
	assert(location.has_shop(), "Shop requested but location has no shop")
	game_clock.pause()
	view.update_pause_state(true)
	view.show_shop(location.shop, actor.player_squad, location)


func on_travel_confirmed(location_id: String) -> void:
	var squad := actor.player_squad
	var from_id := squad.current_location_id
	var path: Array = game_scenario.world.travel_graph.find_path(from_id, location_id)
	if path.size() < 2:
		return

	var route: Array[String] = []
	for p in path:
		route.append(p)
	squad.travel_route = route
	squad.travel_segment_index = 0
	squad.travel_progress_km = 0.0
	squad.current_activity_type = StrategyTypes.ActivityType.TRAVEL
	actor.walking_towards = location_id

	view.update_location(_get_travel_label())
	view.hide_travel_menu()
	view.set_travel_mode_autopilot()
	_update_activity_buttons()
	view.update_resting_banner(false)


func on_travel_cancelled() -> void:
	view.hide_travel_menu()


func on_continue_travel() -> void:
	var dest_location = actor.walking_towards["location"]
	assert(dest_location != null, "Continue travel called but no destination set")
	actor.player_squad.current_activity_type = StrategyTypes.ActivityType.TRAVEL
	view.update_resting_banner(false)
	_update_ui()


func on_go_back_travel() -> void:
	var from_location = actor.current_location
	assert(from_location != null, "Go back called but no current location")
	Log.info("Presenter", "Cancelling travel, staying at %s" % from_location.location_name)
	actor.walking_towards = null
	actor.player_squad.clear_travel()
	actor.player_squad.current_activity_type = StrategyTypes.ActivityType.REST
	_update_ui()


func on_investigation_closed() -> void:
	view.hide_investigation_menu()


func on_recruitment_completed(warrior: Warrior) -> void:
	Log.info("Presenter", "Recruited warrior: %s" % warrior.name)
	stage_presenter.refresh_warriors(actor.player_squad)
	actor.player_squad.current_activity_type = StrategyTypes.ActivityType.RECRUIT
	_update_ui()


func on_recruitment_closed() -> void:
	view.hide_recruitment_menu()


func on_manage_squad_closed() -> void:
	pass


func on_purchase_completed(purchases: Dictionary) -> void:
	Log.debug("Presenter", "Purchase completed: %s" % [purchases])
	_update_ui()


func on_shop_closed() -> void:
	pass


func on_scouting_requested() -> void:
	game_clock.pause()
	view.update_pause_state(true)
	var ai_decisions := ai_fleet.decisions_this_turn if ai_fleet else { }
	view.show_scouting(game_scenario.world, actor.player_squad, ai_decisions)


func on_scouting_closed() -> void:
	pass


func on_missions_requested() -> void:
	if game_scenario.factions.is_empty():
		return
	game_clock.pause()
	view.update_pause_state(true)
	view.show_missions(game_scenario.factions)


func on_missions_closed() -> void:
	pass


func on_market_requested() -> void:
	var location = actor.current_location
	if not location.has_economy():
		return
	game_clock.pause()
	view.update_pause_state(true)
	view.show_market(game_scenario.world, location, visited_locations)


func on_market_closed() -> void:
	pass


func on_combat_choice(choice: CombatController.IntermissionChoice) -> void:
	if ui_mode != UIMode.COMBAT_INTERMISSION:
		return
	Log.debug("Presenter", "Player chose: %s" % CombatController.IntermissionChoice.keys()[choice])
	_process_encounter_choice(choice)


func on_skip_pressed() -> void:
	pass


func on_summary_pressed() -> void:
	var _summary_text = "=== Campaign Summary ===\n"
	_summary_text += "CombatSquad: %s\n" % actor.player_squad.squad_name
	_summary_text += "Hour: %d (%s)\n" % [game_scenario.world.current_hour, game_scenario.world.get_clock_display()]
	_summary_text += "Location: %s (Dev:%d Stab:%.0f)\n" % [
		actor.current_location.location_name,
		actor.current_location.development,
		actor.current_location.stability,
	]
	_summary_text += "Morale: %.1f\n" % actor.player_squad.get_morale()
	_summary_text += "Money: %.0f\n" % actor.player_squad.money
	_summary_text += "Food: %d\n" % actor.player_squad.food
	_summary_text += "Karma: %.0f\n" % actor.player_squad.karma


func on_battle_close() -> void:
	Log.debug("Presenter", "User closed battle manually")
	view.cleanup_battle_scene()


func on_pause_toggle() -> void:
	game_clock.toggle_pause()
	var is_paused := game_scenario.world.is_paused
	view.update_pause_state(is_paused)
	view.update_resting_banner(
		actor.player_squad.current_activity_type == StrategyTypes.ActivityType.REST
	)


func on_speed_changed(speed: float) -> void:
	game_clock.set_speed(speed)
	view.update_speed_display(speed)


func on_retreat_requested() -> void:
	Log.info("Presenter", "Player requested retreat mid-battle")
	var battle_presenter = _get_active_battle_presenter()
	if battle_presenter:
		battle_presenter.request_retreat(SquadBattleTypes.Side.ATTACKER)


func _get_active_battle_presenter():
	for child in view.combat_overlay.get_children():
		var bp = child.get_node_or_null("SquadBattlePresenter")
		if bp:
			return bp
	for child in view.battle_viewport.get_children():
		var bp = child.get_node_or_null("SquadBattlePresenter")
		if bp:
			return bp
	return null

#endregion

#region Activity Pipeline


func _build_karma_sorted_entries(ai_results: Dictionary) -> Array:
	var entries: Array = []

	entries.append(
		{
			"is_player": true,
			"karma": actor.player_squad.karma,
		},
	)

	var decisions = ai_results["decisions_this_turn"]
	for squad_id in decisions:
		var decision = decisions[squad_id]
		entries.append(
			{
				"is_player": false,
				"squad_id": squad_id,
				"activity": decision["activity"],
				"executor": ai_fleet.squad_executors[squad_id],
				"karma": decision["squad"].karma,
			},
		)

	entries.sort_custom(func(a, b): return a["karma"] > b["karma"])
	return entries


func _resolve_ai_combat_from_results(results: Array[GenericResult], squad_id: String) -> void:
	for result in results:
		if result is ActivityResult and result.requires_combat:
			var target_id = result.combat_target_squad_id
			if target_id.is_empty():
				continue
			var attacker = ai_fleet._find_squad_by_id(squad_id)
			var defender = ai_fleet._find_squad_by_id(target_id)
			if attacker and defender:
				ai_fleet._execute_headless_combat(
					{
						"attacker_id": squad_id,
						"defender_id": target_id,
					},
				)


func _exec_play_animchanges_loop(activity, state):
	_capture_stat_snapshot()

	var all_activity_result = actor["exec_%s" % state].call(activity)
	_pending_results.append_array(all_activity_result)
	_queue_multiple_eventchains_from_results(all_activity_result)
	await _vn_play_next_recurs()
	var has_combat = await _enter_combat_if_exists(activity, all_activity_result)
	if not has_combat:
		await _animate_stat_changes()


func _handle_player_engagement(engagement: Dictionary) -> void:
	var engagement_type: StrategyTypes.EngagementType = engagement["type"]
	var player = actor.player_squad

	var enemy_id: String
	if engagement["attacker_id"] == player.squad_id:
		enemy_id = engagement["defender_id"]
	else:
		enemy_id = engagement["attacker_id"]

	var enemy_squad = actor.aem._find_enemy_squad(enemy_id)
	if not enemy_squad:
		return

	if player.engagement_stance == StrategyTypes.EngagementStance.ALWAYS_ENGAGE:
		Log.info(
			"Presenter",
			"Auto-engaging %s (stance: ALWAYS_ENGAGE, type: %s)" % [
				enemy_squad.squad_name,
				StrategyTypes.EngagementType.keys()[engagement_type],
			],
		)
		start_encounter(enemy_squad, { }, engagement_type)
		await encounter_resolved
	else:
		Log.info(
			"Presenter",
			"Contact LOCKED with %s (type: %s) — player decides" % [
				enemy_squad.squad_name,
				StrategyTypes.EngagementType.keys()[engagement_type],
			],
		)
		start_encounter(enemy_squad, { }, engagement_type)
		await encounter_resolved


func _collect_and_show_notifications() -> void:
	return # Notifications disabled temporarily


func _enter_combat_if_exists(activity: Activity, all_activity_result: Array[GenericResult]) -> bool:
	var has_combat = all_activity_result.any(func(r): return r is ActivityResult and r.requires_combat)
	if has_combat:
		var _combat: ActivityResult
		for a in all_activity_result:
			if a is ActivityResult and a.requires_combat:
				_combat = a
				break

		assert(_combat.combat_target_squad_id != "", "[GameScenario] Combat required but no target squad ID specified in activity result")

		var enemy_squad = actor.aem._find_enemy_squad(_combat.combat_target_squad_id)
		if enemy_squad:
			start_encounter(enemy_squad, actor.aem._build_context(activity), _combat.engagement_type)
			await encounter_resolved
		else:
			Log.warn("Presenter", "Combat required but enemy squad with ID '%s' not found" % _combat.combat_target_squad_id)
	return has_combat


func _vn_play_next_recurs():
	if not view.has_queued_vn_chains():
		await _show_pending_results()
		await set_ui_mode(UIMode.STRATEGY)
		return
	var trans_type = view.peek_next_vn_transition_type()
	await set_ui_mode(UIMode.VISUAL_NOVEL, trans_type)
	view.play_next_queued_chain()
	await view.get_chain_completed_signal()
	await _vn_play_next_recurs()


func _show_pending_results() -> void:
	if _pending_results.is_empty():
		return

	var aggregated_stats: Dictionary = { }
	var recruits: Array[Warrior] = []

	for result in _pending_results:
		for stat_key in result.squad_stat_changes:
			var label = StrategyTypes.SquadProperty.keys()[stat_key]
			if not aggregated_stats.has(label):
				aggregated_stats[label] = 0.0
			aggregated_stats[label] += result.squad_stat_changes[stat_key]
		for recruit in result.new_recruits:
			recruits.append(recruit)

	_pending_results.clear()

	if aggregated_stats.is_empty() and recruits.is_empty():
		return

	await view.show_result_summary(aggregated_stats, recruits)


func _queue_multiple_eventchains_from_results(results_list: Array[GenericResult]) -> void:
	for result in results_list:
		if result is GenericResult:
			if result.has_event_chain():
				view.queue_vn_chain(result.event_chain_path)
		else:
			assert(false, "%s" % result)


func _execute_story_triggerables(when: StrategyTypes.TriggerWhen) -> void:
	var results = actor.exec_at(when)
	if results.is_empty():
		return
	_queue_multiple_eventchains_from_results(results)
	await _vn_play_next_recurs()


func _check_missions() -> void:
	var context = actor.aem._build_context()
	var all_results: Array[MissionResult] = []
	for faction in game_scenario.factions:
		var results = faction.check_mission_completions(context)
		for r in results:
			all_results.append(r)
	if all_results.is_empty():
		return
	_last_mission_results = all_results
	for r in all_results:
		for unlocked_id in r.unlocked_missions:
			var unlocked_mission := _find_mission_by_id(unlocked_id)
			if unlocked_mission:
				_last_unlocked_missions.append(unlocked_mission.mission_name)
	for r in all_results:
		var mission = _find_mission_by_id(r.mission_id)
		if mission:
			game_scenario.triggerable_manager.triggerable_fired.emit(mission, [r])
	var generic_results: Array[GenericResult] = []
	for r in all_results:
		generic_results.append(r)
	_queue_multiple_eventchains_from_results(generic_results)
	await _vn_play_next_recurs()


func _find_mission_by_id(mission_id: String) -> Mission:
	for faction in game_scenario.factions:
		var m = faction.get_mission_by_id(mission_id)
		if m:
			return m
	return null

#endregion

#region Combat System

func start_encounter(enemy_squad: SquadData, _context: Dictionary = { }, engagement_type: StrategyTypes.EngagementType = StrategyTypes.EngagementType.SET_PIECE) -> void:
	Log.info("Presenter", "COMBAT ENCOUNTER INITIATED (%s)" % StrategyTypes.EngagementType.keys()[engagement_type])
	Log.info("Presenter", "Enemy: %s (%d warriors)" % [enemy_squad.squad_name, enemy_squad.get_living_warriors().size()])

	GrimdarkFX.set_combat_mode(true)

	combat_options = combat_orch.inject_context(
		actor.player_squad,
		enemy_squad,
		view.battle_viewport,
		view.combat_overlay,
		engagement_type,
	)
	encounter_timeout_timer = 0

	_process_encounter_choice(CombatController.IntermissionChoice.FIGHT)


func _process_encounter_choice(choice: CombatController.IntermissionChoice) -> void:
	view.disable_combat_buttons()
	encounter_timeout_timer = 0

	var encounter_result: CombatController.CombatResult = await combat_orch.execute_choice(choice)
	view.hide_combat_panel()

	Log.info("Presenter", "Combat result received: %s" % [encounter_result.to_string() if encounter_result else "null"])
	await _handle_encounter_result(encounter_result)


func _on_combat_timeout() -> void:
	if ui_mode != UIMode.COMBAT_INTERMISSION:
		return
	Log.info("Presenter", "COMBAT TIMEOUT - Auto-fighting!")
	view.set_combat_info_text("Time's up! Engaging in combat...")
	_process_encounter_choice(CombatController.IntermissionChoice.FIGHT)


func _handle_encounter_result(result: CombatController.CombatResult) -> void:
	Log.info("Presenter", "COMBAT RESOLVED: %s" % result.to_string())

	GrimdarkFX.set_combat_mode(false)
	if not result.player_casualties.is_empty():
		GrimdarkFX.trigger_damage_pulse()

	var outcome = combat_orch.apply_result(result, actor.player_squad, actor.current_location, game_scenario.world, turn_log)
	await view.show_combat_result_overlay(result, outcome["morale_before"], outcome["morale_after"])

	if outcome["game_over"]:
		StrategyEventBus.game_ended.emit("Squad Annihilated")
		view.show_game_over("DEFEAT", "Your entire squad has perished.")
		return

	encounter_resolved.emit(result)


func _check_game_over() -> bool:
	if CombatOrchestrator.check_game_over(actor.player_squad):
		StrategyEventBus.game_ended.emit("Squad Annihilated")
		view.show_game_over("DEFEAT", "Your entire squad has perished.")
		return true
	return false

#endregion

#endregion

#region Stat Tracking

func _capture_stat_snapshot() -> void:
	# Saves current squad stats before an activity phase executes
	# Used later by _calculate_stat_deltas() to determine what changed and animate it
	# e.g., snapshot = {money: 100, food: 8, karma: 5, morale: 60}
	if not game_scenario:
		Log.warn("StatAnim", "Cannot capture snapshot - no game_scenario")
		return

	var squad = actor.player_squad
	var _location = actor.current_location

	stat_snapshot = {
		"money": squad.money,
		"food": float(squad.food),
		"karma": squad.karma,
		"morale": squad.get_morale(),
	}
	Log.trace("StatAnim", "Snapshot captured: %s" % [stat_snapshot])


func _calculate_stat_deltas() -> Dictionary:
	# Compares current stats against the snapshot to find what changed
	# Returns only stats that changed by ≥0.01 (filters noise)
	# e.g., snapshot={money:100, food:8}, current={money:100, food:6} → deltas={food: -2.0}
	if not game_scenario:
		Log.warn("StatAnim", "Cannot calculate deltas - no game_scenario")
		return { }
	if stat_snapshot.is_empty():
		Log.warn("StatAnim", "Cannot calculate deltas - snapshot is empty")
		return { }

	var squad = actor.player_squad

	var current_stats := {
		"money": squad.money,
		"food": float(squad.food),
		"karma": squad.karma,
		"morale": squad.get_morale(),
	}
	Log.trace("StatAnim", "Current stats: %s" % [current_stats])

	var deltas := { }
	for stat_name in stat_snapshot:
		var old_value = stat_snapshot[stat_name]
		var new_value = current_stats[stat_name]
		var delta = new_value - old_value
		if abs(delta) >= 0.01:
			deltas[stat_name] = delta
			Log.trace("StatAnim", "Delta for %s: %.2f (from %.2f to %.2f)" % [stat_name, delta, old_value, new_value])

	if deltas.is_empty():
		Log.trace("StatAnim", "No meaningful deltas detected (all changes < 0.01)")
	else:
		Log.debug("StatAnim", "Total deltas to animate: %s" % [deltas])
	return deltas


func _animate_stat_changes() -> void:
	Log.trace("StatAnim", "_animate_stat_changes() called")
	var deltas = _calculate_stat_deltas()
	if deltas.is_empty():
		Log.trace("StatAnim", "No deltas to animate, returning early")
		return

	Log.trace("StatAnim", "Starting animation with %d delta(s)" % deltas.size())
	await view.animate_stat_changes(deltas)
	Log.trace("StatAnim", "Animation completed")

#endregion

#region UI Updates

func _update_ui() -> void:
	# Refreshes all UI elements to reflect current game state: turn counter, location, stats, morale, buttons
	# Called after scenario init and after each activity completes
	# e.g., turn=5, location="Vienna (City)", morale=72 "Good", money=150, food=6, karma=10
	var squad = actor.player_squad
	var world = game_scenario.world
	var location = actor.current_location

	view.update_clock(world.current_hour)

	var walking = actor.walking_towards
	if walking != null and walking["location"] != null:
		var dest: Location = walking["location"]
		squad = actor.player_squad
		if squad.is_traveling():
			var total_km = world.travel_graph.get_path_distance_km(squad.travel_route)
			view.update_location("Travelling to %s (%.0f/%.0f km)" % [dest.location_name, squad.travel_progress_km, total_km])
		else:
			view.update_location("Travelling to %s" % dest.location_name)
	else:
		view.update_location(
			"%s (%s)" % [
				location.location_name if location else "Unknown",
				_location_type_to_string(location.type) if location else "",
			],
		)

	view.update_condition(_get_morale_condition(squad.get_morale()))
	view.update_morale_bar(squad.get_morale())
	_update_contact_bars(world, squad)

	view.update_stats(
		squad.money,
		squad.food,
		squad.karma,
		location.stability if location else 0.0,
		location.development if location else 0,
	)

	walking = actor.walking_towards
	if walking != null and walking["location"] != null:
		var from_name: String = location.location_name if location else "Unknown"
		view.show_travel_arrows(walking["location"].location_name, from_name)
	else:
		view.hide_travel_arrows()

	_update_activity_buttons()


func _update_contact_bars(world: World, squad: SquadData) -> void:
	if not world.contact_tracker:
		view.update_contact_bars([])
		return
	var our_contacts = world.contact_tracker.get_contacts_for(squad.squad_id)
	var bars: Array[Dictionary] = []
	for contact in our_contacts:
		if contact.progress <= 0.0:
			continue
		var target_squad: SquadData = null
		for s in world.roaming_squads:
			if s.squad_id == contact.target_id:
				target_squad = s
				break
		if not target_squad:
			continue
		var state = contact.get_state()
		var title: String
		match state:
			StrategyTypes.ContactState.SUSPECTED:
				title = target_squad.squad_name if target_squad.is_caravan() else "Unknown Force"
			_:
				title = target_squad.squad_name
		bars.append(
			{
				"target_id": contact.target_id,
				"state": state,
				"progress": contact.progress,
				"progress_delta": contact.last_delta,
				"title": title,
			},
		)
	bars.sort_custom(func(a, b): return a["progress"] > b["progress"])
	view.update_contact_bars(bars)


func _update_activity_buttons() -> void:
	if not game_scenario or not actor.current_location:
		return

	var location = actor.current_location
	var current_at := actor.player_squad.current_activity_type

	view.update_resting_banner(current_at == StrategyTypes.ActivityType.REST)

	view.update_activity_button(
		"drill",
		"Drill" + (" [ACTIVE]" if current_at == StrategyTypes.ActivityType.DRILL else ""),
		not location.has_activity_type(StrategyTypes.ActivityType.DRILL),
		_get_activity_tooltip(StrategyTypes.ActivityType.DRILL),
		current_at == StrategyTypes.ActivityType.DRILL,
	)

	view.update_activity_button(
		"patrol",
		"Patrol" + (" [ACTIVE]" if current_at == StrategyTypes.ActivityType.PATROL else ""),
		not location.has_activity_type(StrategyTypes.ActivityType.PATROL),
		_get_activity_tooltip(StrategyTypes.ActivityType.PATROL),
		current_at == StrategyTypes.ActivityType.PATROL,
	)

	view.update_activity_button(
		"investigate",
		"Investigate" + (" [ACTIVE]" if current_at == StrategyTypes.ActivityType.INVESTIGATE else ""),
		not location.has_activity_type(StrategyTypes.ActivityType.INVESTIGATE),
		_get_activity_tooltip(StrategyTypes.ActivityType.INVESTIGATE),
		current_at == StrategyTypes.ActivityType.INVESTIGATE,
	)

	view.update_activity_button(
		"hold_mass",
		"Hold Mass" + (" [ACTIVE]" if current_at == StrategyTypes.ActivityType.HOLD_MASS else ""),
		not location.has_activity_type(StrategyTypes.ActivityType.HOLD_MASS),
		_get_activity_tooltip(StrategyTypes.ActivityType.HOLD_MASS),
		current_at == StrategyTypes.ActivityType.HOLD_MASS,
	)

	view.update_activity_button(
		"travel",
		"Travel" + (" [ACTIVE]" if current_at == StrategyTypes.ActivityType.TRAVEL else ""),
		false,
		"Travel to another location",
		current_at == StrategyTypes.ActivityType.TRAVEL,
	)

	var enemies_here = game_scenario.world.get_squads_at_location(location.location_id)
	var attack_tooltip: String
	var attack_disabled := true
	if enemies_here.is_empty():
		attack_tooltip = "No enemies at this location"
	else:
		var tracker = game_scenario.world.contact_tracker
		var player_id = actor.player_squad.squad_id
		var attackable: Array[SquadData] = []
		var tooltip_lines: Array[String] = []
		for enemy in enemies_here:
			var contact = tracker.get_contact(player_id, enemy.squad_id)
			var state = contact.get_state() if contact else StrategyTypes.ContactState.NONE
			var state_name = StrategyTypes.ContactState.keys()[state]
			if state >= StrategyTypes.ContactState.LOCKED:
				attackable.append(enemy)
				tooltip_lines.append("%s [%s]" % [enemy.squad_name, state_name])
			else:
				tooltip_lines.append("Unknown presence [%s]" % state_name)
		if attackable.is_empty():
			attack_tooltip = "Enemies detected but contact not LOCKED.\nPatrol or investigate to improve awareness.\n\n" + "\n".join(tooltip_lines)
		else:
			attack_disabled = false
			attack_tooltip = "Engage enemy forces:\n" + "\n".join(tooltip_lines)
	view.update_activity_button(
		"attack",
		"Attack",
		attack_disabled,
		attack_tooltip,
	)

	view.update_activity_button(
		"manage_squad",
		"Manage CombatSquad",
		false,
		"View and manage your warriors",
	)

	var has_shop = location.has_shop()
	view.update_activity_button(
		"shop",
		"Shop",
		not has_shop,
		"Browse the local shop" if has_shop else "No shop at this location",
	)

	var has_economy = location.has_economy()
	view.update_activity_button(
		"market",
		"Market",
		not has_economy,
		"View local market prices and economy" if has_economy else "No market at this location",
	)


func _get_activity_tooltip(activity_type: StrategyTypes.ActivityType) -> String:
	var activity = actor.get_activity(activity_type)
	if not activity:
		return "Unknown activity"
	return activity.description


func _get_travel_label() -> String:
	if walking_towards:
		return "Travelling to %s" % walking_towards.location_name
	else:
		return current_location.location_name

#endregion

#region Model Signal Handlers

func _on_hour_tick(hour: int) -> void:
	if is_executing_activity:
		return
	is_executing_activity = true
	StrategyEventBus.hour_advanced.emit(hour)
	view.update_clock(hour)
	view.disable_all_activity_buttons()

	var activity := _resolve_player_activity()
	var player_location_before := actor.player_squad.current_location_id
	var ai_results := ai_fleet.prepare_ai_turns()

	_log_turn_decisions(activity, player_location_before, ai_results)
	_tick_world_systems(hour)

	var contact_before_states := ContactOrchestrator.snapshot_states(game_scenario.world.contact_tracker, actor.player_squad.squad_id)
	var squad_names_cache := ContactOrchestrator.cache_squad_names(game_scenario.world.roaming_squads)

	var turn_entries := _build_karma_sorted_entries(ai_results)
	await _execute_all_activities(activity, turn_entries)

	if _check_game_over():
		is_executing_activity = false
		return

	await _process_contacts_and_engagements(
		activity, player_location_before,
		contact_before_states, squad_names_cache,
	)

	if _check_game_over():
		is_executing_activity = false
		return

	await _finalize_tick(activity)


func _resolve_player_activity() -> Activity:
	var player_activity_type := actor.player_squad.current_activity_type
	var activity := actor.get_activity(player_activity_type)
	if activity == null:
		activity = actor.get_activity(StrategyTypes.ActivityType.REST)

	if player_activity_type == StrategyTypes.ActivityType.TRAVEL:
		var dest = actor.walking_towards
		if dest and dest["location"]:
			activity = actor.create_travel_activity(dest["location"].location_id)
		else:
			actor.player_squad.current_activity_type = StrategyTypes.ActivityType.REST
			activity = actor.get_activity(StrategyTypes.ActivityType.REST)

	return activity


func _log_turn_decisions(activity: Activity, player_location_before: String, ai_results: Dictionary) -> void:
	turn_log.clear()
	var activity_name: String = StrategyTypes.ActivityType.keys()[activity.activity_type]
	turn_log.append("PLAYER %s at %s" % [activity_name, player_location_before])

	var decisions = ai_results["decisions_this_turn"]
	for squad_id in decisions:
		var d = decisions[squad_id]
		var sq_name: String = d["squad"].squad_name
		var at_name: String = StrategyTypes.ActivityType.keys()[d["activity_type"]]
		var sq_loc: String = d.get("location_at_decision", "")
		var travel_dest: String = d["context"].get("travel_destination", "")
		if not travel_dest.is_empty():
			turn_log.append("AI %s %s at %s → %s" % [sq_name, at_name, sq_loc, travel_dest])
		else:
			turn_log.append("AI %s %s at %s" % [sq_name, at_name, sq_loc])


func _tick_world_systems(hour: int) -> void:
	if hour % 24 == 0:
		turn_log.append_array(economy_orch.tick_and_spawn_caravans(game_scenario, ai_fleet))
	for location in game_scenario.world.locations:
		location.decay_clues()


func _execute_all_activities(activity: Activity, turn_entries: Array) -> void:
	for entry in turn_entries:
		if entry["is_player"]:
			await _execute_story_triggerables(StrategyTypes.TriggerWhen.HOUR_START)
		else:
			(entry["executor"] as ActivityExecuteManager).execute_triggerables_at(StrategyTypes.TriggerWhen.HOUR_START)

	for phase in ['before', 'activity', 'after']:
		for entry in turn_entries:
			if entry["is_player"]:
				await _exec_play_animchanges_loop(activity, phase)
			else:
				var executor: ActivityExecuteManager = entry["executor"]
				var results: Array[GenericResult] = executor["exec_%s" % phase].call(entry["activity"])
				_resolve_ai_combat_from_results(results, entry["squad_id"])

	ai_fleet.cleanup_defeated_squads()
	turn_log.append_array(ai_fleet.combat_log)
	ai_fleet.combat_log.clear()


func _process_contacts_and_engagements(
	activity: Activity,
	player_location_before: String,
	contact_before_states: Dictionary,
	squad_names_cache: Dictionary,
) -> void:
	var contact_before_for_log := contact_before_states.duplicate()
	var contact_result = contact_orch.update(
		game_scenario.world,
		actor.player_squad,
		actor.walking_towards,
		ai_fleet,
		activity,
		player_location_before,
		contact_before_states,
		_notification_collector,
		squad_names_cache,
	)

	var contact_after_states: Dictionary = contact_result["contact_after"]
	for key in contact_after_states:
		var after_state: int = contact_after_states[key]
		var before_state: int = contact_before_for_log.get(key, StrategyTypes.ContactState.NONE)
		if after_state != before_state:
			var parts: PackedStringArray = key.split("::")
			var target_id: String = parts[1] if parts.size() > 1 else key
			var target_name: String = squad_names_cache.get(target_id, target_id)
			var before_name: String = StrategyTypes.ContactState.keys()[before_state]
			var after_name: String = StrategyTypes.ContactState.keys()[after_state]
			turn_log.append("CONTACT %s %s→%s" % [target_name, before_name, after_name])

	var player_engagements: Array[Dictionary] = contact_result["engagements"]
	for engagement in player_engagements:
		game_clock.pause()
		await _handle_player_engagement(engagement)


func _finalize_tick(activity: Activity) -> void:
	await _check_missions()
	_collect_and_show_notifications()
	if actor.player_squad.current_location_id not in visited_locations:
		visited_locations.append(actor.player_squad.current_location_id)
	actor.advance_hour()

	if activity.activity_type == StrategyTypes.ActivityType.RECRUIT:
		actor.player_squad.current_activity_type = StrategyTypes.ActivityType.REST
		game_clock.pause()
		view.update_pause_state(true)

	is_executing_activity = false
	_update_ui()
	tick_completed.emit()


func _on_hour_advanced(hour: int) -> void:
	view.update_clock(hour)

#endregion

#region Display Helpers

func _location_type_to_string(loc_type: StrategyTypes.LocationType) -> String:
	match loc_type:
		StrategyTypes.LocationType.CITY:
			return "City"
		StrategyTypes.LocationType.TOWN:
			return "Town"
		StrategyTypes.LocationType.VILLAGE:
			return "Village"
		StrategyTypes.LocationType.FORT:
			return "Fort"
		StrategyTypes.LocationType.ROAD:
			return "Road"
		_:
			return "Unknown"


func _get_morale_condition(morale: float) -> String:
	if morale >= 90.0:
		return "Excellent"
	elif morale >= 70.0:
		return "Good"
	elif morale >= 50.0:
		return "Fair"
	elif morale >= 30.0:
		return "Poor"
	else:
		return "Critical"

#endregion
