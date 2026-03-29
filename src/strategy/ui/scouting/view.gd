class_name ScoutingView extends Control

signal closed

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var warning_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer/WarningContainer
@onready var no_contacts_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/NoContactsLabel
@onready var contacts_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer/ContactsScroll/ContactsContainer
@onready var close_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/CloseButton
@onready var presenter: ScoutingPresenter = $ScoutingPresenter

var _focus_section: VBoxContainer
var _coordination_label: Label
var _role_checkboxes: Dictionary = {}
var _class_checkboxes: Dictionary = {}

func _ready() -> void:
	overlay_panel.visible = false
	close_button.pressed.connect(_on_close)
	_build_focus_section()

func show_scouting(world: World, player_squad: SquadData, ai_decisions: Dictionary = {}) -> void:
	visible = true
	overlay_panel.visible = true
	presenter.refresh(world, player_squad, ai_decisions)
	await UIAnimations.show_overlay(self, overlay_panel)

func hide_scouting() -> void:
	await UIAnimations.hide_overlay(self, overlay_panel)
	overlay_panel.visible = false
	visible = false

func display_contacts(contact_cards: Array[Dictionary]) -> void:
	_clear_contacts()
	for card in contact_cards:
		_create_contact_card(card)

func display_warnings(warning_texts: Array[String]) -> void:
	for child in warning_container.get_children():
		child.queue_free()

	warning_container.visible = not warning_texts.is_empty()
	for text in warning_texts:
		var label = Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
		warning_container.add_child(label)

func show_no_contacts() -> void:
	no_contacts_label.visible = true

func hide_no_contacts() -> void:
	no_contacts_label.visible = false

func update_focus_ui(focus, coordination: float) -> void:
	_coordination_label.text = "(%d%%)" % int(coordination * 100.0)

	for role_key in _role_checkboxes:
		var cb: CheckBox = _role_checkboxes[role_key]
		cb.set_pressed_no_signal(focus.selected_roles.has(role_key))

	for cls_key in _class_checkboxes:
		var cb: CheckBox = _class_checkboxes[cls_key]
		cb.set_pressed_no_signal(focus.selected_classes.has(cls_key))

