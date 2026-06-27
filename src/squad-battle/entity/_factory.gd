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


## Builds a runtime CombatEntity from the template named `id`.
## DISABLED: CombatEntity.from_resource() is commented out during the
## runtime/template rewrite. Stubbed to keep callers parsing.
static func get_by_identification(_id: String) -> CombatEntity:
	push_error("CombatEntityFactory.get_by_identification disabled during CombatEntity rewrite")
	return null
	# return CombatEntity.from_resource(get_resource(id))


static var pathlib = {
	"Landsknecht": "res://resources/combat/classes/landsknecht.tres",
	"Healer": "res://resources/combat/classes/healer.tres",
	"Crossbowman": "res://resources/combat/classes/crossbowman.tres",
	"Arquebusier": "res://resources/combat/classes/arquebusier.tres",
	"Pikeman": "res://resources/combat/classes/pikeman.tres",
	"Feldprediger": "res://resources/combat/classes/feldprediger.tres",
	"Gelehrter": "res://resources/combat/classes/gelehrter.tres",
}

# static var _cached_key = EntityClasses.Types.keys()


# static func get_entity(_entity: EntityClasses.Types) -> CombatEntity:
# 	var path = pathlib.get(_cached_key[_entity])
# 	var entity_template = load(path)
# 	assert(entity_template != null, "Failed to load entity from path: %s" % path)
# 	assert(entity_template is CombatEntityResource, "Path %s loaded wrong type; got %s instead of CombatEntityResource" % [path, entity_template.get_class()])
# 	return CombatEntity.from_resource(entity_template)


# static func quick_dummy():
# 	return CombatEntity.new(
# 		EntityConfig.new(
# 			EntityClasses.Types.Landsknecht,
# 			0,
# 			"Dummy",
# 			"Dummy",
# 			CombatEntityBaseStats.new(),
# 			SquadBattleTypes.SquadEntityInSquadLocation.Front,
# 			LogicFactory.LogicAvailable.Frontline,
# 			null,
# 			SquadBattleTypes.WeaponClasses.Unarmed,
# 			null,
# 			SquadBattleTypes.ArmorClasses.Unarmored,
# 		),
# 	)
