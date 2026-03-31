class_name StrategicGlance
extends Resource

@export var subject: StrategicAITypes.GlanceSubject = StrategicAITypes.GlanceSubject.SQUAD
@export var squad_property: StrategicAITypes.SquadGlanceable = StrategicAITypes.SquadGlanceable.FOOD
@export var location_property: StrategicAITypes.LocationGlanceable = StrategicAITypes.LocationGlanceable.STABILITY
@export var world_property: StrategicAITypes.WorldGlanceable = StrategicAITypes.WorldGlanceable.HOUR_COUNT
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
@export var trade_property: StrategicAITypes.TradeGlanceable = StrategicAITypes.TradeGlanceable.PROFIT_MARGIN


func evaluate(situation) -> float:
	# Reads a single world property from the situation, normalizes, inverts, chains, and filters it
	# Pipeline: raw_value → normalize → inverse → chain additional_glance → comparison gate
	# e.g., Glance(subject=SQUAD, squad_property=FOOD, normalize_max=100, inverse=true)
	#   → raw=20 → normalize(20/100)=0.2 → inverse(1.0-0.2)=0.8
	# e.g., Glance(subject=LOCATION, location_property=ENEMY_COUNT, use_comparison=true, comparison=ABOVE, threshold=0)
	#   → raw=2 → no normalize → no inverse → check: 2 > 0 → passes → returns 2.0

	# 1. Get the raw numeric value based on subject + property
	# e.g., SQUAD.FOOD → squad.food = 20
	var value := _get_raw_value(situation)

	# 2. Normalize to [0,1] if normalize_max is set
	# e.g., value=20, normalize_max=100 → 0.2
	if normalize_max > 0.0:
		value = clamp(value / normalize_max, 0.0, 1.0)

	# 3. Invert: makes "low food" into "high urgency"
	# e.g., 0.2 → 0.8 (squad with low food gets high forage urgency)
	if inverse:
		value = 1.0 - value

	# 4. Chain with another glance using an operation (MUL, ADD, RDC, AVG)
	# e.g., food_urgency(0.8) MUL has_market(1.0) = 0.8 (both must be true)
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

	# 5. Gate: if use_comparison is on, value must pass the threshold check or return 0
	# e.g., comparison=ABOVE, threshold=0.5 → value=0.3 → returns 0.0 (below threshold)
	if use_comparison and not _check_condition(value):
		value = 0.0

	return value


func _get_raw_value(situation: StrategicSituation) -> float:
	# Routes to the correct value getter based on the configured subject
	# e.g., subject=SQUAD → _get_squad_value() reads squad.food, squad.morale, etc.
	# e.g., subject=LOCATION → _get_location_value() reads location.stability, enemy_count, etc.
	match subject:
		StrategicAITypes.GlanceSubject.SQUAD:
			return _get_squad_value(situation)
		StrategicAITypes.GlanceSubject.LOCATION:
			return _get_location_value(situation)
		StrategicAITypes.GlanceSubject.WORLD:
			return _get_world_value(situation)
		StrategicAITypes.GlanceSubject.FACTION:
			return _get_faction_value(situation)
		StrategicAITypes.GlanceSubject.TRADE:
			return _get_trade_value(situation)
		_:
			assert(false, "Unknown GlanceSubject: %s" % subject)
			return 0.0


func _get_squad_value(situation: StrategicSituation) -> float:
	# Reads a numeric property from the AI's own squad
	# e.g., FOOD → squad.food=20, MORALE → squad.get_morale()=0.7, WARRIOR_COUNT → 5
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
		StrategicAITypes.SquadGlanceable.WEAKEST_TRACKED_ENEMY_WARRIORS:
			return float(situation.weakest_tracked_enemy_warriors)
		StrategicAITypes.SquadGlanceable.INJURED_WARRIOR_COUNT:
			var count := 0
			for w in situation.squad.warriors:
				if w.is_injured and not w.is_dead:
					count += 1
			return float(count)
		_:
			assert(false, "Unknown SquadGlanceable: %s" % squad_property)
			return 0.0


func _get_location_value(situation: StrategicSituation) -> float:
	# Reads a numeric property from the squad's current location
	# e.g., STABILITY → location.stability=0.6, ENEMY_COUNT → 2, HAS_ACTIVITY(FORAGE) → 1.0
	match location_property:
		StrategicAITypes.LocationGlanceable.STABILITY:
			return situation.location.stability
		StrategicAITypes.LocationGlanceable.DEVELOPMENT:
			return float(situation.location.development)
		StrategicAITypes.LocationGlanceable.ENEMY_COUNT:
			return float(situation.enemies_here.size())
		StrategicAITypes.LocationGlanceable.ACTIVE_CLUE_COUNT:
			return float(situation.location.get_active_clues(situation.world.current_hour).size())
		StrategicAITypes.LocationGlanceable.HAS_ACTIVITY:
			return 1.0 if situation.location.has_activity_type(activity_type_filter) else 0.0
		StrategicAITypes.LocationGlanceable.TYPE:
			return 1.0 if situation.location.type == location_type_filter else 0.0
		StrategicAITypes.LocationGlanceable.HAS_SHOP:
			return 1.0 if situation.location.has_shop() else 0.0
		_:
			assert(false, "Unknown LocationGlanceable: %s" % location_property)
			return 0.0


func _get_world_value(situation: StrategicSituation) -> float:
	# Reads a numeric property from the broader world state
	# e.g., ADJACENT_ENEMY_COUNT → 3 enemies in neighboring locations, NEAREST_TOWN_DISTANCE → 2 hops
	match world_property:
		StrategicAITypes.WorldGlanceable.HOUR_COUNT:
			return float(situation.world.current_hour)
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
	# Reads a numeric property from the squad's faction
	# e.g., REPUTATION → faction.get_reputation()=50, ARMY_COUNT → faction.armies.size()=3
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
	# Gates the glance output — returns false if value doesn't meet the threshold
	# e.g., comparison=ABOVE, threshold=0.5, value=0.3 → false (0.3 is not above 0.5)
	# e.g., comparison=BELOW, threshold=0.2, value=0.1 → true (0.1 is below 0.2)
	match comparison:
		CsdrTypes.DETECTION.EQUAL:
			return value == threshold
		CsdrTypes.DETECTION.ABOVE:
			return value > threshold
		CsdrTypes.DETECTION.BELOW:
			return value < threshold
		_:
			return false


func _get_trade_value(situation) -> float:
	match trade_property:
		StrategicAITypes.TradeGlanceable.PROFIT_MARGIN:
			return situation.profit_margin
		StrategicAITypes.TradeGlanceable.ROUTE_DANGER:
			return situation.route_danger
		StrategicAITypes.TradeGlanceable.DEMAND_URGENCY:
			return situation.demand.priority
		StrategicAITypes.TradeGlanceable.DELIVERY_VALUE:
			return situation.delivery_value
		StrategicAITypes.TradeGlanceable.ACQUISITION_COST:
			return situation.acquisition_cost
		StrategicAITypes.TradeGlanceable.DISTANCE_KM:
			return situation.distance_km
		StrategicAITypes.TradeGlanceable.SUPPLY_QUANTITY:
			return situation.supply.available
		StrategicAITypes.TradeGlanceable.DEMAND_QUANTITY:
			return situation.demand.unfulfilled
		_:
			assert(false, "Unknown TradeGlanceable: %s" % trade_property)
			return 0.0
