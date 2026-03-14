extends RefCounted
class_name EconomyEngine

var world: World
var active_moves: Array[EconomyMove] = []
var bank: CentralBank = null
var active_contracts: Array[Contract] = []
var completed_contracts: Array[Contract] = []
var noble_loan_threshold: float = 100.0
var loan_amount: float = 500.0
var total_promotions: int = 0
var _shipment_counter: int = 0

func get_travel_time(from_id: String, to_id: String) -> int:
	assert(world != null)
	var t := world.calculate_travel_time(from_id, to_id)
	return t if t > 0 else 1

func _get_location(loc_id: String) -> Location:
	assert(world != null)
	return world.get_location_by_id(loc_id)

func _get_in_transit_to(dest_id: String, thing: Thing) -> float:
	var total := 0.0
	for move in active_moves:
		if move.dest_location_id == dest_id and move.thing == thing:
			total += move.quantity
	return total


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
	var result := EconomyTickResult.new()
	result.turn = turn

	_phase_bank_lending()
	_phase_demand()
	_phase_contracts()
	_phase_production(result)
	_phase_subsistence()
	_phase_trade_advance(result)
	_phase_trade_dispatch(result)
	_phase_price_update()
	_phase_market()
	_phase_consumption()
	_phase_wages()
	_phase_household_wages()
	_phase_rent()
	_phase_loan_repayment()
	_phase_government_spending()
	_phase_satisfaction()
	_phase_social_mobility()

	for loc in world.get_economy_locations():
		var snap := EconomyTickResult.create_snapshot(
			loc.location_id,
			loc.location_name,
			loc.population,
			loc.inventory,
		)
		result.location_snapshots.append(snap)

	return result


func _phase_demand() -> void:
	for loc in world.get_economy_locations():
		for person in loc.population.people:
			person.compute_wants(world.goods)


func _phase_production(result: EconomyTickResult) -> void:
	for loc in world.get_economy_locations():
		for rule: SupplyRule in loc.supply_rules:
			if rule.action in [EconomyTypes.RuleAction.PRODUCE, EconomyTypes.RuleAction.EXTRACT]:
				var produced := rule.execute(loc.inventory, loc.population)
				if produced > 0.0:
					Log.trace("Economy", "%s: produced %.1f %s" % [loc.location_name, produced, rule.thing.thing_name])


func _phase_subsistence() -> void:
	for loc in world.get_economy_locations():
		var farmers := loc.population.get_by_job(EconomyTypes.JobType.FARMER)
		for farmer in farmers:
			for thing in world.goods:
				if thing.thing_type == EconomyTypes.ThingType.FOOD:
					var available := loc.inventory.get_available(thing)
					if available >= 1.0:
						loc.inventory.consume(thing, 1.0)
						farmer.inventory[thing] = farmer.inventory.get(thing, 0.0) + 1.0


