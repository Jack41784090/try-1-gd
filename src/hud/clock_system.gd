class_name ClockSystemHud
extends PanelContainer

@onready var time_label = $HBoxContainer/Label

func set_time(time: int):
	time_label.text = str(time)
	LogGd.debug(time_label.text)
