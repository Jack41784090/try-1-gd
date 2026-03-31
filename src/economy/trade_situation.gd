class_name TradeSituation
extends RefCounted

var supply: EconomicSupply
var demand: EconomicDemand
var world: World

var route: Array[String]:
	get:
		if not _route_computed:
			_route = _compute_route()
			_route_computed = true
		return _route

var distance_km: float:
	get:
		if not _distance_computed:
			_distance_km = _compute_distance()
			_distance_computed = true
		return _distance_km

var route_danger: float:
	get:
		if not _route_danger_computed:
			_route_danger = _compute_route_danger()
			_route_danger_computed = true
		return _route_danger

var delivery_value: float:
	get:
		if not _delivery_value_computed:
			var qty := minf(supply.available, demand.unfulfilled)
			_delivery_value = demand.max_price * qty * route_danger
			_delivery_value_computed = true
		return _delivery_value

var acquisition_cost: float:
	get:
		if not _acquisition_cost_computed:
			var qty := minf(supply.available, demand.unfulfilled)
			_acquisition_cost = supply.cost_basis * qty
			_acquisition_cost_computed = true
		return _acquisition_cost

var profit_margin: float:
	get:
		if not _profit_margin_computed:
			if delivery_value > 0.0:
				_profit_margin = (delivery_value - acquisition_cost) / delivery_value
			else:
				_profit_margin = 0.0
			_profit_margin_computed = true
		return _profit_margin

var _route: Array[String] = []
var _route_computed: bool = false
var _distance_km: float = 0.0
var _distance_computed: bool = false
var _route_danger: float = 1.0
var _route_danger_computed: bool = false
var _delivery_value: float = 0.0
var _delivery_value_computed: bool = false
var _acquisition_cost: float = 0.0
var _acquisition_cost_computed: bool = false
var _profit_margin: float = 0.0
var _profit_margin_computed: bool = false

var _danger_calculator: RefCounted


func _init(p_supply: EconomicSupply, p_demand: EconomicDemand, p_world: World, p_danger_calc: RefCounted = null) -> void:
	supply = p_supply
	demand = p_demand
	world = p_world
	_danger_calculator = p_danger_calc


func _compute_route() -> Array[String]:
	if supply.location_id == demand.location_id:
		return [supply.location_id]
	return world.find_path(supply.location_id, demand.location_id)


func _compute_distance() -> float:
	if route.is_empty() or route.size() < 2:
		return 0.0
	return world.travel_graph.get_path_distance_km(route)


func _compute_route_danger() -> float:
	if _danger_calculator == null:
		return 1.0
	return _danger_calculator.calculate_route_safety(route, world)
