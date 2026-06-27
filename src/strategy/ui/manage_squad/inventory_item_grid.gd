extends PanelContainer

@export var item_config: CombatEquipment:
	set(_ic):
		if item_config != _ic:
			item_config = _ic
			setup(_ic)
@onready var _icon: TextureRect = $MarginContainer/Icon
@onready var _name_label: RichTextLabel = $MarginContainer/RichTextLabel
@onready var _draggable_comp = $DraggableComponent


func _ready() -> void:
	setup(item_config)


func setup(item: CombatEquipment) -> void:
	if not is_node_ready():
		await self.ready

	if item == null:
		_name_label.text = ""
		_icon.visible = false
	else:
		_draggable_comp.return_data = { "item": item }
		_icon.visible = true
		_icon.texture = item.icon
		if item is WeaponResource:
			_name_label.text = SquadBattleTypes.WeaponClasses.keys()[item.weapon_class]
		elif item is ArmorConfig:
			_name_label.text = SquadBattleTypes.ArmorClasses.keys()[item.armor_class]
