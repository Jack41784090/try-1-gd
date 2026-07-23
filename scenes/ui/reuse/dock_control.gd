@tool
class_name DockControl
extends Control

## Composition component (like FloatingControl): drop it in and point it at an
## "area" Control via area_path (default: its parent). It arranges the area's
## window-children with a DockLayout and registers the area as a drop target.
## A home dock has side == NONE; edge carousels use LEFT/RIGHT.

enum DockSide { NONE, LEFT, RIGHT }

@export var area_path: NodePath
@export var layout: DockLayout:
	set(v):
		if layout != null and layout.changed.is_connected(_relayout):
			layout.changed.disconnect(_relayout)
		layout = v
		if layout != null and not layout.changed.is_connected(_relayout):
			layout.changed.connect(_relayout)
		_relayout()
@export var side: DockSide = DockSide.NONE:
	set(v):
		side = v
		_relayout()
@export var anim_time: float = 0.22

var area: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	area = get_node(area_path) if not area_path.is_empty() else get_parent() as Control
	assert(area != null, "DockControl: no area — set area_path or parent to a Control")
	area.child_entered_tree.connect(_on_area_child_entered)
	area.child_exiting_tree.connect(_on_area_child_exiting)
	if not area.resized.is_connected(_relayout):
		area.resized.connect(_relayout)
	if layout != null and not layout.changed.is_connected(_relayout):
		layout.changed.connect(_relayout)
	add_to_group(&"dock_control")
	_relayout()
	for w in _items():
		_notify(w, true)


func contains_point(global_pos: Vector2) -> bool:
	return area != null and area.get_global_rect().has_point(global_pos)


## Override to reject dragged windows. DesktopManager consults this before
## showing the snap overlay and before docking.
func can_accept(_window: Control) -> bool:
	return true


func _on_area_child_entered(node: Node) -> void:
	print("child entered docker: ",node.name," -> ", get_parent().name)
	if _is_window(node):
		_notify.call_deferred(node, true)
	_relayout.call_deferred()


func _on_area_child_exiting(node: Node) -> void:
	if _is_window(node):
		_notify(node, false)
	_relayout.call_deferred()


func _notify(node: Node, docked: bool) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(node):
		return
	var fc := _find_float_control(node)
	if fc == null:
		return
	if docked:
		fc.notify_docked(self)
	else:
		fc.notify_undocked()


func _relayout() -> void:
	if area == null or not area.is_inside_tree():
		return
	if layout != null:
		layout.place(area, _items(), apply_item)


func _items() -> Array[Control]:
	var out: Array[Control] = []
	for c in area.get_children():
		if c is Control and not c.is_queued_for_deletion() and _is_window(c):
			out.append(c)
	return out


func _is_window(node: Node) -> bool:
	return node != self and node is Control and not (node is FloatingControl) and not (node is DockControl)


func _find_float_control(node: Node) -> FloatingControl:
	for c in node.get_children():
		if c is FloatingControl:
			return c
	return null


func apply_item(item: Control, dest_pos: Vector2, dest_rot: float) -> void:
	kill_item_tween(item)
	if Engine.is_editor_hint() or anim_time <= 0.0:
		item.position = dest_pos
		item.rotation = dest_rot
		return
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(item, "position", dest_pos, anim_time)
	t.tween_property(item, "rotation", dest_rot, anim_time)
	item.set_meta(&"dock_tween", t)


func kill_item_tween(item: Control) -> void:
	if item.has_meta(&"dock_tween"):
		var old: Tween = item.get_meta(&"dock_tween")
		if old != null and old.is_valid():
			old.kill()
		item.remove_meta(&"dock_tween")
