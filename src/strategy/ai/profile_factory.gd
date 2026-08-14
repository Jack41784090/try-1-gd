class_name AIProfileFactory extends RefCounted

const PROFILES: Registry = preload("res://resources/registries/profile_registry.tres")

const DEFAULT_SQUAD_PROFILE_PATH = "balanced_roamer"
# caravan-courier.tres currently fails to load (its considerations ext_resource
# points at a missing res://resources/ai/strategic/considerations/caravan-rest-when-out-of-food.tres),
# so it isn't registered — kept as a raw path so it still resolves once that's fixed.
const CARAVAN_PROFILE_PATH = "res://resources/ai/strategic/profiles/caravan-courier.tres"

static func get_squad_profile(id_or_path: String) -> SquadBrainConfig:
	var resolved := id_or_path.strip_edges()
	if resolved.is_empty():
		resolved = DEFAULT_SQUAD_PROFILE_PATH

	if PROFILES.has(resolved):
		return PROFILES.load_entry(resolved) as SquadBrainConfig

	# Back-compat fallback for callers still passing a raw res:// path.
	var profile := load(resolved) as SquadBrainConfig
	assert(profile != null, "AI profile not found: %s" % resolved)
	return profile

static func get_default_squad_profile() -> SquadBrainConfig:
	return get_squad_profile(DEFAULT_SQUAD_PROFILE_PATH)
