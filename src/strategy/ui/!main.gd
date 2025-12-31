extends Control

## Strategic Campaign UI Screen with integrated Visual Novel system
## Displays squad state, world info, and allows activity selection
## Seamlessly transitions to VN mode for EventChain playback
## Handles combat encounters with intermission choices (Flee/Negotiate/Fight)

# const StatChangeAnimator = preload("res://src/strategy/core/stat_change_animator.gd")

signal vn_completed();
signal combat_completed(result: CombatController.CombatResult);
signal encounter_resolved(); # Emitted when combat encounter ends (regardless of outcome)

enum UIMode {
	STRATEGY, # Normal activity buttons visible
	VISUAL_NOVEL, # VN elements visible, strategy UI dimmed
	COMBAT_INTERMISSION # Combat choice screen (Flee/Negotiate/Fight)
}

@onready var turn_label: Label = $PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderHBox/HeaderMargin/TurnAndLocation/TurnLabel
@onready var location_label: Label = $PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderHBox/HeaderMargin/TurnAndLocation/LocationLabel
@onready var end_button: Button = $PanelContainer/MainVBox/StatusArea/EndButton
@onready var morale_bar: ProgressBar = $PanelContainer/MainVBox/StatusArea/StatusPanel/StatusMargin/StatusContent/ProgressBar
@onready var morale_panel: PanelContainer = $PanelContainer/MainVBox/StatusArea/StatusPanel
@onready var condition_label: Label = $PanelContainer/MainVBox/StatusArea/StatusPanel/StatusMargin/StatusContent/ConditionStatus/ConditionMargin/ConditionLabel

@onready var main_background: TextureRect = $PanelContainer/MainBackground
@onready var foreground: TextureRect = $PanelContainer/Foreground
@onready var character_container: HBoxContainer = $PanelContainer/MainVBox/MainScreenArea/CharacterContainer
# @onready var hint_icon: TextureRect = $PanelContainer/MainVBox/MainScreenArea/HintIcon
@onready var dialogue_box: PanelContainer = $PanelContainer/MainVBox/MainScreenArea/DialogueBox
@onready var speaker_label: Label = $PanelContainer/MainVBox/MainScreenArea/DialogueBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_label: Label = $PanelContainer/MainVBox/MainScreenArea/DialogueBox/MarginContainer/VBoxContainer/DialogueLabel
@onready var advance_prompt: Label = $PanelContainer/MainVBox/MainScreenArea/DialogueBox/AdvancePrompt

@onready var stats_panel: PanelContainer = $PanelContainer/MainVBox/StatusHeader/HeaderPanel
@onready var stability_label: Label = get_node("PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Stability/MarginContainer/Stability/Label")
@onready var development_label: Label = get_node("PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Development/MarginContainer/Development/Label")
@onready var money_label: Label = get_node("PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Money/MarginContainer/BoxContainer/Label")
@onready var food_label: Label = get_node("PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Food/MarginContainer/BoxContainer/Label")
@onready var karma_label: Label = get_node("PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Karma/MarginContainer/BoxContainer/Label")

@onready var action_buttons: PanelContainer = $PanelContainer/MainVBox/ActionButtons
@onready var rest_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/TrainingButton
@onready var drill_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/RestButton
@onready var patrol_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/SkillButton
@onready var investigate_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/NurseButton
@onready var hold_mass_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/OutingButton
@onready var travel_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/RaceButton
@onready var attack_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/AttackButton
@onready var travel_gui: TravelGUI = $TravelGUI

@onready var skip_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/SkipButton
@onready var short_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/ShortButton

# Combat UI elements (will be added to scene)
@onready var combat_panel: PanelContainer = $CombatIntermission
@onready var combat_enemy_label: Label = $CombatIntermission/MarginContainer/VBoxContainer/EnemyInfoLabel
@onready var encounter_flee_button: Button = $CombatIntermission/MarginContainer/VBoxContainer/ButtonContainer/FleeButton
@onready var encounter_negotiate_button: Button = $CombatIntermission/MarginContainer/VBoxContainer/ButtonContainer/NegotiateButton
@onready var encounter_fight_button: Button = $CombatIntermission/MarginContainer/VBoxContainer/ButtonContainer/FightButton
@onready var combat_timer_bar: ProgressBar = $CombatIntermission/MarginContainer/VBoxContainer/TimerBar
@onready var combat_info_label: Label = $CombatIntermission/MarginContainer/VBoxContainer/InfoLabel

@onready var combat_overlay: CanvasLayer = $CombatOverlay
@onready var battle_viewport: SubViewport = $CombatOverlay/BattleViewportContainer/BattleViewport
@onready var battle_close_button: Button = $CombatOverlay/CloseButton

#region State Variables
var game_scenario: GameScenario
var ui_mode: UIMode = UIMode.STRATEGY
var event_chain_queue: Array[String] = []
var is_playing_chain: bool = false
var is_executing_activity: bool = false
var stat_snapshot: Dictionary = {}

