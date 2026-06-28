@tool
class_name UnitsFloatingPanel
extends Control

const WARRIOR_ITEM_SCENE = preload("res://scenes/warrior_item.tscn")

@onready var _title_label: Label = $ScrollContainer/VBox/TitleLabel
@onready var _units_container: VBoxContainer = $ScrollContainer/VBox/UnitsContainer

var _squad: StrategySquad


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


func setup(squad: StrategySquad) -> void:
	_squad = squad


func _rebuild_units_container() -> void:
	for child in _units_container.get_children():
		child.queue_free()
	for warrior in _squad.warriors:
		var item = WARRIOR_ITEM_SCENE.instantiate()
		item.setup(warrior)
		_units_container.add_child(item)


func _connect_signals() -> void:
	if not _squad.warriors_changed.is_connected(_rebuild_units_container):
		_squad.warriors_changed.connect(_rebuild_units_container)


func _disconnect_signals() -> void:
	if _squad and _squad.warriors_changed.is_connected(_rebuild_units_container):
		_squad.warriors_changed.disconnect(_rebuild_units_container)


func _on_visibility_changed() -> void:
	if _squad == null:
		return
	if visible:
		_connect_signals()
		_rebuild_units_container()
	else:
		_disconnect_signals()
