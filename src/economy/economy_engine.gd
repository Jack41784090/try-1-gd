class_name EconomyEngine extends RefCounted

var world: World
var active_moves: Array[EconomyMove] = []
## Imperial bank parameters — forwarded to C# CsGovernment.IsImperial via SetupBank.
var loan_interest_rate: float = 0.0
var print_per_turn: float = 0.0
var noble_loan_threshold: float = 100.0
var loan_amount: float = 500.0
var total_promotions: int = 0
var total_deaths: int = 0
var total_births: int = 0
var _shipment_counter: int = 0

## Tracking for in-flight caravan shipments. Mirrors economic state of
## EconomyMove objects with the strategy-layer SquadData ids materializing them.
## shipment_id (String) -> squad_id (String). Engine owns this state so that
## arrival/defeat/reassignment notifications can keep it consistent.
var _active_shipments: Dictionary = {}
var _mercenary_demand: MercenaryDemandCalculator = null
var _route_danger: RouteDangerCalculator = null

var active_shipment_count: int:
	get: return _active_shipments.size()

var _cs_bridge: Node = null
var _cs_initialized: bool = false

var active_contracts_count: int:
	get:
		if _cs_bridge != null:
			return _cs_bridge.call("GetActiveContractsCount") as int
		return 0

var completed_contracts_count: int:
	get:
		if _cs_bridge != null:
			return _cs_bridge.call("GetCompletedContractsCount") as int
		return 0

func get_bank_info() -> Dictionary:
	if _cs_bridge == null:
		return {}
	return _cs_bridge.call("GetBankInfo") as Dictionary

func get_government_info() -> Array:
	if _cs_bridge == null:
		return []
	return _cs_bridge.call("GetGovernmentInfo") as Array

func get_guild_info() -> Dictionary:
	if _cs_bridge == null:
		return {}
	return _cs_bridge.call("GetGuildInfo") as Dictionary

func get_geist_info(location_id: String) -> Dictionary:
	if _cs_bridge == null:
		return {}
	return _cs_bridge.call("GetGeistInfo", location_id) as Dictionary

func get_bandit_pressure(location_id: String) -> float:
	if _cs_bridge == null:
		return 0.0
	return _cs_bridge.call("GetBanditPressure", location_id) as float

func get_mercenary_demand(location_id: String) -> float:
	if _cs_bridge == null:
		return 0.0
	return _cs_bridge.call("GetMercenaryDemand", location_id) as float

func enable_csharp() -> void:
	if _cs_bridge != null:
		return
	var script = load("res://src/economy/csharp/CsEconomyBridge.cs")
	assert(script != null, "C# bridge script not found — godot-mono required")
	var instance = script.new()
	assert(instance != null, "C# bridge instantiation failed")
	_cs_bridge = instance as Node
	_mercenary_demand = MercenaryDemandCalculator.new()
	_route_danger = RouteDangerCalculator.new()
	Log.info("Economy", "C# economy engine enabled")

func _calculate_guard_count(move: EconomyMove) -> int:
	var cargo_value := move.quantity * move.thing.base_price
	if cargo_value < 20.0:
		return 1
	if cargo_value < 100.0:
		return 2
	if cargo_value < 300.0:
		return 3
	return 4


