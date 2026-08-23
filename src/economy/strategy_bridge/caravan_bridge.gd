class_name CaravanBridge extends RefCounted


static func create_caravan_squad(
	move: EconomyMove,
	shipment_id: String,
	guard_count: int = 2,
) -> StrategySquad:
	var squad := SquadDataFactory.create_squad(
		"caravan_%s" % shipment_id,
		_next_convoy_name(move.thing.thing_name),
		move.quantity * move.thing.base_price,
		maxi(guard_count * move.turns_remaining, 3),
		5,
		-50.0,
		move.source_location_id,
		move.source_location_id,
		StrategyTypes.SquadRole.MERCHANT,
	)
	squad.cargo.shipment_id = shipment_id
	squad.cargo.manifest[move.thing.thing_id] = move.quantity
	squad.cargo.destination_id = move.dest_location_id

	return squad


static func _create_caravan_guard(_squad_id: String, _index: int) -> StrategyEntity:
	push_error("CaravanBridge._create_caravan_guard disabled during StrategyEntity rewrite")
	return null


static func calculate_guard_count(move: EconomyMove) -> int:
	var cargo_value := move.quantity * move.thing.base_price
	if cargo_value < 20.0:
		return 1
	if cargo_value < 100.0:
		return 2
	if cargo_value < 300.0:
		return 3
	return 4


static func apply_delivery(
	squad: StrategySquad,
	dest_inventory: LocationInventory,
	goods_registry: Array[Thing],
) -> void:
	for thing_id in squad.cargo.manifest:
		var qty: float = squad.cargo.manifest[thing_id]
		var thing := _find_thing(thing_id, goods_registry)
		if thing:
			dest_inventory.add(thing, qty)
			MyLog.info("Caravan", "Delivered %.1f %s to %s" % [
				qty, thing.thing_name, squad.cargo.destination_id,
			])
	squad.cargo.manifest.clear()


static func apply_loot(
	caravan: StrategySquad,
	attacker: StrategySquad,
) -> Dictionary:
	var looted: Dictionary = {}
	for thing_id in caravan.cargo.manifest:
		var qty: float = caravan.cargo.manifest[thing_id]
		if thing_id == "food":
			attacker.food += int(qty)
		else:
			attacker.gain_money(qty * 2.0)
		looted[thing_id] = qty
		MyLog.info("Caravan", "Looted %.1f %s from %s" % [
			qty, thing_id, caravan.squad_name,
		])
	caravan.cargo.manifest.clear()
	return looted


static func execute_caravan_reassignment(
	squad: StrategySquad,
	move: EconomyMove,
	shipment_id: String,
) -> void:
	squad.cargo.manifest.clear()
	squad.cargo.manifest[move.thing.thing_id] = move.quantity
	squad.cargo.destination_id = move.dest_location_id
	squad.cargo.shipment_id = shipment_id
	squad.money = move.quantity * move.thing.base_price
	squad.food = maxi(squad.get_living_warriors().size() * move.turns_remaining, 3)
	MyLog.info("Caravan", "Reassigned %s: %s → %s (%.1f %s)" % [
		squad.squad_name, squad.current_location_id,
		move.dest_location_id, move.quantity, move.thing.thing_name,
	])


static func _find_thing(thing_id: String, goods: Array[Thing]) -> Thing:
	for thing in goods:
		if thing.thing_id == thing_id:
			return thing
	return null


static func _next_convoy_name(goods_name: String) -> String:
	return ConvoyNames.next_name(goods_name)
