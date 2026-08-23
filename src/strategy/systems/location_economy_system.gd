class_name LocationEconomySystem
extends Node

## Sole emitter of phase-boundary signals for every Location (a Resource, which never emits); never references CaravanEconomySystem directly — wiring is done by the demo driver.

signal spoiled(location_id: String, amount_lost: float)
signal price_updated(location_id: String, prices: Dictionary)
signal intents_generated(location_id: String, consumer_demands: Array[EconomyOrder], crafting_intents: Array[EconomyOrder])
signal boms_exploded(location_id: String, derived_demands: Array[EconomyOrder])
signal always_produced(location_id: String, base_supply: Array[EconomyOrder])
signal base_settled(location_id: String, filled: Dictionary, unmet: Dictionary)
signal crafted_produced(location_id: String, crafted_supply: Array[EconomyOrder])
signal finished_settled(location_id: String, filled: Dictionary, unmet: Dictionary)
signal workers_paid(location_id: String, total_wages: float)
signal revenue_collected(location_id: String, total_revenue: float)
signal geist_updated(location_id: String, unrest_delta: float)
signal snapshot_taken(location_id: String, snapshot: Dictionary)
signal trade_offer(location_id: String, surplus: Dictionary, unmet: Dictionary)

var locations: Array[Location] = []
var _guilds_by_location: Dictionary[StringName, Array] = {}            		# location_id -> Array[CraftingGuild]
var _consumer_demand_by_location: Dictionary[StringName, Dictionary] = {}   # location_id -> Dictionary[Thing, {"qty":float, "priority":float}]
var _last_demand_by_location: Dictionary[StringName, Dictionary] = {}


func setup(world: World) -> void:
	locations = world.locations


func register_location(location: Location, guilds: Array[CraftingGuild], consumer_demand: Dictionary) -> void:
	assert(locations.has(location), "register_location: Location must already be in world.locations")
	_guilds_by_location[location.location_id] = guilds
	_consumer_demand_by_location[location.location_id] = consumer_demand

func _on_location_arrived(location_id: String, thing: Thing, qty: float) -> void:
	for loc in locations:
		if loc.location_id == location_id:
			loc.inventory.add(thing, qty)
			return

func _on_hour_changed(_hour: int) -> void:
	for loc in locations:
		_run_phase_column(loc)


func _run_phase_column(loc: Location) -> void:
	_spoil(loc)
	_price_update(loc)

	var intents := _generate_intents(loc)
	var base_consumer_demands: Array[EconomyOrder] = []
	var finished_consumer_demands: Array[EconomyOrder] = []
	for order: EconomyOrder in intents.consumer_demands:
		if order.thing.inputs.is_empty():
			base_consumer_demands.append(order)
		else:
			finished_consumer_demands.append(order)

	var derived := _explode_boms(loc, intents.crafting_intents)
	var base_supply := _always_produce(loc)

	var base_demands: Array[EconomyOrder] = []
	base_demands.append_array(base_consumer_demands)
	base_demands.append_array(derived)
	var base_result := _settle_base(loc, base_demands, base_supply)

	var crafted_supply := _produce_crafted(loc, intents.crafting_intents, derived)
	var finished_result := _settle_finished(loc, finished_consumer_demands, crafted_supply)

	_pay_workers(loc)
	_collect_revenue(loc, crafted_supply)
	_geist_update(loc)
	_snapshot(loc)

	var unmet: Dictionary = {}
	for thing in base_result.unmet:
		unmet[thing] = unmet.get(thing, 0.0) + base_result.unmet[thing]
	for thing in finished_result.unmet:
		unmet[thing] = unmet.get(thing, 0.0) + finished_result.unmet[thing]
	_last_demand_by_location[loc.location_id] = unmet

	var surplus: Dictionary = {}
	for thing in loc.inventory.stocks:
		var avail: float = loc.inventory.get_available(thing)
		if avail > 0.0:
			surplus[thing] = avail
	trade_offer.emit(loc.location_id, surplus, unmet)