# Combat state
var combat_controller: CombatController = null
var is_in_combat_encounter: bool = false
var encounter_timeout_timer: float = 0.0
var combat_options: Dictionary = {}
#endregion

#region Components
var vn_controller: VisualNovelController = VisualNovelController.new()
var stat_animator: StatChangeAnimator = StatChangeAnimator.new()
#endregion

@export var player__registered_squad: StrategicSquad = null
@export var scenario_path: String
@export var is_demo_scenario: bool = true

func _init() -> void:
	print(" --- main gui init --- ")

func _ready() -> void:
	print(" --- Main gui is ready --- ")
	_initialize_scenario()
	_setup_components()
	_connect_signals()
	_set_ui_mode(UIMode.STRATEGY)
	_update_ui()

func _process(delta: float) -> void:
	if is_in_combat_encounter and encounter_timeout_timer > 0:
		encounter_timeout_timer -= delta
		_update_combat_timer_display()
		if encounter_timeout_timer <= 0:
			_on_combat_timeout()

#region Initialization

func _initialize_scenario() -> void:
	print(" --- Initialising scenario --- ")
	if is_demo_scenario:
		print (" \\=> DEMO ")
		game_scenario = DemoScenarioFactory.create_demo_scenario()
	else:
		print (" \\=> loading ", scenario_path)
		var loaded = load(scenario_path)
		game_scenario = loaded
		game_scenario.initialize({
			"player_squad": player__registered_squad
		})

func _setup_components() -> void:
	vn_controller.chain_completed.connect(_on_vn_chain_completed)
	vn_controller.dialogue_advanced.connect(_on_vn_dialogue_advanced)
	
	# Initialize combat controller
	combat_controller = CombatController.new()
	print("[TrainingScreen] CombatController initialized")

#endregion

