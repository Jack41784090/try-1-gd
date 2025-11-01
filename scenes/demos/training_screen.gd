extends Control

## Strategic Campaign UI Screen with integrated Visual Novel system
## Displays squad state, world info, and allows activity selection
## Seamlessly transitions to VN mode for EventChain playback

const VisualNovelComponentClass = preload("res://src/strategy/ui/visual_novel_component.gd")

enum UIMode {
	STRATEGY,      # Normal activity buttons visible
	VISUAL_NOVEL   # VN elements visible, strategy UI dimmed
}

@onready var turn_label: Label = $PanelContainer/MainVBox/StatusHeader/TurnStatus
@onready var location_label: Label = $PanelContainer/MainVBox/StatusHeader/QualifierStatus
@onready var end_button: Button = $PanelContainer/MainVBox/StatusArea/EndButton
@onready var morale_bar: ProgressBar = $PanelContainer/MainVBox/StatusArea/StaminaBar
@onready var condition_label: Label = $PanelContainer/MainVBox/StatusArea/ConditionStatus/ConditionLabel

@onready var main_background: TextureRect = $PanelContainer/MainBackground
@onready var foreground: TextureRect = $PanelContainer/Foreground
@onready var character_container: HBoxContainer = $PanelContainer/MainVBox/MainScreenArea/CharacterContainer
@onready var hint_icon: TextureRect = $PanelContainer/MainVBox/MainScreenArea/HintIcon
@onready var dialogue_box: PanelContainer = $PanelContainer/MainVBox/MainScreenArea/DialogueBox
@onready var speaker_label: Label = $PanelContainer/MainVBox/MainScreenArea/DialogueBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_label: Label = $PanelContainer/MainVBox/MainScreenArea/DialogueBox/MarginContainer/VBoxContainer/DialogueLabel
@onready var advance_prompt: Label = $PanelContainer/MainVBox/MainScreenArea/DialogueBox/AdvancePrompt

@onready var stats_panel: GridContainer = $PanelContainer/MainVBox/StatsPanel
@onready var money_label: Label = $PanelContainer/MainVBox/StatsPanel/SpeedLabel
@onready var food_label: Label = $PanelContainer/MainVBox/StatsPanel/StaminaLabel
@onready var tools_label: Label = $PanelContainer/MainVBox/StatsPanel/PowerLabel
@onready var karma_label: Label = $PanelContainer/MainVBox/StatsPanel/GutsLabel
@onready var warriors_label: Label = $PanelContainer/MainVBox/StatsPanel/WisdomLabel
@onready var end_prog_label: Label = $PanelContainer/MainVBox/StatsPanel/SkillPtLabel

@onready var action_buttons: HBoxContainer = $PanelContainer/MainVBox/ActionButtons
@onready var rest_button: Button = $PanelContainer/MainVBox/ActionButtons/TrainingButton
@onready var drill_button: Button = $PanelContainer/MainVBox/ActionButtons/RestButton
@onready var patrol_button: Button = $PanelContainer/MainVBox/ActionButtons/SkillButton
@onready var investigate_button: Button = $PanelContainer/MainVBox/ActionButtons/NurseButton
@onready var hold_mass_button: Button = $PanelContainer/MainVBox/ActionButtons/OutingButton
@onready var travel_button: Button = $PanelContainer/MainVBox/ActionButtons/RaceButton

@onready var skip_button: Button = $PanelContainer/MainVBox/BottomNavBar/SkipButton
@onready var short_button: Button = $PanelContainer/MainVBox/BottomNavBar/ShortButton

var game_scenario: GameScenario
var current_activity_result: StrategyTypes.ActivityResult = null
var vn_component: VisualNovelComponentClass
var ui_mode: UIMode = UIMode.STRATEGY
var portrait_cache: Dictionary = {}
var event_chain_queue: Array[String] = []
var is_playing_chain: bool = false

