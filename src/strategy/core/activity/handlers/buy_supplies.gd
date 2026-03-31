class_name BuySuppliesHandler
extends ActivityHandler


func execute(context: Dictionary, result: ActivityResult) -> ActivityResult:
	var squad = context.get("squad") as SquadData
	var world = context.get("world") as World
	var location = world.get_location_by_id(squad.current_location_id)

	if not location or not location.has_shop():
		return result

	var shop = location.shop
	var supply_thing: Thing = shop.get_thing_by_type(EconomyTypes.ThingType.FOOD)
	if not supply_thing:
		return result

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
