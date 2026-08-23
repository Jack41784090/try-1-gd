class_name CaravanEconomySystem
extends Node

## Never references LocationEconomySystem directly — wiring is done entirely by the demo driver's own local signal connections.

signal location_arrived(location_id: String, thing: Thing, qty: float)
signal shipment_dispatched(move: EconomyMove, guard_count: int)

var active_moves: Array[EconomyMove] = []

var _expected_reports: int = 0
var _reports_this_hour: int = 0
var _pending_offers: Array[Dictionary] = []   # {location_id, surplus, unmet}


func setup(location_count: int) -> void:
	_expected_reports = location_count


## Must connect to ClockSystem.hour_changed BEFORE LocationEconomySystem's handler — Godot fires listeners in connection order.
func _on_hour_changed(_hour: int) -> void:
	_reports_this_hour = 0
	_pending_offers.clear()

	var arrived: Array[EconomyMove] = []
	for move in active_moves:
		move.turns_remaining -= 1
		if move.turns_remaining <= 0:
			arrived.append(move)
	for move in arrived:
		active_moves.erase(move)
		location_arrived.emit(move.dest_location_id, move.thing, move.quantity)


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
	for s in supply_entries:
		for d in demand_entries:
			if s.thing == d.thing and s.location_id != d.location_id:
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

		var move := EconomyMove.create(s.thing, qty, s.location_id, d.location_id, 1)
		active_moves.append(move)
		var guard_count := CaravanBridge.calculate_guard_count(move)
		shipment_dispatched.emit(move, guard_count)
