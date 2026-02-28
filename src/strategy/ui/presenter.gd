class_name StrategyPresenter
extends Node

enum UIMode {
	STRATEGY,
	VISUAL_NOVEL,
	COMBAT_INTERMISSION,
}

signal encounter_resolved()

@export var scenario_path: String
@export var is_demo_scenario: bool = true

var view: StrategyView
var actor: ActivityRunner
var ai_fleet: AIFleetManager
var vn_view: VnView
var stage_presenter: StagePresenter
var combat_controller: CombatController

var game_scenario: GameScenario:
	get:
		return actor.data.scenario

var ui_mode: UIMode = UIMode.STRATEGY
var is_executing_activity: bool = false
var stat_snapshot: Dictionary = { }
var is_in_combat_encounter: bool = false
var encounter_timeout_timer: float = 0.0
var combat_options: Dictionary = { }

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


func bind_view(v: StrategyView) -> void:
	view = v
	actor = view.actor
	ai_fleet = view.ai_fleet
	vn_view = view.vn_view
	stage_presenter = view.get_stage_presenter()
	_initialize_scenario()
	_setup_components()
	StrategyEventBus.turn_advanced.connect(_on_turn_advanced)
	view.update_morale_bar(actor.player_squad.get_morale())
	game_scenario.initialize(actor.data._build_context())
	_update_ui()
	stage_presenter.start_march(actor.player_squad)
	await _execute_story_triggerables(StrategyTypes.TriggerWhen.GAME_START)


func _process(delta: float) -> void:
	if is_in_combat_encounter and encounter_timeout_timer > 0:
		encounter_timeout_timer -= delta
		view.update_combat_timer(encounter_timeout_timer, combat_options.get("timeout_seconds", 30.0))
		if encounter_timeout_timer <= 0:
			_on_combat_timeout()

#region Initialization

func _initialize_scenario() -> void:
	print(" --- Initialising scenario --- ")
	if is_demo_scenario:
		print(" \\=> DEMO ")
		actor.setup(DemoScenarioFactory.create_demo_scenario())
	else:
		print(" \\=> loading ", scenario_path)
		assert(not scenario_path.is_empty(), "Scenario path is empty")
		assert(ResourceLoader.exists(scenario_path), "Scenario resource does not exist at path: %s" % scenario_path)

		var loaded = ResourceLoader.load(scenario_path)
		if loaded == null:
			var error_msg = "Failed to load scenario from path: %s\nPossible causes:\n" % scenario_path
			error_msg += "  - Script class not found (check class_name matches)\n"
			error_msg += "  - Missing dependencies (check ExtResource paths)\n"
			error_msg += "  - Circular reference in resources\n"
			error_msg += "  - Corrupted .tres file\n"
			push_error(error_msg)
			assert(false, error_msg)

		assert(loaded is GameScenario, "Loaded resource is not a GameScenario (got %s): %s" % [loaded.get_class(), scenario_path])
		actor.setup(loaded)


func _setup_components() -> void:
	combat_controller = CombatController.new()
	combat_controller.set_contact_tracker(game_scenario.world.contact_tracker)
	view.setup_child_guis(actor)
	ai_fleet.setup(game_scenario)
	vn_view.presenter.set_stage_presenter(stage_presenter)
	print("[StrategyPresenter] CombatController initialized")
	print("[StrategyPresenter] AIFleetManager initialized with %d AI squads" % ai_fleet.get_ai_squad_count())

#endregion

#region UI Mode State Machine

func set_ui_mode(mode: UIMode) -> void:
	if ui_mode == mode:
		return
	ui_mode = mode
	match mode:
		UIMode.STRATEGY:
			view.hide_combat_panel()
			stage_presenter.set_mode(StagePresenter.StageMode.MARCH)
			await view.transition_to_strategy()
			_update_activity_buttons()
		UIMode.VISUAL_NOVEL:
			view.hide_combat_panel()
			view.disable_all_activity_buttons()
			view.action_buttons.visible = false
			stage_presenter.set_mode(StagePresenter.StageMode.VN)
			await view.transition_to_vn()
		UIMode.COMBAT_INTERMISSION:
			stage_presenter.set_mode(StagePresenter.StageMode.HIDDEN)
			view.show_combat_ui()

#endregion

#region User Action Handlers

func on_activity_requested(type: StrategyTypes.ActivityType) -> void:
	_execute_activity(type)


func on_travel_requested() -> void:
	view.show_travel_menu(game_scenario, actor.locations)


func on_investigate_requested() -> void:
	view.show_investigation_menu()


