class_name AIProfileFactory extends RefCounted

const DEFAULT_SQUAD_PROFILE_PATH = "res://resources/ai/strategic/profiles/balanced-roamer.tres"
const CARAVAN_PROFILE_PATH = "res://resources/ai/strategic/profiles/caravan-courier.tres"

static var _squad_profile_cache: Dictionary = {}

static func get_squad_profile(path: String) -> SquadBrainConfig:
	var resolved_path := path.strip_edges()
	if resolved_path.is_empty():
		resolved_path = DEFAULT_SQUAD_PROFILE_PATH

	if _squad_profile_cache.has(resolved_path):
		var cached_profile := _squad_profile_cache[resolved_path] as SquadBrainConfig
		if cached_profile != null:
			return cached_profile
		_squad_profile_cache.erase(resolved_path)

	var profile := load(resolved_path) as SquadBrainConfig
	if profile == null and resolved_path != DEFAULT_SQUAD_PROFILE_PATH:
		push_warning("AIProfileFactory: Failed to load SquadBrainConfig from '%s'. Falling back to default profile." % resolved_path)
		resolved_path = DEFAULT_SQUAD_PROFILE_PATH
		if _squad_profile_cache.has(resolved_path):
			var default_cached := _squad_profile_cache[resolved_path] as SquadBrainConfig
			if default_cached != null:
				return default_cached
			_squad_profile_cache.erase(resolved_path)
		profile = load(resolved_path) as SquadBrainConfig

	assert(profile != null, "Failed to load default SquadBrainConfig from: %s" % DEFAULT_SQUAD_PROFILE_PATH)
	_squad_profile_cache[resolved_path] = profile
	return profile

static func get_default_squad_profile() -> SquadBrainConfig:
	return get_squad_profile(DEFAULT_SQUAD_PROFILE_PATH)


static func get_caravan_profile() -> SquadBrainConfig:
	return get_squad_profile(CARAVAN_PROFILE_PATH)

static func clear_cache() -> void:
	_squad_profile_cache.clear()
