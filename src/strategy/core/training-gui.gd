extends Control

## Strategic Campaign UI Screen with integrated Visual Novel system
## Displays squad state, world info, and allows activity selection
## Seamlessly transitions to VN mode for EventChain playback

# const StatChangeAnimator = preload("res://src/strategy/ui/stat_change_animator.gd")

enum UIMode {
	STRATEGY,      # Normal activity buttons visible
	VISUAL_NOVEL   # VN elements visible, strategy UI dimmed
}

@onready var turn_label: Label = $PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderMargin/HeaderContent/TurnStatus
@onready var location_label: Label = $PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderMargin/HeaderContent/QualifierStatus
@onready var end_button: Button = $PanelContainer/MainVBox/StatusArea/EndButton
@onready var morale_bar: ProgressBar = $PanelContainer/MainVBox/StatusArea/StatusPanel/StatusMargin/StatusContent/MoraleSection/StaminaBar
@onready var condition_label: Label = $PanelContainer/MainVBox/StatusArea/StatusPanel/StatusMargin/StatusContent/ConditionStatus/ConditionMargin/ConditionLabel

@onready var main_background: TextureRect = $PanelContainer/MainBackground
@onready var foreground: TextureRect = $PanelContainer/Foreground
@onready var character_container: HBoxContainer = $PanelContainer/MainVBox/MainScreenArea/CharacterContainer
# @onready var hint_icon: TextureRect = $PanelContainer/MainVBox/MainScreenArea/HintIcon
@onready var dialogue_box: PanelContainer = $PanelContainer/MainVBox/MainScreenArea/DialogueBox
@onready var speaker_label: Label = $PanelContainer/MainVBox/MainScreenArea/DialogueBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_label: Label = $PanelContainer/MainVBox/MainScreenArea/DialogueBox/MarginContainer/VBoxContainer/DialogueLabel
@onready var advance_prompt: Label = $PanelContainer/MainVBox/MainScreenArea/DialogueBox/AdvancePrompt

@onready var stats_panel: PanelContainer = $PanelContainer/MainVBox/StatsPanel
@onready var money_label: Label = $PanelContainer/MainVBox/StatsPanel/StatsMargin/StatsGrid/SpeedLabel
@onready var food_label: Label = $PanelContainer/MainVBox/StatsPanel/StatsMargin/StatsGrid/StaminaLabel
@onready var tools_label: Label = $PanelContainer/MainVBox/StatsPanel/StatsMargin/StatsGrid/PowerLabel
@onready var karma_label: Label = $PanelContainer/MainVBox/StatsPanel/StatsMargin/StatsGrid/GutsLabel
@onready var warriors_label: Label = $PanelContainer/MainVBox/StatsPanel/StatsMargin/StatsGrid/WisdomLabel
@onready var end_prog_label: Label = $PanelContainer/MainVBox/StatsPanel/StatsMargin/StatsGrid/SkillPtLabel

@onready var action_buttons: PanelContainer = $PanelContainer/MainVBox/ActionButtons
@onready var rest_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/TrainingButton
@onready var drill_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/RestButton
@onready var patrol_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/SkillButton
@onready var investigate_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/NurseButton
@onready var hold_mass_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/OutingButton
@onready var travel_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/RaceButton

@onready var skip_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/SkipButton
@onready var short_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/ShortButton

var game_scenario: GameScenario
var current_activity_result: ActivityResult = null
var ui_mode: UIMode = UIMode.STRATEGY
var portrait_cache: Dictionary = {}
var event_chain_queue: Array[String] = []
var is_playing_chain: bool = false

var vn_current_chain: EventChain
var vn_current_index: int = 0
var vn_character_ids_in_chain: Array[String] = []

var stat_snapshot: Dictionary = {}
var stat_animator: StatChangeAnimator = StatChangeAnimator.new()

func _ready() -> void:
	_initialize_demo_scenario()
	_connect_signals()
	_setup_dialogue_box_input()
	_set_ui_mode(UIMode.STRATEGY)
	_update_ui()

#region Initialization