func on_recruit_requested() -> void:
	view.show_recruitment_menu()


func on_manage_squad_requested() -> void:
	view.show_manage_squad(actor.player_squad)


func on_shop_requested() -> void:
	var location = actor.current_location
	assert(location.has_shop(), "Shop requested but location has no shop")
	view.show_shop(location.shop, actor.player_squad)


func on_travel_confirmed(location_id: String) -> void:
	var travel_activity = actor.create_travel_activity(location_id)
	view.update_location(_get_travel_label())
	view.hide_travel_menu()
	await _execute_activity_obj(travel_activity)
	if travel_activity.result.location_changed == location_id:
		view.set_travel_mode_autopilot()


func on_travel_cancelled() -> void:
	view.hide_travel_menu()


func on_continue_travel() -> void:
	var dest_location = actor.walking_towards["location"]
	assert(dest_location != null, "Continue travel called but no destination set")
	var travel_activity = actor.create_travel_activity(dest_location.location_id)
	view.update_location(_get_travel_label())
	await _execute_activity_obj(travel_activity)
	if travel_activity.result.location_changed == dest_location.location_id:
		view.set_travel_mode_autopilot()


func on_investigation_closed() -> void:
	view.hide_investigation_menu()


func on_recruitment_completed(warrior: CharacterSocialStats) -> void:
	print("[StrategyPresenter] Recruited warrior: %s" % warrior.name)
	_update_ui()
	stage_presenter.refresh_warriors(actor.player_squad)
	await _execute_activity(StrategyTypes.ActivityType.RECRUIT)


func on_recruitment_closed() -> void:
	view.hide_recruitment_menu()


func on_manage_squad_closed() -> void:
	pass


func on_purchase_completed(purchases: Dictionary) -> void:
	print("[StrategyPresenter] Purchase completed: %s" % [purchases])
	_update_ui()


func on_shop_closed() -> void:
	pass


func on_scouting_requested() -> void:
	view.show_scouting(game_scenario.world, actor.player_squad)


func on_scouting_closed() -> void:
	pass


func on_combat_choice(choice: CombatController.IntermissionChoice) -> void:
	if ui_mode != UIMode.COMBAT_INTERMISSION:
		return
	print("[StrategyPresenter] Player chose: %s" % CombatController.IntermissionChoice.keys()[choice])
	_process_encounter_choice(choice)


func on_skip_pressed() -> void:
	pass


func on_summary_pressed() -> void:
	var _summary_text = "=== Campaign Summary ===\n"
	_summary_text += "SquadCombatData: %s\n" % actor.player_squad.squad_name
	_summary_text += "Turn: %d\n" % game_scenario.world.turn_count
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
	print("[StrategyPresenter] User closed battle manually")
	view.cleanup_battle_scene()

#endregion

#region Activity Pipeline

func _execute_activity(at: StrategyTypes.ActivityType) -> void:
	var activity = actor.get_activity(at)
	assert(activity is Activity)
	await _execute_activity_obj(activity)


func _execute_activity_obj(activity: Activity) -> void:
	if is_executing_activity:
		print("[StrategyPresenter] Activity already in progress, ignoring duplicate request")
		return

	is_executing_activity = true
	view.disable_all_activity_buttons()

	var player_location_before = actor.player_squad.current_location_id

	for state in ['before', 'activity', 'after']:
		await _exec_play_animchanges_loop(activity, state)

	var ai_results = ai_fleet.return_all_ai_turns()
	if ai_results["combats"].size() > 0:
		print("[StrategyPresenter] AI combats occurred: %d" % ai_results["combats"].size())
	if ai_results["movements"].size() > 0:
		print("[StrategyPresenter] AI movements: %d" % ai_results["movements"].size())

	_update_contacts(activity, player_location_before, ai_results)

	ai_fleet.commit_ai_decisions(ai_results)

	actor.advance_turn()
	is_executing_activity = false
	_update_activity_buttons()


