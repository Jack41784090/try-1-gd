class_name MissionsView
extends Control

signal closed
signal mission_selected(mission: Mission)

const ITEM_BUTTON_SCENE = preload("res://scenes/ui/mission_item_button.tscn")
const LABEL_SCENE = preload("res://scenes/ui/styled_label.tscn")

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var presenter: MissionsPresenter = $MissionsPresenter
@onready var active_list: VBoxContainer = $OverlayPanel/MarginContainer/MainVBox/ContentHBox/LeftPanel/LeftMargin/LeftScroll/LeftVBox/ActiveList
@onready var completed_list: VBoxContainer = $OverlayPanel/MarginContainer/MainVBox/ContentHBox/LeftPanel/LeftMargin/LeftScroll/LeftVBox/CompletedList
@onready var detail_vbox: VBoxContainer = $OverlayPanel/MarginContainer/MainVBox/ContentHBox/RightPanel/RightMargin/RightScroll/DetailVBox
@onready var active_header: Label = $OverlayPanel/MarginContainer/MainVBox/ContentHBox/LeftPanel/LeftMargin/LeftScroll/LeftVBox/ActiveHeader
@onready var completed_header: Label = $OverlayPanel/MarginContainer/MainVBox/ContentHBox/LeftPanel/LeftMargin/LeftScroll/LeftVBox/CompletedHeader
@onready var _close_btn: Button = $OverlayPanel/MarginContainer/MainVBox/CloseButton

var _selected_button: Button = null
var _mission_buttons: Array[Button] = []


func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(func():
		hide_missions()
		closed.emit()
	)
	presenter.bind_view(self)


#region Public API

func show_missions() -> void:
	visible = true
	overlay_panel.visible = true
	await UIAnimations.show_overlay(self, overlay_panel)


func hide_missions() -> void:
	await UIAnimations.hide_overlay(self, overlay_panel)
	overlay_panel.visible = false
	visible = false


func display_mission_list(active: Array[Mission], completed: Array[Mission]) -> void:
	_clear_container(active_list)
	_clear_container(completed_list)
	_selected_button = null
	_mission_buttons.clear()

	for mission in active:
		_create_mission_item(active_list, mission, true)

	for mission in completed:
		_create_mission_item(completed_list, mission, false)

	active_header.text = "Active (%d)" % active.size()
	completed_header.text = "Completed (%d)" % completed.size()


func select_mission_at(index: int) -> void:
	if index >= 0 and index < _mission_buttons.size():
		_highlight_button(_mission_buttons[index])


func display_mission_details(mission: Mission) -> void:
	_clear_container(detail_vbox)

	_add_section_header(detail_vbox, "Details")

	var desc: Label = LABEL_SCENE.instantiate()
	desc.text = mission.description if not mission.description.is_empty() else "No description available."
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	detail_vbox.add_child(desc)

	if not mission.conditions.is_empty():
		_add_subsection_header(detail_vbox, "Conditions")
		for condition in mission.conditions:
			_add_detail_line(detail_vbox, _describe_condition(condition), Color(0.75, 0.75, 0.75))

	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 12)
	detail_vbox.add_child(sep)

	_add_section_header(detail_vbox, "Rewards")
	_display_rewards(mission)


func clear_details() -> void:
	_clear_container(detail_vbox)
	var label: Label = LABEL_SCENE.instantiate()
	label.text = "Select a mission to view details"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	detail_vbox.add_child(label)

#endregion


#region Mission List Items

func _create_mission_item(parent: VBoxContainer, mission: Mission, is_active: bool) -> void:
	var button: Button = ITEM_BUTTON_SCENE.instantiate()
	button.text = mission.mission_name

	var base_color: Color
	if is_active:
		base_color = Color(0.95, 0.9, 0.75)
	else:
		base_color = Color(0.5, 0.5, 0.5)

	button.add_theme_color_override("font_color", base_color)
	button.set_meta("base_color", base_color)

	button.pressed.connect(func():
		_highlight_button(button)
		mission_selected.emit(mission)
	)

	_mission_buttons.append(button)
	parent.add_child(button)


func _highlight_button(btn: Button) -> void:
	if _selected_button:
		var prev_color: Color = _selected_button.get_meta("base_color", Color(0.95, 0.9, 0.75))
		_selected_button.add_theme_color_override("font_color", prev_color)
	_selected_button = btn
	btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

#endregion


#region Detail Display

