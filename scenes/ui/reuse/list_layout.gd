@tool
class_name ListLayout
extends DockLayout

## Vertical stack (replaces a VBoxContainer). Sets the dock's
## custom_minimum_size.y so a wrapping ScrollContainer can scroll the content.

@export var spacing: float = 6.0:
	set(v):
		spacing = v
		emit_changed()
@export var padding: float = 0.0:
	set(v):
		padding = v
		emit_changed()
@export var stretch_width: bool = true:
	set(v):
		stretch_width = v
		emit_changed()


func place(area: Control, items: Array[Control], apply: Callable) -> void:
	var y := padding
	var max_w := 0.0
	for item in items:
		item.pivot_offset = Vector2.ZERO
		if stretch_width and area.size.x > 0.0:
			item.size.x = maxf(0.0, area.size.x - padding * 2.0)
		apply.call(item, Vector2(padding, y), 0.0)
		y += item.size.y + spacing
		max_w = maxf(max_w, item.size.x)
	if items.size() > 0:
		y -= spacing
	area.custom_minimum_size = Vector2(max_w + padding * 2.0, y + padding)
