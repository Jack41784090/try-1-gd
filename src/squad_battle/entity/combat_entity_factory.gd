class_name CombatEntityFactory

## Reassign to point the CombatEntityResource identification dropdown at a different folder.
static var identification_root := "res://resources/combat/classes/"


## Scanned from disk (not cached), so add/remove a template and the dropdown follows.
static func available_identifications() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(identification_root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tres"):
			out.append(f.trim_suffix(".tres"))
	out.sort()
	return out


static func get_resource(id: String) -> CombatEntityResource:
	var path := identification_root.path_join(id + ".tres")
	var res = load(path)
	assert(res != null, "No entity template at %s" % path)
	assert(res is CombatEntityResource, "%s is not a CombatEntityResource" % path)
	return res


## Template-only path (monsters/bandits): the template's base-attribute ReactiveStats resolve as-is, with no tier-2 StrategyEntity override.
static func build_config_from_resource(
		res: CombatEntityResource,
		side: SquadBattleTypes.Side,
		player_id: int,
		starting_location: SquadBattleTypes.SquadEntityInSquadLocation,
) -> CombatEntityConfig:
	var resolved: Dictionary[StatName.I, Variant] = {}
	for key in StatName.BASE_ATTRIBUTE_STATS:
		resolved[key] = res.get_stat_value(key)
	return CombatEntityConfig.new(res, side, player_id, starting_location, resolved)


static func get_by_identification(
		id: String,
		side: SquadBattleTypes.Side,
		player_id: int,
		starting_location: SquadBattleTypes.SquadEntityInSquadLocation,
) -> CombatEntity:
	var res := get_resource(id)
	return CombatEntity.new(build_config_from_resource(res, side, player_id, starting_location))
