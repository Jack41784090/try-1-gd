class_name ScoutingView
extends Control

signal closed

const CONTACT_CARD_SCENE = preload("res://scenes/ui/scouting_contact_card.tscn")
const LABEL_SCENE = preload("res://scenes/ui/styled_label.tscn")

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var warning_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer/WarningContainer
@onready var no_contacts_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/NoContactsLabel
@onready var contacts_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer/ContactsScroll/ContactsContainer
@onready var close_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/CloseButton
@onready var presenter: ScoutingPresenter = $ScoutingPresenter
@onready var _coordination_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/FocusSection/HeaderRow/CoordinationLabel
@onready var _aggr_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/FocusSection/HeaderRow/AggrButton
@onready var _supp_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/FocusSection/HeaderRow/SuppButton
@onready var _clear_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/FocusSection/HeaderRow/ClearButton
@onready var _combat_check: CheckBox = $OverlayPanel/MarginContainer/VBoxContainer/FocusSection/FilterRow/CombatCheck
@onready var _merchant_check: CheckBox = $OverlayPanel/MarginContainer/VBoxContainer/FocusSection/FilterRow/MerchantCheck
@onready var _class_grid: GridContainer = $OverlayPanel/MarginContainer/VBoxContainer/FocusSection/ClassGrid

var _role_checkboxes: Dictionary = { }
var _class_checkboxes: Dictionary = { }


func _ready() -> void:
	overlay_panel.visible = false
	close_button.pressed.connect(_on_close)
	_connect_focus_signals()


func _connect_focus_signals() -> void:
	_aggr_button.pressed.connect(func(): presenter.on_preset_aggressive())
	_supp_button.pressed.connect(func(): presenter.on_preset_support())
	_clear_button.pressed.connect(func(): presenter.on_clear_focus())

	_role_checkboxes[StrategyTypes.SquadRole.COMBAT] = _combat_check
	_combat_check.toggled.connect(func(_pressed): presenter.on_role_toggled(StrategyTypes.SquadRole.COMBAT))

	_role_checkboxes[StrategyTypes.SquadRole.MERCHANT] = _merchant_check
	_merchant_check.toggled.connect(func(_pressed): presenter.on_role_toggled(StrategyTypes.SquadRole.MERCHANT))

	for child in _class_grid.get_children():
		if child is CheckBox:
			var cls_name: String = child.text
			for cls in EntityClasses.Types.values():
				if EntityClasses.Types.keys()[cls] == cls_name:
					_class_checkboxes[cls] = child
					child.toggled.connect(func(_pressed, c = cls): presenter.on_class_toggled(c))
					break


func show_scouting(world: World, player_squad: SquadData, ai_decisions: Dictionary = { }) -> void:
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
		var label: Label = LABEL_SCENE.instantiate()
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


func _on_close() -> void:
	hide_scouting()
	closed.emit()


func _clear_contacts() -> void:
	for child in contacts_container.get_children():
		child.queue_free()