func _phase_trade_dispatch(result: EconomyTickResult) -> void:
	var ordered_this_tick: Dictionary = {}
	var source_reserve_cache: Dictionary = {}
	var consumption_cache: Dictionary = {}
	for loc in world.get_economy_locations():
		var loc_id := loc.location_id
		for rule: SupplyRule in loc.supply_rules:
			if rule.action != EconomyTypes.RuleAction.IMPORT:
				continue
			var cons_key := "%s:%s" % [loc_id, rule.thing.thing_id]
			var consumption_per_turn: float
			if consumption_cache.has(cons_key):
				consumption_per_turn = consumption_cache[cons_key] as float
			else:
				consumption_per_turn = loc.population.get_total_demand(rule.thing)
				consumption_cache[cons_key] = consumption_per_turn
			if consumption_per_turn <= 0.0:
				continue
			var travel_time := get_travel_time(rule.source_location_id, loc_id)
			var coverage_needed := consumption_per_turn * (travel_time + 1)
			var local_supply := loc.inventory.get_available(rule.thing)
			var in_transit := _get_in_transit_to(loc_id, rule.thing)
			var key := "%s:%s" % [loc_id, rule.thing.thing_id]
			var already_ordered: float = ordered_this_tick.get(key, 0.0)
			var projected_supply: float = local_supply + in_transit + already_ordered
			if projected_supply >= coverage_needed:
				continue
			var shortfall: float = coverage_needed - projected_supply
			var source_loc := _get_location(rule.source_location_id)
			if source_loc == null or not source_loc.has_economy():
				continue
			var source_inv := source_loc.inventory
			var raw_source := source_inv.get_available(rule.thing)
			if raw_source <= 0.0:
				continue
			var reserve_key := "%s:%s" % [rule.source_location_id, rule.thing.thing_id]
			var source_reserve: float
			if source_reserve_cache.has(reserve_key):
				source_reserve = source_reserve_cache[reserve_key] as float
			else:
				source_reserve = 0.0
				for sp in source_loc.population.people:
					var w: float = sp.wants.get(rule.thing, 0.0)
					var h: float = sp.inventory.get(rule.thing, 0.0)
					source_reserve += maxf(w - h, 0.0)
				source_reserve_cache[reserve_key] = source_reserve
			var available_at_source := maxf(raw_source - source_reserve, 0.0)
			if available_at_source <= 0.0:
				continue
			var send_qty := minf(shortfall, minf(available_at_source, rule.capacity_per_turn))
			source_inv.consume(rule.thing, send_qty)
			ordered_this_tick[key] = already_ordered + send_qty
			var move := rule.create_import_move(loc_id, send_qty, travel_time)
			active_moves.append(move)
			result.moves_created.append(move)
			_shipment_counter += 1
			var guard_count: int = _calculate_guard_count(move)
			var dispatch := EconomyTickResult.ShipmentDispatch.create(
				"shipment_%d" % _shipment_counter, move, guard_count,
			)
			result.shipment_dispatches.append(dispatch)
			Log.trace("Economy", "Trade: %.1f %s from %s→%s (%d turns)" % [
				send_qty, rule.thing.thing_name,
				source_loc.location_name,
				loc.location_name, travel_time,
			])


func _phase_trade_advance(result: EconomyTickResult) -> void:
	var still_active: Array[EconomyMove] = []
	for move in active_moves:
		var arrived := move.advance()
		if arrived:
			var dest_loc := _get_location(move.dest_location_id)
			if dest_loc and dest_loc.has_economy():
				dest_loc.inventory.add(move.thing, move.quantity)
			result.moves_completed.append(move)
			var dest_name := dest_loc.location_name if dest_loc else move.dest_location_id
			Log.trace("Economy", "Delivered: %.1f %s to %s" % [
				move.quantity, move.thing.thing_name, dest_name,
			])
		else:
			still_active.append(move)
	active_moves = still_active


func _phase_market() -> void:
	for loc in world.get_economy_locations():
		var buyers := loc.population.sorted_by_wealth_desc()
		for person in buyers:
			for thing in person.wants:
				var want_qty: float = person.wants[thing]
				var held: float = person.inventory.get(thing, 0.0)
				var need := maxf(want_qty - held, 0.0)
				if need <= 0.0:
					continue
				var price := loc.inventory.get_price(thing)
				var market_available := loc.inventory.get_available(thing)
				var buy_qty := minf(need, market_available)
				buy_qty = person.can_afford(price, buy_qty)
				if buy_qty <= 0.0:
					continue
				person.buy(thing, buy_qty, price)
				loc.inventory.consume(thing, buy_qty)
				_distribute_revenue(loc, buy_qty * price)
		loc.population.mark_wealth_dirty()


func _phase_consumption() -> void:
	for loc in world.get_economy_locations():
		for person in loc.population.people:
			person._comfort_this_turn = 0.0
			for thing in person.wants:
				var want_qty: float = person.wants[thing]
				if thing.thing_type == EconomyTypes.ThingType.FOOD:
					var consumed := person.consume(thing, 1.0)
					person._fed_this_turn = consumed >= 0.99
				else:
					var consumed := person.consume(thing, want_qty)
					if want_qty > 0.0 and consumed > 0.0:
						person._comfort_this_turn += consumed / want_qty


func _phase_bank_lending() -> void:
	if bank == null:
		return
	for loc in world.get_economy_locations():
		var nobles := loc.population.get_by_class(EconomyTypes.SocialClass.NOBLE)
		for noble in nobles:
			if bank.should_issue_loan(noble, noble_loan_threshold):
				bank.issue_loan(noble, loan_amount)


