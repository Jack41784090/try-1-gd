class_name FormationSlot
extends PanelContainer

signal warrior_dropped(warrior: Character, slot: Variant)
signal slot_clicked(slot: Variant)

var warrior: Character = null
var row_position: SquadBattleTypes.SquadEntityInSquadLocation
var slot_index: int = 0

@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _class_label: Label = $Margin/VBox/ClassLabel
@onready var _hp_label: Label = $Margin/VBox/HPLabel

var _style_empty: StyleBoxFlat
var _style_filled: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_selected: StyleBoxFlat
var _is_hovered: bool = false
var _is_selected: bool = false


func _init() -> void:
	_style_empty = StyleBoxFlat.new()
	_style_empty.bg_color = Color(0.1, 0.1, 0.14, 0.6)
	_style_empty.border_width_left = 1
	_style_empty.border_width_top = 1
	_style_empty.border_width_right = 1
	_style_empty.border_width_bottom = 1
	_style_empty.border_color = Color(0.3, 0.3, 0.35, 0.5)
	_style_empty.corner_radius_top_left = 4
	_style_empty.corner_radius_top_right = 4
	_style_empty.corner_radius_bottom_left = 4
	_style_empty.corner_radius_bottom_right = 4

	_style_filled = StyleBoxFlat.new()
	_style_filled.bg_color = Color(0.15, 0.18, 0.12, 0.9)
	_style_filled.border_width_left = 2
	_style_filled.border_width_top = 1
	_style_filled.border_width_right = 1
	_style_filled.border_width_bottom = 1
	_style_filled.border_color = Color(0.6, 0.5, 0.3, 0.8)
	_style_filled.corner_radius_top_left = 4
	_style_filled.corner_radius_top_right = 4
	_style_filled.corner_radius_bottom_left = 4
	_style_filled.corner_radius_bottom_right = 4

	_style_hover = StyleBoxFlat.new()
	_style_hover.bg_color = Color(0.2, 0.25, 0.15, 0.9)
	_style_hover.border_width_left = 2
	_style_hover.border_width_top = 2
	_style_hover.border_width_right = 2
	_style_hover.border_width_bottom = 2
	_style_hover.border_color = Color(0.9, 0.8, 0.4, 0.9)
	_style_hover.corner_radius_top_left = 4
	_style_hover.corner_radius_top_right = 4
	_style_hover.corner_radius_bottom_left = 4
	_style_hover.corner_radius_bottom_right = 4

	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.25, 0.28, 0.12, 0.95)
	_style_selected.border_width_left = 3
	_style_selected.border_width_top = 3
	_style_selected.border_width_right = 3
	_style_selected.border_width_bottom = 3
	_style_selected.border_color = Color(1.0, 0.85, 0.3, 1.0)
	_style_selected.corner_radius_top_left = 4
	_style_selected.corner_radius_top_right = 4
	_style_selected.corner_radius_bottom_left = 4
	_style_selected.corner_radius_bottom_right = 4


func _ready() -> void:
	_refresh_display()


func setup(pos: SquadBattleTypes.SquadEntityInSquadLocation, idx: int) -> void:
	row_position = pos
	slot_index = idx


func set_warrior(w: Character) -> void:
	warrior = w
	_refresh_display()


func clear_warrior() -> void:
	warrior = null
	_refresh_display()


func set_selected(selected: bool) -> void:
	_is_selected = selected
	_refresh_display()


func _refresh_display() -> void:
	if not is_node_ready():
		return

	if warrior:
		_name_label.text = warrior.display_name
		_class_label.text = warrior.identification
		if warrior.is_dead:
			_hp_label.text = "DEAD"
			_hp_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1.0))
		elif warrior.is_injured:
			_hp_label.text = "INJURED"
			_hp_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3, 1.0))
		else:
			_hp_label.text = "Healthy"
			_hp_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
		var style := _style_selected if _is_selected else (_style_hover if _is_hovered else _style_filled)
		add_theme_stylebox_override("panel", style)
	else:
		_name_label.text = "(empty)"
		_class_label.text = ""
		_hp_label.text = ""
		var style := _style_selected if _is_selected else (_style_hover if _is_hovered else _style_empty)
		add_theme_stylebox_override("panel", style)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if warrior == null:
		return null

	var preview := Label.new()
	preview.text = warrior.display_name
	preview.add_theme_font_size_override("font_size", 14)
	preview.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))

	var preview_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.22, 0.15, 0.95)
	style.border_color = Color(0.8, 0.7, 0.3, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	preview_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	preview_panel.add_child(margin)
	margin.add_child(preview)

	set_drag_preview(preview_panel)

	return {"warrior": warrior, "source_slot": self }


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not data.has("warrior"):
		return false
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	var dropped_warrior: Character = data["warrior"]
	var source_slot = data["source_slot"]

	if source_slot == self:
		return

	var my_warrior := warrior
	source_slot.set_warrior(my_warrior)
	set_warrior(dropped_warrior)

	warrior_dropped.emit(dropped_warrior, self )
	if my_warrior:
		warrior_dropped.emit(my_warrior, source_slot)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_is_hovered = false
			_is_selected = false
			_refresh_display()
		NOTIFICATION_DRAG_END:
			_is_hovered = false
			_refresh_display()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(self )
			accept_event()


func _mouse_enter() -> void:
	_is_hovered = true
	_refresh_display()


func _mouse_exit() -> void:
	_is_hovered = false
	_refresh_display()
