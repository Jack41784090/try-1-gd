class_name TravelView extends Control

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var locations_container: VBoxContainer = $OverlayPanel/MarginContainer/HBoxContainer/ListPanel/ListVBox/LocationsScroll/LocationsContainer
@onready var confirm_button: Button = $OverlayPanel/MarginContainer/HBoxContainer/ListPanel/ListVBox/ConfirmButton
@onready var cancel_button: Button = $OverlayPanel/MarginContainer/HBoxContainer/ListPanel/ListVBox/CancelButton
@onready var selected_location_label: Label = $OverlayPanel/MarginContainer/HBoxContainer/ListPanel/ListVBox/SelectedLocationLabel
@onready var mode_toggle_button: Button = $OverlayPanel/MarginContainer/HBoxContainer/ListPanel/ListVBox/ModeToggleButton
@onready var travel_progress: ProgressBar = $OverlayPanel/MarginContainer/HBoxContainer/ListPanel/ListVBox/TravelProgressBar
@onready var map_container: PanelContainer = $OverlayPanel/MarginContainer/HBoxContainer/MapPanel
@onready var presenter: TravelPresenter = $TravelPresenter

signal travel_confirmed(location_id: String)
signal travel_cancelled()

var location_buttons: Dictionary = {}
var map_view: TravelMapView

func _ready() -> void:
	overlay_panel.visible = false
	confirm_button.visible = false
	confirm_button.pressed.connect(func(): presenter.on_confirm())
	cancel_button.pressed.connect(func(): presenter.on_cancel())
	if mode_toggle_button:
		mode_toggle_button.pressed.connect(func(): presenter.on_mode_toggle())
	presenter.bind_view(self )

	map_view = TravelMapView.new()
	map_view.name = "TravelMapView"
	map_view.set_anchors_preset(PRESET_FULL_RECT)
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_container.add_child(map_view)
	map_view.location_selected.connect(func(id): presenter.on_location_selected(id))

func setup(_actor) -> void:
	presenter.setup(_actor)

func show_travel_menu(_scenario, locs) -> void:
	presenter.on_show(_scenario, locs)

func hide_travel_menu() -> void:
	presenter.on_hide()

func set_mode_autopilot() -> void:
	presenter.set_mode_autopilot()

func setup_map(world: World) -> void:
	map_view.setup(world)

func set_current_location_on_map(location_id: String) -> void:
	map_view.set_current_location(location_id)

func highlight_path_on_map(path: Array[String]) -> void:
	map_view.highlight_path(path)

func clear_map_highlights() -> void:
	map_view.clear_highlights()

#region Display Methods

func show_menu() -> void:
	self.visible = true
	confirm_button.visible = true
	overlay_panel.visible = true
	await UIAnimations.show_overlay(self, overlay_panel)

func hide_menu() -> void:
	await UIAnimations.hide_overlay(self, overlay_panel)
	overlay_panel.visible = false
	self.visible = false
	_clear_location_buttons()

func show_going_mode() -> void:
	travel_progress.visible = true
	mode_toggle_button.visible = false

func show_selection_mode() -> void:
	travel_progress.visible = false
	mode_toggle_button.visible = true

func update_mode_button(mode: TravelPresenter.TravelMode) -> void:
	match mode:
		TravelPresenter.TravelMode.AUTOPILOT:
			mode_toggle_button.text = "Switch to " + TravelPresenter.TravelMode.keys()[mode]
		TravelPresenter.TravelMode.MANUAL:
			mode_toggle_button.text = "Switch to " + TravelPresenter.TravelMode.keys()[mode]
		TravelPresenter.TravelMode.GOING:
			mode_toggle_button.visible = false

func update_selected_location(text: String) -> void:
	selected_location_label.text = text

func clear_selected_label() -> void:
	selected_location_label.text = ""

func set_confirm_visible(vis: bool) -> void:
	confirm_button.visible = vis

func update_travel_progress(value: float) -> void:
	travel_progress.value = value

func display_locations(location_data: Array[Dictionary], mode: TravelPresenter.TravelMode) -> void:
	_clear_location_buttons()
	if location_data.is_empty():
		var no_locations_label = Label.new()
		no_locations_label.text = "No reachable locations found."
		no_locations_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locations_container.add_child(no_locations_label)
	else:
		for data in location_data:
			_create_location_button(data.location, data.distance, mode)

func highlight_location_button(location_id: String) -> void:
	for button_id in location_buttons:
		var button = location_buttons[button_id]
		if button_id == location_id:
			button.modulate = Color(0.8, 0.9, 1.0, 1.0)
		else:
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)

#endregion

#region Display Helpers

func _create_location_button(location: Location, distance: int, mode: TravelPresenter.TravelMode) -> void:
	var button = Button.new()
	button.custom_minimum_size = Vector2(0, 50)
	button.text = _format_location_text(location, distance, mode)
	button.pressed.connect(func(): presenter.on_location_selected(location.location_id))
	location_buttons[location.location_id] = button
	locations_container.add_child(button)

func _format_location_text(location: Location, distance: int, mode: TravelPresenter.TravelMode) -> String:
	var type_str: String = _location_type_to_string(location.type)
	var icon: String = _location_type_to_icon(location.type)

	if mode == TravelPresenter.TravelMode.AUTOPILOT:
		var distance_str = ""
		if distance == 1:
			distance_str = "1 location away"
		else:
			distance_str = "%d locations away" % distance
		return "%s %s (%s) - %s\nDev: %d | Stab: %.0f" % [
			icon, location.location_name, type_str,
			distance_str, location.development, location.stability
		]
	else:
		if location.type == StrategyTypes.LocationType.ROAD:
			return "→ %s\nStab: %.0f" % [location.location_name, location.stability]
		else:
			return "%s %s (%s)\nDev: %d | Stab: %.0f" % [
				icon, location.location_name, type_str,
				location.development, location.stability
			]

func _location_type_to_string(loc_type: StrategyTypes.LocationType) -> String:
	match loc_type:
		StrategyTypes.LocationType.CITY: return "City"
		StrategyTypes.LocationType.TOWN: return "Town"
		StrategyTypes.LocationType.VILLAGE: return "Village"
		StrategyTypes.LocationType.FORT: return "Fort"
		StrategyTypes.LocationType.ROAD: return "Road"
		_: return "Unknown"

func _location_type_to_icon(loc_type: StrategyTypes.LocationType) -> String:
	match loc_type:
		StrategyTypes.LocationType.CITY: return "🏛️"
		StrategyTypes.LocationType.TOWN: return "🏘️"
		StrategyTypes.LocationType.VILLAGE: return "🏡"
		StrategyTypes.LocationType.FORT: return "🏰"
		StrategyTypes.LocationType.ROAD: return "🛤️"
		_: return "❓"

func _clear_location_buttons() -> void:
	for child in locations_container.get_children():
		child.queue_free()
	location_buttons.clear()

#endregion
