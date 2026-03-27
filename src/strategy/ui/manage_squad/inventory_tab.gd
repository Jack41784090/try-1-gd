class_name InventoryTab
extends Control

signal equip_weapon_requested(warrior: CharacterSocialStats, weapon: WeaponConfig)
signal equip_armor_requested(warrior: CharacterSocialStats, armor: ArmorConfig)
signal unequip_weapon_requested(warrior: CharacterSocialStats)
signal unequip_armor_requested(warrior: CharacterSocialStats)

var _title_label: Label
var _inventory_container: VBoxContainer
var _warriors_container: VBoxContainer
var _empty_label: Label

var _current_squad: SquadStrategicData
var _selected_weapon: WeaponConfig
var _selected_armor: ArmorConfig


func _ready() -> void:
	var main_hbox := HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 16)
	add_child(main_hbox)

	_build_inventory_panel(main_hbox)
	_build_warriors_panel(main_hbox)


func _build_inventory_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.45
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.8)
	style.border_color = Color(0.5, 0.4, 0.25, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "SQUAD INVENTORY"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5, 1.0))
	vbox.add_child(header)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.5, 0.4, 0.25, 0.4))
	vbox.add_child(sep)

	_empty_label = Label.new()
	_empty_label.text = "No items in inventory"
	_empty_label.add_theme_font_size_override("font_size", 14)
	_empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.8))
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_empty_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_inventory_container = VBoxContainer.new()
	_inventory_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_inventory_container)


func _build_warriors_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.55
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.8)
	style.border_color = Color(0.5, 0.4, 0.25, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "WARRIORS"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5, 1.0))
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.5, 0.4, 0.25, 0.4))
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_warriors_container = VBoxContainer.new()
	_warriors_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warriors_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_warriors_container)


func refresh(squad: SquadStrategicData) -> void:
	_current_squad = squad
	_selected_weapon = null
	_selected_armor = null
	_refresh_inventory()
	_refresh_warriors()


func _refresh_inventory() -> void:
	for child in _inventory_container.get_children():
		child.queue_free()

	var inv := _current_squad.inventory
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var type_label := Label.new()
	type_label.text = "[%s]" % item_type
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", color.darkened(0.2))
	type_label.custom_minimum_size.x = 70
	row.add_child(type_label)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var select_btn := Button.new()
	select_btn.text = "Select"
	select_btn.add_theme_font_size_override("font_size", 12)
	select_btn.custom_minimum_size = Vector2(70, 28)
	UIAnimations.register_button(select_btn)
	row.add_child(select_btn)

	row.set_meta("select_btn", select_btn)
	return row


func _create_warrior_card(warrior: CharacterSocialStats) -> PanelContainer:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.12, 0.16, 0.9)
	card_style.border_color = Color(0.4, 0.35, 0.25, 0.5)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(4)
	card_style.content_margin_left = 8
	card_style.content_margin_right = 8
	card_style.content_margin_top = 6
	card_style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "%s — %s" % [warrior.name, EntityClasses.Types.keys()[warrior.class_id]]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)

	var weapon_row := _create_equipment_row(
		"Weapon",
		warrior.equipment_weapon.weapon_name if warrior.equipment_weapon else "Unarmed",
		warrior.equipment_weapon != null,
		Color(0.7, 0.85, 1.0),
	)
	vbox.add_child(weapon_row)

	var equip_weapon_btn: Button = weapon_row.get_meta("equip_btn")
	var unequip_weapon_btn: Button = weapon_row.get_meta("unequip_btn")

	if _selected_weapon != null:
		equip_weapon_btn.text = "Equip"
		equip_weapon_btn.visible = true
		equip_weapon_btn.pressed.connect(func():
			equip_weapon_requested.emit(warrior, _selected_weapon)
		)
	else:
		equip_weapon_btn.visible = false

	unequip_weapon_btn.visible = warrior.equipment_weapon != null
	unequip_weapon_btn.pressed.connect(func():
		unequip_weapon_requested.emit(warrior)
	)

	var armor_row := _create_equipment_row(
		"Armor",
		warrior.equipment_armor.armor_name if warrior.equipment_armor else "Unarmored",
		warrior.equipment_armor != null,
		Color(0.85, 0.75, 0.55),
	)
	vbox.add_child(armor_row)

	var equip_armor_btn: Button = armor_row.get_meta("equip_btn")
	var unequip_armor_btn: Button = armor_row.get_meta("unequip_btn")

	if _selected_armor != null:
		equip_armor_btn.text = "Equip"
		equip_armor_btn.visible = true
		equip_armor_btn.pressed.connect(func():
			equip_armor_requested.emit(warrior, _selected_armor)
		)
	else:
		equip_armor_btn.visible = false

	unequip_armor_btn.visible = warrior.equipment_armor != null
	unequip_armor_btn.pressed.connect(func():
		unequip_armor_requested.emit(warrior)
	)

	return card


func _create_equipment_row(slot_name: String, item_name: String, has_item: bool, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var slot_label := Label.new()
	slot_label.text = "%s:" % slot_name
	slot_label.add_theme_font_size_override("font_size", 13)
	slot_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	slot_label.custom_minimum_size.x = 60
	row.add_child(slot_label)

	var item_label := Label.new()
	item_label.text = item_name
	item_label.add_theme_font_size_override("font_size", 13)
	item_label.add_theme_color_override("font_color", color if has_item else Color(0.5, 0.5, 0.5, 0.6))
	item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(item_label)

	var equip_btn := Button.new()
	equip_btn.text = "Equip"
	equip_btn.add_theme_font_size_override("font_size", 11)
	equip_btn.custom_minimum_size = Vector2(60, 24)
	equip_btn.visible = false
	UIAnimations.register_button(equip_btn)
	row.add_child(equip_btn)

	var unequip_btn := Button.new()
	unequip_btn.text = "Unequip"
	unequip_btn.add_theme_font_size_override("font_size", 11)
	unequip_btn.custom_minimum_size = Vector2(70, 24)
	unequip_btn.visible = false
	UIAnimations.register_button(unequip_btn)
	row.add_child(unequip_btn)

	row.set_meta("equip_btn", equip_btn)
	row.set_meta("unequip_btn", unequip_btn)
	return row


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
		var inv := _current_squad.inventory
		if _selected_weapon != null:
			idx = inv.weapons.find(_selected_weapon)
		elif _selected_armor != null:
			idx = inv.weapons.size() + inv.armors.find(_selected_armor)
		if idx >= 0 and idx < _inventory_container.get_child_count():
			var row = _inventory_container.get_child(idx)
			if row is HBoxContainer:
				var btn: Button = row.get_meta("select_btn")
				btn.text = "✓ Selected"
