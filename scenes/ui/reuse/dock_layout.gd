@tool
class_name DockLayout
extends Resource

## Base strategy for arranging a dock area's window-children. Subclasses override
## place(): read geometry from `area` (a plain Control) and position each item via
## the `apply` Callable (DockControl.apply_item), keeping the layout decoupled from
## the DockControl type.

func place(_area: Control, _items: Array[Control], _apply: Callable) -> void:
	pass
