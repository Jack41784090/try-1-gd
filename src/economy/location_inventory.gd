extends Resource
class_name LocationInventory

@export var initial_stocks: Array[StockEntry] = []

var stocks: Dictionary = {}
var prices: Dictionary = {}
var _initialized: bool = false

func get_available(thing: Thing) -> float:
	_ensure_initialized()
	return stocks.get(thing, 0.0)

func add(thing: Thing, qty: float) -> void:
	_ensure_initialized()
	stocks[thing] = stocks.get(thing, 0.0) + qty

func consume(thing: Thing, qty: float) -> float:
	_ensure_initialized()
	var available: float = stocks.get(thing, 0.0)
	var consumed := minf(available, qty)
	stocks[thing] = available - consumed
	return consumed

func get_price(thing: Thing) -> float:
	_ensure_initialized()
	return prices.get(thing, thing.base_price)

func set_price(thing: Thing, price: float) -> void:
	_ensure_initialized()
	prices[thing] = price

func update_prices(total_demand: Dictionary) -> void:
	_ensure_initialized()
	for thing in stocks:
		var demand: float = total_demand.get(thing, 0.0)
		var supply: float = stocks.get(thing, 0.01)
		supply = maxf(supply, 0.01)
		var ratio := demand / supply
		var new_price: float = thing.base_price * clampf(ratio, 0.5, 3.0)
		prices[thing] = new_price

func init_thing(thing: Thing, starting_stock: float = 0.0) -> void:
	_ensure_initialized()
	stocks[thing] = starting_stock
	prices[thing] = thing.base_price

func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	for entry in initial_stocks:
		if entry.thing and not stocks.has(entry.thing):
			stocks[entry.thing] = entry.amount
			prices[entry.thing] = entry.thing.base_price

func _to_string() -> String:
	_ensure_initialized()
	var parts: Array[String] = []
	for thing in stocks:
		parts.append("%s: %.1f @ %.2f" % [thing.thing_name, stocks[thing], get_price(thing)])
	return ", ".join(parts)