func _phase_contracts() -> void:
	var new_completed: Array[Contract] = []
	for contract in active_contracts:
		if contract.work_one_turn():
			new_completed.append(contract)
			Log.trace("Economy", "Contract completed: %s" % contract)
	for c in new_completed:
		active_contracts.erase(c)
		completed_contracts.append(c)

	var assigned_set: Dictionary = {}
	var patron_counts: Dictionary = {}
	for c in active_contracts:
		if c.merchant_assigned != null:
			assigned_set[c.merchant_assigned] = true
		for w in c.workers_assigned:
			assigned_set[w] = true
		patron_counts[c.patron] = patron_counts.get(c.patron, 0) + 1

	for loc in world.get_economy_locations():
		var nobles := loc.population.get_by_class(EconomyTypes.SocialClass.NOBLE)
		var merchants := loc.population.get_by_class(EconomyTypes.SocialClass.BOURGEOIS)
		var workers := loc.population.get_by_class(EconomyTypes.SocialClass.PEASANT)

		for noble in nobles:
			if patron_counts.get(noble, 0) >= 2:
				continue
			var surplus := noble.money - noble_loan_threshold
			if surplus < 50.0:
				continue
			var budget := surplus * 0.6
			var labor := clampi(int(budget / 15.0), 1, 10)
			var wage := 1.5
			var merchant_fee := budget * 0.15
			var contract_type := _pick_contract_type(noble)
			var contract := Contract.create(
				contract_type, noble, loc.location_id,
				budget, labor, 3, wage, merchant_fee,
			)
			_assign_staff_fast(contract, merchants, workers, assigned_set)
			active_contracts.append(contract)
			patron_counts[noble] = patron_counts.get(noble, 0) + 1
			Log.trace("Economy", "%s creates %s (budget=%.0f, labor=%d)" % [
				noble.person_name,
				Contract.ContractType.keys()[contract_type],
				budget, labor,
			])


func _noble_active_contract_count(noble: EconPerson) -> int:
	var count := 0
	for c in active_contracts:
		if c.patron == noble:
			count += 1
	return count


func _pick_contract_type(noble: EconPerson) -> Contract.ContractType:
	var types := [
		Contract.ContractType.CONSTRUCTION,
		Contract.ContractType.LUXURY_GOODS,
		Contract.ContractType.FOOD_SUPPLY,
	]
	var idx := hash(noble.person_id) % types.size()
	return types[idx] as Contract.ContractType


func _assign_staff(
	contract: Contract,
	merchants: Array[EconPerson],
	workers: Array[EconPerson],
) -> void:
	for m in merchants:
		if not _person_assigned_to_contract(m):
			contract.assign_merchant(m)
			break
	var assigned := 0
	for w in workers:
		if assigned >= contract.labor_needed:
			break
		if not _person_assigned_to_contract(w):
			contract.assign_worker(w)
			assigned += 1


func _assign_staff_fast(
	contract: Contract,
	merchants: Array[EconPerson],
	workers: Array[EconPerson],
	assigned_set: Dictionary,
) -> void:
	for m in merchants:
		if not assigned_set.has(m):
			contract.assign_merchant(m)
			assigned_set[m] = true
			break
	var assigned := 0
	for w in workers:
		if assigned >= contract.labor_needed:
			break
		if not assigned_set.has(w):
			contract.assign_worker(w)
			assigned_set[w] = true
			assigned += 1


func _person_assigned_to_contract(person: EconPerson) -> bool:
	for c in active_contracts:
		if c.merchant_assigned == person:
			return true
		if person in c.workers_assigned:
			return true
	return false


func _phase_wages() -> void:
	var any_paid := false
	for contract in active_contracts:
		if contract.workers_assigned.is_empty():
			continue
		var patron := contract.patron
		var cost := contract.get_total_cost_per_turn()
		var can_pay := minf(patron.money, cost)
		if can_pay <= 0.0:
			continue
		var wage_portion := contract.get_total_wage_cost()
		var merchant_portion := contract.merchant_fee
		var total := wage_portion + merchant_portion
		var pay_ratio := can_pay / maxf(total, 0.01)

		for worker in contract.workers_assigned:
			var w_pay := contract.wage_per_worker * pay_ratio
			patron.money -= w_pay
			worker.money += w_pay

		if contract.merchant_assigned != null:
			var m_pay := merchant_portion * pay_ratio
			patron.money -= m_pay
			contract.merchant_assigned.money += m_pay
		any_paid = true
	if any_paid:
		for loc in world.get_economy_locations():
			loc.population.mark_wealth_dirty()


