@tool
class_name GridLayout
extends DockLayout

## Uniform-cell grid (replaces a GridContainer). Cell size is the largest item.
## Sets the dock's custom_minimum_size so a wrapping ScrollContainer can scroll.

@export var columns: int = 5:
	set(v):
		columns = maxi(1, v)
		emit_changed()
@export var h_sep: float = 4.0:
	set(v):
		h_sep = v
		emit_changed()
@export var v_sep: float = 4.0:
	set(v):
		v_sep = v
		emit_changed()


func place(area: Control, items: Array[Control], apply: Callable) -> void:
	var n := items.size()
	if n == 0:
		area.custom_minimum_size = Vector2.ZERO
		return
	var cols := maxi(1, columns)
	var avail := area.size.x
	var cell_w := 0.0
	var cell_h := 0.0
	for item in items:
		cell_w = maxf(cell_w, item.size.x)
		cell_h = maxf(cell_h, item.size.y)
	if avail > 0.0:
		cell_w = maxf(0.0, (avail - float(cols - 1) * h_sep) / float(cols))
	for i in n:
		var item := items[i]
		var c := i % cols
		var r := i / cols
		if avail > 0.0:
			item.size.x = cell_w
		item.pivot_offset = Vector2.ZERO
		apply.call(item, Vector2(float(c) * (cell_w + h_sep), float(r) * (cell_h + v_sep)), 0.0)
	var rows := int(ceil(float(n) / float(cols)))
	area.custom_minimum_size = Vector2(
		float(cols) * cell_w + float(cols - 1) * h_sep,
		float(rows) * cell_h + float(maxi(0, rows - 1)) * v_sep)