## Public entry point used by the strategy layer. The C# engine runs the full
## per-location pipeline AND the trade-matching greedy match in a single call;
## GDScript only contributes a precomputed danger matrix and post-tick
## mercenary-demand evaluation. Two bridge calls total: Tick and SyncBackToGdScript.
func tick_full(turn: int) -> EconomyTickResult:
	assert(_mercenary_demand != null and _route_danger != null, "tick_full requires enable_csharp() to have been called")
	assert(_cs_bridge != null, "C# bridge required — call enable_csharp() first")

	# Initialise C# Scripts
	if not _cs_initialized:
		_cs_bridge.call("Setup", world)
		_cs_bridge.call("SetupBank", loan_interest_rate, print_per_turn, noble_loan_threshold, loan_amount)
		_cs_initialized = true
		Log.info("Economy", "C# bridge initialized with %d locations, %d goods" % [world.get_economy_locations().size(), world.goods.size(), ])

	# Precompute NxN inter-location danger matrix (0..1). Index order matches
	# world.get_economy_locations(), which is also the C# Locations[] ordering.
	var danger_matrix := _compute_danger_matrix()

	# Single mega-tick: C# runs all phases, including trade matching.
	var cs_dict: Dictionary = _cs_bridge.call("Tick", turn, danger_matrix)

	# Translate tick result
	var result := EconomyTickResult.new()
	result.turn = cs_dict.get("turn", turn)
	result.deaths = cs_dict.get("deaths", 0)
	result.births = cs_dict.get("births", 0)

	var things_cache = {}
	var location_snapshots: Array = cs_dict.get("location_snapshots", [])
	for loc_snap_dict: Dictionary in location_snapshots:
		var snap := EconomyTickResult.LocationSnapshot.new()
		snap.location_id = loc_snap_dict.get("location_id", "")
		snap.location_name = loc_snap_dict.get("location_name", "")
		snap.population_count = loc_snap_dict.get("population_count", 0)
		snap.avg_satisfaction = loc_snap_dict.get("avg_satisfaction", 0.0)
		snap.avg_money = loc_snap_dict.get("avg_money", 0.0)
		snap.peasant_count = loc_snap_dict.get("peasant_count", 0)
		snap.bourgeois_count = loc_snap_dict.get("bourgeois_count", 0)
		snap.noble_count = loc_snap_dict.get("noble_count", 0)
		snap.government_treasury = loc_snap_dict.get("government_treasury", 0.0)
		snap.government_tax_collected = loc_snap_dict.get("government_tax_collected", 0.0)
		snap.government_directives_count = loc_snap_dict.get("government_directives_count", 0)
		snap.government_workers_hired = loc_snap_dict.get("government_workers_hired", 0)
		snap.guild_treasury = loc_snap_dict.get("guild_treasury", 0.0)
		snap.guild_produced = loc_snap_dict.get("guild_produced", 0.0)
		snap.guild_worker_count = loc_snap_dict.get("guild_worker_count", 0)

		var stocks_raw: Dictionary = loc_snap_dict.get("stocks", {})
		var prices_raw: Dictionary = loc_snap_dict.get("prices", {})
		for thing_id: String in stocks_raw:
			var thing = things_cache.get(thing_id, null) if things_cache.has(thing_id) else _find_thing_by_id(thing_id)
			things_cache[thing_id] = thing
			snap.stocks[thing] = stocks_raw[thing_id]
		for thing_id: String in prices_raw:
			var thing = things_cache.get(thing_id, null) if things_cache.has(thing_id) else _find_thing_by_id(thing_id)
			things_cache[thing_id] = thing
			snap.prices[thing] = prices_raw[thing_id]
		result.location_snapshots.append(snap)

	# Shipment dispatches (created inside C# trade matcher)
	var matched_dispatches_raw: Array = cs_dict.get("shipment_dispatches", [])
	for d_dict: Dictionary in matched_dispatches_raw:
		var move_dict: Dictionary = d_dict.get("move", {})
		var move := _move_from_dict(move_dict)
		active_moves.append(move)
		_shipment_counter += 1
		var dispatch := EconomyTickResult.ShipmentDispatch.create(
			d_dict.get("shipment_id", "shipment_%d" % _shipment_counter),
			move,
			d_dict.get("guard_count", 2),
		)
		result.shipment_dispatches.append(dispatch)

	# Completed moves (arrived deliveries)
	var moves_completed_raw: Array = cs_dict.get("moves_completed", [])
	for m_dict: Dictionary in moves_completed_raw:
		result.moves_completed.append(_move_from_dict(m_dict))

	# Aggregate counters
	total_promotions = _cs_bridge.call("GetTotalPromotions")
	total_deaths = _cs_bridge.call("GetTotalDeaths")
	total_births = _cs_bridge.call("GetTotalBirths")

	# Sync C# state into GDScript so the strategy layer can query person/inventory state.
	_cs_bridge.call("SyncBackToGdScript")

	# Mercenary demand evaluation (stays in GDScript — depends on world's bandit squads)
	for loc in world.locations:
		if loc.type == StrategyTypes.LocationType.FORT:
			continue
		var demand := _mercenary_demand.calculate_demand(loc, world)
		var should_offer := demand > MercenaryDemandCalculator.DEMAND_THRESHOLD
		if not should_offer:
			# Location only loses MERCENARY_WORK if there are no bandits left
			# nearby — otherwise the bounty contract should remain available.
			if BanditSpawner.count_bandits_at_location(loc.location_id, world) > 0:
				continue
		result.mercenary_work_changes[loc.location_id] = should_offer
	return result