func _spoil(loc: Location) -> void:
	# No FOOD-type good in this dataset, so this is a no-op — port CsEconomyEngine.cs:175-180's spoilage rule if a spoilable Thing is added.
	spoiled.emit(loc.location_id, 0.0)


func _price_update(loc: Location) -> void:
	# Port of CsEconomyEngine.cs:182-208's imbalance formula; demand is read from the PREVIOUS tick's _last_demand_by_location.
	var last_demand: Dictionary = _last_demand_by_location.get(loc.location_id, {})
	for thing in loc.inventory.stocks:
		var demand: float = last_demand.get(thing, 0.0)
		var supply: float = maxf(loc.inventory.get_available(thing), 0.01)
		var base_price: float = thing.base_price
		var current_price: float = loc.inventory.get_price(thing)
		var imbalance: float = (demand - supply) / maxf(demand + supply, 1.0)
		var new_price: float = current_price * (1.0 + imbalance * 0.15)
		loc.inventory.prices[thing] = clampf(new_price, base_price * 0.5, base_price * 3.0)
	price_updated.emit(loc.location_id, loc.inventory.prices.duplicate())


func _generate_intents(loc: Location) -> Dictionary:
	var consumer_demands: Array[EconomyOrder] = []
	if loc.population != null and not loc.population.people.is_empty():
		# Population-sourced demand overrides the hand-authored rules below — PopulationSystem recomputes it this same hour, connected BEFORE this handler.
		for thing: Thing in loc.inventory.stocks:
			var qty := loc.population.get_total_demand(thing)
			if qty <= 0.0:
				continue
			consumer_demands.append(EconomyOrder.create(thing, qty, _consumer_priority_for(thing), "consumer"))
	else:
		# Fallback for locations with no Population wired up yet.
		var rules: Dictionary = _consumer_demand_by_location.get(loc.location_id, {})
		for thing in rules:
			var rule: Dictionary = rules[thing]
			consumer_demands.append(EconomyOrder.create(thing, rule.qty, rule.priority, "consumer"))

	var crafting_intents: Array[EconomyOrder] = []
	for guild: CraftingGuild in _guilds_by_location.get(loc.location_id, []):
		crafting_intents.append(EconomyOrder.create(guild.output_thing, guild.max_capacity, guild.priority, "guild_intent", 0.0, guild))

	intents_generated.emit(loc.location_id, consumer_demands, crafting_intents)
	return {"consumer_demands": consumer_demands, "crafting_intents": crafting_intents}


## Port of CsPerson.GenerateOrders' priority table (CsPerson.cs:162-167): food outranks weapons outranks everything else.
func _consumer_priority_for(thing: Thing) -> float:
	match thing.thing_type:
		EconomyTypes.ThingType.FOOD:
			return 10.0
		EconomyTypes.ThingType.WEAPONS:
			return 8.0
	return 5.0


func _explode_boms(loc: Location, crafting_intents: Array[EconomyOrder]) -> Array[EconomyOrder]:
	var derived: Array[EconomyOrder] = []
	for intent in crafting_intents:
		var leaf_needs := BomExploder.flatten(intent.thing, intent.quantity)
		for leaf_thing in leaf_needs:
			derived.append(EconomyOrder.create(leaf_thing, leaf_needs[leaf_thing], intent.priority, "guild_derived", 0.0, intent.guild, intent))
	boms_exploded.emit(loc.location_id, derived)
	return derived


## Ignores NaturalResource.worker_job/workers_needed — no Population in this prototype, so extraction is uncapped by workforce, unlike CsGuildSpecialization.Produce's efficiency scaling.
func _always_produce(loc: Location) -> Array[EconomyOrder]:
	var supply: Array[EconomyOrder] = []
	for nr: NaturalResource in loc.natural_resources:
		loc.inventory.add(nr.thing, nr.base_capacity)
		var available := loc.inventory.get_available(nr.thing)
		supply.append(EconomyOrder.create(nr.thing, available, 5.0, "extraction", loc.inventory.get_price(nr.thing)))
	always_produced.emit(loc.location_id, supply)
	return supply


