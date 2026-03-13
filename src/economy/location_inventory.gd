extends RefCounted
class_name LocationInventory

var stocks: Dictionary = {}
var prices: Dictionary = {}

func get_available(thing: Thing) -> float:
	return stocks.get(thing, 0.0)

func add(thing: Thing, qty: float) -> void:
	stocks[thing] = stocks.get(thing, 0.0) + qty

func consume(thing: Thing, qty: float) -> float:
	var available: float = stocks.get(thing, 0.0)
	var consumed := minf(available, qty)
	stocks[thing] = available - consumed
	return consumed

func get_price(thing: Thing) -> float:
	return prices.get(thing, thing.base_price)

func set_price(thing: Thing, price: float) -> void:
	prices[thing] = price

func update_prices(total_demand: Dictionary) -> void:
	for thing in stocks:
		var demand: float = total_demand.get(thing, 0.0)
		var supply: float = stocks.get(thing, 0.01)
		supply = maxf(supply, 0.01)
		var ratio := demand / supply
		var new_price: float = thing.base_price * clampf(ratio, 0.5, 3.0)
		prices[thing] = new_price

func init_thing(thing: Thing, starting_stock: float = 0.0) -> void:
	stocks[thing] = starting_stock
	prices[thing] = thing.base_price

func _to_string() -> String:
	var parts: Array[String] = []
	for thing in stocks:
		parts.append("%s: %.1f @ %.2f" % [thing.thing_name, stocks[thing], get_price(thing)])
	return ", ".join(parts)