func _update_contacts(activity: Activity, player_location_before: String, ai_results: Dictionary) -> void:
	var world = game_scenario.world
	var tracker = world.contact_tracker
	var player = actor.player_squad

	var activity_log: Dictionary = { }
	var edge_log: Dictionary = { }

	activity_log[player.squad_id] = activity.activity_type

	var player_location_after = player.current_location_id
	if player_location_before != player_location_after:
		edge_log[player.squad_id] = { "from": player_location_before, "to": player_location_after }

	ai_fleet.fill_activity_log(activity_log, edge_log)

	var all_squads: Array = [player]
	for sq in world.roaming_squads:
		all_squads.append(sq)

	tracker.update_all_contacts(world, all_squads, activity_log, edge_log, world.turn_count)

	var location = world.get_location_by_id(player.current_location_id)
	if location:
		var active_clues = location.get_active_clues(world.turn_count)
		for clue in active_clues:
			for enemy in world.roaming_squads:
				if clue.left_by_squad_id == enemy.squad_id:
					tracker.apply_clue_bonus(clue, enemy, player)

	var engagements = tracker.check_engagements(world, all_squads)
	for engagement in engagements:
		var involves_player = engagement["attacker_id"] == player.squad_id or engagement["defender_id"] == player.squad_id
		if involves_player:
			await _handle_player_engagement(engagement)


func _handle_player_engagement(engagement: Dictionary) -> void:
	var engagement_type: StrategyTypes.EngagementType = engagement["type"]
	var player = actor.player_squad

	var enemy_id: String
	if engagement["attacker_id"] == player.squad_id:
		enemy_id = engagement["defender_id"]
	else:
		enemy_id = engagement["attacker_id"]

	var enemy_squad = actor.data._find_enemy_squad(enemy_id)
	if not enemy_squad:
		return

	if player.engagement_stance == StrategyTypes.EngagementStance.ALWAYS_ENGAGE:
		print(
			"[StrategyPresenter] Auto-engaging %s (stance: ALWAYS_ENGAGE, type: %s)" % [
				enemy_squad.squad_name,
				StrategyTypes.EngagementType.keys()[engagement_type],
			],
		)
		start_encounter(enemy_squad, { }, engagement_type)
		await encounter_resolved
	else:
		print(
			"[StrategyPresenter] Contact LOCKED with %s (type: %s) — player decides" % [
				enemy_squad.squad_name,
				StrategyTypes.EngagementType.keys()[engagement_type],
			],
		)
		start_encounter(enemy_squad, { }, engagement_type)
		await encounter_resolved


func _enter_combat_if_exists(activity: Activity, all_activity_result: Array[GenericResult]) -> bool:
	var has_combat = all_activity_result.any(func(r): return r is ActivityResult and r.requires_combat)
	if has_combat:
		var _combat: ActivityResult
		for a in all_activity_result:
			if a is ActivityResult and a.requires_combat:
				_combat = a
				break

		assert(_combat.combat_target_squad_id != "", "[GameScenario] Combat required but no target squad ID specified in activity result")

		var enemy_squad = actor.data._find_enemy_squad(_combat.combat_target_squad_id)
		if enemy_squad:
			start_encounter(enemy_squad, actor.data._build_context(activity), _combat.engagement_type)
			await encounter_resolved
		else:
			push_warning("[GameScenario] Combat required but enemy squad with ID '%s' not found" % _combat.combat_target_squad_id)
	return has_combat


func _exec_play_animchanges_loop(activity, state):
	_capture_stat_snapshot()

	var all_activity_result = actor["exec_%s" % state].call(activity)

	_queue_multiple_eventchains_from_results(all_activity_result)
	await _vn_play_next_recurs()
	var has_combat = await _enter_combat_if_exists(activity, all_activity_result)
	if not has_combat:
		await _animate_stat_changes()


func _vn_play_next_recurs():
	var play_empty = view.play_next_queued_chain()
	if play_empty:
		await set_ui_mode(UIMode.STRATEGY)
	else:
		await set_ui_mode(UIMode.VISUAL_NOVEL)
		await view.get_chain_completed_signal()
		await _vn_play_next_recurs()


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

#endregion

#region Combat System

func start_encounter(enemy_squad: SquadStrategicData, _context: Dictionary = { }, engagement_type: StrategyTypes.EngagementType = StrategyTypes.EngagementType.SET_PIECE) -> void:
	print("\n[StrategyPresenter] ========================================")
	print("[StrategyPresenter] COMBAT ENCOUNTER INITIATED (%s)" % StrategyTypes.EngagementType.keys()[engagement_type])
	print("[StrategyPresenter] Enemy: %s (%d warriors)" % [enemy_squad.squad_name, enemy_squad.get_living_warriors().size()])
	print("[StrategyPresenter] ========================================")

	is_in_combat_encounter = true
	combat_options = combat_controller.inject_context(
		actor.player_squad,
		enemy_squad,
		view.battle_viewport,
		view.combat_overlay,
		engagement_type,
	)
	encounter_timeout_timer = combat_options.get("timeout_seconds", 30.0)

	await set_ui_mode(UIMode.COMBAT_INTERMISSION)

	var enemy_name = combat_options.get("enemy_name", "Unknown Enemy")
	var enemy_count = combat_options.get("enemy_count", 0)
	var flee_chance = combat_options.get("flee_chance", 0.0) * 100
	var negotiate_chance = combat_options.get("negotiate_chance", 0.0) * 100

	view.update_combat_intermission(enemy_name, enemy_count, flee_chance, negotiate_chance, combat_options)
	view.update_combat_timer(encounter_timeout_timer, combat_options.get("timeout_seconds", 30.0))

	print("[StrategyPresenter] Combat UI updated:")
	print("[StrategyPresenter]   Flee chance: %.1f%%" % flee_chance)
	print("[StrategyPresenter]   Negotiate chance: %.1f%%" % negotiate_chance)


