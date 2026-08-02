class_name TravelMapView extends Control

signal location_selected(location_id: String)

@onready var _viewport_container: SubViewportContainer = $MapViewportContainer
@onready var _viewport: SubViewport = $MapViewportContainer/MapViewport
@onready var _camera: Camera2D = $MapViewportContainer/MapViewport/MapCamera

var _marker_map: Dictionary = {}
var _line_map: Dictionary = {}
var _connections_layer: Node2D
var _markers_layer: Node2D
var _map_content: Node2D

var _panning: bool = false
var _map_ready: bool = false

const ZOOM_MIN: Vector2 = Vector2(0.3, 0.3)
const ZOOM_MAX: Vector2 = Vector2(4.0, 4.0)
const ZOOM_STEP: float = 0.1

const LINE_COLOR_DEFAULT: Color = Color(0.4, 0.38, 0.32, 0.6)
const LINE_COLOR_GLOW: Color = Color(0.9, 0.75, 0.3, 0.9)
const LINE_WIDTH_DEFAULT: float = 2.0
const LINE_WIDTH_GLOW: float = 4.0

var _glow_shader: Shader

func _ready() -> void:
	clip_contents = true
	_glow_shader = load("res://assets/shaders/map_glow.gdshader")

	_map_content = Node2D.new()
	_map_content.name = "MapContent"
	_viewport.add_child(_map_content)

	_connections_layer = Node2D.new()
	_connections_layer.name = "ConnectionsLayer"
	_map_content.add_child(_connections_layer)

	_markers_layer = Node2D.new()
	_markers_layer.name = "MarkersLayer"
	_map_content.add_child(_markers_layer)

func setup(world: World) -> void:
	if _map_ready:
		return
	assert(world.map_scene != null, "World.map_scene must be set")

	var map_instance = world.map_scene.instantiate()
	var markers_to_reparent: Array[LocationMarker] = []
	_find_markers_recursive(map_instance, markers_to_reparent)
	for marker in markers_to_reparent:
		var saved_pos = marker.position
		marker.reparent(_markers_layer)
		marker.position = saved_pos
		_marker_map[marker.location_id] = marker
		marker.marker_clicked.connect(_on_marker_clicked)

	var bg = map_instance.get_node_or_null("Background")
	if not bg:
		for child in map_instance.get_children():
			if child is TextureRect or child is Sprite2D:
				bg = child
				break
	if bg:
		bg.reparent(_map_content)
		_map_content.move_child(bg, 0)

	map_instance.queue_free()

	var processed_pairs: Dictionary = {}
	for location in world.locations:
		if location.type == StrategyTypes.LocationType.ROAD:
			continue
		if not _marker_map.has(location.location_id):
			continue

		var endpoints: Array[String] = []
		if location.connections != null:
			for connected_id in location.connections:
				var connected_loc = world.get_location_by_id(connected_id)
				if connected_loc == null:
					continue
				if connected_loc.type == StrategyTypes.LocationType.ROAD:
					var chain_result = _follow_road_chain(connected_loc, location.location_id, world)
					for end_id in chain_result:
						if end_id not in endpoints:
							endpoints.append(end_id)
				else:
					if connected_id not in endpoints:
						endpoints.append(connected_id)

		for endpoint_id in endpoints:
			if not _marker_map.has(endpoint_id):
				continue

			var pair_key = _make_line_key(location.location_id, endpoint_id)
			if processed_pairs.has(pair_key):
				continue
			processed_pairs[pair_key] = true

			var from_marker: LocationMarker = _marker_map[location.location_id]
			var to_marker: LocationMarker = _marker_map[endpoint_id]

			var line = Line2D.new()
			line.add_point(from_marker.position)
			line.add_point(to_marker.position)
			line.width = LINE_WIDTH_DEFAULT
			line.default_color = LINE_COLOR_DEFAULT
			line.antialiased = true

			var mat = ShaderMaterial.new()
			mat.shader = _glow_shader
			mat.set_shader_parameter("is_glowing", 0.0)
			mat.set_shader_parameter("glow_color", Color(0.9, 0.75, 0.3, 1.0))
			mat.set_shader_parameter("glow_intensity", 1.5)
			mat.set_shader_parameter("pulse_speed", 3.0)
			line.material = mat

			_connections_layer.add_child(line)
			_line_map[pair_key] = line

	for location in world.locations:
		if _marker_map.has(location.location_id):
			(_marker_map[location.location_id] as LocationMarker).set_label_text(location.location_name)

	if not _marker_map.is_empty():
		var min_pos = Vector2(INF, INF)
		var max_pos = Vector2(-INF, -INF)
		for marker in _marker_map.values():
			var pos = (marker as LocationMarker).position
			min_pos.x = min(min_pos.x, pos.x)
			min_pos.y = min(min_pos.y, pos.y)
			max_pos.x = max(max_pos.x, pos.x)
			max_pos.y = max(max_pos.y, pos.y)

		var center = (min_pos + max_pos) / 2.0
		_camera.position = center

		var map_extent = max_pos - min_pos
		var view_size = size
		if view_size.x > 0 and view_size.y > 0 and map_extent.x > 0 and map_extent.y > 0:
			var padding = 100.0
			var zoom_x = view_size.x / (map_extent.x + padding)
			var zoom_y = view_size.y / (map_extent.y + padding)
			var fit_zoom = min(zoom_x, zoom_y)
			fit_zoom = clamp(fit_zoom, ZOOM_MIN.x, ZOOM_MAX.x)
			_camera.zoom = Vector2(fit_zoom, fit_zoom)

	_map_ready = true

