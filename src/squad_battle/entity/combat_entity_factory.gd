class_name CombatEntityFactory

## Folder scanned for entity-template (.tres) identifications. Reassign to point the
## identification dropdown (CombatEntityResource) at a different folder.
static var identification_root := "res://resources/combat/classes/"


## File stems of the .tres templates in identification_root, sorted — the live list
## backing CombatEntityResource.identification. Scanned from disk so it reflects the
## actual folder contents (add/remove a template and the dropdown follows).
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


## Loads the CombatEntityResource template named `id` (one of
## available_identifications()).
static func get_resource(id: String) -> CombatEntityResource:
	var path := identification_root.path_join(id + ".tres")
	var res = load(path)
	assert(res != null, "No entity template at %s" % path)
	assert(res is CombatEntityResource, "%s is not a CombatEntityResource" % path)
	return res


## Template-only path — no Character, no StrategyEntity. Used by CombatSquad's
## scripted/demo-battle path (monsters/bandits, no persistent campaign identity):
## the template's own base-attribute ReactiveStats are the resolved constants,
## with nothing from a tier-2 StrategyEntity to override them.
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


## Builds a runtime CombatEntity from the template named `id`.
static func get_by_identification(
		id: String,
		side: SquadBattleTypes.Side,
		player_id: int,
		starting_location: SquadBattleTypes.SquadEntityInSquadLocation,
) -> CombatEntity:
	var res := get_resource(id)
	return CombatEntity.new(build_config_from_resource(res, side, player_id, starting_location))
