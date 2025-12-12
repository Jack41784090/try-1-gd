class_name LogicFactory

enum LogicAvailable {
	Frontline
}

static var pathlib = {
	"Frontline": "res://resources/combat/logic/logic/test-frontline.tres"
}
static var _cached_key = LogicAvailable.keys()
static func get_logic(_logic: LogicAvailable):
	var path = pathlib.get(_cached_key[_logic]);
	var logic = load(path)
	assert(logic != null, "Failed to load logic from path: %s" % path)
	assert(logic is SimplifiedLogicConfig, "Path %s loaded wrong type; got %s instead of SimplifiedLogicConfig" % [path, logic.get_class()])
	return logic
