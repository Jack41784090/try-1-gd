class_name ClockDisplay
extends Control
## Analog clock: SVG face texture + dynamic hands drawn per-hour.

const HOUR_HAND_COLOR := Color(0.95, 0.90, 0.75, 1.0)
const MINUTE_HAND_COLOR := Color(0.80, 0.75, 0.60, 0.9)
const CENTER_DOT_COLOR := Color(0.85, 0.75, 0.50, 1.0)

var _hour: int = 0
var _face_tex: Texture2D = preload("res://assets/icons/clock_face.svg")


func set_hour(hour: int) -> void:
	_hour = hour % 24
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size / 2.0
	var radius: float = min(size.x, size.y) / 2.0 - 2.0

	draw_texture_rect(_face_tex, Rect2(Vector2.ZERO, size), false)

	var min_angle := _hour_to_angle(0)
	var min_tip := center + Vector2.from_angle(min_angle) * (radius * 0.62)
	var min_base_offset := Vector2.from_angle(min_angle) * 4.0
	var min_perp := Vector2.from_angle(min_angle + PI / 2.0)
	var min_points := PackedVector2Array(
		[
			center - min_base_offset + min_perp * 2.0,
			center - min_base_offset - min_perp * 2.0,
			min_tip - min_perp * 0.6,
			min_tip + min_perp * 0.6,
		],
	)
	draw_colored_polygon(min_points, MINUTE_HAND_COLOR)

	var hour_12 := _hour % 12
	var hr_angle := _hour_to_angle(hour_12)
	var hr_tip := center + Vector2.from_angle(hr_angle) * (radius * 0.48)
	var hr_base_offset := Vector2.from_angle(hr_angle) * 4.0
	var hr_perp := Vector2.from_angle(hr_angle + PI / 2.0)
	var hr_points := PackedVector2Array(
		[
			center - hr_base_offset + hr_perp * 3.5,
			center - hr_base_offset - hr_perp * 3.5,
			hr_tip - hr_perp * 1.0,
			hr_tip + hr_perp * 1.0,
		],
	)
	draw_colored_polygon(hr_points, HOUR_HAND_COLOR)
	draw_polyline(hr_points, Color(0, 0, 0, 0.4), 1.0, true)

	draw_circle(center, 3.5, CENTER_DOT_COLOR)
	draw_arc(center, 3.5, 0, TAU, 16, Color(0, 0, 0, 0.5), 1.0, true)


func _hour_to_angle(hour_val: int) -> float:
	return (float(hour_val) / 12.0) * TAU - PI / 2.0
