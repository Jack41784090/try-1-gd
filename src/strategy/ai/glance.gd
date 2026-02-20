class_name StrategicGlance extends Resource

@export var subject: StrategicAITypes.GlanceSubject = StrategicAITypes.GlanceSubject.SQUAD
@export var squad_property: StrategicAITypes.SquadGlanceable = StrategicAITypes.SquadGlanceable.FOOD
@export var location_property: StrategicAITypes.LocationGlanceable = StrategicAITypes.LocationGlanceable.STABILITY
@export var world_property: StrategicAITypes.WorldGlanceable = StrategicAITypes.WorldGlanceable.TURN_COUNT
@export var faction_property: StrategicAITypes.FactionGlanceable = StrategicAITypes.FactionGlanceable.REPUTATION
@export var normalize_max: float = 0.0
@export var use_comparison: bool = false
@export var comparison: CsdrTypes.DETECTION = CsdrTypes.DETECTION.ABOVE
@export var threshold: float = 0.0
@export var inverse: bool = false
@export var activity_type_filter: StrategyTypes.ActivityType = StrategyTypes.ActivityType.REST
@export var location_type_filter: StrategyTypes.LocationType = StrategyTypes.LocationType.VILLAGE
@export var additional_glance: StrategicGlance = null
@export var operation_on_other_glance: CsdrTypes.OP = CsdrTypes.OP.MUL

func evaluate(situation: StrategicSituation) -> float:
	var value := _get_raw_value(situation)

	if normalize_max > 0.0:
		value = clamp(value / normalize_max, 0.0, 1.0)

	if inverse:
		value = 1.0 - value

	if additional_glance != null:
		var other_value = additional_glance.evaluate(situation)
		match operation_on_other_glance:
			CsdrTypes.OP.ADD:
				value += other_value
			CsdrTypes.OP.RDC:
				value -= other_value
			CsdrTypes.OP.MUL:
				value *= other_value
			CsdrTypes.OP.AVG:
				value = (value + other_value) / 2.0

	if use_comparison and not _check_condition(value):
		value = 0.0

	return value

func _get_raw_value(situation: StrategicSituation) -> float:
	match subject:
		StrategicAITypes.GlanceSubject.SQUAD:
			return _get_squad_value(situation)
		StrategicAITypes.GlanceSubject.LOCATION:
			return _get_location_value(situation)
		StrategicAITypes.GlanceSubject.WORLD:
			return _get_world_value(situation)
		StrategicAITypes.GlanceSubject.FACTION:
			return _get_faction_value(situation)
		_:
			assert(false, "Unknown GlanceSubject: %s" % subject)
			return 0.0

func _get_squad_value(situation: StrategicSituation) -> float:
	match squad_property:
		StrategicAITypes.SquadGlanceable.FOOD:
			return float(situation.squad.food)
		StrategicAITypes.SquadGlanceable.MONEY:
			return situation.squad.money
		StrategicAITypes.SquadGlanceable.MORALE:
			return situation.squad.get_morale()
		StrategicAITypes.SquadGlanceable.WARRIOR_COUNT:
			return float(situation.squad.get_living_warriors().size())
		StrategicAITypes.SquadGlanceable.KARMA:
			return situation.squad.karma
		StrategicAITypes.SquadGlanceable.TRAVEL_TOOLS:
			return float(situation.squad.travel_tools)
		StrategicAITypes.SquadGlanceable.HIGHEST_ENEMY_CONTACT:
			return situation.highest_contact_on_us
		StrategicAITypes.SquadGlanceable.OUR_BEST_CONTACT:
			return situation.our_best_contact
		StrategicAITypes.SquadGlanceable.CAN_AMBUSH:
			return 1.0 if situation.can_ambush else 0.0
		_:
			assert(false, "Unknown SquadGlanceable: %s" % squad_property)
			return 0.0

func _get_location_value(situation: StrategicSituation) -> float:
	match location_property:
		StrategicAITypes.LocationGlanceable.STABILITY:
			return situation.location.stability
		StrategicAITypes.LocationGlanceable.DEVELOPMENT:
			return float(situation.location.development)
		StrategicAITypes.LocationGlanceable.ENEMY_COUNT:
			return float(situation.enemies_here.size())
		StrategicAITypes.LocationGlanceable.ACTIVE_CLUE_COUNT:
			return float(situation.location.get_active_clues(situation.world.turn_count).size())
		StrategicAITypes.LocationGlanceable.HAS_ACTIVITY:
			return 1.0 if situation.location.has_activity_type(activity_type_filter) else 0.0
		StrategicAITypes.LocationGlanceable.TYPE:
			return 1.0 if situation.location.type == location_type_filter else 0.0
		_:
			assert(false, "Unknown LocationGlanceable: %s" % location_property)
			return 0.0

func _get_world_value(situation: StrategicSituation) -> float:
	match world_property:
		StrategicAITypes.WorldGlanceable.TURN_COUNT:
			return float(situation.world.turn_count)
		StrategicAITypes.WorldGlanceable.ADJACENT_ENEMY_COUNT:
			return float(situation.adjacent_enemies.size())
		StrategicAITypes.WorldGlanceable.NEAREST_ENEMY_DISTANCE:
			return float(situation.nearest_enemy_distance)
		StrategicAITypes.WorldGlanceable.NEAREST_TOWN_DISTANCE:
			return float(situation.nearest_town_distance)
		_:
			assert(false, "Unknown WorldGlanceable: %s" % world_property)
			return 0.0

func _get_faction_value(situation: StrategicSituation) -> float:
	if situation.faction == null:
		return 0.0
	match faction_property:
		StrategicAITypes.FactionGlanceable.REPUTATION:
			return situation.faction.get_reputation()
		StrategicAITypes.FactionGlanceable.ARMY_COUNT:
			return float(situation.faction.armies.size())
		_:
			assert(false, "Unknown FactionGlanceable: %s" % faction_property)
			return 0.0

func _check_condition(value: float) -> bool:
	match comparison:
		CsdrTypes.DETECTION.EQUAL:
			return value == threshold
		CsdrTypes.DETECTION.ABOVE:
			return value > threshold
		CsdrTypes.DETECTION.BELOW:
			return value < threshold
		_:
			return false