func _process_encounter_choice(choice: CombatController.IntermissionChoice) -> void:
	view.disable_combat_buttons()
	encounter_timeout_timer = 0

	var encounter_result: CombatController.CombatResult = await combat_controller.process_intermission_choice(choice)
	view.hide_combat_panel()

	print("[StrategyPresenter] Combat result received: %s" % encounter_result.to_string() if encounter_result else "null")
	await _handle_encounter_result(encounter_result)


func _on_combat_timeout() -> void:
	if ui_mode != UIMode.COMBAT_INTERMISSION:
		return
	print("[StrategyPresenter] COMBAT TIMEOUT - Auto-fighting!")
	view.set_combat_info_text("Time's up! Engaging in combat...")
	_process_encounter_choice(CombatController.IntermissionChoice.FIGHT)


func _handle_encounter_result(result: CombatController.CombatResult) -> void:
	is_in_combat_encounter = false

	print("\n[StrategyPresenter] ========================================")
	print("[StrategyPresenter] COMBAT RESOLVED")
	print("[StrategyPresenter] %s" % result.to_string())
	print("[StrategyPresenter] ========================================")

	var morale_before = actor.player_squad.get_morale()

	if result.morale_change != 0:
		actor.player_squad.modify_aggregate_morale(result.morale_change)
		print("[StrategyPresenter] Applied morale change: %.1f" % result.morale_change)

	for casualty_id in result.player_casualties:
		var warrior = actor.player_squad.get_warrior_by_id(casualty_id)
		if warrior:
			print("[StrategyPresenter] Casualty: %s" % warrior.name)

	if result.loot:
		print("[StrategyPresenter] Loot collected: %s" % [result.loot])
		_apply_combat_loot(result.loot)

	if result.clues_dropped.size() > 0:
		var loc = actor.current_location
		for clue in result.clues_dropped:
			loc.add_clue(clue)
			print("[StrategyPresenter] Clue dropped: %s" % clue.clue_name)

	var morale_after = actor.player_squad.get_morale()
	await view.show_combat_result_overlay(result, morale_before, morale_after)

	encounter_resolved.emit(result)


func _apply_combat_loot(loot: Dictionary) -> void:
	var squad = actor.player_squad
	if loot.has("money"):
		squad.money += loot.money
		print("[StrategyPresenter] Gained money: %.0f" % loot.money)
	if loot.has("food"):
		squad.food += int(loot.food)
		print("[StrategyPresenter] Gained food: %d" % int(loot.food))

#endregion

#region Stat Tracking

func _capture_stat_snapshot() -> void:
	if not game_scenario:
		print("[StatAnimation] Cannot capture snapshot - no game_scenario")
		return

	var squad = actor.player_squad
	var _location = actor.current_location

	stat_snapshot = {
		"money": squad.money,
		"food": float(squad.food),
		"karma": squad.karma,
		"morale": squad.get_morale(),
	}
	print("[StatAnimation] Snapshot captured: ", stat_snapshot)


func _calculate_stat_deltas() -> Dictionary:
	if not game_scenario:
		print("[StatAnimation] Cannot calculate deltas - no game_scenario")
		return { }
	if stat_snapshot.is_empty():
		print("[StatAnimation] Cannot calculate deltas - snapshot is empty")
		return { }

	var squad = actor.player_squad

	var current_stats := {
		"money": squad.money,
		"food": float(squad.food),
		"karma": squad.karma,
		"morale": squad.get_morale(),
	}
	print("[StatAnimation] Current stats: ", current_stats)

	var deltas := { }
	for stat_name in stat_snapshot:
		var old_value = stat_snapshot[stat_name]
		var new_value = current_stats[stat_name]
		var delta = new_value - old_value
		if abs(delta) >= 0.01:
			deltas[stat_name] = delta
			print("[StatAnimation] Delta for %s: %.2f (from %.2f to %.2f)" % [stat_name, delta, old_value, new_value])

	if deltas.is_empty():
		print("[StatAnimation] No meaningful deltas detected (all changes < 0.01)")
	else:
		print("[StatAnimation] Total deltas to animate: ", deltas)
	return deltas