## Build an NxN matrix of inter-location route safety values (0..1) where
## diagonal is 1.0 and entry [i,j] is the product of edge safeties along the
## shortest path between economy locations i and j. C# uses this to score
## trade pairs.
func _compute_danger_matrix() -> Array:
	_route_danger.clear_cache()
	var locs := world.get_economy_locations()
	var n := locs.size()
	var matrix: Array = []
	matrix.resize(n)
	for i in n:
		var row: Array = []
		row.resize(n)
		for j in n:
			if i == j:
				row[j] = 1.0
			else:
				var route: Array[String] = world.find_path(locs[i].location_id, locs[j].location_id)
				if route.is_empty():
					row[j] = 0.0
				else:
					row[j] = _route_danger.calculate_route_safety(route, world)
		matrix[i] = row
	return matrix


## Strategy layer notifies the engine that a materialized caravan has reached
## its destination. Engine applies the inventory delivery and clears the
## shipment tracking entry.
func execute_caravan_delivery(caravan: SquadData) -> void:
	assert(caravan.is_caravan(), "execute_caravan_delivery requires a caravan squad")
	var dest_loc := world.get_location_by_id(caravan.cargo.destination_id)
	assert(dest_loc != null, "Caravan destination '%s' not found" % caravan.cargo.destination_id)
	assert(dest_loc.inventory != null, "Caravan destination '%s' has no inventory" % dest_loc.location_id)
	CaravanBridge.apply_delivery(caravan, dest_loc.inventory, world.goods)
	_clear_shipment_for_squad(caravan.squad_id)


## Strategy layer notifies the engine that a materialized caravan was destroyed.
## Engine applies the loot transfer and clears the shipment tracking entry.
func notify_caravan_defeated(caravan: SquadData, attacker: SquadData) -> Dictionary:
	var looted: Dictionary = CaravanBridge.apply_loot(caravan, attacker)
	_clear_shipment_for_squad(caravan.squad_id)
	return looted


## Strategy layer registers a shipment_id <-> squad_id binding either at
## first spawn or when an idle caravan is reassigned to a new dispatch.
func register_dispatch_to_squad(shipment_id: String, squad_id: String) -> void:
	_active_shipments[shipment_id] = squad_id


## Strategy layer notifies the engine that an idle caravan has been retired
## without delivering. Engine clears its shipment tracking.
func clear_shipment_for_squad(squad_id: String) -> void:
	_clear_shipment_for_squad(squad_id)


func _clear_shipment_for_squad(squad_id: String) -> void:
	for shipment_id in _active_shipments.keys():
		if _active_shipments[shipment_id] == squad_id:
			_active_shipments.erase(shipment_id)
			return

func _find_thing_by_id(thing_id: String) -> Thing:
	for thing in world.goods:
		if thing.thing_id == thing_id:
			return thing
	return null


func _move_from_dict(d: Dictionary) -> EconomyMove:
	var thing := _find_thing_by_id(d.get("thing_id", ""))
	assert(thing != null, "Unknown thing_id in C# result: %s" % d.get("thing_id", ""))
	return EconomyMove.create(
		thing,
		d.get("quantity", 0.0),
		d.get("source_location_id", ""),
		d.get("dest_location_id", ""),
		d.get("turns_remaining", 1),
		d.get("origin", ""),
	)
