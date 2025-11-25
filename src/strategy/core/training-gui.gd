extends Control

## Strategic Campaign UI Screen with integrated Visual Novel system
## Displays squad state, world info, and allows activity selection
## Seamlessly transitions to VN mode for EventChain playback

# const StatChangeAnimator = preload("res://src/strategy/ui/stat_change_animator.gd")

signal vn_completed();

enum UIMode {
	STRATEGY,      # Normal activity buttons visible
	VISUAL_NOVEL   # VN elements visible, strategy UI dimmed
}

@onready var turn_label: Label = $PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderHBox/HeaderMargin/TurnAndLocation/TurnLabel
@onready var location_label: Label = $PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderHBox/HeaderMargin/TurnAndLocation/LocationLabel
@onready var end_button: Button = $PanelContainer/MainVBox/StatusArea/EndButton
@onready var morale_bar: ProgressBar = $PanelContainer/MainVBox/StatusArea/StatusPanel/StatusMargin/StatusContent/ProgressBar
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
@onready var travel_gui: TravelGUI = $TravelGUI

@onready var skip_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/SkipButton
@onready var short_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/ShortButton

var game_scenario: GameScenario
# var current_activity_result: ActivityResult = null
var ui_mode: UIMode = UIMode.STRATEGY
var portrait_cache: Dictionary = {}
var event_chain_queue: Array[String] = []
var is_playing_chain: bool = false
var is_executing_activity: bool = false

var vn_current_chain: EventChain
var vn_current_index: int = 0
var vn_character_ids_in_chain: Array[String] = []

var stat_snapshot: Dictionary = {}
var stat_animator: StatChangeAnimator = StatChangeAnimator.new()

@export var scenario_path: String
@export var is_demo_scenario: bool = true

var _demo_values: Dictionary = {
	"city": {
		"location_id": "test_city",
		"location_name": "Ravenna",
		"development": 75,
		"stability": 85.0
	},
	"village": {
		"location_id": "test_village",
		"location_name": "Countryside",
		"development": 30,
		"stability": 60.0
	},
	"squad": {
		"squad_id": "player_squad",
		"squad_name": "The Condors",
		"money": 150.0,
		"food": 20,
		"travel_tools": 8,
		"karma": 10.0,
		"starting_location_id": "test_city"
	},
	"world": {
		"turn_count": 0,
		"end_progression": 0.0
	}
}

func _ready() -> void:
	_initialize_scenario()
	_connect_signals()
	_set_ui_mode(UIMode.STRATEGY)
	_update_ui()

#region Initialization

#region Demo-Specific Functions

func _create_demo_locations() -> Array[Location]:
	var city_values = _demo_values["city"]
	var village_values = _demo_values["village"]
	
	var location_configs: Array[Dictionary] = [
		{
			"location_id": city_values["location_id"],
			"location_name": city_values["location_name"],
			"type": StrategyTypes.LocationType.CITY,
			"development": city_values["development"],
			"stability": city_values["stability"],
			"activity_types": [
				StrategyTypes.ActivityType.REST,
				StrategyTypes.ActivityType.DRILL,
				StrategyTypes.ActivityType.PATROL,
				StrategyTypes.ActivityType.INVESTIGATE,
				StrategyTypes.ActivityType.HOLD_MASS
			]
		},
		{
			"location_id": village_values["location_id"],
			"location_name": village_values["location_name"],
			"type": StrategyTypes.LocationType.VILLAGE,
			"development": village_values["development"],
			"stability": village_values["stability"],
			"activity_types": [
				StrategyTypes.ActivityType.REST,
				StrategyTypes.ActivityType.DRILL,
				StrategyTypes.ActivityType.HOLD_MASS
			]
		}
	]
	
	var connections: Array[Array] = [
		[city_values["location_id"], village_values["location_id"]],
		[village_values["location_id"], city_values["location_id"]]
	]
	
	return _create_locations_with_connections(location_configs, connections)

func _create_demo_world() -> World:
	var world_values = _demo_values["world"]
	var locations = _create_demo_locations()
	return _create_world(world_values["turn_count"], world_values["end_progression"], locations)

func _create_demo_squad() -> StrategicSquad:
	var squad_values = _demo_values["squad"]
	return _create_squad(
		squad_values["squad_id"], 
		squad_values["squad_name"], 
		squad_values["money"], 
		squad_values["food"], 
		squad_values["travel_tools"], 
		squad_values["karma"], 
		squad_values["starting_location_id"]
	)

func _initialize_demo_scenario() -> void:
	var world = _create_demo_world()
	var starting_location_id = _demo_values["city"]["location_id"]
	var squad = _create_demo_squad()
	# For demo scenario, let GameScenario register default events/activities
	var config = _create_scenario_config(world, squad, starting_location_id, [], [])
	
	game_scenario = GameScenario.new(config)
	
	print("Demo scenario initialized: %s in %s" % [squad.squad_name, world.travel_graph.get_location(starting_location_id).location_name])

