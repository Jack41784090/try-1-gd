@tool
class_name DesktopManager
extends Control

## Generic drag coordinator. Owns the float layer + snap overlay. On drag end it
## finds the DockControl area under the cursor (by rect) and reparents the window
## into it — no special-cased sides/corners. Current dock is derived from the
## scene tree; a window's home is stored as node metadata.

@onready var _panel_layer: Control = %PanelLayer
@onready var _snap_overlay: Panel = %SnapOverlay

var _windows: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(&"desktop_manager")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_snap_overlay.hide()
	_snap_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for handle in get_tree().get_nodes_in_group(&"floating_control"):
		register_window(handle)


func register_window(handle: FloatingControl) -> void:
	var control := handle.window
	if _windows.has(control):
		return
	_windows[control] = handle
	var parent := control.get_parent()
	var dock := _dock_of_area(parent)
	if dock != null and dock.side == DockControl.DockSide.NONE:
		control.set_meta(&"home_area", parent)
		control.set_meta(&"home_index", control.get_index())
	handle.drag_started.connect(_on_drag_started)
	handle.dragging.connect(_on_dragging)
	handle.drag_ended.connect(_on_drag_ended)


func unregister_window(control: Control) -> void:
	if not _windows.has(control):
		return
	var dock := _dock_of_area(control.get_parent())
	if dock != null:
		dock.kill_item_tween(control)
	_windows.erase(control)


func _on_drag_started(window: Control) -> void:
	if not _windows.has(window):
		return
	if window.get_parent() != _panel_layer:
		_pop_out(window)


func _pop_out(window: Control) -> void:
	var dock := _dock_of_area(window.get_parent())
	if dock != null:
		dock.kill_item_tween(window)
	var keep_global := window.global_position
	window.reparent(_panel_layer, false)
	window.rotation = 0.0
	window.pivot_offset = Vector2.ZERO
	window.global_position = keep_global
	window.move_to_front()


func _on_dragging(window: Control, global_pos: Vector2) -> void:
	var dock := _find_best_dock_for_dragging_win(window, global_pos)
	if dock != null:
		var dock_area_rect := dock.area.get_global_rect()
		_snap_overlay.show()
		_snap_overlay.position = dock_area_rect.position - _panel_layer.global_position
		_snap_overlay.size = dock_area_rect.size


func _on_drag_ended(window: Control, global_pos: Vector2) -> void:
	_snap_overlay.hide()
	if _windows.has(window):
		var dock := _find_best_dock_for_dragging_win(window, global_pos)
		if dock != null:
			_dock_into(window, dock)


func _dock_into(window: Control, dock: DockControl) -> void:
	window.reparent(dock.area)
	if window.has_meta(&"home_area") and window.get_meta(&"home_area") == dock.area:
		var idx: int = clampi(int(window.get_meta(&"home_index")), 0, dock.area.get_child_count() - 1)
		dock.area.move_child(window, idx)


func _find_best_dock_for_dragging_win(dragging_window: Control, at_glob_pos: Vector2) -> DockControl:
	var best: DockControl = null
	var best_area := INF
	var docks_group = get_tree().get_nodes_in_group(&"dock_control")
	for d in docks_group:
		var dock := d as DockControl
		if \
			dock.area != null and dock.area != dragging_window \
			and dock.contains_point(at_glob_pos) \
			and dock.can_accept(dragging_window) \
			and not dragging_window.is_ancestor_of(dock.area):
			var dock_area_size := dock.area.get_global_rect().get_area()
			if dock_area_size < best_area:
				best = dock
				best_area = dock_area_size

	return best


func _dock_of_area(area: Node) -> DockControl:
	if area == null:
		return null
	for c in area.get_children():
		if c is DockControl:
			return c
	return null
