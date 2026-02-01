class_name StatChangeAnimator extends Control

@onready var ui_root = get_parent()
@onready var morale_label: ProgressBar = $MainVBox/StatusArea/StatusPanel/StatusMargin/StatusContent/ProgressBar
@onready var stats_panel: PanelContainer = $MainVBox/StatusHeader/HeaderPanel
@onready var stability_label: Label = get_node("MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Stability/MarginContainer/Stability/Label")
@onready var development_label: Label = get_node("MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Development/MarginContainer/Development/Label")
@onready var money_label: Label = get_node("MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Money/MarginContainer/BoxContainer/Label")
@onready var food_label: Label = get_node("MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Food/MarginContainer/BoxContainer/Label")
@onready var karma_label: Label = get_node("MainVBox/StatusHeader/HeaderPanel/HeaderHBox/StatsPanel(NoMargin)/Karma/MarginContainer/BoxContainer/Label")


## Animates stat changes with floating delta labels and UI interpolation
## Similar to DamageNumbersManager but adapted for 2D strategic UI

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

## Animates all stat changes with floating deltas, interpolation, and visual feedback
## Returns when all animations complete
func animate_changes(stat_deltas: Dictionary) -> void:
	print("[StatChangeAnimator] animate_changes() called with %d deltas" % stat_deltas.size())
	print("[StatChangeAnimator] Deltas: ", stat_deltas)
	active_tweens.clear()
	
	var has_any_change := false
	var net_change := 0.0
	
	# Calculate net change for background flash
	for delta_value in stat_deltas.values():
		if abs(delta_value) >= DELTA_THRESHOLD:
			has_any_change = true
			net_change += delta_value
	
	if not has_any_change:
		print("[StatChangeAnimator] No changes meet threshold (%.2f), returning early" % DELTA_THRESHOLD)
		return
	
	print("[StatChangeAnimator] Net change: %.2f" % net_change)
	
	# Spawn floating delta labels
	var spawned_labels := 0
	for stat_name in stat_deltas:
		var delta_value = stat_deltas[stat_name]
		if abs(delta_value) < DELTA_THRESHOLD:
			print("[StatChangeAnimator] Skipping %s (delta %.4f below threshold)" % [stat_name, delta_value])
			continue
		
		var label_node = self [stat_name + "_label"]
		if label_node and label_node is Label:
			print("[StatChangeAnimator] Spawning floating delta for %s: %+.2f" % [stat_name, delta_value])
			_spawn_floating_delta(ui_root, label_node, delta_value, stat_name)
			spawned_labels += 1
		else:
			print("[StatChangeAnimator] Warning: UI element for %s not found or not a Label" % stat_name)
	
	print("[StatChangeAnimator] Spawned %d floating label(s)" % spawned_labels)
	
	# Flash stats panel background if available
	if stats_panel and stats_panel is Control:
		print("[StatChangeAnimator] Flashing background (net change: %.2f)" % net_change)
		_flash_background(stats_panel, net_change)
	else:
		print("[StatChangeAnimator] Stats panel not available for flashing")
	
	# Interpolate morale bar if available
	var new_morale = morale_label.value + stat_deltas.get("morale")
	if morale_label and morale_label is ProgressBar and new_morale != null:
		print("[StatChangeAnimator] Interpolating morale bar to %.2f" % new_morale)
		_interpolate_progress_bar(morale_label, new_morale)
	else:
		print("[StatChangeAnimator] Morale bar interpolation skipped (bar=%s, value=%s)" % [str(morale_label != null), str(new_morale)])
	
	# Wait for all animations to complete
	if active_tweens.size() > 0:
		print("[StatChangeAnimator] Waiting for %d tween(s) to complete..." % active_tweens.size())
		await active_tweens[0].finished
		print("[StatChangeAnimator] All animations finished")
	else:
		print("[StatChangeAnimator] No tweens created, nothing to wait for")

func _spawn_floating_delta(ui_root: Control, anchor_label: Label, delta_value: float, stat_name: String) -> void:
	print("[StatChangeAnimator] _spawn_floating_delta: %s = %+.2f" % [stat_name, delta_value])
	var delta_label := Label.new()
	ui_root.add_child(delta_label)
	
	# Format text based on stat type
	var formatted_text := ""
	if stat_name in ["money", "karma", "morale", "end_progression"]:
		formatted_text = "%+.1f" % delta_value
	else:
		formatted_text = "%+d" % int(delta_value)
	
	delta_label.text = formatted_text
	delta_label.add_theme_font_size_override("font_size", 24)
	
	# Color code: green for positive, red for negative
	var color := Color.GREEN if delta_value > 0 else Color.RED
	delta_label.add_theme_color_override("font_color", color)
	
	# Position above the anchor label
	var anchor_global_pos := anchor_label.global_position
	var anchor_size := anchor_label.size
	delta_label.global_position = anchor_global_pos + Vector2(anchor_size.x * 0.5, -10)
	
	# Center the label horizontally
	delta_label.pivot_offset = delta_label.size * 0.5
	
	# Animate: float up, fade out, and scale down
	var tween := ui_root.create_tween().set_parallel(true)
	active_tweens.append(tween)
	
	var target_y := delta_label.global_position.y - FLOAT_HEIGHT
	tween.tween_property(delta_label, "global_position:y", target_y, FLOAT_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(delta_label, "modulate:a", 0.0, FADE_DURATION) \
		.set_delay(FADE_DELAY).set_ease(Tween.EASE_IN)
	
	tween.tween_property(delta_label, "scale", Vector2(0.5, 0.5), FADE_DURATION) \
		.set_delay(FADE_DELAY).set_ease(Tween.EASE_IN)
	
	# Scale bounce on anchor label
	_bounce_scale(anchor_label, ui_root)
	
	# Cleanup after animation
	tween.finished.connect(func(): delta_label.queue_free())

func _bounce_scale(node: Control, tween_parent: Node) -> void:
	print("[StatChangeAnimator] _bounce_scale on node: ", node.name)
	var original_scale := node.scale
	var bounce_scale := original_scale * 1.2
	
	var tween := tween_parent.create_tween()
	active_tweens.append(tween)
	
	tween.tween_property(node, "scale", bounce_scale, SCALE_BOUNCE_DURATION * 0.5) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", original_scale, SCALE_BOUNCE_DURATION * 0.5) \
		.set_ease(Tween.EASE_IN)

func _flash_background(panel: Control, net_change: float) -> void:
	var flash_color := Color.WHITE
	if net_change > 0:
		flash_color = Color(0.5, 1.0, 0.5, 1.0) # Green tint
		print("[StatChangeAnimator] _flash_background: GREEN (net positive)")
	else:
		flash_color = Color(1.0, 0.5, 0.5, 1.0) # Red tint
		print("[StatChangeAnimator] _flash_background: RED (net negative)")
	
	var original_modulate := panel.modulate
	
	var tween := panel.create_tween()
	active_tweens.append(tween)
	
	tween.tween_property(panel, "modulate", flash_color, FLASH_DURATION * 0.5)
	tween.tween_property(panel, "modulate", original_modulate, FLASH_DURATION * 0.5)

func _interpolate_progress_bar(bar: ProgressBar, new_value: float) -> void:
	print("[StatChangeAnimator] _interpolate_progress_bar: %.2f -> %.2f" % [bar.value, new_value])
	var tween := bar.create_tween()
	active_tweens.append(tween)
	
	tween.tween_property(bar, "value", new_value, BAR_INTERPOLATE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
