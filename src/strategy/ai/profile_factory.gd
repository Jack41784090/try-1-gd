class_name AIProfileFactory extends RefCounted

const DEFAULT_SQUAD_PROFILE_PATH = "res://resources/ai/strategic/profiles/balanced-roamer.tres"

static var _squad_profile_cache: Dictionary = {}

static func get_squad_profile(path: String) -> SquadBrainConfig:
	if _squad_profile_cache.has(path):
		return _squad_profile_cache[path]

	var profile = load(path) as SquadBrainConfig
	assert(profile != null, "Failed to load SquadBrainConfig from: %s" % path)
	_squad_profile_cache[path] = profile
	return profile

static func get_default_squad_profile() -> SquadBrainConfig:
	return get_squad_profile(DEFAULT_SQUAD_PROFILE_PATH)

static func clear_cache() -> void:
	_squad_profile_cache.clear()