func _find_markers_recursive(node: Node, result: Array[LocationMarker]) -> void:
	if node is LocationMarker:
		result.append(node)
	for child in node.get_children():
		_find_markers_recursive(child, result)

func _follow_road_chain(road: Location, came_from_id: String, world: World) -> Array[String]:
	var endpoints: Array[String] = []
	if road.connections == null:
		return endpoints

	for next_id in road.connections:
		if next_id == came_from_id:
			continue
		var next_loc = world.get_location_by_id(next_id)
		if next_loc == null:
			continue
		if next_loc.type == StrategyTypes.LocationType.ROAD:
			var deeper = _follow_road_chain(next_loc, road.location_id, world)
			endpoints.append_array(deeper)
		else:
			endpoints.append(next_id)
	return endpoints

func _make_line_key(id_a: String, id_b: String) -> String:
	if id_a < id_b:
		return "%s|%s" % [id_a, id_b]
	return "%s|%s" % [id_b, id_a]

func highlight_path(path: Array[String]) -> void:
	clear_highlights()
	for location_id in path:
		if _marker_map.has(location_id):
			(_marker_map[location_id] as LocationMarker).set_glowing(true)

	var major_path: Array[String] = []
	for loc_id in path:
		if _marker_map.has(loc_id):
			major_path.append(loc_id)
	for i in range(major_path.size() - 1):
		var key = _make_line_key(major_path[i], major_path[i + 1])
		if _line_map.has(key):
			var line: Line2D = _line_map[key]
			line.default_color = LINE_COLOR_GLOW
			line.width = LINE_WIDTH_GLOW
			if line.material is ShaderMaterial:
				(line.material as ShaderMaterial).set_shader_parameter("is_glowing", 1.0)

func clear_highlights() -> void:
	for marker in _marker_map.values():
		(marker as LocationMarker).set_glowing(false)

	for line in _line_map.values():
		(line as Line2D).default_color = LINE_COLOR_DEFAULT
		(line as Line2D).width = LINE_WIDTH_DEFAULT
		if line.material is ShaderMaterial:
			(line.material as ShaderMaterial).set_shader_parameter("is_glowing", 0.0)

func set_current_location(location_id: String) -> void:
	for marker in _marker_map.values():
		(marker as LocationMarker).set_current(false)

	if _marker_map.has(location_id):
		(_marker_map[location_id] as LocationMarker).set_current(true)

func _on_marker_clicked(location_id: String) -> void:
	location_selected.emit(location_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var viewport_size = Vector2(_viewport.size)
			var world_pos = (event.position - viewport_size * 0.5) / _camera.zoom + _camera.position
			print("[MapView] click screen=%s  world=%s  cam=%s  zoom=%s  vp=%s" % [event.position, world_pos, _camera.position, _camera.zoom, _viewport.size])
			for loc_id in _marker_map:
				var m := _marker_map[loc_id] as LocationMarker
				print("  marker %s pos=%s dist=%.1f radius=%.1f" % [loc_id, m.position, world_pos.distance_to(m.position), m.get_marker_radius()])
			var hit_id := ""
			for hit_loc_id in _marker_map:
				var hit_marker := _marker_map[hit_loc_id] as LocationMarker
				var hit_radius: float = hit_marker.get_marker_radius()
				if world_pos.distance_to(hit_marker.position) <= hit_radius:
					hit_id = hit_loc_id
					break
			if not hit_id.is_empty():
				location_selected.emit(hit_id)
				accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, ZOOM_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, -ZOOM_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_panning = event.pressed
			accept_event()

	elif event is InputEventMouseMotion and _panning:
		_camera.position -= event.relative / _camera.zoom
		accept_event()

func _zoom_at(_mouse_pos: Vector2, step: float) -> void:
	var old_zoom = _camera.zoom
	var new_zoom = (old_zoom + Vector2(step, step)).clamp(ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = new_zoom
