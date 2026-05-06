class_name EconomyOrchestrator extends RefCounted

var _active_shipments: Dictionary = {}
var _trade_matcher: TradeMatcher
var _mercenary_demand: MercenaryDemandCalculator

var active_shipment_count: int:
	get: return _active_shipments.size()


func _init() -> void:
	_trade_matcher = TradeMatcher.new()
	_mercenary_demand = MercenaryDemandCalculator.new()


## Ticks the economy and emits a report describing caravan-fleet deltas.
## The caller (StrategyPresenter) is responsible for bridging these deltas
## into AISquadManager — EconomyOrchestrator does not depend on the AI layer.
##
## Returns:
##   {
##     "event_log": Array[String],
##     "spawned_caravans": Array[SquadData],     # caller registers with AISquadManager
##     "despawned_caravan_ids": Array[String],   # caller unregisters with AISquadManager
##   }
func tick_and_spawn_caravans(game_scenario: GameScenario) -> Dictionary:
	var event_log: Array[String] = []
	var spawned_caravans: Array[SquadData] = []
	var despawned_caravan_ids: Array[String] = []

	var economy_engine := game_scenario.world.economy_engine
	assert(economy_engine != null, "World.economy_engine is null \u2014 GameScenario._setup_economy() must initialize it")
	var turn := game_scenario.world.current_hour
	var economy_engine_tick_result := economy_engine.tick(turn)

	economy_engine.sync_full()

	var demands := economy_engine.get_pending_demands()
	var supplies := economy_engine.get_available_supplies()
	var trade_matches := _trade_matcher.match_trades(demands, supplies, game_scenario.world)
	var trade_dispatches := economy_engine.apply_trade_matches(trade_matches)

	var idle_caravans: Array[SquadData] = []
	_deliver_arrived_caravans(idle_caravans, game_scenario, event_log)

	var pending_dispatches: Array[EconomyTickResult.ShipmentDispatch] = []
	for dispatch in economy_engine_tick_result.shipment_dispatches:
		if _active_shipments.has(dispatch.shipment_id):
			continue
		pending_dispatches.append(dispatch)
	for dispatch in trade_dispatches:
		if _active_shipments.has(dispatch.shipment_id):
			continue
		pending_dispatches.append(dispatch)

	_reassign_idle_caravans(idle_caravans, pending_dispatches, event_log)
	_spawn_new_caravans(pending_dispatches, game_scenario, spawned_caravans, event_log)
	_despawn_excess_caravans(idle_caravans, game_scenario, despawned_caravan_ids, event_log)

	_tick_mercenary_demand(game_scenario.world)

	return {
		"event_log": event_log,
		"spawned_caravans": spawned_caravans,
		"despawned_caravan_ids": despawned_caravan_ids,
	}


func _deliver_arrived_caravans(idle_caravans: Array[SquadData], game_scenario: GameScenario, event_log: Array[String]) -> void:
	for squad in game_scenario.world.roaming_squads:
		if not squad.is_caravan():
			continue
		if not squad.has_reached_destination():
			continue
		var dest_loc := game_scenario.world.get_location_by_id(squad.cargo.destination_id)
		assert(dest_loc != null, "Caravan destination '%s' not found" % squad.cargo.destination_id)
		assert(dest_loc.inventory != null, "Caravan destination '%s' has no inventory but economy is mandatory" % dest_loc.location_id)
		CaravanBridge.apply_delivery(squad, dest_loc.inventory, game_scenario.world.goods)
		for shipment_id in _active_shipments:
			if _active_shipments[shipment_id] == squad.squad_id:
				_active_shipments.erase(shipment_id)
				break
		event_log.append("CARAVAN delivered %s to %s" % [squad.squad_name, squad.cargo.destination_id])
		Log.info("Economy", "Caravan %s delivered to %s" % [squad.squad_name, squad.cargo.destination_id])
		idle_caravans.append(squad)


func _reassign_idle_caravans(idle_caravans: Array[SquadData], pending_dispatches: Array[EconomyTickResult.ShipmentDispatch], event_log: Array[String]) -> void:
	while not idle_caravans.is_empty() and not pending_dispatches.is_empty():
		var squad: SquadData = idle_caravans.pop_back()
		var dispatch: EconomyTickResult.ShipmentDispatch = pending_dispatches.pop_front()
		CaravanBridge.reassign_caravan(squad, dispatch.move, dispatch.shipment_id)
		_active_shipments[dispatch.shipment_id] = squad.squad_id
		event_log.append("CARAVAN reassigned %s at %s \u2192 %s" % [
			squad.squad_name, squad.current_location_id, squad.cargo.destination_id])


func _spawn_new_caravans(pending_dispatches: Array[EconomyTickResult.ShipmentDispatch], game_scenario: GameScenario, spawned_caravans: Array[SquadData], event_log: Array[String]) -> void:
	for dispatch in pending_dispatches:
		var squad: SquadData = CaravanBridge.create_caravan_squad(
			dispatch.move, dispatch.shipment_id, dispatch.guard_count,
		)
		game_scenario.world.add_roaming_squad(squad)
		spawned_caravans.append(squad)
		_active_shipments[dispatch.shipment_id] = squad.squad_id
		event_log.append("CARAVAN spawned %s at %s \u2192 %s" % [
			squad.squad_name, squad.current_location_id, squad.cargo.destination_id])
		Log.info("Economy", "Spawned caravan: %s at %s \u2192 %s (%d guards)" % [
			squad.squad_name, squad.current_location_id,
			squad.cargo.destination_id, dispatch.guard_count,
		])


func _despawn_excess_caravans(idle_caravans: Array[SquadData], game_scenario: GameScenario, despawned_caravan_ids: Array[String], event_log: Array[String]) -> void:
	for squad in idle_caravans:
		event_log.append("CARAVAN retired %s" % squad.squad_name)
		Log.info("Economy", "Retiring idle caravan: %s" % squad.squad_name)
		game_scenario.world.remove_roaming_squad(squad.squad_id)
		despawned_caravan_ids.append(squad.squad_id)


func _tick_mercenary_demand(world: World) -> void:
	for loc in world.locations:
		if loc.type == StrategyTypes.LocationType.FORT:
			continue
		var demand := _mercenary_demand.calculate_demand(loc, world)
		if demand > MercenaryDemandCalculator.DEMAND_THRESHOLD:
			loc.add_activity_type(StrategyTypes.ActivityType.MERCENARY_WORK)
		elif BanditSpawner.count_bandits_at_location(loc.location_id, world) == 0:
			loc.available_activity_types.erase(StrategyTypes.ActivityType.MERCENARY_WORK)


func get_bandit_faction(game_scenario: GameScenario) -> Faction:
	for faction in game_scenario.factions:
		if faction.faction_id == "bandits":
			return faction
	return null


func handle_caravan_defeated(caravan: SquadData, attacker: SquadData) -> Dictionary:
	var looted: Dictionary = CaravanBridge.apply_loot(caravan, attacker)
	for shipment_id in _active_shipments:
		if _active_shipments[shipment_id] == caravan.squad_id:
			_active_shipments.erase(shipment_id)
			break
	return looted