func _settle_base(loc: Location, demands: Array[EconomyOrder], supplies: Array[EconomyOrder]) -> Dictionary:
	var result := EconomyOrderMatcher.match(demands, supplies, loc)
	base_settled.emit(loc.location_id, result.filled, result.unmet)
	return result


## Caps output by what was ACTUALLY secured in settle_base; does not consume raw materials itself — that already happened inside EconomyOrderMatcher.match() when each derived leaf order was matched.
func _produce_crafted(loc: Location, crafting_intents: Array[EconomyOrder], derived: Array[EconomyOrder]) -> Array[EconomyOrder]:
	var secured_by_guild: Dictionary = {}   # CraftingGuild -> Dictionary[Thing, float]
	for order in derived:
		if order.guild == null:
			continue
		if not secured_by_guild.has(order.guild):
			secured_by_guild[order.guild] = {}
		var secured: float = order.original_quantity - order.quantity
		secured_by_guild[order.guild][order.thing] = secured

	var crafted_supply: Array[EconomyOrder] = []
	for intent in crafting_intents:
		var guild: CraftingGuild = intent.guild
		var secured: Dictionary = secured_by_guild.get(guild, {})
		guild.secured_last_tick = secured.duplicate()

		var per_unit := BomExploder.flatten(guild.output_thing, 1.0)
		var producible: float = minf(intent.original_quantity, guild.max_capacity)
		for leaf_thing in per_unit:
			var need_per_unit: float = per_unit[leaf_thing]
			if need_per_unit <= 0.0:
				continue
			producible = minf(producible, secured.get(leaf_thing, 0.0) / need_per_unit)
		producible = maxf(producible, 0.0)

		guild.produced_last_tick = producible
		if producible <= 0.0:
			continue

		loc.inventory.add(guild.output_thing, producible)
		crafted_supply.append(EconomyOrder.create(guild.output_thing, producible, guild.priority, "guild_supply", loc.inventory.get_price(guild.output_thing), guild))

	crafted_produced.emit(loc.location_id, crafted_supply)
	return crafted_supply


func _settle_finished(loc: Location, finished_consumer_demands: Array[EconomyOrder], crafted_supply: Array[EconomyOrder]) -> Dictionary:
	var result := EconomyOrderMatcher.match(finished_consumer_demands, crafted_supply, loc)
	finished_settled.emit(loc.location_id, result.filled, result.unmet)
	return result


func _pay_workers(loc: Location) -> void:
	# No-op: no Population/worker roster in this prototype — port CsGuildSpecialization.PayWorkers (CsGuildSpecialization.cs:98-112) here later.
	workers_paid.emit(loc.location_id, 0.0)


func _collect_revenue(loc: Location, crafted_supply: Array[EconomyOrder]) -> void:
	for guild: CraftingGuild in _guilds_by_location.get(loc.location_id, []):
		guild.sold_last_tick = 0.0
	var total := 0.0
	for supply_order in crafted_supply:
		if supply_order.guild == null:
			continue
		var qty_sold: float = supply_order.original_quantity - supply_order.quantity
		var revenue: float = qty_sold * supply_order.unit_price
		supply_order.guild.treasury += revenue
		supply_order.guild.sold_last_tick = qty_sold
		total += revenue
	revenue_collected.emit(loc.location_id, total)


func _geist_update(loc: Location) -> void:
	# No-op: Geist/unrest depends on Population.satisfaction, not part of this prototype.
	geist_updated.emit(loc.location_id, 0.0)


func _snapshot(loc: Location) -> void:
	var snap: Dictionary = {
		"location_id": loc.location_id,
		"stocks": loc.inventory.stocks.duplicate(),
		"prices": loc.inventory.prices.duplicate(),
	}
	snapshot_taken.emit(loc.location_id, snap)
