class_name WarriorRigConfigFactory extends RefCounted

## Resolves a character or class id to its WarriorRigConfig.
##
## Configs are named after who they dress, with an authoring prefix that isn't
## part of the identity (`wcr_adventurer_rachelle.tres` is rachelle's,
## `rig2_bishop.tres` is the bishop's), so the lookup is keyed on the id that
## remains once the prefix is stripped.

const CONFIG_BASE_PATH = "res://resources/animation/configs/"
const FALLBACK_ID = "landsknecht"
const AUTHORING_PREFIXES = ["wcr_adventurer_", "wcr_", "rig2_"]

static var _by_id: Dictionary = {}

static func get_config(id = null) -> WarriorRigConfig:
	if _by_id.is_empty():
		var dir := DirAccess.open(CONFIG_BASE_PATH)
		assert(dir != null, "Missing rig config folder: %s" % CONFIG_BASE_PATH)
		for file_name in dir.get_files():
			if not file_name.ends_with(".tres"):
				continue
			var key := file_name.trim_suffix(".tres")
			for prefix in AUTHORING_PREFIXES:
				key = key.trim_prefix(prefix)
			_by_id[key] = CONFIG_BASE_PATH + file_name

	var wanted := String(id).to_lower() if id != null else ""
	if not _by_id.has(wanted):
		if not wanted.is_empty():
			MyLog.warn("WarriorRigConfigFactory",
				"No rig config for '%s' — falling back to %s" % [wanted, FALLBACK_ID])
		wanted = FALLBACK_ID
	var config = load(_by_id[wanted]) as WarriorRigConfig
	assert(config != null, "Failed to load WarriorRigConfig from: %s" % _by_id[wanted])
	return config

static func clear_cache() -> void:
	_by_id.clear()
