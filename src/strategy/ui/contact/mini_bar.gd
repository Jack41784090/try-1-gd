class_name ContactMiniBar extends HBoxContainer

@onready var symbol_label: Label = $Symbol
@onready var name_label: Label = $NameLabel
@onready var bar_bg: PanelContainer = $BarBg
@onready var bar_fill: ColorRect = $BarBg/Fill
@onready var delta_mark: ColorRect = $BarBg/DeltaMark
@onready var pct_label: Label = $PctLabel
@onready var delta_label: Label = $DeltaLabel

var target_id: String = ""

func populate(data: Dictionary) -> void:
	target_id = data.get("target_id", "")
	var state: StrategyTypes.ContactState = data["state"]
	var progress: float = data["progress"]
	var delta: float = data.get("progress_delta", 0.0)
	var title: String = data.get("title", "Unknown")
	var state_color := _get_state_color(state)

	_update_symbol(delta, state_color)
	name_label.text = title
	name_label.add_theme_color_override("font_color", state_color)

	var fill_fraction := clampf(progress / 100.0, 0.0, 1.0)
	bar_fill.color = state_color * Color(1, 1, 1, 0.8)
	bar_fill.anchor_right = fill_fraction

	_update_delta_mark(delta, fill_fraction, progress)

	pct_label.text = "%.0f%%" % progress

	_update_delta_label(delta)

	visible = true


func update_existing(data: Dictionary) -> void:
	var state: StrategyTypes.ContactState = data["state"]
	var progress: float = data["progress"]
	var delta: float = data.get("progress_delta", 0.0)
	var title: String = data.get("title", "Unknown")
	var state_color := _get_state_color(state)

	_update_symbol(delta, state_color)
	name_label.text = title
	name_label.add_theme_color_override("font_color", state_color)

	var new_fraction := clampf(progress / 100.0, 0.0, 1.0)
	var old_fraction := bar_fill.anchor_right
	bar_fill.color = state_color * Color(1, 1, 1, 0.8)

	var tween := create_tween()
	tween.tween_property(bar_fill, "anchor_right", new_fraction, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	delta_mark.visible = false
	if not is_zero_approx(delta):
		delta_mark.visible = true
		if delta > 0.0:
			delta_mark.color = Color(0.4, 1.0, 0.4, 0.35)
			delta_mark.anchor_left = old_fraction
			delta_mark.anchor_right = new_fraction
		else:
			delta_mark.color = Color(1.0, 0.4, 0.4, 0.35)
			delta_mark.anchor_left = new_fraction
			delta_mark.anchor_right = old_fraction
		tween.parallel().tween_property(delta_mark, "modulate:a", 0.0, 1.5).set_delay(0.5)

	pct_label.text = "%.0f%%" % progress
	_update_delta_label(delta)


func reset_bar() -> void:
	target_id = ""
	visible = false
	delta_mark.visible = false
	delta_mark.modulate.a = 1.0
	delta_label.visible = false
	bar_fill.anchor_right = 0.0
	modulate.a = 1.0
	position.y = 0.0


func _update_symbol(delta: float, state_color: Color) -> void:
	if not is_zero_approx(delta):
		if delta > 0.0:
			symbol_label.text = "▲"
			symbol_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			symbol_label.text = "▼"
			symbol_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		symbol_label.text = "●"
		symbol_label.add_theme_color_override("font_color", state_color * Color(1, 1, 1, 0.5))


func _update_delta_mark(delta: float, fill_fraction: float, progress: float) -> void:
	delta_mark.visible = false
	if not is_zero_approx(delta):
		var prev_progress := clampf(progress - delta, 0.0, 100.0)
		var prev_fraction := clampf(prev_progress / 100.0, 0.0, 1.0)
		delta_mark.visible = true
		delta_mark.modulate.a = 1.0
		if delta > 0.0:
			delta_mark.color = Color(0.4, 1.0, 0.4, 0.35)
			delta_mark.anchor_left = prev_fraction
			delta_mark.anchor_right = fill_fraction
		else:
			delta_mark.color = Color(1.0, 0.4, 0.4, 0.35)
			delta_mark.anchor_left = fill_fraction
			delta_mark.anchor_right = prev_fraction


func _update_delta_label(delta: float) -> void:
	if not is_zero_approx(delta):
		delta_label.visible = true
		if delta > 0.0:
			delta_label.text = "+%.1f" % delta
			delta_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			delta_label.text = "%.1f" % delta
			delta_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		delta_label.visible = false


static func _get_state_color(state: StrategyTypes.ContactState) -> Color:
	match state:
		StrategyTypes.ContactState.SUSPECTED:
			return Color(0.6, 0.6, 0.6)
		StrategyTypes.ContactState.TRACKED:
			return Color(1.0, 0.9, 0.4)
		StrategyTypes.ContactState.LOCKED:
			return Color(0.4, 1.0, 0.4)
		_:
			return Color(0.5, 0.5, 0.5)
