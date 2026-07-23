@tool
class_name InventoryItemContainer
extends PanelContainer

@export var item_config: CombatEquipment:
	set(_ic):
		if item_config != _ic:
			item_config = _ic
			setup(_ic)
@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
#@onready var _draggable_comp = $DraggableComponent

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup(item_config)


func setup(item: CombatEquipment) -> void:
	if not is_node_ready():
		await self.ready

	if item == null:
		_name_label.text = ""
		_icon.texture = load("res://assets/hoi4_icons/divisions.png")
	else:
		#_draggable_comp.return_data = { "item": item }
		_icon.visible = true
		var icon_tex = item.get("icon")
		_icon.texture = icon_tex if icon_tex != null else load("res://assets/hoi4_icons/divisions.png")
		if item is WeaponResource:
			_name_label.text = SquadBattleTypes.WeaponClasses.keys()[item.weapon_class]
		elif item is ArmorConfig:
			_name_label.text = SquadBattleTypes.ArmorClasses.keys()[item.armor_class]
