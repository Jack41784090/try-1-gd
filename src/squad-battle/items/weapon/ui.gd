class_name WeaponControl
extends PanelContainer

@export var weapon_config: WeaponResource
@onready var inv_grid = $InventoryItem


func _ready() -> void:
	inv_grid.item_config = weapon_config
