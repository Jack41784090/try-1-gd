class_name StatChangeAnimator extends Control

@onready var ui_root = get_parent()
@onready var morale_label: ProgressBar = $MainVBox/StatusArea/StatusPanel/StatusMargin/StatusContent/ProgressBar
@onready var stats_panel: PanelContainer = $MainVBox/StatusHeader/HeaderPanel
@onready var stability_label: Label = get_node("MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Stability/MarginContainer/Stability/Label")
@onready var development_label: Label = get_node("MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Development/MarginContainer/Development/Label")
@onready var money_label: Label = get_node("MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Money/MarginContainer/BoxContainer/Label")
@onready var food_label: Label = get_node("MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Food/MarginContainer/BoxContainer/Label")
@onready var karma_label: Label = get_node("MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Karma/MarginContainer/BoxContainer/Label")


const FLOAT_DURATION := 1.0
const FLOAT_HEIGHT := 40.0
const FADE_DELAY := 0.3
const FADE_DURATION := 0.7
const SCALE_BOUNCE_DURATION := 0.3
const LABEL_INTERPOLATE_DURATION := 0.8
const BAR_INTERPOLATE_DURATION := 0.8
const FLASH_DURATION := 0.4
const DELTA_THRESHOLD := 0.1

var active_tweens: Array[Tween] = []

## Callers should await this — it doesn't return until all tweens finish.
func animate_changes(stat_deltas: Dictionary) -> void:
	print("[StatChangeAnimator] animate_changes() called with %d deltas" % stat_deltas.size())
	print("[StatChangeAnimator] Deltas: ", stat_deltas)
	active_tweens.clear()
	
	var has_any_change := false
	var net_change := 0.0
	
	for delta_value in stat_deltas.values():
		if abs(delta_value) >= DELTA_THRESHOLD:
			has_any_change = true
			net_change += delta_value
	
	if not has_any_change:
		print("[StatChangeAnimator] No changes meet threshold (%.2f), returning early" % DELTA_THRESHOLD)
		return
	
	print("[StatChangeAnimator] Net change: %.2f" % net_change)
	
	var spawned_labels := 0
	for stat_name in stat_deltas:
		var delta_value = stat_deltas[stat_name]
		if abs(delta_value) < DELTA_THRESHOLD:
			print("[StatChangeAnimator] Skipping %s (delta %.4f below threshold)" % [stat_name, delta_value])
			continue
		
		var label_node = self [stat_name + "_label"]
		if label_node and label_node is Label:
			print("[StatChangeAnimator] Spawning floating delta for %s: %+.2f" % [stat_name, delta_value])
			var delta_label := Label.new()
			ui_root.add_child(delta_label)
			var formatted_text := ""
			if stat_name in ["money", "karma", "morale"]:
				formatted_text = "%+.1f" % delta_value
			else:
				formatted_text = "%+d" % int(delta_value)
			delta_label.text = formatted_text
			delta_label.add_theme_font_size_override("font_size", 24)
			var color := Color.GREEN if delta_value > 0 else Color.RED
			delta_label.add_theme_color_override("font_color", color)
			var anchor_global_pos: Vector2 = label_node.global_position
			var anchor_size: Vector2 = label_node.size
			delta_label.global_position = anchor_global_pos + Vector2(anchor_size.x * 0.5, -10)
			delta_label.pivot_offset = delta_label.size * 0.5
			var tween := ui_root.create_tween().set_parallel(true)
			active_tweens.append(tween)
			var target_y := delta_label.global_position.y - FLOAT_HEIGHT
			tween.tween_property(delta_label, "global_position:y", target_y, FLOAT_DURATION) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(delta_label, "modulate:a", 0.0, FADE_DURATION) \
				.set_delay(FADE_DELAY).set_ease(Tween.EASE_IN)
			tween.tween_property(delta_label, "scale", Vector2(0.5, 0.5), FADE_DURATION) \
				.set_delay(FADE_DELAY).set_ease(Tween.EASE_IN)
			print("[StatChangeAnimator] _bounce_scale on node: ", label_node.name)
			var original_scale: Vector2 = label_node.scale
			var bounce_scale: Vector2 = original_scale * 1.2
			var bounce_tween := ui_root.create_tween()
			active_tweens.append(bounce_tween)
			bounce_tween.tween_property(label_node, "scale", bounce_scale, SCALE_BOUNCE_DURATION * 0.5) \
				.set_ease(Tween.EASE_OUT)
			bounce_tween.tween_property(label_node, "scale", original_scale, SCALE_BOUNCE_DURATION * 0.5) \
				.set_ease(Tween.EASE_IN)
			tween.finished.connect(func(): delta_label.queue_free())
			spawned_labels += 1
		else:
			print("[StatChangeAnimator] Warning: UI element for %s not found or not a Label" % stat_name)
	
	print("[StatChangeAnimator] Spawned %d floating label(s)" % spawned_labels)
	
	if stats_panel and stats_panel is Control:
		print("[StatChangeAnimator] Flashing background (net change: %.2f)" % net_change)
		var flash_color := Color.WHITE
		if net_change > 0:
			flash_color = Color(0.5, 1.0, 0.5, 1.0)
			print("[StatChangeAnimator] _flash_background: GREEN (net positive)")
		else:
			flash_color = Color(1.0, 0.5, 0.5, 1.0)
			print("[StatChangeAnimator] _flash_background: RED (net negative)")
		var original_modulate := stats_panel.modulate
		var flash_tween := stats_panel.create_tween()
		active_tweens.append(flash_tween)
		flash_tween.tween_property(stats_panel, "modulate", flash_color, FLASH_DURATION * 0.5)
		flash_tween.tween_property(stats_panel, "modulate", original_modulate, FLASH_DURATION * 0.5)
	else:
		print("[StatChangeAnimator] Stats panel not available for flashing")
	
	var new_morale = morale_label.value + stat_deltas.get("morale")
	if morale_label and morale_label is ProgressBar and new_morale != null:
		print("[StatChangeAnimator] Interpolating morale bar to %.2f" % new_morale)
		print("[StatChangeAnimator] _interpolate_progress_bar: %.2f -> %.2f" % [morale_label.value, new_morale])
		var bar_tween := morale_label.create_tween()
		active_tweens.append(bar_tween)
		bar_tween.tween_property(morale_label, "value", new_morale, BAR_INTERPOLATE_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		print("[StatChangeAnimator] Morale bar interpolation skipped (bar=%s, value=%s)" % [str(morale_label != null), str(new_morale)])
	
	if active_tweens.size() > 0:
		print("[StatChangeAnimator] Waiting for %d tween(s) to complete..." % active_tweens.size())
		await active_tweens[0].finished
		print("[StatChangeAnimator] All animations finished")
	else:
		print("[StatChangeAnimator] No tweens created, nothing to wait for")
