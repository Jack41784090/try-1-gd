@tool
class_name ArmorControl
extends PanelContainer

@export var armor_config: ArmorConfig
@onready var inv_grid = $InventoryItem


func _ready() -> void:
	inv_grid.item_config = armor_config
