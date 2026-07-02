@tool
class_name InventoryFloatingPanel
extends PanelContainer

@export var bookmark_left_path: NodePath
@export var bookmark_right_path: NodePath

signal equip_weapon_requested(warrior: StrategyEntity, weapon: WeaponResource)
signal equip_armor_requested(warrior: StrategyEntity, armor: ArmorConfig)
signal unequip_weapon_requested(warrior: StrategyEntity)
signal unequip_armor_requested(warrior: StrategyEntity)

const GRID_ITEM_SCENE = preload("res://scenes/ui/manage_squad/inventory_item_grid.tscn")
const WEAPON_SLOT_SCENE = preload("res://src/squad-battle/items/weapon/ui.tscn")

@export var preview_in_editor: bool = false:
	set(v):
		preview_in_editor = v
		if Engine.is_editor_hint() and is_node_ready():
			if preview_in_editor:
				_build_demo_squad()
				_rebuild_inv()
			else:
				for child in _inventory_container.get_children():
					child.queue_free()
		else:
			push_warning("preview_in_editor can only be set in the editor.")

@onready var _inventory_container: Control = %InventoryContainer
#@onready var _empty_label: Label = $MainHBox/InventoryPanel/VBox/EmptyLabel

var _item_windows: Array[Control] = []

var _squad: StrategySquad:
	set(_s):
		if _s:
			_squad = _s
			_rebuild_inv()


func _build_demo_squad() -> StrategySquad:
	_squad = StrategySquad.new()
	var w = load("res://resources/strategy/warrior-presets/_crossbowman.tres")
	for i in range(5):
		var nw = StrategyEntity.new(w)
		_squad.add_warrior(nw)

	var mace = load("res://resources/combat/weapon/config/mace.tres")
	for i in range(15):
		_squad.inventory.add_weapon(mace)
	return _squad


func _ready() -> void:
	if Engine.is_editor_hint() and _squad == null:
		_build_demo_squad()
		_rebuild_inv()
	visibility_changed.connect(_on_visibility_changed)


func setup(squad: StrategySquad) -> void:
	_squad = squad


func _connect_signals() -> void:
	if not _squad.inventory.changed.is_connected(_rebuild_inv):
		_squad.inventory.changed.connect(_rebuild_inv)


func _disconnect_signals() -> void:
	if _squad and _squad.inventory.changed.is_connected(_rebuild_inv):
		_squad.inventory.changed.disconnect(_rebuild_inv)


func _on_visibility_changed() -> void:
	if _squad == null:
		return
	if visible:
		_connect_signals()
		_rebuild_inv()
	else:
		_disconnect_signals()


func _rebuild_inv() -> void:
	var dm := get_tree().get_first_node_in_group(&"desktop_manager")
	for w in _item_windows:
		if is_instance_valid(w):
			if dm != null:
				dm.unregister_window(w)
			w.queue_free()
	_item_windows.clear()
	var items: Array = _squad.inventory.get_all_items()
	for i in items:
		if i is WeaponResource:
			var ws = WEAPON_SLOT_SCENE.instantiate()
			ws.weapon_config = i
			_inventory_container.add_child(ws)
			_item_windows.append(ws)
		elif i is ArmorConfig:
			pass

	#_empty_label.visible = _squad.inventory.is_empty()
