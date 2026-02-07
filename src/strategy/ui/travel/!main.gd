class_name TravelGUI extends Control

enum TravelMode {
	AUTOPILOT,
	MANUAL,
	GOING
}

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var locations_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer/LocationsScroll/LocationsContainer
@onready var confirm_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/ConfirmButton
@onready var cancel_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/CancelButton
@onready var selected_location_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/SelectedLocationLabel
@onready var mode_toggle_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/ModeToggleButton
@onready var travel_progress: ProgressBar = $OverlayPanel/MarginContainer/VBoxContainer/TravelProgressBar

# var game_scenario: GameScenario
var towards_location: Location:
	get:
		towards_location = actor.walking_towards["location"]
		return towards_location
var towards_progress: float:
	get:
		towards_progress = actor.walking_towards["progress"]
		return towards_progress
var actor: ActivityRunner # provided by parent in setup
var current_location: Location:
	get:
		return actor.current_location

var selected_location_id: String = ""
var location_buttons: Dictionary = {}
var current_mode: TravelMode = TravelMode.AUTOPILOT:
	get:
		if towards_location != null:
			current_mode = TravelMode.GOING
			return TravelMode.GOING
		return current_mode
	set(_mode):
		if towards_location != null:
			current_mode = TravelMode.GOING
			return TravelMode.GOING
		if current_mode == _mode: return ;
		selected_location_id = ""
		# confirm_button.visible = false
		selected_location_label.text = ""
		_update_mode_button()
		_update_locations_list()
		current_mode = _mode

signal location_selected(location_id: String)
signal travel_confirmed(location_id: String)
signal travel_cancelled()

func setup(_actor):
	assert(_actor is ActivityRunner)
	actor = _actor

func _process(delta: float) -> void:
	pass

func _ready() -> void:
	overlay_panel.visible = false
	confirm_button.visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	if mode_toggle_button:
		mode_toggle_button.pressed.connect(_on_mode_toggle_pressed)

func show_travel_menu(_scenario, locs) -> void:
	self.visible = true
	match current_mode:
		TravelMode.GOING:
			travel_progress.visible = true
			mode_toggle_button.visible = false
		_:
			travel_progress.visible = false
			mode_toggle_button.visible = true
			_update_locations_list()
	#selected_location_id = ""
	confirm_button.visible = true
	#selected_location_label.text = ""
	#current_mode = TravelMode.AUTOPILOT
	overlay_panel.visible = true
	_update_mode_button()

func hide_travel_menu() -> void:
	overlay_panel.visible = false
	selected_location_id = ""
	_clear_location_buttons()

func _update_locations_list() -> void:
	_clear_location_buttons()
	var current_loc_id = current_location.location_id
	
	var location_data: Array[Dictionary] = []
	var reachable_ids = actor.get_all_reachable_locations(current_location)
	
	if current_mode == TravelMode.AUTOPILOT:
		for location_id in reachable_ids:
			var location = actor.get_location_by_id(location_id)
			if not location:
				continue
			
			if location.type not in [StrategyTypes.LocationType.CITY, StrategyTypes.LocationType.TOWN, StrategyTypes.LocationType.FORT]:
				continue
			
			var distance = actor.get_distance(current_loc_id, location_id)
			if distance < 0:
				continue
			
			location_data.append({
				"location_id": location_id,
				"location": location,
				"distance": distance,
				"development": location.development
			})
	else:
		var current_loc = actor.get_location_by_id(current_loc_id)
		if current_loc:
			for neighbor_id in current_loc.connections:
				var location = actor.get_location_by_id(neighbor_id)
				if not location:
					continue
				
				location_data.append({
					"location_id": neighbor_id,
					"location": location,
					"distance": 1,
					"development": location.development
				})
	
	location_data.sort_custom(_sort_locations)
	
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
	var icon = _location_type_to_icon(location.type)
	var distance_str = ""
	
	if current_mode == TravelMode.AUTOPILOT:
		if distance == 1:
			distance_str = "1 location away"
		else:
			distance_str = "%d locations away" % distance
		return "%s %s (%s) - %s\nDev: %d | Stab: %.0f" % [
			icon,
			location.location_name,
			type_str,
			distance_str,
			location.development,
			location.stability
		]
	else:
		if location.type == StrategyTypes.LocationType.ROAD:
			return "→ %s\nStab: %.0f" % [location.location_name, location.stability]
		else:
			return "%s %s (%s)\nDev: %d | Stab: %.0f" % [
				icon,
				location.location_name,
				type_str,
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

func _location_type_to_icon(loc_type: StrategyTypes.LocationType) -> String:
	match loc_type:
		StrategyTypes.LocationType.CITY:
			return "🏛️"
		StrategyTypes.LocationType.TOWN:
			return "🏘️"
		StrategyTypes.LocationType.VILLAGE:
			return "🏡"
		StrategyTypes.LocationType.FORT:
			return "🏰"
		StrategyTypes.LocationType.ROAD:
			return "🛤️"
		_:
			return "❓"

func _update_mode_button() -> void:
	match current_mode:
		TravelMode.AUTOPILOT:
			mode_toggle_button.text = "Switch to " + TravelMode.keys()[current_mode]
		TravelMode.MANUAL:
			mode_toggle_button.text = "Switch to " + TravelMode.keys()[current_mode]
		TravelMode.GOING:
			mode_toggle_button.visible = false

func _on_mode_toggle_pressed() -> void:
	if current_mode == TravelMode.AUTOPILOT:
		current_mode = TravelMode.MANUAL
	else:
		current_mode = TravelMode.AUTOPILOT

func _on_location_button_pressed(location_id: String) -> void:
	selected_location_id = location_id
	var location = actor.data.world.travel_graph.get_location(location_id)
	# if location:
	var distance = actor.data.world.travel_graph.get_distance(
		current_location.location_id,
		location_id
	)
	var travel_time = actor.data.world.travel_graph.calculate_travel_time_between(
		current_location.location_id,
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
	if current_mode == TravelMode.GOING:
		travel_progress.value = towards_progress / actor.get_distance(current_location, towards_location) * 100.0
		travel_confirmed.emit(towards_location.location_id)
	elif not selected_location_id.is_empty():
		var path = actor.data.world.travel_graph.find_path(current_location.location_id, selected_location_id)
		travel_confirmed.emit(path[1])

func _on_cancel_pressed() -> void:
	travel_cancelled.emit()

func _clear_location_buttons() -> void:
	for child in locations_container.get_children():
		child.queue_free()
	location_buttons.clear()
