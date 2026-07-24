class_name StrategyEntityResource
extends Resource

@export var name: String
@export var social_class: StrategyTypes.SocialClass
@export var religion: StrategyTypes.Religion
@export var identification: String = ""
@export var rs_array: Array[ReactiveStat] = []


func get_stat(key: StatName.I) -> ReactiveStat:
	for rs in rs_array:
		if rs.stat_name == key:
			return rs
	return null


func get_stat_value(key: StatName.I) -> Variant:
	var s := get_stat(key)
	return s.stat_value if s else null
