@tool
class_name TestUnitsFloatingPanel
extends Control

const WARRIOR_ITEM_SCENE = preload("res://src/unit_item.tscn")
@onready var _units_container: Control = %VBC
@onready var timer = $Timer

var _item_windows: Array[Control] = []

var _squad: TestStrategySquad:
	set(_s):
		if _s:
			_squad = _s
			if is_node_ready():
				setup(_s)
				_rebuild_units_container()
			else:
				setup.call_deferred(_s)

func _build_demo_squad() -> TestStrategySquad:
	var ns = TestStrategySquad.new()
	var w = load("res://src/strategy_entity_resource-instance1.tres")
	for i in range(5):
		var nw = TestStrategyEntity.new(w)
		nw.display_name = "W"
		ns.add_warrior(nw)

	var mace = load("res://resources/combat/weapon/config/mace.tres")
	for i in range(15):
		ns.inventory.add_weapon(mace)
	return ns

func _change_random_squad_member_prop() -> void:
	var rand = floor(randf() * len(_squad.warriors))
	var unit_changing: TestStrategyEntity = _squad.warriors[rand]
	#var rand2 = floor(randf() * len(unit_changing.rs_arr))
	
	var prop := unit_changing.rs_arr[StatName.I.MORALE]
	prop.stat_value += randf()

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	timer.timeout.connect(_change_random_squad_member_prop)
	setup()

func setup(squad: TestStrategySquad = null) -> void:
	if squad != null and squad != _squad:
		_squad = squad
	elif get_tree().current_scene == self and squad == null:
		_squad = _build_demo_squad()


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
