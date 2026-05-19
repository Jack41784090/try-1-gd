class_name WarriorRigConfigFactory extends RefCounted

const CONFIG_BASE_PATH = "res://resources/animation/configs/"

static var _default_config: WarriorRigConfig = null

static func get_config(_class_id = null) -> WarriorRigConfig:
	if _default_config:
		return _default_config
	var path = CONFIG_BASE_PATH + "landsknecht.tres"
	if ResourceLoader.exists(path):
		var config = load(path) as WarriorRigConfig
		assert(config != null, "Failed to load WarriorRigConfig from: %s" % path)
		_default_config = config
		return config
	return null

static func get_default_config() -> WarriorRigConfig:
	return get_config()

static func clear_cache() -> void:
	_default_config = null
