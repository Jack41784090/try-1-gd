class_name Shop extends Resource

@export var shop_name: String = "General Store"
@export var items: Array[ShopItem] = []

func get_item_by_type(item_type: StrategyTypes.ItemType) -> ShopItem:
	for item in items:
		if item.item_type == item_type:
			return item
	return null
