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
		return actor.aem.scenario

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
	# Master setup: wires the presenter to its view and all child components, initializes the scenario
	# Called once by StrategyView._ready(). This is the game's boot sequence.
	# Flow: bind refs → load scenario → setup components → connect signals → initialize world → start march → run GAME_START events
	# e.g., binds view → loads "demo_scenario" → creates CombatController + AIFleetManager → plays opening EventChain
	view = v
	actor = view.actor
	ai_fleet = view.ai_fleet
	vn_view = view.vn_view
	stage_presenter = view.get_stage_presenter()
	_initialize_scenario()
	_setup_components()
	StrategyEventBus.turn_advanced.connect(_on_turn_advanced)
	view.update_morale_bar(actor.player_squad.get_morale())
	game_scenario.initialize(actor.aem._build_context())
	_update_ui()
	stage_presenter.start_march(actor.player_squad)
	await _execute_story_triggerables(StrategyTypes.TriggerWhen.GAME_START)
	await _check_missions()


func _process(delta: float) -> void:
	if is_in_combat_encounter and encounter_timeout_timer > 0:
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
	# Initializes combat controller, child GUIs (travel/investigation/recruitment menus), and AI fleet
	# Also links VnPresenter to StagePresenter so VN timelines can control the 2D stage characters
	# e.g., CombatController gets contact_tracker so it can determine engagement types (AMBUSH vs SET_PIECE)
	combat_controller = CombatController.new()
	combat_controller.set_contact_tracker(game_scenario.world.contact_tracker)
	view.setup_child_guis(actor)
	ai_fleet.setup(game_scenario)
	vn_view.presenter.set_stage_presenter(stage_presenter)
	Log.info("Presenter", "CombatController initialized")
	Log.info("Presenter", "AIFleetManager initialized with %d AI squads" % ai_fleet.get_ai_squad_count())

#endregion

#region UI Mode State Machine

func set_ui_mode(mode: UIMode) -> void:
	# State machine that transitions between STRATEGY (activity buttons), VISUAL_NOVEL (timeline playback), and COMBAT_INTERMISSION (fight/flee/negotiate)
	# Each mode shows/hides relevant UI panels and sets the stage to the appropriate visual mode
	# e.g., STRATEGY → shows action buttons, stage in MARCH mode (warriors walk)
	# e.g., VISUAL_NOVEL → hides buttons, stage in VN mode (dialogue scene), transitions via SceneManager
	# e.g., COMBAT_INTERMISSION → hides stage, shows combat choice panel with flee/negotiate percentages
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
	Log.info("Presenter", "Recruited warrior: %s" % warrior.name)
	_update_ui()
	stage_presenter.refresh_warriors(actor.player_squad)
	await _execute_activity(StrategyTypes.ActivityType.RECRUIT)


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
	view.show_scouting(game_scenario.world, actor.player_squad)


func on_scouting_closed() -> void:
	pass


func on_missions_requested() -> void:
	if game_scenario.factions.is_empty():
		return
	view.show_missions(game_scenario.factions)


func on_missions_closed() -> void:
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
	Log.debug("Presenter", "User closed battle manually")
	view.cleanup_battle_scene()

#endregion

#region Activity Pipeline

func _execute_activity(at: StrategyTypes.ActivityType) -> void:
	# Shortcut: looks up the Activity resource by type and delegates to _execute_activity_obj
	# e.g., _execute_activity(REST) → finds "rest" Activity from triggerable_manager → _execute_activity_obj(rest_activity)
	var activity = actor.get_activity(at)
	assert(activity is Activity)
	await _execute_activity_obj(activity)


