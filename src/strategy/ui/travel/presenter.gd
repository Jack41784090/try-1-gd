class_name TravelPresenter extends Node

enum TravelMode {
	AUTOPILOT,
	MANUAL,
	GOING
}

var view: TravelView
var actor: ActivityRunner

var selected_location_id: String = ""
var current_mode: TravelMode = TravelMode.AUTOPILOT
var _map_initialized: bool = false
var _selected_path: Array = []

var towards_location: Location:
	get:
		towards_location = actor.walking_towards["location"]
		return towards_location
var towards_progress: float:
	get:
		towards_progress = actor.walking_towards["progress"]
		return towards_progress
var current_location: Location:
	get:
		return actor.current_location

func setup(_actor: ActivityRunner) -> void:
	actor = _actor

func bind_view(v: TravelView) -> void:
	view = v

func get_effective_mode() -> TravelMode:
	if towards_location != null:
		return TravelMode.GOING
	return current_mode

func on_show(_scenario, _locs) -> void:
	if not _map_initialized:
		view.setup_map(actor.aem.scenario.world)
		_map_initialized = true
	view.set_current_location_on_map(current_location.location_id)
	var mode = get_effective_mode()
	match mode:
		TravelMode.GOING:
			view.show_going_mode()
		_:
			_refresh_locations_list()
			view.show_selection_mode()
	view.show_menu()
	view.update_mode_button(mode)

func on_hide() -> void:
	selected_location_id = ""
	_selected_path = []
	view.clear_map_highlights()
	view.hide_menu()

func on_mode_toggle() -> void:
	var mode = get_effective_mode()
	if mode == TravelMode.GOING:
		return
	if current_mode == TravelMode.AUTOPILOT:
		current_mode = TravelMode.MANUAL
	else:
		current_mode = TravelMode.AUTOPILOT
	selected_location_id = ""
	view.clear_selected_label()
	_refresh_locations_list()
	view.update_mode_button(get_effective_mode())

func on_location_selected(location_id: String) -> void:
	selected_location_id = location_id
	var location = actor.aem.world.travel_graph.get_location(location_id)
	var distance = actor.aem.world.travel_graph.get_distance(
		current_location.location_id,
		location_id
	)
	var travel_time = actor.aem.world.travel_graph.calculate_travel_time_between(
		current_location.location_id,
		location_id
	)
	_selected_path = actor.aem.world.travel_graph.find_path(
		current_location.location_id,
		location_id
	)
	var path_typed: Array[String] = []
	for p in _selected_path:
		path_typed.append(p)
	view.highlight_path_on_map(path_typed)
	view.update_selected_location("Selected: %s (%d locations, %d turns)" % [
		location.location_name,
		distance,
		travel_time
	])
	view.set_confirm_visible(true)
	view.highlight_location_button(location_id)

func on_confirm() -> void:
	var mode = get_effective_mode()
	if mode == TravelMode.GOING:
		var progress_pct = towards_progress / actor.get_distance(current_location, towards_location) * 100.0
		view.update_travel_progress(progress_pct)
		view.travel_confirmed.emit(towards_location.location_id)
	elif not selected_location_id.is_empty():
		var path = actor.aem.world.travel_graph.find_path(current_location.location_id, selected_location_id)
		view.travel_confirmed.emit(path[1])

func on_cancel() -> void:
	view.travel_cancelled.emit()

func set_mode_autopilot() -> void:
	current_mode = TravelMode.AUTOPILOT

func _refresh_locations_list() -> void:
	var location_data = _gather_location_data()
	view.display_locations(location_data, get_effective_mode())

func _gather_location_data() -> Array[Dictionary]:
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
	return location_data

func _sort_locations(a: Dictionary, b: Dictionary) -> bool:
	if a.distance != b.distance:
		return a.distance < b.distance
	return a.development > b.development