func _build_focus_section() -> void:
	var main_vbox = warning_container.get_parent()
	_focus_section = VBoxContainer.new()
	_focus_section.add_theme_constant_override("separation", 3)
	main_vbox.add_child(_focus_section)
	main_vbox.move_child(_focus_section, warning_container.get_index())

	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	_focus_section.add_child(header_row)

	var title = Label.new()
	title.text = "Scouting Focus"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	header_row.add_child(title)

	_coordination_label = Label.new()
	_coordination_label.text = "(0%)"
	_coordination_label.add_theme_font_size_override("font_size", 12)
	_coordination_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header_row.add_child(_coordination_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	var btn_aggressive = Button.new()
	btn_aggressive.text = "Aggr"
	btn_aggressive.add_theme_font_size_override("font_size", 11)
	btn_aggressive.pressed.connect(func(): presenter.on_preset_aggressive())
	header_row.add_child(btn_aggressive)

	var btn_support = Button.new()
	btn_support.text = "Supp"
	btn_support.add_theme_font_size_override("font_size", 11)
	btn_support.pressed.connect(func(): presenter.on_preset_support())
	header_row.add_child(btn_support)

	var btn_clear = Button.new()
	btn_clear.text = "Clear"
	btn_clear.add_theme_font_size_override("font_size", 11)
	btn_clear.pressed.connect(func(): presenter.on_clear_focus())
	header_row.add_child(btn_clear)

	var filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	_focus_section.add_child(filter_row)

	for role in [StrategyTypes.SquadRole.COMBAT, StrategyTypes.SquadRole.MERCHANT]:
		var cb = CheckBox.new()
		cb.text = StrategyTypes.SquadRole.keys()[role]
		cb.add_theme_font_size_override("font_size", 11)
		cb.toggled.connect(func(_pressed): presenter.on_role_toggled(role))
		filter_row.add_child(cb)
		_role_checkboxes[role] = cb

	var class_grid = GridContainer.new()
	class_grid.columns = 4
	class_grid.add_theme_constant_override("h_separation", 6)
	class_grid.add_theme_constant_override("v_separation", 1)
	_focus_section.add_child(class_grid)
	for cls in EntityClasses.Types.values():
		var cb = CheckBox.new()
		cb.text = EntityClasses.Types.keys()[cls]
		cb.add_theme_font_size_override("font_size", 11)
		cb.toggled.connect(func(_pressed): presenter.on_class_toggled(cls))
		class_grid.add_child(cb)
		_class_checkboxes[cls] = cb

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	_focus_section.add_child(sep)

func _on_close() -> void:
	hide_scouting()
	closed.emit()

func _clear_contacts() -> void:
	for child in contacts_container.get_children():
		child.queue_free()

func _create_contact_card(data: Dictionary) -> void:
	var state: StrategyTypes.ContactState = data["state"]
	var progress: float = data["progress"]

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var state_color := _get_state_color(state)
	var state_name = StrategyTypes.ContactState.keys()[state]

	var title_label = Label.new()
	title_label.text = "[%s] %s" % [state_name, data.get("title", "Unknown")]
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", state_color)
	vbox.add_child(title_label)

	if data.get("being_tracked", false):
		var tracked_banner = HBoxContainer.new()
		tracked_banner.add_theme_constant_override("separation", 6)
		var tracked_icon = TextureRect.new()
		tracked_icon.texture = load("res://assets/hoi4_icons/spotting.png")
		tracked_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tracked_icon.custom_minimum_size = Vector2(20, 20)
		tracked_banner.add_child(tracked_icon)
		var tracked_label = Label.new()
		tracked_label.text = "Tracked"
		tracked_label.add_theme_font_size_override("font_size", 15)
		tracked_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		tracked_banner.add_child(tracked_label)
		vbox.add_child(tracked_banner)

	match state:
		StrategyTypes.ContactState.SUSPECTED:
			_add_detail(vbox, "Size: %s" % data.get("size_hint", "Unknown"))
			_add_detail(vbox, "Last detected near: %s" % data.get("area_hint", "Unknown"))

		StrategyTypes.ContactState.TRACKED:
			_add_detail(vbox, "Warriors: %d  |  Location: %s" % [
				data.get("warrior_count", 0),
				data.get("location", "Unknown")
			])
			_add_detail(vbox, "Morale: %s" % data.get("morale_hint", "Unknown"))
			_add_destination_intel(vbox, data, false)

		StrategyTypes.ContactState.LOCKED:
			_add_detail(vbox, "Warriors: %d  |  Location: %s" % [
				data.get("warrior_count", 0),
				data.get("location", "Unknown")
			])
			_add_detail(vbox, "Morale: %.1f  |  Stance: %s" % [
				data.get("morale", 0.0),
				StrategyTypes.EngagementStance.keys()[data.get("stance", 0)]
			])
			_add_destination_intel(vbox, data, true)
			var warriors_data: Array = data.get("warriors", [])
			if not warriors_data.is_empty():
				_add_detail(vbox, "Roster:")
				for w in warriors_data:
					var w_color = Color(0.7, 0.7, 0.7)
					if w["status"] == "Injured":
						w_color = Color(1.0, 0.8, 0.3)
					elif w["status"] == "Dead":
						w_color = Color(1.0, 0.3, 0.3)
					var w_label = Label.new()
					w_label.text = "  - %s (%s)" % [w["name"], w["status"]]
					w_label.add_theme_font_size_override("font_size", 13)
					w_label.add_theme_color_override("font_color", w_color)
					vbox.add_child(w_label)

	_add_scout_report_bar(vbox, progress, data.get("progress_delta", 0.0), state_color)

	contacts_container.add_child(card)

func _add_detail(parent: VBoxContainer, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	parent.add_child(label)


func _add_scout_report_bar(parent: VBoxContainer, progress: float, delta: float, state_color: Color) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	if not is_zero_approx(delta):
		var symbol = Label.new()
		symbol.add_theme_font_size_override("font_size", 14)
		if delta > 0.0:
			symbol.text = "▲"
			symbol.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			symbol.text = "▼"
			symbol.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		row.add_child(symbol)

	var bar_bg = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(200, 12)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.color = Color(0.15, 0.15, 0.15)
	row.add_child(bar_bg)

	var bar_fill = ColorRect.new()
	var fill_fraction := clampf(progress / 100.0, 0.0, 1.0)
	bar_fill.color = state_color
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.anchor_right = fill_fraction
	bar_bg.add_child(bar_fill)

	if not is_zero_approx(delta):
		var prev_progress := clampf(progress - delta, 0.0, 100.0)
		var prev_fraction := clampf(prev_progress / 100.0, 0.0, 1.0)
		var delta_mark = ColorRect.new()
		if delta > 0.0:
			delta_mark.color = Color(0.4, 1.0, 0.4, 0.5)
			delta_mark.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			delta_mark.anchor_left = prev_fraction
			delta_mark.anchor_right = fill_fraction
		else:
			delta_mark.color = Color(1.0, 0.4, 0.4, 0.5)
			delta_mark.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			delta_mark.anchor_left = fill_fraction
			delta_mark.anchor_right = prev_fraction
		bar_bg.add_child(delta_mark)

	var pct_label = Label.new()
	pct_label.text = "%.0f%%" % progress
	pct_label.add_theme_font_size_override("font_size", 12)
	pct_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(pct_label)

	if not is_zero_approx(delta):
		var delta_label = Label.new()
		delta_label.add_theme_font_size_override("font_size", 11)
		if delta > 0.0:
			delta_label.text = "+%.1f" % delta
			delta_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			delta_label.text = "%.1f" % delta
			delta_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		row.add_child(delta_label)


func _add_destination_intel(parent: VBoxContainer, data: Dictionary, show_distance: bool) -> void:
	var intel: Dictionary = data.get("destination_intel", {})
	if intel.is_empty():
		return
	var dest_name: String = intel.get("destination_name", "Unknown")
	var text := "Heading toward: %s" % dest_name
	if show_distance and intel.has("turns_remaining"):
		var turns: int = intel["turns_remaining"]
		text += " (%d %s away)" % [turns, "turn" if turns == 1 else "turns"]
	var progress: float = data.get("progress", 0.0)
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	if not show_distance and progress < 60.0:
		label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
		label.text += " (uncertain)"
	else:
		label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	parent.add_child(label)

func _get_state_color(state: StrategyTypes.ContactState) -> Color:
	match state:
		StrategyTypes.ContactState.SUSPECTED:
			return Color(0.6, 0.6, 0.6)
		StrategyTypes.ContactState.TRACKED:
			return Color(1.0, 0.9, 0.4)
		StrategyTypes.ContactState.LOCKED:
			return Color(0.4, 1.0, 0.4)
		_:
			return Color(0.5, 0.5, 0.5)
