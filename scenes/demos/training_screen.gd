extends Control

## Strategic Campaign UI Screen
## Displays squad state, world info, and allows activity selection

@onready var turn_label: Label = $PanelContainer/MainVBox/StatusHeader/TurnStatus
@onready var location_label: Label = $PanelContainer/MainVBox/StatusHeader/QualifierStatus
@onready var end_button: Button = $PanelContainer/MainVBox/StatusArea/EndButton
@onready var morale_bar: ProgressBar = $PanelContainer/MainVBox/StatusArea/StaminaBar
@onready var condition_label: Label = $PanelContainer/MainVBox/StatusArea/ConditionStatus/ConditionLabel

@onready var character_portrait: TextureRect = $PanelContainer/MainVBox/MainScreenArea/Character
@onready var hint_icon: TextureRect = $PanelContainer/MainVBox/MainScreenArea/HintIcon
@onready var dialogue_label: Label = $PanelContainer/MainVBox/MainScreenArea/DialogueBox/DialogueLabel

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

func _ready() -> void:
	_initialize_demo_scenario()
	_connect_signals()
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
	
	var scenario_config = {
		"world": test_world,
		"player_squad": test_squad,
		"starting_location_id": city_location.location_id,
		"factions": [],
		"events": [],
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
	
	var turn_summary = game_scenario.execute_turn(activity)
	
	if turn_summary.has("error"):
		dialogue_label.text = "Error: %s" % turn_summary["error"]
		return
	
	print("\n=== Turn %d Summary ===" % game_scenario.world.turn_count)
	print("Activity: %s" % turn_summary["activity"])
	print(turn_summary)
	
	_update_ui()

func _display_activity_result(result: StrategyTypes.ActivityResult) -> void:
	var display_text = ""
	
	for narrative in result.narrative_log:
		display_text += narrative + "\n"
	
	if result.squad_stat_changes.size() > 0:
		display_text += "\nSquad Changes:\n"
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
	dialogue_label.text = "Travel system requires destination selection UI - not yet implemented in this demo."

func _on_end_pressed() -> void:
	dialogue_label.text = "Game ended. Final turn: %d" % game_scenario.world.turn_count

func _on_skip_pressed() -> void:
	for i in range(5):
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
