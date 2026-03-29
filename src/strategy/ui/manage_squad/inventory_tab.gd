class_name InventoryTab
extends Control

signal equip_weapon_requested(warrior: Warrior, weapon: WeaponConfig)
signal equip_armor_requested(warrior: Warrior, armor: ArmorConfig)
signal unequip_weapon_requested(warrior: Warrior)
signal unequip_armor_requested(warrior: Warrior)

const ITEM_ROW_SCENE = preload("res://scenes/ui/manage_squad/inventory_item_row.tscn")
const WARRIOR_CARD_SCENE = preload("res://scenes/ui/manage_squad/warrior_equipment_card.tscn")

@onready var _title_label: Label = $MainHBox/WarriorsPanel/VBox/TitleLabel
@onready var _inventory_container: VBoxContainer = $MainHBox/InventoryPanel/VBox/InventoryScroll/InventoryContainer
@onready var _warriors_container: VBoxContainer = $MainHBox/WarriorsPanel/VBox/WarriorsScroll/WarriorsContainer
@onready var _empty_label: Label = $MainHBox/InventoryPanel/VBox/EmptyLabel

var _current_squad: SquadData
var _selected_weapon: WeaponConfig
var _selected_armor: ArmorConfig


func refresh(squad: SquadData) -> void:
	_current_squad = squad
	_selected_weapon = null
	_selected_armor = null
	_refresh_inventory()
	_refresh_warriors()


func _refresh_inventory() -> void:
	for child in _inventory_container.get_children():
		child.queue_free()

	var inv = _current_squad.inventory
	_empty_label.visible = inv.is_empty()

	for weapon in inv.weapons:
		var row := _create_item_row(weapon.weapon_name, "Weapon", Color(0.7, 0.85, 1.0))
		var select_btn := row.get_meta("select_btn") as Button
		select_btn.pressed.connect(_on_weapon_selected.bind(weapon, select_btn))
		_inventory_container.add_child(row)

	for armor in inv.armors:
		var row := _create_item_row(armor.armor_name, "Armor", Color(0.85, 0.75, 0.55))
		var select_btn := row.get_meta("select_btn") as Button
		select_btn.pressed.connect(_on_armor_selected.bind(armor, select_btn))
		_inventory_container.add_child(row)


func _refresh_warriors() -> void:
	for child in _warriors_container.get_children():
		child.queue_free()

	_title_label.text = "WARRIORS — %d" % _current_squad.get_living_warriors().size()

	for warrior in _current_squad.get_living_warriors():
		var card := _create_warrior_card(warrior)
		_warriors_container.add_child(card)


func _create_item_row(item_name: String, item_type: String, color: Color) -> HBoxContainer:
	var row: HBoxContainer = ITEM_ROW_SCENE.instantiate()

	var type_label: Label = row.get_node("TypeLabel")
	type_label.text = "[%s]" % item_type
	type_label.add_theme_color_override("font_color", color.darkened(0.2))

	var name_label: Label = row.get_node("NameLabel")
	name_label.text = item_name
	name_label.add_theme_color_override("font_color", color)

	var select_btn: Button = row.get_node("SelectButton")
	UIAnimations.register_button(select_btn)

	row.set_meta("select_btn", select_btn)
	return row


func _create_warrior_card(warrior: Warrior) -> PanelContainer:
	var card: PanelContainer = WARRIOR_CARD_SCENE.instantiate()

	var name_label: Label = card.get_node("VBox/NameRow/NameLabel")
	name_label.text = "%s — %s" % [warrior.name, EntityClasses.Types.keys()[warrior.class_id]]

	var weapon_name_label: Label = card.get_node("VBox/WeaponRow/ItemLabel")
	weapon_name_label.text = warrior.equipment_weapon.weapon_name if warrior.equipment_weapon else "Unarmed"
	weapon_name_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0) if warrior.equipment_weapon else Color(0.5, 0.5, 0.5, 0.6))

	var equip_weapon_btn: Button = card.get_node("VBox/WeaponRow/EquipBtn")
	var unequip_weapon_btn: Button = card.get_node("VBox/WeaponRow/UnequipBtn")

	if _selected_weapon != null:
		equip_weapon_btn.visible = true
		UIAnimations.register_button(equip_weapon_btn)
		equip_weapon_btn.pressed.connect(
			func():
				equip_weapon_requested.emit(warrior, _selected_weapon)
		)
	else:
		equip_weapon_btn.visible = false

	unequip_weapon_btn.visible = warrior.equipment_weapon != null
	UIAnimations.register_button(unequip_weapon_btn)
	unequip_weapon_btn.pressed.connect(
		func():
			unequip_weapon_requested.emit(warrior)
	)

	var armor_name_label: Label = card.get_node("VBox/ArmorRow/ItemLabel")
	armor_name_label.text = warrior.equipment_armor.armor_name if warrior.equipment_armor else "Unarmored"
	armor_name_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55) if warrior.equipment_armor else Color(0.5, 0.5, 0.5, 0.6))

	var equip_armor_btn: Button = card.get_node("VBox/ArmorRow/EquipBtn")
	var unequip_armor_btn: Button = card.get_node("VBox/ArmorRow/UnequipBtn")

	if _selected_armor != null:
		equip_armor_btn.visible = true
		UIAnimations.register_button(equip_armor_btn)
		equip_armor_btn.pressed.connect(
			func():
				equip_armor_requested.emit(warrior, _selected_armor)
		)
	else:
		equip_armor_btn.visible = false

	unequip_armor_btn.visible = warrior.equipment_armor != null
	UIAnimations.register_button(unequip_armor_btn)
	unequip_armor_btn.pressed.connect(
		func():
			unequip_armor_requested.emit(warrior)
	)

	return card


func _on_weapon_selected(weapon: WeaponConfig, btn: Button) -> void:
	_selected_weapon = weapon
	_selected_armor = null
	_highlight_selection()
	_refresh_warriors()


func _on_armor_selected(armor: ArmorConfig, btn: Button) -> void:
	_selected_armor = armor
	_selected_weapon = null
	_highlight_selection()
	_refresh_warriors()


func _highlight_selection() -> void:
	for child in _inventory_container.get_children():
		if child is HBoxContainer:
			var btn: Button = child.get_meta("select_btn")
			btn.text = "Select"

	if _selected_weapon != null or _selected_armor != null:
		var idx := 0
		var inv = _current_squad.inventory
		if _selected_weapon != null:
			idx = inv.weapons.find(_selected_weapon)
		elif _selected_armor != null:
			idx = inv.weapons.size() + inv.armors.find(_selected_armor)
		if idx >= 0 and idx < _inventory_container.get_child_count():
			var row = _inventory_container.get_child(idx)
			if row is HBoxContainer:
				var btn: Button = row.get_meta("select_btn")
				btn.text = "✓ Selected"