func _initialize_demo_scenario() -> void:
	var test_world = World.new()
	test_world.turn_count = 0
	test_world.end_progression = 0.0
	
	var city_location = Location.new()
	city_location.location_id = "test_city"
	city_location.location_name = "Ravenna"
	city_location.type = StrategyTypes.LocationType.CITY
	city_location.development = 75
	city_location.stability = 85.0
	city_location.add_activity_type(StrategyTypes.ActivityType.REST)
	city_location.add_activity_type(StrategyTypes.ActivityType.DRILL)
	city_location.add_activity_type(StrategyTypes.ActivityType.PATROL)
	city_location.add_activity_type(StrategyTypes.ActivityType.INVESTIGATE)
	city_location.add_activity_type(StrategyTypes.ActivityType.HOLD_MASS)
	
	var village_location = Location.new()
	village_location.location_id = "test_village"
	village_location.location_name = "Countryside"
	village_location.type = StrategyTypes.LocationType.VILLAGE
	village_location.development = 30
	village_location.stability = 60.0
	village_location.add_activity_type(StrategyTypes.ActivityType.REST)
	village_location.add_activity_type(StrategyTypes.ActivityType.DRILL)
	village_location.add_activity_type(StrategyTypes.ActivityType.HOLD_MASS)
	
	city_location.add_connection(village_location.location_id)
	village_location.add_connection(city_location.location_id)
	
	test_world.add_location(city_location)
	test_world.add_location(village_location)
	test_world.build_travel_graph()
	
	var test_squad = StrategicSquad.new()
	test_squad.squad_id = "player_squad"
	test_squad.squad_name = "The Condors"
	test_squad.money = 150.0
	test_squad.food = 20
	test_squad.travel_tools = 8
	test_squad.karma = 10.0
	test_squad.set_location(city_location.location_id)
	
	for i in range(5):
		var warrior = Warrior.new()
		warrior.warrior_id = "warrior_%d" % i
		warrior.warrior_name = ["Marcus", "Giovanni", "Alessandro", "Francesco", "Lorenzo"][i]
		warrior.morale = randf_range(70.0, 100.0)
		warrior.religion = [
			StrategyTypes.Religion.CATHOLIC,
			StrategyTypes.Religion.CATHOLIC,
			StrategyTypes.Religion.PROTESTANT,
			StrategyTypes.Religion.CATHOLIC,
			StrategyTypes.Religion.MUSLIM
		][i]
		
		warrior.combat_stats = EntityBaseStats.new()
		warrior.combat_stats.strength = randi_range(5, 10)
		warrior.combat_stats.dex = randi_range(5, 10)
		warrior.combat_stats.endurance = randi_range(5, 10)
		
		warrior.set_attribute(StrategyTypes.WarriorAttribute.PERCEPTION, randi_range(30, 70))
		warrior.set_attribute(StrategyTypes.WarriorAttribute.LEADERSHIP, randi_range(20, 60))
		warrior.logic_type = "frontline" if i < 3 else "archer"
		
		test_squad.add_warrior(warrior)
	
	test_squad.update_aggregate_morale()
	
	# Load test events
	var test_events: Array[GameEvent] = []
	test_events.append(load("res://resources/generic-events/faction-attention.tres"))
	test_events.append(load("res://resources/generic-events/religious-vision.tres"))
	test_events.append(load("res://resources/generic-events/mysterious-stranger.tres"))
	
	# Load generic activities
	var test_activities: Array[Activity] = []
	test_activities.append(load("res://resources/generic-activities/rest/rest.tres"))
	test_activities.append(load("res://resources/generic-activities/drill.tres"))
	test_activities.append(load("res://resources/generic-activities/patrol.tres"))
	test_activities.append(load("res://resources/generic-activities/investigate.tres"))
	test_activities.append(load("res://resources/generic-activities/hold-mass.tres"))
	
	var scenario_config = {
		"world": test_world,
		"player_squad": test_squad,
		"starting_location_id": city_location.location_id,
		"factions": [],
		"events": test_events,
		"activities": test_activities,
		"endings": []
	}
	
	game_scenario = GameScenario.new(scenario_config)
	
	print("Demo scenario initialized: %s in %s" % [test_squad.squad_name, city_location.location_name])

