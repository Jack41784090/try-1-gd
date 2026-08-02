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
	## Reads a single world property from the situation, normalizes, inverts, chains, and filters it
	## Pipeline: raw_value → normalize → inverse → chain additional_glance → comparison gate
	## e.g., Glance(subject=SQUAD, squad_property=FOOD, normalize_max=100, inverse=true)
	##   → raw=20 → normalize(20/100)=0.2 → inverse(1.0-0.2)=0.8
	## e.g., Glance(subject=LOCATION, location_property=ENEMY_COUNT, use_comparison=true, comparison=ABOVE, threshold=0)
	##   → raw=2 → no normalize → no inverse → check: 2 > 0 → passes → returns 2.0

	## 1. Get the raw numeric value based on subject + property
	var value := 0.0
	match subject:
		StrategicAITypes.GlanceSubject.SQUAD:
			match squad_property:
				StrategicAITypes.SquadGlanceable.FOOD:
					value = float(situation.squad.food)
				StrategicAITypes.SquadGlanceable.MONEY:
					value = situation.squad.money
				StrategicAITypes.SquadGlanceable.MORALE:
					value = situation.squad.get_morale()
				StrategicAITypes.SquadGlanceable.WARRIOR_COUNT:
					value = float(situation.squad.get_living_warriors().size())
				StrategicAITypes.SquadGlanceable.KARMA:
					value = situation.squad.karma
				StrategicAITypes.SquadGlanceable.TRAVEL_TOOLS:
					value = float(situation.squad.travel_tools)
				StrategicAITypes.SquadGlanceable.HIGHEST_ENEMY_CONTACT:
					value = situation.highest_contact_on_us
				StrategicAITypes.SquadGlanceable.OUR_BEST_CONTACT:
					value = situation.our_best_contact
				StrategicAITypes.SquadGlanceable.CAN_AMBUSH:
					value = 1.0 if situation.can_ambush else 0.0
				StrategicAITypes.SquadGlanceable.WEAKEST_TRACKED_ENEMY_WARRIORS:
					value = float(situation.weakest_tracked_enemy_warriors)
				StrategicAITypes.SquadGlanceable.INJURED_WARRIOR_COUNT:
					var count := 0
					for w in situation.squad.warriors:
						if w.is_injured and not w.is_dead:
							count += 1
					value = float(count)
				_:
					assert(false, "Unknown SquadGlanceable: %s" % squad_property)
		StrategicAITypes.GlanceSubject.LOCATION:
			match location_property:
				StrategicAITypes.LocationGlanceable.STABILITY:
					value = situation.location.stability
				StrategicAITypes.LocationGlanceable.DEVELOPMENT:
					value = float(situation.location.development)
				StrategicAITypes.LocationGlanceable.ENEMY_COUNT:
					value = float(situation.enemies_here.size())
				StrategicAITypes.LocationGlanceable.ACTIVE_CLUE_COUNT:
					value = float(situation.location.get_active_clues(situation.world.current_hour).size())
				StrategicAITypes.LocationGlanceable.HAS_ACTIVITY:
					value = 1.0 if situation.location.has_activity_type(activity_type_filter) else 0.0
				StrategicAITypes.LocationGlanceable.TYPE:
					value = 1.0 if situation.location.type == location_type_filter else 0.0
				StrategicAITypes.LocationGlanceable.HAS_SHOP:
					value = 1.0 if situation.location.has_shop() else 0.0
				StrategicAITypes.LocationGlanceable.MERCHANT_COUNT:
					value = float(situation.merchants_here.size() + situation.merchants_adjacent.size())
				_:
					assert(false, "Unknown LocationGlanceable: %s" % location_property)
		StrategicAITypes.GlanceSubject.WORLD:
			match world_property:
				StrategicAITypes.WorldGlanceable.HOUR_COUNT:
					value = float(situation.world.current_hour)
				StrategicAITypes.WorldGlanceable.ADJACENT_ENEMY_COUNT:
					value = float(situation.adjacent_enemies.size())
				StrategicAITypes.WorldGlanceable.NEAREST_ENEMY_DISTANCE:
					value = float(situation.nearest_enemy_distance)
				StrategicAITypes.WorldGlanceable.NEAREST_TOWN_DISTANCE:
					value = float(situation.nearest_town_distance)
				_:
					assert(false, "Unknown WorldGlanceable: %s" % world_property)
		StrategicAITypes.GlanceSubject.FACTION:
			if situation.faction == null:
				value = 0.0
			else:
				match faction_property:
					StrategicAITypes.FactionGlanceable.REPUTATION:
						value = situation.faction.get_reputation()
					StrategicAITypes.FactionGlanceable.ARMY_COUNT:
						value = float(situation.faction.armies.size())
					_:
						assert(false, "Unknown FactionGlanceable: %s" % faction_property)
		StrategicAITypes.GlanceSubject.TRADE:
			match trade_property:
				StrategicAITypes.TradeGlanceable.PROFIT_MARGIN:
					value = situation.profit_margin
				StrategicAITypes.TradeGlanceable.ROUTE_DANGER:
					value = situation.route_danger
				StrategicAITypes.TradeGlanceable.DEMAND_URGENCY:
					value = situation.demand.priority
				StrategicAITypes.TradeGlanceable.DELIVERY_VALUE:
					value = situation.delivery_value
				StrategicAITypes.TradeGlanceable.ACQUISITION_COST:
					value = situation.acquisition_cost
				StrategicAITypes.TradeGlanceable.DISTANCE_KM:
					value = situation.distance_km
				StrategicAITypes.TradeGlanceable.SUPPLY_QUANTITY:
					value = situation.supply.available
				StrategicAITypes.TradeGlanceable.DEMAND_QUANTITY:
					value = situation.demand.unfulfilled
				_:
					assert(false, "Unknown TradeGlanceable: %s" % trade_property)
		_:
			assert(false, "Unknown GlanceSubject: %s" % subject)

	## 2. Normalize to [0,1] if normalize_max is set
	## e.g., value=20, normalize_max=100 → 0.2
	if normalize_max > 0.0:
		value = clamp(value / normalize_max, 0.0, 1.0)

	## 3. Invert: makes "low food" into "high urgency"
	## e.g., 0.2 → 0.8 (squad with low food gets high forage urgency)
	if inverse:
		value = 1.0 - value

	## 4. Chain with another glance using an operation (MUL, ADD, RDC, AVG)
	## e.g., food_urgency(0.8) MUL has_market(1.0) = 0.8 (both must be true)
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

	## 5. Gate: if use_comparison is on, value must pass the threshold check or return 0
	## e.g., comparison=ABOVE, threshold=0.5 → value=0.3 → returns 0.0 (below threshold)
	if use_comparison and not _check_condition(value):
		value = 0.0

	return value


func _check_condition(value: float) -> bool:
	## Gates the glance output — returns false if value doesn't meet the threshold
	## e.g., comparison=ABOVE, threshold=0.5, value=0.3 → false (0.3 is not above 0.5)
	## e.g., comparison=BELOW, threshold=0.2, value=0.1 → true (0.1 is below 0.2)
	match comparison:
		CsdrTypes.DETECTION.EQUAL:
			return value == threshold
		CsdrTypes.DETECTION.ABOVE:
			return value > threshold
		CsdrTypes.DETECTION.BELOW:
			return value < threshold
		_:
			return false



