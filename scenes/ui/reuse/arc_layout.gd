@tool
class_name ArcLayout
extends DockLayout

## Elliptical half-arc (the carousel). Items fan across a 12->6 o'clock arc that
## widens as more are added (full arc at fan_count items).

@export var bulge: float = 110.0:
	set(v):
		bulge = v
		emit_changed()
@export var vertical_margin: float = 120.0:
	set(v):
		vertical_margin = v
		emit_changed()
@export var tilt_deg: float = 22.0:
	set(v):
		tilt_deg = v
		emit_changed()
@export var flip: bool = false:
	set(v):
		flip = v
		emit_changed()
@export var fan_count: float = 8.0:
	set(v):
		fan_count = maxf(1.0, v)
		emit_changed()


func place(area: Control, items: Array[Control], apply: Callable) -> void:
	var n := items.size()
	if n == 0:
		return
	var s := 1.0 if flip else -1.0
	var eff_spread := minf(1.0, float(n) / fan_count)
	var ry: float = maxf(0.0, area.size.y * 0.5 - vertical_margin)
	var cy := area.size.y * 0.5
	var base_x := bulge if flip else area.size.x - bulge
	for i in n:
		var item := items[i]
		var t := (float(i) + 0.5) / float(n)
		var angle_deg := lerpf(-90.0, 90.0, t) * eff_spread
		var angle := deg_to_rad(angle_deg)
		var px := base_x + s * cos(angle) * bulge
		var py := cy + sin(angle) * ry
		var rot := deg_to_rad(-s * (angle_deg / 90.0) * tilt_deg)
		item.pivot_offset = item.size * 0.5
		apply.call(item, Vector2(px, py) - item.size * 0.5, rot)
