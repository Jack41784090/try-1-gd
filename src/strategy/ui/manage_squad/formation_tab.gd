class_name FormationTab
extends Control

signal formation_changed(warrior: Warrior, new_position: SquadBattleTypes.SquadEntityInSquadLocation)

const MAX_SLOTS_PER_ROW := 5
const ROW_LABELS := { 1: "FRONT LINE", 2: "MIDDLE LINE", 3: "BACK LINE" }
const ROW_COLORS := {
	1: Color(0.7, 0.3, 0.3, 0.15),
	2: Color(0.7, 0.6, 0.3, 0.1),
	3: Color(0.3, 0.5, 0.7, 0.1),
}

var _rows: Dictionary = {}
var _all_slots: Array = []
var _main_vbox: VBoxContainer
var _hint_label: Label
var _selected_slot = null


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(outer_vbox)

	var title := Label.new()
	title.text = "Click or drag warriors between rows to change formation"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(_hint_label)

	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(_main_vbox)

	_build_rows()


func _build_rows() -> void:
	var _slot_script = load("res://src/strategy/ui/manage_squad/formation_slot.gd")

	for pos_val in [SquadBattleTypes.SquadEntityInSquadLocation.Front,
					SquadBattleTypes.SquadEntityInSquadLocation.Middle,
					SquadBattleTypes.SquadEntityInSquadLocation.Back]:
		var row_panel := PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0, 110)

		var row_style := StyleBoxFlat.new()
		row_style.bg_color = ROW_COLORS[pos_val]
		row_style.border_width_bottom = 1
		row_style.border_color = Color(0.3, 0.3, 0.35, 0.4)
		row_style.corner_radius_top_left = 6
		row_style.corner_radius_top_right = 6
		row_style.corner_radius_bottom_left = 6
		row_style.corner_radius_bottom_right = 6
		row_panel.add_theme_stylebox_override("panel", row_style)

		var row_margin := MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 10)
		row_margin.add_theme_constant_override("margin_right", 10)
		row_margin.add_theme_constant_override("margin_top", 6)
		row_margin.add_theme_constant_override("margin_bottom", 6)
		row_panel.add_child(row_margin)

		var row_vbox := VBoxContainer.new()
		row_vbox.add_theme_constant_override("separation", 4)
		row_margin.add_child(row_vbox)

		var row_header := Label.new()
		row_header.text = ROW_LABELS[pos_val]
		row_header.add_theme_font_size_override("font_size", 13)
		row_header.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45, 0.9))
		row_vbox.add_child(row_header)

		var slots_hbox := HBoxContainer.new()
		slots_hbox.add_theme_constant_override("separation", 8)
		row_vbox.add_child(slots_hbox)

		var row_slots: Array = []
		for i in MAX_SLOTS_PER_ROW:
			var slot = _slot_script.new()
			slot.setup(pos_val, i)
			slot.warrior_dropped.connect(_on_warrior_dropped)
			slot.slot_clicked.connect(_on_slot_clicked)
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slots_hbox.add_child(slot)
			row_slots.append(slot)
			_all_slots.append(slot)

		_rows[pos_val] = row_slots
		_main_vbox.add_child(row_panel)


func refresh(squad: SquadData) -> void:
	_clear_selection()
	for slot in _all_slots:
		slot.clear_warrior()

	var row_counts: Dictionary = { 1: 0, 2: 0, 3: 0 }

	for warrior in squad.warriors:
		if warrior.is_dead:
			continue
		var pos: int = warrior.location_prebattle
		var idx: int = row_counts.get(pos, 0)
		if idx < MAX_SLOTS_PER_ROW:
			var slots: Array = _rows[pos]
			slots[idx].set_warrior(warrior)
			row_counts[pos] = idx + 1

	var living := squad.get_living_warriors().size()
	_hint_label.text = "%d / %d warriors placed" % [living, squad.warriors.size()]


func _on_warrior_dropped(warrior: Warrior, slot) -> void:
	_clear_selection()
	formation_changed.emit(warrior, slot.row_position)


func _on_slot_clicked(slot) -> void:
	if _selected_slot == null:
		if slot.warrior == null:
			return
		_selected_slot = slot
		slot.set_selected(true)
		return

	if slot == _selected_slot:
		_clear_selection()
		return

	var source_warrior: Warrior = _selected_slot.warrior
	var target_warrior: Warrior = slot.warrior
	var source_slot = _selected_slot

	source_slot.set_warrior(target_warrior)
	slot.set_warrior(source_warrior)

	formation_changed.emit(source_warrior, slot.row_position)
	if target_warrior:
		formation_changed.emit(target_warrior, source_slot.row_position)

	_clear_selection()


func _clear_selection() -> void:
	if _selected_slot:
		_selected_slot.set_selected(false)
		_selected_slot = null
