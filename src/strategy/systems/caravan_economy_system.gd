class_name CaravanEconomySystem
extends Node

## Never references LocationEconomySystem directly — wiring is done entirely by the composition root's signal connections.
## Convoys are real StrategySquads: the delivery timer IS the convoy's travel time, detected via SquadTravelSystem.location_changed (wired by the composition root). No countdown field.

signal location_arrived(location_id: String, thing: Thing, qty: float)
signal shipment_dispatched(move: EconomyMove)

var active_moves: Array[EconomyMove] = []

var _expected_reports: int = 0
var _reports_this_hour: int = 0
var _pending_offers: Array[Dictionary] = []   # {location_id, surplus, unmet}
var _shipment_counter: int = 0


func setup(location_count: int) -> void:
	_expected_reports = location_count


## Must connect to ClockSystem.hour_changed BEFORE LocationEconomySystem's handler — Godot fires listeners in connection order.
func _on_hour_changed(_hour: int) -> void:
	_reports_this_hour = 0
	_pending_offers.clear()


## BARRIER, not rolling match: waits for every location to report so the match result depends only on declared unmet/surplus data, never on Location iteration order.
func _on_trade_offer(location_id: String, surplus: Dictionary, unmet: Dictionary) -> void:
	_pending_offers.append({"location_id": location_id, "surplus": surplus, "unmet": unmet})
	_reports_this_hour += 1
	if _reports_this_hour >= _expected_reports: _run_global_trade_match()


## Margin/safety scoring is deliberately collapsed to plain matched-quantity scoring — the demo only asserts barrier TIMING and delivery FILTERING, not trade-economics fidelity.
func _run_global_trade_match() -> void:
	var demand_entries: Array[Dictionary] = []
	var supply_entries: Array[Dictionary] = []
	for offer in _pending_offers:
		for thing in offer.unmet:
			demand_entries.append({"location_id": offer.location_id, "thing": thing, "qty": offer.unmet[thing]})
		for thing in offer.surplus:
			supply_entries.append({"location_id": offer.location_id, "thing": thing, "qty": offer.surplus[thing]})

	var scored: Array[Dictionary] = []
	# One convoy per (thing, route) at a time: demand stays "unmet" while a
	# shipment is in transit, so without this guard every hour would dispatch
	# a duplicate convoy for the same gap.
	var in_transit: Dictionary = {}
	for move in active_moves:
		in_transit["%s|%s|%s" % [move.thing.thing_id, move.source_location_id, move.dest_location_id]] = true
	for s in supply_entries:
		for d in demand_entries:
			if s.thing == d.thing and s.location_id != d.location_id:
				if in_transit.has("%s|%s|%s" % [s.thing.thing_id, s.location_id, d.location_id]):
					continue
				var qty: float = minf(s.qty, d.qty)
				if qty > 0.0: scored.append({"supply": s, "demand": d, "score": qty})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)

	for pair in scored:
		var s: Dictionary = pair.supply
		var d: Dictionary = pair.demand
		if s.qty <= 0.0 or d.qty <= 0.0:
			continue
		var qty: float = minf(s.qty, d.qty)
		s.qty -= qty
		d.qty -= qty

		var move := EconomyMove.create(s.thing, qty, s.location_id, d.location_id)
		var shipment_id := "shipment_%d" % _shipment_counter
		_shipment_counter += 1
		move.squad = CaravanBridge.create_caravan_squad(move, shipment_id, CaravanBridge.calculate_guard_count(move))
		# The brain is part of the squad's identity (MonsterSpawnSystem pattern):
		# SquadActingSystem.register_squad() is the single registration step.
		move.squad.resource = StrategySquadResource.new()
		move.squad.resource.brain = StrategySquadBrain.new(move.squad, AIProfileFactory.get_squad_profile(AIProfileFactory.CARAVAN_PROFILE_PATH))
		active_moves.append(move)
		LogGd.info("[CaravanEconomySystem] dispatched %s: %.1f %s %s -> %s" % [
			move.squad.squad_name, qty, s.thing.thing_name, s.location_id, d.location_id,
		])
		shipment_dispatched.emit(move)


## Wired to SquadTravelSystem.location_changed by the composition root. A convoy whose squad just reached its cargo destination completes its move and delivers.
func _on_squad_moved(squad_id: String, _from_id: String, to_id: String) -> void:
	for move in active_moves:
		if move.squad != null and move.squad.squad_id == squad_id and move.squad.cargo.has_reached(to_id):
			move.state = EconomyTypes.MoveState.COMPLETED
			active_moves.erase(move)
			LogGd.info("[CaravanEconomySystem] %s delivered %.1f %s to %s" % [
				move.squad.squad_name, move.quantity, move.thing.thing_name, to_id,
			])
			location_arrived.emit(move.dest_location_id, move.thing, move.quantity)
			return
