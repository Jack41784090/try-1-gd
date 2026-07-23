class_name ReactiveStat
extends Resource

## only float and other ReactiveStat for now
@export var stat_value: Variant:
	set(_nv):
		stat_value = _nv
		emit_changed()
@export var stat_name: StatName.I
