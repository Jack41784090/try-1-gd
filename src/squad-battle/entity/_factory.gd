class_name EntityFactory

enum EntityClasses {
	Landsknecht,
	Healer
}

static var pathlib = {
	"Landsknecht": "res://resources/combat/classes/landsknecht.tres",
	"Healer": "res://resources/combat/classes/healer.tres"
}

static var _cached_key = EntityClasses.keys()
static func get_entity(_entity: EntityClasses) -> SquadEntity:
	var path = pathlib.get(_cached_key[_entity]);
	var entity_template = load(path)
	assert(entity_template != null, "Failed to load entity from path: %s" % path)
	assert(entity_template is SquadEntity, "Path %s loaded wrong type; got %s instead of SquadEntity" % [path, entity_template.get_class()])
	var entity = entity_template.duplicate(true)
	return entity
