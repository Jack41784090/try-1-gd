extends Control
class_name TravelGUI

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var locations_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer/LocationsScroll/LocationsContainer
@onready var confirm_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/ConfirmButton
@onready var cancel_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/CancelButton
@onready var title_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var selected_location_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/SelectedLocationLabel

var game_scenario: GameScenario
var selected_location_id: String = ""
var location_buttons: Dictionary = {}

signal location_selected(location_id: String)
signal travel_confirmed(location_id: String)
signal travel_cancelled()

func _ready() -> void:
	overlay_panel.visible = false
	confirm_button.visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

func show_travel_menu(scenario: GameScenario) -> void:
	game_scenario = scenario
	selected_location_id = ""
	confirm_button.visible = false
	selected_location_label.text = ""
	overlay_panel.visible = true
	_update_locations_list()

func hide_travel_menu() -> void:
	overlay_panel.visible = false
	selected_location_id = ""
	_clear_location_buttons()

func _update_locations_list() -> void:
	_clear_location_buttons()
	
	if not game_scenario or not game_scenario.current_location:
		return
	
	var current_id = game_scenario.current_location.location_id
	var travel_graph = game_scenario.world.travel_graph
	
	if not travel_graph:
		game_scenario.world.build_travel_graph()
		travel_graph = game_scenario.world.travel_graph
	
	var reachable_ids = travel_graph.get_all_reachable_locations(current_id)
	
	var location_data: Array[Dictionary] = []
	for location_id in reachable_ids:
		var location = travel_graph.get_location(location_id)
		if not location:
			continue
		
		var distance = travel_graph.get_distance(current_id, location_id)
		if distance < 0:
			continue
		
		location_data.append({
			"location_id": location_id,
			"location": location,
			"distance": distance,
			"development": location.development
		})
	
	location_data.sort_custom(_sort_locations)
	
	title_label.text = "Travel from %s" % game_scenario.current_location.location_name
	
	if location_data.is_empty():
		var no_locations_label = Label.new()
		no_locations_label.text = "No reachable locations found."
		no_locations_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locations_container.add_child(no_locations_label)
	else:
		for data in location_data:
			_create_location_button(data.location, data.distance)

func _sort_locations(a: Dictionary, b: Dictionary) -> bool:
	if a.distance != b.distance:
		return a.distance < b.distance
	return a.development > b.development

func _create_location_button(location: Location, distance: int) -> void:
	var button = Button.new()
	button.custom_minimum_size = Vector2(0, 60)
	button.text = _format_location_text(location, distance)
	button.pressed.connect(func(): _on_location_button_pressed(location.location_id))
	
	location_buttons[location.location_id] = button
	locations_container.add_child(button)

func _format_location_text(location: Location, distance: int) -> String:
	var type_str = _location_type_to_string(location.type)
	var distance_str = ""
	if distance == 1:
		distance_str = "1 location away"
	else:
		distance_str = "%d locations away" % distance
	
	return "%s (%s) - %s\nDev: %d | Stab: %.0f" % [
		location.location_name,
		type_str,
		distance_str,
		location.development,
		location.stability
	]

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

func _on_location_button_pressed(location_id: String) -> void:
	selected_location_id = location_id
	var location = game_scenario.world.travel_graph.get_location(location_id)
	if location:
		var distance = game_scenario.world.travel_graph.get_distance(
			game_scenario.current_location.location_id,
			location_id
		)
		var travel_time = game_scenario.world.calculate_travel_time(
			game_scenario.current_location.location_id,
			location_id
		)
		
		selected_location_label.text = "Selected: %s (%d locations, %d turns)" % [
			location.location_name,
			distance,
			travel_time
		]
		confirm_button.visible = true
		location_selected.emit(location_id)
		
		for button_id in location_buttons:
			var button = location_buttons[button_id]
			if button_id == location_id:
				button.modulate = Color(0.8, 0.9, 1.0, 1.0)
			else:
				button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_confirm_pressed() -> void:
	if not selected_location_id.is_empty():
		travel_confirmed.emit(selected_location_id)

func _on_cancel_pressed() -> void:
	travel_cancelled.emit()

func _clear_location_buttons() -> void:
	for child in locations_container.get_children():
		child.queue_free()
	location_buttons.clear()
