class_name UnitsTab
extends Control

const WARRIOR_ITEM_SCENE = preload("res://scenes/warrior_item.tscn")

@onready var _title_label: Label = $ScrollContainer/VBox/TitleLabel
@onready var _warriors_container: VBoxContainer = $ScrollContainer/VBox/WarriorsContainer

var _squad: StrategySquad


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


func setup(squad: StrategySquad) -> void:
	_squad = squad


func _pull() -> void:
	_title_label.text = "%s — %d warriors" % [_squad.squad_name, _squad.get_living_warriors().size()]
	for child in _warriors_container.get_children():
		child.queue_free()
	for warrior in _squad.warriors:
		var item = WARRIOR_ITEM_SCENE.instantiate()
		item.setup(warrior)
		_warriors_container.add_child(item)


func _connect_signals() -> void:
	if not _squad.warriors_changed.is_connected(_pull):
		_squad.warriors_changed.connect(_pull)


func _disconnect_signals() -> void:
	if _squad and _squad.warriors_changed.is_connected(_pull):
		_squad.warriors_changed.disconnect(_pull)


func _on_visibility_changed() -> void:
	if _squad == null:
		return
	if visible:
		_connect_signals()
		_pull()
	else:
		_disconnect_signals()
