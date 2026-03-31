class_name TradeMatcher
extends RefCounted

var _danger_calculator: RouteDangerCalculator
var _considerations: Array[StrategicConsideration]


func _init(p_considerations: Array[StrategicConsideration] = []) -> void:
	_danger_calculator = RouteDangerCalculator.new()
	_considerations = p_considerations


func match_trades(
	demands: Array[EconomicDemand],
	supplies: Array[EconomicSupply],
	world: World,
) -> Array[TradeMatch]:
	_danger_calculator.clear_cache()

	var scored: Array[Dictionary] = []

	for supply in supplies:
		if supply.available <= 0.0:
			continue
		for demand in demands:
			if demand.unfulfilled <= 0.0:
				continue
			if supply.thing.thing_id != demand.thing.thing_id:
				continue
			if supply.location_id == demand.location_id:
				continue

			var situation := TradeSituation.new(supply, demand, world, _danger_calculator)
			var score := _score_trade(situation)
			if score <= 0.0:
				continue

			scored.append({
				"supply": supply,
				"demand": demand,
				"score": score,
				"situation": situation,
			})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"]
	)

	var matches: Array[TradeMatch] = []
	for entry in scored:
		var supply: EconomicSupply = entry["supply"]
		var demand: EconomicDemand = entry["demand"]
		if supply.available <= 0.0 or demand.unfulfilled <= 0.0:
			continue

		var qty := minf(supply.available, demand.unfulfilled)
		supply.reserved += qty
		demand.fulfilled += qty

		var situation: TradeSituation = entry["situation"]
		var m := TradeMatch.new()
		m.supply = supply
		m.demand = demand
		m.quantity = qty
		m.route = situation.route
		m.route_safety = situation.route_danger
		m.score = entry["score"]
		matches.append(m)

	return matches


func _score_trade(situation: TradeSituation) -> float:
	if _considerations.is_empty():
		return _default_score(situation)

	var best_score := 0.0
	for consideration in _considerations:
		var s := consideration.score(situation)
		best_score = maxf(best_score, s)
	return best_score


func _default_score(situation: TradeSituation) -> float:
	var margin := situation.profit_margin
	var safety := situation.route_danger
	var urgency := situation.demand.priority / 10.0
	return (margin * 0.4 + urgency * 0.6) * safety
