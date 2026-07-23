class_name FloatingControl
extends Control

signal drag_started(window: Control)
signal dragging(window: Control, global_pos: Vector2)
signal drag_ended(window: Control, global_pos: Vector2)
signal docked(dock: DockControl)
signal undocked()

@export var window_path: NodePath
@export var grab_node_path: NodePath
@export var grab_node_name: StringName = &"TitleBar"
@export var window_title: String = "Panel"

var window: Control
var grab: Control

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	window = get_node(window_path) if not window_path.is_empty() else _resolve_window()
	assert(window != null,
		"FloatingControl: no positionable window found — set window_path")
	assert(not (window.get_parent() is Container),
		"FloatingControl: window '%s' parent must be a Dock area or PanelLayer, not a raw Container" % window.name)
	grab = get_node(grab_node_path) if not grab_node_path.is_empty() else _find_grab(window)
	assert(grab != null,
		"FloatingControl: no grab node — add a Control named '%s' (or a Label), or set grab_node_path" % grab_node_name)
	add_to_group(&"floating_control")
	var dm := get_tree().get_first_node_in_group(&"desktop_manager")
	if dm != null:
		dm.register_window(self)


## Broadcast that this window entered/left a dock. Listeners (bookmarks, a parent
## that interprets the target dock) react; FloatingControl no longer sets anything
## directly.
func notify_docked(dock: DockControl) -> void:
	print("fc docked for prt: ",get_parent().name)
	docked.emit(dock)


func notify_undocked() -> void:
	undocked.emit()


func _resolve_window() -> Control:
	var n: Node = get_parent()
	while n != null:
		var p: Node = n.get_parent()
		if p == null or not (p is Container):
			return n as Control
		n = p
	return null


func _find_grab(root: Node) -> Control:
	var named := _find_by_name(root)
	return named if named != null else _find_first_label(root)


func _find_by_name(node: Node) -> Control:
	for child in node.get_children():
		if child == self:
			continue
		if child is Control and StringName(child.name) == grab_node_name:
			return child
		var nested := _find_by_name(child)
		if nested != null:
			return nested
	return null


func _find_first_label(node: Node) -> Control:
	for child in node.get_children():
		if child == self:
			continue
		if child is Label:
			return child
		var nested := _find_first_label(child)
		if nested != null:
			return nested
	return null


func _input(event: InputEvent) -> void:
	var grab_rect := grab.get_global_rect()
	var mouse_pos := get_global_mouse_position()
	
	#print("grab:",grab.position," mp:",mouse_pos)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if grab_rect.has_point(mouse_pos):
				_dragging = true
				window.move_to_front()
				window.rotation = 0.0
				window.pivot_offset = Vector2.ZERO
				#window.global_position = keep_global
				drag_started.emit(window)
				_drag_offset = mouse_pos - window.global_position
				accept_event()
				#get_viewport().set_input_as_handled()
		elif _dragging:
			_dragging = false
			drag_ended.emit(window, mouse_pos)
			#get_viewport().set_input_as_handled()
			accept_event()
			
	elif event is InputEventMouseMotion and _dragging:
		window.global_position = mouse_pos - _drag_offset
		dragging.emit(window, mouse_pos)
		accept_event()
		#get_viewport().set_input_as_handled()
