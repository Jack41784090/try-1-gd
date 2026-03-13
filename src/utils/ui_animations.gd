class_name UIAnimations


const HOVER_SCALE := Vector2(1.05, 1.05)
const PRESS_SCALE := Vector2(0.95, 0.95)
const NORMAL_SCALE := Vector2(1.0, 1.0)
const HOVER_DURATION := 0.12
const PRESS_DURATION := 0.06
const OVERLAY_FADE_DURATION := 0.25
const OVERLAY_SLIDE_DURATION := 0.3
const PANEL_SLIDE_OFFSET := 40.0
const BUTTON_STAGGER_DELAY := 0.04


static func register_button(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	button.mouse_entered.connect(func(): _on_hover_enter(button))
	button.mouse_exited.connect(func(): _on_hover_exit(button))
	button.button_down.connect(func(): _on_press(button))
	button.button_up.connect(func(): _on_release(button))
	button.resized.connect(func(): button.pivot_offset = button.size / 2.0)


static func _on_hover_enter(button: Button) -> void:
	if button.disabled:
		return
	_play_sfx("play_ui_hover")
	var tw := button.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(button, "scale", HOVER_SCALE, HOVER_DURATION)


static func _on_hover_exit(button: Button) -> void:
	var tw := button.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(button, "scale", NORMAL_SCALE, HOVER_DURATION)


static func _on_press(button: Button) -> void:
	if button.disabled:
		return
	var tw := button.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(button, "scale", PRESS_SCALE, PRESS_DURATION)


static func _on_release(button: Button) -> void:
	if not button.disabled:
		_play_sfx("play_ui_click")
	var tw := button.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(button, "scale", HOVER_SCALE, PRESS_DURATION)


static func _play_sfx(method_name: String) -> void:
	var main_loop = Engine.get_main_loop()
	if main_loop == null:
		return
	if not (main_loop is SceneTree):
		return
	var tree = main_loop as SceneTree
	var sfx = tree.root.get_node_or_null("SFX")
	if sfx and sfx.has_method(method_name):
		sfx.call(method_name)


static func register_all_buttons(root: Control) -> void:
	for child in root.get_children():
		if child is Button:
			register_button(child)
		if child is Control:
			register_all_buttons(child)


## Fade + slide an overlay panel in from below
static func show_overlay(overlay: Control, panel: Control = null) -> void:
	overlay.visible = true
	overlay.modulate = Color(1, 1, 1, 0)

	var target_panel := panel if panel else _find_panel(overlay)
	var original_y := 0.0
	if target_panel:
		original_y = target_panel.position.y
		target_panel.position.y = original_y + PANEL_SLIDE_OFFSET

	var tw := overlay.create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, OVERLAY_FADE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if target_panel:
		tw.tween_property(target_panel, "position:y", original_y, OVERLAY_SLIDE_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tw.finished


## Fade + slide an overlay panel out downward
static func hide_overlay(overlay: Control, panel: Control = null) -> void:
	var target_panel := panel if panel else _find_panel(overlay)

	var tw := overlay.create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 0.0, OVERLAY_FADE_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	if target_panel:
		tw.tween_property(target_panel, "position:y", target_panel.position.y + PANEL_SLIDE_OFFSET, OVERLAY_SLIDE_DURATION * 0.7) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tw.finished

	overlay.visible = false
	overlay.modulate = Color(1, 1, 1, 1)
	if target_panel:
		target_panel.position.y -= PANEL_SLIDE_OFFSET


## Stagger-animate buttons appearing one by one (e.g., when strategy UI shows)
static func stagger_buttons(buttons: Array[Button], delay_between: float = BUTTON_STAGGER_DELAY) -> void:
	for i in buttons.size():
		var btn := buttons[i]
		btn.modulate = Color(1, 1, 1, 0)
		btn.scale = Vector2(0.8, 0.8)
		btn.pivot_offset = btn.size / 2.0

	for i in buttons.size():
		var btn := buttons[i]
		var tw := btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "modulate:a", 1.0, 0.2) \
			.set_ease(Tween.EASE_OUT).set_delay(i * delay_between)
		tw.tween_property(btn, "scale", NORMAL_SCALE, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK) \
			.set_delay(i * delay_between)


## Animate a panel sliding in from the bottom and fading in
static func slide_in_panel(panel: Control) -> void:
	var original_y := panel.position.y
	panel.position.y = original_y + PANEL_SLIDE_OFFSET
	panel.modulate = Color(1, 1, 1, 0)
	panel.visible = true

	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, OVERLAY_FADE_DURATION) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "position:y", original_y, OVERLAY_SLIDE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tw.finished


## Animate a panel sliding out downward and fading out
static func slide_out_panel(panel: Control) -> void:
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 0.0, OVERLAY_FADE_DURATION) \
		.set_ease(Tween.EASE_IN)
	tw.tween_property(panel, "position:y", panel.position.y + PANEL_SLIDE_OFFSET, OVERLAY_SLIDE_DURATION * 0.7) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	panel.visible = false
	panel.position.y -= PANEL_SLIDE_OFFSET
	panel.modulate = Color(1, 1, 1, 1)


## Smooth number counter animation for labels
static func animate_label_number(label: Label, from: float, to: float, duration: float = 0.6, format: String = "%.0f") -> void:
	var tw := label.create_tween()
	tw.tween_method(func(val: float): label.text = format % val, from, to, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Pulse a control to draw attention
static func pulse(control: Control, intensity: float = 1.15, duration: float = 0.3) -> void:
	control.pivot_offset = control.size / 2.0
	var tw := control.create_tween()
	tw.tween_property(control, "scale", Vector2(intensity, intensity), duration * 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(control, "scale", NORMAL_SCALE, duration * 0.6) \
		.set_ease(Tween.EASE_IN_OUT)


static func _find_panel(overlay: Control) -> Control:
	for child in overlay.get_children():
		if child is PanelContainer:
			return child
	return null