#region Signals
func _connect_signals() -> void:
	rest_button.pressed.connect(_on_rest_pressed)
	drill_button.pressed.connect(_on_drill_pressed)
	patrol_button.pressed.connect(_on_patrol_pressed)
	investigate_button.pressed.connect(_on_investigate_pressed)
	hold_mass_button.pressed.connect(_on_hold_mass_pressed)
	travel_button.pressed.connect(_on_travel_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	
	end_button.pressed.connect(_on_end_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	short_button.pressed.connect(_on_short_pressed)

	vn_completed.connect(_on_vn_completed_signal)
	
	# Combat button signals (only connect if nodes exist)
	if encounter_flee_button:
		encounter_flee_button.pressed.connect(_on_combat_flee_pressed)
	if encounter_negotiate_button:
		encounter_negotiate_button.pressed.connect(_on_combat_negotiate_pressed)
	if encounter_fight_button:
		encounter_fight_button.pressed.connect(_on_combat_fight_pressed)
	
	if travel_gui:
		travel_gui.travel_confirmed.connect(_on_travel_confirmed)
		travel_gui.travel_cancelled.connect(_on_travel_cancelled)
	
	if game_scenario:
		game_scenario.activity_executed.connect(_on_activity_executed)
		game_scenario.turn_advanced.connect(_on_turn_advanced)
		game_scenario.triggerable_fired.connect(_on_triggerable_fired)

	if dialogue_box:
		dialogue_box.gui_input.connect(_on_dialogue_box_clicked)

#region Button Signal Handlers

func _on_rest_pressed() -> void:
	_execute_activity(StrategyTypes.ActivityType.REST)

func _on_drill_pressed() -> void:
	_execute_activity(StrategyTypes.ActivityType.DRILL)

func _on_patrol_pressed() -> void:
	_execute_activity(StrategyTypes.ActivityType.PATROL)

func _on_investigate_pressed() -> void:
	_execute_activity(StrategyTypes.ActivityType.INVESTIGATE)

func _on_hold_mass_pressed() -> void:
	_execute_activity(StrategyTypes.ActivityType.HOLD_MASS)

func _on_travel_pressed() -> void:
	travel_gui.show_travel_menu(game_scenario)

func _on_attack_pressed() -> void:
	_execute_activity(StrategyTypes.ActivityType.ATTACK)

func _on_end_pressed() -> void:
	dialogue_label.text = "Game ended. Final turn: %d" % game_scenario.world.turn_count

func _on_skip_pressed() -> void:
	# for i in 5:
	# 	_execute_activity(StrategyTypes.ActivityType.REST)
	pass

func _on_travel_confirmed(location_id: String) -> void:
	var travel_activity = _create_travel_activity(location_id)
	travel_activity.result.location_changed = location_id
	var travel_time = game_scenario.world.calculate_travel_time(
		game_scenario.current_location.location_id,
		location_id
	)
	if travel_time > 0:
		travel_activity.time_cost = travel_time
	
	travel_gui.hide_travel_menu()
	_execute_activity_with_object(travel_activity)

func _on_travel_cancelled() -> void:
	# if travel_gui:
	travel_gui.hide_travel_menu()

func _create_travel_activity(location_id: String) -> Activity:
	var activity = Activity.new()
	activity.trigger_id = "travel-to-%s" % location_id
	activity.trigger_name = "Travel"
	activity.description = "Travel to another location"
	activity.activity_type = StrategyTypes.ActivityType.TRAVEL
	activity.time_cost = 1
	
	# Create result with travel costs - morale decreases, travel tools consumed
	var travel_result = ActivityResult.new({"location_changed": location_id})
	travel_result.event_chain_path = "empty"
	
	# Travel costs: morale penalty and travel tools consumption
	# These can be modified based on distance, terrain, etc.
	travel_result.squad_stat_changes[StrategyTypes.SquadProperty.MORALE] = -5.0
	travel_result.squad_stat_changes[StrategyTypes.SquadProperty.AMMO_SUPPLIES] = -1.0 # travel_tools
	
	activity.result = travel_result
	return activity

func _execute_activity_with_object(activity: Activity) -> void:
	# Guard against race conditions from double-clicking
	if is_executing_activity:
		print("[TrainingScreen] Activity already in progress, ignoring duplicate request")
		return
	
	is_executing_activity = true

	# Disable all buttons at the start of activity execution
	_disable_all_activity_buttons()
	
	# First capture of stat does not require animations or updates (nothing has changed since last round)
	_capture_stat_snapshot()
	
	var player_squad = game_scenario.player_squad
	var world = game_scenario.world
	print("\n[GameScenario] === execute_turn() START ===")
	print("[GameScenario] Activity: ", activity.trigger_name)
	print("[GameScenario] Squad before: Money=%.1f, Food=%d, Morale=%.1f" % [player_squad.money, player_squad.food, player_squad.get_morale()])
	
	
	var preact_results: Array[GenericResult] = game_scenario.execute_triggerables(
		activity,
		StrategyTypes.TriggerWhen.BEFORE_ACTIVITY
	);
	await _apply_play_wait(preact_results)

	var activity_result: ActivityResult = activity.execute(player_squad, world); print("[GameScenario] Activity result: %s" % activity_result)
	await _apply_play_wait([activity_result])
	
	# Check if combat was triggered by the activity
	if activity_result.requires_combat:
		assert(activity_result.combat_target_squad_id != "", "[GameScenario] Combat required but no target squad ID specified in activity result");
		var enemy_squad = _find_enemy_squad(activity_result.combat_target_squad_id)
		if enemy_squad:
			start_encounter(enemy_squad, {"activity": activity.trigger_name})
			await encounter_resolved
		else:
			push_warning("[GameScenario] Combat required but enemy squad with ID '%s' not found" % activity_result.combat_target_squad_id)
	
	var postact_results: Array[GenericResult] = game_scenario.execute_triggerables(
		activity,
		StrategyTypes.TriggerWhen.AFTER_ACTIVITY
	);
	await _apply_play_wait(postact_results)
	
	var completed_missions: Array[Mission] = game_scenario._check_mission_completion()
	for mission in completed_missions:
		game_scenario.mission_completed.emit(mission)
	
	var ending: Ending = game_scenario._check_ending_conditions()
	if ending:
		game_scenario.game_ended = true
		game_scenario.ending_triggered = ending
		game_scenario.ending_reached.emit(ending)
	
	world.advance_turn(activity.time_cost)
	game_scenario.turn_advanced.emit(world.turn_count)
	
	print("[GameScenario] Squad final: Money=%.1f, Food=%d, Morale=%.1f" % [player_squad.money, player_squad.food, player_squad.get_morale()])
	print("[GameScenario] === execute_turn() END ===\n")
	
	# Re-enable buttons after activity is complete
	is_executing_activity = false
	_reenable_activity_buttons()
	

func _on_short_pressed() -> void:
	var summary_text = "=== Campaign Summary ===\n"
	summary_text += "Squad: %s\n" % game_scenario.player_squad.squad_name
	summary_text += "Turn: %d\n" % game_scenario.world.turn_count
	summary_text += "Location: %s (Dev:%d Stab:%.0f)\n" % [
		game_scenario.current_location.location_name,
		game_scenario.current_location.development,
		game_scenario.current_location.stability
	]
	summary_text += "Morale: %.1f\n" % game_scenario.player_squad.get_morale()
	summary_text += "Money: %.0f\n" % game_scenario.player_squad.money
	summary_text += "Food: %d\n" % game_scenario.player_squad.food
	summary_text += "Karma: %.0f\n" % game_scenario.player_squad.karma
	
	dialogue_label.text = summary_text

#endregion

#region Game Scenario Signal Handlers

func _on_activity_executed(activity: Activity, _result: ActivityResult) -> void:
	# current_activity_result = _result
	print("Activity executed: %s" % activity.trigger_name)

func _on_turn_advanced(turn: int) -> void:
	print("Turn advanced to: %d" % turn)

func _on_triggerable_fired(triggerable: Triggerable, _result: Variant) -> void:
	print("TrainingScreen: Triggerable fired: %s (%s)" % [triggerable.trigger_name, triggerable.get_class()])

#endregion

#endregion

#region UI Helpers

func _update_ui() -> void:
	var squad = game_scenario.player_squad
	var world = game_scenario.world
	var location = game_scenario.current_location
	
	turn_label.text = "Turn %d" % world.turn_count
	location_label.text = "%s (%s)" % [
		location.location_name if location else "Unknown",
		_location_type_to_string(location.type) if location else "",
	]
	
	morale_bar.value = squad.get_morale()
	morale_bar.max_value = 100.0
	condition_label.text = _get_morale_condition(squad.get_morale())
	
	stability_label.text = "%.0f" % (location.stability if location else 0.0)
	development_label.text = "%d" % (location.development if location else 0)
	money_label.text = "%.0f" % squad.money
	food_label.text = "%d" % squad.food
	karma_label.text = "%.0f" % squad.karma
	
	_update_activity_buttons()

func _update_activity_buttons() -> void:
	if not game_scenario or not game_scenario.current_location:
		return
	
	var location = game_scenario.current_location
	
	rest_button.text = "Rest"
	rest_button.disabled = not location.has_activity_type(StrategyTypes.ActivityType.REST)
	rest_button.tooltip_text = _get_activity_tooltip(StrategyTypes.ActivityType.REST)
	
	drill_button.text = "Drill"
	drill_button.disabled = not location.has_activity_type(StrategyTypes.ActivityType.DRILL)
	drill_button.tooltip_text = _get_activity_tooltip(StrategyTypes.ActivityType.DRILL)
	
	patrol_button.text = "Patrol"
	patrol_button.disabled = not location.has_activity_type(StrategyTypes.ActivityType.PATROL)
	patrol_button.tooltip_text = _get_activity_tooltip(StrategyTypes.ActivityType.PATROL)
	
	investigate_button.text = "Investigate"
	investigate_button.disabled = not location.has_activity_type(StrategyTypes.ActivityType.INVESTIGATE)
	investigate_button.tooltip_text = _get_activity_tooltip(StrategyTypes.ActivityType.INVESTIGATE)
	
	hold_mass_button.text = "Hold Mass"
	hold_mass_button.disabled = not location.has_activity_type(StrategyTypes.ActivityType.HOLD_MASS)
	hold_mass_button.tooltip_text = _get_activity_tooltip(StrategyTypes.ActivityType.HOLD_MASS)
	
	travel_button.text = "Travel"
	travel_button.disabled = false
	travel_button.tooltip_text = "Travel to another location"
	
	# Attack button - enabled only if enemies are at this location
	var enemies_here = game_scenario.world.get_squads_at_location(location.location_id)
	attack_button.text = "Attack"
	attack_button.disabled = enemies_here.is_empty()
	if not enemies_here.is_empty():
		attack_button.tooltip_text = "Attack %s (%d warriors)" % [enemies_here[0].squad_name, enemies_here[0].get_living_warriors().size()]
	else:
		attack_button.tooltip_text = "No enemies at this location"

func _disable_all_activity_buttons() -> void:
	rest_button.disabled = true
	drill_button.disabled = true
	patrol_button.disabled = true
	investigate_button.disabled = true
	hold_mass_button.disabled = true
	travel_button.disabled = true
	attack_button.disabled = true

func _reenable_activity_buttons() -> void:
	_update_activity_buttons()

func _get_activity(_getting_type: StrategyTypes.ActivityType) -> Activity:
	for triggerable in game_scenario.triggerable_manager.registered_triggerables:
		if triggerable is Activity and triggerable.activity_type == _getting_type:
			return triggerable as Activity
	return null

func _get_activity_tooltip(activity_type: StrategyTypes.ActivityType) -> String:
	var activity = _get_activity(activity_type)
	if not activity:
		return "Unknown activity"
	return "%s\n\nTime Cost: %d turn(s)" % [activity.description, activity.time_cost]

#endregion

#region Activity Execution

func _apply_play_wait(results: Array[GenericResult]):
	# apply changes
	for r in results:
		game_scenario._apply_result(r)

	# queue and play
	_queue_multiple_eventchains_from_results(results)
	await _play_next_queued_chain()
	
	# 
	if is_playing_chain: await vn_completed

	_update_ui()

func _execute_activity(activity_type: StrategyTypes.ActivityType) -> void:
	var activity = _get_activity(activity_type)
	assert(activity != null)

	await _execute_activity_with_object(activity)

func _queue_multiple_eventchains_from_results(results_list: Array[GenericResult]) -> void:
	for result in results_list:
		if result is GenericResult:
			if result.has_event_chain(): _queue_event_chain(result.event_chain_path)
		else:
			assert(false, "%s" % result)

#endregion

#region Stat Animation

func _anim_update_capture() -> void:
	await _animate_stat_changes()
	_update_ui()
	_capture_stat_snapshot()

func _capture_stat_snapshot() -> void:
	if not game_scenario:
		print("[StatAnimation] Cannot capture snapshot - no game_scenario")
		return
	
	var squad = game_scenario.player_squad
	var _location = game_scenario.current_location
	
	stat_snapshot = {
		"money": squad.money,
		"food": float(squad.food),
		"karma": squad.karma,
		"morale": squad.get_morale(),
		#"stability": location.stability if location else 0.0,
		#"development": float(location.development if location else 0)
	}
	print("[StatAnimation] Snapshot captured: ", stat_snapshot)

func _calculate_stat_deltas() -> Dictionary:
	if not game_scenario:
		print("[StatAnimation] Cannot calculate deltas - no game_scenario")
		return {}
	if stat_snapshot.is_empty():
		print("[StatAnimation] Cannot calculate deltas - snapshot is empty")
		return {}
	
	var squad = game_scenario.player_squad
	# var location = game_scenario.current_location
	
	var current_stats := {
		"money": squad.money,
		"food": float(squad.food),
		"karma": squad.karma,
		"morale": squad.get_morale(),
		# "stability": location.stability if location else 0.0,
		# "development": float(location.development if location else 0)
	}
	print("[StatAnimation] Current stats: ", current_stats)
	
	var deltas := {}
	for stat_name in stat_snapshot:
		var old_value = stat_snapshot[stat_name]
		var new_value = current_stats[stat_name]
		var delta = new_value - old_value
		if abs(delta) >= 0.01: # Only include meaningful changes
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
	
	var ui_elements := {
		"money": money_label,
		"food": food_label,
		"karma": karma_label,
		"stability": stability_label,
		"development": development_label,
		"morale": morale_bar,
		"morale_bar": morale_bar,
		"new_morale_value": game_scenario.player_squad.get_morale() if game_scenario else 0.0,
		"stats_panel": stats_panel
	}
	
	print("[StatAnimation] Starting animation with %d delta(s)" % deltas.size())
	await stat_animator.animate_changes(self, deltas, ui_elements)
	print("[StatAnimation] Animation completed")

#endregion

#region Utility Functions

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

#region Event Chain Management

func _queue_event_chain(chain_path: String) -> void:
	event_chain_queue.append(chain_path)
	print("TrainingScreen: Queued event chain: %s (queue size: %d)" % [chain_path, event_chain_queue.size()])
	# Don't auto-play here - let the caller decide when to start playback

func _play_next_queued_chain() -> void:
	if event_chain_queue.is_empty():
		_exit_from_vn_to_strategy()
	else:
		is_playing_chain = true
		var chain_path = event_chain_queue.pop_front()
		await SceneManager.transition_quick(func(): _play_event_chain(chain_path))

func _exit_from_vn_to_strategy():
	print("exiting from vn to strategy")
	is_playing_chain = false
	_set_ui_mode(UIMode.STRATEGY)
	_update_ui()
	return


#endregion

#region Visual Novel Functions

func _set_ui_mode(mode: UIMode) -> void:
	ui_mode = mode
	match mode:
		UIMode.STRATEGY:
			dialogue_box.visible = false
			if combat_panel: combat_panel.visible = false
			_show_strategy_ui()
		UIMode.VISUAL_NOVEL:
			dialogue_box.visible = true
			if combat_panel: combat_panel.visible = false
			_show_vn_ui()
		UIMode.COMBAT_INTERMISSION:
			dialogue_box.visible = false
			if combat_panel: combat_panel.visible = true
			_show_combat_ui()

func _show_strategy_ui() -> void:
	action_buttons.visible = true
	stats_panel.modulate.a = 1.0
	character_container.visible = false
	speaker_label.visible = false
	advance_prompt.visible = false
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _show_vn_ui() -> void:
	action_buttons.visible = false
	stats_panel.modulate.a = 0.5
	character_container.visible = true
	speaker_label.visible = true
	advance_prompt.visible = true
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _play_event_chain(chain_path: String) -> void:
	if chain_path.is_empty() or chain_path == "empty":
		push_warning("TrainingScreen: Empty event chain path")
		# await SceneManager.transition_quick(_exit_from_vn_to_strategy)
		_exit_from_vn_to_strategy()
		return
	if not ResourceLoader.exists(chain_path):
		push_error("TrainingScreen: EventChain resource not found: %s" % chain_path)
		dialogue_label.text = "Error: EventChain resource not found"
		_exit_from_vn_to_strategy()
		return
	
	var chain = load(chain_path)
	
	if not chain or not chain is EventChain:
		push_error("TrainingScreen: Failed to load EventChain from: %s" % chain_path)
		dialogue_label.text = "Error: Failed to load EventChain"
		_exit_from_vn_to_strategy()
		return
	if chain.get_dialogue_count() == 0:
		push_warning("TrainingScreen: EventChain '%s' has no dialogues, skipping VN mode" % chain.chain_id)
		dialogue_label.text = "EventChain has no content (add dialogues to the resource)"
		_exit_from_vn_to_strategy()
		return
	
	print("TrainingScreen: Playing EventChain: %s (%d dialogues)" % [chain.chain_id, chain.get_dialogue_count()])
	_set_ui_mode(UIMode.VISUAL_NOVEL)
	
	if vn_controller.load_chain(chain):
		_vn_display_current_dialogue()

func _vn_display_current_dialogue() -> void:
	var dialogue_data = vn_controller.get_current_dialogue_data()
	if dialogue_data.is_empty():
		return
	
	speaker_label.text = dialogue_data.get("speaker_name", "")
	dialogue_label.text = dialogue_data.get("line_spoken", "")
	_update_vn_background(dialogue_data.get("background_id", ""))
	_update_vn_portraits(dialogue_data.get("on_screen_character_ids", []))
	advance_prompt.text = "Click to continue %s" % vn_controller.get_progress_text()

func _update_vn_background(_bg_id: String) -> void:
	pass

func _update_vn_portraits(character_ids: Array) -> void:
	for child in character_container.get_children():
		child.queue_free()
	for char_id in character_ids:
		if char_id is String:
			character_container.add_child(vn_controller.get_or_create_portrait(char_id))

func _on_dialogue_box_clicked(event: InputEvent) -> void:
	if ui_mode == UIMode.VISUAL_NOVEL and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			vn_controller.advance()

func _on_vn_chain_completed() -> void:
	vn_controller.reset()
	await _animate_stat_changes()
	_capture_stat_snapshot()
	
	if event_chain_queue.size() > 0:
		print("[StatAnimation] More chains in queue (%d), playing next..." % event_chain_queue.size())
		_play_next_queued_chain()
	else:
		print("[StatAnimation] All chains completed")
		vn_completed.emit()

func _on_vn_dialogue_advanced(_index: int, _total: int) -> void:
	_vn_display_current_dialogue()

func _on_vn_completed_signal() -> void:
	is_playing_chain = false
	_exit_from_vn_to_strategy()

#endregion

#region Combat System

## Finds an enemy squad by ID from the world's roaming squads
func _find_enemy_squad(squad_id: String) -> StrategicSquad:
	if not game_scenario or not game_scenario.world:
		return null
	for squad in game_scenario.world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad
	return null

## Initiates combat encounter with intermission screen
## Called when player encounters enemies (via patrol, attack activity, or enemy ambush)
func start_encounter(enemy_squad: StrategicSquad, context: Dictionary = {}) -> void:
	print("\n[TrainingScreen] ========================================")
	print("[TrainingScreen] COMBAT ENCOUNTER INITIATED")
	print("[TrainingScreen] Enemy: %s (%d warriors)" % [enemy_squad.squad_name, enemy_squad.get_living_warriors().size()])
	print("[TrainingScreen] ========================================")
	
	is_in_combat_encounter = true
	combat_options = combat_controller.inject_context(
		game_scenario.player_squad,
		enemy_squad,
		battle_viewport,
		combat_overlay
	)
	encounter_timeout_timer = combat_options.get("timeout_seconds", 30.0)
	
	_set_ui_mode(UIMode.COMBAT_INTERMISSION)
	_update_combat_intermission_ui()


#region helpers to dynamically change Encounter UI's

func _update_combat_intermission_ui() -> void:
	var enemy_name = combat_options.get("enemy_name", "Unknown Enemy")
	var enemy_count = combat_options.get("enemy_count", 0)
	var flee_chance = combat_options.get("flee_chance", 0.0) * 100
	var negotiate_chance = combat_options.get("negotiate_chance", 0.0) * 100
	
	_update_combat_intermission_labels(enemy_name, enemy_count, flee_chance, negotiate_chance)
	_update_combat_timer_display()
	
	print("[TrainingScreen] Combat UI updated:")
	print("[TrainingScreen]   Flee chance: %.1f%%" % flee_chance)
	print("[TrainingScreen]   Negotiate chance: %.1f%%" % negotiate_chance)

func _update_combat_intermission_labels(enemy_name, enemy_count, flee_chance, negotiate_chance):	
	combat_enemy_label.text = "⚔️ Encountered: %s (%d warriors)" % [enemy_name, enemy_count]

	encounter_flee_button.text = "🏃 Flee (%.0f%% chance)" % flee_chance
	encounter_flee_button.disabled = not combat_options.get("can_flee", true)
	encounter_flee_button.tooltip_text = "Attempt to escape. Uses SURVIVAL stat.\nSuccess: Escape with morale penalty\nFailure: Forced into combat"

	encounter_negotiate_button.text = "🤝 Negotiate (%.0f%% chance)" % negotiate_chance
	encounter_negotiate_button.disabled = not combat_options.get("can_negotiate", true)
	encounter_negotiate_button.tooltip_text = "Attempt peaceful resolution. Uses DIPLOMACY stat.\nSuccess: Avoid combat entirely\nFailure: Forced into combat"

	encounter_fight_button.text = "⚔️ Fight!"
	encounter_fight_button.disabled = not combat_options.get("can_fight", true)
	encounter_fight_button.tooltip_text = "Engage in tactical combat.\nVictory brings loot and clues.\nDefeat brings casualties."

func _update_combat_timer_display() -> void:
	var max_time = combat_options.get("timeout_seconds", 30.0)
	combat_timer_bar.max_value = max_time
	combat_timer_bar.value = encounter_timeout_timer
	
	# Change color based on remaining time
	if encounter_timeout_timer < 5.0:
		combat_timer_bar.modulate = Color.RED
	elif encounter_timeout_timer < 10.0:
		combat_timer_bar.modulate = Color.YELLOW
	else:
		combat_timer_bar.modulate = Color.WHITE
#endregion

#region _on helpers of different Encounter reactions, goes into _process_encounter_choice
func _on_combat_flee_pressed() -> void:
	if not ui_mode == UIMode.COMBAT_INTERMISSION:
		return
	print("[TrainingScreen] Player chose: FLEE")
	_process_encounter_choice(CombatController.IntermissionChoice.FLEE)

func _on_combat_negotiate_pressed() -> void:
	if not ui_mode == UIMode.COMBAT_INTERMISSION:
		return
	print("[TrainingScreen] Player chose: NEGOTIATE")
	_process_encounter_choice(CombatController.IntermissionChoice.NEGOTIATE)

func _on_combat_fight_pressed() -> void:
	if not ui_mode == UIMode.COMBAT_INTERMISSION:
		return
	print("[TrainingScreen] Player chose: FIGHT")
	_process_encounter_choice(CombatController.IntermissionChoice.FIGHT)

func _on_combat_timeout() -> void:
	if not ui_mode == UIMode.COMBAT_INTERMISSION:
		return
	print("[TrainingScreen] COMBAT TIMEOUT - Auto-fighting!")
	combat_info_label.text = "Time's up! Engaging in combat..."
	_process_encounter_choice(CombatController.IntermissionChoice.FIGHT)
#endregion

func _process_encounter_choice(choice: CombatController.IntermissionChoice) -> void:
	if encounter_flee_button: encounter_flee_button.disabled = true
	if encounter_negotiate_button: encounter_negotiate_button.disabled = true
	if encounter_fight_button: encounter_fight_button.disabled = true
	encounter_timeout_timer = 0
	
	var encounter_result: CombatController.CombatResult = await combat_controller.process_intermission_choice(choice)
	combat_panel.visible = false
	
	print("[TrainingScreen] Combat result received: %s" % encounter_result.to_string() if encounter_result else "null")
	await _handle_encounter_result(encounter_result)

func _on_3d_battle_completed() -> void:
	print("[TrainingScreen] 3D battle visualization completed")
	_cleanup_battle_scene()

func _on_battle_close_pressed() -> void:
	print("[TrainingScreen] User closed battle manually")
	_cleanup_battle_scene()

func _cleanup_battle_scene() -> void:
	for child in battle_viewport.get_children():
		child.queue_free()
	combat_overlay.visible = false

func _handle_encounter_result(result: CombatController.CombatResult) -> void:
	is_in_combat_encounter = false
	
	print("\n[TrainingScreen] ========================================")
	print("[TrainingScreen] COMBAT RESOLVED")
	print("[TrainingScreen] %s" % result.to_string())
	print("[TrainingScreen] ========================================")
	
	# Capture morale before changes for animation
	var morale_before = game_scenario.player_squad.get_morale()
	
	# Apply morale changes to squad
	if result.morale_change != 0:
		game_scenario.player_squad.modify_aggregate_morale(result.morale_change)
		print("[TrainingScreen] Applied morale change: %.1f" % result.morale_change)
	
	# Handle casualties
	for casualty_id in result.player_casualties:
		var warrior = game_scenario.player_squad.get_warrior_by_id(casualty_id)
		if warrior:
			print("[TrainingScreen] Casualty: %s" % warrior.warrior_name)
	
	# Handle loot if victory
	if result.loot:
		print("[TrainingScreen] Loot collected: %s" % [result.loot])
		_apply_combat_loot(result.loot)
	
	# Handle clues if victory
	if result.clues_dropped.size() > 0:
		var current_location = game_scenario.current_location
		for clue in result.clues_dropped:
			current_location.add_clue(clue)
			print("[TrainingScreen] Clue dropped: %s" % clue.clue_name)
	
	# Show combat result with animated morale bar overlay
	await _show_combat_result_overlay(result, morale_before)
	
	_exit_combat_to_strategy()
	
	# Emit signal AFTER cleanup so _execute_activity_with_object can continue
	encounter_resolved.emit(result)

## Shows the battle result with morale bar overlaid on the 3D battle scene
func _show_combat_result_overlay(result: CombatController.CombatResult, morale_before: float) -> void:
	combat_panel.visible = false
	
	# Show the combat overlay (3D battle scene is in BattleViewport)
	combat_overlay.visible = true
	
	# Store original parent and position of morale panel (contains the morale bar)
	var original_parent = morale_panel.get_parent()
	var original_index = morale_panel.get_index()
	
	# Create a container for the overlay UI elements (on top of 3D scene)
	var overlay_container = Control.new()
	overlay_container.name = "BattleSummaryOverlay"
	overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_overlay.add_child(overlay_container)
	
	# Add result label in center of screen
	var result_label = _create_result_label(result)
	overlay_container.add_child(result_label)
	
	# Reparent the morale panel (which contains morale bar) to the overlay
	original_parent.remove_child(morale_panel)
	overlay_container.add_child(morale_panel)
	
	# Position morale panel at the TOP (same position as strategy UI)
	morale_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	morale_panel.anchor_left = 0.1
	morale_panel.anchor_right = 0.9
	morale_panel.anchor_top = 0.02
	morale_panel.anchor_bottom = 0.08
	morale_panel.offset_left = 0
	morale_panel.offset_right = 0
	morale_panel.offset_top = 0
	morale_panel.offset_bottom = 0
	morale_panel.visible = true
	morale_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	# Set morale bar to "before" value
	morale_bar.value = morale_before
	morale_bar.visible = true
	
	# Wait for user to see the result
	await get_tree().create_timer(0.5).timeout
	
	# Animate morale bar change
	var morale_after = game_scenario.player_squad.get_morale()
	var tween = create_tween()
	tween.tween_property(morale_bar, "value", morale_after, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	
	# Spawn floating delta label on the overlay
	if abs(result.morale_change) >= 0.1:
		_spawn_morale_delta_label_on_overlay(result.morale_change, overlay_container)
	
	# Brief pause to read
	await get_tree().create_timer(1.2).timeout
	
	# Reparent morale panel back to original location
	overlay_container.remove_child(morale_panel)
	original_parent.add_child(morale_panel)
	original_parent.move_child(morale_panel, original_index)
	
	# Reset morale panel anchors to fill horizontally in its container
	morale_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	morale_panel.anchor_left = 0
	morale_panel.anchor_right = 1
	morale_panel.anchor_top = 0
	morale_panel.anchor_bottom = 0
	morale_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Clean up overlay UI container
	overlay_container.queue_free()
	
	# Clean up battle scene from viewport (was kept visible for summary)
	for child in battle_viewport.get_children():
		child.queue_free()
	combat_overlay.visible = false

## Creates the result label (Victory/Defeat/Fled/Negotiated)
func _create_result_label(result: CombatController.CombatResult) -> Label:
	var result_label = Label.new()
	result_label.name = "ResultLabel"
	result_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	result_label.anchor_top = 0.15
	result_label.anchor_bottom = 0.25
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 48)
	result_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	result_label.add_theme_constant_override("shadow_offset_x", 3)
	result_label.add_theme_constant_override("shadow_offset_y", 3)
	
	if result.victory:
		result_label.text = "✓ VICTORY!"
		result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	elif result.fled:
		result_label.text = "🏃 Escaped!"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	elif result.negotiated:
		result_label.text = "🤝 Negotiated!"
		result_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	else:
		result_label.text = "✗ DEFEAT!"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	
	return result_label

## Spawns a floating morale delta label on the combat overlay
func _spawn_morale_delta_label_on_overlay(delta_value: float, parent: Control) -> void:
	var delta_label = Label.new()
	parent.add_child(delta_label)
	
	delta_label.text = "%+.1f Morale" % delta_value
	delta_label.add_theme_font_size_override("font_size", 28)
	delta_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	delta_label.add_theme_constant_override("shadow_offset_x", 2)
	delta_label.add_theme_constant_override("shadow_offset_y", 2)
	
	if delta_value >= 0:
		delta_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		delta_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	
	# Position below the morale bar (which is now at top)
	delta_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	delta_label.anchor_top = 0.10
	delta_label.anchor_bottom = 0.14
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Animate float down and fade
	var tween = create_tween().set_parallel(true)
	tween.tween_property(delta_label, "anchor_top", 0.16, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(delta_label, "anchor_bottom", 0.20, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(delta_label, "modulate:a", 0.0, 0.8).set_delay(0.4)



func _apply_combat_loot(loot: Dictionary) -> void:
	var squad = game_scenario.player_squad
	if loot.has("money"):
		squad.money += loot.money
		print("[TrainingScreen] Gained money: %.0f" % loot.money)
	if loot.has("food"):
		squad.food += int(loot.food)
		print("[TrainingScreen] Gained food: %d" % int(loot.food))

func _exit_combat_to_strategy() -> void:
	print("[TrainingScreen] Exiting combat, returning to strategy mode")
	is_in_combat_encounter = false
	encounter_timeout_timer = 0
	combat_options = {}
	_set_ui_mode(UIMode.STRATEGY)
	_update_ui()
	# Note: encounter_resolved is emitted in _handle_encounter_result, not here

func _show_combat_ui() -> void:
	# Hide strategy elements
	action_buttons.visible = false
	stats_panel.modulate.a = 0.5
	dialogue_box.visible = false
	character_container.visible = false
	
	# Show combat panel
	combat_panel.visible = true

#endregion
