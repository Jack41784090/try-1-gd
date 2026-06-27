extends PanelContainer

@export var item_config: CombatEquipment:
	set(_ic):
		if _ic and _draggable_comp:
			_draggable_comp.return_data = {"item": _ic}
		item_config = _ic
		return _ic
@onready var _icon: TextureRect = $MarginContainer/Icon
@onready var _name_label: RichTextLabel = $MarginContainer/RichTextLabel
@onready var _draggable_comp = $DraggableComponent


func _ready() -> void:
	if not item_config:
		item_config = load("res://resources/combat/weapon/config/mace.tres")
	setup(item_config)


func setup(item: CombatEquipment) -> void:
	item_config = item
	if item == null:
		_name_label.text = ""
		_icon.visible = false
		return
	_icon.visible = true
	if item is WeaponResource:
		_name_label.text = SquadBattleTypes.WeaponClasses.keys()[item.weapon_class]
	elif item is ArmorConfig:
		_name_label.text = SquadBattleTypes.ArmorClasses.keys()[item.armor_class]