func _execute_activity_obj(activity: Activity) -> void:
	if is_executing_activity:
		return
	is_executing_activity = true
	view.disable_all_activity_buttons()

	var player_location_before = actor.player_squad.current_location_id

	var ai_results = ai_fleet.prepare_ai_turns()
	var turn_entries = _build_karma_sorted_entries(ai_results)

	for entry in turn_entries:
		if entry["is_player"]:
			await _execute_story_triggerables(StrategyTypes.TriggerWhen.TURN_START)
		else:
			(entry["executor"] as ActivityExecuteManager).execute_triggerables_at(StrategyTypes.TriggerWhen.TURN_START)

	for phase in ['before', 'activity', 'after']:
		for entry in turn_entries:
			if entry["is_player"]:
				await _exec_play_animchanges_loop(activity, phase)
			else:
				var executor: ActivityExecuteManager = entry["executor"]
				var results: Array[GenericResult] = executor["exec_%s" % phase].call(entry["activity"])
				_resolve_ai_combat_from_results(results, entry["squad_id"])

	ai_fleet.cleanup_defeated_squads()
	_update_contacts(activity, player_location_before, ai_results)

	await _check_missions()
	actor.advance_turn()
	is_executing_activity = false
	_update_ui()


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
	_queue_multiple_eventchains_from_results(all_activity_result)
	await _vn_play_next_recurs()
	var has_combat = await _enter_combat_if_exists(activity, all_activity_result)
	if not has_combat:
		await _animate_stat_changes()


func _update_contacts(activity: Activity, player_location_before: String, ai_results: Dictionary) -> void:
	# Updates the contact/detection system after a turn:
	# 1. Builds activity logs (who did what) and edge logs (who moved where)
	# 2. Runs contact_tracker.update_all_contacts() to advance detection progress for all squads
	# 3. Checks location clues for bonus contact on enemies
	# 4. Checks for engagement triggers (contact LOCKED → combat)
	#
	# e.g., player did TRAVEL from "salzburg" to "linz", AI squad "Raiders" did PATROL at "linz"
	#   → activity_log = {player: TRAVEL, raiders: PATROL}
	#   → edge_log = {player: {from: salzburg, to: linz}}
	#   → contacts updated: player↔Raiders both gain detection progress (same location now)
	#   → clue at linz from Raiders → bonus contact
	#   → engagement check: player has LOCKED on Raiders → _handle_player_engagement()
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
	# Handles a detected engagement where the player is involved
	# Determines which squad is the enemy, then starts the combat encounter
	# Currently auto-engages regardless of stance (both ALWAYS_ENGAGE and player-decides call start_encounter)
	# e.g., engagement={attacker_id: "player", defender_id: "raiders", type: AMBUSH}
	#   → enemy = "raiders" → start_encounter(raiders, {}, AMBUSH) → awaits combat resolution
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
	# Recursively plays all queued EventChains: dequeue → play → wait for completion → repeat
	# When queue is empty, transitions back to STRATEGY mode
	# e.g., queue=["opening_cutscene", "camp_fire"] → play "opening_cutscene" → await done → play "camp_fire" → await done → STRATEGY
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


func _check_missions() -> void:
	var context = actor.aem._build_context()
	var all_results: Array[MissionResult] = []
	for faction in game_scenario.factions:
		var results = faction.check_mission_completions(context)
		for r in results:
			all_results.append(r)
	if all_results.is_empty():
		return
	var generic_results: Array[GenericResult] = []
	for r in all_results:
		generic_results.append(r)
	_queue_multiple_eventchains_from_results(generic_results)
	await _vn_play_next_recurs()

#endregion

#region Combat System

func start_encounter(enemy_squad: SquadStrategicData, _context: Dictionary = { }, engagement_type: StrategyTypes.EngagementType = StrategyTypes.EngagementType.SET_PIECE) -> void:
	# Initiates a combat encounter: injects context into CombatController, switches UI to intermission mode
	# The controller calculates flee/negotiate chances based on squad stats and engagement type
	# UI shows the intermission panel with buttons and a countdown timer (30s default)
	# e.g., enemy="Raiders"(4 warriors), engagement=AMBUSH (player ambushed)
	#   → inject_context() returns {can_flee: false, can_negotiate: false, ...}
	#   → UI shows only FIGHT button, timer starts at 30s
	# e.g., enemy="Bandits"(2 warriors), engagement=SET_PIECE
	#   → returns {flee_chance: 0.45, negotiate_chance: 0.35, ...}
	#   → UI shows all 3 buttons with percentages
	Log.info("Presenter", "COMBAT ENCOUNTER INITIATED (%s)" % StrategyTypes.EngagementType.keys()[engagement_type])
	Log.info("Presenter", "Enemy: %s (%d warriors)" % [enemy_squad.squad_name, enemy_squad.get_living_warriors().size()])

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

	Log.debug("Presenter", "Combat UI updated: flee=%.1f%% negotiate=%.1f%%" % [flee_chance, negotiate_chance])


