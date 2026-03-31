extends Resource
class_name EconomicSupply

var supply_id: String = ""
var thing: Thing
var quantity: float = 0.0
var cost_basis: float = 0.0
var location_id: String = ""
var supplier_id: String = ""
var reserved: float = 0.0


var available: float:
	get: return maxf(quantity - reserved, 0.0)


static func create(
	p_thing: Thing,
	p_quantity: float,
	p_cost_basis: float,
	p_location_id: String,
	p_supplier_id: String,
) -> EconomicSupply:
	var s := EconomicSupply.new()
	s.supply_id = "%s_%s_%s" % [p_location_id, p_supplier_id, p_thing.thing_id]
	s.thing = p_thing
	s.quantity = p_quantity
	s.cost_basis = p_cost_basis
	s.location_id = p_location_id
	s.supplier_id = p_supplier_id
	return s


func _to_string() -> String:
	return "Supply(%s: %.1f %s @ cost %.1f, %s)" % [
		supplier_id, quantity, thing.thing_name, cost_basis, location_id,
	]