func _ready() -> void:
	vn_component = VisualNovelComponentClass.new()
	_initialize_demo_scenario()
	_connect_signals()
	_setup_dialogue_box_input()
	_set_ui_mode(UIMode.STRATEGY)
	_update_ui()

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
	
	var scenario_config = {
		"world": test_world,
		"player_squad": test_squad,
		"starting_location_id": city_location.location_id,
		"factions": [],
		"events": test_events,
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
	
	if vn_component:
		vn_component.display_updated.connect(_on_vn_display_updated)
		vn_component.chain_completed.connect(_on_vn_chain_completed)

func _setup_dialogue_box_input() -> void:
	if dialogue_box:
		dialogue_box.gui_input.connect(_on_dialogue_box_clicked)

func _update_ui() -> void:
	if not game_scenario:
		return
	
	var squad = game_scenario.player_squad
	var world = game_scenario.world
	var location = game_scenario.current_location
	
	turn_label.text = "Turn %d" % world.turn_count
	
	if location:
		location_label.text = "%s (%s) - Dev:%d Stab:%.0f" % [
			location.location_name,
			_location_type_to_string(location.type),
			location.development,
			location.stability
		]
	else:
		location_label.text = "Unknown Location"
	
	morale_bar.value = squad.get_morale()
	morale_bar.max_value = 100.0
	
	var morale_condition = _get_morale_condition(squad.get_morale())
	condition_label.text = morale_condition
	
	money_label.text = "Money: %.1f" % squad.money
	food_label.text = "Food: %d" % squad.food
	tools_label.text = "Tools: %d" % squad.travel_tools
	karma_label.text = "Karma: %.1f" % squad.karma
	warriors_label.text = "Warriors: %d" % squad.get_living_warriors().size()
	end_prog_label.text = "End Prog: %.1f" % world.end_progression
	
	_update_activity_buttons()
	
	if current_activity_result:
		_display_activity_result(current_activity_result)
	else:
		dialogue_label.text = "Choose an activity to continue your campaign."

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

func _get_activity_tooltip(activity_type: StrategyTypes.ActivityType) -> String:
	var activity = Activity.create_activity(activity_type)
	if not activity:
		return "Unknown activity"
	
	var tooltip = activity.description + "\n\n"
	tooltip += "Time Cost: %d turn(s)\n" % activity.time_cost
	
	if activity.food_cost > 0:
		tooltip += "Food Cost: %d\n" % activity.food_cost
	if activity.money_cost > 0:
		tooltip += "Money Cost: %.1f\n" % activity.money_cost
	if activity.travel_tools_cost > 0:
		tooltip += "Tools Cost: %d\n" % activity.travel_tools_cost
	
	if activity.location_requirements.size() > 0:
		tooltip += "Requires: "
		for loc_type in activity.location_requirements:
			tooltip += _location_type_to_string(loc_type) + " "
	
	return tooltip

func _execute_activity(activity_type: StrategyTypes.ActivityType) -> void:
	var activity = Activity.create_activity(activity_type)
	
	if not activity.can_execute(game_scenario.player_squad, game_scenario.current_location):
		var reason = activity.get_cannot_execute_reason(game_scenario.player_squad, game_scenario.current_location)
		dialogue_label.text = "Cannot execute %s: %s" % [activity.activity_name, reason]
		return
	
	# Clear previous activity result
	current_activity_result = null
	
	var turn_summary = game_scenario.execute_turn(activity)
	
	if turn_summary.has("error"):
		dialogue_label.text = "Error: %s" % turn_summary["error"]
		return
	
	print("\n=== Turn %d Summary ===" % game_scenario.world.turn_count)
	print("Activity: %s" % turn_summary["activity"])
	print(turn_summary)
	
	# Queue all event chains from pre-triggerables, activity, and post-triggerables
	_queue_triggerable_chains(turn_summary.get("pre_triggerables", []))
	
	if current_activity_result and current_activity_result.has_event_chain():
		_queue_event_chain(current_activity_result.event_chain_path)
	
	_queue_triggerable_chains(turn_summary.get("post_triggerables", []))
	
	# Play queued chains or update UI
	if event_chain_queue.is_empty():
		_update_ui()
	else:
		_play_next_queued_chain()

func _queue_triggerable_chains(triggerable_list: Array) -> void:
	for triggerable_data in triggerable_list:
		var result = triggerable_data.get("result")
		if result is StrategyTypes.GenericResult and result.has_event_chain():
			_queue_event_chain(result.event_chain_path)

func _display_activity_result(result: StrategyTypes.ActivityResult) -> void:
	var display_text = ""
	
	if result.squad_stat_changes.size() > 0:
		display_text += "Squad Changes:\n"
		for stat in result.squad_stat_changes:
			var value = result.squad_stat_changes[stat]
			display_text += "  %s: %+.1f\n" % [stat, value]
	
	if result.triggered_event_ids.size() > 0:
		display_text += "\nEvents Triggered: %s" % str(result.triggered_event_ids)
	
	dialogue_label.text = display_text.strip_edges()

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

func _on_activity_executed(activity: Activity, result: StrategyTypes.ActivityResult) -> void:
	current_activity_result = result
	print("Activity executed: %s" % activity.activity_name)

func _on_turn_advanced(turn: int) -> void:
	print("Turn advanced to: %d" % turn)

func _on_triggerable_fired(triggerable: Triggerable, _result: Variant) -> void:
	print("TrainingScreen: Triggerable fired: %s (%s)" % [triggerable.trigger_name, triggerable.get_class()])
	# Note: EventChains are queued from turn_summary in _execute_activity(), not here
	# This prevents duplicate queuing and timing issues

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

## Visual Novel Mode Functions

func _set_ui_mode(mode: UIMode) -> void:
	ui_mode = mode
	
	match mode:
		UIMode.STRATEGY:
			_show_strategy_ui()
		UIMode.VISUAL_NOVEL:
			_show_vn_ui()

func _show_strategy_ui() -> void:
	# Show strategy elements
	if action_buttons:
		action_buttons.visible = true
	if stats_panel:
		stats_panel.modulate.a = 1.0
	
	# Hide VN elements
	if character_container:
		character_container.visible = false
	if speaker_label:
		speaker_label.visible = false
	if advance_prompt:
		advance_prompt.visible = false
	
	# Restore background textures to normal (TODO: implement background switching)
	
	# Reset dialogue box to strategy mode
	if dialogue_label:
		dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _show_vn_ui() -> void:
	# Dim strategy elements
	if action_buttons:
		action_buttons.visible = false
	if stats_panel:
		stats_panel.modulate.a = 0.5
	
	# Show VN elements
	if character_container:
		character_container.visible = true
	if speaker_label:
		speaker_label.visible = true
	if advance_prompt:
		advance_prompt.visible = true
	
	# Change background textures (TODO: implement background switching)
	
	# Set dialogue box to VN mode
	if dialogue_label:
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
	vn_component.load_chain(chain)

func _on_vn_display_updated(dialogue_data: Dictionary) -> void:
	if dialogue_data.is_empty():
		return
	
	# Update speaker
	if speaker_label:
		speaker_label.text = dialogue_data.get("speaker_name", "")
	
	# Update dialogue text
	if dialogue_label:
		dialogue_label.text = dialogue_data.get("line_spoken", "")
	
	# Update background (TODO: switch MainBackground and Foreground textures)
	var bg_id = dialogue_data.get("background_id", "")
	_update_vn_background(bg_id)
	
	# Update character portraits
	var char_ids: Array = dialogue_data.get("on_screen_character_ids", [])
	_update_vn_portraits(char_ids)
	
	# Update progress indicator on advance prompt
	var index = dialogue_data.get("index", 0)
	var total = dialogue_data.get("total", 0)
	if advance_prompt:
		advance_prompt.text = "Click to continue (%d/%d)" % [index + 1, total]

func _update_vn_background(_bg_id: String) -> void:
	# TODO: Load and set actual background textures to main_background and foreground
	# For now, just a placeholder comment
	# Example:
	# if _bg_id == "camp_evening":
	#     main_background.texture = load("res://assets/backgrounds/camp_evening.png")
	#     foreground.texture = load("res://assets/backgrounds/camp_evening_fg.png")
	pass

func _update_vn_portraits(character_ids: Array) -> void:
	if not character_container:
		return
	
	# Clear existing portraits
	for child in character_container.get_children():
		child.queue_free()
	
	# Add portraits for on-screen characters
	for char_id in character_ids:
		if char_id is String:
			var portrait = _get_or_create_portrait(char_id)
			character_container.add_child(portrait)

func _get_or_create_portrait(character_id: String) -> Control:
	if portrait_cache.has(character_id):
		return portrait_cache[character_id].duplicate()
	
	# Create placeholder portrait
	var portrait = ColorRect.new()
	portrait.custom_minimum_size = Vector2(150, 250)
	
	# Different colors for different characters
	var hash_val = character_id.hash()
	portrait.color = Color(
		float(hash_val % 100) / 100.0,
		float(int(hash_val / 100.0) % 100) / 100.0,
		float(int(hash_val / 10000.0) % 100) / 100.0,
		1.0
	)
	
	portrait_cache[character_id] = portrait
	return portrait.duplicate()

func _on_dialogue_box_clicked(event: InputEvent) -> void:
	if ui_mode != UIMode.VISUAL_NOVEL:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if vn_component:
				vn_component.advance()

func _on_vn_chain_completed() -> void:
	print("TrainingScreen: EventChain completed")
	
	# Clear VN state
	if vn_component:
		vn_component.reset()
	
	# Play next chain in queue or return to strategy mode
	if event_chain_queue.size() > 0:
		print("TrainingScreen: %d more chains in queue, playing next..." % event_chain_queue.size())
		_play_next_queued_chain()
	else:
		print("TrainingScreen: All chains completed, returning to strategy mode")
		is_playing_chain = false
		_set_ui_mode(UIMode.STRATEGY)
		
		# Show completion message
		if current_activity_result:
			_display_activity_result(current_activity_result)
		else:
			dialogue_label.text = "All event chains completed. Choose your next action."
		
		_update_ui()
