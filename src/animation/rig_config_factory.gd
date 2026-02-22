class_name WarriorRigConfigFactory extends RefCounted

const CONFIG_BASE_PATH = "res://resources/animation/configs/"

static var _cache: Dictionary = {}

static func get_config(class_id: EntityClasses.Types) -> WarriorRigConfig:
	if _cache.has(class_id):
		return _cache[class_id]

	var path = CONFIG_BASE_PATH + _class_id_to_filename(class_id)
	if ResourceLoader.exists(path):
		var config = load(path) as WarriorRigConfig
		assert(config != null, "Failed to load WarriorRigConfig from: %s" % path)
		_cache[class_id] = config
		return config

	return null

static func clear_cache() -> void:
	_cache.clear()

static func _class_id_to_filename(class_id: EntityClasses.Types) -> String:
	match class_id:
		EntityClasses.Types.Landsknecht:
			return "landsknecht.tres"
		EntityClasses.Types.Healer:
			return "healer.tres"
		_:
			return "landsknecht.tres"
