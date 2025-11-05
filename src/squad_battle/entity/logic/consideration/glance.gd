class_name Glance extends Resource

@export var property: SquadBattleTypes.EntityChangeable
@export var dynamic_normalise_by: SquadBattleTypes.EntityChangeable = -1
@export var normalise_by: float = 1.0

func evaluate(entity: SquadEntity) -> float:
	var value = entity.changeable_stats.get(property, 0.0)
	
	if dynamic_normalise_by != -1:
		if normalise_by != 1.0:
			push_warning("Glance has both dynamic_normalise_by and normalise_by set. Using dynamic_normalise_by.")
		var divisor = entity.get_ceiling_changeable_stat(dynamic_normalise_by)
		if divisor > 0:
			value = value / divisor
		return value
	
	if normalise_by > 0:
		value = value / normalise_by
	
	return value