#endregion

func _initialize_scenario() -> void:
	if is_demo_scenario:
		_initialize_demo_scenario()
	else:
		var loaded = load(scenario_path);
		game_scenario = loaded
		game_scenario.initialize()

func _create_location(location_id: String, location_name: String, location_type: StrategyTypes.LocationType, development: int, stability: float, activity_types: Array) -> Location:
	var location = Location.new()
	location.location_id = location_id
	location.location_name = location_name
	location.type = location_type
	location.development = development
	location.stability = stability
	for activity_type in activity_types:
		location.add_activity_type(activity_type)
	return location

func _create_locations_with_connections(location_configs: Array[Dictionary], connections: Array[Array]) -> Array[Location]:
	var locations: Array[Location] = []
	for config in location_configs:
		var location = _create_location(
			config.get("location_id", ""),
			config.get("location_name", ""),
			config.get("type", StrategyTypes.LocationType.CITY),
			config.get("development", 0),
			config.get("stability", 0.0),
			config.get("activity_types", [])
		)
		locations.append(location)
	
	for connection in connections:
		if connection.size() >= 2:
			var from_id: String = connection[0]
			var to_id: String = connection[1]
			var from_location = locations.filter(func(loc): return loc.location_id == from_id)
			var to_location = locations.filter(func(loc): return loc.location_id == to_id)
			if from_location.size() > 0 and to_location.size() > 0:
				from_location[0].add_connection(to_id)
	return locations

func _create_world(turn_count: int, end_progression: float, locations: Array[Location]) -> World:
	var world = World.new()
	world.turn_count = turn_count
	world.end_progression = end_progression
	
	for location in locations:
		world.add_location(location)
	world.build_travel_graph()
	return world

func _create_warriors() -> Array[Warrior]:
	var warriors: Array[Warrior] = []
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
		
		warriors.append(warrior)
	return warriors

func _create_squad(squad_id: String, squad_name: String, money: float, food: int, travel_tools: int, karma: float, starting_location_id: String) -> StrategicSquad:
	var squad = StrategicSquad.new()
	squad.squad_id = squad_id
	squad.squad_name = squad_name
	squad.money = money
	squad.food = food
	squad.travel_tools = travel_tools
	squad.karma = karma
	squad.set_location(starting_location_id)
	
	var warriors = _create_warriors()
	for warrior in warriors:
		squad.add_warrior(warrior)
	
	squad.update_aggregate_morale()
	return squad

func _create_scenario_config(world: World, squad: StrategicSquad, starting_location_id: String, events: Array[GameEvent], activities: Array[Activity]) -> Dictionary:
	return {
		"world": world,
		"player_squad": squad,
		"starting_location_id": starting_location_id,
		"factions": [],
		"events": events,
		"activities": activities,
		"endings": []
	}

#endregion

#region Signals
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

	vn_completed.connect(_vn_on_chain_completed)
	
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
	activity.result = ActivityResult.new({"location_changed": location_id})
	activity.result.event_chain_path = "empty";
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

	# print("[GameScenario] Squad after activity: Money=%.1f, Food=%d, Morale=%.1f" % [player_squad.money, player_squad.food, player_squad.get_morale()])
	# game_scenario.activity_executed.emit(activity, activity_result)
	
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

func _on_activity_executed(activity: Activity, result: ActivityResult) -> void:
	# current_activity_result = result
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

func _disable_all_activity_buttons() -> void:
	rest_button.disabled = true
	drill_button.disabled = true
	patrol_button.disabled = true
	investigate_button.disabled = true
	hold_mass_button.disabled = true
	travel_button.disabled = true

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
	var location = game_scenario.current_location
	
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
			_show_strategy_ui()
		UIMode.VISUAL_NOVEL:
			dialogue_box.visible = true
			_show_vn_ui()

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
		vn_completed.emit()
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

	vn_current_index += 1
	if _vn_is_complete():
		print("EventChain '%s' completed (showed %d/%d dialogues)" % [vn_current_chain.chain_id, vn_current_index, vn_current_chain.get_dialogue_count()])
		vn_completed.emit()
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

func _vn_components_reset() -> void:
	vn_current_chain = null
	vn_current_index = 0
	vn_character_ids_in_chain.clear()

func _vn_on_chain_completed() -> void:
	_vn_components_reset()
	await _animate_stat_changes()
	_capture_stat_snapshot()
	
	if event_chain_queue.size() > 0:
		print("[StatAnimation] More chains in queue (%d), playing next..." % event_chain_queue.size())
		_play_next_queued_chain()
	else:
		print("[StatAnimation] All chains completed, triggering stat animation...")
		is_playing_chain = false
		_exit_from_vn_to_strategy()

#endregion