func _create_contact_card(data: Dictionary) -> void:
	var state: StrategyTypes.ContactState = data["state"]
	var progress: float = data["progress"]
	var state_color := _get_state_color(state)
	var state_name = StrategyTypes.ContactState.keys()[state]

	var card: PanelContainer = CONTACT_CARD_SCENE.instantiate()
	var card_vbox: VBoxContainer = card.get_node("CardMargin/CardVBox")
	var title_label: Label = card.get_node("CardMargin/CardVBox/TitleLabel")
	var tracked_banner: HBoxContainer = card.get_node("CardMargin/CardVBox/TrackedBanner")
	var tracked_icon: TextureRect = card.get_node("CardMargin/CardVBox/TrackedBanner/TrackedIcon")
	var details_container: VBoxContainer = card.get_node("CardMargin/CardVBox/DetailsContainer")
	var progress_row: HBoxContainer = card.get_node("CardMargin/CardVBox/ProgressRow")
	var delta_symbol: Label = card.get_node("CardMargin/CardVBox/ProgressRow/DeltaSymbol")
	var bar_bg: ColorRect = card.get_node("CardMargin/CardVBox/ProgressRow/BarBackground")
	var bar_fill: ColorRect = card.get_node("CardMargin/CardVBox/ProgressRow/BarBackground/BarFill")
	var delta_mark: ColorRect = card.get_node("CardMargin/CardVBox/ProgressRow/BarBackground/DeltaMark")
	var pct_label: Label = card.get_node("CardMargin/CardVBox/ProgressRow/PercentLabel")
	var delta_label: Label = card.get_node("CardMargin/CardVBox/ProgressRow/DeltaLabel")

	title_label.text = "[%s] %s" % [state_name, data.get("title", "Unknown")]
	title_label.add_theme_color_override("font_color", state_color)

	if data.get("being_tracked", false):
		tracked_banner.visible = true
		tracked_icon.texture = load("res://assets/hoi4_icons/spotting.png")

	match state:
		StrategyTypes.ContactState.SUSPECTED:
			_add_detail(details_container, "Size: %s" % data.get("size_hint", "Unknown"))
			_add_detail(details_container, "Last detected near: %s" % data.get("area_hint", "Unknown"))
		StrategyTypes.ContactState.TRACKED:
			_add_detail(
				details_container,
				"Warriors: %d  |  Location: %s" % [
					data.get("warrior_count", 0),
					data.get("location", "Unknown"),
				],
			)
			_add_detail(details_container, "Morale: %s" % data.get("morale_hint", "Unknown"))
			_add_destination_intel(details_container, data, false)
		StrategyTypes.ContactState.LOCKED:
			_add_detail(
				details_container,
				"Warriors: %d  |  Location: %s" % [
					data.get("warrior_count", 0),
					data.get("location", "Unknown"),
				],
			)
			_add_detail(
				details_container,
				"Morale: %.1f  |  Stance: %s" % [
					data.get("morale", 0.0),
					StrategyTypes.EngagementStance.keys()[data.get("stance", 0)],
				],
			)
			_add_destination_intel(details_container, data, true)
			var warriors_data: Array = data.get("warriors", [])
			if not warriors_data.is_empty():
				_add_detail(details_container, "Roster:")
				for w in warriors_data:
					var w_color = Color(0.7, 0.7, 0.7)
					if w["status"] == "Injured":
						w_color = Color(1.0, 0.8, 0.3)
					elif w["status"] == "Dead":
						w_color = Color(1.0, 0.3, 0.3)
					var w_label: Label = LABEL_SCENE.instantiate()
					w_label.text = "  - %s (%s)" % [w["name"], w["status"]]
					w_label.add_theme_font_size_override("font_size", 13)
					w_label.add_theme_color_override("font_color", w_color)
					details_container.add_child(w_label)

	var progress_delta: float = data.get("progress_delta", 0.0)
	_configure_progress_bar(delta_symbol, bar_fill, delta_mark, pct_label, delta_label, progress, progress_delta, state_color)

	contacts_container.add_child(card)


func _add_detail(parent: VBoxContainer, text: String) -> void:
	var label: Label = LABEL_SCENE.instantiate()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	parent.add_child(label)


func _configure_progress_bar(delta_symbol: Label, bar_fill: ColorRect, delta_mark: ColorRect, pct_label: Label, delta_label: Label, progress: float, delta: float, state_color: Color) -> void:
	if not is_zero_approx(delta):
		delta_symbol.visible = true
		if delta > 0.0:
			delta_symbol.text = "▲"
			delta_symbol.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			delta_symbol.text = "▼"
			delta_symbol.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	var fill_fraction := clampf(progress / 100.0, 0.0, 1.0)
	bar_fill.color = state_color
	bar_fill.anchor_right = fill_fraction

	if not is_zero_approx(delta):
		delta_mark.visible = true
		var prev_progress := clampf(progress - delta, 0.0, 100.0)
		var prev_fraction := clampf(prev_progress / 100.0, 0.0, 1.0)
		if delta > 0.0:
			delta_mark.color = Color(0.4, 1.0, 0.4, 0.5)
			delta_mark.anchor_left = prev_fraction
			delta_mark.anchor_right = fill_fraction
		else:
			delta_mark.color = Color(1.0, 0.4, 0.4, 0.5)
			delta_mark.anchor_left = fill_fraction
			delta_mark.anchor_right = prev_fraction

	pct_label.text = "%.0f%%" % progress

	if not is_zero_approx(delta):
		delta_label.visible = true
		if delta > 0.0:
			delta_label.text = "+%.1f" % delta
			delta_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			delta_label.text = "%.1f" % delta
			delta_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))


func _add_destination_intel(parent: VBoxContainer, data: Dictionary, show_distance: bool) -> void:
	var intel: Dictionary = data.get("destination_intel", { })
	if intel.is_empty():
		return
	var dest_name: String = intel.get("destination_name", "Unknown")
	var text := "Heading toward: %s" % dest_name
	if show_distance and intel.has("estimated_hours"):
		var hours: int = intel["estimated_hours"]
		text += " (~%d %s away)" % [hours, "hour" if hours == 1 else "hours"]
	var progress_val: float = data.get("progress", 0.0)
	var label: Label = LABEL_SCENE.instantiate()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	if not show_distance and progress_val < 60.0:
		label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
		label.text += " (uncertain)"
	else:
		label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		parent.add_child(label)
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
