extends Resource
class_name ThingInput

@export var thing: Thing
@export var quantity: float = 1.0

static func create(p_thing: Thing, p_quantity: float = 1.0) -> ThingInput:
	var ti := ThingInput.new()
	ti.thing = p_thing
	ti.quantity = p_quantity
	return ti
