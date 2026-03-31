class_name EconomyOrchestrator
extends RefCounted

var _active_shipments: Dictionary = {}
var _trade_matcher: TradeMatcher

var active_shipment_count: int:
	get: return _active_shipments.size()


func _init() -> void:
	_trade_matcher = TradeMatcher.new()


func tick_and_spawn_caravans(game_scenario: GameScenario, ai_fleet: AIFleetManager) -> Array[String]:
	var log: Array[String] = []
	var economy_engine := game_scenario.world.economy_engine
	assert(economy_engine != null, "World.economy_engine is null — GameScenario._setup_economy() must initialize it")
	var turn := game_scenario.world.current_hour
	var tick_result := economy_engine.tick(turn)

	var demands := economy_engine.get_pending_demands()
	var supplies := economy_engine.get_available_supplies()
	var trade_matches := _trade_matcher.match_trades(demands, supplies, game_scenario.world)
	var trade_dispatches := economy_engine.apply_trade_matches(trade_matches)

	var Bridge = load("res://src/economy/caravan_bridge.gd")
	var idle_caravans: Array[SquadData] = []
	_deliver_arrived_caravans(Bridge, idle_caravans, game_scenario, log)

	var pending_dispatches: Array[EconomyTickResult.ShipmentDispatch] = []
	for dispatch in tick_result.shipment_dispatches:
		if _active_shipments.has(dispatch.shipment_id):
			continue
		pending_dispatches.append(dispatch)
	for dispatch in trade_dispatches:
		if _active_shipments.has(dispatch.shipment_id):
			continue
		pending_dispatches.append(dispatch)

	_reassign_idle_caravans(Bridge, idle_caravans, pending_dispatches, log)
	_spawn_new_caravans(Bridge, pending_dispatches, game_scenario, ai_fleet, log)
	_despawn_excess_caravans(idle_caravans, game_scenario, ai_fleet, log)
	return log


func _deliver_arrived_caravans(Bridge, idle_caravans: Array[SquadData], game_scenario: GameScenario, log: Array[String]) -> void:
	for squad in game_scenario.world.roaming_squads:
		if not squad.is_caravan():
			continue
		if not squad.has_reached_destination():
			continue
		var dest_loc := game_scenario.world.get_location_by_id(squad.cargo.destination_id)
		if dest_loc and dest_loc.has_economy():
			Bridge.apply_delivery(squad, dest_loc.inventory, game_scenario.world.goods)
		for shipment_id in _active_shipments:
			if _active_shipments[shipment_id] == squad.squad_id:
				_active_shipments.erase(shipment_id)
				break
		log.append("CARAVAN delivered %s to %s" % [squad.squad_name, squad.cargo.destination_id])
		Log.info("Economy", "Caravan %s delivered to %s" % [squad.squad_name, squad.cargo.destination_id])
		idle_caravans.append(squad)


func _reassign_idle_caravans(Bridge, idle_caravans: Array[SquadData], pending_dispatches: Array[EconomyTickResult.ShipmentDispatch], log: Array[String]) -> void:
	while not idle_caravans.is_empty() and not pending_dispatches.is_empty():
		var squad: SquadData = idle_caravans.pop_back()
		var dispatch: EconomyTickResult.ShipmentDispatch = pending_dispatches.pop_front()
		Bridge.reassign_caravan(squad, dispatch.move, dispatch.shipment_id)
		_active_shipments[dispatch.shipment_id] = squad.squad_id
		log.append("CARAVAN reassigned %s at %s → %s" % [
			squad.squad_name, squad.current_location_id, squad.cargo.destination_id])


func _spawn_new_caravans(Bridge, pending_dispatches: Array[EconomyTickResult.ShipmentDispatch], game_scenario: GameScenario, ai_fleet: AIFleetManager, log: Array[String]) -> void:
	for dispatch in pending_dispatches:
		var squad: SquadData = Bridge.create_caravan_squad(
			dispatch.move, dispatch.shipment_id, dispatch.guard_count,
		)
		game_scenario.world.add_roaming_squad(squad)
		ai_fleet.register_caravan(squad)
		_active_shipments[dispatch.shipment_id] = squad.squad_id
		log.append("CARAVAN spawned %s at %s → %s" % [
			squad.squad_name, squad.current_location_id, squad.cargo.destination_id])
		Log.info("Economy", "Spawned caravan: %s at %s → %s (%d guards)" % [
			squad.squad_name, squad.current_location_id,
			squad.cargo.destination_id, dispatch.guard_count,
		])


func _despawn_excess_caravans(idle_caravans: Array[SquadData], game_scenario: GameScenario, ai_fleet: AIFleetManager, log: Array[String]) -> void:
	for squad in idle_caravans:
		log.append("CARAVAN retired %s" % squad.squad_name)
		Log.info("Economy", "Retiring idle caravan: %s" % squad.squad_name)
		game_scenario.world.remove_roaming_squad(squad.squad_id)
		ai_fleet.unregister_caravan(squad.squad_id)


func handle_caravan_defeated(caravan: SquadData, attacker: SquadData) -> Dictionary:
	var Bridge = load("res://src/economy/caravan_bridge.gd")
	var looted: Dictionary = Bridge.apply_loot(caravan, attacker)
	for shipment_id in _active_shipments:
		if _active_shipments[shipment_id] == caravan.squad_id:
			_active_shipments.erase(shipment_id)
			break
	return looted
