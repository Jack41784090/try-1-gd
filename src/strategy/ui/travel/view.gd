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

const MAP_VIEW_SCENE := preload("res://scenes/ui/maps/travel_map_view.tscn")

var location_buttons: Dictionary = {}
var map_view: TravelMapView
var _location_btns: Array[Button]
var _no_locations_label: Label

func _ready() -> void:
	overlay_panel.visible = false
	confirm_button.visible = false
	confirm_button.pressed.connect(func(): presenter.on_confirm())
	cancel_button.pressed.connect(func(): presenter.on_cancel())
	if mode_toggle_button:
		mode_toggle_button.pressed.connect(func(): presenter.on_mode_toggle())
	presenter.bind_view(self )

	map_view = MAP_VIEW_SCENE.instantiate()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_container.add_child(map_view)
	map_view.location_selected.connect(func(id): presenter.on_location_selected(id))

	for child in locations_container.get_children():
		if child is Button:
			_location_btns.append(child)
		elif child is Label:
			_no_locations_label = child

	for btn in _location_btns:
		btn.visible = false
	_no_locations_label.visible = false

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
		_no_locations_label.visible = true
	else:
		_no_locations_label.visible = false
		for i in location_data.size():
			if i >= _location_btns.size():
				break
			var data := location_data[i]
			var btn := _location_btns[i]
			var loc: Location = data.location
			var type_str: String = _location_type_to_string(loc.type)
			var icon: String
			match loc.type:
				StrategyTypes.LocationType.CITY: icon = "🏛️"
				StrategyTypes.LocationType.TOWN: icon = "🏘️"
				StrategyTypes.LocationType.VILLAGE: icon = "🏡"
				StrategyTypes.LocationType.FORT: icon = "🏰"
				StrategyTypes.LocationType.ROAD: icon = "🛤️"
				_: icon = "❓"

			if mode == TravelPresenter.TravelMode.AUTOPILOT:
				var distance_str = ""
				if data.distance == 1:
					distance_str = "1 location away"
				else:
					distance_str = "%d locations away" % data.distance
				btn.text = "%s %s (%s) - %s\nDev: %d | Stab: %.0f" % [
					icon, loc.location_name, type_str,
					distance_str, loc.development, loc.stability
				]
			else:
				if loc.type == StrategyTypes.LocationType.ROAD:
					btn.text = "→ %s\nStab: %.0f" % [loc.location_name, loc.stability]
				else:
					btn.text = "%s %s (%s)\nDev: %d | Stab: %.0f" % [
						icon, loc.location_name, type_str,
						loc.development, loc.stability
					]
			for conn in btn.pressed.get_connections():
				btn.pressed.disconnect(conn.callable)
			btn.pressed.connect(func(): presenter.on_location_selected(loc.location_id))
			location_buttons[loc.location_id] = btn
			btn.visible = true

func highlight_location_button(location_id: String) -> void:
	for button_id in location_buttons:
		var button = location_buttons[button_id]
		if button_id == location_id:
			button.modulate = Color(0.8, 0.9, 1.0, 1.0)
		else:
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)

#endregion

#region Display Helpers

func _location_type_to_string(loc_type: StrategyTypes.LocationType) -> String:
	match loc_type:
		StrategyTypes.LocationType.CITY: return "City"
		StrategyTypes.LocationType.TOWN: return "Town"
		StrategyTypes.LocationType.VILLAGE: return "Village"
		StrategyTypes.LocationType.FORT: return "Fort"
		StrategyTypes.LocationType.ROAD: return "Road"
		_: return "Unknown"

func _clear_location_buttons() -> void:
	for btn in _location_btns:
		btn.visible = false
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
	_no_locations_label.visible = false
	location_buttons.clear()

#endregion
