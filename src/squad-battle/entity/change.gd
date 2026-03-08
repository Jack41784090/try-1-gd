class_name EntityChange extends Resource

var property: SquadBattleTypes.EntityChangeable
var from: float
var to: float
var metadata: Dictionary = {}

var _cached_keys = SquadBattleTypes.EntityChangeable.keys()

func _to_string() -> String:
	var prop_name = _cached_keys[property]
	if from == -1 and to == -1:
		return prop_name
	return "%s %.1f→%.1f" % [prop_name, from, to]

func _init(p_property: SquadBattleTypes.EntityChangeable, p_from: float=-1, p_to: float=-1, p_metadata: Dictionary = {}):
	property = p_property
	from = p_from
	to = p_to
	metadata = p_metadata