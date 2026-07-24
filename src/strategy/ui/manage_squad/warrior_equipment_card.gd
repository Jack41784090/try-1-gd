@tool
class_name WarriorEquipmentCard
extends PanelContainer

signal equip_weapon_requested(warrior: Character, weapon: WeaponResource)
signal equip_armor_requested(warrior: Character, armor: ArmorConfig)
signal unequip_weapon_requested(warrior: Character)
signal unequip_armor_requested(warrior: Character)

@onready var _name_label: Label = $VBox/NameRow/NameLabel
@onready var _weapon_label: Label = $VBox/WeaponRow/ItemLabel
@onready var _unequip_weapon_btn: Button = $VBox/WeaponRow/UnequipBtn
@onready var _armor_label: Label = $VBox/ArmorRow/ItemLabel
@onready var _unequip_armor_btn: Button = $VBox/ArmorRow/UnequipBtn

var _warrior: Character


func setup(warrior: Character) -> void:
	if not is_node_ready():
		await ready

	_warrior = warrior

	var weapon := warrior.get_equipped_weapon()
	_weapon_label.text = SquadBattleTypes.WeaponClasses.keys()[weapon.weapon_class] if weapon else "Unarmed"
	_weapon_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0) if weapon else Color(0.5, 0.5, 0.5, 0.6))
	_unequip_weapon_btn.visible = weapon != null
	UIAnimations.register_button(_unequip_weapon_btn)
	_unequip_weapon_btn.pressed.connect(func(): unequip_weapon_requested.emit(_warrior))

	var armor := warrior.get_equipped_armor()
	_armor_label.text = SquadBattleTypes.ArmorClasses.keys()[armor.armor_class] if armor else "Unarmored"
	_armor_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55) if armor else Color(0.5, 0.5, 0.5, 0.6))
	_unequip_armor_btn.visible = armor != null
	UIAnimations.register_button(_unequip_armor_btn)
	_unequip_armor_btn.pressed.connect(func(): unequip_armor_requested.emit(_warrior))


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("item") \
	and (data["item"] is WeaponResource or data["item"] is ArmorConfig)


func _drop_data(_pos: Vector2, data: Variant) -> void:
	var item: CombatEquipment = data["item"]
	if item is WeaponResource:
		equip_weapon_requested.emit(_warrior, item)
	elif item is ArmorConfig:
		equip_armor_requested.emit(_warrior, item)
