extends RefCounted
class_name EconomyEngine

var world: World
var active_moves: Array[EconomyMove] = []
var bank: CentralBank = null
var noble_loan_threshold: float = 100.0
var loan_amount: float = 500.0
var total_promotions: int = 0
var total_deaths: int = 0
var total_births: int = 0
var _shipment_counter: int = 0

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

func sync_full() -> void:
	assert(_cs_bridge != null, "C# bridge required")
	_cs_bridge.call("SyncBackToGdScript")

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
	Log.info("Economy", "C# economy engine enabled")

func _setup_cs_bridge() -> void:
	if _cs_initialized:
		return
	_cs_bridge.call("Setup", world)
	if bank != null:
		_cs_bridge.call("SetupBank", bank.loan_interest_rate, bank.print_per_turn, noble_loan_threshold, loan_amount)
	_cs_initialized = true
	Log.info("Economy", "C# bridge initialized with %d locations, %d goods" % [
		world.get_economy_locations().size(), world.goods.size(),
	])

func _calculate_guard_count(move: EconomyMove) -> int:
	var cargo_value := move.quantity * move.thing.base_price
	if cargo_value < 20.0:
		return 1
	if cargo_value < 100.0:
		return 2
	if cargo_value < 300.0:
		return 3
	return 4


func tick(turn: int) -> EconomyTickResult:
	assert(_cs_bridge != null, "C# bridge required — call enable_csharp() first")
	_setup_cs_bridge()
	return _tick_csharp(turn)


func get_pending_demands() -> Array[EconomicDemand]:
	assert(_cs_bridge != null, "C# bridge required")
	var raw: Array = _cs_bridge.call("GetPendingDemands")
	var demands: Array[EconomicDemand] = []
	for d: Dictionary in raw:
		var thing := _find_thing_by_id(d["thing_id"])
		if thing == null:
			continue
		demands.append(EconomicDemand.create(
			thing,
			d["quantity"],
			d["max_price"],
			d["location_id"],
			"population",
			d["priority"],
		))
	return demands


func get_available_supplies() -> Array[EconomicSupply]:
	assert(_cs_bridge != null, "C# bridge required")
	var raw: Array = _cs_bridge.call("GetAvailableSupplies")
	var supplies: Array[EconomicSupply] = []
	for s: Dictionary in raw:
		var thing := _find_thing_by_id(s["thing_id"])
		if thing == null:
			continue
		supplies.append(EconomicSupply.create(
			thing,
			s["quantity"],
			s["cost_basis"],
			s["location_id"],
			"inventory",
		))
	return supplies


func apply_trade_matches(matches: Array[TradeMatch]) -> Array[EconomyTickResult.ShipmentDispatch]:
	assert(_cs_bridge != null, "C# bridge required")
	var match_array: Array = []
	for m in matches:
		match_array.append({
			"thing_id": m.supply.thing.thing_id,
			"quantity": m.quantity,
			"source_location_id": m.supply.location_id,
			"dest_location_id": m.demand.location_id,
		})
	var result: Dictionary = _cs_bridge.call("ApplyTradeMatches", match_array)
	_cs_bridge.call("SyncInventories")

	var dispatches: Array[EconomyTickResult.ShipmentDispatch] = []
	var dispatches_raw: Array = result.get("shipment_dispatches", [])
	for d_dict: Dictionary in dispatches_raw:
		var move_dict: Dictionary = d_dict.get("move", {})
		var move := _move_from_dict(move_dict)
		active_moves.append(move)
		_shipment_counter += 1
		var dispatch := EconomyTickResult.ShipmentDispatch.create(
			d_dict.get("shipment_id", "shipment_%d" % _shipment_counter),
			move,
			d_dict.get("guard_count", 2),
		)
		dispatches.append(dispatch)
	return dispatches


func _tick_csharp(turn: int) -> EconomyTickResult:
	var cs_dict: Dictionary = _cs_bridge.call("Tick", turn)
	_cs_bridge.call("SyncInventories")

	var result := EconomyTickResult.new()
	result.turn = cs_dict.get("turn", turn)
	result.deaths = cs_dict.get("deaths", 0)
	result.births = cs_dict.get("births", 0)

	var snapshots: Array = cs_dict.get("location_snapshots", [])
	for snap_dict: Dictionary in snapshots:
		var snap := EconomyTickResult.LocationSnapshot.new()
		snap.location_id = snap_dict.get("location_id", "")
		snap.location_name = snap_dict.get("location_name", "")
		snap.population_count = snap_dict.get("population_count", 0)
		snap.avg_satisfaction = snap_dict.get("avg_satisfaction", 0.0)
		snap.avg_money = snap_dict.get("avg_money", 0.0)
		snap.peasant_count = snap_dict.get("peasant_count", 0)
		snap.bourgeois_count = snap_dict.get("bourgeois_count", 0)
		snap.noble_count = snap_dict.get("noble_count", 0)
		snap.government_treasury = snap_dict.get("government_treasury", 0.0)
		snap.government_tax_collected = snap_dict.get("government_tax_collected", 0.0)
		snap.government_directives_count = snap_dict.get("government_directives_count", 0)
		snap.government_workers_hired = snap_dict.get("government_workers_hired", 0)
		snap.guild_treasury = snap_dict.get("guild_treasury", 0.0)
		snap.guild_produced = snap_dict.get("guild_produced", 0.0)
		snap.guild_worker_count = snap_dict.get("guild_worker_count", 0)
		var stocks_raw: Dictionary = snap_dict.get("stocks", {})
		for thing_id: String in stocks_raw:
			var thing := _find_thing_by_id(thing_id)
			if thing:
				snap.stocks[thing] = stocks_raw[thing_id]
		var prices_raw: Dictionary = snap_dict.get("prices", {})
		for thing_id: String in prices_raw:
			var thing := _find_thing_by_id(thing_id)
			if thing:
				snap.prices[thing] = prices_raw[thing_id]
		result.location_snapshots.append(snap)

	var dispatches_raw: Array = cs_dict.get("shipment_dispatches", [])
	for d_dict: Dictionary in dispatches_raw:
		var move_dict: Dictionary = d_dict.get("move", {})
		var move := _move_from_dict(move_dict)
		active_moves.append(move)
		result.moves_created.append(move)
		_shipment_counter += 1
		var dispatch := EconomyTickResult.ShipmentDispatch.create(
			d_dict.get("shipment_id", "shipment_%d" % _shipment_counter),
			move,
			d_dict.get("guard_count", 2),
		)
		result.shipment_dispatches.append(dispatch)

	var moves_completed_raw: Array = cs_dict.get("moves_completed", [])
	for m_dict: Dictionary in moves_completed_raw:
		result.moves_completed.append(_move_from_dict(m_dict))

	total_promotions = _cs_bridge.call("GetTotalPromotions")
	total_deaths = _cs_bridge.call("GetTotalDeaths")
	total_births = _cs_bridge.call("GetTotalBirths")
	return result


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
