class_name MercenaryDemandCalculator
extends RefCounted

const DEMAND_THRESHOLD := 1.0
const BOUNTY_PER_WARRIOR := 25.0


func calculate_demand(location: Location, world: World) -> float:
	assert(world != null, "Mercenary demand calculation requires world context")
	assert(world.economy_engine != null, "Mercenary demand calculation requires initialized economy engine")
	var demand_cs := world.economy_engine.get_mercenary_demand(location.location_id)
	if demand_cs > 0.0:
		return demand_cs

	var danger_calc := RouteDangerCalculator.new()
	var trade_loss := 0.0

	if location.connections == null:
		return 0.0

	for conn in location.connections.tt:
		var route: Array[String] = [location.location_id, conn.to_location_id]
		var safety := danger_calc.calculate_route_safety(route, world)
		var suppression := 1.0 - safety
		var avg_trade_value := _estimate_trade_value(location)
		trade_loss += suppression * avg_trade_value

	var bandit_count := _count_nearby_bandits(location, world)
	if bandit_count == 0:
		return 0.0

	var hire_cost := float(bandit_count) * 50.0
	return trade_loss / maxf(hire_cost, 1.0)


func get_bounty(squad: SquadData) -> float:
	return float(squad.get_living_warriors().size()) * BOUNTY_PER_WARRIOR


func find_nearest_bandit(location: Location, world: World) -> SquadData:
	var squads_here := world.get_squads_at_location(location.location_id)
	for s in squads_here:
		if s.squad_role == StrategyTypes.SquadRole.BANDIT:
			return s

	if location.connections:
		for conn in location.connections.tt:
			var squads_adj := world.get_squads_at_location(conn.to_location_id)
			for s in squads_adj:
				if s.squad_role == StrategyTypes.SquadRole.BANDIT:
					return s
	return null


func _count_nearby_bandits(location: Location, world: World) -> int:
	var count := 0
	var squads_here := world.get_squads_at_location(location.location_id)
	for s in squads_here:
		if s.squad_role == StrategyTypes.SquadRole.BANDIT:
			count += 1

	if location.connections:
		for conn in location.connections.tt:
			var squads_adj := world.get_squads_at_location(conn.to_location_id)
			for s in squads_adj:
				if s.squad_role == StrategyTypes.SquadRole.BANDIT:
					count += 1
	return count


func _estimate_trade_value(location: Location) -> float:
	assert(location.inventory != null, "Mercenary demand requires inventory at location '%s'" % location.location_id)
	var total := 0.0
	for thing in location.inventory.stocks:
		var qty: float = location.inventory.stocks[thing]
		total += qty * thing.base_price
	return clampf(total * 0.1, 10.0, 500.0)
