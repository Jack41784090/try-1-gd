class_name UnitsTab
extends Control

const WARRIOR_ITEM_SCENE = preload("res://scenes/warrior_item.tscn")

var _title_label: Label
var _warriors_container: VBoxContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1.0))
	vbox.add_child(_title_label)

	_warriors_container = VBoxContainer.new()
	_warriors_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warriors_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_warriors_container)


func refresh(squad: SquadStrategicData) -> void:
	_title_label.text = "%s — %d warriors" % [squad.squad_name, squad.get_living_warriors().size()]

	for child in _warriors_container.get_children():
		child.queue_free()

	for warrior in squad.warriors:
		var item = WARRIOR_ITEM_SCENE.instantiate()
		item.setup_warrior(warrior)
		_warriors_container.add_child(item)
