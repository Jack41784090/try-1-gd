@tool
class_name UnitsFloatingPanel
extends Control

signal weapon_window_received(warrior: Character, window: Control)
signal armor_window_received(warrior: Character, window: Control)
signal weapon_display_removed(warrior: Character, window: Control)
signal armor_display_removed(warrior: Character, window: Control)

const WARRIOR_ITEM_SCENE = preload("res://scenes/ui/manage_squad/unit_item.tscn")
@onready var _units_container: Control = %VBC

var _item_windows: Array[Control] = []

var _squad: StrategySquad:
	set(_s):
		if _s:
			_squad = _s
			if is_node_ready():
				_rebuild_units_container()


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if _squad:
		_rebuild_units_container()


func setup(squad: StrategySquad) -> void:
	_squad = squad


func _rebuild_units_container() -> void:
	var dm := get_tree().get_first_node_in_group(&"desktop_manager")
	for w in _item_windows:
		if is_instance_valid(w):
			if dm != null:
				dm.unregister_window(w)
			w.queue_free()
	_item_windows.clear()
	for warrior in _squad.warriors:
		var item = WARRIOR_ITEM_SCENE.instantiate()
		item.setup(warrior)
		item.weapon_window_received.connect(func(w, win): weapon_window_received.emit(w, win))
		item.armor_window_received.connect(func(w, win): armor_window_received.emit(w, win))
		item.weapon_display_removed.connect(func(w, win): weapon_display_removed.emit(w, win))
		item.armor_display_removed.connect(func(w, win): armor_display_removed.emit(w, win))
		_units_container.add_child(item)
		_item_windows.append(item)


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
