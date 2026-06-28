@tool
class_name TabCarousel
extends Control

enum CarouselSide {
	Free,
	Left, 
	Right,
}

@export var side: CarouselSide = CarouselSide.Free:
	set(_s):
		side = _s
		match _s:
			CarouselSide.Left:
				position.x = 0
				size.y = get_parent_area_size().y
				pass
			CarouselSide.Right:
				position.x = get_parent_area_size().x
				size.y = get_parent_area_size().y
		_relayout()
@export var bulge: float = 110.0:
	set(v):
		bulge = v
		_relayout()
@export var vertical_margin: float = 120.0:
	set(v):
		vertical_margin = v
		_relayout()
@export_range(0.0, 2.0) var spread: float = 1.0:
	set(v):
		spread = v
		_relayout()
@export var tilt_deg: float = 22.0:
	set(v):
		tilt_deg = v
		_relayout()
@export var flip: bool = false:
	set(v):
		flip = v
		_relayout()
@export var anim_time: float = 0.22

func _ready() -> void:
	resized.connect(_relayout)
	child_entered_tree.connect(_on_child_entered)
	child_exiting_tree.connect(_on_child_exiting)
	size.y = get_parent_area_size().y
	_relayout()
	for item in _items():
		_notify_dock_side(item)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				accept_event()

func add_item(item: Control) -> void:
	add_child(item)


func remove_item(item: Control) -> void:
	remove_child(item)


func _on_child_entered(node: Node) -> void:
	if node is Control:
		_notify_dock_side.call_deferred(node)
	_refresh_spread.call_deferred()


func _on_child_exiting(node: Node) -> void:
	if node is Control:
		_notify_dock_side(node)
	_refresh_spread.call_deferred()


func _notify_dock_side(node: Node) -> void:
	if not is_instance_valid(node):
		return
	for c in node.get_children():
		if c.has_method(&"set_dock_side"):
			c.set_dock_side(side)
			return


func _refresh_spread() -> void:
	spread = float(get_child_count()) / 8.0


func _relayout() -> void:
	if not is_inside_tree():
		return
	var items := _items()
	var n := items.size()
	if n == 0:
		return
	var side := 1.0 if flip else -1.0
	var ry: float = maxf(0.0, size.y * 0.5 - vertical_margin)
	var cy := size.y * 0.5
	var base_x := bulge if flip else size.x - bulge
	for i in n:
		var item := items[i]
		var t := (float(i) + 0.5) / float(n)
		var angle_deg := lerpf(-90.0, 90.0, t) * spread
		var angle := deg_to_rad(angle_deg)
		var px := base_x + side * cos(angle) * bulge
		var py := cy + sin(angle) * ry
		var rot := deg_to_rad(-side * (angle_deg / 90.0) * tilt_deg)
		item.pivot_offset = item.size * 0.5
		_apply_tween(item, Vector2(px, py) - item.size * 0.5, rot)
		if side != CarouselSide.Free:
			item


func _items() -> Array[Control]:
	var out: Array[Control] = []
	for c in get_children():
		if c is Control:
			out.append(c)
	return out


func _apply_tween(item: Control, dest_pos: Vector2, dest_rot: float) -> void:
	kill_item_tween(item)
	if Engine.is_editor_hint() or anim_time <= 0.0:
		item.position = dest_pos
		item.rotation = dest_rot
		return
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(item, "position", dest_pos, anim_time)
	t.tween_property(item, "rotation", dest_rot, anim_time)
	item.set_meta(&"carousel_tween", t)


func kill_item_tween(item: Control) -> void:
	if item.has_meta(&"carousel_tween"):
		var old: Tween = item.get_meta(&"carousel_tween")
		if old != null and old.is_valid():
			old.kill()
		item.remove_meta(&"carousel_tween")
