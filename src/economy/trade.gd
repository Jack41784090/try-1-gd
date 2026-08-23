extends RefCounted
class_name Trade

## Carries every reference it needs (squad + location), so committing it never requires reaching into World. unit_price is locked at creation time.

var squad: StrategySquad
var location: Location
var thing: Thing
var quantity: float
var unit_price: float
var is_buy: bool
var state: EconomyTypes.TradeState = EconomyTypes.TradeState.PENDING


func _to_string() -> String:
	return "%s %s %.0f %s @ %.2f at %s (%s)" % [
		squad.squad_name,
		"buys" if is_buy else "sells",
		quantity,
		thing.thing_name,
		unit_price,
		location.location_name,
		EconomyTypes.TradeState.keys()[state],
	]


static func create(
	p_squad: StrategySquad,
	p_location: Location,
	p_thing: Thing,
	qty: float,
	buy: bool,
) -> Trade:
	var t := Trade.new()
	t.squad = p_squad
	t.location = p_location
	t.thing = p_thing
	t.quantity = qty
	t.is_buy = buy
	t.unit_price = p_location.inventory.get_price(p_thing)
	return t


## Empty string means the trade can commit.
func get_rejection_reason() -> String:
	if quantity <= 0.0:
		return "quantity must be positive"
	if is_buy:
		var available := location.inventory.get_available(thing)
		if available < quantity:
			return "%s has only %.1f %s in stock" % [location.location_name, available, thing.thing_name]
		var cost := unit_price * quantity
		if squad.money < cost:
			return "%s needs %.2f gold but has %.2f" % [squad.squad_name, cost, squad.money]
	else:
		var carried: float = squad.cargo.manifest.get(thing, 0.0)
		if carried < quantity:
			return "%s carries only %.1f %s" % [squad.squad_name, carried, thing.thing_name]
	return ""


## Re-validates first — state may have drifted between queueing and the commit barrier.
func commit() -> bool:
	assert(state == EconomyTypes.TradeState.PENDING)
	if not get_rejection_reason().is_empty():
		state = EconomyTypes.TradeState.REJECTED
		return false
	var total := unit_price * quantity
	if is_buy:
		var paid := squad.spend_money(total)
		assert(paid)
		location.inventory.consume(thing, quantity)
		squad.cargo.manifest[thing] = squad.cargo.manifest.get(thing, 0.0) + quantity
	else:
		squad.cargo.manifest[thing] = squad.cargo.manifest.get(thing, 0.0) - quantity
		location.inventory.add(thing, quantity)
		squad.gain_money(total)
	state = EconomyTypes.TradeState.COMMITTED
	return true