func _phase_household_wages() -> void:
	var servant_wage := 0.5
	for loc in world.get_economy_locations():
		var nobles := loc.population.get_by_class(EconomyTypes.SocialClass.NOBLE)
		var servants := loc.population.get_by_job(EconomyTypes.JobType.SERVANT)
		if nobles.is_empty() or servants.is_empty():
			continue
		var servants_per_noble := ceili(servants.size() / float(nobles.size()))
		var servant_idx := 0
		for noble in nobles:
			var count := 0
			while count < servants_per_noble and servant_idx < servants.size():
				var s := servants[servant_idx]
				var pay := minf(servant_wage, noble.money)
				if pay > 0.0:
					noble.money -= pay
					s.money += pay
				servant_idx += 1
				count += 1
		loc.population.mark_wealth_dirty()


func _phase_rent() -> void:
	var rent_rate := 0.08
	for loc in world.get_economy_locations():
		var nobles := loc.population.get_by_class(EconomyTypes.SocialClass.NOBLE)
		if nobles.is_empty():
			continue
		var peasants := loc.population.get_by_class(EconomyTypes.SocialClass.PEASANT)
		var bourgeois := loc.population.get_by_class(EconomyTypes.SocialClass.BOURGEOIS)
		var total_rent := 0.0
		for p in peasants:
			var rent := p.money * rent_rate
			if rent > 0.01:
				p.money -= rent
				total_rent += rent
		for p in bourgeois:
			var rent := p.money * rent_rate * 0.5
			if rent > 0.01:
				p.money -= rent
				total_rent += rent
		if total_rent > 0.0:
			var per_noble := total_rent / nobles.size()
			for noble in nobles:
				noble.money += per_noble
		loc.population.mark_wealth_dirty()


func _phase_loan_repayment() -> void:
	if bank == null:
		return
	bank.collect_interest_and_repayments()


func _phase_government_spending() -> void:
	if bank == null:
		return
	var spend := bank.reserves * 0.1
	if spend < 1.0:
		return
	bank.reserves -= spend
	var all_workers: Array[EconPerson] = []
	for loc in world.get_economy_locations():
		all_workers.append_array(loc.population.get_by_class(EconomyTypes.SocialClass.PEASANT))
	if all_workers.is_empty():
		return
	var per_worker := spend / all_workers.size()
	for w in all_workers:
		w.money += per_worker


func _distribute_revenue(loc: Location, revenue: float) -> void:
	var merchants := loc.population.get_by_job(EconomyTypes.JobType.MERCHANT)
	if merchants.is_empty():
		return
	var share := revenue * 0.5 / merchants.size()
	for m in merchants:
		m.money += share


func _phase_price_update() -> void:
	for loc in world.get_economy_locations():
		var demand_totals: Dictionary = {}
		for thing in world.goods:
			demand_totals[thing] = loc.population.get_total_demand(thing)
		loc.inventory.update_prices(demand_totals)


func _phase_satisfaction() -> void:
	for loc in world.get_economy_locations():
		for person in loc.population.people:
			if person._fed_this_turn:
				person.satisfaction = minf(person.satisfaction + 5.0, 100.0)
			else:
				person.satisfaction = maxf(person.satisfaction - 15.0, 0.0)
			var comfort_bonus := person._comfort_this_turn * 2.0
			person.satisfaction = minf(person.satisfaction + comfort_bonus, 100.0)
			person._fed_this_turn = false
			person._comfort_this_turn = 0.0


func _phase_social_mobility() -> void:
	for loc in world.get_economy_locations():
		var peasants := loc.population.get_by_class(EconomyTypes.SocialClass.PEASANT)
		var to_promote: Array[EconPerson] = []
		for p in peasants:
			if p.money < 100.0 or p.satisfaction < 80.0:
				continue
			if randf() > 0.1:
				continue
			to_promote.append(p)
		for p in to_promote:
			var old_class := p.social_class
			var old_job := p.job
			p.social_class = EconomyTypes.SocialClass.BOURGEOIS
			p.job = EconomyTypes.JobType.MERCHANT
			loc.population.notify_class_changed(p, old_class, old_job)
			total_promotions += 1
			Log.info("Economy", "%s rises to BOURGEOIS at %s (money=%.0f sat=%.0f)" % [
				p.person_name, loc.location_name, p.money, p.satisfaction,
			])
