extends PanelContainer

@export var item_config: Resource

func _ready() -> void:
	assert(item_config is WeaponConfig or item_config is ArmorConfig, "item_config must be a WeaponConfig or ArmorConfig.")