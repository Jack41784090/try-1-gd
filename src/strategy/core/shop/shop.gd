class_name Shop extends Resource

@export var shop_name: String = "General Store"
@export var items: Array[Thing] = []

func get_thing_by_type(thing_type: EconomyTypes.ThingType) -> Thing:
	for item in items:
		if item.thing_type == thing_type:
			return item
	return null
