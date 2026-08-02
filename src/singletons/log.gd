class_name Log
extends RefCounted

enum Level { TRACE, DEBUG, INFO, WARN, ERROR }

static var min_level: Level = Level.DEBUG
static var muted_sources: Dictionary = {}

static var _level_names: PackedStringArray = ["TRACE", "DEBUG", "INFO", "WARN", "ERROR"]


static func _log(level: Level, source: String, msg: String) -> void:
	if level < min_level:
		return
	if _is_muted(source):
		return
	print("[%s] [%s] %s" % [_level_names[level], source, msg])


static func trace(source: String, msg: String) -> void:
	_log(Level.TRACE, source, msg)


static func debug(source: String, msg: String) -> void:
	_log(Level.DEBUG, source, msg)


static func info(source: String, msg: String) -> void:
	_log(Level.INFO, source, msg)


static func warn(source: String, msg: String) -> void:
	_log(Level.WARN, source, msg)
	push_warning("[%s] %s" % [source, msg])


static func error(source: String, msg: String) -> void:
	_log(Level.ERROR, source, msg)
	push_error("[%s] %s" % [source, msg])


static func set_level(level: Level) -> void:
	min_level = level


static func _is_muted(source: String) -> bool:
	if muted_sources.has(source):
		return true
	for muted_key in muted_sources:
		if source.begins_with(muted_key):
			return true
	return false
