@tool
extends HBoxContainer

@export var key: String = "Key:"
@export var value: float = 0.0
@export var show_bar: bool = false

@onready var key_label: Label = $Key
@onready var value_label: Label = $ValueLabel
@onready var value_bar: ProgressBar = $ValueBar

func _ready() -> void:
	key_label.text = key
	value_label.text = "%.0f" % value
	value_bar.visible = show_bar
	if show_bar:
		value_bar.value = value

func set_value(val: float) -> void:
	value = val
	if is_node_ready():
		value_label.text = "%.0f" % val
		if show_bar:
			value_bar.value = val

func set_value_text(text: String) -> void:
	if is_node_ready():
		value_label.text = text

func set_value_color(color: Color) -> void:
	if is_node_ready():
		value_label.add_theme_color_override("font_color", color)
