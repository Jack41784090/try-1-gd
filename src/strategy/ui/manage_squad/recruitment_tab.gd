class_name RecruitmentTab
extends Control

signal recruit_requested(class_enum: EntityClasses.Types, cost: float)

var _money_label: Label
var _classes_container: VBoxContainer
var _current_squad: SquadData

const RECRUITMENT_COSTS: Dictionary = {
	EntityClasses.Types.Landsknecht: 100.0,
	EntityClasses.Types.Healer: 150.0,
	EntityClasses.Types.Crossbowman: 120.0,
	EntityClasses.Types.Arquebusier: 200.0,
	EntityClasses.Types.Pikeman: 130.0,
	EntityClasses.Types.Feldprediger: 180.0,
	EntityClasses.Types.Gelehrter: 250.0,
}


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 18)
	_money_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1.0))
	vbox.add_child(_money_label)

	_classes_container = VBoxContainer.new()
	_classes_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_classes_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_classes_container)


func refresh(squad: SquadData, _actor: ActivityRunner) -> void:
	_current_squad = squad
	_money_label.text = "Available Gold: %.0f" % squad.money

	for child in _classes_container.get_children():
		child.queue_free()

	for class_enum in EntityClasses.Types.values():
		_classes_container.add_child(_create_class_card(class_enum))


func _create_class_card(class_enum: EntityClasses.Types) -> PanelContainer:
	var entity_template = EntityFactory.get_entity(class_enum)
	var cost: float = RECRUITMENT_COSTS.get(class_enum, 100.0)
	var can_afford := _current_squad.money >= cost

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.35, 0.25, 0.6)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var icon_rect := TextureRect.new()
	if entity_template.icon:
		icon_rect.texture = entity_template.icon
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon_rect)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = entity_template.entity_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1.0))
	info_vbox.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "Cost: %.0f gold" % cost
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1.0))
	info_vbox.add_child(cost_label)

	if entity_template.stats:
		var stats_label := Label.new()
		stats_label.text = "STR:%.0f DEX:%.0f END:%.0f INT:%.0f" % [
			entity_template.stats.strength,
			entity_template.stats.dex,
			entity_template.stats.endurance,
			entity_template.stats.int_stat
		]
		stats_label.add_theme_font_size_override("font_size", 11)
		stats_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		info_vbox.add_child(stats_label)

	var recruit_btn := Button.new()
	recruit_btn.custom_minimum_size = Vector2(100, 36)
	recruit_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if can_afford:
		recruit_btn.text = "Recruit"
		recruit_btn.pressed.connect(func(): recruit_requested.emit(class_enum, cost))
	else:
		recruit_btn.text = "Can't Afford"
		recruit_btn.disabled = true
		recruit_btn.tooltip_text = "Need %.0f more gold" % (cost - _current_squad.money)

	UIAnimations.register_button(recruit_btn)
	hbox.add_child(recruit_btn)

	return panel