func _connect_signals() -> void:
	rest_button.pressed.connect(_on_rest_pressed)
	drill_button.pressed.connect(_on_drill_pressed)
	patrol_button.pressed.connect(_on_patrol_pressed)
	investigate_button.pressed.connect(_on_investigate_pressed)
	hold_mass_button.pressed.connect(_on_hold_mass_pressed)
	travel_button.pressed.connect(_on_travel_pressed)
	
	end_button.pressed.connect(_on_end_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	short_button.pressed.connect(_on_short_pressed)
	
	if game_scenario:
		game_scenario.activity_executed.connect(_on_activity_executed)
		game_scenario.turn_advanced.connect(_on_turn_advanced)
		game_scenario.triggerable_fired.connect(_on_triggerable_fired)

func _setup_dialogue_box_input() -> void:
	if dialogue_box:
		dialogue_box.gui_input.connect(_on_dialogue_box_clicked)

#endregion

#region UI Helpers

func _update_ui() -> void:
	if not game_scenario:
		return
	
	var squad = game_scenario.player_squad
	var world = game_scenario.world
	var location = game_scenario.current_location
	
	turn_label.text = "Turn %d" % world.turn_count
	location_label.text = "%s (%s) - Dev:%d Stab:%.0f" % [
		location.location_name if location else "Unknown",
		_location_type_to_string(location.type) if location else "",
		location.development if location else 0,
		location.stability if location else 0.0
	]
	
	morale_bar.value = squad.get_morale()
	morale_bar.max_value = 100.0
	condition_label.text = _get_morale_condition(squad.get_morale())
	
	money_label.text = "Money: %.1f" % squad.money
	food_label.text = "Food: %d" % squad.food
	tools_label.text = "Tools: %d" % squad.travel_tools
	karma_label.text = "Karma: %.1f" % squad.karma
	warriors_label.text = "Warriors: %d" % squad.get_living_warriors().size()
	end_prog_label.text = "End Prog: %.1f" % world.end_progression
	
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
	travel_button.disabled = true
	travel_button.tooltip_text = "Travel system not yet implemented in this demo"

func _get_activity(activity_type: StrategyTypes.ActivityType) -> Activity:
	# Get activity from triggerable manager by activity_type
	if not game_scenario or not game_scenario.triggerable_manager:
		return null
	
	for triggerable in game_scenario.triggerable_manager.registered_triggerables:
		if triggerable is Activity and (triggerable as Activity).activity_type == activity_type:
			return triggerable as Activity
	
	return null

func _get_activity_tooltip(activity_type: StrategyTypes.ActivityType) -> String:
	var activity = _get_activity(activity_type)
	if not activity:
		return "Unknown activity"
	return "%s\n\nTime Cost: %d turn(s)" % [activity.description, activity.time_cost]

#endregion

#region Activity Execution

func _execute_activity(activity_type: StrategyTypes.ActivityType) -> void:
	var activity = _get_activity(activity_type)
	if not activity:
		dialogue_label.text = "Activity not found or not registered in scenario."
		return
	
	current_activity_result = null
	
	# Capture stat snapshot before executing
	_capture_stat_snapshot()
	
	var turn_summary = game_scenario.execute_turn(activity)
	
	if turn_summary.has("error"):
		dialogue_label.text = "Error: %s" % turn_summary["error"]
		return
	
	print("\n=== Turn %d Summary ===" % game_scenario.world.turn_count)
	print("Activity: %s" % turn_summary["activity"])
	print(turn_summary)
	
	# Queue all event chains from pre-triggerables, activity, and post-triggerables
	var pre_triggerables: Array[GenericResult] = turn_summary.get("pre_triggerables", [])
	_queue_triggerable_chains(pre_triggerables)
	
	# Queue activity event chain from turn_summary
	var activity_result_data = turn_summary.get("activity_result", {})
	var activity_event_chain = activity_result_data.get("event_chain_path", "")
	if not activity_event_chain.is_empty():
		_queue_event_chain(activity_event_chain)
	
	var post_triggers: Array[GenericResult] = turn_summary.get("post_triggerables", [])
	_queue_triggerable_chains(post_triggers)
	
	# Play queued chains or update UI
	if event_chain_queue.is_empty():
		print("No event chains to play, animating stat changes...")
		await _animate_stat_changes()
		_update_ui()
	else:
		print("Starting event chain playback...")
		_play_next_queued_chain()

func _queue_triggerable_chains(results_list: Array[GenericResult]) -> void:
	for result in results_list:
		if result is GenericResult and result.has_event_chain():
			_queue_event_chain(result.event_chain_path)
		else:
			assert(false)

#endregion

#region Stat Animation

func _capture_stat_snapshot() -> void:
	if not game_scenario:
		print("[StatAnimation] Cannot capture snapshot - no game_scenario")
		return
	
	var squad = game_scenario.player_squad
	var world = game_scenario.world
	
	stat_snapshot = {
		"money": squad.money,
		"food": float(squad.food),
		"tools": float(squad.travel_tools),
		"karma": squad.karma,
		"warriors": float(squad.get_living_warriors().size()),
		"morale": squad.get_morale(),
		"end_progression": world.end_progression
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
	var world = game_scenario.world
	
	var current_stats := {
		"money": squad.money,
		"food": float(squad.food),
		"tools": float(squad.travel_tools),
		"karma": squad.karma,
		"warriors": float(squad.get_living_warriors().size()),
		"morale": squad.get_morale(),
		"end_progression": world.end_progression
	}
	print("[StatAnimation] Current stats: ", current_stats)
	
	var deltas := {}
	for stat_name in stat_snapshot:
		var old_value = stat_snapshot[stat_name]
		var new_value = current_stats[stat_name]
		var delta = new_value - old_value
		if abs(delta) >= 0.01:  # Only include meaningful changes
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
		"tools": tools_label,
		"karma": karma_label,
		"warriors": warriors_label,
		"end_progression": end_prog_label,
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
	dialogue_label.text = "Travel system not yet implemented in this demo."

func _on_end_pressed() -> void:
	dialogue_label.text = "Game ended. Final turn: %d" % game_scenario.world.turn_count

func _on_skip_pressed() -> void:
	for i in 5:
		_execute_activity(StrategyTypes.ActivityType.REST)

func _on_short_pressed() -> void:
	var summary_text = "=== Campaign Summary ===\n"
	summary_text += "Squad: %s\n" % game_scenario.player_squad.squad_name
	summary_text += "Turn: %d\n" % game_scenario.world.turn_count
	summary_text += "Location: %s\n" % game_scenario.current_location.location_name
	summary_text += "Warriors: %d\n" % game_scenario.player_squad.get_living_warriors().size()
	summary_text += "Morale: %.1f\n" % game_scenario.player_squad.get_morale()
	summary_text += "Money: %.1f\n" % game_scenario.player_squad.money
	summary_text += "Food: %d\n" % game_scenario.player_squad.food
	
	dialogue_label.text = summary_text

#endregion

#region Game Scenario Signal Handlers

func _on_activity_executed(activity: Activity, result: ActivityResult) -> void:
	current_activity_result = result
	print("Activity executed: %s" % activity.trigger_name)

func _on_turn_advanced(turn: int) -> void:
	print("Turn advanced to: %d" % turn)

func _on_triggerable_fired(triggerable: Triggerable, _result: Variant) -> void:
	print("TrainingScreen: Triggerable fired: %s (%s)" % [triggerable.trigger_name, triggerable.get_class()])

#endregion

#region Event Chain Management

func _queue_event_chain(chain_path: String) -> void:
	event_chain_queue.append(chain_path)
	print("TrainingScreen: Queued event chain: %s (queue size: %d)" % [chain_path, event_chain_queue.size()])
	# Don't auto-play here - let the caller decide when to start playback

func _play_next_queued_chain() -> void:
	if event_chain_queue.is_empty():
		is_playing_chain = false
		_set_ui_mode(UIMode.STRATEGY)
		_update_ui()
		return

	is_playing_chain = true
	var chain_path = event_chain_queue.pop_front()
	_play_event_chain(chain_path)

#endregion

#region Visual Novel Functions

func _set_ui_mode(mode: UIMode) -> void:
	ui_mode = mode
	
	match mode:
		UIMode.STRATEGY:
			dialogue_box.visible = false
			_show_strategy_ui()
		UIMode.VISUAL_NOVEL:
			_show_vn_ui()
			dialogue_box.visible = true

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
	if chain_path.is_empty():
		push_warning("TrainingScreen: Empty event chain path")
		_set_ui_mode(UIMode.STRATEGY)
		_update_ui()
		return
	
	if not ResourceLoader.exists(chain_path):
		push_error("TrainingScreen: EventChain resource not found: %s" % chain_path)
		dialogue_label.text = "Error: EventChain resource not found"
		_set_ui_mode(UIMode.STRATEGY)
		_update_ui()
		return
	
	var chain = load(chain_path)
	if not chain or not chain is EventChain:
		push_error("TrainingScreen: Failed to load EventChain from: %s" % chain_path)
		dialogue_label.text = "Error: Failed to load EventChain"
		_set_ui_mode(UIMode.STRATEGY)
		_update_ui()
		return
	
	if chain.get_dialogue_count() == 0:
		push_warning("TrainingScreen: EventChain '%s' has no dialogues, skipping VN mode" % chain.chain_id)
		dialogue_label.text = "EventChain has no content (add dialogues to the resource)"
		_set_ui_mode(UIMode.STRATEGY)
		_update_ui()
		return
	
	print("TrainingScreen: Playing EventChain: %s (%d dialogues)" % [chain.chain_id, chain.get_dialogue_count()])
	_set_ui_mode(UIMode.VISUAL_NOVEL)
	_vn_load_chain(chain)

func _vn_display_current_dialogue() -> void:
	var dialogue_data = _vn_get_current_dialogue_data()
	if dialogue_data.is_empty():
		return
	
	speaker_label.text = dialogue_data.get("speaker_name", "")
	dialogue_label.text = dialogue_data.get("line_spoken", "")
	_update_vn_background(dialogue_data.get("background_id", ""))
	_update_vn_portraits(dialogue_data.get("on_screen_character_ids", []))
	advance_prompt.text = "Click to continue (%d/%d)" % [
		dialogue_data.get("index", 0) + 1,
		dialogue_data.get("total", 0)
	]

func _update_vn_background(_bg_id: String) -> void:
	pass

func _update_vn_portraits(character_ids: Array) -> void:
	for child in character_container.get_children():
		child.queue_free()
	for char_id in character_ids:
		if char_id is String:
			character_container.add_child(_get_or_create_portrait(char_id))

func _get_or_create_portrait(character_id: String) -> Control:
	if portrait_cache.has(character_id):
		return portrait_cache[character_id].duplicate()
	
	var portrait = ColorRect.new()
	portrait.custom_minimum_size = Vector2(150, 250)
	var hash_val = character_id.hash()
	portrait.color = Color(
		float(hash_val % 100) / 100.0,
		float(int(hash_val / 100.0) % 100) / 100.0,
		float(int(hash_val / 10000.0) % 100) / 100.0, 1.0)
	portrait_cache[character_id] = portrait
	return portrait.duplicate()

func _on_dialogue_box_clicked(event: InputEvent) -> void:
	if ui_mode == UIMode.VISUAL_NOVEL and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_vn_advance()

func _vn_load_chain(chain: EventChain) -> void:
	if not chain:
		push_error("Cannot load null EventChain")
		return
	
	if chain.get_dialogue_count() == 0:
		push_warning("EventChain '%s' has no dialogues, completing immediately" % chain.chain_id)
		vn_current_chain = null
		_vn_on_chain_completed()
		return
	
	vn_current_chain = chain
	vn_current_index = 0
	vn_character_ids_in_chain = chain.get_all_character_ids()
	if vn_current_chain.get_dialogue_count() > 0:
		_vn_display_current_dialogue()

func _vn_advance() -> void:
	if not vn_current_chain:
		push_warning("No chain loaded, cannot advance")
		return
	
	if _vn_is_complete():
		push_warning("Chain already complete")
		_vn_on_chain_completed()
		return
	
	vn_current_index += 1
	
	if _vn_is_complete():
		print("EventChain '%s' completed (showed %d/%d dialogues)" % [vn_current_chain.chain_id, vn_current_index, vn_current_chain.get_dialogue_count()])
		_vn_on_chain_completed()
	else:
		print("Advanced to dialogue %d/%d" % [vn_current_index + 1, vn_current_chain.get_dialogue_count()])
		_vn_display_current_dialogue()

func _vn_get_current_dialogue_data() -> Dictionary:
	if not vn_current_chain or vn_current_index >= vn_current_chain.get_dialogue_count():
		return {}
	
	var dialogue: Dialogue = vn_current_chain.dialogues[vn_current_index]
	return {
		"speaker_name": dialogue.speaker_name,
		"line_spoken": dialogue.line_spoken,
		"on_screen_character_ids": dialogue.on_screen_character_ids,
		"background_id": dialogue.background_id,
		"triggers": dialogue.triggers,
		"index": vn_current_index,
		"total": vn_current_chain.get_dialogue_count()
	}

func _vn_is_complete() -> bool:
	if not vn_current_chain:
		return true
	return vn_current_index >= vn_current_chain.get_dialogue_count()

func _vn_reset() -> void:
	vn_current_chain = null
	vn_current_index = 0
	vn_character_ids_in_chain.clear()

func _vn_on_chain_completed() -> void:
	_vn_reset()
	if event_chain_queue.size() > 0:
		print("[StatAnimation] More chains in queue (%d), playing next..." % event_chain_queue.size())
		_play_next_queued_chain()
	else:
		print("[StatAnimation] All chains completed, triggering stat animation...")
		is_playing_chain = false
		# Animate stat changes before returning to strategy mode
		await _animate_stat_changes()
		print("[StatAnimation] Returning to strategy UI mode")
		_set_ui_mode(UIMode.STRATEGY)
		dialogue_label.text = "All event chains completed. Choose your next action."
		_update_ui()

#endregion
