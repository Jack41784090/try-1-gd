class_name UnitsTab
extends Control

const WARRIOR_ITEM_SCENE = preload("res://scenes/warrior_item.tscn")

@onready var _title_label: Label = $ScrollContainer/VBox/TitleLabel
@onready var _warriors_container: VBoxContainer = $ScrollContainer/VBox/WarriorsContainer


func refresh(squad: SquadData) -> void:
	_title_label.text = "%s — %d warriors" % [squad.squad_name, squad.get_living_warriors().size()]

	for child in _warriors_container.get_children():
		child.queue_free()

	for warrior in squad.warriors:
		var item = WARRIOR_ITEM_SCENE.instantiate()
		item.setup_warrior(warrior)
		_warriors_container.add_child(item)
