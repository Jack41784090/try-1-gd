class_name ShopItem extends Resource

@export var item_type: StrategyTypes.ItemType = StrategyTypes.ItemType.SUPPLY
@export var price: float = 10.0
@export var display_name: String = ""
@export var description: String = ""

func get_label() -> String:
	if display_name != "":
		return display_name
	return StrategyTypes.ItemType.keys()[item_type].capitalize()