func _display_rewards(mission: Mission) -> void:
	var has_rewards := false

	var squad_stats: Dictionary = mission.completion_effects.get("squad_stats", {})
	for stat_key in squad_stats:
		var value: float = squad_stats[stat_key]
		var sign_str := "+" if value >= 0 else ""
		_add_detail_line(detail_vbox, "%s%s %.0f" % [sign_str, _squad_stat_display(stat_key), absf(value)], Color(0.5, 1.0, 0.5))
		has_rewards = true

	var reputation: Dictionary = mission.completion_effects.get("reputation", {})
	for faction_id in reputation:
		var value: float = reputation[faction_id]
		var sign_str := "+" if value >= 0 else ""
		_add_detail_line(detail_vbox, "%s%.0f %s reputation" % [sign_str, absf(value), faction_id], Color(0.5, 0.8, 1.0))
		has_rewards = true

	if not mission.postrequisite_mission_ids.is_empty():
		_add_detail_line(detail_vbox, "Unlocks %d new mission(s)" % mission.postrequisite_mission_ids.size(), Color(1.0, 0.9, 0.5))
		has_rewards = true

	if not has_rewards:
		_add_detail_line(detail_vbox, "No rewards specified.", Color(0.5, 0.5, 0.5))

#endregion


#region Condition Descriptions

func _describe_condition(condition: TriggerCondition) -> String:
	match condition.condition_type:
		TriggerCondition.ConditionType.LOCATION:
			return "Be at %s" % condition.parameters.get("location_id", "unknown")
		TriggerCondition.ConditionType.LOCATION_TYPE:
			var loc_type: int = condition.parameters.get("location_type", 0)
			return "Be at a %s" % StrategyTypes.LocationType.keys()[loc_type].capitalize()
		TriggerCondition.ConditionType.SQUAD_STATUS:
			return _describe_squad_condition(condition.parameters)
		TriggerCondition.ConditionType.WARRIOR_STATUS:
			return _describe_warrior_condition(condition.parameters)
		TriggerCondition.ConditionType.ACTIVITY_TYPE:
			var at: int = condition.parameters.get("activity_type", 0)
			return "Perform %s" % StrategyTypes.ActivityType.keys()[at].capitalize()
		TriggerCondition.ConditionType.TIME:
			return _describe_time_condition(condition.parameters)
		TriggerCondition.ConditionType.MISSION_STATUS:
			var mid: String = condition.parameters.get("mission_id", "")
			var status: String = condition.parameters.get("status", "completed")
			return "Mission '%s' %s" % [mid, status]
		TriggerCondition.ConditionType.LOCATION_TRANSITION:
			var transition: String = condition.parameters.get("transition_type", "arriving")
			return "%s at a location" % transition.capitalize()
		_:
			return str(condition.condition_type)


func _describe_squad_condition(params: Dictionary) -> String:
	var parts: Array[String] = []
	if params.has("squad_morale_min") and params["squad_morale_min"] > -999:
		parts.append("Morale >= %.0f" % params["squad_morale_min"])
	if params.has("squad_morale_max") and params["squad_morale_max"] < 999:
		parts.append("Morale <= %.0f" % params["squad_morale_max"])
	if params.has("money_min") and params["money_min"] > -999:
		parts.append("Money >= %.0f" % params["money_min"])
	if params.has("food_min") and params["food_min"] > -999:
		parts.append("Food >= %d" % params["food_min"])
	if params.has("karma_min") and params["karma_min"] > -999:
		parts.append("Karma >= %.0f" % params["karma_min"])
	if parts.is_empty():
		return "Squad status check"
	return ", ".join(parts)


func _describe_warrior_condition(params: Dictionary) -> String:
	if params.has("warrior_religion") and params["warrior_religion"] >= 0:
		var religion: String = StrategyTypes.Religion.keys()[params["warrior_religion"]]
		var count: int = params.get("warrior_count_min", 1)
		return "Have %d+ %s warrior(s)" % [count, religion.capitalize()]
	return "Warrior status check"


func _describe_time_condition(params: Dictionary) -> String:
	var min_turn: int = params.get("turn_min", 0)
	var max_turn: int = params.get("turn_max", 999999)
	if min_turn > 0 and max_turn < 999999:
		return "Between turns %d and %d" % [min_turn, max_turn]
	elif min_turn > 0:
		return "After turn %d" % min_turn
	elif max_turn < 999999:
		return "Before turn %d" % max_turn
	return "Any turn"

#endregion


#region Helpers

func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var label: Label = LABEL_SCENE.instantiate()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	parent.add_child(label)


func _add_subsection_header(parent: VBoxContainer, text: String) -> void:
	var label: Label = LABEL_SCENE.instantiate()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	parent.add_child(label)


func _add_detail_line(parent: VBoxContainer, text: String, color: Color) -> void:
	var label: Label = LABEL_SCENE.instantiate()
	label.text = "  %s" % text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _squad_stat_display(stat_key: Variant) -> String:
	if stat_key is StrategyTypes.SquadProperty:
		return StrategyTypes.SquadProperty.keys()[stat_key].capitalize()
	if stat_key is int:
		return StrategyTypes.SquadProperty.keys()[stat_key].capitalize()
	return str(stat_key)


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()

#endregion