func _process_encounter_choice(choice: CombatController.IntermissionChoice) -> void:
	# Processes the player's combat intermission choice (FIGHT/FLEE/NEGOTIATE)
	# Disables buttons to prevent double-input, delegates to CombatController, then handles result
	# e.g., FIGHT → _execute_combat() → CombatResult{victory, casualties=[w2]} → _handle_encounter_result()
	# e.g., FLEE(roll fails) → forced combat → CombatResult{victory=false} → _handle_encounter_result()
	view.disable_combat_buttons()
	encounter_timeout_timer = 0

	var encounter_result: CombatController.CombatResult = await combat_controller.process_intermission_choice(choice)
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
	# Applies combat outcome to the game state: morale changes, casualty tracking, loot, clues
	# Then shows the combat result overlay (VICTORY/DEFEAT/FLED/NEGOTIATED with morale animation)
	# e.g., result={victory:true, morale_change:+10, loot:{money:50, food:3}, clues:[Clue("linz")]}
	#   → apply morale +10, add 50 money, add 3 food, add clue to current location
	#   → show overlay with "VICTORY!" label and morale bar animation 60→70
	is_in_combat_encounter = false

	Log.info("Presenter", "COMBAT RESOLVED: %s" % result.to_string())

	var morale_before = actor.player_squad.get_morale()

	if result.morale_change != 0:
		actor.player_squad.modify_aggregate_morale(result.morale_change)
		Log.debug("Presenter", "Applied morale change: %.1f" % result.morale_change)

	for casualty_id in result.player_casualties:
		var warrior = actor.player_squad.get_warrior_by_id(casualty_id)
		if warrior:
			Log.info("Presenter", "Casualty: %s" % warrior.name)

	if result.loot:
		Log.debug("Presenter", "Loot collected: %s" % [result.loot])
		_apply_combat_loot(result.loot)

	if result.clues_dropped.size() > 0:
		var loc = actor.current_location
		for clue in result.clues_dropped:
			loc.add_clue(clue)
			Log.debug("Presenter", "Clue dropped: %s" % clue.clue_name)

	var morale_after = actor.player_squad.get_morale()
	await view.show_combat_result_overlay(result, morale_before, morale_after)

	encounter_resolved.emit(result)


func _apply_combat_loot(loot: Dictionary) -> void:
	var squad = actor.player_squad
	if loot.has("money"):
		squad.money += loot.money
		Log.debug("Presenter", "Gained money: %.0f" % loot.money)
	if loot.has("food"):
		squad.food += int(loot.food)
		Log.debug("Presenter", "Gained food: %d" % int(loot.food))

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

	view.update_turn(world.turn_count)

	var walking = actor.walking_towards
	if walking != null and walking["location"] != null:
		var dest: Location = walking["location"]
		var progress: int = walking["progress"]
		var distance: int = actor.get_distance(actor.current_location, dest)
		view.update_location("Travelling to %s (%d/%d)" % [dest.location_name, progress, distance])
	else:
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

	walking = actor.walking_towards
	if walking != null and walking["location"] != null:
		view.show_continue_travel_button(walking["location"].location_name)
	else:
		view.hide_continue_travel_button()

	_update_activity_buttons()


func _update_activity_buttons() -> void:
	# Enables/disables each activity button based on whether the current location supports that activity
	# Also handles special cases: attack requires enemies at location, shop requires location.has_shop()
	# e.g., location="salzburg" (Village) with activities=[REST, FORAGE, TRAVEL]
	#   → rest=enabled, drill=disabled, forage=enabled, travel=enabled, attack=disabled (no enemies)
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
	view.update_turn(turn)

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
