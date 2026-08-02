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
	assert(profile != null, "AI profile not found: %s" % resolved_path)
	_squad_profile_cache[resolved_path] = profile
	return profile

static func get_default_squad_profile() -> SquadBrainConfig:
	return get_squad_profile(DEFAULT_SQUAD_PROFILE_PATH)
