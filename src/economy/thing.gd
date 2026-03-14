extends Resource
class_name Thing

@export var thing_id: String = ""
@export var thing_name: String = ""
@export var thing_type: EconomyTypes.ThingType = EconomyTypes.ThingType.FOOD
@export var base_price: float = 1.0
@export var description: String = ""

static func create(id: String, p_name: String, type: EconomyTypes.ThingType, price: float = 1.0, p_description: String = "") -> Thing:
	var t := Thing.new()
	t.thing_id = id
	t.thing_name = p_name
	t.thing_type = type
	t.base_price = price
	t.description = p_description
	return t

func get_label() -> String:
	if thing_name != "":
		return thing_name
	return EconomyTypes.ThingType.keys()[thing_type].capitalize()

func _to_string() -> String:
	return thing_name
