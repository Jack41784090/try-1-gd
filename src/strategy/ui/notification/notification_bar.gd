class_name NotificationBar
extends HBoxContainer

const DETAIL_PANEL_SCENE := preload("res://scenes/ui/notification_detail_panel.tscn")

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
		var notif := _notifications[i]
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

		btn.pressed.connect(_on_alert_pressed.bind(i))
		add_child(btn)

		btn.scale = Vector2(0.5, 0.5)
		btn.modulate.a = 0.0
		btn.pivot_offset = btn.custom_minimum_size / 2.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(i * 0.05)
		tween.tween_property(btn, "modulate:a", 1.0, 0.15).set_delay(i * 0.05)


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


func _on_alert_pressed(index: int) -> void:
	if index < 0 or index >= _notifications.size():
		return
	if _active_button_index == index:
		_dismiss_panel()
		return
	_dismiss_panel()
	_active_button_index = index
	var notif := _notifications[index]
	var color: Color = TYPE_COLORS.get(notif.type, Color.WHITE)

	var panel: PanelContainer = DETAIL_PANEL_SCENE.instantiate()
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

	var vbox: VBoxContainer = panel.get_node("VBox")
	vbox.add_theme_constant_override("separation", 4)

	var title: Label = vbox.get_node("Title")
	title.text = notif.title
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", color)

	var desc: Label = vbox.get_node("Description")
	desc.text = notif.description
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc.custom_minimum_size.x = 220

	var hbox: HBoxContainer = vbox.get_node("HBox")
	var action_btn: Button = hbox.get_node("ActionButton")
	var dismiss_btn: Button = hbox.get_node("DismissButton")

	if notif.action.is_valid():
		hbox.add_theme_constant_override("separation", 6)
		action_btn.text = notif.action_label
		action_btn.add_theme_font_size_override("font_size", 12)
		action_btn.custom_minimum_size = Vector2(100, 28)
		action_btn.pressed.connect(func():
			_dismiss_panel()
			notif.action.call()
		)
		dismiss_btn.text = "Dismiss"
		dismiss_btn.add_theme_font_size_override("font_size", 12)
		dismiss_btn.custom_minimum_size = Vector2(70, 28)
		dismiss_btn.pressed.connect(_dismiss_panel)
	else:
		action_btn.visible = false
		dismiss_btn.text = "Dismiss"
		dismiss_btn.add_theme_font_size_override("font_size", 12)
		dismiss_btn.custom_minimum_size = Vector2(70, 28)
		dismiss_btn.pressed.connect(_dismiss_panel)

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
