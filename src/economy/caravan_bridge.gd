class_name CaravanBridge extends RefCounted

## Factory methods for creating caravan squads from economy moves.
## cargo_manifest uses thing_id (String) keys.


static func create_caravan_squad(
	move: EconomyMove,
	shipment_id: String,
	guard_count: int = 2,
) -> SquadData:
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

	for i in range(guard_count):
		var warrior := _create_caravan_guard(squad.squad_id, i)
		squad.add_warrior(warrior)

	return squad


static func _create_caravan_guard(squad_id: String, index: int) -> Warrior:
	var guard := WarriorFactory.create_warrior(
		EntityClasses.Types.Landsknecht,
		"%s_guard_%d" % [squad_id, index],
		"Caravan Guard",
		StrategyTypes.Religion.CATHOLIC,
		EntityBaseStats.new(),
	)
	guard.morale = 60.0
	guard.set_attribute(StrategyTypes.WarriorAttribute.PERCEPTION, 15)
	guard.set_attribute(StrategyTypes.WarriorAttribute.STEALTH, 5)
	return guard


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
	squad: SquadData,
	dest_inventory: LocationInventory,
	goods_registry: Array[Thing],
) -> void:
	for thing_id in squad.cargo.manifest:
		var qty: float = squad.cargo.manifest[thing_id]
		var thing := _find_thing(thing_id, goods_registry)
		if thing:
			dest_inventory.add(thing, qty)
			Log.info("Caravan", "Delivered %.1f %s to %s" % [
				qty, thing.thing_name, squad.cargo.destination_id,
			])
	squad.cargo.manifest.clear()


static func apply_loot(
	caravan: SquadData,
	attacker: SquadData,
) -> Dictionary:
	var looted: Dictionary = {}
	for thing_id in caravan.cargo.manifest:
		var qty: float = caravan.cargo.manifest[thing_id]
		if thing_id == "food":
			attacker.food += int(qty)
		else:
			attacker.gain_money(qty * 2.0)
		looted[thing_id] = qty
		Log.info("Caravan", "Looted %.1f %s from %s" % [
			qty, thing_id, caravan.squad_name,
		])
	caravan.cargo.manifest.clear()
	return looted


static func reassign_caravan(
	squad: SquadData,
	move: EconomyMove,
	shipment_id: String,
) -> void:
	squad.cargo.manifest.clear()
	squad.cargo.manifest[move.thing.thing_id] = move.quantity
	squad.cargo.destination_id = move.dest_location_id
	squad.cargo.shipment_id = shipment_id
	squad.money = move.quantity * move.thing.base_price
	squad.food = maxi(squad.get_living_warriors().size() * move.turns_remaining, 3)
	Log.info("Caravan", "Reassigned %s: %s → %s (%.1f %s)" % [
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
