class_name EntityUpdate

var source: int
var affected: int
var change: EntityChange


func _to_string() -> String:
	if change == null or (change.from == -1 and change.to == -1):
		if change != null:
			return "[%d→%d] %s" % [source, affected, str(change)]
		return "no-op"
	if source == affected:
		return "[%d] %s" % [source, str(change)]
	return "[%d→%d] %s" % [source, affected, str(change)]


func _init(p_source: int, p_affected: int, p_change: EntityChange):
	source = p_source
	affected = p_affected
	change = p_change
