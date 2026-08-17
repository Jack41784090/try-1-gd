class_name CaravanEconomySystem
extends Node

## Owns in-flight shipments (EconomyMove, src/economy/economy_move.gd —
## reused as-is) and the trade-offer barrier. Never references
## LocationEconomySystem directly — wiring is done entirely by the demo
## driver's own local signal connections.

signal location_arrived(location_id: String, thing: Thing, qty: float)
signal shipment_dispatched(move: EconomyMove, guard_count: int)

var active_moves: Array[EconomyMove] = []

var _expected_reports: int = 0
var _reports_this_hour: int = 0
var _pending_offers: Array[Dictionary] = []   # {location_id, surplus, unmet}


func setup(location_count: int) -> void:
	_expected_reports = location_count


## Connected to ClockSystem.hour_changed by the demo driver — must be
## connected BEFORE LocationEconomySystem's own hour_changed handler:
## Godot fires signal listeners in connection order, same documented
## technique main.gd uses for squad_ai_system/activity_run_system ordering.
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


## Connected to LocationEconomySystem.trade_offer by the demo driver.
##
## BARRIER, not rolling match: a rolling/greedy match (running the global
## match as soon as any two locations happen to have compatible offers)
## would make the outcome depend on which location's phase column happened
## to finish first — the exact ordering-accident class of bug this whole
## redesign exists to eliminate, just recreated one level up (at the
## inter-location trade layer instead of the intra-location crafting
## layer). Waiting for every location to report before running the global
## match guarantees the result is a function of the declared per-location
## unmet/surplus data only, never of Location iteration order.
func _on_trade_offer(location_id: String, surplus: Dictionary, unmet: Dictionary) -> void:
	_pending_offers.append({"location_id": location_id, "surplus": surplus, "unmet": unmet})
	_reports_this_hour += 1
	if _reports_this_hour < _expected_reports:
		return
	_run_global_trade_match()


## Simplified GDScript port of RunTradeMatching's scored-pair shape
## (CsEconomyEngine.cs:404-537) — margin/safety scoring is collapsed to
## plain matched-quantity scoring (no danger matrix / bandit system in this
## prototype; safety is implicitly 1.0 everywhere). This simplification is
## scoped deliberately: the demo's required assertions are about barrier
## TIMING and delivery FILTERING, not about trade-economics fidelity.
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
			if s.thing != d.thing or s.location_id == d.location_id:
				continue
			var qty: float = minf(s.qty, d.qty)
			if qty <= 0.0:
				continue
			scored.append({"supply": s, "demand": d, "score": qty})
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
