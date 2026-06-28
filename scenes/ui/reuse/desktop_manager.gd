@tool
class_name DesktopManager
extends Control

@export var snap_anim_time: float = 0.18
@export var corner_band: float = 0.25
@export var collapse_gutter_px: float = 56.0

@onready var _panel_layer: Control = %PanelLayer
@onready var _snap_overlay: Panel = %SnapOverlay
@onready var _left_tab_bar: TabCarousel = %LeftTabBar
@onready var _right_tab_bar: TabCarousel = %RightTabBar

var _windows: Dictionary = { }


func _ready() -> void:
	_snap_overlay.hide()
	_snap_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for handle in get_tree().get_nodes_in_group(&"floating_control"):
		_register(handle)


func _register(handle: FloatingControl) -> void:
	var window := handle.window
	_windows[window] = {
		"floating_rect": Rect2(window.position, window.size),
		"bar": null,
	}
	handle.drag_started.connect(_on_drag_started)
	handle.dragging.connect(_on_dragging)
	handle.drag_ended.connect(_on_drag_ended)


func _on_drag_started(window: Control) -> void:
	var state: Dictionary = _windows[window]
	var bar: TabCarousel = state["bar"]
	if bar == null:
		return
	state["bar"] = null
	bar.kill_item_tween(window)
	var keep_global: Vector2 = window.global_position
	window.reparent(_panel_layer, false)
	window.rotation = 0.0
	window.pivot_offset = Vector2.ZERO
	window.global_position = keep_global
	window.move_to_front()


func _collapse_side(global_pos: Vector2) -> int:
	var local_x := global_pos.x - _panel_layer.global_position.x
	if local_x <= collapse_gutter_px:
		return -1
	if local_x >= _panel_layer.size.x - collapse_gutter_px:
		return 1
	return 0


func _on_dragging(_window: Control, global_pos: Vector2) -> void:
	var side := _collapse_side(global_pos)
	if side != 0:
		var w := collapse_gutter_px
		_snap_overlay.show()
		_snap_overlay.size = Vector2(w, _panel_layer.size.y)
		_snap_overlay.position = Vector2(0.0 if side < 0 else _panel_layer.size.x - w, 0.0)
	else:
		var target := _target_rect(global_pos)
		if target.size == Vector2.ZERO:
			_snap_overlay.hide()
		else:
			_snap_overlay.show()
			_snap_overlay.position = target.position
			_snap_overlay.size = target.size
	


func _on_drag_ended(window: Control, global_pos: Vector2) -> void:
	_snap_overlay.hide()
	var side := _collapse_side(global_pos)
	if side != 0:
		_dock(window, _left_tab_bar if side < 0 else _right_tab_bar)
		return
	_windows[window]["floating_rect"] = Rect2(window.position, window.size)
	var target := _target_rect(global_pos)
	if target.size != Vector2.ZERO:
		_animate_to(window, target)


func _dock(window: Control, bar: TabCarousel) -> void:
	var state: Dictionary = _windows[window]
	if state["bar"] != null:
		return
	state["floating_rect"] = Rect2(window.position, window.size)
	state["bar"] = bar
	window.reparent(bar)


func _target_rect(global_pos: Vector2) -> Rect2:
	var area := _panel_layer.size
	var local := global_pos - _panel_layer.global_position
	var fx := local.x / area.x
	var fy := local.y / area.y
	var c := corner_band
	if fx <= c and fy <= c:
		return _zone(0.0, 0.0, 0.5, 0.5, area)
	if fx >= 1.0 - c and fy <= c:
		return _zone(0.5, 0.0, 0.5, 0.5, area)
	if fx <= c and fy >= 1.0 - c:
		return _zone(0.0, 0.5, 0.5, 0.5, area)
	if fx >= 1.0 - c and fy >= 1.0 - c:
		return _zone(0.5, 0.5, 0.5, 0.5, area)
	return Rect2()


func _zone(x: float, y: float, w: float, h: float, area: Vector2) -> Rect2:
	return Rect2(Vector2(x, y) * area, Vector2(w, h) * area)


func _animate_to(window: Control, target: Rect2) -> void:
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(window, "position", target.position, snap_anim_time)
	t.tween_property(window, "size", target.size, snap_anim_time)
