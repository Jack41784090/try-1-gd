extends RefCounted
class_name EconomyEngine

var locations: Dictionary = {}
var populations: Dictionary = {}
var inventories: Dictionary = {}
var supply_rules: Dictionary = {}
var active_moves: Array[EconomyMove] = []
var goods: Array[Thing] = []
var travel_times: Dictionary = {}

func register_location(
	location_id: String,
	location_name: String,
	pop: Population,
	inv: LocationInventory,
	rules: Array[SupplyRule],
) -> void:
	locations[location_id] = location_name
	populations[location_id] = pop
	inventories[location_id] = inv
	var sorted_rules: Array[SupplyRule] = []
	sorted_rules.append_array(rules)
	sorted_rules.sort_custom(func(a: SupplyRule, b: SupplyRule) -> bool: return a.priority < b.priority)
	supply_rules[location_id] = sorted_rules

func register_goods(things: Array[Thing]) -> void:
	goods.append_array(things)

func set_travel_time(from_id: String, to_id: String, turns: int) -> void:
	travel_times["%s→%s" % [from_id, to_id]] = turns

func get_travel_time(from_id: String, to_id: String) -> int:
	return travel_times.get("%s→%s" % [from_id, to_id], 1)

func _get_in_transit_to(dest_id: String, thing: Thing) -> float:
	var total := 0.0
	for move in active_moves:
		if move.dest_location_id == dest_id and move.thing == thing:
			total += move.quantity
	return total

func tick(turn: int) -> EconomyTickResult:
	var result := EconomyTickResult.new()
	result.turn = turn

	_phase_demand()
	_phase_production(result)
	_phase_trade_advance(result)
	_phase_price_update()
	_phase_market()
	_phase_consumption()
	_phase_income()
	_phase_trade_dispatch(result)
	_phase_satisfaction()

	for loc_id in locations:
		var snap := EconomyTickResult.create_snapshot(
			loc_id,
			locations[loc_id],
			populations[loc_id],
			inventories[loc_id],
		)
		result.location_snapshots.append(snap)

	return result


func _phase_demand() -> void:
	for loc_id in populations:
		var pop: Population = populations[loc_id]
		for person in pop.people:
			person.compute_wants(goods)


func _phase_production(result: EconomyTickResult) -> void:
	for loc_id in supply_rules:
		var rules: Array = supply_rules[loc_id]
		var pop: Population = populations[loc_id]
		var inv: LocationInventory = inventories[loc_id]
		for rule: SupplyRule in rules:
			if rule.action == EconomyTypes.RuleAction.EXTRACT or rule.action == EconomyTypes.RuleAction.PRODUCE:
				var produced := rule.execute(inv, pop)
				if produced > 0.0:
					Log.trace("Economy", "%s: produced %.1f %s" % [locations[loc_id], produced, rule.thing.thing_name])


func _phase_trade_dispatch(result: EconomyTickResult) -> void:
	for loc_id in supply_rules:
		var rules: Array = supply_rules[loc_id]
		var inv: LocationInventory = inventories[loc_id]
		var pop: Population = populations[loc_id]
		for rule: SupplyRule in rules:
			if rule.action != EconomyTypes.RuleAction.IMPORT:
				continue
			var consumption_need := float(pop.size()) * 1.3
			var local_supply := inv.get_available(rule.thing)
			var in_transit := _get_in_transit_to(loc_id, rule.thing)
			var effective_supply := local_supply + in_transit
			if effective_supply >= consumption_need:
				continue
			var order_qty := consumption_need - effective_supply
			var source_inv: LocationInventory = inventories.get(rule.source_location_id)
			if source_inv == null:
				continue
			var available_at_source := source_inv.get_available(rule.thing)
			if available_at_source <= 0.0:
				continue
			var send_qty := minf(order_qty, minf(available_at_source, rule.capacity_per_turn))
			source_inv.consume(rule.thing, send_qty)
			var travel := get_travel_time(rule.source_location_id, loc_id)
			var move := rule.create_import_move(loc_id, send_qty, travel)
			active_moves.append(move)
			result.moves_created.append(move)
			Log.trace("Economy", "Trade: %.1f %s from %s→%s (%d turns)" % [
				send_qty, rule.thing.thing_name,
				locations.get(rule.source_location_id, rule.source_location_id),
				locations[loc_id], travel,
			])


