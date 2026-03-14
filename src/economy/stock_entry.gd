class_name StockEntry
extends Resource

@export var thing: Thing
@export var amount: float = 0.0

static func create(t: Thing, amt: float) -> StockEntry:
	var e := StockEntry.new()
	e.thing = t
	e.amount = amt
	return e
