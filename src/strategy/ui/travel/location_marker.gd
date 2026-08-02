class_name LocationMarker extends Area2D

signal marker_clicked(location_id: String)

@export var location_id: String = ""
@export var location_type: StrategyTypes.LocationType = StrategyTypes.LocationType.CITY

@onready var _label: Label = $Label

var _is_glowing: bool = false
var _is_current: bool = false
var _is_hovered: bool = false

const MARKER_SIZES: Dictionary = {
	StrategyTypes.LocationType.CITY: 18.0,
	StrategyTypes.LocationType.TOWN: 14.0,
	StrategyTypes.LocationType.VILLAGE: 10.0,
	StrategyTypes.LocationType.FORT: 16.0,
}

const MARKER_COLORS: Dictionary = {
	StrategyTypes.LocationType.CITY: Color(0.85, 0.75, 0.45),
	StrategyTypes.LocationType.TOWN: Color(0.7, 0.65, 0.5),
	StrategyTypes.LocationType.VILLAGE: Color(0.6, 0.55, 0.45),
	StrategyTypes.LocationType.FORT: Color(0.75, 0.4, 0.35),
}

const CURRENT_COLOR: Color = Color(0.3, 0.85, 0.5)
const GLOW_COLOR: Color = Color(0.9, 0.75, 0.3)
const HOVER_COLOR: Color = Color(1.0, 0.95, 0.8)

func _ready() -> void:
	assert(not location_id.is_empty(), "LocationMarker requires a non-empty location_id")
	input_pickable = true
	set_process(false)
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = _get_marker_size() + 6.0
	collision.shape = shape
	add_child(collision)
	_label.text = location_id
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.position = Vector2(-50, _get_marker_size() + 8)
	_label.size = Vector2(100, 20)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_label_text(text: String) -> void:
	_label.text = text

func _get_marker_size() -> float:
	return MARKER_SIZES.get(location_type, 12.0)

func get_marker_radius() -> float:
	return _get_marker_size() + 6.0

func _draw() -> void:
	var size = _get_marker_size()
	var color: Color
	if _is_current:
		color = CURRENT_COLOR
	elif _is_glowing:
		color = GLOW_COLOR
	elif _is_hovered:
		color = HOVER_COLOR
	else:
		color = MARKER_COLORS.get(location_type, Color(0.6, 0.6, 0.6))
	var outline_color = color * 1.3
	outline_color.a = 1.0

	if _is_glowing:
		var glow_alpha = sin(Time.get_ticks_msec() * 0.003) * 0.2 + 0.3
		draw_circle(Vector2.ZERO, size + 8.0, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, glow_alpha))

	if _is_current:
		var pulse_alpha = sin(Time.get_ticks_msec() * 0.002) * 0.15 + 0.25
		draw_circle(Vector2.ZERO, size + 6.0, Color(CURRENT_COLOR.r, CURRENT_COLOR.g, CURRENT_COLOR.b, pulse_alpha))

	if location_type == StrategyTypes.LocationType.FORT:
		var points = PackedVector2Array()
		points.append(Vector2(0, -size))
		points.append(Vector2(size, 0))
		points.append(Vector2(0, size))
		points.append(Vector2(-size, 0))
		draw_colored_polygon(points, color)
		draw_polyline(points + PackedVector2Array([points[0]]), outline_color, 2.0, true)
	else:
		draw_circle(Vector2.ZERO, size, color)
		draw_arc(Vector2.ZERO, size, 0, TAU, 32, outline_color, 2.0, true)

	var icon: String
	match location_type:
		StrategyTypes.LocationType.CITY: icon = "C"
		StrategyTypes.LocationType.TOWN: icon = "T"
		StrategyTypes.LocationType.VILLAGE: icon = "V"
		StrategyTypes.LocationType.FORT: icon = "F"
		_: icon = ""
	if not icon.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(-5, 5), icon, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

func set_glowing(enabled: bool) -> void:
	_is_glowing = enabled
	set_process(enabled)
	queue_redraw()

func set_current(enabled: bool) -> void:
	_is_current = enabled
	set_process(enabled or _is_glowing)
	queue_redraw()

func _process(_delta: float) -> void:
	if _is_glowing or _is_current:
		queue_redraw()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	print(event)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		marker_clicked.emit(location_id)

func _on_mouse_entered() -> void:
	_is_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	_is_hovered = false
	queue_redraw()