func _phase_trade_advance(result: EconomyTickResult) -> void:
	var still_active: Array[EconomyMove] = []
	for move in active_moves:
		var arrived := move.advance()
		if arrived:
			var dest_inv: LocationInventory = inventories.get(move.dest_location_id)
			if dest_inv:
				dest_inv.add(move.thing, move.quantity)
			result.moves_completed.append(move)
			Log.trace("Economy", "Delivered: %.1f %s to %s" % [
				move.quantity, move.thing.thing_name,
				locations.get(move.dest_location_id, move.dest_location_id),
			])
		else:
			still_active.append(move)
	active_moves = still_active


func _phase_market() -> void:
	for loc_id in populations:
		var pop: Population = populations[loc_id]
		var inv: LocationInventory = inventories[loc_id]
		var buyers := pop.sorted_by_wealth_desc()
		for person in buyers:
			for thing in person.wants:
				var want_qty: float = person.wants[thing]
				var held: float = person.inventory.get(thing, 0.0)
				var need := maxf(want_qty - held, 0.0)
				if need <= 0.0:
					continue
				var price := inv.get_price(thing)
				var market_available := inv.get_available(thing)
				var buy_qty := minf(need, market_available)
				buy_qty = person.can_afford(price, buy_qty)
				if buy_qty <= 0.0:
					continue
				person.buy(thing, buy_qty, price)
				inv.consume(thing, buy_qty)
				_distribute_revenue(loc_id, buy_qty * price)


func _phase_consumption() -> void:
	for loc_id in populations:
		var pop: Population = populations[loc_id]
		for person in pop.people:
			for thing in person.wants:
				if thing.thing_type == EconomyTypes.ThingType.FOOD:
					var consumed := person.consume(thing, 1.0)
					person._fed_this_turn = consumed >= 0.99


func _phase_income() -> void:
	for loc_id in populations:
		var pop: Population = populations[loc_id]
		var nobles := pop.get_by_class(EconomyTypes.SocialClass.NOBLE)
		var bourgeois := pop.get_by_class(EconomyTypes.SocialClass.BOURGEOIS)
		var peasants := pop.get_by_class(EconomyTypes.SocialClass.PEASANT)

		var tax_per_peasant := 0.2
		var total_tax := tax_per_peasant * peasants.size()
		for p in peasants:
			p.money = maxf(p.money - tax_per_peasant, 0.0)
		if not nobles.is_empty():
			var share := total_tax / nobles.size()
			for n in nobles:
				n.money += share

		var wage := 1.0
		for p in peasants:
			if p.job == EconomyTypes.JobType.FARMER or p.job == EconomyTypes.JobType.LABORER or p.job == EconomyTypes.JobType.SERVANT:
				p.money += wage

		for b in bourgeois:
			if b.job == EconomyTypes.JobType.MERCHANT:
				b.money += 2.0


func _distribute_revenue(loc_id: String, revenue: float) -> void:
	var pop: Population = populations[loc_id]
	var merchants := pop.get_by_job(EconomyTypes.JobType.MERCHANT)
	if merchants.is_empty():
		return
	var share := revenue * 0.1 / merchants.size()
	for m in merchants:
		m.money += share


func _phase_price_update() -> void:
	for loc_id in populations:
		var pop: Population = populations[loc_id]
		var inv: LocationInventory = inventories[loc_id]
		var demand_totals: Dictionary = {}
		for thing in goods:
			demand_totals[thing] = pop.get_total_demand(thing)
		inv.update_prices(demand_totals)


func _phase_satisfaction() -> void:
	for loc_id in populations:
		var pop: Population = populations[loc_id]
		for person in pop.people:
			if person._fed_this_turn:
				person.satisfaction = minf(person.satisfaction + 5.0, 100.0)
			else:
				person.satisfaction = maxf(person.satisfaction - 15.0, 0.0)
			person._fed_this_turn = false
