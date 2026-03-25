class_name NotificationBar
extends HBoxContainer

var _notifications: Array[NotificationData] = []
var _active_panel: PanelContainer = null
var _active_button_index: int = -1

const TYPE_COLORS := {
	NotificationData.NotificationType.CONTACT_DETECTED: Color(0.2, 0.6, 1.0),
	NotificationData.NotificationType.CONTACT_LOST: Color(0.5, 0.5, 0.5),
	NotificationData.NotificationType.CONTACT_DECAYING: Color(0.8, 0.6, 0.3),
	NotificationData.NotificationType.LOW_FOOD: Color(1.0, 0.7, 0.2),
	NotificationData.NotificationType.MISSION_UNLOCKED: Color(0.3, 1.0, 0.5),
	NotificationData.NotificationType.MISSION_COMPLETED: Color(0.3, 1.0, 0.3),
}

const TYPE_ICONS := {
	NotificationData.NotificationType.CONTACT_DETECTED: "!",
	NotificationData.NotificationType.CONTACT_LOST: "?",
	NotificationData.NotificationType.CONTACT_DECAYING: "~",
	NotificationData.NotificationType.LOW_FOOD: "F",
	NotificationData.NotificationType.MISSION_UNLOCKED: "M",
	NotificationData.NotificationType.MISSION_COMPLETED: "M",
}


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_notifications(notifications: Array[NotificationData]) -> void:
	_dismiss_panel()
	_clear_buttons()
	_notifications = notifications
	for i in _notifications.size():
		_add_alert_button(i)


func clear() -> void:
	_dismiss_panel()
	_clear_buttons()
	_notifications.clear()


func _clear_buttons() -> void:
	var children := get_children()
	for i in range(children.size() - 1, -1, -1):
		var child := children[i]
		remove_child(child)
		child.queue_free()
	_active_button_index = -1


func _add_alert_button(index: int) -> void:
	var notif := _notifications[index]
	var color: Color = TYPE_COLORS.get(notif.type, Color.WHITE)
	var icon_text: String = TYPE_ICONS.get(notif.type, "!")

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(32, 32)
	btn.text = icon_text
	btn.tooltip_text = notif.title
	btn.add_theme_font_size_override("font_size", 14)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = Color(color, 1.0)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(color, 0.6)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))

	btn.pressed.connect(_on_alert_pressed.bind(index))
	add_child(btn)

	btn.scale = Vector2(0.5, 0.5)
	btn.modulate.a = 0.0
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(index * 0.05)
	tween.tween_property(btn, "modulate:a", 1.0, 0.15).set_delay(index * 0.05)


func _on_alert_pressed(index: int) -> void:
	if index < 0 or index >= _notifications.size():
		return
	if _active_button_index == index:
		_dismiss_panel()
		return
	_dismiss_panel()
	_active_button_index = index
	_show_detail_panel(index)


func _show_detail_panel(index: int) -> void:
	var notif := _notifications[index]
	var color: Color = TYPE_COLORS.get(notif.type, Color.WHITE)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_color = Color(color, 0.7)
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.custom_minimum_size.x = 250

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = notif.title
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", color)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = notif.description
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 220
	vbox.add_child(desc)

	if notif.action.is_valid():
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		vbox.add_child(hbox)

		var action_btn := Button.new()
		action_btn.text = notif.action_label
		action_btn.add_theme_font_size_override("font_size", 12)
		action_btn.custom_minimum_size = Vector2(100, 28)
		action_btn.pressed.connect(func():
			_dismiss_panel()
			notif.action.call()
		)
		hbox.add_child(action_btn)

		var dismiss_btn := Button.new()
		dismiss_btn.text = "Dismiss"
		dismiss_btn.add_theme_font_size_override("font_size", 12)
		dismiss_btn.custom_minimum_size = Vector2(70, 28)
		dismiss_btn.pressed.connect(_dismiss_panel)
		hbox.add_child(dismiss_btn)
	else:
		var dismiss_btn := Button.new()
		dismiss_btn.text = "Dismiss"
		dismiss_btn.add_theme_font_size_override("font_size", 12)
		dismiss_btn.custom_minimum_size = Vector2(70, 28)
		dismiss_btn.pressed.connect(_dismiss_panel)
		vbox.add_child(dismiss_btn)

	panel.top_level = true
	panel.modulate.a = 0.0
	add_child(panel)
	panel.global_position = global_position + Vector2(max(0.0, size.x - panel.custom_minimum_size.x - 12), size.y + 4)
	_active_panel = panel

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)


func _dismiss_panel() -> void:
	if _active_panel:
		_active_panel.queue_free()
		_active_panel = null
	_active_button_index = -1
