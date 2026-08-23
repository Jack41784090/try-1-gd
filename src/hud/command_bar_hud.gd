class_name CommandBarHud
extends Control

## Only reacts to text starting with "/"; knows nothing about how it gets interpreted — just hands the raw text off via command_submitted.
signal command_submitted(raw_text: String)

const BAR_HEIGHT := 32.0

var input: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -BAR_HEIGHT
	offset_bottom = 0.0

	input = LineEdit.new()
	input.name = "CommandInput"
	input.placeholder_text = "/command ..."
	input.clear_button_enabled = true
	input.set_anchors_preset(Control.PRESET_FULL_RECT)
	input.text_submitted.connect(_on_text_submitted)
	add_child(input)


func _on_text_submitted(text: String) -> void:
	var trimmed := text.strip_edges()
	input.clear()
	if not trimmed.begins_with("/"):
		return
	LogGd.debug("[CommandBarHud] submitted: %s" % trimmed)
	command_submitted.emit(trimmed)
