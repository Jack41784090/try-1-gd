extends RefCounted
class_name CaravanBridge

## Factory methods for creating caravan squads from economy moves.
## cargo_manifest uses thing_id (String) keys.


static func create_caravan_squad(
	move: EconomyMove,
	shipment_id: String,
	guard_count: int = 2,
) -> SquadStrategicData:
	var squad := SquadStrategicData.new()
	squad.squad_id = "caravan_%s" % shipment_id
	squad.squad_name = "%s Caravan" % move.thing.thing_name.capitalize()
	squad.starting_location_id = move.source_location_id
	squad.current_location_id = move.source_location_id
	squad.squad_role = StrategyTypes.SquadRole.MERCHANT
	squad.money = move.quantity * move.thing.base_price
	squad.food = maxi(guard_count * move.turns_remaining, 3)
	squad.karma = -50.0
	squad.shipment_id = shipment_id

	squad.cargo_manifest[move.thing.thing_id] = move.quantity
	squad.cargo_destination_id = move.dest_location_id

	for i in range(guard_count):
		var warrior := _create_caravan_guard(squad.squad_id, i)
		squad.add_warrior(warrior)

	return squad


static func _create_caravan_guard(squad_id: String, index: int) -> CharacterSocialStats:
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
	squad: SquadStrategicData,
	dest_inventory: LocationInventory,
	goods_registry: Array[Thing],
) -> void:
	for thing_id in squad.cargo_manifest:
		var qty: float = squad.cargo_manifest[thing_id]
		if qty <= 0.0:
			continue
		var thing := _find_thing(thing_id, goods_registry)
		if thing:
			dest_inventory.add(thing, qty)
			Log.info("Caravan", "Delivered %.1f %s to %s" % [
				qty, thing.thing_name, squad.cargo_destination_id,
			])
	squad.cargo_manifest.clear()


static func apply_loot(
	caravan: SquadStrategicData,
	attacker: SquadStrategicData,
) -> Dictionary:
	var looted: Dictionary = {}
	for thing_id in caravan.cargo_manifest:
		var qty: float = caravan.cargo_manifest[thing_id]
		if qty <= 0.0:
			continue
		if thing_id == "food":
			attacker.food += int(qty)
		else:
			attacker.gain_money(qty * 2.0)
		looted[thing_id] = qty
		Log.info("Caravan", "Looted %.1f %s from %s" % [
			qty, thing_id, caravan.squad_name,
		])
	caravan.cargo_manifest.clear()
	return looted


static func _find_thing(thing_id: String, goods: Array[Thing]) -> Thing:
	for thing in goods:
		if thing.thing_id == thing_id:
			return thing
	return null
