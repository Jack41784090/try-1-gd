extends Resource
class_name EconomicDemand

var demand_id: String = ""
var thing: Thing
var quantity: float = 0.0
var max_price: float = 0.0
var location_id: String = ""
var demander_id: String = ""
var priority: float = 1.0
var fulfilled: float = 0.0


var unfulfilled: float:
	get: return maxf(quantity - fulfilled, 0.0)


static func create(
	p_thing: Thing,
	p_quantity: float,
	p_max_price: float,
	p_location_id: String,
	p_demander_id: String,
	p_priority: float = 1.0,
) -> EconomicDemand:
	var d := EconomicDemand.new()
	d.demand_id = "%s_%s_%s" % [p_location_id, p_demander_id, p_thing.thing_id]
	d.thing = p_thing
	d.quantity = p_quantity
	d.max_price = p_max_price
	d.location_id = p_location_id
	d.demander_id = p_demander_id
	d.priority = p_priority
	return d


func _to_string() -> String:
	return "Demand(%s: %.1f %s @ %.1f, %s)" % [
		demander_id, quantity, thing.thing_name, max_price, location_id,
	]
