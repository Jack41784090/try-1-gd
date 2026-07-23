@tool
class_name FillLayout
extends DockLayout

## Snaps every item to fill the dock area. For single-slot docks
## (WeaponDock/ArmorDock) whose area is a plain Panel, not a Container.

func place(area: Control, items: Array[Control], apply: Callable) -> void:
	for item in items:
		item.pivot_offset = Vector2.ZERO
		item.size = area.size
		apply.call(item, Vector2.ZERO, 0.0)
