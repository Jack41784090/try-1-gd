class_name BuySuppliesHandler
extends ActivityHandler


func execute(context: Dictionary, result: ActivityResult) -> ActivityResult:
	var squad = context.get("squad") as SquadData
	var world = context.get("world") as World
	var location = world.get_location_by_id(squad.current_location_id)
	assert(location != null, "BUY_SUPPLIES location not found for squad '%s'" % squad.squad_id)
	assert(location.has_shop(), "BUY_SUPPLIES at '%s' requires shop" % location.location_id)
	assert(location.inventory != null, "BUY_SUPPLIES at '%s' requires inventory-backed economy" % location.location_id)

	var shop = location.shop
	var supply_thing: Thing = shop.get_thing_by_type(EconomyTypes.ThingType.FOOD)
	assert(supply_thing != null, "Shop at '%s' must provide FOOD for BUY_SUPPLIES" % location.location_id)

	var price: float = supply_thing.base_price
	var desired_amount := 5
	var affordable = int(squad.money / price)
	var buy_amount = mini(desired_amount, affordable)

	if buy_amount > 0:
		squad.spend_money(buy_amount * price)
		squad.food += buy_amount
		StrategyEventBus.squad_resource_changed.emit("money", squad.money)
		StrategyEventBus.squad_resource_changed.emit("food", squad.food)
		Log.info("BuySuppliesHandler", "BUY_SUPPLIES at %s: bought %d for %.0f gold (food now %d)" % [
			location.location_name,
			buy_amount,
			buy_amount * price,
			squad.food,
		])

	return result
