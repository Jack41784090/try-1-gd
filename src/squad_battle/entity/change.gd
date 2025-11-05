class_name EntityChange extends Resource

var property: SquadBattleTypes.EntityChangeable
var from: float
var to: float
var metadata: Dictionary = {}

var _cached_keys = SquadBattleTypes.EntityChangeable.keys()

func _to_string() -> String:
	return "EntityChange(property=%s, from=%f, to=%f, metadata=%s)" % [
		_cached_keys[property]
		, from, to, metadata]

func _init(p_property: SquadBattleTypes.EntityChangeable, p_from: float, p_to: float, p_metadata: Dictionary = {}):
	property = p_property
	from = p_from
	to = p_to
	metadata = p_metadata