func _animate_stat_changes() -> void:
	print("[StatAnimation] _animate_stat_changes() called")
	var deltas = _calculate_stat_deltas()
	if deltas.is_empty():
		print("[StatAnimation] No deltas to animate, returning early")
		return

	print("[StatAnimation] Starting animation with %d delta(s)" % deltas.size())
	await view.animate_stat_changes(deltas)
	print("[StatAnimation] Animation completed")

#endregion

#region UI Updates

func _update_ui() -> void:
	var squad = actor.player_squad
	var world = game_scenario.world
	var location = actor.current_location

	view.update_turn(world.turn_count)
	view.update_location(
		"%s (%s)" % [
			location.location_name if location else "Unknown",
			_location_type_to_string(location.type) if location else "",
		],
	)

	view.update_condition(_get_morale_condition(squad.get_morale()))
	view.update_morale_bar(squad.get_morale())

	view.update_stats(
		squad.money,
		squad.food,
		squad.karma,
		location.stability if location else 0.0,
		location.development if location else 0,
	)

	var walking = actor.walking_towards
	if walking != null and walking["location"] != null:
		view.show_continue_travel_button(walking["location"].location_name)
	else:
		view.hide_continue_travel_button()

	_update_activity_buttons()


func _update_activity_buttons() -> void:
	if not game_scenario or not actor.current_location:
		return

	var location = actor.current_location

	view.update_activity_button(
		view.rest_button,
		"Rest",
		not location.has_activity_type(StrategyTypes.ActivityType.REST),
		_get_activity_tooltip(StrategyTypes.ActivityType.REST),
	)

	view.update_activity_button(
		view.drill_button,
		"Drill",
		not location.has_activity_type(StrategyTypes.ActivityType.DRILL),
		_get_activity_tooltip(StrategyTypes.ActivityType.DRILL),
	)

	view.update_activity_button(
		view.patrol_button,
		"Patrol",
		not location.has_activity_type(StrategyTypes.ActivityType.PATROL),
		_get_activity_tooltip(StrategyTypes.ActivityType.PATROL),
	)

	view.update_activity_button(
		view.investigate_button,
		"Investigate",
		not location.has_activity_type(StrategyTypes.ActivityType.INVESTIGATE),
		_get_activity_tooltip(StrategyTypes.ActivityType.INVESTIGATE),
	)

	view.update_activity_button(
		view.hold_mass_button,
		"Hold Mass",
		not location.has_activity_type(StrategyTypes.ActivityType.HOLD_MASS),
		_get_activity_tooltip(StrategyTypes.ActivityType.HOLD_MASS),
	)

	view.update_activity_button(
		view.travel_button,
		"Travel",
		false,
		"Travel to another location",
	)

	var enemies_here = game_scenario.world.get_squads_at_location(location.location_id)
	var attack_tooltip: String
	if not enemies_here.is_empty():
		attack_tooltip = "Attack %s" % [enemies_here]
	else:
		attack_tooltip = "No enemies at this location"
	view.update_activity_button(
		view.attack_button,
		"Attack",
		enemies_here.is_empty(),
		attack_tooltip,
	)

	view.update_activity_button(
		view.manage_squad_button,
		"Manage SquadCombatData",
		false,
		"View and manage your warriors",
	)

	var has_shop = location.has_shop()
	view.update_activity_button(
		view.shop_button,
		"Shop",
		not has_shop,
		"Browse the local shop" if has_shop else "No shop at this location",
	)


func _get_activity_tooltip(activity_type: StrategyTypes.ActivityType) -> String:
	var activity = actor.get_activity(activity_type)
	if not activity:
		return "Unknown activity"
	return "%s\n\nTime Cost: %d turn(s)" % [activity.description, activity.time_cost]


func _get_travel_label() -> String:
	if walking_towards:
		return "Travelling to %s" % walking_towards.location_name
	else:
		return current_location.location_name

#endregion

#region Model Signal Handlers

func _on_turn_advanced(turn: int) -> void:
	print("Turn advanced to: %d" % turn)
	view.update_turn(turn)
	await _execute_story_triggerables(StrategyTypes.TriggerWhen.TURN_START)

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
