class_name TacticsTab
extends Control

signal tactic_selected(tactic: Tactic)

var _cards_container: VBoxContainer
var _current_tactic_id: String = ""

const TACTIC_DEFS: Array[Dictionary] = [
	{
		"type": Tactic.TacticType.BALANCED,
		"name": "Balanced",
		"desc": "Standard formation. Equal actions and reactions.",
		"stats": "ATK: x1.0  DEF: x1.0  Actions: 1  Reactions: 1",
	},
	{
		"type": Tactic.TacticType.AGGRESSIVE_CHARGE,
		"name": "Aggressive Charge",
		"desc": "Push forward with extra attacks at the cost of defense.",
		"stats": "ATK: x1.0  DEF: x0.8  Actions: 2  Reactions: 1",
	},
	{
		"type": Tactic.TacticType.GUERILLA_DEFENCE,
		"name": "Guerilla Defence",
		"desc": "Reactive stance that favors counter-attacks.",
		"stats": "ATK: x0.8  DEF: x1.0  Actions: 1  Reactions: 2",
	},
	{
		"type": Tactic.TacticType.FULL_ASSAULT,
		"name": "Full Assault",
		"desc": "All-out attack. Maximum aggression, minimal protection.",
		"stats": "ATK: x1.2  DEF: x0.6  Actions: 3  Reactions: 0",
	},
	{
		"type": Tactic.TacticType.DEFENSIVE_FORMATION,
		"name": "Defensive Formation",
		"desc": "Hold the line. Maximum defense, no attacks.",
		"stats": "ATK: x0.6  DEF: x1.2  Actions: 0  Reactions: 3",
	},
]


func _ready() -> void:
	_cards_container = VBoxContainer.new()
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_container.add_theme_constant_override("separation", 8)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	scroll.add_child(_cards_container)


func refresh(squad: SquadData) -> void:
	_current_tactic_id = squad.current_tactic.tactic_id if squad.current_tactic else "balanced"
	_rebuild_cards()


func _rebuild_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()

	for def in TACTIC_DEFS:
		_cards_container.add_child(_create_card(def))


func _create_card(def: Dictionary) -> PanelContainer:
	var tactic := Tactic.create_from_type(def["type"] as Tactic.TacticType)
	var is_active := tactic.tactic_id == _current_tactic_id

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 90)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.22, 0.15, 0.95) if is_active else Color(0.12, 0.12, 0.16, 0.9)
	style.border_width_left = 3 if is_active else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.8, 0.7, 0.3, 1.0) if is_active else Color(0.4, 0.35, 0.25, 0.6)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = def["name"]
	name_label.add_theme_font_size_override("font_size", 18)
	if is_active:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65, 1.0))
	info_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = def["desc"]
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)

	var stats_label := Label.new()
	stats_label.text = def["stats"]
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55, 1.0))
	info_vbox.add_child(stats_label)

	if is_active:
		var active_label := Label.new()
		active_label.text = "ACTIVE"
		active_label.add_theme_font_size_override("font_size", 14)
		active_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1.0))
		active_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(active_label)
	else:
		var select_btn := Button.new()
		select_btn.text = "Select"
		select_btn.custom_minimum_size = Vector2(80, 36)
		select_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UIAnimations.register_button(select_btn)
		select_btn.pressed.connect(func(): tactic_selected.emit(tactic))
		hbox.add_child(select_btn)

	return panel
