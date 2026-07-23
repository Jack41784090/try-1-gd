@tool
class_name TypedDock
extends DockControl

## DockControl that only accepts specific window types. Lives next to the
## manage-squad UI (not in reuse/) because it references game window classes.

enum WindowKind { UNIT, WEAPON, ARMOR }

@export var accepted: Array[WindowKind] = []


func can_accept(window: Control) -> bool:
	for kind in accepted:
		match kind:
			WindowKind.UNIT:
				if window is UnitItem:
					return true
			WindowKind.WEAPON:
				if window is WeaponControl:
					return true
			WindowKind.ARMOR:
				if window is ArmorControl:
					return true
	return false
