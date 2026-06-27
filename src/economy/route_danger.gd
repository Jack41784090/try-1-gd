class_name RouteDangerCalculator
extends RefCounted

const MAX_SQUAD_SIZE := 10.0

var _cache: Dictionary = {}


func calculate_route_safety(route: Array[String], world: World) -> float:
	if route.size() < 2:
		return 1.0

	var safety := 1.0
	for i in range(route.size() - 1):
		var from_id := route[i]
		var to_id := route[i + 1]
		var edge_safety := _get_edge_safety(from_id, to_id, world)
		safety *= edge_safety

	return safety


func clear_cache() -> void:
	_cache.clear()


func _get_edge_safety(from_id: String, to_id: String, world: World) -> float:
	var key := from_id + ">" + to_id
	if _cache.has(key):
		return _cache[key]

	var danger := 0.0
	var checked_squads: Dictionary = {}

	var squads_from := world.get_squads_at_location(from_id)
	var squads_to := world.get_squads_at_location(to_id)

	for squad in squads_from:
		if checked_squads.has(squad.squad_id):
			continue
		checked_squads[squad.squad_id] = true
		danger += _squad_threat(squad)

	for squad in squads_to:
		if checked_squads.has(squad.squad_id):
			continue
		checked_squads[squad.squad_id] = true
		danger += _squad_threat(squad)

	var edge_safety := 1.0 / (1.0 + danger)
	_cache[key] = edge_safety
	var reverse_key := to_id + ">" + from_id
	_cache[reverse_key] = edge_safety
	return edge_safety


func _squad_threat(squad: StrategySquad) -> float:
	if squad.squad_role == StrategyTypes.SquadRole.MERCHANT:
		return 0.0
	var warrior_count := squad.get_living_warriors().size()
	var base_threat := float(warrior_count) / MAX_SQUAD_SIZE
	if squad.squad_role == StrategyTypes.SquadRole.BANDIT:
		base_threat *= 1.5
	return base_threat
