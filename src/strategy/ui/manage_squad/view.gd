class_name ManageSquadView
extends Control

signal closed

@onready var title_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var warriors_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer/ScrollContainer/WarriorsContainer
@onready var close_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/CloseButton

const WARRIOR_ITEM_SCENE = preload("res://scenes/warrior_item.tscn")

var current_squad: SquadStrategicData = null


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)


func show_squad(squad: SquadStrategicData) -> void:
	current_squad = squad
	visible = true
	_populate_warrior_list()


func hide_screen() -> void:
	visible = false
	current_squad = null


func _populate_warrior_list() -> void:
	for child in warriors_container.get_children():
		child.queue_free()

	title_label.text = current_squad.squad_name

	for warrior in current_squad.warriors:
		var warrior_item = WARRIOR_ITEM_SCENE.instantiate()
		warrior_item.setup_warrior(warrior)
		warriors_container.add_child(warrior_item)


func _on_close_pressed() -> void:
	hide_screen()
	closed.emit()
