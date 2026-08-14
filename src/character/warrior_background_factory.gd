class_name WarriorBackgroundFactory extends RefCounted

const BACKGROUNDS_DIR := "res://resources/strategy/warrior-presets/"

static var _registry: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var dir := DirAccess.open(BACKGROUNDS_DIR)
	if dir == null:
		MyLog.warn("WarriorBackgroundFactory", "Backgrounds directory not found: %s" % BACKGROUNDS_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(BACKGROUNDS_DIR + file_name) as WarriorBackground
			if res and not res.background_id.is_empty():
				_registry[res.background_id] = res
		file_name = dir.get_next()
	dir.list_dir_end()


static func get_background(background_id: StringName) -> WarriorBackground:
	_ensure_loaded()
	var bg: WarriorBackground = _registry.get(background_id, null)
	assert(bg != null, "WarriorBackground not found: %s" % background_id)
	return bg


static func all() -> Array[WarriorBackground]:
	_ensure_loaded()
	var result: Array[WarriorBackground] = []
	for key in _registry:
		result.append(_registry[key])
	return result

